// 檔案名稱：functions/cameras/camera_access_callables.js
// 功能說明：顧客讀取自己房間的攝影機，以及米家分享申請的建立與狀態更新。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  hasShopPermission,
  normalizeString,
  toDate,
} = require("../daycare/daycare_utils");
const policy = require("./camera_access_policy");
const brands = require("./camera_brands");

const region = "asia-east1";

/**
 * @param {*} value 時間欄位
 * @return {string}
 */
function formatDateLabel(value) {
  const date = toDate(value);
  if (!date) {
    const text = normalizeString(value);
    return text.length >= 10 ? text.slice(0, 10) : text;
  }
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

/**
 * @param {*} booking 訂單
 * @return {string}
 */
function servicePeriodLabel(booking) {
  if (policy.isDaycareBooking(booking)) {
    const start = formatDateLabel(
        booking.actualStartAt || booking.scheduledStartAt,
    );
    const end = formatDateLabel(
        booking.actualEndAt || booking.scheduledEndAt,
    );
    return [start, end].filter(Boolean).join(" – ");
  }
  const start = formatDateLabel(booking.startDate);
  const end = formatDateLabel(booking.endDate);
  return [start, end].filter(Boolean).join(" – ");
}

/**
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} docs 設備
 * @param {boolean} cameraOn 總開關
 * @return {Object|null}
 */
function pickShareDevice(docs, cameraOn) {
  const ready = [];
  docs.forEach((doc) => {
    const data = {id: doc.id, ...(doc.data() || {})};
    if (policy.customerCanWatchDevice(data, cameraOn) &&
        policy.viewModeOf(data) === policy.VIEW_EXTERNAL &&
        brands.brandSupportsAccountShare(data.provider) &&
        normalizeString(data.roomId)) {
      ready.push(data);
    }
  });
  ready.sort((left, right) => {
    const leftTime = toDate(left.updatedAt);
    const rightTime = toDate(right.updatedAt);
    if (leftTime && rightTime) {
      return rightTime.getTime() - leftTime.getTime();
    }
    return 0;
  });
  return ready[0] || null;
}

/**
 * @param {string} shopId 店家
 * @param {string} roomId 房間
 * @return {Promise<Object|null>}
 */
async function loadReadyDevice(shopId, roomId) {
  const snap = await admin.firestore()
      .collection("shops")
      .doc(shopId)
      .collection("devices")
      .where("roomId", "==", roomId)
      .get();
  const ready = [];
  snap.forEach((doc) => {
    const data = {id: doc.id, ...(doc.data() || {})};
    if (policy.customerCanWatchDevice(data, true)) {
      ready.push(data);
    }
  });
  ready.sort((a, b) => {
    const left = toDate(a.updatedAt);
    const right = toDate(b.updatedAt);
    if (left && right) {
      return right.getTime() - left.getTime();
    }
    return 0;
  });
  return ready[0] || null;
}

/**
 * 已啟用的外部設備，但品牌未開放。不當成小米。
 * @param {string} shopId 店家
 * @param {string} roomId 房間
 * @return {Promise<boolean>}
 */
async function roomHasUnsupportedExternal(shopId, roomId) {
  const snap = await admin.firestore()
      .collection("shops")
      .doc(shopId)
      .collection("devices")
      .where("roomId", "==", roomId)
      .get();
  return snap.docs.some((doc) => {
    const data = {id: doc.id, ...(doc.data() || {})};
    return data.enabled === true &&
      data.platformLocked !== true &&
      policy.viewModeOf(data) === policy.VIEW_EXTERNAL &&
      !brands.brandSupportsAccountShare(data.provider);
  });
}

/**
 * @param {FirebaseFirestore.DocumentSnapshot} bookingSnap 訂單
 * @param {string} uid 登入者
 * @return {Object}
 */
function requireOwnedBooking(bookingSnap, uid) {
  if (!bookingSnap.exists) {
    throw new HttpsError("not-found", "找不到這筆訂單");
  }
  const booking = bookingSnap.data() || {};
  if (normalizeString(booking.userId) !== uid) {
    throw new HttpsError("permission-denied", "只能查看自己的訂單攝影機");
  }
  const shopId = normalizeString(booking.shopId);
  if (!shopId) {
    throw new HttpsError("failed-precondition", "訂單缺少店家資料");
  }
  return booking;
}

/**
 * @param {string} uid 登入者
 * @param {string} shopId 店家
 * @return {Promise<void>}
 */
async function requireCameraManager(uid, shopId) {
  const allowed = await hasShopPermission(shopId, uid, "manage_devices");
  if (!allowed) {
    throw new HttpsError("permission-denied", "沒有管理攝影機的權限");
  }
}

/**
 * @param {string} shopId 店家
 * @return {FirebaseFirestore.CollectionReference}
 */
function requestCollection(shopId) {
  return admin.firestore()
      .collection("shops")
      .doc(shopId)
      .collection("camera_access_requests");
}

/**
 * @param {string} shopId 店家
 * @param {string} bookingId 訂單
 * @param {string} roomId 房間
 * @return {FirebaseFirestore.DocumentReference}
 */
function slotRef(shopId, bookingId, roomId) {
  return admin.firestore()
      .collection("shops")
      .doc(shopId)
      .collection("camera_access_slots")
      .doc(`${bookingId}_${roomId}`);
}

exports.getCustomerRoomCamera = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const bookingId = normalizeString((request.data || {}).bookingId);
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "缺少訂單");
  }
  const bookingSnap = await admin.firestore()
      .collection("bookings")
      .doc(bookingId)
      .get();
  const booking = requireOwnedBooking(bookingSnap, request.auth.uid);
  const shopId = normalizeString(booking.shopId);
  if (!policy.cameraServiceOpen(booking)) {
    return {visibility: "hidden"};
  }
  const shopSnap = await admin.firestore()
      .collection("shops").doc(shopId).get();
  const shop = shopSnap.data() || {};
  if (!policy.shopCameraOn(shop)) {
    return {visibility: "hidden"};
  }
  const roomId = normalizeString(booking.roomId);
  const device = await loadReadyDevice(shopId, roomId);
  if (!device) {
    if (await roomHasUnsupportedExternal(shopId, roomId)) {
      return {
        visibility: "unsupported",
        message: "此房間的外部攝影機品牌尚未開放",
      };
    }
    return {visibility: "hidden"};
  }
  const camera = policy.customerCameraView(device, booking);
  camera.shopId = shopId;
  camera.servicePeriodLabel = servicePeriodLabel(booking);
  camera.customerName = normalizeString(booking.customerName);
  return {visibility: "ready", camera};
});

exports.submitCameraAccessRequest = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const data = request.data || {};
  const bookingId = normalizeString(data.bookingId);
  const account = normalizeString(data.externalAccount);
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "缺少訂單");
  }
  if (!account) {
    throw new HttpsError("invalid-argument", "請填寫分享帳號");
  }
  const uid = request.auth.uid;
  const firestore = admin.firestore();
  const bookingRef = firestore.collection("bookings").doc(bookingId);
  const previewSnap = await bookingRef.get();
  const preview = requireOwnedBooking(previewSnap, uid);
  const shopId = normalizeString(preview.shopId);
  const requests = requestCollection(shopId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const nowLabel = new Date().toISOString();
  return firestore.runTransaction(async (transaction) => {
    const liveBookingSnap = await transaction.get(bookingRef);
    const liveBooking = liveBookingSnap.data() || {};
    if (normalizeString(liveBooking.userId) !== uid) {
      throw new HttpsError("permission-denied", "只能為自己的訂單申請");
    }
    if (normalizeString(liveBooking.shopId) !== shopId ||
        !policy.cameraServiceOpen(liveBooking)) {
      throw new HttpsError(
          "failed-precondition",
          "訂單狀態已變更，請重新開啟後再試",
      );
    }
    const roomId = normalizeString(liveBooking.roomId);
    const shopSnap = await transaction.get(
        firestore.collection("shops").doc(shopId),
    );
    const deviceSnap = await transaction.get(
        firestore.collection("shops").doc(shopId).collection("devices")
            .where("roomId", "==", roomId),
    );
    const slot = slotRef(shopId, bookingId, roomId);
    const liveSlot = await transaction.get(slot);
    const cameraOn = policy.shopCameraOn(shopSnap.data() || {});
    const device = pickShareDevice(deviceSnap.docs, cameraOn);
    if (!cameraOn || !device) {
      throw new HttpsError(
          "failed-precondition",
          "此房間目前沒有可申請的外部攝影機",
      );
    }
    if (normalizeString(device.roomId) !== roomId ||
        !brands.brandSupportsAccountShare(device.provider)) {
      throw new HttpsError(
          "failed-precondition",
          "此房間的外部攝影機品牌未開放或不在目前房間",
      );
    }
    if (!brands.plausibleBrandAccount(device.provider, account)) {
      const brand = brands.brandById(device.provider);
      throw new HttpsError(
          "invalid-argument",
          (brand && brand.accountHint) || "分享帳號格式不正確",
      );
    }
    const currentId = liveSlot.exists ?
      normalizeString((liveSlot.data() || {}).currentRequestId) : "";
    let currentSnap = null;
    if (currentId) {
      currentSnap = await transaction.get(requests.doc(currentId));
    }
    const loaded = currentSnap && currentSnap.exists ?
      {id: currentSnap.id, ...(currentSnap.data() || {})} : null;
    const current = loaded && normalizeString(loaded.userId) === uid ?
      loaded : null;
    const decision = policy.planCustomerSubmit(current, account, device.id);
    if (decision.type === "noop" && current) {
      return {
        requestId: current.id,
        status: current.status,
        duplicated: true,
      };
    }
    if (decision.type === "update" || decision.type === "retarget") {
      const update = {
        externalAccount: account,
        deviceId: device.id,
        roomId,
        status: policy.STATUS_PENDING,
        needsInfoReason: "",
        provider: normalizeString(device.provider),
        updatedAt: now,
      };
      if (current &&
          current.status === policy.STATUS_NEEDS_INFO &&
          normalizeString(current.needsInfoReason)) {
        update.needsInfoLog = admin.firestore.FieldValue.arrayUnion(
            normalizeString(current.needsInfoReason),
        );
      }
      transaction.update(requests.doc(current.id), update);
      transaction.set(slot, {
        currentRequestId: current.id,
        userId: uid,
        bookingId,
        roomId,
        deviceId: device.id,
        updatedAt: now,
      }, {merge: true});
      return {requestId: current.id, status: policy.STATUS_PENDING};
    }
    if (decision.type === "replace" && current) {
      const patch = policy.commitSyncWrite(
          current,
          decision.reason || "account_changed",
          nowLabel,
      );
      if (patch) {
        transaction.set(requests.doc(current.id), {
          status: patch.status,
          revocationReason: patch.revocationReason ||
            decision.reason || "account_changed",
          revocationRequestedAt: current.revocationRequestedAt || now,
          updatedAt: now,
        }, {merge: true});
      }
    }
    const created = requests.doc();
    transaction.set(created, requestPayload({
      booking: liveBooking,
      bookingId,
      uid,
      shopId,
      roomId,
      device,
      account,
      now,
    }));
    transaction.set(slot, {
      currentRequestId: created.id,
      userId: uid,
      bookingId,
      roomId,
      deviceId: device.id,
      updatedAt: now,
    });
    return {requestId: created.id, status: policy.STATUS_PENDING};
  });
});

/**
 * @param {Object} params 新申請
 * @return {Object}
 */
function requestPayload(params) {
  const booking = params.booking;
  const daycare = policy.isDaycareBooking(booking);
  return {
    bookingId: params.bookingId,
    userId: params.uid,
    shopId: params.shopId,
    roomId: params.roomId,
    deviceId: params.device.id,
    provider: normalizeString(params.device.provider),
    externalAccount: params.account,
    status: policy.STATUS_PENDING,
    needsInfoReason: "",
    customerName: normalizeString(booking.customerName),
    roomName: normalizeString(booking.roomName) ||
      normalizeString(params.device.roomName),
    bookingKind: daycare ? "daycare" : "accommodation",
    bookingKindLabel: daycare ? "安親" : "住宿",
    servicePeriodLabel: servicePeriodLabel(booking),
    createdAt: params.now,
    updatedAt: params.now,
  };
}

exports.confirmCustomerCameraWatching = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const data = request.data || {};
  const shopId = normalizeString(data.shopId);
  const requestId = normalizeString(data.requestId);
  if (!shopId || !requestId) {
    throw new HttpsError("invalid-argument", "缺少申請資料");
  }
  const ref = requestCollection(shopId).doc(requestId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  return admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "找不到分享申請");
    }
    const current = snap.data() || {};
    if (normalizeString(current.userId) !== request.auth.uid) {
      throw new HttpsError("permission-denied", "只能確認自己的申請");
    }
    const decision = policy.planCustomerConfirm(current);
    if (!decision.ok) {
      throw new HttpsError("failed-precondition", decision.message);
    }
    const bookingSnap = await transaction.get(
        admin.firestore().collection("bookings")
            .doc(normalizeString(current.bookingId)),
    );
    const deviceSnap = await transaction.get(
        admin.firestore().collection("shops").doc(shopId)
            .collection("devices")
            .doc(normalizeString(current.deviceId)),
    );
    const shopSnap = await transaction.get(
        admin.firestore().collection("shops").doc(shopId),
    );
    const booking = bookingSnap.data() || {};
    const device = {id: deviceSnap.id, ...(deviceSnap.data() || {})};
    const cameraOn = policy.shopCameraOn(shopSnap.data() || {});
    if (normalizeString(booking.userId) !==
            normalizeString(current.userId) ||
        normalizeString(booking.shopId) !== shopId ||
        normalizeString(booking.roomId) !==
            normalizeString(current.roomId) ||
        normalizeString(device.roomId) !==
            normalizeString(current.roomId) ||
        !policy.cameraServiceOpen(booking) ||
        !policy.customerCanWatchDevice(device, cameraOn) ||
        policy.viewModeOf(device) !== policy.VIEW_EXTERNAL ||
        !brands.brandSupportsAccountShare(device.provider)) {
      throw new HttpsError(
          "failed-precondition",
          "訂單、房間或設備已變更，不能確認可觀看",
      );
    }
    if (decision.unchanged) {
      return {requestId, status: policy.STATUS_CONFIRMED};
    }
    transaction.update(ref, {
      status: policy.STATUS_CONFIRMED,
      customerConfirmedAt: now,
      updatedAt: now,
    });
    return {requestId, status: policy.STATUS_CONFIRMED};
  });
});

exports.updateCameraAccessRequest = onCall({region}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const data = request.data || {};
  const shopId = normalizeString(data.shopId);
  const requestId = normalizeString(data.requestId);
  const action = normalizeString(data.action);
  const reason = normalizeString(data.reason);
  if (!shopId || !requestId || !action) {
    throw new HttpsError("invalid-argument", "缺少處理資料");
  }
  if (action !== "mark_invited" &&
      action !== "needs_info" &&
      action !== "mark_revoked") {
    throw new HttpsError("invalid-argument", "不支援的操作");
  }
  await requireCameraManager(request.auth.uid, shopId);
  const ref = requestCollection(shopId).doc(requestId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  return admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "找不到分享申請");
    }
    const current = snap.data() || {};
    if (normalizeString(current.shopId) !== shopId) {
      throw new HttpsError("permission-denied", "不能處理其他店家的申請");
    }
    if (action !== "mark_revoked") {
      const bookingSnap = await transaction.get(
          admin.firestore().collection("bookings")
              .doc(normalizeString(current.bookingId)),
      );
      const deviceSnap = await transaction.get(
          admin.firestore().collection("shops").doc(shopId)
              .collection("devices")
              .doc(normalizeString(current.deviceId)),
      );
      const shopSnap = await transaction.get(
          admin.firestore().collection("shops").doc(shopId),
      );
      const booking = bookingSnap.data() || {};
      const device = {
        id: deviceSnap.id,
        ...(deviceSnap.data() || {}),
      };
      if (normalizeString(booking.userId) !==
              normalizeString(current.userId) ||
          normalizeString(booking.shopId) !== shopId ||
          normalizeString(booking.roomId) !==
              normalizeString(current.roomId) ||
          normalizeString(device.roomId) !==
              normalizeString(current.roomId) ||
          !policy.cameraServiceOpen(booking) ||
          !policy.customerCanWatchDevice(
              device,
              policy.shopCameraOn(shopSnap.data() || {}),
          ) ||
          policy.viewModeOf(device) !== policy.VIEW_EXTERNAL ||
          !brands.brandSupportsAccountShare(device.provider)) {
        throw new HttpsError(
            "failed-precondition",
            "訂單已換房、退房或設備已失效，不能再處理舊房的新分享",
        );
      }
    }
    const decision = policy.planShopAction(current, action, reason);
    if (!decision.ok) {
      throw new HttpsError("failed-precondition", decision.message);
    }
    const patch = {
      status: decision.status,
      updatedAt: now,
    };
    if (action === "mark_invited") {
      patch.invitedAt = current.invitedAt || now;
      patch.invitedBy = request.auth.uid;
      patch.needsInfoReason = "";
    }
    if (action === "needs_info") {
      patch.needsInfoReason = reason;
    }
    if (action === "mark_revoked") {
      patch.revokedAt = now;
      patch.revokedBy = request.auth.uid;
      patch.closedAt = now;
      patch.closedBy = request.auth.uid;
      patch.closeReason = decision.closeReason;
    }
    transaction.update(ref, patch);
    return {requestId, status: decision.status};
  });
});
