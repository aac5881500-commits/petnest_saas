const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {computeEarnPoints, capSpendAmount, canSpend} = require("./daycare_points");

describe("computeEarnPoints", () => {
  const setting = {
    enabled: true,
    daycareEarnEnabled: true,
    daycareAmountPerPoint: 100,
    daycareMaximumPointsPerBooking: 10,
  };

  it("uses net collected and caps points", () => {
    const points = computeEarnPoints(setting, {
      bookingKind: "daycare",
      paidAmount: 2500,
      refundAmount: 0,
      status: "completed",
    });
    assert.equal(points, 10);
  });

  it("does not use fixed per-order points", () => {
    const points = computeEarnPoints({
      ...setting,
      daycareCalculationType: "fixed",
      daycarePointsPerOrder: 3,
      daycareMaximumPointsPerBooking: 0,
    }, {
      bookingKind: "daycare",
      paidAmount: 10,
      status: "completed",
    });
    assert.equal(points, 0);
  });

  it("does not earn when disabled", () => {
    const points = computeEarnPoints({...setting, daycareEarnEnabled: false}, {
      bookingKind: "daycare",
      paidAmount: 900,
      status: "completed",
    });
    assert.equal(points, 0);
  });
});

describe("capSpendAmount", () => {
  it("never exceeds balance, payable or max", () => {
    assert.equal(capSpendAmount({
      requested: 500,
      balance: 80,
      payableAfterCoupon: 100,
      maxPerBooking: 50,
    }), 50);
  });
});

describe("canSpend", () => {
  it("requires daycare spend flag", () => {
    assert.equal(canSpend({
      enabled: true,
      spendEnabled: true,
      daycareSpendEnabled: true,
    }), true);
    assert.equal(canSpend({
      enabled: true,
      spendEnabled: true,
      daycareSpendEnabled: false,
    }), false);
  });
});
