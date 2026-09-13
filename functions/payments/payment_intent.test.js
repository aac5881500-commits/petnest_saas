// 檔案名稱：functions/payments/payment_intent.test.js
// 功能說明：結算尾款金額來源與付款用途分類

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  resolveBookingPaymentIntent,
  resolveRequestedPaymentAmount,
} = require("./payment_verify");

test("結算後信用卡收取當下 remainingDue，用途為 balance", () => {
  const booking = {
    settlementConfirmed: true,
    quotedTotalPrice: 1000,
    overtimeAmount: 0,
    manualAdjust: 800,
    paidAmount: 500,
    refundAmount: 0,
    totalPrice: 1800,
    totalPayableAmount: 1800,
    finalSettlementAmount: 1800,
  };
  const intent = resolveBookingPaymentIntent({
    booking,
    amountType: "full",
    paymentPurpose: "additional",
  });
  assert.equal(intent.amountType, "full");
  assert.equal(intent.paymentPurpose, "balance");
  assert.equal(resolveRequestedPaymentAmount({booking, amountType: intent.chargeType}), 1300);
});

test("訂金請求在未結算時維持 deposit", () => {
  const booking = {
    quotedTotalPrice: 2000,
    totalPrice: 2000,
    depositAmount: 500,
    paidAmount: 0,
  };
  const intent = resolveBookingPaymentIntent({
    booking,
    amountType: "deposit",
    paymentPurpose: "full",
  });
  assert.equal(intent.paymentPurpose, "deposit");
  assert.equal(intent.amountType, "deposit");
  assert.equal(resolveRequestedPaymentAmount({booking, amountType: intent.chargeType}), 500);
});

test("一次付清未付款訂單用途為 full", () => {
  const booking = {
    quotedTotalPrice: 2000,
    totalPrice: 2000,
    paidAmount: 0,
  };
  const intent = resolveBookingPaymentIntent({
    booking,
    amountType: "full",
    paymentPurpose: "full",
  });
  assert.equal(intent.paymentPurpose, "full");
});

test("前端誤傳 amountType=balance 仍正規成 full，不會付款金額類型不正確", () => {
  const {
    normalizeStoredAmountType,
    normalizeStoredPaymentPurpose,
  } = require("./payment_verify");
  assert.equal(normalizeStoredAmountType("balance"), "full");
  assert.equal(normalizeStoredPaymentPurpose("balance", "balance"), "balance");
  const booking = {
    settlementConfirmed: true,
    quotedTotalPrice: 1800,
    paidAmount: 500,
    finalSettlementAmount: 1800,
  };
  const intent = resolveBookingPaymentIntent({
    booking,
    amountType: "balance",
    paymentPurpose: "balance",
  });
  assert.equal(intent.amountType, "full");
  assert.equal(intent.chargeType, "full");
  assert.equal(intent.paymentPurpose, "balance");
  assert.equal(
      resolveRequestedPaymentAmount({booking, amountType: intent.amountType}),
      1300,
  );
});
