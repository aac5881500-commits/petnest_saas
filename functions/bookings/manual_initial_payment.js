/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/manual_initial_payment.js
// 功能說明：銀行轉帳等人工確認，依客戶下單時的 deposit／full 寫入同一套付款結果。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  resolveBookingKind,
  writeActionLog,
} = require("../daycare/daycare_utils");
const {
  resolveDepositAmount,
  resolvePaidAmount,
  resolveTotalAmount,
} = require("../payments/payment_verify");

const BOOKING_KIND_DAYCARE = "daycare";

function isDaycareBooking(booking) {
  const data = booking && typeof booking === "object" ? booking : {};
  return normalizeString(data.bookingKind).toLowerCase() === BOOKING_KIND_DAYCARE ||
    normalizeString(data.serviceType).toLowerCase() === BOOKING_KIND_DAYCARE;
}

function explicitPurpose(value) {
  const text = normalizeString(value).toLowerCase();
  if (text === "full" || text === "deposit") {
    return text;
  }
  return "";
}

/**
 * 客戶下單時的付款目的。沒有明確欄位時維持舊訂單的訂金流程，不依金額猜全額。
 *
 * @param {Object} booking
 * @return {string}
 */
function resolveInitialPayAmountType(booking) {
  const data = booking && typeof booking === "object" ? booking : {};
  const fromChoice = explicitPurpose(data.payAmountType);
  if (fromChoice) {
    return fromChoice;
  }
  const fromPurpose = explicitPurpose(
      data.paymentPurpose || data.lastPaymentPurpose,
  );
  if (fromPurpose) {
    return fromPurpose;
  }
  const fromAmountType = explicitPurpose(data.amountType);
  if (fromAmountType) {
    return fromAmountType;
  }
  return "deposit";
}

function planManualInitialPayment(booking) {
  const data = booking && typeof booking === "object" ? booking : {};
  const purpose = resolveInitialPayAmountType(data);
  const payable = resolveTotalAmount(data);
  const deposit = resolveDepositAmount(data);
  const existingPaid = resolvePaidAmount(data);
  const daycare = isDaycareBooking(data);
  const target = purpose === "full" ? payable : deposit;
  if (purpose === "deposit" && deposit <= 0) {
    return {ok: false, message: "此訂單無需確認訂金"};
  }
  if (purpose === "full" && payable <= 0) {
    return {ok: false, message: "訂單應付金額不正確，無法確認全額"};
  }
  const depositConfirmed = data.depositPaid === true ||
    normalizeString(data.depositStatus) === "confirmed";
  if (purpose === "deposit" && depositConfirmed) {
    return {ok: false, message: "訂金已確認，不可重複執行"};
  }
  if (purpose === "full" && payable > 0 && existingPaid >= payable) {
    return {ok: false, message: "全額已確認，不可重複執行"};
  }
  const charge = Math.max(0, target - existingPaid);
  if (charge <= 0) {
    return {ok: false, message: "這筆訂單目前沒有待確認金額"};
  }
  const paidAmount = existingPaid + charge;
  const remainingAmount = Math.max(0, payable - paidAmount);
  let paymentStatus = "unpaid";
  if (payable > 0 && paidAmount >= payable) {
    paymentStatus = "paid";
  } else if (paidAmount > 0) {
    paymentStatus = daycare ? "partial" : "partially_paid";
  }
  const markDeposit = purpose === "deposit" || (daycare && purpose === "full");
  const status = normalizeString(data.status);
  const confirmBooking = status === "pending" ||
    status === "pending_confirmation" ||
    status === "unpaid";
  return {
    ok: true,
    purpose,
    amountType: purpose,
    paymentPurpose: purpose,
    amount: charge,
    depositAmount: deposit,
    paidAmount,
    remainingAmount,
    paymentStatus,
    markDeposit,
    confirmBooking,
    paymentMethod: normalizeString(data.paymentMethod) || "transfer",
    paymentDocId: `manual_initial_${normalizeString(data.id)}`,
  };
}

function isSettledManualPayment(data) {
  return normalizeString(data && data.status) === "paid";
}

function manualInitialPaymentFields(plan, params) {
  return {
    shopId: params.shopId,
    bookingId: params.bookingId,
    bookingCode: normalizeString(params.booking.bookingCode),
    userId: normalizeString(params.booking.userId),
    customerName: normalizeString(params.booking.customerName),
    sourceType: "booking",
    sourceId: params.bookingId,
    gateway: "manual",
    paymentMethod: plan.paymentMethod,
    amountType: plan.amountType,
    paymentPurpose: plan.paymentPurpose,
    amount: plan.amount,
    currency: "TWD",
    status: "paid",
    requestId: plan.paymentDocId,
    merchantTradeNo: "",
    description: plan.purpose === "full" ? "店家確認全額入帳" : "店家確認訂金",
    createdBy: params.uid,
    updatedBy: params.uid,
  };
}

function buildManualPaymentActionLog(plan, context) {
  return {
    action: "manual_payment_confirmed",
    type: "manual_payment_confirmed",
    payload: {
      bookingId: context.bookingId,
      shopId: context.shopId,
      actorUid: context.uid,
      paymentMethod: plan.paymentMethod,
      paymentPurpose: plan.paymentPurpose,
      amountType: plan.amountType,
      amount: plan.amount,
      depositAmount: plan.depositAmount,
      paidAmount: plan.paidAmount,
      remainingAmount: plan.remainingAmount,
      paymentStatus: plan.paymentStatus,
      paymentId: plan.paymentDocId,
      confirmedAt: context.confirmedAt,
    },
  };
}

function bookingUpdateFromPlan(plan) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const update = {
    paidAmount: plan.paidAmount,
    remainingAmount: plan.remainingAmount,
    paymentStatus: plan.paymentStatus,
    paymentConfirmedAt: now,
    lastPaymentAmount: plan.amount,
    lastPaymentMethod: plan.paymentMethod,
    lastPaymentPurpose: plan.paymentPurpose,
    paymentUpdatedAt: now,
    updatedAt: now,
  };
  if (plan.markDeposit) {
    update.depositPaid = true;
    update.depositStatus = "confirmed";
    update.depositPaidAt = now;
  }
  if (plan.paymentStatus === "paid") {
    update.paidAt = now;
  }
  if (plan.confirmBooking) {
    update.status = "confirmed";
    update.confirmedAt = now;
  }
  return update;
}

function paymentRecordFromPlan(plan, params) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    ...manualInitialPaymentFields(plan, params),
    paidAt: now,
    createdAt: now,
    updatedAt: now,
  };
}

async function applyManualInitialPayment(params) {
  const firestore = params.firestore || admin.firestore();
  const bookingRef = params.bookingRef;
  const bookingId = bookingRef.id;
  let applied = null;
  await firestore.runTransaction(async (transaction) => {
    const freshSnap = await transaction.get(bookingRef);
    if (!freshSnap.exists) {
      throw new HttpsError("not-found", "找不到訂單");
    }
    const current = freshSnap.data() || {};
    const plan = planManualInitialPayment({...current, id: bookingId});
    if (!plan.ok) {
      throw new HttpsError("failed-precondition", plan.message);
    }
    const paymentRef = firestore.collection("payments").doc(
        `manual_initial_${bookingId}`,
    );
    const paymentSnap = await transaction.get(paymentRef);
    if (paymentSnap.exists && isSettledManualPayment(paymentSnap.data())) {
      throw new HttpsError("failed-precondition", "款項已確認，不可重複執行");
    }
    const ready = {...plan, paymentDocId: paymentRef.id};
    transaction.set(paymentRef, paymentRecordFromPlan(ready, {
      shopId: params.shopId,
      bookingId,
      booking: current,
      uid: params.uid,
    }));
    const update = bookingUpdateFromPlan(ready);
    update.lastPaymentId = paymentRef.id;
    update.paymentConfirmedBy = params.uid;
    transaction.update(bookingRef, update);
    applied = ready;
  });
  const confirmedAt = admin.firestore.FieldValue.serverTimestamp();
  const actionLog = buildManualPaymentActionLog(applied, {
    shopId: params.shopId,
    bookingId,
    uid: params.uid,
    confirmedAt,
  });
  await writeActionLog({
    shopId: params.shopId,
    targetId: bookingId,
    bookingId,
    bookingKind: resolveBookingKind(params.booking || {}),
    action: actionLog.action,
    type: actionLog.type,
    operatorUid: params.uid,
    operatorRole: "staff",
    payload: actionLog.payload,
  });
  return {
    ok: true,
    // Legacy response action. Daycare callers still send confirmDeposit.
    action: "confirmDeposit",
    paymentPurpose: applied.paymentPurpose,
    amountType: applied.amountType,
    amount: applied.amount,
    paidAmount: applied.paidAmount,
    remainingAmount: applied.remainingAmount,
    paymentStatus: applied.paymentStatus,
    depositPaid: applied.markDeposit ? true : false,
    depositStatus: applied.markDeposit ? "confirmed" : "",
    paymentId: applied.paymentDocId,
  };
}

const confirmManualBookingPayment = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      // 金額與付款目的只讀訂單。不採用 request 的 amount、payAmountType。
      const bookingId = normalizeString(request.data && request.data.bookingId);
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單");
      }
      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const snap = await bookingRef.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "找不到訂單");
      }
      const booking = snap.data() || {};
      const shopId = normalizeString(booking.shopId);
      const daycare = isDaycareBooking(booking);
      const permission = daycare ?
        "manage_daycare_bookings" : "manage_bookings";
      const allowed = isRootAdmin(uid) ||
        await hasShopPermission(shopId, uid, permission) ||
        await hasShopPermission(shopId, uid, "manage_bookings");
      if (!allowed) {
        throw new HttpsError("permission-denied", "沒有確認付款的權限");
      }
      return applyManualInitialPayment({
        firestore,
        bookingRef,
        booking,
        uid,
        shopId,
      });
    },
);

module.exports = {
  resolveInitialPayAmountType,
  planManualInitialPayment,
  isSettledManualPayment,
  manualInitialPaymentFields,
  buildManualPaymentActionLog,
  applyManualInitialPayment,
  confirmManualBookingPayment,
};
