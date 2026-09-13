// 檔案名稱：functions/bookings/settlement_payment_direction.test.js
// 功能說明：減免後依待補／待退決定顯示補款或退款

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  settlementMoneyDirection,
  applySettlementPaymentDirection,
} = require("./settlement_payment_direction");
const {remainingDue, refundDue, expectedTotal} = require("./booking_settlement_math");

test("原價 3200 已收 1600 減免 500 仍待補 1100", () => {
  const booking = {quotedTotalPrice: 3200, paidAmount: 1600};
  assert.equal(expectedTotal(booking, -500), 2700);
  assert.equal(remainingDue(booking, -500), 1100);
  assert.equal(refundDue(booking, -500), 0);
  const dir = applySettlementPaymentDirection({
    remainingAmount: 1100,
    refundDueAmount: 0,
    topUpMethod: "cash",
    refundMethod: "cash",
  });
  assert.equal(dir.showTopUp, true);
  assert.equal(dir.showRefund, false);
  assert.equal(dir.settlementTopUpMethod, "cash");
  assert.equal(dir.settlementRefundMethod, "");
});

test("已收大於最終應收才顯示退款", () => {
  const booking = {quotedTotalPrice: 3200, paidAmount: 3200};
  assert.equal(remainingDue(booking, -500), 0);
  assert.equal(refundDue(booking, -500), 500);
  const dir = applySettlementPaymentDirection({
    remainingAmount: 0,
    refundDueAmount: 500,
    topUpMethod: "transfer",
    refundMethod: "transfer",
  });
  assert.equal(dir.showTopUp, false);
  assert.equal(dir.showRefund, true);
  assert.equal(dir.settlementTopUpMethod, "");
  assert.equal(dir.settlementTopUpStatus, "none");
  assert.equal(dir.settlementRefundMethod, "transfer");
});

test("待補與待退皆 0 不顯示任一種方式", () => {
  const dir = settlementMoneyDirection(0, 0);
  assert.equal(dir.showTopUp, false);
  assert.equal(dir.showRefund, false);
});
