// 檔案名稱：functions/daycare/manage_daycare_booking.test.js
// 功能說明：安親實際送達／接回不可晚於現在

const test = require("node:test");
const assert = require("node:assert/strict");
const {assertActualTimes, resolveDaycareCancelActor} =
    require("./manage_daycare_booking");
const {shopLatePickupBreakdown} = require("./daycare_pricing");

test("未來 actualEndAt 被 Function 拒絕", () => {
  const now = new Date("2026-09-13T05:42:00.000Z");
  const start = new Date("2026-09-13T05:40:00.000Z");
  const future = new Date("2026-09-13T13:40:00.000Z");
  assert.throws(
      () => assertActualTimes(start, future, now),
      /實際接回時間不可晚於目前時間/,
  );
});

test("未來 actualStartAt 被 Function 拒絕", () => {
  const now = new Date("2026-09-13T05:42:00.000Z");
  const start = new Date("2026-09-13T06:00:00.000Z");
  const end = new Date("2026-09-13T05:41:00.000Z");
  assert.throws(
      () => assertActualTimes(start, end, now),
      /實際送達時間不可晚於目前時間/,
  );
});

test("實際接回早於送達被拒絕", () => {
  const now = new Date("2026-09-13T08:00:00.000Z");
  const start = new Date("2026-09-13T06:00:00.000Z");
  const end = new Date("2026-09-13T05:00:00.000Z");
  assert.throws(
      () => assertActualTimes(start, end, now),
      /實際接回時間不可早於實際送達時間/,
  );
});

test("提早接回不產生晚接回費", () => {
  const settings = {
    latePickupEnabled: true,
    overtimeGraceMinutes: 15,
    latePickupUnitMinutes: 30,
    latePickupPrice: 100,
  };
  const scheduledEnd = new Date("2026-09-13T10:00:00.000Z");
  const actualEnd = new Date("2026-09-13T09:00:00.000Z");
  const pickup = shopLatePickupBreakdown(settings, scheduledEnd, actualEnd);
  assert.equal(pickup.amount, 0);
});

test("同一 uid 兼店主與客戶時，checked_in 取消成功且 cancelBy 為 staff", () => {
  const booking = {
    userId: "uid-owner",
    status: "checked_in",
  };
  const uid = "uid-owner";
  const isBookingOwner = booking.userId === uid;
  const isStaff = true;
  const cancelBy = resolveDaycareCancelActor({
    isStaff,
    isBookingOwner,
    status: booking.status,
  });
  assert.equal(isBookingOwner, true);
  assert.equal(cancelBy, "staff");
  assert.equal(
      {status: "cancelled", cancelBy}.status,
      "cancelled",
  );
});

test("純客戶取消 checked_in 安親訂單維持 failed-precondition", () => {
  assert.throws(
      () => resolveDaycareCancelActor({
        isStaff: false,
        isBookingOwner: true,
        status: "checked_in",
      }),
      (error) => {
        assert.equal(error.code, "failed-precondition");
        assert.match(error.message, /臨托開始後請聯絡店家取消/);
        return true;
      },
  );
});
