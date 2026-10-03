// 檔案名稱：functions/cameras/camera_access_policy.js
// 功能說明：攝影機觀看模式、服務是否仍可看，以及米家分享申請的狀態規則。

const brands = require("./camera_brands");
const VIEW_WEB = "web_url";
const VIEW_EXTERNAL = "external_app";
const PROVIDER_XIAOMI = "xiaomi";

const STATUS_PENDING = "pending";
const STATUS_NEEDS_INFO = "needs_info";
const STATUS_INVITED = "invited";
const STATUS_CONFIRMED = "customer_confirmed";
const STATUS_REVOCATION = "revocation_pending";
const STATUS_CLOSED = "closed";

/**
 * @param {*} device 設備文件
 * @return {string}
 */
function viewModeOf(device) {
  const mode = String((device && device.viewMode) || "").trim();
  return mode === VIEW_EXTERNAL ? VIEW_EXTERNAL : VIEW_WEB;
}

/**
 * @param {*} raw 網址
 * @return {boolean}
 */
function isDirectHttps(raw) {
  try {
    const uri = new URL(String(raw || "").trim());
    return uri.protocol === "https:" &&
      String(uri.hostname || "").trim() !== "";
  } catch (error) {
    return false;
  }
}

/**
 * 舊設備沒有 viewMode 時視為網址模式。米家模式不因 url 為空而視為未完成。
 * @param {*} device 設備文件
 * @return {boolean}
 */
function cameraSetupComplete(device) {
  if (!device || String(device.type || "camera") !== "camera") {
    return false;
  }
  if (viewModeOf(device) === VIEW_EXTERNAL) {
    return brands.brandSupportsAccountShare(device.provider);
  }
  return isDirectHttps(device.url);
}

/**
 * @param {*} booking 訂單
 * @return {boolean}
 */
function isDaycareBooking(booking) {
  const data = booking || {};
  const kind = String(data.bookingKind || "").trim();
  const service = String(data.serviceType || "").trim();
  return kind === "daycare" || service === "daycare";
}

/**
 * @param {*} value 欄位
 * @return {boolean}
 */
function hasValue(value) {
  return value != null && String(value).trim() !== "";
}

/**
 * 住宿：checked_in、已分房，且尚未寫入退房或釋放房間。
 * 安親：checked_in、已分房，且尚未寫入 actualEndAt。
 * 不使用預計結束日單獨判斷。
 * @param {*} booking 訂單
 * @return {boolean}
 */
function cameraServiceOpen(booking) {
  if (!booking) {
    return false;
  }
  const status = String(booking.status || "").trim();
  const roomId = String(booking.roomId || "").trim();
  if (!roomId || status === "cancelled") {
    return false;
  }
  if (isDaycareBooking(booking)) {
    if (hasValue(booking.actualEndAt)) {
      return false;
    }
    if (status === "completed" || status === "checked_out") {
      return false;
    }
    return status === "checked_in";
  }
  if (status !== "checked_in") {
    return false;
  }
  if (hasValue(booking.checkOutAt) || hasValue(booking.checkedOutAt)) {
    return false;
  }
  if (booking.stayRoomReleased === true) {
    return false;
  }
  return true;
}

/**
 * @param {*} shop 店家文件
 * @return {boolean}
 */
function shopCameraOn(shop) {
  return !shop || shop.showCameraSection !== false;
}

/**
 * @param {*} device 設備
 * @param {boolean} cameraOn 店家總開關
 * @return {boolean}
 */
function customerCanWatchDevice(device, cameraOn) {
  if (cameraOn === false || !device) {
    return false;
  }
  if (String(device.type || "") !== "camera") {
    return false;
  }
  if (device.enabled !== true || device.platformLocked === true) {
    return false;
  }
  return cameraSetupComplete(device);
}

/**
 * @param {*} request 申請
 * @return {boolean}
 */
function invitationWasSent(request) {
  if (!request) {
    return false;
  }
  if (hasValue(request.invitedAt)) {
    return true;
  }
  const status = String(request.status || "");
  return status === STATUS_INVITED ||
    status === STATUS_CONFIRMED ||
    status === STATUS_REVOCATION;
}

/**
 * 已分享的改為待取消；從未邀請的直接結束，不寫取消分享時間。
 * @param {*} request 申請
 * @param {string} reason 原因
 * @param {string} now 時間字串
 * @return {Object|null}
 */
function stopSharingPatch(request, reason, now) {
  const status = String((request && request.status) || "");
  if (!request || status === STATUS_CLOSED || status === STATUS_REVOCATION) {
    return null;
  }
  if (invitationWasSent(request)) {
    return {
      status: STATUS_REVOCATION,
      revocationReason: reason,
      revocationRequestedAt: request.revocationRequestedAt || now,
      updatedAt: now,
    };
  }
  return {
    status: STATUS_CLOSED,
    closeReason: reason,
    closedAt: request.closedAt || now,
    updatedAt: now,
  };
}

/**
 * @param {*} before 更新前訂單
 * @param {*} after 更新後訂單
 * @param {Array<Object>} requests 既有申請
 * @param {string} now 時間
 * @return {Array<{id: string, patch: Object}>}
 */
function planBookingSync(before, after, requests, now) {
  const patches = [];
  if (!after) {
    return patches;
  }
  const beforeRoom = String((before && before.roomId) || "").trim();
  const afterRoom = String(after.roomId || "").trim();
  const roomChanged = Boolean(beforeRoom) && beforeRoom !== afterRoom;
  const ended = !cameraServiceOpen(after);
  const list = Array.isArray(requests) ? requests : [];
  for (const request of list) {
    if (!request || String(request.status || "") === STATUS_CLOSED) {
      continue;
    }
    const requestRoom = String(request.roomId || "").trim();
    let reason = "";
    if (String(after.status || "").trim() === "cancelled") {
      reason = "cancelled";
    } else if (roomChanged && requestRoom && requestRoom !== afterRoom) {
      reason = "room_changed";
    } else if (ended) {
      reason = isDaycareBooking(after) ? "daycare_ended" : "stay_ended";
    }
    if (!reason) {
      continue;
    }
    const write = commitSyncWrite(request, reason, now);
    if (write) {
      patches.push({id: request.id, patch: write});
    }
  }
  return patches;
}

/**
 * @param {*} device 設備，需含 id
 * @param {boolean} cameraOn 店家總開關
 * @param {Array<Object>} requests 申請
 * @param {string} now 時間
 * @return {Array<{id: string, patch: Object}>}
 */
function planDeviceSync(device, cameraOn, requests, now) {
  const patches = [];
  const list = Array.isArray(requests) ? requests : [];
  for (const request of list) {
    const deviceId = String((device && device.id) || "").trim();
    if (deviceId && String(request.deviceId || "") !== deviceId) {
      continue;
    }
    const reason = requestSyncReason(request, {
      device,
      shopCameraOn: cameraOn,
    });
    const write = commitSyncWrite(request, reason, now);
    if (write) {
      patches.push({id: request.id, patch: write});
    }
  }
  return patches;
}

/**
 * @param {Array<Object>} requests 申請
 * @param {string} now 時間
 * @return {Array<{id: string, patch: Object}>}
 */
function planShopCameraOff(requests, now) {
  const patches = [];
  const list = Array.isArray(requests) ? requests : [];
  for (const request of list) {
    const write = commitSyncWrite(request, "shop_camera_off", now);
    if (write) {
      patches.push({id: request.id, patch: write});
    }
  }
  return patches;
}

/**
 * @param {*} current 目前有效申請
 * @param {string} account 新帳號
 * @param {string} deviceId 目前設備
 * @return {{type: string, reason: string}}
 */
function planCustomerSubmit(current, account, deviceId) {
  if (!current) {
    return {type: "create", reason: ""};
  }
  const status = String(current.status || "");
  if (status === STATUS_CLOSED || status === STATUS_REVOCATION) {
    return {type: "create", reason: ""};
  }
  const currentDevice = String(current.deviceId || "").trim();
  if (currentDevice && deviceId && currentDevice !== deviceId) {
    if (invitationWasSent(current)) {
      return {type: "replace", reason: "device_changed"};
    }
    return {type: "retarget", reason: ""};
  }
  const same = String(current.externalAccount || "").trim() === account;
  if (status === STATUS_PENDING) {
    return {type: same ? "noop" : "update", reason: ""};
  }
  if (status === STATUS_NEEDS_INFO) {
    return {type: "update", reason: ""};
  }
  if (status === STATUS_INVITED || status === STATUS_CONFIRMED) {
    return {
      type: same ? "noop" : "replace",
      reason: same ? "" : "account_changed",
    };
  }
  return {type: "create", reason: ""};
}

/**
 * 顧客不能自行標記店家處理狀態。
 * @param {string} action 操作
 * @return {boolean}
 */
function customerActionForbidden(action) {
  return action === "mark_invited" ||
    action === "needs_info" ||
    action === "mark_revoked";
}

/**
 * @param {*} request 申請
 * @return {{ok: boolean, message: string, unchanged: boolean}}
 */
function planCustomerConfirm(request) {
  const status = String((request && request.status) || "");
  if (status === STATUS_CONFIRMED) {
    return {ok: true, message: "", unchanged: true};
  }
  if (status !== STATUS_INVITED) {
    return {
      ok: false,
      message: "店家尚未記錄已發送邀請，還不能按已可觀看",
      unchanged: false,
    };
  }
  return {ok: true, message: "", unchanged: false};
}

/**
 * @param {*} request 申請
 * @param {string} action 店家操作
 * @param {string} reason 補充說明
 * @return {{ok: boolean, message: string, status: string, closeReason: string}}
 */
function planShopAction(request, action, reason) {
  const status = String((request && request.status) || "");
  const note = String(reason || "").trim();
  if (action === "mark_invited") {
    if (status !== STATUS_PENDING && status !== STATUS_NEEDS_INFO) {
      return failShop("此申請目前不能標記為已發送邀請");
    }
    return {ok: true, message: "", status: STATUS_INVITED, closeReason: ""};
  }
  if (action === "needs_info") {
    if (!note) {
      return failShop("請填寫需要顧客補充的說明");
    }
    if (status !== STATUS_PENDING && status !== STATUS_NEEDS_INFO) {
      return failShop("此申請目前不能要求補充資料");
    }
    return {ok: true, message: "", status: STATUS_NEEDS_INFO, closeReason: ""};
  }
  if (action === "mark_revoked") {
    if (status === STATUS_CLOSED) {
      return failShop("此申請已結束");
    }
    if (!invitationWasSent(request)) {
      return failShop("尚未發送邀請，不需要取消分享");
    }
    if (status !== STATUS_INVITED &&
        status !== STATUS_CONFIRMED &&
        status !== STATUS_REVOCATION) {
      return failShop("此申請目前不能確認取消分享");
    }
    return {
      ok: true,
      message: "",
      status: STATUS_CLOSED,
      closeReason: "share_removed",
    };
  }
  return failShop("不支援的操作");
}

/**
 * @param {string} message 錯誤
 * @return {{ok: boolean, message: string, status: string, closeReason: string}}
 */
function failShop(message) {
  return {ok: false, message, status: "", closeReason: ""};
}

/**
 * 米家帳號可為手機、Email 或小米帳號，不限定 Email，也不宣稱所有型號相同。
 * @param {*} raw 帳號
 * @return {boolean}
 */
function plausibleMiHomeAccount(raw) {
  return brands.plausibleXiaomiAccount(raw);
}

/**
 * 依最新申請與最新訂單／設備決定同步原因。空字串代表不需變更。
 * @param {*} request 申請
 * @param {Object} context 最新資料
 * @return {string}
 */
function requestSyncReason(request, context) {
  const booking = context && context.booking;
  const device = context && context.device;
  const cameraOn = !context || context.shopCameraOn !== false;
  if (booking) {
    if (String(booking.status || "").trim() === "cancelled") {
      return "cancelled";
    }
    const afterRoom = String(booking.roomId || "").trim();
    const requestRoom = String((request && request.roomId) || "").trim();
    if (requestRoom && afterRoom && requestRoom !== afterRoom) {
      return "room_changed";
    }
    if (!cameraServiceOpen(booking)) {
      return isDaycareBooking(booking) ? "daycare_ended" : "stay_ended";
    }
  }
  if (device) {
    const deviceRoom = String(device.roomId || "").trim();
    const requestRoom = String((request && request.roomId) || "").trim();
    if (deviceRoom && requestRoom && deviceRoom !== requestRoom) {
      return "device_moved";
    }
    const shareable = cameraOn &&
      customerCanWatchDevice(device, true) &&
      viewModeOf(device) === VIEW_EXTERNAL &&
      brands.brandSupportsAccountShare(device.provider);
    if (!shareable) {
      if (!cameraOn) {
        return "shop_camera_off";
      }
      if (device.platformLocked === true) {
        return "platform_locked";
      }
      if (device.enabled !== true) {
        return "device_disabled";
      }
      if (viewModeOf(device) !== VIEW_EXTERNAL) {
        return "view_mode_changed";
      }
      return "unsupported_brand";
    }
  }
  if (context && context.shopCameraOn === false) {
    return "shop_camera_off";
  }
  return "";
}

/**
 * 已結束不可改回待取消。既有取消／結束時間不覆蓋。
 * @param {*} latest 最新申請
 * @param {string} reason 原因
 * @param {string} now 時間
 * @return {Object|null}
 */
function commitSyncWrite(latest, reason, now) {
  if (!latest || !reason || String(latest.status || "") === STATUS_CLOSED) {
    return null;
  }
  const patch = stopSharingPatch(latest, reason, now);
  if (!patch) {
    return null;
  }
  const write = {status: patch.status, updatedAt: now};
  if (patch.status === STATUS_REVOCATION) {
    if (!hasValue(latest.revocationReason)) {
      write.revocationReason = reason;
    }
    if (!hasValue(latest.revocationRequestedAt)) {
      write.revocationRequestedAt = now;
    }
  }
  if (patch.status === STATUS_CLOSED) {
    if (!hasValue(latest.closeReason)) {
      write.closeReason = patch.closeReason || reason;
    }
    if (!hasValue(latest.closedAt)) {
      write.closedAt = now;
    }
  }
  return write;
}

/**
 * 顧客可見欄位。不包含店內備註 note。
 * @param {*} device 設備
 * @param {*} booking 訂單
 * @return {Object}
 */
function customerCameraView(device, booking) {
  const mode = viewModeOf(device);
  const daycare = isDaycareBooking(booking);
  const provider = mode === VIEW_EXTERNAL ?
    String((device && device.provider) || "").trim() : "";
  const brand = brands.brandById(provider);
  const view = {
    viewMode: mode,
    name: String((device && device.name) || "房間攝影機"),
    provider,
    providerLabel: brand ? brand.label : (provider ? "不支援的品牌" : ""),
    appName: brand ? brand.appName : "",
    customerShareNote: mode === VIEW_EXTERNAL ?
      String((device && device.customerShareNote) || "") : "",
    deviceId: String((device && device.id) || ""),
    roomId: String((booking && booking.roomId) || ""),
    roomName: String(
        (booking && booking.roomName) ||
        (device && device.roomName) ||
        "",
    ),
    bookingKind: daycare ? "daycare" : "accommodation",
    bookingKindLabel: daycare ? "安親" : "住宿",
  };
  if (mode === VIEW_WEB) {
    view.url = String((device && device.url) || "").trim();
  }
  return view;
}

/**
 * 房間訊號只回傳房間文件 ID。移房同時包含原房與新房。
 * @param {Object|null} before 寫入前的設備
 * @param {Object|null} after 寫入後的設備
 * @return {Array<string>}
 */
function cameraSignalRoomIds(before, after) {
  const ids = [];
  const rows = [before, after];
  for (const data of rows) {
    if (!data || String(data.type || "") !== "camera") {
      continue;
    }
    const roomId = String(data.roomId || "").trim();
    if (roomId && !ids.includes(roomId)) {
      ids.push(roomId);
    }
  }
  return ids;
}

module.exports = {
  VIEW_WEB,
  VIEW_EXTERNAL,
  PROVIDER_XIAOMI,
  STATUS_PENDING,
  STATUS_NEEDS_INFO,
  STATUS_INVITED,
  STATUS_CONFIRMED,
  STATUS_REVOCATION,
  STATUS_CLOSED,
  viewModeOf,
  isDirectHttps,
  cameraSetupComplete,
  isDaycareBooking,
  cameraServiceOpen,
  shopCameraOn,
  customerCanWatchDevice,
  invitationWasSent,
  stopSharingPatch,
  planBookingSync,
  planDeviceSync,
  planShopCameraOff,
  planCustomerSubmit,
  customerActionForbidden,
  planCustomerConfirm,
  planShopAction,
  plausibleMiHomeAccount,
  requestSyncReason,
  commitSyncWrite,
  customerCameraView,
  cameraSignalRoomIds,
};
