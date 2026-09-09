const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {computeEarnPoints, capSpendAmount} = require("./daycare_points");

describe("computeEarnPoints", () => {
  const setting = {
    enabled: true,
    daycareEarnEnabled: true,
    daycareCalculationType: "amount",
    daycareAmountPerPoint: 100,
    daycareIncludeAddons: true,
    daycareIncludeSurcharge: true,
    daycareIncludeOvertime: false,
    daycareMaximumPointsPerBooking: 10,
  };

  it("uses amount mode and caps points", () => {
    const points = computeEarnPoints(setting, {
      finalSettlementAmount: 2500,
      overtimeAmount: 400,
      specialDateSurchargeAmount: 200,
    });
    assert.equal(points, 10);
  });

  it("uses fixed points", () => {
    const points = computeEarnPoints({
      ...setting,
      daycareCalculationType: "fixed",
      daycarePointsPerOrder: 3,
      daycareMaximumPointsPerBooking: 0,
    }, {finalSettlementAmount: 10});
    assert.equal(points, 3);
  });

  it("does not earn when disabled", () => {
    const points = computeEarnPoints({...setting, daycareEarnEnabled: false}, {
      finalSettlementAmount: 900,
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
