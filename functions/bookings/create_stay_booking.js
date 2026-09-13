// 檔案名稱：functions/bookings/create_stay_booking.js
// 功能說明：住宿建單／分房 transaction：共用房型可賣數與未分房保留

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  BOOKING_KIND_ACCOMMODATION,
  generateBookingCode,
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  resolveOperatorIdentity,
  toDate,
  toInt,
  writeActionLogInTransaction,
} = require("../daycare/daycare_utils");
const {bookingSearchFields} = require("../search/normalize_fields");
const {
  calendarBlocksRoom,
  commitRoomTypeHold,
  loadStayRoomTypeHoldStates,
  remainingRoomsFromData,
  releaseStayRoomTypeHoldsInTransaction,
  roomPermanentlyUnsellable,
  stayNightKeys,
  ROOM_TYPE_SOLD_OUT,
} = require("../daycare/daycare_occupancy");

/**
 * @param {Error} error
 * @return {HttpsError}
 */
function asHttps(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  const code = error && error.code === "failed-precondition" ?
    "failed-precondition" : "internal";
  return new HttpsError(
      code,
      (error && error.message) || ROOM_TYPE_SOLD_OUT,
  );
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<void>}
 */
async function assertPhysicalRoomFree(transaction, firestore, params) {
  const shopId = normalizeString(params.shopId);
  const roomId = normalizeString(params.roomId);
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const nights = stayNightKeys(params.startDate, params.endDate);
  const roomRef = firestore.collection("shops").doc(shopId)
      .collection("rooms").doc(roomId);
  const roomSnap = await transaction.get(roomRef);
  if (!roomSnap.exists) {
    throw new HttpsError("failed-precondition", "找不到房間");
  }
  const room = {id: roomId, ...(roomSnap.data() || {})};
  if (roomPermanentlyUnsellable(room)) {
    throw new HttpsError("failed-precondition", "此房間目前不可賣");
  }
  for (const dateKey of nights) {
    const calRef = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${roomId}_${dateKey}`);
    const calSnap = await transaction.get(calRef);
    if (calSnap.exists &&
        calendarBlocksRoom((calSnap.data() || {}).status)) {
      throw new HttpsError("failed-precondition", "此房間在該日期區間已被預約");
    }
  }
  const bookingsSnap = await transaction.get(
      firestore.collection("bookings")
          .where("shopId", "==", shopId)
          .where("status", "in", ["pending", "confirmed", "checked_in"]),
  );
  const occupanciesSnap = await transaction.get(
      firestore.collection("shops").doc(shopId)
          .collection("room_occupancies").where("status", "==", "active"),
  );
  const startDate = params.startDate;
  const endDate = params.endDate;
  const occupied = remainingRoomsFromData({
    rooms: [room],
    bookings: bookingsSnap.docs.map((doc) => {
      return {id: doc.id, ...(doc.data() || {})};
    }).filter((item) => normalizeString(item.roomId) === roomId),
    occupancies: occupanciesSnap.docs.map((doc) => doc.data() || {})
        .filter((item) => normalizeString(item.roomId) === roomId),
    calendarEntries: [],
    holdEntries: [],
    roomTypeId: normalizeString(room.roomTypeId),
    startAt: startDate,
    endAt: endDate,
    excludeBookingId,
    dateKey: stayNightKeys(startDate, endDate)[0] || "",
  });
  if (occupied.freeCount <= 0) {
    throw new HttpsError("failed-precondition", "此房間在該日期區間已被預約");
  }
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomId
 * @param {Array<string>} nights
 * @param {string} bookingId
 * @param {string} status
 * @return {void}
 */
function writeStayCalendar(
    transaction, firestore, shopId, roomId, nights, bookingId, status,
) {
  nights.forEach((dateKey) => {
    const calRef = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${roomId}_${dateKey}`);
    transaction.set(calRef, {
      roomId,
      date: dateKey,
      status,
      bookingId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomId
 * @param {Array<string>} nights
 * @return {void}
 */
function deleteStayCalendar(transaction, firestore, shopId, roomId, nights) {
  nights.forEach((dateKey) => {
    transaction.delete(
        firestore.collection("shops").doc(shopId)
            .collection("room_calendar").doc(`${roomId}_${dateKey}`),
    );
  });
}

exports.createStayBooking = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const roomTypeId = normalizeString(data.roomTypeId);
      const startDate = toDate(data.startDate);
      const endDate = toDate(data.endDate);
      const uid = request.auth.uid;
      if (!shopId || !roomTypeId || !startDate || !endDate) {
        throw new HttpsError("invalid-argument", "缺少住宿房型或日期");
      }
      const isStaff = await hasShopPermission(
          shopId, uid, "manage_bookings",
      ) || isRootAdmin(uid);
      const source = isStaff && normalizeString(data.source) === "admin" ?
        "admin" : "customer";
      const userId = source === "admin" ?
        normalizeString(data.userId) : uid;
      if (!userId) {
        throw new HttpsError("invalid-argument", "缺少會員");
      }
      if (source === "customer" && normalizeString(data.userId) &&
          normalizeString(data.userId) !== uid) {
        throw new HttpsError("permission-denied", "沒有權限代訂");
      }
      const requestId = normalizeString(data.requestId);
      const firestore = admin.firestore();
      const bookingRef = requestId ?
        firestore.collection("bookings").doc(requestId) :
        firestore.collection("bookings").doc();
      const existing = await bookingRef.get();
      if (existing.exists) {
        return {bookingId: bookingRef.id, reused: true};
      }
      const booking = data.booking && typeof data.booking === "object" ?
        data.booking : {};
      try {
        await firestore.runTransaction(async (transaction) => {
          const again = await transaction.get(bookingRef);
          if (again.exists) {
            return;
          }
          const states = await loadStayRoomTypeHoldStates(
              transaction, firestore, {
                shopId,
                roomTypeId,
                startDate,
                endDate,
                bookingId: bookingRef.id,
              },
          );
          const bookingCode = await generateBookingCode(transaction, shopId);
          states.forEach((state) => commitRoomTypeHold(transaction, state));
          const depositExpireAt = toDate(booking.depositExpireAt);
          transaction.set(bookingRef, {
            ...booking,
            requestId: requestId || bookingRef.id,
            bookingId: bookingRef.id,
            bookingCode,
            shopId,
            userId,
            source,
            roomTypeId,
            roomId: null,
            roomName: null,
            assignStatus: "unassigned",
            bookingKind: BOOKING_KIND_ACCOMMODATION,
            startDate: admin.firestore.Timestamp.fromDate(startDate),
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            nights: toInt(booking.nights, stayNightKeys(startDate, endDate)
                .length),
            status: "pending",
            depositExpireAt: depositExpireAt ?
              admin.firestore.Timestamp.fromDate(depositExpireAt) : null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            ...bookingSearchFields({
              customerName: booking.customerName,
              customerPhone: booking.customerPhone,
              bookingCode,
              pets: booking.pets,
            }),
          });
        });
      } catch (error) {
        throw asHttps(error);
      }
      return {bookingId: bookingRef.id, reused: false};
    },
);

exports.manageStayInventory = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      const bookingId = normalizeString(data.bookingId);
      const action = normalizeString(data.action);
      const uid = request.auth.uid;
      if (!shopId || !bookingId || !action) {
        throw new HttpsError("invalid-argument", "缺少住宿庫存操作資料");
      }
      const isStaff = await hasShopPermission(
          shopId, uid, "manage_bookings",
      ) || isRootAdmin(uid);
      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "找不到這筆訂單");
      }
      const booking = {id: bookingId, ...(bookingSnap.data() || {})};
      if (normalizeString(booking.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }
      const isOwner = normalizeString(booking.userId) === uid;
      if (!isStaff && !isOwner) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }
      const startDate = toDate(booking.startDate);
      const endDate = toDate(booking.endDate);
      try {
        if (action === "release") {
          await firestore.runTransaction(async (transaction) => {
            await transaction.get(bookingRef);
            await releaseStayRoomTypeHoldsInTransaction(
                transaction, firestore, booking,
            );
          });
          return {ok: true, action};
        }
        if (!isStaff) {
          throw new HttpsError("permission-denied", "沒有權限分房");
        }
        if (action === "assign" || action === "change") {
          const roomId = normalizeString(data.roomId);
          const roomName = normalizeString(data.roomName) || roomId;
          if (!roomId) {
            throw new HttpsError("invalid-argument", "請選擇房間");
          }
          const reason = normalizeString(data.reason);
          const liveBefore = bookingSnap.data() || {};
          const fromRoomId = normalizeString(liveBefore.roomId);
          if (action === "change" || (fromRoomId && fromRoomId !== roomId)) {
            if (!reason) {
              throw new HttpsError("invalid-argument", "更換房間請填寫原因");
            }
          }
          const operator = await resolveOperatorIdentity({
            operatorUid: uid,
            operatorEmail: normalizeString(
                request.auth.token && request.auth.token.email,
            ),
            shopId,
          });
          await firestore.runTransaction(async (transaction) => {
            const live = await transaction.get(bookingRef);
            const liveData = live.data() || {};
            await assertPhysicalRoomFree(transaction, firestore, {
              shopId,
              roomId,
              startDate,
              endDate,
              excludeBookingId: bookingId,
            });
            const nights = stayNightKeys(startDate, endDate);
            const oldRoomId = normalizeString(liveData.roomId);
            if ((action === "change" || oldRoomId) &&
                oldRoomId && oldRoomId !== roomId) {
              deleteStayCalendar(
                  transaction, firestore, shopId, oldRoomId, nights,
              );
            }
            writeStayCalendar(
                transaction, firestore, shopId, roomId, nights, bookingId,
                "booked",
            );
            await releaseStayRoomTypeHoldsInTransaction(
                transaction, firestore, {
                  ...liveData,
                  id: bookingId,
                  shopId,
                },
            );
            const roomTypeName = normalizeString(liveData.roomTypeName) ||
              normalizeString(liveData.roomTypeNameSnapshot);
            transaction.update(bookingRef, {
              roomId,
              roomName,
              assignStatus: "assigned",
              assignedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const changing = Boolean(oldRoomId && oldRoomId !== roomId);
            writeActionLogInTransaction(transaction, {
              shopId,
              targetId: bookingId,
              bookingId,
              bookingKind: BOOKING_KIND_ACCOMMODATION,
              action: changing ? "stay_change_room" : "stay_assign_room",
              type: changing ? "room_changed" : "room_assigned",
              operatorUid: uid,
              operatorEmail: operator.email,
              operatorDisplayName: operator.displayName,
              operatorRole: "staff",
              payload: {
                roomTypeName,
                fromRoomTypeName: roomTypeName,
                toRoomTypeName: roomTypeName,
                fromRoomId: oldRoomId,
                fromRoomName: normalizeString(liveData.roomName) || oldRoomId,
                toRoomId: roomId,
                toRoomName: roomName,
                oldRoomId,
                oldRoomName: normalizeString(liveData.roomName) || oldRoomId,
                newRoomId: roomId,
                newRoomName: roomName,
                roomId,
                roomName,
                reason,
              },
            }, operator);
          });
          return {ok: true, action};
        }
        throw new HttpsError("invalid-argument", "不支援的住宿庫存操作");
      } catch (error) {
        throw asHttps(error);
      }
    },
);
