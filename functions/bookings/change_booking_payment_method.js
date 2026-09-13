/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/change_booking_payment_method.js
// 功能說明：客戶變更住宿／安親付款方式；不改總額、訂金金額與付款期限。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  normalizeString,
  writeActionLog,
} = require("../daycare/daycare_utils");
const {
  remainingDue,
  isSettlementLocked,
  isSettlementConfirmed,
} = require("./booking_settlement_math");
const {
  isCustomerMethodAvailable,
  normalizeMethodId,
} = require("../payments/shop_payment_methods");
const {
  isActivePayment,
  supersedeStalePendingPayments,
} = require("../payments/payment_record");

const ONLINE_METHODS = ["credit_card", "atm", "cvs"];

function isOnlineMethod(method) {
  return ONLINE_METHODS.includes(normalizeMethodId(method));
}

function assertCustomerCanChangePaymentMethod(booking, uid) {
  if (normalizeString(booking.userId) !== normalizeString(uid)) {
    const error = new Error("僅訂單本人可變更付款方式");
    error.code = "permission-denied";
    throw error;
  }
  const status = normalizeString(booking.status);
  if (status === "cancelled") {
    const error = new Error("已取消的訂單無法變更付款方式");
    error.code = "failed-precondition";
    throw error;
  }
  if (isSettlementLocked(booking)) {
    const error = new Error("訂單已鎖定，無法變更付款方式");
    error.code = "failed-precondition";
    throw error;
  }
  if (isSettlementConfirmed(booking)) {
    if (remainingDue(booking) <= 0) {
      const error = new Error("目前沒有待補款，無法變更付款方式");
      error.code = "failed-precondition";
      throw error;
    }
    return "settlement_top_up";
  }
  if (status === "completed" || status === "checked_in") {
    const error = new Error("訂單進行中或已完成，無法變更付款方式");
    error.code = "failed-precondition";
    throw error;
  }
  return "deposit";
}

function buildCustomerPaymentMethodPatch(params) {
  const paymentMethod = normalizeMethodId(params.paymentMethod);
  const mode = params.mode;
  const payAmountType = normalizeString(params.payAmountType);
  if (mode === "settlement_top_up") {
    return {
      settlementTopUpMethod: paymentMethod,
      settlementTopUpStatus: paymentMethod === "transfer" ?
        "awaiting_proof" : "selected",
      paymentChoiceChangedAt: params.now,
      updatedAt: params.now,
    };
  }
  const patch = {
    paymentMethod,
    depositStatus: paymentMethod === "transfer" ? "awaiting_proof" : "unpaid",
    paymentChoiceChangedAt: params.now,
    updatedAt: params.now,
  };
  if (payAmountType === "deposit" || payAmountType === "full") {
    patch.payAmountType = payAmountType;
  }
  return patch;
}

function httpsFrom(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  return new HttpsError(error.code || "internal", error.message || "操作失敗");
}

exports.assertCustomerCanChangePaymentMethod =
  assertCustomerCanChangePaymentMethod;
exports.buildCustomerPaymentMethodPatch = buildCustomerPaymentMethodPatch;
exports.isOnlineMethod = isOnlineMethod;

exports.changeBookingPaymentMethod = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const paymentMethod = normalizeMethodId(data.paymentMethod);
      const payAmountType = normalizeString(data.payAmountType);
      if (!shopId || !bookingId || !paymentMethod) {
        throw new HttpsError("invalid-argument", "缺少必要參數");
      }
      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const result = await firestore.runTransaction(async (transaction) => {
        const bookingSnap = await transaction.get(bookingRef);
        if (!bookingSnap.exists) {
          throw new HttpsError("not-found", "找不到訂單");
        }
        const booking = bookingSnap.data() || {};
        if (normalizeString(booking.shopId) !== shopId) {
          throw new HttpsError("permission-denied", "訂單店家不一致");
        }
        let mode;
        try {
          mode = assertCustomerCanChangePaymentMethod(booking, uid);
        } catch (error) {
          throw httpsFrom(error);
        }
        const shopSnap = await transaction.get(
            firestore.collection("shops").doc(shopId),
        );
        const shop = shopSnap.data() || {};
        if (!isCustomerMethodAvailable(shop, paymentMethod)) {
          throw new HttpsError(
              "failed-precondition",
              "店家尚未啟用此付款方式",
          );
        }
        const previousMethod = normalizeString(booking.paymentMethod);
        const previousTopUp = normalizeString(booking.settlementTopUpMethod);
        const previousAmountType = normalizeString(booking.payAmountType);
        const now = admin.firestore.FieldValue.serverTimestamp();
        const patch = buildCustomerPaymentMethodPatch({
          mode,
          paymentMethod,
          payAmountType,
          now,
        });
        const paySnap = await transaction.get(
            firestore.collection("payments")
                .where("bookingId", "==", bookingId),
        );
        const stale = paySnap.docs.filter((doc) => {
          const payment = doc.data() || {};
          if (!isActivePayment(payment)) {
            return false;
          }
          const method = normalizeMethodId(payment.paymentMethod);
          return isOnlineMethod(method) || Boolean(payment.merchantTradeNo);
        });
        supersedeStalePendingPayments(transaction, stale, {
          reason: "payment_method_changed",
          label: "已失效（付款方式已變更）",
          gatewayStatus: "superseded_method_changed",
        });
        transaction.update(bookingRef, patch);
        return {
          ok: true,
          mode,
          paymentMethod,
          previousMethod: mode === "settlement_top_up" ?
            previousTopUp : previousMethod,
          previousPayAmountType: previousAmountType,
          payAmountType: patch.payAmountType || previousAmountType,
          needsEcpay: isOnlineMethod(paymentMethod),
        };
      });
      await writeActionLog({
        shopId,
        targetType: "booking",
        targetId: bookingId,
        action: "payment_choice_changed",
        operatorUid: uid,
        operatorRole: "customer",
        payload: {
          previousPaymentMethod: result.previousMethod,
          paymentMethod: result.paymentMethod,
          previousPayAmountType: result.previousPayAmountType,
          payAmountType: result.payAmountType,
          mode: result.mode,
        },
      });
      return result;
    },
);
