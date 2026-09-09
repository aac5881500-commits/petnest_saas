// 檔案名稱：functions/payments/apply_booking_payment.js
// 功能說明：綠界付款成功後，住宿／安親共用的 booking 彙總更新（不含 Firestore 寫入）

const {
  normalizeInteger,
  normalizeString,
  resolveDepositAmount,
  resolvePaidAmount,
  resolveTotalAmount,
} = require("./payment_verify");

/**
 * 是否為可更新 bookings 的付款來源。
 * store_order 走商城訂單；其餘（booking／daycare／空值）視為預約訂單。
 *
 * @param {Object} payment 付款紀錄
 * @return {boolean}
 */
function isBookingPaymentSource(payment) {
  const sourceType = normalizeString(payment && payment.sourceType)
      .toLowerCase();
  return sourceType !== "store_order";
}

/**
 * 解析付款對應的 bookingId。
 * 相容只寫在 sourceId、或 sourceType 標成 daycare 的舊資料。
 *
 * @param {Object} payment 付款紀錄
 * @return {string}
 */
function resolvePaymentBookingId(payment) {
  const data = payment && typeof payment === "object" ? payment : {};
  const bookingId = normalizeString(data.bookingId);
  if (bookingId) {
    return bookingId;
  }
  if (!isBookingPaymentSource(data)) {
    return "";
  }
  return normalizeString(data.sourceId);
}

/**
 * @param {Object} booking 訂單
 * @return {boolean}
 */
function isDaycareBooking(booking) {
  const data = booking && typeof booking === "object" ? booking : {};
  return normalizeString(data.bookingKind).toLowerCase() === "daycare" ||
    normalizeString(data.serviceType).toLowerCase() === "daycare";
}

/**
 * @param {Object} booking 訂單
 * @return {boolean}
 */
function isPendingConfirmableStatus(booking) {
  const status = normalizeString(booking && booking.status).toLowerCase();
  return status === "pending" || status === "pending_confirmation";
}

/**
 * @param {Object} payment 付款紀錄
 * @return {boolean}
 */
function isDepositPaymentRecord(payment) {
  const data = payment && typeof payment === "object" ? payment : {};
  const purpose = normalizeString(data.paymentPurpose).toLowerCase();
  const amountType = normalizeString(data.amountType).toLowerCase();
  return purpose === "deposit" || amountType === "deposit";
}

/**
 * 綠界實際付款成功後，計算 payments／bookings 應寫入的彙總欄位。
 * 不寫入 depositExpireAt。已 paid 的付款紀錄不重複加款。
 *
 * @param {Object} params
 * @param {Object} params.payment 付款紀錄
 * @param {Object} params.booking 訂單
 * @param {string} params.paymentId
 * @param {string} params.merchantTradeNo
 * @param {string} params.gatewayTradeNo
 * @param {number} params.callbackAmount
 * @return {Object}
 */
function buildSuccessfulEcpayBookingPaymentUpdates(params) {
  const payment = params.payment || {};
  const booking = params.booking || {};
  const paymentId = normalizeString(params.paymentId);
  const merchantTradeNo = normalizeString(params.merchantTradeNo);
  const gatewayTradeNo = normalizeString(params.gatewayTradeNo);
  const callbackAmount = normalizeInteger(params.callbackAmount);

  if (normalizeString(payment.status).toLowerCase() === "paid") {
    return {alreadyPaid: true};
  }

  const savedMerchantTradeNo = normalizeString(payment.merchantTradeNo);
  if (!savedMerchantTradeNo || savedMerchantTradeNo !== merchantTradeNo) {
    throw new Error("交易編號已變更，停止更新訂單。");
  }

  if (normalizeInteger(payment.amount) !== callbackAmount) {
    throw new Error("付款紀錄金額與 Callback 不一致。");
  }

  const bookingTotalAmount = resolveTotalAmount(booking);
  if (bookingTotalAmount <= 0) {
    throw new Error("訂單總金額不正確，停止更新付款彙總。");
  }

  const currentPaidAmount = resolvePaidAmount(booking);
  const newPaidAmount = currentPaidAmount + callbackAmount;
  const safePaidAmount = Math.min(newPaidAmount, bookingTotalAmount);
  const remainingAmount = Math.max(bookingTotalAmount - safePaidAmount, 0);
  const daycare = isDaycareBooking(booking);
  const paymentStatus = remainingAmount <= 0 ?
    "paid" :
    (daycare ? "partial" : "partially_paid");

  const lastPaymentMethod = normalizeString(payment.paymentMethod);
  const lastPaymentPurpose = normalizeString(payment.paymentPurpose);
  const bookingCode = normalizeString(booking.bookingCode);

  const paymentUpdate = {
    status: "paid",
    gatewayStatus: "payment_success",
    bookingCode,
    callbackAmount,
    gatewayTradeNo,
  };

  const bookingUpdate = {
    paidAmount: safePaidAmount,
    remainingAmount,
    paymentStatus,
    lastPaymentId: paymentId,
    lastMerchantTradeNo: merchantTradeNo,
    lastGatewayTradeNo: gatewayTradeNo,
    lastPaymentAmount: callbackAmount,
    lastPaymentMethod,
    lastPaymentPurpose,
  };

  if (remainingAmount <= 0) {
    bookingUpdate.markPaidAt = true;
  }

  const depositAmount = resolveDepositAmount(booking);
  const reachedDeposit = depositAmount > 0 && safePaidAmount >= depositAmount;
  const confirmDeposit = reachedDeposit && (
    isDepositPaymentRecord(payment) ||
    (daycare && (
      lastPaymentPurpose === "full" ||
      normalizeString(payment.amountType).toLowerCase() === "full"
    ))
  );

  if (confirmDeposit) {
    bookingUpdate.depositPaid = true;
    bookingUpdate.depositStatus = "confirmed";
    bookingUpdate.markDepositPaidAt = true;
    if (isPendingConfirmableStatus(booking)) {
      bookingUpdate.status = "confirmed";
      bookingUpdate.markConfirmedAt = true;
    }
  }

  return {
    alreadyPaid: false,
    paymentUpdate,
    bookingUpdate,
  };
}

module.exports = {
  buildSuccessfulEcpayBookingPaymentUpdates,
  isBookingPaymentSource,
  isDaycareBooking,
  resolvePaymentBookingId,
};
