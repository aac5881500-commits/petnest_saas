const test = require("node:test");
const assert = require("node:assert/strict");
const {
  parseApplicableServices,
  findBestDaycareCampaign,
} = require("./discount_campaign");

test("legacy campaign without applicableServices is lodging only", () => {
  assert.deepEqual(parseApplicableServices(undefined), ["accommodation"]);
  const best = findBestDaycareCampaign({
    campaigns: [{
      id: "c1",
      enabled: true,
      type: "minimumAmount",
      valueType: "percent",
      applyTarget: "total",
      discountValue: 10,
      minimumAmount: 1000,
    }],
    input: {
      checkInDate: new Date(2026, 8, 28),
      checkOutDate: new Date(2026, 8, 29),
      roomTypeId: "p1",
      roomAmount: 3000,
      petAmount: 0,
      extraServiceAmount: 0,
    },
    now: new Date(2026, 8, 10),
  });
  assert.equal(best, null);
});

test("min amount campaign with daycare applies", () => {
  const best = findBestDaycareCampaign({
    campaigns: [{
      id: "c1",
      enabled: true,
      type: "minimumAmount",
      valueType: "percent",
      applyTarget: "total",
      discountValue: 10,
      minimumAmount: 1000,
      applicableServices: ["daycare"],
    }],
    input: {
      checkInDate: new Date(2026, 8, 28),
      checkOutDate: new Date(2026, 8, 29),
      roomTypeId: "p1",
      roomAmount: 3000,
      petAmount: 0,
      extraServiceAmount: 0,
    },
    now: new Date(2026, 8, 10),
  });
  assert.equal(best.discountAmount, 300);
});

test("long stay never applies to daycare", () => {
  const best = findBestDaycareCampaign({
    campaigns: [{
      id: "c1",
      enabled: true,
      type: "longStay",
      valueType: "percent",
      applyTarget: "total",
      discountValue: 10,
      minimumNights: 3,
      applicableServices: ["daycare", "accommodation"],
    }],
    input: {
      checkInDate: new Date(2026, 8, 28),
      checkOutDate: new Date(2026, 8, 29),
      roomTypeId: "p1",
      roomAmount: 3000,
      petAmount: 0,
      extraServiceAmount: 0,
    },
    now: new Date(2026, 8, 10),
  });
  assert.equal(best, null);
});
