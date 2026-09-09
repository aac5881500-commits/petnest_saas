// 檔案名稱：functions/daycare/quote_time_charge.test.js
// 功能說明：起步時間是計費門檻，短於起步仍收起步價

const test = require("node:test");
const assert = require("node:assert/strict");
const {quoteTimeCharge} = require("./daycare_pricing");

test("3 hours against 5-hour included still charges base only", () => {
  const charge = quoteTimeCharge({
    durationMinutes: 180,
    includedMinutes: 300,
    extraBillingMinutes: 60,
    extraBillingPrice: 200,
    extraPetPrice: 0,
    maxBaseCharge: 0,
    petCount: 1,
    basePrice: 1000,
  });
  assert.equal(charge.timeCharge, 1000);
  assert.equal(charge.extraMinutes, 0);
  assert.equal(charge.extraUnits, 0);
});
