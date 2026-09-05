// 檔案名稱：functions/daycare/assign_daycare_room.js
// 功能說明：臨托分房／換房：確認後才選房型＋實際房間，Transaction 防超賣

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_DAYCARE,
  hasShopPermission,
  normalizeString,
  resolveBookingKind,
  toDate,
  toInt,
  writeActionLog,
  overnightCapForRoom,
} = require("./daycare_utils");
const {
  assertAvailable,
  releaseOccupancies,
} = require("./daycare_occupancy");
const {
  isRoomBased,
  quoteRoom,
  paymentStatusOf,
} = require("./daycare_pricing");

exports.assignDaycareRoom = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const roomId = normalizeString(data.roomId);
      if (!shopId || !bookingId || !roomId) {
        throw new HttpsError("invalid-argument", "缺少房間資料");
      }
      const allowed = await hasShopPermission(
          shopId, uid, "manage_daycare_bookings",
      );
      if (!allowed) {
        throw new HttpsError("permission-denied", "沒有分配房間權限");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
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
      if (!["confirmed", "checked_in"].includes(booking.status)) {
        throw new HttpsError("failed-precondition", "請先確認訂單後再分配房間");
      }

      const roomSnap = await firestore.collection("shops").doc(shopId)
          .collection("rooms").doc(roomId).get();
      if (!roomSnap.exists) {
        throw new HttpsError("not-found", "找不到房間");
      }
      const room = roomSnap.data() || {};
      const roomTypeId = normalizeString(room.roomTypeId) ||
        normalizeString(data.roomTypeId);
      if (!roomTypeId) {
        throw new HttpsError("failed-precondition", "此房間沒有房型");
      }
      const roomTypeSnap = await firestore.collection("shops").doc(shopId)
          .collection("room_types").doc(roomTypeId).get();
      const roomType = roomTypeSnap.exists ? (roomTypeSnap.data() || {}) : {};
      const roomTypeName = normalizeString(data.roomTypeName) ||
        normalizeString(roomType.name) || roomTypeId;
      const roomName = normalizeString(data.roomName) ||
        normalizeString(room.name) || roomId;
      const roomNumber = normalizeString(room.number) || roomName;
      const capacity = toInt(room.capacity, 0) || toInt(roomType.capacity, 0);
      const petCount = Array.isArray(booking.petIds) ?
        booking.petIds.length : toInt(booking.petCount, 1);
      if (capacity > 0 && petCount > capacity) {
        throw new HttpsError("failed-precondition", "房間容量不足");
      }

      const startAt = toDate(booking.scheduledStartAt);
      const endAt = toDate(booking.scheduledEndAt);
      const availability = await assertAvailable(firestore, {
        shopId,
        startAt,
        endAt,
        petIds: booking.petIds || [],
        roomId,
        roomTypeId,
        occupancyMode: "slot",
        blockUntilCleaned: true,
        excludeBookingId: bookingId,
      });
      if (!availability.ok) {
        throw new HttpsError("failed-precondition", availability.reason);
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      const settingsSnap = await firestore.collection("shops").doc(shopId)
          .collection("daycare_settings").doc("main").get();
      const settings = settingsSnap.data() || {};
      let quoteFields = {};
      if (isRoomBased({
        pricingMode: booking.pricingMode || settings.pricingMode,
      })) {
        const roomSetting = (Array.isArray(settings.roomTypes) ?
          settings.roomTypes : []).find((item) =>
          normalizeString(item && item.roomTypeId) === roomTypeId);
        if (!roomSetting || roomSetting.enabled !== true) {
          throw new HttpsError("failed-precondition", "此房型未開放安親");
        }
        const overnightCap = await overnightCapForRoom(
            firestore, shopId, roomTypeId, petCount, startAt,
        );
        const roomQuote = quoteRoom({
          roomSetting,
          startAt,
          endAt,
          petCount,
          overnightCapAmount: overnightCap,
        });
        const addonAmount = toInt(
            booking.daycarePricingSnapshot &&
            booking.daycarePricingSnapshot.addonAmount, 0,
        );
        const couponAmount = toInt(booking.couponDiscountAmount, 0);
        const pointAmount = toInt(booking.pointAmount, 0);
        const manualAdjust = toInt(booking.manualAdjust, 0);
        const quotedTotal = Math.max(0,
            roomQuote.cappedRoomAmount + addonAmount + manualAdjust -
            couponAmount - pointAmount);
        quoteFields = {
          quotedTotalPrice: quotedTotal,
          totalPrice: quotedTotal,
          remainingAmount: Math.max(
              0, quotedTotal - toInt(booking.paidAmount, 0),
          ),
          paymentStatus: paymentStatusOf(
              booking.paidAmount, quotedTotal,
          ),
          priceQuoteLocked: true,
          priceConfirmedAt: now,
          priceQuoteSnapshot: {
            ...roomQuote,
            overnightCapAmount: overnightCap,
            addonAmount,
            couponAmount,
            pointAmount,
            manualAdjust,
            totalAmount: quotedTotal,
          },
          daycarePricingSnapshot: {
            ...(booking.daycarePricingSnapshot || {}),
            ...roomQuote,
            addonAmount,
            totalAmount: quotedTotal,
            depositAmount: toInt(
                booking.daycarePricingSnapshot &&
                booking.daycarePricingSnapshot.depositAmount, 0,
            ),
          },
        };
      }
      await firestore.runTransaction(async (transaction) => {
        await releaseOccupancies(firestore, transaction, shopId, bookingId);
        const occRef = firestore.collection("shops").doc(shopId)
            .collection("room_occupancies").doc();
        transaction.set(occRef, {
          shopId,
          bookingId,
          bookingKind: BOOKING_KIND_DAYCARE,
          roomId,
          roomTypeId,
          startAt: booking.scheduledStartAt,
          endAt: booking.scheduledEndAt,
          occupancyMode: "slot",
          serviceDate: booking.serviceDate || "",
          status: "active",
          createdAt: now,
          updatedAt: now,
        });
        transaction.update(bookingRef, {
          roomId,
          roomName,
          roomNumberSnapshot: roomNumber,
          roomTypeId,
          roomTypeName,
          roomTypeNameSnapshot: roomTypeName,
          assignStatus: "assigned",
          assignedAt: now,
          assignedBy: uid,
          updatedAt: now,
          ...quoteFields,
        });
      });

      await writeActionLog({
        shopId,
        targetId: bookingId,
        action: "daycare_assign_room",
        operatorUid: uid,
        operatorRole: "staff",
        payload: {
          roomId,
          roomName,
          roomTypeId,
          roomTypeName,
          fromRoomId: booking.roomId || "",
        },
      });

      return {
        ok: true,
        roomId,
        roomName,
        roomTypeId,
        roomTypeName,
        quotedTotalPrice: quoteFields.quotedTotalPrice || null,
      };
    },
);
