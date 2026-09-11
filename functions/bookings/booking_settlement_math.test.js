// 檔案名稱：functions/bookings/booking_settlement_math.test.js
// 功能說明：待補／待退計算

const test = require("node:test");
const assert = require("node:assert/strict");
const {remainingDue, refundDue, expectedTotal} = require(
    "./booking_settlement_math",
);

test("已收 1600 應收 1800 待補 200", () => {
  const booking = {quotedTotalPrice: 1800, totalPrice: 1800, paidAmount: 1600};
  assert.equal(remainingDue(booking), 200);
  assert.equal(refundDue(booking), 0);
});

test("已收 1600 應收 1400 待退 200", () => {
  const booking = {quotedTotalPrice: 1400, totalPrice: 1400, paidAmount: 1600};
  assert.equal(remainingDue(booking), 0);
  assert.equal(refundDue(booking), 200);
});

test("已收 800 應收 1400 待補 600 不退", () => {
  const booking = {quotedTotalPrice: 1400, totalPrice: 1400, paidAmount: 800};
  assert.equal(remainingDue(booking), 600);
  assert.equal(refundDue(booking), 0);
});

test("已收 1600 已退 200 應收 1500 待補 100", () => {
  const booking = {
    quotedTotalPrice: 1500,
    totalPrice: 1500,
    paidAmount: 1600,
    refundAmount: 200,
  };
  assert.equal(remainingDue(booking), 100);
  assert.equal(expectedTotal(booking), 1500);
});
