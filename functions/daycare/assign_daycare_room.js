// 檔案名稱：functions/daycare/assign_daycare_room.js
// 功能說明：安親分房／換房：確認後選實際房間，Transaction 防超賣，不重新計價

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_DAYCARE,
  hasShopPermission,
  normalizeString,
  resolveBookingKind,
  serviceDateKey,
  toDate,
  toInt,
  writeActionLog,
} = require("./daycare_utils");
const {
  assertAvailable,
  applyHoldReleaseFromSnap,
  calendarBlocksRoom,
  hasOverlappingOccupancy,
  holdIdentity,
  holdRefForBooking,
  releaseOccupancyDocs,
  roomUnavailable,
} = require("./daycare_occupancy");
const {
  isRoomBased,
  findRoomTypeSetting,
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
        throw new HttpsError("failed-precondition", "此訂單不是安親訂單");
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
      if (room.enabled === false) {
        throw new HttpsError("failed-precondition", "此房間已停用");
      }
      const actualRoomTypeId = normalizeString(room.roomTypeId);
      if (!actualRoomTypeId) {
        throw new HttpsError("failed-precondition", "此房間沒有房型");
      }
      const claimedTypeId = normalizeString(data.roomTypeId);
      if (claimedTypeId && claimedTypeId !== actualRoomTypeId) {
        throw new HttpsError("failed-precondition", "房間不屬於指定房型");
      }
      const roomTypeSnap = await firestore.collection("shops").doc(shopId)
          .collection("room_types").doc(actualRoomTypeId).get();
      if (!roomTypeSnap.exists) {
        throw new HttpsError(
            "failed-precondition",
            "房型不存在或已停用，無法分配房間",
        );
      }
      const roomType = roomTypeSnap.data() || {};
      if (roomType.enabled === false) {
        throw new HttpsError(
            "failed-precondition",
            "房型不存在或已停用，無法分配房間",
        );
      }
      const settingsSnap = await firestore.collection("shops").doc(shopId)
          .collection("daycare_settings").doc("main").get();
      const settings = settingsSnap.data() || {};
      const roomBased = isRoomBased({
        pricingMode: booking.pricingMode || settings.pricingMode,
      });
      const requestedRoomTypeId =
        normalizeString(booking.requestedRoomTypeId) ||
        normalizeString(booking.requested_room_type_id);
      if (roomBased) {
        if (!requestedRoomTypeId) {
          throw new HttpsError(
              "failed-precondition",
              "訂單沒有客戶選擇的房型，無法分配房間",
          );
        }
        if (actualRoomTypeId !== requestedRoomTypeId) {
          throw new HttpsError(
              "failed-precondition",
              "不可更換客戶選擇的房型",
          );
        }
        const requestedTypeSnap = actualRoomTypeId === requestedRoomTypeId ?
          roomTypeSnap :
          await firestore.collection("shops").doc(shopId)
              .collection("room_types").doc(requestedRoomTypeId).get();
        const roomSetting = findRoomTypeSetting(settings, requestedRoomTypeId);
        if (!requestedTypeSnap.exists || !roomSetting ||
            roomSetting.enabled !== true) {
          throw new HttpsError(
              "failed-precondition",
              "客戶選擇的房型不存在或已停用，無法分配房間",
          );
        }
      }

      const roomTypeName = normalizeString(roomType.name) || actualRoomTypeId;
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
      if (!startAt || !endAt) {
        throw new HttpsError("failed-precondition", "訂單時間不完整，無法分房");
      }
      const availability = await assertAvailable(firestore, {
        shopId,
        startAt,
        endAt,
        petIds: booking.petIds || [],
        roomId,
        roomTypeId: actualRoomTypeId,
        occupancyMode: "slot",
        blockUntilCleaned: true,
        excludeBookingId: bookingId,
      });
      if (!availability.ok) {
        throw new HttpsError("failed-precondition", availability.reason);
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      const dateKey = normalizeString(booking.serviceDate) ||
        serviceDateKey(startAt);
      try {
        await firestore.runTransaction(async (transaction) => {
          const roomRef = firestore.collection("shops").doc(shopId)
              .collection("rooms").doc(roomId);
          const roomTx = await transaction.get(roomRef);
          if (!roomTx.exists) {
            throw new HttpsError("not-found", "找不到房間");
          }
          const roomInTx = roomTx.data() || {};
          if (roomInTx.enabled === false || roomUnavailable(roomInTx)) {
            throw new HttpsError("failed-precondition", "此房間目前不可分配");
          }
          if (normalizeString(roomInTx.roomTypeId) !== actualRoomTypeId) {
            throw new HttpsError("failed-precondition", "房間不屬於指定房型");
          }
          if (roomBased && requestedRoomTypeId &&
              normalizeString(roomInTx.roomTypeId) !== requestedRoomTypeId) {
            throw new HttpsError(
                "failed-precondition",
                "不可更換客戶選擇的房型",
            );
          }
          const calSnap = await transaction.get(
              firestore.collection("shops").doc(shopId)
                  .collection("room_calendar")
                  .doc(`${roomId}_${dateKey}`),
          );
          const holdBooking = holdIdentity(booking, bookingId, shopId);
          const holdRef = holdRefForBooking(firestore, holdBooking);
          const holdSnap = holdRef ? await transaction.get(holdRef) : null;
          const occSnap = await transaction.get(
              firestore.collection("shops").doc(shopId)
                  .collection("room_occupancies")
                  .where("roomId", "==", roomId)
                  .where("status", "==", "active"),
          );
          const myOccSnap = await transaction.get(
              firestore.collection("shops").doc(shopId)
                  .collection("room_occupancies")
                  .where("bookingId", "==", bookingId)
                  .where("status", "==", "active"),
          );
          if (calSnap.exists &&
              calendarBlocksRoom((calSnap.data() || {}).status)) {
            throw new HttpsError(
                "failed-precondition",
                "此房間已被住宿訂單占用",
            );
          }
          const occupancies = occSnap.docs.map((doc) => doc.data() || {});
          if (hasOverlappingOccupancy(
              occupancies, startAt, endAt, bookingId, "slot",
          )) {
            throw new HttpsError("failed-precondition", "此時段房間已被占用");
          }
          releaseOccupancyDocs(transaction, myOccSnap.docs);
          transaction.update(roomRef, {occupancyLockAt: now});
          const occRef = firestore.collection("shops").doc(shopId)
              .collection("room_occupancies").doc();
          transaction.set(occRef, {
            shopId,
            bookingId,
            bookingKind: BOOKING_KIND_DAYCARE,
            roomId,
            roomTypeId: actualRoomTypeId,
            startAt: booking.scheduledStartAt,
            endAt: booking.scheduledEndAt,
            occupancyMode: "slot",
            serviceDate: dateKey,
            status: "active",
            createdAt: now,
            updatedAt: now,
          });
          transaction.update(bookingRef, {
            roomId,
            roomName,
            roomNumberSnapshot: roomNumber,
            roomTypeId: actualRoomTypeId,
            roomTypeName,
            roomTypeNameSnapshot: roomTypeName,
            assignStatus: "assigned",
            assignedAt: now,
            assignedBy: uid,
            updatedAt: now,
          });
          applyHoldReleaseFromSnap(
              transaction, holdRef, holdSnap, holdBooking,
          );
        });
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        const message = error && error.message ?
          error.message : String(error);
        if (message.includes("此時段房間已被占用")) {
          throw new HttpsError("failed-precondition", "此時段房間已被占用");
        }
        throw error;
      }

      await writeActionLog({
        shopId,
        targetId: bookingId,
        action: "daycare_assign_room",
        operatorUid: uid,
        operatorRole: "staff",
        payload: {
          roomId,
          roomName,
          roomTypeId: actualRoomTypeId,
          roomTypeName,
          fromRoomId: booking.roomId || "",
        },
      });

      return {
        ok: true,
        roomId,
        roomName,
        roomTypeId: actualRoomTypeId,
        roomTypeName,
      };
    },
);
