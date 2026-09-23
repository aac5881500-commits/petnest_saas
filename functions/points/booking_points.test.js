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

  it("退款後店員調整不可超過新系統點數", () => {
    assert.equal(resolveFinalEarn({
      systemPoints: 3,
      eligible: true,
      adjusted: true,
      overridePoints: 10,
    }), 3);
  });
});
