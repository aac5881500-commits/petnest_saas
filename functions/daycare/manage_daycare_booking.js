// functions/daycare/manage_daycare_booking.js
// 🐾 臨托狀態、延長、超時、改價、取消、No-show

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_DAYCARE,
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  resolveBookingKind,
  toDate,
  toInt,
  writeActionLog,
} = require("./daycare_utils");
const {overtimeFee, quote} = require("./daycare_pricing");
const {
  assertAvailable,
  loadActiveOccupancies,
  releaseOccupancyDocs,
} = require("./daycare_occupancy");

/**
 * @param {string} uid
 * @param {string} shopId
 * @param {string} key
 */
async function requirePerm(uid, shopId, key) {
  const ok = await hasShopPermission(shopId, uid, key);
  if (!ok) {
    throw new HttpsError("permission-denied", "沒有執行此操作的權限");
  }
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
        if (booking.status !== "pending") {
          throw new HttpsError("failed-precondition", "僅待確認訂單可確認");
        }
        await bookingRef.update({
          status: "confirmed",
          confirmedAt: now,
          updatedAt: now,
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
      } else if (action === "complete") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        if (booking.status !== "checked_in") {
          throw new HttpsError("failed-precondition", "僅臨托中訂單可完成");
        }
        const actualEnd = toDate(payload.actualEndAt) || new Date();
        const scheduledEnd = toDate(booking.scheduledEndAt);
        const extra = payload.waiveOvertime === true ? 0 :
          overtimeFee(plan, settings, scheduledEnd, actualEnd);
        const overtimeMinutes = Math.max(0, Math.round(
            (actualEnd - scheduledEnd) / 60000,
        ));
        const total = toInt(booking.totalPrice, 0) + extra;
        const occSnap = await loadActiveOccupancies(
            firestore, shopId, bookingId,
        );
        await firestore.runTransaction(async (transaction) => {
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
          transaction.update(bookingRef, {
            status: "completed",
            actualEndAt: admin.firestore.Timestamp.fromDate(actualEnd),
            checkedOutAt: admin.firestore.Timestamp.fromDate(actualEnd),
            completedAt: now,
            overtimeMinutes,
            overtimeAmount: extra,
            totalPrice: total,
            remainingAmount: Math.max(0, total - toInt(booking.paidAmount, 0)),
            updatedAt: now,
          });
        });
        await issueOrRevokeDaycarePoints(firestore, {
          shopId,
          bookingId,
          booking: {...booking, totalPrice: total, source: booking.source,
            userId: booking.userId, addons: booking.addons,
            overtimeAmount: extra,
            specialDateSurchargeAmount: booking.specialDateSurchargeAmount,
            status: "completed"},
          mode: "issue",
        });
        if (normalizeString(booking.roomId)) {
          await firestore.collection("shops").doc(shopId)
              .collection("rooms").doc(booking.roomId)
              .set({
                status: "cleaning",
                cleaningStartedAt: now,
                updatedAt: now,
              }, {merge: true});
        }
        result = {ok: true, action, totalPrice: total, overtimeAmount: extra};
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
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
          transaction.update(bookingRef, cancelUpdates);
        });
        await issueOrRevokeDaycarePoints(firestore, {
          shopId,
          bookingId,
          booking,
          mode: "revoke",
        });
      } else if (action === "noShow") {
        await requirePerm(uid, shopId, "manage_daycare_bookings");
        if (booking.status !== "confirmed" && booking.status !== "pending") {
          throw new HttpsError("failed-precondition", "目前狀態不可標記未到");
        }
        const occSnap = await loadActiveOccupancies(
            firestore, shopId, bookingId,
        );
        const paid = toInt(booking.paidAmount, 0);
        await firestore.runTransaction(async (transaction) => {
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
          transaction.update(bookingRef, {
            status: "cancelled",
            noShowAt: now,
            noShow: true,
            cancelReason: "no_show",
            cancelBy: "staff",
            cancelledAt: now,
            refundStatus: settings.forfeitDepositOnNoShow !== false &&
              paid > 0 ? "forfeited" : "",
            updatedAt: now,
          });
        });
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
          dailyMaxPets: toInt(settings.dailyMaxPets, 0),
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
          for (const doc of occSnap.docs) {
            await transaction.get(doc.ref);
          }
          releaseOccupancyDocs(transaction, occSnap.docs);
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
      }

      await writeActionLog({
        shopId,
        targetId: bookingId,
        action: `daycare_${action}`,
        operatorUid: uid,
        operatorRole: isRootAdmin(uid) ? "root" : "staff",
        payload: {action, requestId},
      });
      if (requestId) {
        await firestore.collection("shops").doc(shopId)
            .collection("daycare_ops").doc(requestId).set({
              ...result,
              bookingId,
              reused: false,
              createdAt: now,
            });
      }
      return result;
    },
);

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
  let amount = toInt(booking.totalPrice, 0);
  if (setting.daycareIncludeAddons === false) {
    const addons = Array.isArray(booking.addons) ? booking.addons : [];
    const addonSum = addons.reduce((sum, item) =>
      sum + toInt(item && item.price, 0), 0);
    amount -= addonSum;
  }
  if (setting.daycareIncludeSurcharge === false) {
    amount -= toInt(booking.specialDateSurchargeAmount, 0);
  }
  if (setting.daycareIncludeOvertime === false) {
    amount -= toInt(booking.overtimeAmount, 0);
  }
  amount = Math.max(0, amount);
  const minAmount = toInt(setting.daycareMinimumOrderAmount, 0);
  if (minAmount > 0 && amount < minAmount) {
    amount = 0;
  }
  let points = 0;
  if (setting.daycareCalculationType === "fixed") {
    points = toInt(setting.daycarePointsPerOrder, 0);
  } else {
    const per = toInt(setting.daycareAmountPerPoint, 0);
    points = per > 0 ? Math.floor(amount / per) : 0;
  }
  const maxPoints = toInt(setting.daycareMaximumPointsPerBooking, 0);
  if (maxPoints > 0 && points > maxPoints) {
    points = maxPoints;
  }

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
