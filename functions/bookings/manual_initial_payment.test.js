/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/manual_initial_payment.test.js
// 功能說明：銀行轉帳人工確認沿用客戶下單的 deposit／full，且不重複累加。

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildManualPaymentActionLog,
  isSettledManualPayment,
  manualInitialPaymentFields,
  planManualInitialPayment,
  resolveInitialPayAmountType,
} = require("./manual_initial_payment");
const {netCollected} = require("./booking_settlement_math");
const {computeEarnPoints} = require("../points/booking_points");

function stayBase(extra) {
  return {
    id: "stay1",
    bookingKind: "stay",
    status: "pending",
    paymentMethod: "transfer",
    totalPrice: 5000,
    depositAmount: 1500,
    paidAmount: 0,
    ...extra,
  };
}

function daycareBase(extra) {
  return {
    id: "day1",
    bookingKind: "daycare",
    status: "pending",
    paymentMethod: "transfer",
    totalPrice: 5000,
    depositAmount: 1500,
    paidAmount: 0,
    ...extra,
  };
}

test("住宿銀行轉帳訂金確認 1500，剩餘 3500", () => {
  const plan = planManualInitialPayment(stayBase({payAmountType: "deposit"}));
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "deposit");
  assert.equal(plan.amountType, "deposit");
  assert.equal(plan.amount, 1500);
  assert.equal(plan.paidAmount, 1500);
  assert.equal(plan.remainingAmount, 3500);
  assert.equal(plan.paymentStatus, "partially_paid");
  assert.equal(plan.markDeposit, true);
  assert.equal(plan.paymentDocId, "manual_initial_stay1");
});

test("住宿銀行轉帳全額確認 5000，剩餘 0，且不標成只有訂金", () => {
  const plan = planManualInitialPayment(stayBase({payAmountType: "full"}));
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "full");
  assert.equal(plan.amount, 5000);
  assert.equal(plan.paidAmount, 5000);
  assert.equal(plan.remainingAmount, 0);
  assert.equal(plan.paymentStatus, "paid");
  assert.equal(plan.markDeposit, false);
});

test("安親銀行轉帳訂金確認後仍是部分付款", () => {
  const plan = planManualInitialPayment(daycareBase({
    payAmountType: "deposit",
  }));
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "deposit");
  assert.equal(plan.amount, 1500);
  assert.equal(plan.paidAmount, 1500);
  assert.equal(plan.remainingAmount, 3500);
  assert.equal(plan.paymentStatus, "partial");
  assert.equal(plan.markDeposit, true);
});

test("安親銀行轉帳全額確認後與信用卡全額相同語意", () => {
  const plan = planManualInitialPayment(daycareBase({payAmountType: "full"}));
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "full");
  assert.equal(plan.amount, 5000);
  assert.equal(plan.paidAmount, 5000);
  assert.equal(plan.remainingAmount, 0);
  assert.equal(plan.paymentStatus, "paid");
  assert.equal(plan.markDeposit, true);
});

test("全額確認重試不會再加一次 paidAmount", () => {
  const first = planManualInitialPayment(stayBase({payAmountType: "full"}));
  const second = planManualInitialPayment(stayBase({
    payAmountType: "full",
    paidAmount: first.paidAmount,
    paymentStatus: first.paymentStatus,
  }));
  assert.equal(second.ok, false);
  assert.match(second.message, /全額已確認/);
  assert.equal(first.paidAmount, 5000);
});

test("訂金已確認不可重複執行", () => {
  const second = planManualInitialPayment(stayBase({
    payAmountType: "deposit",
    paidAmount: 1500,
    depositPaid: true,
    depositStatus: "confirmed",
  }));
  assert.equal(second.ok, false);
  assert.match(second.message, /訂金已確認/);
});

test("舊訂單沒有 payAmountType 時維持訂金，不猜全額", () => {
  const booking = stayBase({});
  delete booking.payAmountType;
  assert.equal(resolveInitialPayAmountType(booking), "deposit");
  const plan = planManualInitialPayment(booking);
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "deposit");
  assert.equal(plan.amount, 1500);
  const sameAmount = stayBase({totalPrice: 1500, depositAmount: 1500});
  delete sameAmount.payAmountType;
  assert.equal(resolveInitialPayAmountType(sameAmount), "deposit");
});

test("優惠後全額使用最終應付，不用原始房價", () => {
  const plan = planManualInitialPayment(stayBase({
    payAmountType: "full",
    totalPayableAmount: 4200,
    totalPrice: 5000,
    depositAmount: 1500,
  }));
  assert.equal(plan.amount, 4200);
  assert.equal(plan.paidAmount, 4200);
  assert.equal(plan.remainingAmount, 0);
  assert.equal(plan.paymentPurpose, "full");
});

test("客戶傳入金額不會被採用，全額仍用訂單最終應付", () => {
  const plan = planManualInitialPayment(stayBase({
    payAmountType: "full",
    totalPrice: 5000,
    amount: 1,
    clientAmount: 99999,
  }));
  assert.equal(plan.ok, true);
  assert.equal(plan.amount, 5000);
  assert.equal(plan.paymentPurpose, "full");
});

test("活動折扣與點數折抵後，住宿全額確認最終應付 4000", () => {
  const plan = planManualInitialPayment(stayBase({
    payAmountType: "full",
    originalTotal: 5000,
    discountAmount: 500,
    pointAmount: 500,
    totalPrice: 4000,
    depositAmount: 1500,
  }));
  assert.equal(plan.ok, true);
  assert.equal(plan.paymentPurpose, "full");
  assert.equal(plan.amountType, "full");
  assert.equal(plan.amount, 4000);
  assert.equal(plan.paidAmount, 4000);
  assert.equal(plan.remainingAmount, 0);
  assert.equal(plan.paymentStatus, "paid");
  assert.notEqual(plan.amount, 5000);
  assert.notEqual(plan.amount, 1500);
});

test("活動折扣與點數折抵後，安親全額確認最終應付 4000", () => {
  const plan = planManualInitialPayment(daycareBase({
    payAmountType: "full",
    originalTotal: 5000,
    discountAmount: 500,
    pointAmount: 500,
    totalPrice: 4000,
    quotedTotalPrice: 4000,
    depositAmount: 1500,
  }));
  assert.equal(plan.amount, 4000);
  assert.equal(plan.paidAmount, 4000);
  assert.equal(plan.remainingAmount, 0);
  assert.equal(plan.paymentPurpose, "full");
  assert.equal(plan.paymentStatus, "paid");
});

test("全額銀行轉帳確認後點數同步讀到實收全額", () => {
  const plan = planManualInitialPayment(daycareBase({
    payAmountType: "full",
    totalPayableAmount: 4200,
    totalPrice: 5000,
  }));
  const booking = daycareBase({
    payAmountType: "full",
    totalPayableAmount: 4200,
    totalPrice: 5000,
    paidAmount: plan.paidAmount,
    remainingAmount: plan.remainingAmount,
    paymentStatus: plan.paymentStatus,
  });
  assert.equal(netCollected(booking), 4200);
  const points = computeEarnPoints({
    enabled: true,
    daycareEarnEnabled: true,
    daycareAmountPerPoint: 100,
  }, booking, {isAppMember: true});
  assert.equal(points, 42);
  const depositBooking = daycareBase({
    payAmountType: "deposit",
    paidAmount: 1500,
  });
  assert.equal(netCollected(depositBooking), 1500);
});

test("實收 4000 的點數讀到 4000，不會讀成原價或訂金", () => {
  const plan = planManualInitialPayment(stayBase({
    payAmountType: "full",
    originalTotal: 5000,
    discountAmount: 500,
    pointAmount: 500,
    totalPrice: 4000,
  }));
  const booking = stayBase({
    payAmountType: "full",
    originalTotal: 5000,
    totalPrice: 4000,
    paidAmount: plan.paidAmount,
    remainingAmount: plan.remainingAmount,
    paymentStatus: plan.paymentStatus,
  });
  assert.equal(netCollected(booking), 4000);
  const points = computeEarnPoints({
    enabled: true,
    calculationType: "amount",
    amountPerPoint: 100,
  }, booking, {isAppMember: true});
  assert.equal(points, 40);
  const depositOnly = stayBase({
    payAmountType: "deposit",
    paidAmount: 1500,
    totalPrice: 4000,
  });
  assert.equal(netCollected(depositOnly), 1500);
  assert.equal(computeEarnPoints({
    enabled: true,
    calculationType: "amount",
    amountPerPoint: 100,
  }, depositOnly, {isAppMember: true}), 15);
});

test("全額付款文件與操作紀錄使用中性 action，並保留付款目的", () => {
  const plan = planManualInitialPayment(stayBase({payAmountType: "full"}));
  const payment = manualInitialPaymentFields(plan, {
    shopId: "shop1",
    bookingId: "stay1",
    booking: {bookingCode: "S1", userId: "u1", customerName: "王小明"},
    uid: "staff1",
  });
  assert.equal(payment.paymentPurpose, "full");
  assert.equal(payment.amountType, "full");
  assert.equal(payment.amount, 5000);
  assert.equal(payment.status, "paid");
  assert.equal(payment.requestId, "manual_initial_stay1");
  assert.equal(payment.gateway, "manual");
  const log = buildManualPaymentActionLog(plan, {
    shopId: "shop1",
    bookingId: "stay1",
    uid: "staff1",
    confirmedAt: "2026-10-06T00:00:00.000Z",
  });
  assert.equal(log.action, "manual_payment_confirmed");
  assert.equal(log.type, "manual_payment_confirmed");
  assert.equal(log.payload.bookingId, "stay1");
  assert.equal(log.payload.shopId, "shop1");
  assert.equal(log.payload.actorUid, "staff1");
  assert.equal(log.payload.paymentMethod, "transfer");
  assert.equal(log.payload.paymentPurpose, "full");
  assert.equal(log.payload.amount, 5000);
  assert.equal(log.payload.confirmedAt, "2026-10-06T00:00:00.000Z");
  const depositPlan = planManualInitialPayment(stayBase({
    payAmountType: "deposit",
  }));
  const depositLog = buildManualPaymentActionLog(depositPlan, {
    shopId: "shop1",
    bookingId: "stay1",
    uid: "staff1",
    confirmedAt: "2026-10-06T00:00:00.000Z",
  });
  assert.equal(depositLog.payload.paymentPurpose, "deposit");
  assert.equal(depositLog.payload.amount, 1500);
});

test("已入帳的人工付款文件不可再視為可確認", () => {
  assert.equal(isSettledManualPayment({status: "paid"}), true);
  assert.equal(isSettledManualPayment({status: "pending"}), false);
  assert.equal(isSettledManualPayment(null), false);
  const first = planManualInitialPayment(daycareBase({payAmountType: "full"}));
  const second = planManualInitialPayment(daycareBase({
    payAmountType: "full",
    paidAmount: first.paidAmount,
    paymentStatus: first.paymentStatus,
  }));
  assert.equal(first.paidAmount, 5000);
  assert.equal(second.ok, false);
  assert.equal(first.paymentDocId, second.paymentDocId || "manual_initial_day1");
  assert.equal(first.paymentDocId, "manual_initial_day1");
});
