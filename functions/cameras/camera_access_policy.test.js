// 檔案名稱：functions/cameras/camera_access_policy.test.js
// 功能說明：攝影機模式、服務期間與米家申請狀態轉換。

const test = require("node:test");
const assert = require("node:assert/strict");
const policy = require("./camera_access_policy");

test("舊網址設備沒有新欄位仍可視為網址模式", () => {
  const device = {type: "camera", url: "https://cam.example/live"};
  assert.equal(policy.viewModeOf(device), "web_url");
  assert.equal(policy.cameraSetupComplete(device), true);
  const view = policy.customerCameraView(device, {
    roomId: "r1",
    roomName: "A1",
  });
  assert.equal(view.url, "https://cam.example/live");
  assert.equal(view.note, undefined);
});

test("米家設備沒有網址仍可完成設定", () => {
  const device = {
    type: "camera",
    viewMode: "external_app",
    provider: "xiaomi",
    url: "",
    note: "店內密碼不要外流",
    customerShareNote: "請使用台灣區米家",
  };
  assert.equal(policy.cameraSetupComplete(device), true);
  const view = policy.customerCameraView(device, {roomId: "r1"});
  assert.equal(view.url, undefined);
  assert.equal(view.customerShareNote, "請使用台灣區米家");
  assert.equal(view.note, undefined);
});

test("只有訂單本人的服務中房間可看，結束與鎖定不可新申請", () => {
  assert.equal(policy.cameraServiceOpen({
    status: "checked_in",
    roomId: "r1",
    bookingKind: "accommodation",
  }), true);
  assert.equal(policy.cameraServiceOpen({
    status: "checked_in",
    roomId: "r1",
    checkOutAt: "2026-10-02",
  }), false);
  assert.equal(policy.cameraServiceOpen({
    status: "checked_in",
    roomId: "r1",
    bookingKind: "daycare",
    scheduledEndAt: "2026-10-02",
  }), true);
  assert.equal(policy.cameraServiceOpen({
    status: "checked_in",
    roomId: "r1",
    bookingKind: "daycare",
    actualEndAt: "2026-10-02T10:00:00Z",
  }), false);
  const locked = {
    id: "d1",
    type: "camera",
    viewMode: "external_app",
    provider: "xiaomi",
    enabled: true,
    platformLocked: true,
  };
  assert.equal(policy.customerCanWatchDevice(locked, true), false);
  const off = {...locked, platformLocked: false, enabled: false};
  assert.equal(policy.customerCanWatchDevice(off, true), false);
});

test("重複提交同一待處理申請不會新增，邀請後換帳號保留取消待辦", () => {
  const pending = {
    id: "a",
    status: "pending",
    deviceId: "d1",
    externalAccount: "0912000111",
  };
  assert.equal(
      policy.planCustomerSubmit(pending, "0912000111", "d1").type,
      "noop",
  );
  assert.equal(
      policy.planCustomerSubmit(pending, "0912000222", "d1").type,
      "update",
  );
  const invited = {
    id: "b",
    status: "invited",
    deviceId: "d1",
    externalAccount: "old@example.com",
    invitedAt: "t",
  };
  const replaced = policy.planCustomerSubmit(
      invited, "new@example.com", "d1",
  );
  assert.equal(replaced.type, "replace");
  const patch = policy.stopSharingPatch(invited, "account_changed", "now");
  assert.equal(patch.status, "revocation_pending");
  const again = policy.stopSharingPatch(
      {...invited, ...patch}, "account_changed", "later",
  );
  assert.equal(again, null);
});

test("顧客不能標記店家狀態，退房換房保留已分享待辦", () => {
  assert.equal(policy.customerActionForbidden("mark_invited"), true);
  assert.equal(policy.customerActionForbidden("mark_revoked"), true);
  assert.equal(policy.planCustomerConfirm({status: "pending"}).ok, false);
  const invited = {
    id: "r1",
    status: "invited",
    roomId: "old",
    invitedAt: "t",
  };
  const pending = {id: "r2", status: "pending", roomId: "old"};
  const roomChange = policy.planBookingSync(
      {roomId: "old", status: "checked_in"},
      {roomId: "new", status: "checked_in"},
      [invited, pending],
      "now",
  );
  assert.equal(roomChange[0].patch.status, "revocation_pending");
  assert.equal(roomChange[1].patch.status, "closed");
  assert.equal(roomChange[1].patch.revocationRequestedAt, undefined);
  const checkout = policy.planBookingSync(
      {roomId: "old", status: "checked_in"},
      {roomId: "old", status: "checked_out", checkOutAt: "t"},
      [invited],
      "now",
  );
  assert.equal(checkout[0].patch.status, "revocation_pending");
  const daycareEnd = policy.planBookingSync(
      {roomId: "a", status: "checked_in", bookingKind: "daycare"},
      {
        roomId: "a",
        status: "checked_in",
        bookingKind: "daycare",
        actualEndAt: "t",
      },
      [invited],
      "now",
  );
  assert.equal(daycareEnd[0].patch.revocationReason, "daycare_ended");
});

test("設備停用與平台鎖定阻止觀看並保留已分享待辦", () => {
  const shared = {id: "s", status: "customer_confirmed", deviceId: "d1", invitedAt: "t"};
  const fresh = {id: "f", status: "pending", deviceId: "d1"};
  const locked = policy.planDeviceSync({
    id: "d1",
    type: "camera",
    viewMode: "external_app",
    provider: "xiaomi",
    enabled: true,
    platformLocked: true,
  }, true, [shared, fresh], "now");
  assert.equal(locked[0].patch.status, "revocation_pending");
  assert.equal(locked[0].patch.revocationReason, "platform_locked");
  assert.equal(locked[1].patch.status, "closed");
  const shop = policy.planShopAction(shared, "mark_revoked", "");
  assert.equal(shop.status, "closed");
  assert.equal(policy.planShopAction(fresh, "mark_revoked", "").ok, false);
  assert.equal(policy.plausibleMiHomeAccount("user@example.com"), true);
  assert.equal(policy.plausibleMiHomeAccount("0912345678"), true);
  assert.equal(policy.plausibleMiHomeAccount("not an email only rule"), false);
});

test("需補資料即使帳號相同也回到待處理，待處理同帳號仍去重", () => {
  const needs = {
    id: "n",
    status: "needs_info",
    deviceId: "d1",
    externalAccount: "0912000111",
    needsInfoReason: "帳號打錯",
  };
  assert.equal(policy.planCustomerSubmit(needs, "0912000111", "d1").type, "update");
  const pending = {
    id: "p",
    status: "pending",
    deviceId: "d1",
    externalAccount: "0912000111",
  };
  assert.equal(policy.planCustomerSubmit(pending, "0912000111", "d1").type, "noop");
});

test("未知品牌不當成小米，設備移房會結束或待取消", () => {
  const tapo = {
    type: "camera",
    viewMode: "external_app",
    provider: "tapo",
    enabled: true,
  };
  assert.equal(policy.cameraSetupComplete(tapo), false);
  const view = policy.customerCameraView(tapo, {roomId: "r1"});
  assert.equal(view.provider, "tapo");
  assert.notEqual(view.provider, "xiaomi");
  assert.equal(view.providerLabel, "不支援的品牌");
  const device = {
    id: "d1",
    type: "camera",
    viewMode: "external_app",
    provider: "xiaomi",
    enabled: true,
    roomId: "new",
  };
  const invited = {
    id: "a",
    status: "invited",
    deviceId: "d1",
    roomId: "old",
    invitedAt: "t",
  };
  const fresh = {id: "b", status: "pending", deviceId: "d1", roomId: "old"};
  const moved = policy.planDeviceSync(device, true, [invited, fresh], "now");
  assert.equal(moved[0].patch.status, "revocation_pending");
  assert.equal(moved[0].patch.revocationReason, "device_moved");
  assert.equal(moved[1].patch.status, "closed");
});

test("已結束不會被同步改回待取消，邀請後退房保留取消待辦", () => {
  const closed = {
    status: "closed",
    closeReason: "share_removed",
    closedAt: "kept",
  };
  assert.equal(policy.commitSyncWrite(closed, "stay_ended", "later"), null);
  const already = {
    status: "revocation_pending",
    revocationRequestedAt: "kept",
    revocationReason: "stay_ended",
    invitedAt: "t",
  };
  assert.equal(policy.commitSyncWrite(already, "stay_ended", "later"), null);
  const invited = {status: "invited", invitedAt: "t", roomId: "r1"};
  const reason = policy.requestSyncReason(invited, {
    booking: {status: "checked_out", roomId: "r1", checkOutAt: "t"},
  });
  const write = policy.commitSyncWrite(invited, reason, "now");
  assert.equal(write.status, "revocation_pending");
  const again = policy.commitSyncWrite(
      {...invited, status: "revocation_pending", revocationRequestedAt: "kept"},
      reason,
      "later",
  );
  assert.equal(again, null);
});

test("房間訊號只含房間文件 ID，移房會通知原房與新房", () => {
  assert.deepEqual(policy.cameraSignalRoomIds(null, {
    type: "camera",
    roomId: "room-a",
    url: "https://cam.example/secret",
    note: "帳號不要外流",
  }), ["room-a"]);
  assert.deepEqual(policy.cameraSignalRoomIds(
      {type: "camera", roomId: "room-a"},
      {type: "camera", roomId: "room-b", url: "https://cam.example/new"},
  ), ["room-a", "room-b"]);
  assert.deepEqual(policy.cameraSignalRoomIds(
      {type: "camera", roomId: "room-a"},
      null,
  ), ["room-a"]);
  assert.deepEqual(policy.cameraSignalRoomIds(
      {type: "lock", roomId: "room-a"},
      {type: "camera", roomId: "room-a"},
  ), ["room-a"]);
  assert.deepEqual(policy.cameraSignalRoomIds(
      {type: "feeder", roomId: "room-a"},
      {type: "feeder", roomId: "room-b"},
  ), []);
});
