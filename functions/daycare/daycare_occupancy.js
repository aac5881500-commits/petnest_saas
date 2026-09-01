// functions/daycare/daycare_occupancy.js
// 🐾 住宿日期占用 + 臨托時段占用，同一套檢查

const admin = require("firebase-admin");
const {
  ACTIVE_STATUSES,
  BOOKING_KIND_DAYCARE,
  overlaps,
  resolveBookingKind,
  serviceDateKey,
  toDate,
  toInt,
  normalizeString,
} = require("./daycare_utils");

/**
 * 住宿占用 [startDate, endDate)
 * @param {Date} stayStart
 * @param {Date} stayEnd
 * @param {Date} slotStart
 * @param {Date} slotEnd
 * @return {boolean}
 */
function stayConflictsSlot(stayStart, stayEnd, slotStart, slotEnd) {
  const stayStartDay = new Date(Date.UTC(
      stayStart.getFullYear(), stayStart.getMonth(), stayStart.getDate(),
  ));
  const stayEndDay = new Date(Date.UTC(
      stayEnd.getFullYear(), stayEnd.getMonth(), stayEnd.getDate(),
  ));
  const slotDay = new Date(Date.UTC(
      slotStart.getFullYear(), slotStart.getMonth(), slotStart.getDate(),
  ));
  return slotDay.getTime() >= stayStartDay.getTime() &&
    slotDay.getTime() < stayEndDay.getTime() &&
    overlaps(slotStart, slotEnd, stayStart, stayEnd || slotEnd);
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<{ok: boolean, reason: string}>}
 */
async function assertAvailable(firestore, params) {
  const shopId = params.shopId;
  const startAt = params.startAt;
  const endAt = params.endAt;
  const petIds = Array.isArray(params.petIds) ? params.petIds : [];
  const roomId = normalizeString(params.roomId);
  const roomTypeId = normalizeString(params.roomTypeId);
  const occupancyMode = normalizeString(params.occupancyMode) || "slot";
  const dailyMaxPets = toInt(params.dailyMaxPets, 0);
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const serviceDate = serviceDateKey(startAt);

  const bookingsSnap = await firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES)
      .get();

  let dayPetCount = 0;

  for (const doc of bookingsSnap.docs) {
    if (doc.id === excludeBookingId) {
      continue;
    }
    const data = doc.data() || {};
    const kind = resolveBookingKind(data);
    const otherPets = Array.isArray(data.petIds) ?
      data.petIds.map((id) => String(id)) : [];
    const petOverlap = petIds.some((id) => otherPets.includes(id));

    if (kind === BOOKING_KIND_DAYCARE) {
      const otherStart = toDate(data.scheduledStartAt);
      const otherEnd = toDate(data.scheduledEndAt);
      if (!otherStart || !otherEnd) {
        continue;
      }
      if (serviceDateKey(otherStart) === serviceDate) {
        dayPetCount += Math.max(1, otherPets.length || toInt(data.petCount, 1));
      }
      if (petOverlap && overlaps(startAt, endAt, otherStart, otherEnd)) {
        return {ok: false, reason: "此寵物在相同時段已有臨托預約"};
      }
      const otherRoom = normalizeString(data.roomId);
      if (roomId && otherRoom && otherRoom === roomId) {
        const otherMode = normalizeString(data.occupancyMode) || "slot";
        if (otherMode === "full_day" || occupancyMode === "full_day") {
          if (serviceDateKey(otherStart) === serviceDate) {
            return {ok: false, reason: "此房間當日已被整日占用"};
          }
        } else if (overlaps(startAt, endAt, otherStart, otherEnd)) {
          return {ok: false, reason: "此房間此時段已被臨托占用"};
        }
      }
      continue;
    }

    const stayStart = toDate(data.startDate);
    const stayEnd = toDate(data.endDate);
    if (!stayStart || !stayEnd) {
      continue;
    }
    const occupiesDay = stayConflictsSlot(stayStart, stayEnd, startAt, endAt);
    if (petOverlap && occupiesDay) {
      return {ok: false, reason: "此寵物在相同日期已有住宿預約"};
    }
    const stayRoom = normalizeString(data.roomId);
    if (roomId && stayRoom && stayRoom === roomId && occupiesDay) {
      return {ok: false, reason: "此房間已被住宿訂單占用"};
    }
  }

  if (dailyMaxPets > 0 &&
      dayPetCount + Math.max(1, petIds.length) > dailyMaxPets) {
    return {ok: false, reason: "當日臨托名額已滿"};
  }

  if (roomId) {
    const roomSnap = await firestore.collection("shops").doc(shopId)
        .collection("rooms").doc(roomId).get();
    if (roomSnap.exists) {
      const room = roomSnap.data() || {};
      if (normalizeString(room.status) === "cleaning" &&
          params.blockUntilCleaned !== false) {
        return {ok: false, reason: "房間清潔中，暫不可分配"};
      }
      if (room.enabled === false) {
        return {ok: false, reason: "此房間目前未開放"};
      }
      const status = normalizeString(room.status);
      if (status === "maintenance" || status === "blocked") {
        return {ok: false, reason: "房間維修中，暫不可分配"};
      }
      const roomCapacity = toInt(room.capacity, 0);
      if (roomCapacity > 0 && petIds.length > roomCapacity) {
        return {ok: false, reason: "房間容量不足"};
      }
      if (roomTypeId && normalizeString(room.roomTypeId) &&
          normalizeString(room.roomTypeId) !== roomTypeId) {
        return {ok: false, reason: "房間與房型不符"};
      }
    }

    const occSnap = await firestore.collection("shops").doc(shopId)
        .collection("room_occupancies")
        .where("roomId", "==", roomId)
        .where("status", "==", "active")
        .get();
    for (const doc of occSnap.docs) {
      const occ = doc.data() || {};
      if (normalizeString(occ.bookingId) === excludeBookingId) {
        continue;
      }
      const occStart = toDate(occ.startAt);
      const occEnd = toDate(occ.endAt);
      if (!occStart || !occEnd) {
        continue;
      }
      const occMode = normalizeString(occ.occupancyMode) || "slot";
      if (occMode === "full_day" || occupancyMode === "full_day") {
        if (serviceDateKey(occStart) === serviceDate) {
          return {ok: false, reason: "此房間當日占用衝突"};
        }
      } else if (overlaps(startAt, endAt, occStart, occEnd)) {
        return {ok: false, reason: "此房間時段占用衝突"};
      }
    }
  }

  return {ok: true, reason: ""};
}

/**
 * 臨托只占用時段、不占用整日。未分房的 pending／confirmed 仍佔用該房型名額。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<{ok: boolean, reason: string, remaining: number}>}
 */
async function assertRoomTypeCapacity(firestore, params) {
  const shopId = params.shopId;
  const roomTypeId = normalizeString(params.roomTypeId);
  const startAt = params.startAt;
  const endAt = params.endAt;
  const excludeBookingId = normalizeString(params.excludeBookingId);
  if (!roomTypeId) {
    return {ok: false, reason: "請選擇臨托房型", remaining: 0};
  }
  const roomsSnap = await firestore.collection("shops").doc(shopId)
      .collection("rooms").where("roomTypeId", "==", roomTypeId).get();
  let free = 0;
  for (const doc of roomsSnap.docs) {
    const room = doc.data() || {};
    if (room.enabled === false) {
      continue;
    }
    const result = await assertAvailable(firestore, {
      shopId,
      startAt,
      endAt,
      petIds: [],
      roomId: doc.id,
      roomTypeId,
      occupancyMode: "slot",
      dailyMaxPets: 0,
      blockUntilCleaned: true,
      excludeBookingId,
    });
    if (result.ok) {
      free++;
    }
  }

  const bookingsSnap = await firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES)
      .get();
  let reserved = 0;
  for (const doc of bookingsSnap.docs) {
    if (doc.id === excludeBookingId) {
      continue;
    }
    const data = doc.data() || {};
    if (resolveBookingKind(data) !== BOOKING_KIND_DAYCARE) {
      continue;
    }
    if (normalizeString(data.roomTypeId) !== roomTypeId) {
      continue;
    }
    if (normalizeString(data.roomId)) {
      continue;
    }
    const otherStart = toDate(data.scheduledStartAt);
    const otherEnd = toDate(data.scheduledEndAt);
    if (!otherStart || !otherEnd) {
      continue;
    }
    if (overlaps(startAt, endAt, otherStart, otherEnd)) {
      reserved++;
    }
  }
  const remaining = Math.max(0, free - reserved);
  if (remaining <= 0) {
    return {ok: false, reason: "該時段已無可用房間", remaining: 0};
  }
  return {ok: true, reason: "", remaining};
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.DocumentReference} occupancyRef
 * @param {Object} data
 */
function writeOccupancy(transaction, occupancyRef, data) {
  transaction.set(occupancyRef, {
    shopId: data.shopId,
    bookingId: data.bookingId,
    bookingKind: BOOKING_KIND_DAYCARE,
    roomId: data.roomId,
    roomTypeId: data.roomTypeId || "",
    startAt: data.startAt,
    endAt: data.endAt,
    occupancyMode: data.occupancyMode || "slot",
    serviceDate: data.serviceDate,
    status: "active",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} bookingId
 * @return {Promise<FirebaseFirestore.QuerySnapshot>}
 */
function loadActiveOccupancies(firestore, shopId, bookingId) {
  return firestore.collection("shops").doc(shopId)
      .collection("room_occupancies")
      .where("bookingId", "==", bookingId)
      .where("status", "==", "active")
      .get();
}

/**
 * Transaction 內必須先讀後寫。請先 loadActiveOccupancies。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} docs
 */
function releaseOccupancyDocs(transaction, docs) {
  docs.forEach((doc) => {
    transaction.update(doc.ref, {
      status: "released",
      releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {string} shopId
 * @param {string} bookingId
 * @return {Promise<void>}
 */
async function releaseOccupancies(firestore, transaction, shopId, bookingId) {
  const snap = await loadActiveOccupancies(firestore, shopId, bookingId);
  releaseOccupancyDocs(transaction, snap.docs);
}

module.exports = {
  stayConflictsSlot,
  assertAvailable,
  assertRoomTypeCapacity,
  writeOccupancy,
  loadActiveOccupancies,
  releaseOccupancyDocs,
  releaseOccupancies,
};
