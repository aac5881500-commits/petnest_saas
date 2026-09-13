/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/adjust_booking_settlement.js
// 功能說明：調整最終應收、店內確認收退款、補款方式、轉帳核對與鎖單；冪等 requestId。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  toDate,
  serviceDateKey,
  writeActionLog,
} = require("../daycare/daycare_utils");
const {
  expectedTotal,
  settlementFields,
  isSettlementLocked,
  isSettlementConfirmed,
  canLock,
  toInt,
  isDaycareBooking,
  stampDaycareClearStatus,
} = require("./booking_settlement_math");
const {
  isSettlementTopUpMethodAvailable,
  normalizeMethodId,
} = require("../payments/shop_payment_methods");
const {
  isActivePayment,
  isBalanceFamily,
  isDepositFamily,
  supersedeStalePendingPayments,
} = require("../payments/payment_record");
const {
  applySettlementPaymentDirection,
  assertRefundMethod,
} = require("./settlement_payment_direction");

const ALLOWED_COLLECT = ["cash", "transfer"];

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

function labelTime(value) {
  const date = toDate(value);
  if (!date) {
    return "";
  }
  return date.toLocaleString("zh-TW", {timeZone: "Asia/Taipei"});
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

function normalizeProofPurpose(value) {
  const raw = normalizeString(value) || "deposit";
  if (raw === "top_up" || raw === "additional" || raw === "balance") {
    return "balance";
  }
  if (raw === "deposit") {
    return "deposit";
  }
  return "deposit";
}

function proofSubmittedMs(proof) {
  const data = proof && typeof proof === "object" ? proof : {};
  const value = data.submittedAt;
  if (!value) {
    return 0;
  }
  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  if (value._seconds != null) {
    return Number(value._seconds) * 1000;
  }
  if (value.seconds != null) {
    return Number(value.seconds) * 1000;
  }
  const parsed = new Date(value);
  const ms = parsed.getTime();
  return Number.isFinite(ms) ? ms : 0;
}

function hasProofImage(proof) {
  const data = proof && typeof proof === "object" ? proof : {};
  return Boolean(normalizeString(data.imageUrl));
}

function isProofConfirmed(proof) {
  const data = proof && typeof proof === "object" ? proof : {};
  return data.confirmedAt != null && data.confirmedAt !== "";
}

function listPaymentProofs(booking) {
  const bookingData = booking && typeof booking === "object" ? booking : {};
  return Array.isArray(bookingData.paymentProofs) ?
    bookingData.paymentProofs.filter((item) => item && typeof item === "object") :
    [];
}

function missingBalanceProofMessage(proofs) {
  const list = Array.isArray(proofs) ? proofs : [];
  const hasDepositImage = list.some((item) => {
    return normalizeProofPurpose(item.purpose) === "deposit" && hasProofImage(item);
  });
  const hasBalanceImage = list.some((item) => {
    return normalizeProofPurpose(item.purpose) === "balance" && hasProofImage(item);
  });
  if (hasDepositImage && !hasBalanceImage) {
    return "尚未提交結算尾款轉帳證明";
  }
  return "沒有待核對的結算尾款轉帳證明";
}

/**
 * 從 paymentProofs[] 選出待核對結算尾款照片；不讀寫 legacy 圖片欄位。
 *
 * @param {Array} proofs
 * @param {string} proofId
 * @return {{proof?: Object, index?: number, error?: string, alreadyConfirmed?: boolean}}
 */
function selectBalanceProofForReview(proofs, proofId) {
  const list = Array.isArray(proofs) ? proofs : [];
  const wantedId = normalizeString(proofId);
  if (wantedId) {
    const index = list.findIndex((item) => normalizeString(item.proofId) === wantedId);
    if (index < 0) {
      return {error: missingBalanceProofMessage(list)};
    }
    const proof = list[index];
    if (normalizeProofPurpose(proof.purpose) !== "balance" || !hasProofImage(proof)) {
      return {error: missingBalanceProofMessage(list)};
    }
    if (isProofConfirmed(proof)) {
      return {proof, index, alreadyConfirmed: true};
    }
    return {proof, index};
  }
  let index = -1;
  let bestMs = -1;
  for (let i = 0; i < list.length; i += 1) {
    const item = list[i];
    if (normalizeProofPurpose(item.purpose) !== "balance") {
      continue;
    }
    if (!hasProofImage(item) || isProofConfirmed(item)) {
      continue;
    }
    const ms = proofSubmittedMs(item);
    if (index < 0 || ms >= bestMs) {
      index = i;
      bestMs = ms;
    }
  }
  if (index < 0) {
    return {error: missingBalanceProofMessage(list)};
  }
  return {proof: list[index], index};
}

function stayDateKeys(booking) {
  const start = toDate((booking || {}).startDate);
  const end = toDate((booking || {}).endDate);
  if (!start || !end) {
    return [];
  }
  const keys = [];
  const endKey = serviceDateKey(end);
  let cursor = new Date(start.getTime());
  let guard = 0;
  while (serviceDateKey(cursor) < endKey && guard < 400) {
    keys.push(serviceDateKey(cursor));
    cursor = new Date(cursor.getTime() + (24 * 60 * 60 * 1000));
    guard += 1;
  }
  return keys;
}

function applyDirectionFields(bookingUpdate, fields, data, shop, booking) {
  const topUpMethod = normalizeMethodId(
      data.settlementTopUpMethod || data.topUpMethod || "",
  );
  const refundMethod = normalizeString(
      data.settlementRefundMethod || data.refundMethod ||
        (booking && booking.settlementRefundMethod) || "",
  ) || (fields.refundDueAmount > 0 &&
    fields.remainingAmount <= 0 ? "cash" : "");
  const refundNote = normalizeString(
      data.settlementRefundNote || data.refundNote ||
        (booking && booking.settlementRefundNote) || "",
  );
  const dir = applySettlementPaymentDirection({
    remainingAmount: fields.remainingAmount,
    refundDueAmount: fields.refundDueAmount,
    topUpMethod,
    refundMethod,
    refundNote,
  });
  bookingUpdate.appTopUpRequested = dir.appTopUpRequested;
  if (dir.showTopUp) {
    if (dir.settlementTopUpMethod) {
      assertTopUpMethod(shop, dir.settlementTopUpMethod);
      bookingUpdate.settlementTopUpMethod = dir.settlementTopUpMethod;
      bookingUpdate.settlementTopUpStatus = dir.settlementTopUpStatus ||
        (dir.settlementTopUpMethod === "transfer" ?
          "awaiting_proof" : "selected");
    }
    bookingUpdate.settlementRefundMethod = "";
    bookingUpdate.settlementRefundNote = "";
  } else if (dir.showRefund) {
    try {
      assertRefundMethod(dir.settlementRefundMethod, dir.settlementRefundNote);
    } catch (error) {
      throw new HttpsError(
          error.code || "invalid-argument",
          error.message || "請選擇退款方式",
      );
    }
    bookingUpdate.settlementTopUpMethod = "";
    bookingUpdate.settlementTopUpStatus = "none";
    bookingUpdate.settlementRefundMethod = dir.settlementRefundMethod;
    bookingUpdate.settlementRefundNote = dir.settlementRefundNote;
  } else {
    bookingUpdate.settlementTopUpMethod = "";
    bookingUpdate.settlementTopUpStatus = "none";
    bookingUpdate.settlementRefundMethod = "";
    bookingUpdate.settlementRefundNote = "";
  }
}

function uniqueImageUrls(values) {
  const out = [];
  const seen = new Set();
  (Array.isArray(values) ? values : []).forEach((item) => {
    const url = normalizeString(item);
    if (!url || seen.has(url)) {
      return;
    }
    seen.add(url);
    out.push(url);
  });
  return out;
}

function patchProofs(proofs, index, patch) {
  const list = Array.isArray(proofs) ? proofs.map((item) => {
    return item && typeof item === "object" ? {...item} : {};
  }) : [];
  if (index < 0 || index >= list.length) {
    return list;
  }
  list[index] = {...list[index], ...patch};
  return list;
}

exports.normalizeProofPurpose = normalizeProofPurpose;
exports.selectBalanceProofForReview = selectBalanceProofForReview;
exports.missingBalanceProofMessage = missingBalanceProofMessage;
exports.patchProofs = patchProofs;
exports.stayDateKeys = stayDateKeys;

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

      const relatedPaymentsQuery = firestore.collection("payments")
          .where("bookingId", "==", bookingId);

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
        const relatedPaySnap = await transaction.get(relatedPaymentsQuery);
        const calendarDeletes = [];
        if (action === "checkOutStay") {
          const roomId = normalizeString(booking.roomId);
          if (roomId && booking.stayRoomReleased !== true) {
            stayDateKeys(booking).forEach((dateKey) => {
              calendarDeletes.push(
                  firestore.collection("shops").doc(shopId)
                      .collection("room_calendar")
                      .doc(`${roomId}_${dateKey}`),
              );
            });
          }
        }
        for (let i = 0; i < calendarDeletes.length; i += 1) {
          await transaction.get(calendarDeletes[i]);
        }

        if (action === "checkOutStay") {
          if (isDaycareBooking(booking)) {
            throw new HttpsError(
                "failed-precondition",
                "安親訂單請使用安親結算",
            );
          }
          const status = normalizeString(booking.status);
          if (status !== "checked_in" &&
              status !== "checked_out" &&
              status !== "completed") {
            throw new HttpsError(
                "failed-precondition",
                "僅入住中訂單可辦理退房",
            );
          }
          const manualAdjust = toInt(data.manualAdjust, 0);
          const reason = normalizeString(data.reason);
          if (manualAdjust !== 0 && !reason) {
            throw new HttpsError("invalid-argument", "調整金額不為零時請填寫原因");
          }
          const evidenceUrls = uniqueImageUrls(data.evidenceImageUrls);
          const alreadyEnded = Boolean(
              booking.checkOutAt ||
              booking.checkedOutAt ||
              status === "checked_out" ||
              status === "completed" ||
              booking.stayRoomReleased === true,
          );
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
            manualAdjustmentReason: reason,
            manualAdjustReason: reason,
            settlementAdjustments: history,
            quotedTotalPrice: fields.quotedTotalPrice,
            totalPayableAmount: fields.expectedTotal,
            totalPrice: fields.expectedTotal,
            totalAmount: fields.expectedTotal,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paymentStatus: fields.remainingAmount > 0 ?
              "awaiting_supplement" : fields.paymentStatus,
            settlementConfirmed: true,
            settlementConfirmedAt: alreadyEnded ?
              (booking.settlementConfirmedAt || now) : now,
            settledAt: alreadyEnded ? (booking.settledAt || now) : now,
            settledBy: alreadyEnded ? (booking.settledBy || uid) : uid,
            updatedAt: now,
          };
          if (!alreadyEnded) {
            bookingUpdate.checkOutAt = now;
            bookingUpdate.checkedOutAt = now;
          }
          applyDirectionFields(bookingUpdate, fields, data, shop, booking);
          if (evidenceUrls.length > 0) {
            bookingUpdate.settlementEvidenceUrls =
              admin.firestore.FieldValue.arrayUnion(...evidenceUrls);
            bookingUpdate.extraChargeImages =
              admin.firestore.FieldValue.arrayUnion(...evidenceUrls);
          }
          if (booking.stayRoomReleased !== true) {
            calendarDeletes.forEach((ref) => {
              transaction.delete(ref);
            });
            bookingUpdate.stayRoomReleased = true;
          }
          if (fields.remainingAmount <= 0 &&
              fields.refundDueAmount <= 0 &&
              data.lockIfClear !== false) {
            applyLock(
                bookingUpdate,
                uid,
                alreadyEnded ? "readjust_cleared" : "settlement_cleared",
                toInt(booking.settlementVersion, 0) + 1,
            );
          }
          payload = {
            before,
            after: fields.expectedTotal,
            delta: fields.expectedTotal - before,
            oldFinalReceivable: before,
            newFinalReceivable: fields.expectedTotal,
            adjustAmount: fields.expectedTotal - before,
            reason,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paidAmount: toInt(booking.paidAmount, 0),
            finalPaidAmount: toInt(booking.paidAmount, 0),
            refundMethod: normalizeString(
                bookingUpdate.settlementRefundMethod ||
                data.refundMethod || booking.settlementRefundMethod,
            ),
            settlementRefundMethod: normalizeString(
                bookingUpdate.settlementRefundMethod ||
                booking.settlementRefundMethod,
            ),
            locked: bookingUpdate.settlementLocked === true,
            stayRoomReleased: bookingUpdate.stayRoomReleased === true ||
              booking.stayRoomReleased === true,
            actualCheckInAt: labelTime(booking.checkInAt),
            actualCheckOutAt: alreadyEnded ?
              labelTime(booking.checkOutAt || booking.checkedOutAt) :
              "本次結算",
            checkInAtLabel: labelTime(booking.checkInAt),
            checkOutAtLabel: alreadyEnded ?
              labelTime(booking.checkOutAt || booking.checkedOutAt) :
              "本次結算",
          };
        } else if (action === "applyAdjust") {
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
            manualAdjustmentReason: reason,
            manualAdjustReason: reason,
            settlementAdjustments: history,
            quotedTotalPrice: fields.quotedTotalPrice,
            totalPayableAmount: fields.expectedTotal,
            totalPrice: fields.expectedTotal,
            totalAmount: fields.expectedTotal,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paymentStatus: fields.paymentStatus,
            settlementConfirmed: true,
            updatedAt: now,
          };
          applyDirectionFields(bookingUpdate, fields, data, shop, booking);
          payload = {
            before,
            after: fields.expectedTotal,
            delta: fields.expectedTotal - before,
            oldFinalReceivable: before,
            newFinalReceivable: fields.expectedTotal,
            adjustAmount: fields.expectedTotal - before,
            reason,
            remainingAmount: fields.remainingAmount,
            refundDueAmount: fields.refundDueAmount,
            paidAmount: toInt(booking.paidAmount, 0),
            finalPaidAmount: toInt(booking.paidAmount, 0),
            refundMethod: normalizeString(
                bookingUpdate.settlementRefundMethod ||
                data.refundMethod || booking.settlementRefundMethod,
            ),
            settlementRefundMethod: normalizeString(
                bookingUpdate.settlementRefundMethod ||
                booking.settlementRefundMethod,
            ),
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
              amountType: "full",
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
          const refundNote = normalizeString(
              data.refundNote || data.reason || data.settlementRefundNote,
          );
          let refundMethod;
          try {
            refundMethod = assertRefundMethod(method, refundNote);
          } catch (error) {
            throw new HttpsError(
                error.code || "invalid-argument",
                error.message || "請選擇退款方式",
            );
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
            lastRefundMethod: refundMethod,
            lastRefundAmount: amount,
            lastRefundReason: refundNote,
            lastRefundBy: uid,
            lastRefundAt: now,
            lastRefundChannel: "manual_in_shop",
            settlementRefundMethod: refundMethod,
            settlementRefundNote: refundMethod === "other" ? refundNote : "",
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
              paymentMethod: refundMethod,
              paymentPurpose: "refund",
              amountType: "refund",
              channel: "in_shop",
              refundChannel: "manual_in_shop",
              refundNote,
              refundReason: refundNote,
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
        } else if (action === "confirmStaffVerifiedTransfer") {
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          if (normalizeMethodId(booking.settlementTopUpMethod) !== "transfer") {
            throw new HttpsError("failed-precondition", "目前不是銀行轉帳補款");
          }
          const note = normalizeString(
              data.transferVerificationNote || data.note,
          );
          if (!note) {
            throw new HttpsError("invalid-argument", "請填寫現場核對註記");
          }
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
            settlementTopUpMethod: "transfer",
            settlementTopUpStatus: "collected",
            settlementTopUpCollectedAt: now,
            settlementTopUpCollectedBy: uid,
            paymentVerificationMode: "staff_verified_no_image",
            transferVerifiedAt: now,
            transferVerifiedBy: uid,
            transferVerificationNote: note,
            paymentUpdatedAt: now,
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
              paymentMethod: "transfer",
              paymentPurpose: "balance",
              amountType: "full",
              channel: "bank_transfer",
              paymentVerificationMode: "staff_verified_no_image",
              transferVerificationNote: note,
              note: "店員現場核對轉帳，未上傳照片",
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
              "staff_verified_transfer",
          );
          payload = {
            amount,
            method: "transfer",
            remainingAmount: next.remainingAmount,
            locked: bookingUpdate.settlementLocked === true,
            paymentVerificationMode: "staff_verified_no_image",
          };
        } else if (action === "confirmTransferTopUp") {
          if (!isSettlementConfirmed(booking)) {
            throw new HttpsError("failed-precondition", "請先完成結算確認");
          }
          if (normalizeMethodId(booking.settlementTopUpMethod) !== "transfer") {
            throw new HttpsError("failed-precondition", "目前不是銀行轉帳補款");
          }
          const proofs = listPaymentProofs(booking);
          const selected = selectBalanceProofForReview(
              proofs,
              normalizeString(data.proofId),
          );
          if (selected.error) {
            throw new HttpsError("failed-precondition", selected.error);
          }
          const ok = data.approved !== false;
          const reviewReason = normalizeString(data.reviewReason);
          if (!ok && !reviewReason) {
            throw new HttpsError("invalid-argument", "核對失敗請填寫原因");
          }
          const proofNow = admin.firestore.Timestamp.now();
          if (!ok) {
            bookingUpdate = {
              paymentProofs: patchProofs(proofs, selected.index, {
                rejectedAt: proofNow,
                rejectedBy: uid,
                reviewReason,
              }),
              settlementTopUpStatus: "rejected",
              settlementTopUpReviewReason: reviewReason,
              updatedAt: now,
            };
            payload = {
              approved: false,
              reviewReason,
              proofId: normalizeString(selected.proof.proofId),
            };
          } else if (selected.alreadyConfirmed) {
            bookingUpdate = {
              updatedAt: now,
            };
            payload = {
              approved: true,
              amount: 0,
              duplicate: true,
              proofId: normalizeString(selected.proof.proofId),
            };
          } else {
            const amount = settlementFields(booking).remainingAmount;
            if (amount <= 0) {
              throw new HttpsError("failed-precondition", "目前沒有待補款");
            }
            const paid = toInt(booking.paidAmount, 0) + amount;
            const next = settlementFields({...booking, paidAmount: paid});
            bookingUpdate = {
              paymentProofs: patchProofs(proofs, selected.index, {
                confirmedAt: proofNow,
                confirmedBy: uid,
              }),
              paidAmount: paid,
              remainingAmount: next.remainingAmount,
              refundDueAmount: next.refundDueAmount,
              paymentStatus: next.paymentStatus,
              lastPaymentMethod: "transfer",
              lastPaymentPurpose: "balance",
              lastPaymentAmount: amount,
              settlementTopUpStatus: "collected",
              settlementTopUpCollectedAt: now,
              settlementTopUpCollectedBy: uid,
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
                amountType: "full",
                channel: "bank_transfer",
                requestId,
                createdAt: now,
                paidAt: now,
                recordedByUid: uid,
                proofUrl: normalizeString(selected.proof.imageUrl),
                proofId: normalizeString(selected.proof.proofId),
              },
            };
            maybeLock(
                {...booking, paidAmount: paid},
                bookingUpdate,
                uid,
                "transfer_top_up_collected",
            );
            payload = {
              approved: true,
              amount,
              locked: bookingUpdate.settlementLocked === true,
              proofId: normalizeString(selected.proof.proofId),
            };
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
        if (action === "applyAdjust" || action === "checkOutStay") {
          const expectedRemain = toInt(bookingUpdate.remainingAmount, 0);
          relatedPaySnap.docs.forEach((doc) => {
            const payment = doc.data() || {};
            if (!isActivePayment(payment)) {
              return;
            }
            if (!isBalanceFamily(payment) &&
                String(payment.amountType || "").toLowerCase() !== "full") {
              return;
            }
            if (isDepositFamily(payment)) {
              return;
            }
            if (toInt(payment.amount, 0) === expectedRemain) {
              return;
            }
            supersedeStalePendingPayments(transaction, [doc]);
          });
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
