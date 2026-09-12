/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/adjust_booking_settlement.js
// 功能說明：調整最終應收、店內確認收退款、補款方式、轉帳核對與鎖單；冪等 requestId。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  writeActionLog,
} = require("../daycare/daycare_utils");
const {
  expectedTotal,
  settlementFields,
  isSettlementLocked,
  isSettlementConfirmed,
  canLock,
  toInt,
  stampDaycareClearStatus,
} = require("./booking_settlement_math");
const {
  isSettlementTopUpMethodAvailable,
  normalizeMethodId,
} = require("../payments/shop_payment_methods");

const ALLOWED_COLLECT = ["cash", "transfer"];
const ALLOWED_REFUND = ["cash", "transfer", "other"];

async function requireBookingPerm(uid, shopId, booking) {
  const daycare = normalizeString(booking.bookingKind) === "daycare" ||
    normalizeString(booking.serviceType) === "daycare";
  const key = daycare ? "manage_daycare_bookings" : "manage_bookings";
  const alt = daycare ? "manage_bookings" : "manage_daycare_bookings";
  const ok = isRootAdmin(uid) ||
    await hasShopPermission(shopId, uid, key) ||
    await hasShopPermission(shopId, uid, alt);
  if (!ok) {
    throw new HttpsError("permission-denied", "沒有執行此操作的權限");
  }
}

function assertNotCancelled(booking) {
  if (normalizeString(booking.status) === "cancelled") {
    throw new HttpsError("failed-precondition", "已取消的訂單無法調整款項");
  }
}

function assertNotLocked(booking) {
  if (isSettlementLocked(booking)) {
    throw new HttpsError("failed-precondition", "訂單已鎖定，無法再修改");
  }
}

function applyLock(bookingUpdate, uid, reason, version) {
  bookingUpdate.settlementLocked = true;
  bookingUpdate.settlementLockedAt = admin.firestore.FieldValue.serverTimestamp();
  bookingUpdate.settlementLockedBy = uid || "system";
  bookingUpdate.settlementLockedReason = reason;
  bookingUpdate.settlementVersion = version;
}

function maybeLock(nextBooking, bookingUpdate, uid, reason) {
  const merged = {...nextBooking, ...bookingUpdate};
  if (!canLock(merged)) {
    return false;
  }
  applyLock(
      bookingUpdate,
      uid,
      reason,
      toInt(nextBooking.settlementVersion, 0) + 1,
  );
  return true;
}

async function loadShop(shopId) {
  const snap = await admin.firestore().collection("shops").doc(shopId).get();
  return snap.data() || {};
}

function assertTopUpMethod(shop, method) {
  const id = normalizeMethodId(method);
  if (!isSettlementTopUpMethodAvailable(shop, id)) {
    throw new HttpsError(
        "failed-precondition",
        "店家尚未啟用此補款方式，請先至付款設定開啟。",
    );
  }
  return id;
}

exports.adjustBookingSettlement = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const action = normalizeString(data.action);
      const requestId = normalizeString(data.requestId) ||
        `${action}_${Date.now()}`;
      if (!shopId || !bookingId || !action) {
        throw new HttpsError("invalid-argument", "缺少必要參數");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const opRef = firestore.collection("shops").doc(shopId)
          .collection("settlement_ops").doc(requestId);
      const bookingSnap0 = await bookingRef.get();
      if (!bookingSnap0.exists) {
        throw new HttpsError("not-found", "找不到訂單");
      }
      const booking0 = bookingSnap0.data() || {};
      if (normalizeString(booking0.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "訂單店家不一致");
      }
      await requireBookingPerm(uid, shopId, booking0);
      const shop = await loadShop(shopId);

      if (action === "preview") {
        const manual = data.manualAdjust == null ?
          undefined : toInt(data.manualAdjust, 0);
        return {ok: true, ...settlementFields(booking0, manual)};
      }

      const pendingQuery = firestore.collection("payments")
          .where("bookingId", "==", bookingId)
          .where("status", "==", "pending");

      const result = await firestore.runTransaction(async (transaction) => {
        const bookingSnap = await transaction.get(bookingRef);
        const opSnap = await transaction.get(opRef);
        if (!bookingSnap.exists) {
          throw new HttpsError("not-found", "找不到訂單");
        }
        if (opSnap.exists) {
          return opSnap.data() || {ok: true, reused: true};
        }
        const booking = bookingSnap.data() || {};
        assertNotCancelled(booking);
        assertNotLocked(booking);

        const now = admin.firestore.FieldValue.serverTimestamp();
        let payload = {};
        let bookingUpdate = {};
        let paymentWrite = null;

        if (action === "applyAdjust") {
          if (!isSettlementConfirmed(booking) &&
              normalizeString(booking.status) !== "completed") {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          const manualAdjust = toInt(data.manualAdjust, 0);
          const reason = normalizeString(data.reason);
          if (manualAdjust !== 0 && !reason) {
            throw new HttpsError("invalid-argument", "調整金額不為零時請填寫原因");
          }
          const before = expectedTotal(booking);
          const fields = settlementFields(booking, manualAdjust);
          const history = Array.isArray(booking.settlementAdjustments) ?
            booking.settlementAdjustments.slice() : [];
          history.push({
            before,
            after: fields.expectedTotal,
            delta: fields.expectedTotal - before,
            manualAdjust,
            reason,
            operatorUid: uid,
            createdAt: new Date().toISOString(),
          });
          bookingUpdate = {
            manualAdjust,
            lastManualAdjustReason: reason,
            settlementAdjustments: history,
            quotedTotalPrice: fields.quotedTotalPrice,
            totalPayableAmount: fields.expectedTotal,
            totalPrice: fields.expectedTotal,
            totalAmount: fields.expectedTotal,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paymentStatus: fields.paymentStatus,
            appTopUpRequested: fields.remainingAmount > 0,
            settlementConfirmed: true,
            updatedAt: now,
          };
          if (fields.remainingAmount <= 0) {
            bookingUpdate.settlementTopUpStatus = "none";
          }
          payload = {
            before,
            after: fields.expectedTotal,
            delta: fields.expectedTotal - before,
            reason,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
          };
        } else if (action === "confirmCollect") {
          const amount = toInt(data.amount, 0);
          const method = normalizeString(data.method) || "cash";
          if (amount <= 0) {
            throw new HttpsError("invalid-argument", "請輸入收款金額");
          }
          if (!ALLOWED_COLLECT.includes(method)) {
            throw new HttpsError("invalid-argument", "不支援的收款方式");
          }
          if (method === "cash" || method === "transfer") {
            assertTopUpMethod(shop, method);
          }
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          const due = settlementFields(booking).remainingAmount;
          if (amount > due) {
            throw new HttpsError(
                "failed-precondition",
                `待補款為 ${due}，不可超過此金額`,
            );
          }
          const paid = toInt(booking.paidAmount, 0) + amount;
          const next = settlementFields({...booking, paidAmount: paid});
          bookingUpdate = {
            paidAmount: paid,
            remainingAmount: next.remainingAmount,
            refundDueAmount: next.refundDueAmount,
            paymentStatus: next.paymentStatus,
            lastPaymentMethod: method,
            lastPaymentPurpose: "balance",
            lastPaymentAmount: amount,
            paymentUpdatedAt: now,
            settlementTopUpStatus: next.remainingAmount > 0 ?
              booking.settlementTopUpStatus || "selected" : "collected",
            updatedAt: now,
          };
          if (next.remainingAmount <= 0) {
            bookingUpdate.paidAt = now;
          }
          paymentWrite = {
            ref: firestore.collection("payments").doc(),
            data: {
              shopId,
              bookingId,
              userId: normalizeString(booking.userId),
              bookingCode: normalizeString(booking.bookingCode),
              sourceType: "booking",
              sourceId: bookingId,
              amount,
              status: "paid",
              paymentMethod: method,
              paymentPurpose: "balance",
              amountType: "balance",
              channel: "in_shop",
              requestId,
              createdAt: now,
              paidAt: now,
              recordedByUid: uid,
            },
          };
          maybeLock(
              {...booking, paidAmount: paid},
              bookingUpdate,
              uid,
              "top_up_collected",
          );
          payload = {
            amount,
            method,
            remainingAmount: next.remainingAmount,
            locked: bookingUpdate.settlementLocked === true,
          };
        } else if (action === "confirmRefund") {
          const amount = toInt(data.amount, 0);
          const method = normalizeString(data.method) || "cash";
          if (amount <= 0) {
            throw new HttpsError("invalid-argument", "請輸入退款金額");
          }
          if (!ALLOWED_REFUND.includes(method)) {
            throw new HttpsError("invalid-argument", "不支援的退款方式");
          }
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          const due = settlementFields(booking).refundDueAmount;
          if (amount > due) {
            throw new HttpsError(
                "failed-precondition",
                `待退款為 ${due}，不可超過此金額`,
            );
          }
          const refunded = toInt(booking.refundAmount, 0) + amount;
          const next = settlementFields({...booking, refundAmount: refunded});
          bookingUpdate = {
            refundAmount: refunded,
            remainingAmount: next.remainingAmount,
            refundDueAmount: next.refundDueAmount,
            paymentStatus: next.paymentStatus,
            lastRefundMethod: method,
            lastRefundAmount: amount,
            lastRefundChannel: "manual_in_shop",
            updatedAt: now,
          };
          paymentWrite = {
            ref: firestore.collection("payments").doc(),
            data: {
              shopId,
              bookingId,
              userId: normalizeString(booking.userId),
              bookingCode: normalizeString(booking.bookingCode),
              sourceType: "booking",
              sourceId: bookingId,
              amount,
              status: "refunded",
              paymentMethod: method,
              paymentPurpose: "refund",
              amountType: "refund",
              channel: "in_shop",
              refundChannel: "manual_in_shop",
              autoRefund: false,
              requestId,
              createdAt: now,
              refundedAt: now,
              recordedByUid: uid,
            },
          };
          maybeLock(
              {...booking, refundAmount: refunded},
              bookingUpdate,
              uid,
              "refund_completed",
          );
          payload = {
            amount,
            method,
            refundDueAmount: next.refundDueAmount,
            locked: bookingUpdate.settlementLocked === true,
          };
        } else if (action === "requestAppTopUp" || action === "switchTopUpMethod") {
          const fields = settlementFields(booking);
          if (fields.remainingAmount <= 0) {
            throw new HttpsError("failed-precondition", "目前沒有待補款");
          }
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          const method = assertTopUpMethod(
              shop,
              normalizeString(data.method) ||
                normalizeString(booking.settlementTopUpMethod),
          );
          bookingUpdate = {
            appTopUpRequested: method !== "cash",
            settlementTopUpMethod: method,
            settlementTopUpStatus: method === "transfer" ?
              "awaiting_proof" : "selected",
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paymentStatus: fields.paymentStatus,
            settlementTopUpSwitchAt: now,
            updatedAt: now,
          };
          payload = {remainingAmount: fields.remainingAmount, method};
        } else if (action === "confirmTransferTopUp") {
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          if (normalizeMethodId(booking.settlementTopUpMethod) !== "transfer") {
            throw new HttpsError("failed-precondition", "目前不是銀行轉帳補款");
          }
          if (normalizeString(booking.settlementTopUpStatus) !== "pending_review") {
            throw new HttpsError("failed-precondition", "沒有待核對的轉帳證明");
          }
          const ok = data.approved !== false;
          const reviewReason = normalizeString(data.reviewReason);
          if (!ok && !reviewReason) {
            throw new HttpsError("invalid-argument", "核對失敗請填寫原因");
          }
          if (!ok) {
            bookingUpdate = {
              settlementTopUpStatus: "rejected",
              settlementTopUpReviewReason: reviewReason,
              updatedAt: now,
            };
            payload = {approved: false, reviewReason};
          } else {
            const amount = settlementFields(booking).remainingAmount;
            if (amount <= 0) {
              throw new HttpsError("failed-precondition", "目前沒有待補款");
            }
            const paid = toInt(booking.paidAmount, 0) + amount;
            const next = settlementFields({...booking, paidAmount: paid});
            bookingUpdate = {
              paidAmount: paid,
              remainingAmount: next.remainingAmount,
              refundDueAmount: next.refundDueAmount,
              paymentStatus: next.paymentStatus,
              lastPaymentMethod: "transfer",
              lastPaymentPurpose: "balance",
              lastPaymentAmount: amount,
              settlementTopUpStatus: "collected",
              paymentUpdatedAt: now,
              updatedAt: now,
            };
            paymentWrite = {
              ref: firestore.collection("payments").doc(),
              data: {
                shopId,
                bookingId,
                userId: normalizeString(booking.userId),
                bookingCode: normalizeString(booking.bookingCode),
                sourceType: "booking",
                sourceId: bookingId,
                amount,
                status: "paid",
                paymentMethod: "transfer",
                paymentPurpose: "balance",
                amountType: "balance",
                channel: "bank_transfer",
                requestId,
                createdAt: now,
                paidAt: now,
                recordedByUid: uid,
                proofUrl: normalizeString(booking.settlementTopUpTransferImageUrl),
              },
            };
            maybeLock(
                {...booking, paidAmount: paid},
                bookingUpdate,
                uid,
                "transfer_top_up_collected",
            );
            payload = {approved: true, amount, locked: bookingUpdate.settlementLocked === true};
          }
        } else if (action === "confirmNoTopUpAndLock") {
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          const fields = settlementFields(booking);
          if (fields.remainingAmount > 0) {
            throw new HttpsError(
                "failed-precondition",
                "仍有待補款，請先調整最終應收或完成收款",
            );
          }
          if (fields.refundDueAmount > 0) {
            throw new HttpsError(
                "failed-precondition",
                "仍有待退款，完成退款後才能鎖定",
            );
          }
          bookingUpdate = {
            remainingAmount: 0,
            refundDueAmount: 0,
            paymentStatus: fields.paymentStatus,
            settlementTopUpStatus: "none",
            appTopUpRequested: false,
            updatedAt: now,
          };
          applyLock(
              bookingUpdate,
              uid,
              "confirmed_no_top_up",
              toInt(booking.settlementVersion, 0) + 1,
          );
          payload = {locked: true};
        } else {
          throw new HttpsError("invalid-argument", `不支援的操作：${action}`);
        }

        stampDaycareClearStatus(
            booking,
            settlementFields({...booking, ...bookingUpdate}),
            bookingUpdate,
        );
        if (bookingUpdate.status === "completed" && !booking.completedAt) {
          bookingUpdate.completedAt = now;
        }
        transaction.update(bookingRef, bookingUpdate);
        if (paymentWrite) {
          transaction.set(paymentWrite.ref, paymentWrite.data);
        }
        const opResult = {
          ok: true,
          action,
          bookingId,
          ...payload,
        };
        transaction.set(opRef, {
          ...opResult,
          createdAt: now,
          operatorUid: uid,
        });
        return opResult;
      });

      if (!result.reused) {
        await writeActionLog({
          shopId,
          targetType: "booking",
          targetId: bookingId,
          bookingKind: normalizeString(booking0.bookingKind) ||
            normalizeString(booking0.serviceType),
          action: `settlement_${action}`,
          operatorUid: uid,
          operatorRole: isRootAdmin(uid) ? "root" : "staff",
          payload: result,
        });
      }
      return result;
    },
);
