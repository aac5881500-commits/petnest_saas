// 檔案名稱：functions/payments/apply_booking_payment.test.js
// 功能說明：綠界付款成功後住宿／安親訂單彙總更新

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildSuccessfulEcpayBookingPaymentUpdates,
  isBookingPaymentSource,
  resolvePaymentBookingId,
} = require("./apply_booking_payment");

function payment(overrides = {}) {
  return {
    status: "pending",
    merchantTradeNo: "TN123",
    amount: 500,
    paymentMethod: "credit_card",
    paymentPurpose: "deposit",
    amountType: "deposit",
    bookingId: "b1",
    sourceType: "booking",
    ...overrides,
  };
}

function stayBooking(overrides = {}) {
  return {
    bookingKind: "accommodation",
    status: "pending",
    totalPrice: 3000,
    depositAmount: 500,
    paidAmount: 0,
    bookingCode: "S-1",
    depositExpireAt: "keep-me",
    ...overrides,
  };
}

function daycareBooking(overrides = {}) {
  return {
    bookingKind: "daycare",
    serviceType: "daycare",
    status: "pending",
    quotedTotalPrice: 2000,
    totalPrice: 2000,
    depositAmount: 500,
    paidAmount: 0,
    bookingCode: "D-1",
    depositExpireAt: "keep-me",
    ...overrides,
  };
}

test("sourceType daycare 或空值仍視為可更新 booking", () => {
  assert.equal(isBookingPaymentSource({sourceType: "daycare"}), true);
  assert.equal(isBookingPaymentSource({sourceType: ""}), true);
  assert.equal(isBookingPaymentSource({sourceType: "booking"}), true);
  assert.equal(isBookingPaymentSource({sourceType: "store_order"}), false);
});

test("bookingId 可從 sourceId 回補", () => {
  assert.equal(
      resolvePaymentBookingId({
        sourceType: "daycare",
        sourceId: "dc-1",
      }),
      "dc-1",
  );
  assert.equal(
      resolvePaymentBookingId({
        bookingId: "b1",
        sourceId: "other",
      }),
      "b1",
  );
});

test("安親訂金信用卡成功 → confirmed，不覆寫 depositExpireAt", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment(),
    booking: daycareBooking(),
    paymentId: "p1",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G1",
    callbackAmount: 500,
  });
  assert.equal(result.alreadyPaid, false);
  assert.equal(result.paymentUpdate.status, "paid");
  assert.equal(result.bookingUpdate.paidAmount, 500);
  assert.equal(result.bookingUpdate.paymentStatus, "partial");
  assert.equal(result.bookingUpdate.depositPaid, true);
  assert.equal(result.bookingUpdate.depositStatus, "confirmed");
  assert.equal(result.bookingUpdate.status, "confirmed");
  assert.equal(result.bookingUpdate.markConfirmedAt, true);
  assert.equal(result.bookingUpdate.depositExpireAt, undefined);
});

test("重複 callback 不重複加款", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({status: "paid"}),
    booking: daycareBooking({paidAmount: 500}),
    paymentId: "p1",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G1",
    callbackAmount: 500,
  });
  assert.equal(result.alreadyPaid, true);
  assert.equal(result.bookingUpdate, undefined);
});

test("安親全額付款成功 → paymentStatus paid 並確認訂金", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 2000,
      paymentPurpose: "full",
      amountType: "full",
    }),
    booking: daycareBooking(),
    paymentId: "p2",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G2",
    callbackAmount: 2000,
  });
  assert.equal(result.bookingUpdate.paidAmount, 2000);
  assert.equal(result.bookingUpdate.remainingAmount, 0);
  assert.equal(result.bookingUpdate.paymentStatus, "paid");
  assert.equal(result.bookingUpdate.depositPaid, true);
  assert.equal(result.bookingUpdate.status, "confirmed");
  assert.equal(result.bookingUpdate.markPaidAt, true);
});

test("安親只寫 quotedTotalPrice 時仍可更新", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment(),
    booking: daycareBooking({
      totalPrice: 0,
      totalAmount: 0,
      quotedTotalPrice: 1800,
    }),
    paymentId: "p3",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G3",
    callbackAmount: 500,
  });
  assert.equal(result.bookingUpdate.paidAmount, 500);
  assert.equal(result.bookingUpdate.paymentStatus, "partial");
});

test("住宿訂金信用卡成功仍為 partially_paid 並 confirmed", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment(),
    booking: stayBooking(),
    paymentId: "p4",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G4",
    callbackAmount: 500,
  });
  assert.equal(result.bookingUpdate.paymentStatus, "partially_paid");
  assert.equal(result.bookingUpdate.depositPaid, true);
  assert.equal(result.bookingUpdate.status, "confirmed");
  assert.equal(result.bookingUpdate.depositExpireAt, undefined);
});

test("住宿全額付款不因安親規則改寫既有訂金確認條件", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 3000,
      paymentPurpose: "full",
      amountType: "full",
    }),
    booking: stayBooking(),
    paymentId: "p5",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G5",
    callbackAmount: 3000,
  });
  assert.equal(result.bookingUpdate.paymentStatus, "paid");
  assert.equal(result.bookingUpdate.depositPaid, undefined);
  assert.equal(result.bookingUpdate.status, undefined);
});

test("已 superseded 的交易仍可入帳且不重複加款於 paid", () => {
  const pending = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      status: "superseded",
      amount: 1000,
      paymentPurpose: "additional",
      amountType: "full",
    }),
    booking: daycareBooking({
      status: "checked_in",
      settlementConfirmed: true,
      quotedTotalPrice: 1000,
      manualAdjust: 800,
      totalPrice: 1800,
      totalPayableAmount: 1800,
      finalSettlementAmount: 1800,
      paidAmount: 500,
    }),
    paymentId: "old-1000",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G9",
    callbackAmount: 1000,
  });
  assert.equal(pending.alreadyPaid, false);
  assert.equal(pending.paymentUpdate.status, "paid");
  assert.equal(pending.bookingUpdate.paidAmount, 1500);
  assert.equal(pending.bookingUpdate.remainingAmount, 300);
  assert.equal(pending.bookingUpdate.status, "checked_in");
});

test("安親結算尾款信用卡成功 → completed 並鎖單", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 1300,
      paymentPurpose: "balance",
      amountType: "full",
    }),
    booking: daycareBooking({
      status: "checked_in",
      settlementConfirmed: true,
      quotedTotalPrice: 1800,
      totalPrice: 1800,
      totalPayableAmount: 1800,
      finalSettlementAmount: 1800,
      paidAmount: 500,
    }),
    paymentId: "p-bal",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G10",
    callbackAmount: 1300,
  });
  assert.equal(result.bookingUpdate.paidAmount, 1800);
  assert.equal(result.bookingUpdate.remainingAmount, 0);
  assert.equal(result.bookingUpdate.refundDueAmount, 0);
  assert.equal(result.bookingUpdate.status, "completed");
  assert.equal(result.bookingUpdate.settlementLocked, true);
  assert.equal(result.bookingUpdate.settlementLockedBy, "system");
  assert.equal(
      result.bookingUpdate.settlementLockedReason,
      "ecpay_top_up_cleared",
  );
  assert.equal(result.bookingUpdate.markCompletedAt, true);
  assert.equal(result.bookingUpdate.depositExpireAt, undefined);
});

test("安親結算後待補款不可 completed", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 200,
      paymentPurpose: "balance",
      amountType: "full",
    }),
    booking: daycareBooking({
      status: "checked_in",
      settlementConfirmed: true,
      quotedTotalPrice: 1800,
      totalPrice: 1800,
      finalSettlementAmount: 1800,
      paidAmount: 500,
    }),
    paymentId: "p-part",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G11",
    callbackAmount: 200,
  });
  assert.equal(result.bookingUpdate.remainingAmount, 1100);
  assert.equal(result.bookingUpdate.status, "checked_in");
});

test("安親結算後待退款不可 completed", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 500,
      paymentPurpose: "balance",
      amountType: "full",
    }),
    booking: daycareBooking({
      status: "checked_in",
      settlementConfirmed: true,
      quotedTotalPrice: 800,
      totalPrice: 800,
      finalSettlementAmount: 800,
      paidAmount: 500,
    }),
    paymentId: "p-over",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G12",
    callbackAmount: 500,
  });
  assert.equal(result.bookingUpdate.paidAmount, 1000);
  assert.equal(result.bookingUpdate.refundDueAmount, 200);
  assert.equal(result.bookingUpdate.status, "checked_in");
});

test("住宿不因安親結算規則改成 completed", () => {
  const result = buildSuccessfulEcpayBookingPaymentUpdates({
    payment: payment({
      amount: 3000,
      paymentPurpose: "full",
      amountType: "full",
    }),
    booking: stayBooking({
      settlementConfirmed: true,
      finalSettlementAmount: 3000,
      paidAmount: 0,
      status: "confirmed",
    }),
    paymentId: "p-stay",
    merchantTradeNo: "TN123",
    gatewayTradeNo: "G13",
    callbackAmount: 3000,
  });
  assert.equal(result.bookingUpdate.status, undefined);
});
