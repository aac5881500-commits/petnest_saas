const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  CHECKOUT_CLEANING_STATUS,
  calendarBlocksRoom,
  canApplyRoomCalendarStatus,
  checkoutDayOnStayCheckout,
  newStayAutoCleaningSnapshot,
  stayAutoCleaningForRebuild,
  stayCalendarPlan,
  stayConflictsSlot,
  stayNightKeys,
  stayReleaseDateKeys,
} = require("../daycare/daycare_occupancy");
const {
  buildReconcileResponse,
  planStayCalendarRepair,
  reconcileWritesAllowed,
  repairWritePlan,
} = require("./reconcile_stay_calendar");

const checkIn = "2026-10-01T00:00:00+08:00";
const checkOut = "2026-10-03T00:00:00+08:00";

describe("住宿台灣日曆日", () => {
  it("UTC 環境下 10/1～10/3 只占用 10/1 與 10/2", () => {
    const keys = stayNightKeys(new Date(checkIn), new Date(checkOut));
    assert.equal(new Date(checkIn).toISOString().startsWith("2026-09-30"), true);
    assert.deepEqual(keys, ["2026-10-01", "2026-10-02"]);
    assert.equal(keys.includes("2026-09-30"), false);
  });

  it("yyyy-MM-dd、UTC ISO、Date 與 Timestamp 得到同一組台灣日期", () => {
    const expected = ["2026-10-01", "2026-10-02"];
    const asTimestamp = (iso) => {
      return {toDate: () => new Date(iso)};
    };
    assert.deepEqual(stayNightKeys("2026-10-01", "2026-10-03"), expected);
    assert.deepEqual(stayNightKeys(
        "2026-09-30T16:00:00.000Z",
        "2026-10-02T16:00:00.000Z",
    ), expected);
    assert.deepEqual(stayNightKeys(
        new Date(checkIn),
        new Date(checkOut),
    ), expected);
    assert.deepEqual(stayNightKeys(
        asTimestamp(checkIn),
        asTimestamp(checkOut),
    ), expected);
  });

  it("09/28～09/30 的住宿夜晚是 09/28、09/29", () => {
    assert.deepEqual(
        stayNightKeys("2026-09-28", "2026-09-30"),
        ["2026-09-28", "2026-09-29"],
    );
  });

  it("退房日不算住宿衝突，但清潔保留會擋住房間", () => {
    const stayStart = new Date(checkIn);
    const stayEnd = new Date(checkOut);
    const checkoutSlot = new Date("2026-10-03T00:00:00+08:00");
    const nightSlot = new Date("2026-10-02T00:00:00+08:00");
    assert.equal(stayConflictsSlot(
        stayStart, stayEnd, checkoutSlot,
        new Date("2026-10-03T08:00:00+08:00"),
    ), false);
    assert.equal(stayConflictsSlot(
        stayStart, stayEnd, nightSlot,
        new Date("2026-10-02T08:00:00+08:00"),
    ), true);
    assert.equal(calendarBlocksRoom(CHECKOUT_CLEANING_STATUS), true);
    assert.equal(calendarBlocksRoom("available"), false);
  });
});

describe("退房日清潔保留", () => {
  it("自動清潔開啟時鎖退房日，但晚數不含退房日", () => {
    const plan = stayCalendarPlan(checkIn, checkOut, true);
    assert.deepEqual(plan.nights, ["2026-10-01", "2026-10-02"]);
    assert.equal(plan.checkoutKey, "2026-10-03");
    assert.deepEqual(plan.blockedKeys, [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
    assert.equal(plan.nights.includes("2026-10-03"), false);
  });

  it("自動清潔關閉時退房日可再排", () => {
    const plan = stayCalendarPlan(checkIn, checkOut, false);
    assert.deepEqual(plan.nights, ["2026-10-01", "2026-10-02"]);
    assert.equal(plan.checkoutKey, "");
    assert.deepEqual(plan.blockedKeys, ["2026-10-01", "2026-10-02"]);
  });

  it("取消、改期、換房會釋放舊夜晚與退房保留", () => {
    const released = stayReleaseDateKeys(checkIn, checkOut);
    assert.deepEqual(released, [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
    const moved = stayCalendarPlan(
        "2026-10-04",
        "2026-10-06",
        true,
    );
    assert.deepEqual(moved.nights, ["2026-10-04", "2026-10-05"]);
    assert.equal(moved.checkoutKey, "2026-10-06");
    assert.equal(released.includes("2026-10-04"), false);
  });
});

/**
 * @param {Object=} extra
 * @return {Object}
 */
function stayBooking(extra) {
  return {
    id: "stay-1",
    roomId: "A001",
    startDate: "2026-10-01",
    endDate: "2026-10-03",
    status: "confirmed",
    ...extra,
  };
}

/**
 * @param {string} date
 * @param {string} status
 * @param {string=} bookingId
 * @param {string=} roomId
 * @return {Object}
 */
function cal(date, status, bookingId, roomId) {
  return {
    date,
    status,
    bookingId: bookingId || "stay-1",
    roomId: roomId || "A001",
  };
}

describe("住宿房曆校正", () => {
  it("TEST 1 自動清潔關閉時退房日沒有住宿鎖", () => {
    const plan = stayCalendarPlan("2026-10-01", "2026-10-03", false);
    assert.deepEqual(plan.nights, ["2026-10-01", "2026-10-02"]);
    assert.equal(plan.checkoutKey, "");
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: false}),
      calendarDocs: [
        cal("2026-10-01", "booked"),
        cal("2026-10-02", "booked"),
      ],
    });
    assert.equal(report.expected["2026-10-03"], undefined);
    assert.equal(report.wouldCreate.length, 0);
    assert.equal(report.wouldDelete.length, 0);
  });

  it("TEST 2 自動清潔開啟時退房日是 checkout_cleaning", () => {
    const plan = stayCalendarPlan("2026-10-01", "2026-10-03", true);
    assert.deepEqual(plan.blockedKeys, [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: true}),
      calendarDocs: [],
    });
    assert.equal(report.expected["2026-10-01"], "booked");
    assert.equal(report.expected["2026-10-02"], "booked");
    assert.equal(report.expected["2026-10-03"], CHECKOUT_CLEANING_STATUS);
    assert.deepEqual(report.wouldCreate.map((item) => item.date), [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
  });

  it("TEST 3 取消會釋放住宿夜與退房日", () => {
    assert.deepEqual(stayReleaseDateKeys("2026-10-01", "2026-10-03"), [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
  });

  it("TEST 4 換房先釋放舊房再建立新房", () => {
    const released = stayReleaseDateKeys("2026-10-01", "2026-10-03");
    const next = stayCalendarPlan("2026-10-01", "2026-10-03", true);
    assert.deepEqual(released, ["2026-10-01", "2026-10-02", "2026-10-03"]);
    assert.deepEqual(next.nights, ["2026-10-01", "2026-10-02"]);
    assert.equal(next.checkoutKey, "2026-10-03");
    const oldRoom = planStayCalendarRepair({
      booking: stayBooking({
        roomId: "A002",
        autoCleaningAfterCheckout: true,
      }),
      calendarDocs: [
        cal("2026-10-01", "booked", "stay-1", "A001"),
        cal("2026-10-02", "booked", "stay-1", "A001"),
        cal("2026-10-03", CHECKOUT_CLEANING_STATUS, "stay-1", "A001"),
      ],
    });
    assert.deepEqual(oldRoom.wouldDelete.map((item) => item.roomId), [
      "A001",
      "A001",
      "A001",
    ]);
    assert.deepEqual(oldRoom.wouldCreate.map((item) => item.date), [
      "2026-10-01",
      "2026-10-02",
      "2026-10-03",
    ]);
    assert.equal(oldRoom.wouldCreate[2].status, CHECKOUT_CLEANING_STATUS);
  });

  it("TEST 5 不會把 10/01 修成 09/30", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: true}),
      autoCleaning: true,
      calendarDocs: [
        cal("2026-09-30", "booked"),
        cal("2026-10-01", "booked"),
      ],
    });
    assert.equal(report.expected["2026-09-30"], undefined);
    assert.deepEqual(report.wouldDelete.map((item) => item.date), [
      "2026-09-30",
    ]);
    assert.equal(report.nights.includes("2026-09-30"), false);
  });

  it("TEST 6 跨月住宿夜與退房清潔", () => {
    const plan = stayCalendarPlan("2026-10-31", "2026-11-02", true);
    assert.deepEqual(plan.nights, ["2026-10-31", "2026-11-01"]);
    assert.equal(plan.checkoutKey, "2026-11-02");
  });

  it("TEST 7 跨年住宿夜與退房清潔", () => {
    const plan = stayCalendarPlan("2026-12-31", "2027-01-02", true);
    assert.deepEqual(plan.nights, ["2026-12-31", "2027-01-01"]);
    assert.equal(plan.checkoutKey, "2027-01-02");
  });

  it("TEST 8 其他 bookingId 不可覆蓋", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: true}),
      calendarDocs: [
        cal("2026-10-02", "booked", "stay-2"),
        cal("2026-10-03", "booked", "stay-2"),
      ],
    });
    const writes = repairWritePlan(report);
    assert.equal(writes.sets.some((item) => item.date === "2026-10-02"), false);
    assert.equal(writes.sets.some((item) => item.date === "2026-10-03"), false);
    assert.equal(writes.deletes.length, 0);
    assert.equal(report.conflicts.length >= 2, true);
  });

  it("TEST 9 人工 maintenance 與 cleaning 不可刪除", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: true}),
      calendarDocs: [
        cal("2026-09-30", "maintenance"),
        cal("2026-10-02", "cleaning"),
        cal("2026-10-03", "maintenance"),
      ],
    });
    const writes = repairWritePlan(report);
    const touched = writes.deletes.concat(writes.sets).map((item) => item.date);
    assert.equal(touched.includes("2026-09-30"), false);
    assert.equal(touched.includes("2026-10-02"), false);
    assert.equal(touched.includes("2026-10-03"), false);
  });

  it("TEST 10 dryRun 不產生寫入", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking({autoCleaningAfterCheckout: true}),
      calendarDocs: [cal("2026-09-30", "booked")],
    });
    assert.equal(report.wouldDelete.length > 0, true);
    assert.equal(reconcileWritesAllowed({}), false);
    assert.equal(reconcileWritesAllowed({dryRun: true}), false);
    assert.equal(reconcileWritesAllowed({apply: true}), false);
    assert.equal(reconcileWritesAllowed({dryRun: false}), true);
    const preview = buildReconcileResponse(true, [report]);
    assert.equal(preview.dryRun, true);
    assert.deepEqual(preview.writes, []);
    assert.equal(preview.wouldDelete > 0, true);
    assert.equal(preview.scannedBookings, 1);
    assert.equal(preview.incorrectBookings, 1);
    const live = buildReconcileResponse(false, [report]);
    assert.equal(live.dryRun, false);
    assert.equal(live.writes.length > 0, true);
    assert.equal(JSON.stringify(preview.examples).includes("customerName"), false);
  });

  it("TEST A 建單快照沿用當時店家設定", () => {
    const shop = {
      housekeepingSetting: {autoCleaningAfterCheckout: true},
    };
    assert.equal(newStayAutoCleaningSnapshot(shop), true);
    const off = {
      housekeepingSetting: {autoCleaningAfterCheckout: false},
    };
    assert.equal(newStayAutoCleaningSnapshot(off), false);
  });

  it("TEST B snapshot true 不因店家後來關閉而拿掉退房日", () => {
    const booking = stayBooking({autoCleaningAfterCheckout: true});
    assert.equal(stayAutoCleaningForRebuild(booking), true);
    const plan = stayCalendarPlan(
        booking.startDate,
        booking.endDate,
        stayAutoCleaningForRebuild(booking),
    );
    assert.equal(plan.checkoutKey, "2026-10-03");
    assert.equal(plan.nights.includes("2026-10-03"), false);
  });

  it("TEST C snapshot false 不因店家後來開啟而建立退房日", () => {
    const booking = stayBooking({autoCleaningAfterCheckout: false});
    assert.equal(stayAutoCleaningForRebuild(booking), false);
    const plan = stayCalendarPlan(
        booking.startDate,
        booking.endDate,
        stayAutoCleaningForRebuild(booking),
    );
    assert.equal(plan.checkoutKey, "");
    assert.deepEqual(plan.nights, ["2026-10-01", "2026-10-02"]);
  });

  it("TEST D 沒快照時 reconcile 不猜店家現況", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking(),
      autoCleaning: true,
      calendarDocs: [
        cal("2026-10-01", "booked"),
        cal("2026-10-02", "booked"),
      ],
    });
    assert.equal(report.autoCleaningKnown, false);
    assert.equal(report.expected["2026-10-03"], undefined);
    assert.equal(report.wouldCreate.length, 0);
    assert.equal(
        report.skipped.some((item) => item.date === "2026-10-03"),
        true,
    );
  });

  it("TEST E 尚未退房不能把待清潔鎖房清成可售", () => {
    const blocked = canApplyRoomCalendarStatus({
      fromStatus: CHECKOUT_CLEANING_STATUS,
      toStatus: "available",
      cleaningCompleted: true,
    });
    assert.equal(blocked.ok, false);
    assert.equal(canApplyRoomCalendarStatus({
      fromStatus: CHECKOUT_CLEANING_STATUS,
      toStatus: "cleaning",
    }).ok, false);
  });

  it("TEST F 完成退房才把待清潔鎖房轉成清潔中", () => {
    const decision = checkoutDayOnStayCheckout({
      booking: {autoCleaningAfterCheckout: true},
      exists: true,
      status: CHECKOUT_CLEANING_STATUS,
      ownerBookingId: "stay-1",
      bookingId: "stay-1",
    });
    assert.equal(decision.action, "convert");
  });

  it("TEST G 只有清潔中可以完成清潔並恢復可售", () => {
    assert.equal(canApplyRoomCalendarStatus({
      fromStatus: "cleaning",
      toStatus: "available",
      cleaningCompleted: true,
    }).ok, true);
    assert.equal(canApplyRoomCalendarStatus({
      fromStatus: CHECKOUT_CLEANING_STATUS,
      toStatus: "available",
      cleaningCompleted: true,
    }).ok, false);
  });

  it("TEST H 退房日歸屬不符不能改成清潔中", () => {
    const decision = checkoutDayOnStayCheckout({
      booking: {autoCleaningAfterCheckout: true},
      exists: true,
      status: CHECKOUT_CLEANING_STATUS,
      ownerBookingId: "stay-2",
      bookingId: "stay-1",
    });
    assert.equal(decision.action, "keep");
    const manual = checkoutDayOnStayCheckout({
      booking: {autoCleaningAfterCheckout: true},
      exists: true,
      status: "maintenance",
      ownerBookingId: "stay-1",
      bookingId: "stay-1",
    });
    assert.equal(manual.action, "keep");
  });

  it("snapshot false 的異常退房日鎖房在完成退房時保留", () => {
    const decision = checkoutDayOnStayCheckout({
      booking: {autoCleaningAfterCheckout: false},
      exists: true,
      status: CHECKOUT_CLEANING_STATUS,
      ownerBookingId: "stay-1",
      bookingId: "stay-1",
    });
    assert.equal(decision.action, "keep");
    assert.equal(decision.reason, "inconsistent");
    assert.notEqual(decision.action, "delete");
    assert.notEqual(decision.action, "convert");
  });

  it("TEST I snapshot false 完成退房不建立清潔中", () => {
    const decision = checkoutDayOnStayCheckout({
      booking: {autoCleaningAfterCheckout: false},
      exists: false,
      status: "",
      ownerBookingId: "",
      bookingId: "stay-1",
    });
    assert.equal(decision.action, "keep");
    assert.notEqual(decision.action, "convert");
  });

  it("沒有設定快照時不刪歷史退房清潔", () => {
    const report = planStayCalendarRepair({
      booking: stayBooking(),
      autoCleaning: false,
      calendarDocs: [
        cal("2026-10-01", "booked"),
        cal("2026-10-02", "booked"),
        cal("2026-10-03", CHECKOUT_CLEANING_STATUS),
      ],
    });
    assert.equal(report.autoCleaningAfterCheckout, null);
    assert.equal(report.wouldDelete.length, 0);
    assert.equal(report.wouldCreate.length, 0);
    assert.equal(report.skipped.some((item) => item.date === "2026-10-03"), true);
  });
});
