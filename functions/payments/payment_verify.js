// functions/payments/payment_verify.js
// 🔐 金流付款驗證工具
// 功能：驗證訂單存在、會員身分、訂單狀態與付款狀態，
// 並由後端重新計算訂金或全額付款金額，避免前端竄改金額。

const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

/**
 * 將未知資料安全轉成字串
 *
 * @param {*} value 原始資料
 * @return {string}
 */
function normalizeString(value) {
  return (value || "").toString().trim();
}

/**
 * 將未知資料安全轉成整數
 *
 * @param {*} value 原始資料
 * @return {number}
 */
function normalizeInteger(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }

  const parsedValue = Number.parseInt(
      normalizeString(value),
      10,
  );

  return Number.isFinite(parsedValue) ? parsedValue : 0;
}

/**
 * 取得訂單目前已付款金額
 *
 * 相容可能存在的欄位：
 * paidAmount、paymentPaidAmount
 *
 * @param {Object} booking 訂單資料
 * @return {number}
 */
function resolvePaidAmount(booking) {
  const paidAmount = normalizeInteger(booking.paidAmount);

  if (paidAmount > 0) {
    return paidAmount;
  }

  return normalizeInteger(booking.paymentPaidAmount);
}

/**
 * 取得訂單總金額
 *
 * 相容可能存在的欄位：
 * total、totalAmount、finalAmount
 *
 * @param {Object} booking 訂單資料
 * @return {number}
 */
function resolveTotalAmount(booking) {
  const totalPayableAmount = normalizeInteger(
      booking.totalPayableAmount,
  );

  if (totalPayableAmount > 0) {
    return totalPayableAmount;
  }

  const totalPrice = normalizeInteger(
      booking.totalPrice,
  );

  if (totalPrice > 0) {
    return totalPrice;
  }

  const finalAmount = normalizeInteger(
      booking.finalAmount,
  );

  if (finalAmount > 0) {
    return finalAmount;
  }

  const totalAmount = normalizeInteger(
      booking.totalAmount,
  );

  if (totalAmount > 0) {
    return totalAmount;
  }

  return normalizeInteger(
      booking.total,
  );
}

/**
 * 取得訂單要求的訂金金額
 *
 * 相容可能存在的欄位：
 * depositAmount、requiredDeposit、deposit
 *
 * @param {Object} booking 訂單資料
 * @return {number}
 */
function resolveDepositAmount(booking) {
  const depositAmount = normalizeInteger(
      booking.depositAmount,
  );

  if (depositAmount > 0) {
    return depositAmount;
  }

  const requiredDeposit = normalizeInteger(
      booking.requiredDeposit,
  );

  if (requiredDeposit > 0) {
    return requiredDeposit;
  }

  return normalizeInteger(booking.deposit);
}

/**
 * 計算本次實際應付款金額
 *
 * 所有金額都由後端訂單資料重新計算，
 * 不採用 Flutter 傳入的 amount。
 *
 * amountType：
 * deposit：支付尚未付清的訂金
 * full：支付訂單剩餘全部金額
 *
 * @param {Object} params 計算參數
 * @param {Object} params.booking 訂單資料
 * @param {string} params.amountType deposit 或 full
 * @return {number}
 */
function resolveRequestedPaymentAmount({
  booking,
  amountType,
}) {
  const normalizedAmountType = normalizeString(
      amountType,
  ).toLowerCase();

  const totalAmount = resolveTotalAmount(booking);
  const paidAmount = resolvePaidAmount(booking);

  const remainingAmount = Math.max(
      totalAmount - paidAmount,
      0,
  );

  if (totalAmount <= 0) {
    throw new HttpsError(
        "failed-precondition",
        "訂單金額不正確，暫時無法付款。",
    );
  }

  if (remainingAmount <= 0) {
    throw new HttpsError(
        "already-exists",
        "這筆訂單已沒有待付款金額。",
    );
  }

  if (normalizedAmountType === "full") {
    return remainingAmount;
  }

  if (normalizedAmountType !== "deposit") {
    throw new HttpsError(
        "invalid-argument",
        "付款金額類型不正確。",
    );
  }

  const depositAmount = resolveDepositAmount(booking);

  if (depositAmount <= 0) {
    throw new HttpsError(
        "failed-precondition",
        "這筆訂單沒有可支付的訂金金額。",
    );
  }

  const remainingDepositAmount = Math.max(
      depositAmount - paidAmount,
      0,
  );

  if (remainingDepositAmount <= 0) {
    throw new HttpsError(
        "already-exists",
        "這筆訂單的訂金已經付清。",
    );
  }

  return Math.min(
      remainingDepositAmount,
      remainingAmount,
  );
}

/**
 * 判斷訂單是否已經全額付款
 *
 * @param {Object} booking 訂單資料
 * @return {boolean}
 */
function isBookingFullyPaid(booking) {
  const paymentStatus = normalizeString(
      booking.paymentStatus,
  ).toLowerCase();

  if (
    paymentStatus === "paid" ||
    paymentStatus === "fully_paid" ||
    paymentStatus === "completed"
  ) {
    return true;
  }

  const totalAmount = resolveTotalAmount(booking);
  const paidAmount = resolvePaidAmount(booking);

  return totalAmount > 0 && paidAmount >= totalAmount;
}

/**
 * 驗證訂單是否可以建立付款
 *
 * @param {Object} params 驗證參數
 * @param {string} params.bookingId 訂單 ID
 * @param {string} params.userId 登入會員 UID
 * @param {string=} params.expectedShopId 前端傳入的店家 ID
 * @return {Promise<Object>}
 */
async function verifyBookingForPayment({
  bookingId,
  userId,
  expectedShopId = "",
}) {
  const normalizedBookingId = normalizeString(bookingId);
  const normalizedUserId = normalizeString(userId);
  const normalizedExpectedShopId =
    normalizeString(expectedShopId);

  if (!normalizedBookingId) {
    throw new HttpsError(
        "invalid-argument",
        "缺少訂單編號。",
    );
  }

  if (!normalizedUserId) {
    throw new HttpsError(
        "unauthenticated",
        "請先登入會員。",
    );
  }

  const bookingRef = admin
      .firestore()
      .collection("bookings")
      .doc(normalizedBookingId);

  const bookingSnapshot = await bookingRef.get();

  if (!bookingSnapshot.exists) {
    throw new HttpsError(
        "not-found",
        "找不到指定的訂單。",
    );
  }

  const booking = bookingSnapshot.data() || {};

  const bookingUserId = normalizeString(booking.userId);
  const bookingShopId = normalizeString(booking.shopId);
  const bookingStatus = normalizeString(
      booking.status,
  ).toLowerCase();

  if (!bookingUserId) {
    throw new HttpsError(
        "failed-precondition",
        "訂單缺少會員資料，暫時無法付款。",
    );
  }

  if (bookingUserId !== normalizedUserId) {
    throw new HttpsError(
        "permission-denied",
        "你沒有支付這筆訂單的權限。",
    );
  }

  if (!bookingShopId) {
    throw new HttpsError(
        "failed-precondition",
        "訂單缺少店家資料，暫時無法付款。",
    );
  }

  if (
    normalizedExpectedShopId &&
    bookingShopId !== normalizedExpectedShopId
  ) {
    throw new HttpsError(
        "invalid-argument",
        "訂單與店家資料不一致。",
    );
  }

  if (bookingStatus === "cancelled") {
    throw new HttpsError(
        "failed-precondition",
        "這筆訂單已取消，無法付款。",
    );
  }

  if (bookingStatus === "completed") {
    throw new HttpsError(
        "failed-precondition",
        "這筆訂單已完成，無法再建立付款。",
    );
  }

  if (isBookingFullyPaid(booking)) {
    throw new HttpsError(
        "already-exists",
        "這筆訂單已完成付款，請勿重複操作。",
    );
  }

  const totalAmount = resolveTotalAmount(booking);
  const paidAmount = resolvePaidAmount(booking);

  const remainingAmount = Math.max(
      totalAmount - paidAmount,
      0,
  );

  if (totalAmount <= 0) {
    throw new HttpsError(
        "failed-precondition",
        "訂單金額不正確，暫時無法付款。",
    );
  }

  return {
    bookingRef,
    bookingSnapshot,
    booking,
    bookingId: normalizedBookingId,
    userId: normalizedUserId,
    shopId: bookingShopId,
    status: bookingStatus,
    totalAmount,
    paidAmount,
    remainingAmount,
  };
}

/**
 * 驗證商城訂單是否可付款
 *
 * @param {Object} params
 * @param {string} params.shopId
 * @param {string} params.orderId
 * @param {string} params.userId
 * @return {Promise<Object>}
 */
async function verifyStoreOrderForPayment({
  shopId,
  orderId,
  userId,
}) {
  const normalizedShopId = normalizeString(shopId);
  const normalizedOrderId = normalizeString(orderId);
  const normalizedUserId = normalizeString(userId);

  if (!normalizedShopId || !normalizedOrderId) {
    throw new HttpsError("invalid-argument", "缺少商城訂單資料。");
  }

  const orderRef = admin.firestore()
      .collection("shops")
      .doc(normalizedShopId)
      .collection("store_orders")
      .doc(normalizedOrderId);
  const orderSnapshot = await orderRef.get();

  if (!orderSnapshot.exists) {
    throw new HttpsError("not-found", "找不到商城訂單。");
  }

  const order = orderSnapshot.data() || {};

  if (normalizeString(order.userId) !== normalizedUserId) {
    throw new HttpsError("permission-denied", "這不是你的商城訂單。");
  }

  if (normalizeString(order.shopId) !== normalizedShopId) {
    throw new HttpsError("failed-precondition", "商城訂單店家不一致。");
  }

  const status = normalizeString(order.status);
  const paymentStatus = normalizeString(order.paymentStatus);

  if (status === "cancelled") {
    const cancelReason = normalizeString(order.cancelReason);
    if (cancelReason.indexOf("過期") >= 0 ||
      cancelReason.indexOf("逾時") >= 0) {
      throw new HttpsError(
          "deadline-exceeded",
          "庫存保留已過期，請重新下單。",
      );
    }
    throw new HttpsError("failed-precondition", "訂單已取消。");
  }

  if (status === "completed" || paymentStatus === "paid") {
    throw new HttpsError("failed-precondition", "訂單已付款。");
  }

  if (status !== "pending_payment") {
    throw new HttpsError("failed-precondition", "此訂單目前不可付款。");
  }

  const totalAmount = normalizeInteger(order.totalAmount);
  if (totalAmount <= 0) {
    throw new HttpsError("failed-precondition", "訂單金額不正確。");
  }

  return {
    orderRef,
    order,
    orderId: normalizedOrderId,
    orderCode: normalizeString(order.orderCode),
    shopId: normalizedShopId,
    userId: normalizedUserId,
    customerName: normalizeString(order.customerName),
    totalAmount,
    paidAmount: 0,
  };
}

module.exports = {
  normalizeString,
  normalizeInteger,
  resolvePaidAmount,
  resolveTotalAmount,
  resolveDepositAmount,
  resolveRequestedPaymentAmount,
  isBookingFullyPaid,
  verifyBookingForPayment,
  verifyStoreOrderForPayment,
};
