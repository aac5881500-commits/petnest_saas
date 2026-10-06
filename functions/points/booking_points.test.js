// 檔案名稱：functions/points/booking_points.test.js
// 功能說明：住宿／安親發點、實收淨額、折抵與冪等目標點數。

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  capSpend,
  canSpend,
  canIssueEarn,
  computeEarnPoints,
  resolveFinalEarn,
  planMemberEarnSync,
  isWalkInMember,
  ntdFromPoints,
} = require("./booking_points");

const stayAmountSetting = {
  enabled: true,
  calculationType: "amount",
  amountPerPoint: 100,
  minimumOrderAmount: 0,
  maximumPointsPerBooking: 0,
  spendEnabled: true,
  staySpendEnabled: true,
  daycareSpendEnabled: true,
  pointsPerNtd: 1,
};

describe("booking points earn", () => {
  it("住宿按晚數發點", () => {
    const points = computeEarnPoints({
      enabled: true,
      calculationType: "night",
      pointsPerNight: 5,
      minimumOrderAmount: 0,
    }, {
      nights: 3,
      paidAmount: 3000,
      refundAmount: 0,
      status: "completed",
    }, {isAppMember: true});
    assert.equal(points, 15);
  });

  it("住宿按實收金額發點", () => {
    const points = computeEarnPoints(stayAmountSetting, {
      paidAmount: 800,
      refundAmount: 0,
      totalPrice: 9999,
      status: "completed",
    }, {isAppMember: true});
    assert.equal(points, 8);
  });

  it("安親按實收金額發點且無固定每筆點數", () => {
    const points = computeEarnPoints({
      enabled: true,
      daycareEarnEnabled: true,
      daycareAmountPerPoint: 100,
      daycarePointsPerOrder: 99,
      daycareCalculationType: "fixed",
    }, {
      bookingKind: "daycare",
      paidAmount: 800,
      refundAmount: 0,
      status: "completed",
    }, {isAppMember: true});
    assert.equal(points, 8);
  });

  it("有訂金、尾款、補款、退款時用淨實收", () => {
    const points = computeEarnPoints(stayAmountSetting, {
      paidAmount: 500 + 400 + 200,
      refundAmount: 300,
      status: "completed",
    }, {isAppMember: true});
    assert.equal(points, 8);
  });

  it("尚有待補／待退時不發點", () => {
    assert.equal(canIssueEarn({
      status: "checked_out",
      paidAmount: 500,
      totalPrice: 1000,
      quotedTotalPrice: 1000,
    }), false);
    assert.equal(canIssueEarn({
      status: "completed",
      paidAmount: 1200,
      refundAmount: 0,
      quotedTotalPrice: 1000,
      totalPrice: 1000,
    }), false);
  });

  it("純手動會員不可得點；既有 App 會員可得點", () => {
    const booking = {
      paidAmount: 800,
      status: "completed",
      bookingKind: "daycare",
    };
    const setting = {
      enabled: true,
      daycareEarnEnabled: true,
      daycareAmountPerPoint: 100,
    };
    assert.equal(computeEarnPoints(setting, booking, {isAppMember: false}), 0);
    assert.equal(computeEarnPoints(setting, booking, {isAppMember: true}), 8);
  });
});

describe("booking points spend", () => {
  it("優惠券後再點數折抵且不可變負數", () => {
    const result = capSpend({
      requestedPoints: 500,
      balance: 500,
      payableAfterCoupon: 80,
      setting: stayAmountSetting,
    });
    assert.equal(result.pointAmount, 80);
    assert.equal(result.pointsUsed, 80);
  });

  it("點數不足只折可折部分", () => {
    const result = capSpend({
      requestedPoints: 200,
      balance: 30,
      payableAfterCoupon: 200,
      setting: stayAmountSetting,
    });
    assert.equal(result.pointAmount, 30);
    assert.equal(result.pointsUsed, 30);
  });

  it("N 點折抵 NT$1 不寫死 1 點 1 元", () => {
    const setting = {...stayAmountSetting, pointsPerNtd: 10};
    assert.equal(ntdFromPoints(80, setting), 8);
    const result = capSpend({
      requestedPoints: 80,
      balance: 80,
      payableAfterCoupon: 100,
      setting,
    });
    assert.equal(result.pointAmount, 8);
    assert.equal(result.pointsUsed, 80);
  });

  it("純手動未註冊會員不可得點", () => {
    const points = computeEarnPoints(stayAmountSetting, {
      paidAmount: 800,
      status: "completed",
    }, {isAppMember: false});
    assert.equal(points, 0);
  });

  it("未完成時 preview 依應付現金預估", () => {
    const preview = computeEarnPoints(stayAmountSetting, {
      paidAmount: 0,
      totalPrice: 800,
      status: "pending",
    }, {isAppMember: true, preview: true});
    const actual = computeEarnPoints(stayAmountSetting, {
      paidAmount: 0,
      totalPrice: 800,
      status: "pending",
    }, {isAppMember: true});
    assert.equal(preview, 8);
    assert.equal(actual, 0);
  });

  it("未開住宿折抵不可用", () => {
    assert.equal(canSpend({
      enabled: true,
      spendEnabled: true,
      staySpendEnabled: false,
    }, "stay"), false);
  });

  it("999999 不可超過餘額與應付", () => {
    const setting = {...stayAmountSetting, pointsPerNtd: 10};
    const result = capSpend({
      requestedPoints: 999999,
      balance: 100,
      payableAfterCoupon: 50,
      setting,
    });
    assert.equal(result.pointAmount, 10);
    assert.equal(result.pointsUsed, 100);
  });

  it("安親 100 點 10點折1元 只折 NT$10", () => {
    const setting = {
      ...stayAmountSetting,
      staySpendEnabled: false,
      daycareSpendEnabled: true,
      pointsPerNtd: 10,
    };
    const result = capSpend({
      requestedPoints: 100,
      balance: 100,
      payableAfterCoupon: 500,
      setting,
    });
    assert.equal(result.pointAmount, 10);
    assert.equal(result.pointsUsed, 100);
  });

  it("部分折抵 40 點 10點=1元 折 NT$4", () => {
    const setting = {...stayAmountSetting, pointsPerNtd: 10};
    const result = capSpend({
      requestedPoints: 40,
      balance: 100,
      payableAfterCoupon: 80,
      setting,
    });
    assert.equal(result.pointAmount, 4);
    assert.equal(result.pointsUsed, 40);
  });
});

describe("booking points adjust", () => {
  it("取消後退點目標為 0", () => {
    assert.equal(resolveFinalEarn({
      systemPoints: 8,
      eligible: false,
      adjusted: true,
      overridePoints: 5,
    }), 0);
  });

  it("同一訂單重試目標不變", () => {
    const first = resolveFinalEarn({
      systemPoints: 8,
      eligible: true,
      adjusted: false,
    });
    const second = resolveFinalEarn({
      systemPoints: 8,
      eligible: true,
      adjusted: false,
    });
    assert.equal(first, 8);
    assert.equal(second, first);
  });

  it("店員調整後以調整值為應發點數，可高於系統值", () => {
    assert.equal(resolveFinalEarn({
      systemPoints: 100,
      eligible: true,
      adjusted: true,
      overridePoints: 120,
    }), 120);
    assert.equal(resolveFinalEarn({
      systemPoints: 100,
      eligible: true,
      adjusted: true,
      overridePoints: 80,
    }), 80);
  });

  it("未完成或取消時調整值也不發", () => {
    assert.equal(resolveFinalEarn({
      systemPoints: 100,
      eligible: false,
      adjusted: true,
      overridePoints: 120,
    }), 0);
  });
});

const nightSetting = {
  enabled: true,
  calculationType: "night",
  pointsPerNight: 10,
  minimumOrderAmount: 0,
};

const daycareSetting = {
  enabled: true,
  daycareEarnEnabled: true,
  daycareAmountPerPoint: 100,
};

/**
 * @param {Object} extra
 * @return {Object}
 */
function stayBooking(extra) {
  return {
    nights: 10,
    totalPrice: 5000,
    paidAmount: 5000,
    refundAmount: 0,
    status: "completed",
    source: "customer",
    ...extra,
  };
}

/**
 * @param {Object} extra
 * @return {Object}
 */
function daycareBooking(extra) {
  return {
    bookingKind: "daycare",
    totalPrice: 800,
    paidAmount: 800,
    refundAmount: 0,
    status: "completed",
    settlementConfirmed: true,
    source: "customer",
    ...extra,
  };
}

describe("manual order points eligibility", () => {
  it("CASE 1 App 會員自己住宿訂單正常發點", () => {
    const booking = stayBooking();
    assert.equal(isWalkInMember({source: "app"}, true), false);
    assert.equal(canIssueEarn(booking), true);
    const system = computeEarnPoints(nightSetting, booking, {isAppMember: true});
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      systemPoints: system,
      alreadyIssued: 0,
      balance: 0,
      totalEarned: 0,
    });
    assert.equal(system, 100);
    assert.equal(plan.target, 100);
    assert.equal(plan.delta, 100);
    assert.equal(plan.writeMemberPoints, true);
    assert.equal(plan.current, 100);
  });

  it("CASE 2 店主幫 App 會員建立住宿仍正常發點", () => {
    const booking = stayBooking({source: "admin"});
    assert.equal(isWalkInMember({source: "admin"}, true), false);
    const system = computeEarnPoints(nightSetting, booking, {isAppMember: true});
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      systemPoints: system,
      alreadyIssued: 0,
      balance: 40,
      totalEarned: 40,
    });
    assert.equal(system, 100);
    assert.equal(plan.delta, 100);
    assert.equal(plan.current, 140);
    assert.equal(plan.writeMemberPoints, true);
  });

  it("CASE 3 店主幫手動會員建立住宿不發點也不寫 member_points", () => {
    const booking = stayBooking({source: "admin"});
    assert.equal(isWalkInMember({source: "admin", isTempAdminMember: true}, false), true);
    assert.equal(isWalkInMember(null, false), true);
    const system = computeEarnPoints(nightSetting, booking, {isAppMember: false});
    const plan = planMemberEarnSync({
      isAppMember: false,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 100,
      alreadyIssued: 0,
      balance: 0,
      pointsUsed: 50,
    });
    assert.equal(system, 0);
    assert.equal(plan.target, 0);
    assert.equal(plan.delta, 0);
    assert.equal(plan.writeMemberPoints, false);
    assert.equal(plan.skipped, true);
  });

  it("CASE 4 App 會員自己安親正常發點", () => {
    const booking = daycareBooking();
    const system = computeEarnPoints(daycareSetting, booking, {isAppMember: true});
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: canIssueEarn(booking),
      systemPoints: system,
      alreadyIssued: 0,
      balance: 0,
      totalEarned: 0,
    });
    assert.equal(system, 8);
    assert.equal(plan.target, 8);
    assert.equal(plan.delta, 8);
    assert.equal(plan.writeMemberPoints, true);
  });

  it("CASE 5 店主幫 App 會員建立安親正常發點", () => {
    const booking = daycareBooking({source: "admin"});
    const system = computeEarnPoints(daycareSetting, booking, {isAppMember: true});
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      systemPoints: system,
      alreadyIssued: 0,
      balance: 2,
      totalEarned: 2,
    });
    assert.equal(system, 8);
    assert.equal(plan.delta, 8);
    assert.equal(plan.current, 10);
  });

  it("CASE 6 店主幫手動會員建立安親不發點", () => {
    const booking = daycareBooking({source: "admin"});
    const system = computeEarnPoints(daycareSetting, booking, {isAppMember: false});
    const plan = planMemberEarnSync({
      isAppMember: false,
      eligible: true,
      systemPoints: system,
      overridePoints: 8,
      adjusted: true,
      alreadyIssued: 0,
      balance: 0,
    });
    assert.equal(system, 0);
    assert.equal(plan.writeMemberPoints, false);
    assert.equal(plan.target, 0);
  });
});

describe("settlement reward delta", () => {
  it("CASE 7 已發 100 調整成 120 只加差額 20", () => {
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 120,
      alreadyIssued: 100,
      balance: 100,
      totalEarned: 100,
      pointsUsed: 30,
    });
    assert.equal(plan.target, 120);
    assert.equal(plan.delta, 20);
    assert.equal(plan.current, 120);
    assert.equal(plan.totalEarned, 120);
    assert.equal(plan.writeMemberPoints, true);
  });

  it("CASE 8 已發 100 調整成 80 只扣差額 20", () => {
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 80,
      alreadyIssued: 100,
      balance: 100,
      totalEarned: 100,
    });
    assert.equal(plan.target, 80);
    assert.equal(plan.delta, -20);
    assert.equal(plan.current, 80);
    assert.equal(plan.totalEarned, 80);
  });

  it("CASE 9 尚未發放時 100 改 120 最終只發 120", () => {
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 120,
      alreadyIssued: 0,
      balance: 0,
      totalEarned: 0,
    });
    assert.equal(plan.target, 120);
    assert.equal(plan.delta, 120);
    assert.equal(plan.current, 120);
  });

  it("CASE 10 同一筆 sync 第二次 delta 為 0", () => {
    const first = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 120,
      alreadyIssued: 100,
      balance: 100,
      totalEarned: 100,
    });
    const second = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 120,
      alreadyIssued: first.nextIssued,
      balance: first.current,
      totalEarned: first.totalEarned,
    });
    assert.equal(first.delta, 20);
    assert.equal(second.delta, 0);
    assert.equal(second.writeMemberPoints, false);
    assert.equal(second.current, 120);
  });

  it("CASE 11 Function retry 用已發目標，不重複發點", () => {
    const issued = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      systemPoints: 100,
      alreadyIssued: 0,
      balance: 0,
      totalEarned: 0,
    });
    const retry = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      systemPoints: 100,
      alreadyIssued: issued.nextIssued,
      balance: issued.current,
      totalEarned: issued.totalEarned,
    });
    assert.equal(issued.delta, 100);
    assert.equal(issued.nextIssued, 100);
    assert.equal(retry.delta, 0);
    assert.equal(retry.writeMemberPoints, false);
    assert.equal(retry.current, 100);
  });

  it("CASE 12 手動會員結算跳過發點且不建立 member_points", () => {
    const plan = planMemberEarnSync({
      isAppMember: false,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 120,
      alreadyIssued: 0,
      balance: 0,
      pointsUsed: 40,
    });
    assert.equal(plan.skipped, true);
    assert.equal(plan.target, 0);
    assert.equal(plan.delta, 0);
    assert.equal(plan.writeMemberPoints, false);
    assert.equal(plan.current, 0);
  });

  it("取消後應發改 0，依差額扣回，不另訂退款政策", () => {
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: false,
      adjusted: true,
      systemPoints: 0,
      overridePoints: 100,
      alreadyIssued: 100,
      balance: 100,
      totalEarned: 100,
    });
    assert.equal(plan.target, 0);
    assert.equal(plan.delta, -100);
    assert.equal(plan.current, 0);
  });

  it("餘額不足時沿用既有下限，不把不足額記成負數", () => {
    const plan = planMemberEarnSync({
      isAppMember: true,
      eligible: true,
      adjusted: true,
      systemPoints: 100,
      overridePoints: 20,
      alreadyIssued: 100,
      balance: 10,
      totalEarned: 100,
    });
    assert.equal(plan.delta, -80);
    assert.equal(plan.current, 0);
    assert.equal(plan.clamped, true);
    assert.equal(plan.nextIssued, 20);
  });
});
