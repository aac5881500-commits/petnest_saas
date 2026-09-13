// 檔案名稱：functions/daycare/manage_daycare_booking.js
// 功能說明：臨托狀態、延長、超時、改價、取消、No-show

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_DAYCARE,
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  resolveBookingKind,
  serviceDateKey,
  toDate,
  toInt,
  writeActionLog,
} = require("./daycare_utils");
const {
  quote,
  remainingFromPaid,
  paymentStatusOf,
  shopLatePickupBreakdown,
} = require("./daycare_pricing");
const {
  assertAvailable,
  applyHoldReleaseFromSnap,
  calendarCleaningFields,
  holdIdentity,
  holdRefForBooking,
  listHoldEntries,
  loadActiveOccupancies,
  releaseOccupancyDocs,
  writeHoldEntries,
} = require("./daycare_occupancy");
const {computeEarnPoints} = require("./daycare_points");

function formatLogTime(value) {
  const date = toDate(value);
  if (!date) {
    return "";
  }
  return date.toLocaleString("zh-TW", {timeZone: "Asia/Taipei"});
}
const {
  applyBookingReport,
} = require("../reports/shop_report_summary");
const {
  paidAmount,
  remainingDue,
  refundDue,
  settlementFields,
  isSettlementLocked,
  stampDaycareClearStatus,
} = require("../bookings/booking_settlement_math");
const {
  isSettlementTopUpMethodAvailable,
  normalizeMethodId,
} = require("../payments/shop_payment_methods");
const {
  applySettlementPaymentDirection,
  assertRefundMethod,
} = require("../bookings/settlement_payment_direction");
const {
  isActivePayment,
  isBalanceFamily,
  isDepositFamily,
  supersedeStalePendingPayments,
} = require("../payments/payment_record");

function assertActualTimes(actualStart, actualEnd, now) {
  const current = now instanceof Date ? now : new Date();
  if (actualStart && actualStart.getTime() > current.getTime()) {
    throw new HttpsError("invalid-argument", "實際送達時間不可晚於目前時間");
  }
  if (actualEnd && actualEnd.getTime() > current.getTime()) {
    throw new HttpsError("invalid-argument", "實際接回時間不可晚於目前時間");
  }
  if (actualStart && actualEnd && actualEnd.getTime() < actualStart.getTime()) {
    throw new HttpsError("invalid-argument", "實際接回時間不可早於實際送達時間");
  }
}

exports.assertActualTimes = assertActualTimes;

/**
 * @param {string} uid
 * @param {string} shopId
 * @param {string} key
 */
async function requirePerm(uid, shopId, key) {
  const ok = await hasShopPermission(shopId, uid, key) ||
    (key === "manage_daycare_bookings" &&
      await hasShopPermission(shopId, uid, "manage_bookings"));
  if (!ok) {
    throw new HttpsError("permission-denied", "沒有執行此操作的權限");
  }
}

/**
 * 銀行轉帳等人工確認訂金：寫入付款狀態、金額、payments 與操作紀錄。
 * @param {Object} params
 */
async function applyManualDepositConfirm(params) {
  const booking = params.booking || {};
  const alreadyPaid = booking.depositPaid === true ||
    normalizeString(booking.depositStatus) === "confirmed";
  if (alreadyPaid) {
    throw new HttpsError("failed-precondition", "訂金已確認，不可重複執行");
  }
  const deposit = toInt(booking.depositAmount, 0);
  if (deposit <= 0) {
    throw new HttpsError("failed-precondition", "此訂單無需確認訂金");
  }
  const total = toInt(booking.totalPayableAmount, 0) ||
    toInt(booking.totalAmount, 0) ||
    toInt(booking.totalPrice, 0);
  const existingPaid = toInt(booking.paidAmount, 0);
  const paid = Math.max(existingPaid, deposit);
  const remaining = remainingFromPaid(total, paid);
  const paymentStatus = paymentStatusOf(paid, total);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const credited = Math.max(deposit, paid - existingPaid);
  const paymentMethod = normalizeString(booking.paymentMethod) || "transfer";
  const amountType = normalizeString(booking.payAmountType) === "full" ?
    "full" : "deposit";
  const firestore = admin.firestore();
  const paymentRef = firestore.collection("payments").doc();
  const currentStatus = normalizeString(booking.status);
  const update = {
    depositPaid: true,
    depositStatus: "confirmed",
    depositPaidAt: now,
    paidAmount: paid,
    remainingAmount: remaining,
    paymentStatus,
    paymentConfirmedAt: now,
    paymentConfirmedBy: params.uid,
    lastPaymentId: paymentRef.id,
    lastPaymentAmount: credited,
    lastPaymentMethod: paymentMethod,
    lastPaymentPurpose: amountType === "full" ? "full" : "deposit",
    paymentUpdatedAt: now,
    updatedAt: now,
  };
  if (currentStatus === "pending" || currentStatus === "pending_confirmation") {
    update.status = "confirmed";
    update.confirmedAt = now;
  }
  const batch = firestore.batch();
  batch.set(paymentRef, {
    shopId: params.shopId,
    bookingId: params.bookingRef.id,
    bookingCode: booking.bookingCode || "",
    userId: booking.userId || "",
    customerName: booking.customerName || "",
    sourceType: "booking",
    sourceId: params.bookingRef.id,
    gateway: "manual",
    paymentMethod,
    amountType,
    paymentPurpose: amountType === "full" ? "full" : "deposit",
    amount: credited,
    currency: "TWD",
    status: "paid",
    requestId: `manual_deposit_${params.bookingRef.id}`,
    merchantTradeNo: "",
    description: "店家確認訂金",
    paidAt: now,
    createdBy: params.uid,
    updatedBy: params.uid,
    createdAt: now,
    updatedAt: now,
  });
  batch.update(params.bookingRef, update);
  await batch.commit();
  await writeActionLog({
    shopId: params.shopId,
    targetId: params.bookingRef.id,
    action: "deposit_confirmed",
    operatorUid: params.uid,
    operatorRole: "staff",
    payload: {
      depositAmount: deposit,
      paidAmount: paid,
      remainingAmount: remaining,
      paymentStatus,
      paymentId: paymentRef.id,
    },
  });
  return {
    ok: true,
    action: "confirmDeposit",
    depositPaid: true,
    depositStatus: "confirmed",
    paidAmount: paid,
    remainingAmount: remaining,
    paymentStatus,
    paymentId: paymentRef.id,
    status: update.status || currentStatus,
  };
}

exports.manageDaycareBooking = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const payload = request.data || {};
      const shopId = normalizeString(payload.shopId);
      const bookingId = normalizeString(payload.bookingId);
      const action = normalizeString(payload.action);
      const requestId = normalizeString(payload.requestId);
      if (!shopId || !bookingId || !action) {
        throw new HttpsError("invalid-argument", "缺少必要參數");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      if (requestId) {
        const opRef = firestore.collection("shops").doc(shopId)
            .collection("daycare_ops").doc(requestId);
        const existing = await opRef.get();
        if (existing.exists) {
          return existing.data() || {ok: true, reused: true};
        }
      }

      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "找不到訂單");
      }
      const booking = bookingSnap.data() || {};
      if (resolveBookingKind(booking) !== BOOKING_KIND_DAYCARE) {
        throw new HttpsError("failed-precondition", "此訂單不是臨托訂單");
      }
      if (normalizeString(booking.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "訂單不屬於此店家");
      }

      const settingsSnap = await firestore.collection("shops").doc(shopId)
          .collection("daycare_settings").doc("main").get();
      const settings = settingsSnap.data() || {};
      const plan = booking.daycarePlanSnapshot || {};
      const now = admin.firestore.FieldValue.serverTimestamp();
      let result = {ok: true, action};

      if (action === "confirm") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        if (booking.status !== "pending" &&
            booking.status !== "pending_confirmation") {
          throw new HttpsError("failed-precondition", "僅待確認訂單可確認");
        }
        await bookingRef.update({
          status: "confirmed",
          confirmedAt: now,
          updatedAt: now,
        });
        await writeActionLog({
          shopId,
          targetId: bookingRef.id,
          action: "confirmed",
          operatorUid: uid,
          operatorRole: "staff",
          payload: {status: "confirmed"},
        });
      } else if (action === "confirmDeposit") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        result = await applyManualDepositConfirm({
          bookingRef,
          booking,
          uid,
          shopId,
        });
      } else if (action === "start") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        if (booking.status !== "confirmed") {
          throw new HttpsError("failed-precondition", "請先確認訂單後再入住");
        }
        if (!normalizeString(booking.roomId)) {
          throw new HttpsError("failed-precondition", "請先分配房間後再入住");
        }
        await bookingRef.update({
          status: "checked_in",
          actualStartAt: now,
          checkedInAt: now,
          updatedAt: now,
        });
      } else if (action === "previewSettle" || action === "complete" ||
          action === "settle") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        const alreadySettled = booking.settlementConfirmed === true ||
          booking.settledAt != null;
        if (isSettlementLocked(booking) && action !== "previewSettle") {
          throw new HttpsError("failed-precondition", "訂單已鎖定，無法再修改");
        }
        if (booking.status !== "checked_in" &&
            booking.status !== "completed" &&
            !alreadySettled) {
          throw new HttpsError("failed-precondition", "僅安親中訂單可結算");
        }
        const scheduledStart = toDate(booking.scheduledStartAt);
        const scheduledEnd = toDate(booking.scheduledEndAt);
        const actualStart = toDate(booking.actualStartAt);
        const actualEnd = alreadySettled ?
          (toDate(booking.actualEndAt) || toDate(payload.actualEndAt) ||
            new Date()) :
          (toDate(payload.actualEndAt) || new Date());
        if (!alreadySettled) {
          assertActualTimes(actualStart, actualEnd, new Date());
        }
        const quoted = toInt(
            booking.quotedTotalPrice != null ?
              booking.quotedTotalPrice : booking.totalPrice, 0,
        );
        const paid = paidAmount(booking);
        const pickup = shopLatePickupBreakdown(
            settings, scheduledEnd, actualEnd,
        );
        const originalOvertime = alreadySettled ?
          toInt(
              booking.settlementOriginalOvertimeAmount != null ?
                booking.settlementOriginalOvertimeAmount : booking.overtimeAmount,
              pickup.amount,
          ) :
          pickup.amount;
        const overtimeAmt = originalOvertime;
        const overtimeMinutes = pickup.extraMinutes;
        const rule = pickup.formula;
        const manualAdjust = toInt(payload.manualAdjust, 0);
        const manualReason = normalizeString(
            payload.manualAdjustmentReason || payload.manualAdjustReason,
        );
        if (manualAdjust !== 0 && !manualReason) {
          throw new HttpsError("invalid-argument", "請填寫手動調整原因");
        }
        const originalSettlementAmount = quoted;
        const finalSettlementAmount = Math.max(
            0, quoted + overtimeAmt + manualAdjust,
        );
        const moneyBooking = {
          ...booking,
          quotedTotalPrice: quoted,
          overtimeAmount: overtimeAmt,
          manualAdjust,
          paidAmount: paid,
        };
        const remaining = remainingDue(moneyBooking);
        const refundDueAmount = refundDue(moneyBooking);
        const scheduledMinutes = (scheduledStart && scheduledEnd) ?
          Math.max(0, Math.floor((scheduledEnd - scheduledStart) / 60000)) : 0;
        const actualMinutes = (actualStart && actualEnd) ?
          Math.max(0, Math.floor((actualEnd - actualStart) / 60000)) : 0;
        const settlement = {
          scheduledStartAt: booking.scheduledStartAt || null,
          scheduledEndAt: booking.scheduledEndAt || null,
          actualStartAt: booking.actualStartAt || null,
          actualEndAt: actualEnd.toISOString(),
          scheduledMinutes,
          actualMinutes,
          quotedTotal: quoted,
          originalSettlementAmount,
          overtimeMinutes,
          overtimeGraceMinutes: pickup.graceMinutes,
          billableMinutes: pickup.billableMinutes,
          overtimeUnits: pickup.units,
          overtimeUnitMinutes: pickup.unitMinutes,
          overtimeUnitPrice: pickup.unitPrice,
          overtimeFormula: pickup.formula,
          overtimeAmount: overtimeAmt,
          overtimeCharge: overtimeAmt,
          roundingLabel: rule,
          capAmount: 0,
          capAdjustment: 0,
          manualAdjust,
          manualAdjustmentAmount: manualAdjust,
          manualAdjustmentReason: manualReason,
          finalTotal: finalSettlementAmount,
          finalSettlementAmount,
          paidAmount: paid,
          finalPaidAmount: paid,
          remainingAmount: remaining,
          refundDueAmount,
          finalRemainingAmount: remaining,
          alreadySettled,
        };
        if (action === "previewSettle") {
          result = {ok: true, action, ...settlement};
        } else {
          const completeMode = normalizeString(payload.completeMode) ||
            "pending_balance";
          const fields = settlementFields(moneyBooking);
          let nextPaymentStatus = fields.paymentStatus;
          if (remaining > 0) {
            nextPaymentStatus = "awaiting_supplement";
          }
          const bookingUpdate = {
            overtimeMinutes: alreadySettled ?
              toInt(booking.overtimeMinutes, overtimeMinutes) : overtimeMinutes,
            overtimeAmount: overtimeAmt,
            originalSettlementAmount,
            overtimeCharge: overtimeAmt,
            manualAdjust,
            manualAdjustmentAmount: manualAdjust,
            manualAdjustmentReason: manualReason,
            lastManualAdjustReason: manualReason,
            manualAdjustReason: manualReason,
            finalSettlementAmount,
            finalPaidAmount: paid,
            finalRemainingAmount: remaining,
            quotedTotalPrice: quoted,
            totalPrice: finalSettlementAmount,
            totalPayableAmount: finalSettlementAmount,
            remainingAmount: remaining,
            refundDueAmount,
            paymentStatus: nextPaymentStatus,
            settleMode: completeMode,
            settlementConfirmed: true,
            settlementConfirmedAt: alreadySettled ?
              (booking.settlementConfirmedAt || now) : now,
            settledAt: alreadySettled ? (booking.settledAt || now) : now,
            settledBy: alreadySettled ? (booking.settledBy || uid) : uid,
            settlementOriginalOvertimeAmount: alreadySettled ?
              toInt(booking.settlementOriginalOvertimeAmount, originalOvertime) :
              originalOvertime,
            updatedAt: now,
          };
          stampDaycareClearStatus(booking, {
            remainingAmount: remaining,
            refundDueAmount,
          }, bookingUpdate);
          const shopSnap = await firestore.collection("shops").doc(shopId).get();
          const shopData = shopSnap.data() || {};
          const dir = applySettlementPaymentDirection({
            remainingAmount: remaining,
            refundDueAmount,
            topUpMethod: normalizeMethodId(
                payload.settlementTopUpMethod || payload.topUpMethod || "",
            ),
            refundMethod: normalizeString(
                payload.settlementRefundMethod || payload.refundMethod ||
                  booking.settlementRefundMethod || "",
            ) || (refundDueAmount > 0 && remaining <= 0 ? "cash" : ""),
            refundNote: normalizeString(
                payload.settlementRefundNote || payload.refundNote ||
                  booking.settlementRefundNote || "",
            ),
          });
          bookingUpdate.appTopUpRequested = dir.appTopUpRequested;
          if (dir.showTopUp) {
            if (dir.settlementTopUpMethod) {
              if (!isSettlementTopUpMethodAvailable(
                  shopData, dir.settlementTopUpMethod,
              )) {
                throw new HttpsError(
                    "failed-precondition",
                    "店家尚未啟用此補款方式，請先至付款設定開啟。",
                );
              }
              bookingUpdate.settlementTopUpMethod = dir.settlementTopUpMethod;
              bookingUpdate.settlementTopUpStatus = dir.settlementTopUpStatus ||
                (dir.settlementTopUpMethod === "transfer" ?
                  "awaiting_proof" : "selected");
            }
            bookingUpdate.settlementRefundMethod = "";
            bookingUpdate.settlementRefundNote = "";
          } else if (dir.showRefund) {
            try {
              assertRefundMethod(
                  dir.settlementRefundMethod, dir.settlementRefundNote,
              );
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
          if (!alreadySettled) {
            bookingUpdate.actualEndAt =
              admin.firestore.Timestamp.fromDate(actualEnd);
            bookingUpdate.checkedOutAt =
              admin.firestore.Timestamp.fromDate(actualEnd);
            if (bookingUpdate.status === "completed") {
              bookingUpdate.completedAt = now;
            }
          } else if (bookingUpdate.status === "completed" &&
              !booking.completedAt) {
            bookingUpdate.completedAt = now;
          }
          if (remaining <= 0 && refundDueAmount <= 0 &&
              payload.lockIfClear !== false) {
            bookingUpdate.settlementLocked = true;
            bookingUpdate.settlementLockedAt = now;
            bookingUpdate.settlementLockedBy = uid;
            bookingUpdate.settlementLockedReason = alreadySettled ?
              "readjust_cleared" : "settlement_cleared";
            bookingUpdate.settlementVersion =
              toInt(booking.settlementVersion, 0) + 1;
          }
          if (!alreadySettled) {
            const occSnap = await loadActiveOccupancies(
                firestore, shopId, bookingId,
            );
            const payQuery = firestore.collection("payments")
                .where("bookingId", "==", bookingId);
            const assignedRoomId = normalizeString(booking.roomId);
            const serviceDate = normalizeString(booking.serviceDate) ||
              (toDate(booking.scheduledStartAt) ?
                serviceDateKey(toDate(booking.scheduledStartAt)) : "");
            const cleaningCalRef = assignedRoomId && serviceDate ?
              firestore.collection("shops").doc(shopId)
                  .collection("room_calendar")
                  .doc(`${assignedRoomId}_${serviceDate}`) : null;
            await firestore.runTransaction(async (transaction) => {
              const holdBooking = holdIdentity(booking, bookingId, shopId);
              const holdRef = holdRefForBooking(firestore, holdBooking);
              const holdSnap = holdRef ?
                await transaction.get(holdRef) : null;
              for (const doc of occSnap.docs) {
                await transaction.get(doc.ref);
              }
              const paySnap = await transaction.get(payQuery);
              if (cleaningCalRef) {
                await transaction.get(cleaningCalRef);
              }
              releaseOccupancyDocs(transaction, occSnap.docs);
              applyHoldReleaseFromSnap(
                  transaction, holdRef, holdSnap, holdBooking,
              );
              paySnap.docs.forEach((doc) => {
                const payment = doc.data() || {};
                if (!isActivePayment(payment) || isDepositFamily(payment)) {
                  return;
                }
                if (!isBalanceFamily(payment)) {
                  return;
                }
                if (toInt(payment.amount, 0) === remaining) {
                  return;
                }
                supersedeStalePendingPayments(transaction, [doc]);
              });
              if (cleaningCalRef) {
                transaction.set(cleaningCalRef, {
                  ...calendarCleaningFields(
                      assignedRoomId, serviceDate, bookingId,
                  ),
                  roomName: normalizeString(booking.roomName),
                  cleaningStartedAt: now,
                  updatedAt: now,
                }, {merge: true});
              }
              transaction.update(bookingRef, bookingUpdate);
            });
            await issueOrRevokeDaycarePoints(firestore, {
              shopId,
              bookingId,
              booking: {
                ...booking,
                totalPrice: finalSettlementAmount,
                source: booking.source,
                userId: booking.userId,
                addons: booking.addons,
                overtimeAmount: overtimeAmt,
                specialDateSurchargeAmount: booking.specialDateSurchargeAmount,
                status: bookingUpdate.status || booking.status,
              },
              mode: "issue",
            });
          } else {
            const payQuery = firestore.collection("payments")
                .where("bookingId", "==", bookingId);
            await firestore.runTransaction(async (transaction) => {
              const paySnap = await transaction.get(payQuery);
              paySnap.docs.forEach((doc) => {
                const payment = doc.data() || {};
                if (!isActivePayment(payment) || isDepositFamily(payment)) {
                  return;
                }
                if (!isBalanceFamily(payment)) {
                  return;
                }
                if (toInt(payment.amount, 0) === remaining) {
                  return;
                }
                supersedeStalePendingPayments(transaction, [doc]);
              });
              transaction.update(bookingRef, bookingUpdate);
            });
          }
          result = {
            ok: true,
            action,
            ...settlement,
            paymentStatus: nextPaymentStatus,
            completeMode,
            locked: bookingUpdate.settlementLocked === true,
            actualStartAtLabel: formatLogTime(booking.actualStartAt),
            actualEndAtLabel: formatLogTime(
                bookingUpdate.actualEndAt || booking.actualEndAt,
            ),
            settlementRefundMethod: normalizeString(
                bookingUpdate.settlementRefundMethod ||
                booking.settlementRefundMethod,
            ),
            refundDueAmount,
          };
        }
      } else if (action === "cancel") {
        const isOwner = normalizeString(booking.userId) === uid;
        if (!isOwner) {
          await requirePerm(uid, shopId, "manage_daycare_bookings");
        } else if (!["pending", "confirmed"].includes(booking.status)) {
          throw new HttpsError(
              "failed-precondition",
              "臨托開始後請聯絡店家取消",
          );
        }
        if (["completed", "cancelled"].includes(booking.status)) {
          throw new HttpsError("failed-precondition", "目前狀態不可取消");
        }
        const refundDeposit = settings.refundDepositOnCancel !== false;
        const paid = toInt(booking.paidAmount, 0);
        const cancelUpdates = {
          status: "cancelled",
          cancelReason: normalizeString(payload.cancelReason),
          cancelBy: isOwner ? "member" : "staff",
          cancelledAt: now,
          updatedAt: now,
        };
        if (paid > 0) {
          cancelUpdates.refundStatus = refundDeposit ?
            "pending_manual" : "forfeited";
          cancelUpdates.refundAmount = refundDeposit ? paid : 0;
        }
        const occSnap = await loadActiveOccupancies(
            firestore, shopId, bookingId,
        );
        await firestore.runTransaction(async (transaction) => {
          const holdBooking = holdIdentity(booking, bookingId, shopId);
          const holdRef = holdRefForBooking(firestore, holdBooking);
          const holdSnap = holdRef ? await transaction.get(holdRef) : null;
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
          applyHoldReleaseFromSnap(
              transaction, holdRef, holdSnap, holdBooking,
          );
          transaction.update(bookingRef, cancelUpdates);
        });
        await restoreDaycareSpend(firestore, {
          shopId,
          bookingId,
          booking,
        });
        await issueOrRevokeDaycarePoints(firestore, {
          shopId,
          bookingId,
          booking,
          mode: "revoke",
        });
      } else if (action === "noShow") {
        // 舊訂單 status=no_show / noShow=true 仍可讀取；不可再新增此狀態。
        throw new HttpsError(
            "failed-precondition",
            "未到店標記已停用，請改用取消訂單",
        );
      } else if (action === "extend") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        const newEnd = toDate(payload.scheduledEndAt);
        if (!newEnd) {
          throw new HttpsError("invalid-argument", "請選擇新的接回時間");
        }
        const startAt = toDate(booking.scheduledStartAt);
        if (!startAt || newEnd.getTime() <= startAt.getTime()) {
          throw new HttpsError("invalid-argument", "延長時間無效");
        }
        const availability = await assertAvailable(firestore, {
          shopId,
          startAt,
          endAt: newEnd,
          petIds: booking.petIds || [],
          roomId: booking.roomId || "",
          roomTypeId: booking.roomTypeId || "",
          occupancyMode: "slot",
          dailyMaxPets: 0,
          blockUntilCleaned: true,
          excludeBookingId: bookingId,
        });
        if (!availability.ok) {
          throw new HttpsError("failed-precondition", availability.reason);
        }
        const recomputed = quote({
          settings,
          plan,
          startAt,
          endAt: newEnd,
          petCount: Array.isArray(booking.petIds) ? booking.petIds.length : 1,
          roomTypeExtra: toInt(
              booking.daycarePricingSnapshot &&
              booking.daycarePricingSnapshot.roomTypeExtra, 0,
          ),
          addonAmount: toInt(
              booking.daycarePricingSnapshot &&
              booking.daycarePricingSnapshot.addonAmount, 0,
          ),
          surchargeAmount: toInt(booking.specialDateSurchargeAmount, 0),
          discountAmount: toInt(booking.discountAmount, 0),
          couponAmount: toInt(booking.couponDiscountAmount, 0),
          pointAmount: toInt(booking.pointAmount, 0),
          overtimeAmount: toInt(booking.overtimeAmount, 0),
          manualAdjust: toInt(booking.manualAdjust, 0),
        });
        const occSnap = await loadActiveOccupancies(
            firestore, shopId, bookingId,
        );
        await firestore.runTransaction(async (transaction) => {
          const holdBooking = holdIdentity(booking, bookingId, shopId);
          const holdRef = holdRefForBooking(firestore, holdBooking);
          const holdSnap = holdRef ? await transaction.get(holdRef) : null;
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
          if (!normalizeString(booking.roomId) && holdRef && holdSnap &&
              holdSnap.exists) {
            const next = listHoldEntries(holdSnap.data()).map((item) => {
              if (normalizeString(item.bookingId) !== bookingId) {
                return item;
              }
              return {
                ...item,
                startAt: startAt.toISOString(),
                endAt: newEnd.toISOString(),
              };
            });
            writeHoldEntries(
                transaction,
                holdRef,
                shopId,
                holdBooking.requestedRoomTypeId || holdBooking.roomTypeId,
                booking.serviceDate || "",
                next,
            );
          }
          if (normalizeString(booking.roomId)) {
            const occRef = firestore.collection("shops").doc(shopId)
                .collection("room_occupancies").doc();
            transaction.set(occRef, {
              shopId,
              bookingId,
              bookingKind: BOOKING_KIND_DAYCARE,
              roomId: booking.roomId,
              roomTypeId: booking.roomTypeId || "",
              startAt: booking.scheduledStartAt,
              endAt: admin.firestore.Timestamp.fromDate(newEnd),
              occupancyMode: "slot",
              serviceDate: booking.serviceDate || "",
              status: "active",
              createdAt: now,
              updatedAt: now,
            });
          }
          transaction.update(bookingRef, {
            scheduledEndAt: admin.firestore.Timestamp.fromDate(newEnd),
            endDate: admin.firestore.Timestamp.fromDate(newEnd),
            totalPrice: recomputed.totalAmount,
            daycarePricingSnapshot: recomputed,
            remainingAmount: Math.max(
                0, recomputed.totalAmount - toInt(booking.paidAmount, 0),
            ),
            updatedAt: now,
          });
        });
        result.totalPrice = recomputed.totalAmount;
      } else if (action === "addOvertime") {
        await requirePerm(uid, shopId, "adjust_daycare_price");
        const amount = Math.max(0, toInt(payload.overtimeAmount, 0));
        const minutes = Math.max(0, toInt(payload.overtimeMinutes, 0));
        const total = toInt(booking.totalPrice, 0) -
          toInt(booking.overtimeAmount, 0) + amount;
        await bookingRef.update({
          overtimeAmount: amount,
          overtimeMinutes: minutes,
          totalPrice: total,
          remainingAmount: Math.max(0, total - toInt(booking.paidAmount, 0)),
          updatedAt: now,
        });
        result.totalPrice = total;
      } else if (action === "adjustPrice") {
        await requirePerm(uid, shopId, "adjust_daycare_price");
        const manualAdjust = toInt(payload.manualAdjust, 0);
        const snap = booking.daycarePricingSnapshot || {};
        const total = Math.max(0,
            toInt(snap.baseAmount, 0) + toInt(snap.extraPetAmount, 0) +
            toInt(snap.roomTypeExtra, 0) + toInt(snap.addonAmount, 0) +
            toInt(snap.surchargeAmount, 0) + toInt(booking.overtimeAmount, 0) +
            manualAdjust - toInt(snap.discountAmount, 0) -
            toInt(snap.couponAmount, 0) - toInt(snap.pointAmount, 0));
        await bookingRef.update({
          manualAdjust,
          totalPrice: total,
          remainingAmount: Math.max(0, total - toInt(booking.paidAmount, 0)),
          updatedAt: now,
        });
        result.totalPrice = total;
        if (booking.status === "completed") {
          await issueOrRevokeDaycarePoints(firestore, {
            shopId,
            bookingId,
            booking: {...booking, totalPrice: total},
            mode: "recalc",
          });
        }
      } else {
        throw new HttpsError("invalid-argument", `不支援的操作：${action}`);
      }

      if (action !== "previewSettle" && action !== "confirmDeposit") {
        await writeActionLog({
          shopId,
          targetId: bookingId,
          action: `daycare_${action}`,
          operatorUid: uid,
          operatorRole: isRootAdmin(uid) ? "root" : "staff",
          payload: {
            action,
            requestId,
            waiveOvertime: payload.waiveOvertime === true,
            waiveReason: normalizeString(payload.waiveReason),
            completeMode: normalizeString(payload.completeMode),
            remainingAmount: result.remainingAmount || 0,
            overtimeAmount: result.overtimeAmount || 0,
            originalSettlementAmount: result.originalSettlementAmount || 0,
            manualAdjustmentAmount: result.manualAdjustmentAmount || 0,
            manualAdjustmentReason: result.manualAdjustmentReason || "",
            reason: result.manualAdjustmentReason ||
              normalizeString(payload.reason),
            finalSettlementAmount: result.finalSettlementAmount ||
              result.finalTotal || result.totalPrice || 0,
            finalPaidAmount: result.finalPaidAmount ||
              toInt(booking.paidAmount, 0),
            finalRemainingAmount: result.finalRemainingAmount ||
              result.remainingAmount || 0,
            refundDueAmount: result.refundDueAmount ||
              toInt(booking.refundDueAmount, 0),
            refundMethod: normalizeString(
                result.settlementRefundMethod ||
                payload.settlementRefundMethod ||
                payload.refundMethod ||
                booking.settlementRefundMethod,
            ),
            settlementRefundMethod: normalizeString(
                result.settlementRefundMethod ||
                booking.settlementRefundMethod ||
                payload.settlementRefundMethod,
            ),
            finalTotal: result.finalTotal || result.totalPrice || 0,
            actualStartAtLabel: result.actualStartAtLabel || formatLogTime(
                booking.actualStartAt || booking.scheduledStartAt,
            ),
            actualEndAtLabel: result.actualEndAtLabel || formatLogTime(
                booking.actualEndAt || booking.checkedOutAt,
            ),
          },
        });
      }
      if (requestId) {
        await firestore.collection("shops").doc(shopId)
            .collection("daycare_ops").doc(requestId).set({
              ...result,
              bookingId,
              reused: false,
              createdAt: now,
            });
      }
      if (action !== "previewSettle") {
        try {
          const latest = await bookingRef.get();
          await applyBookingReport(
              firestore,
              bookingId,
              latest.data() || booking,
          );
        } catch (reportError) {
          console.error("安親營運摘要更新失敗", reportError);
        }
      }
      return result;
    },
);

/**
 * 取消安親訂單時返還折抵點數（只返還一次）
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 */
async function restoreDaycareSpend(firestore, params) {
  const booking = params.booking || {};
  const userId = normalizeString(booking.userId);
  const spent = toInt(booking.pointAmount, 0);
  if (!userId || spent <= 0) {
    return;
  }
  const spendRef = firestore.collection("shops").doc(params.shopId)
      .collection("member_point_logs")
      .doc(`spend_booking_${params.bookingId}`);
  const pointRef = firestore.collection("shops").doc(params.shopId)
      .collection("member_points").doc(userId);
  const bookingRef = firestore.collection("bookings").doc(params.bookingId);
  await firestore.runTransaction(async (transaction) => {
    const spendSnap = await transaction.get(spendRef);
    if (!spendSnap.exists || spendSnap.data().returned === true) {
      return;
    }
    const pointSnap = await transaction.get(pointRef);
    const current = toInt(
        pointSnap.exists ? pointSnap.data().points : 0, 0,
    );
    transaction.update(spendRef, {
      returned: true,
      returnedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.set(pointRef, {
      points: current + spent,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(bookingRef, {
      pointsReturned: true,
    });
  });
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 */
async function issueOrRevokeDaycarePoints(firestore, params) {
  const booking = params.booking || {};
  const userId = normalizeString(booking.userId);
  if (!userId) {
    return;
  }
  let isAppMember = false;
  try {
    await admin.auth().getUser(userId);
    isAppMember = true;
  } catch (error) {
    isAppMember = false;
  }
  if (!isAppMember) {
    return;
  }
  const settingSnap = await firestore.collection("shops").doc(params.shopId)
      .collection("settings").doc("points").get();
  const setting = settingSnap.data() || {};
  const logRef = firestore.collection("shops").doc(params.shopId)
      .collection("member_point_logs").doc(`booking_${params.bookingId}`);
  const pointRef = firestore.collection("shops").doc(params.shopId)
      .collection("member_points").doc(userId);
  const bookingRef = firestore.collection("bookings").doc(params.bookingId);

  if (params.mode === "revoke") {
    await firestore.runTransaction(async (transaction) => {
      const logSnap = await transaction.get(logRef);
      if (!logSnap.exists) {
        return;
      }
      const issued = toInt(logSnap.data().pointsChange, 0);
      if (issued <= 0 || logSnap.data().revoked === true) {
        return;
      }
      const pointSnap = await transaction.get(pointRef);
      const current = toInt(
        pointSnap.exists ? pointSnap.data().points : 0, 0,
      );
      transaction.update(logRef, {
        revoked: true,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (pointSnap.exists) {
        transaction.update(pointRef, {
          points: Math.max(0, current - issued),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      transaction.update(bookingRef, {
        pointsIssued: false,
        pointsIssuedAmount: 0,
      });
    });
    return;
  }

  if (setting.enabled !== true || setting.daycareEarnEnabled !== true) {
    return;
  }
  if (setting.issueAfterCompleted === false) {
    return;
  }
  const points = computeEarnPoints(setting, booking);

  await firestore.runTransaction(async (transaction) => {
    const logSnap = await transaction.get(logRef);
    const pointSnap = await transaction.get(pointRef);
    const current = toInt(
      pointSnap.exists ? pointSnap.data().points : 0, 0,
    );
    const already = logSnap.exists && logSnap.data().revoked !== true ?
      toInt(logSnap.data().pointsChange, 0) : 0;
    if (params.mode === "recalc" && already > 0) {
      const delta = points - already;
      if (delta === 0) {
        return;
      }
      transaction.set(logRef, {
        pointsChange: points,
        changeType: "earn",
        logType: "booking",
        bookingId: params.bookingId,
        userId,
        shopId: params.shopId,
        revoked: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(pointRef, {
        points: Math.max(0, current + delta),
        shopId: params.shopId,
        userId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.update(bookingRef, {
        pointsIssued: points > 0,
        pointsIssuedAmount: points,
      });
      return;
    }
    if (already > 0 || points <= 0) {
      return;
    }
    transaction.set(logRef, {
      pointsChange: points,
      changeType: "earn",
      logType: "booking",
      bookingId: params.bookingId,
      userId,
      shopId: params.shopId,
      revoked: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      snapshot: {
        finalSettlementAmount: toInt(booking.finalSettlementAmount, 0),
        totalPrice: toInt(booking.totalPrice, 0),
        overtimeAmount: toInt(booking.overtimeAmount, 0),
        specialDateSurchargeAmount:
          toInt(booking.specialDateSurchargeAmount, 0),
      },
    });
    transaction.set(pointRef, {
      points: current + points,
      shopId: params.shopId,
      userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.update(bookingRef, {
      pointsIssued: true,
      pointsIssuedAmount: points,
    });
  });
}
