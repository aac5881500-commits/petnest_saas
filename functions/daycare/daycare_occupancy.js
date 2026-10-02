// 檔案名稱：functions/daycare/daycare_occupancy.js
// 功能說明：住宿日期占用 + 臨托時段占用，同一套檢查

const admin = require("firebase-admin");
const {
  ACTIVE_STATUSES,
  BOOKING_KIND_ACCOMMODATION,
  BOOKING_KIND_DAYCARE,
  addCalendarDays,
  overlaps,
  resolveBookingKind,
  serviceDateKey,
  taipeiDateKey,
  toDate,
  toInt,
  normalizeString,
} = require("./daycare_utils");

const CHECKOUT_CLEANING_STATUS = "checkout_cleaning";

/**
 * 取消／結算／過期未付不占用庫存。
 * @param {Object} data
 * @return {boolean}
 */
function occupiesInventory(data) {
  const status = normalizeString(data.status);
  if (status === "cancelled" ||
      status === "no_show" ||
      status === "completed") {
    return false;
  }
  if (!ACTIVE_STATUSES.includes(status)) {
    return false;
  }
  if (resolveBookingKind(data) === BOOKING_KIND_DAYCARE) {
    if (data.settlementConfirmed === true || data.settledAt) {
      return false;
    }
  }
  if (data.depositExpired === true) {
    return false;
  }
  const expire = toDate(data.depositExpireAt);
  const depositPaid = data.depositPaid === true ||
    normalizeString(data.depositStatus) === "confirmed";
  if (expire && Date.now() > expire.getTime() && !depositPaid) {
    return false;
  }
  return true;
}

/**
 * 住宿占用 [startDate, endDate)，退房日不扣。
 * @param {Date} stayStart
 * @param {Date} stayEnd
 * @param {Date} slotStart
 * @param {Date} slotEnd
 * @return {boolean}
 */
function stayConflictsSlot(stayStart, stayEnd, slotStart, slotEnd) {
  const start = stayStart instanceof Date ? stayStart : toDate(stayStart);
  const end = stayEnd instanceof Date ? stayEnd : toDate(stayEnd);
  const slotS = slotStart instanceof Date ? slotStart : toDate(slotStart);
  const slotE = slotEnd instanceof Date ? slotEnd : toDate(slotEnd);
  if (!start || !end || !slotS) {
    return false;
  }
  const startKey = taipeiDateKey(start);
  const endKey = taipeiDateKey(end);
  const slotKey = taipeiDateKey(slotS);
  if (!startKey || !endKey || !slotKey) {
    return false;
  }
  return slotKey >= startKey &&
    slotKey < endKey &&
    overlaps(slotS, slotE || slotS, start, end);
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
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const serviceDate = serviceDateKey(startAt);

  const bookingsSnap = await firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES)
      .get();

  for (const doc of bookingsSnap.docs) {
    if (doc.id === excludeBookingId) {
      continue;
    }
    const data = doc.data() || {};
    if (!occupiesInventory(data)) {
      continue;
    }
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
          return {ok: false, reason: "此時段房間已被占用"};
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

  if (roomId) {
    const roomSnap = await firestore.collection("shops").doc(shopId)
        .collection("rooms").doc(roomId).get();
    if (roomSnap.exists) {
      const room = roomSnap.data() || {};
      if (room.enabled === false) {
        return {ok: false, reason: "此房間目前未開放"};
      }
      if (roomPermanentlyUnsellable(room)) {
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
        return {ok: false, reason: "此時段房間已被占用"};
      }
    }
    const calSnap = await firestore.collection("shops").doc(shopId)
        .collection("room_calendar")
        .doc(`${roomId}_${serviceDate}`).get();
    if (calSnap.exists && calendarBlocksRoom((calSnap.data() || {}).status)) {
      const status = normalizeString((calSnap.data() || {}).status);
      if (status === CHECKOUT_CLEANING_STATUS) {
        return {ok: false, reason: "此房間退房後待清潔，該日不可安排"};
      }
      return {ok: false, reason: "此房間已被住宿訂單占用"};
    }
  }

  return {ok: true, reason: ""};
}

const NO_PHYSICAL_ROOMS =
  "此房型尚未建立可用實體房間，請聯絡店家";
const NO_USABLE_ROOMS =
  "此房型目前沒有可用實體房間（停用、清潔中、維修中或封鎖）";
const ROOM_TYPE_SOLD_OUT =
  "該時段此安親房型已無可用房間，請重新選擇房型或時間。";

/**
 * @param {string} status
 * @return {boolean}
 */
function calendarBlocksRoom(status) {
  const value = normalizeString(status);
  return value === "booked" ||
    value === "checked_in" ||
    value === "occupied" ||
    value === CHECKOUT_CLEANING_STATUS ||
    value === "blocked" ||
    value === "cleaning" ||
    value === "maintenance" ||
    value === "closed" ||
    value === "unavailable";
}

/**
 * 店家未設定時預設開啟，與前台 HousekeepingSettingModel 一致。
 * @param {Object} shop
 * @return {boolean}
 */
function autoCleaningAfterCheckout(shop) {
  const setting = shop && shop.housekeepingSetting;
  if (!setting || typeof setting !== "object") {
    return true;
  }
  if (setting.autoCleaningAfterCheckout === false) {
    return false;
  }
  return true;
}

/**
 * @param {string} status
 * @return {boolean}
 */
function isManualCalendarStatus(status) {
  const value = normalizeString(status);
  return value === "closed" ||
    value === "maintenance" ||
    value === "blocked" ||
    value === "unavailable" ||
    value === "disabled";
}

/**
 * 只釋放這筆訂單自己的住宿或退房清潔保留，不刪手動房態與正式清潔中。
 * @param {Object} data
 * @param {string} bookingId
 * @return {boolean}
 */
function canReleaseOwnedCalendar(data, bookingId) {
  const owner = normalizeString(data && data.bookingId);
  const status = normalizeString(data && data.status);
  if (!owner || owner !== normalizeString(bookingId)) {
    return false;
  }
  if (isManualCalendarStatus(status) || status === "cleaning") {
    return false;
  }
  return status === "booked" ||
    status === "checked_in" ||
    status === "occupied" ||
    status === CHECKOUT_CLEANING_STATUS;
}

/**
 * 訂單自己的布林快照。沒有這個欄位就回傳 null，不回看店家現況。
 * @param {Object} booking
 * @return {boolean|null}
 */
function readBookingAutoCleaning(booking) {
  if (!booking || typeof booking !== "object") {
    return null;
  }
  if (booking.autoCleaningAfterCheckout === true) {
    return true;
  }
  if (booking.autoCleaningAfterCheckout === false) {
    return false;
  }
  return null;
}

/**
 * 建單當下要寫進 booking 的快照，與當時房型保留使用同一值。
 * @param {Object} shop
 * @return {boolean}
 */
function newStayAutoCleaningSnapshot(shop) {
  return autoCleaningAfterCheckout(shop);
}

/**
 * 分房、換房、改期使用的開關。有快照就只用快照。
 * 沒快照時，只有這筆訂單自己已有退房日鎖房才沿用，否則不新建。
 * @param {Object} booking
 * @param {Array<Object>=} calendarReads
 * @return {boolean}
 */
function stayAutoCleaningForRebuild(booking, calendarReads) {
  const flag = readBookingAutoCleaning(booking);
  if (flag === true || flag === false) {
    return flag;
  }
  const bookingId = normalizeString(
      booking && (booking.id || booking.bookingId),
  );
  const checkoutKey = taipeiDateKey(booking && booking.endDate);
  const reads = Array.isArray(calendarReads) ? calendarReads : [];
  if (!bookingId || !checkoutKey) {
    return false;
  }
  return reads.some((item) => {
    const snap = item && item.snap;
    const data = snap && snap.exists ?
      (snap.data() || {}) :
      (item && item.status ? item : null);
    if (!data) {
      return false;
    }
    const date = normalizeString((item && item.dateKey) || data.date);
    return date === checkoutKey &&
      normalizeString(data.bookingId) === bookingId &&
      normalizeString(data.status) === CHECKOUT_CLEANING_STATUS;
  });
}

/**
 * 完成退房時，退房日只能在歸屬正確時從待清潔鎖房轉成清潔中。
 * @param {Object} params
 * @return {{action: string, reason: string}}
 */
function checkoutDayOnStayCheckout(params) {
  const source = params || {};
  const snapshot = readBookingAutoCleaning(source.booking);
  const status = normalizeString(source.status);
  const owner = normalizeString(source.ownerBookingId);
  const bookingId = normalizeString(source.bookingId);
  const exists = source.exists === true;
  if (snapshot !== true && snapshot !== false) {
    return {action: "keep", reason: "no-snapshot"};
  }
  if (!exists) {
    return {
      action: "keep",
      reason: snapshot === true ? "missing-hold" : "no-doc",
    };
  }
  if (isManualCalendarStatus(status) || status === "cleaning") {
    return {action: "keep", reason: "manual-or-cleaning"};
  }
  if (!owner || owner !== bookingId) {
    return {action: "keep", reason: "other-owner"};
  }
  if (snapshot === true && status === CHECKOUT_CLEANING_STATUS) {
    return {action: "convert", reason: "owned-hold"};
  }
  if (snapshot === false && status === CHECKOUT_CLEANING_STATUS) {
    return {action: "keep", reason: "inconsistent"};
  }
  return {action: "keep", reason: "not-hold"};
}

/**
 * 房務直接改狀態。退房日待清潔鎖房不能在這裡被清掉或當成清潔完成。
 * @param {Object} params
 * @return {{ok: boolean, reason: string}}
 */
function canApplyRoomCalendarStatus(params) {
  const source = params || {};
  const from = normalizeString(source.fromStatus);
  const to = normalizeString(source.toStatus);
  if (from === CHECKOUT_CLEANING_STATUS) {
    return {ok: false, reason: "checkout-hold"};
  }
  if (source.cleaningCompleted === true) {
    if (from !== "cleaning") {
      return {ok: false, reason: "not-cleaning"};
    }
    if (to !== "available" && to !== "closed") {
      return {ok: false, reason: "bad-target"};
    }
  }
  return {ok: true, reason: ""};
}

/**
 * @param {string} roomId
 * @param {string} dateKey
 * @param {string} bookingId
 * @return {Object}
 */
function calendarCleaningFields(roomId, dateKey, bookingId) {
  return {
    roomId: normalizeString(roomId),
    date: normalizeString(dateKey),
    status: "cleaning",
    bookingId: normalizeString(bookingId),
  };
}

/**
 * @param {Object} room
 * @return {string}
 */
function roomPermanentStatus(room) {
  const data = room || {};
  const permanent = normalizeString(data.permanentStatus);
  if (permanent === "available" ||
      permanent === "maintenance" ||
      permanent === "blocked" ||
      permanent === "unavailable") {
    return permanent;
  }
  const legacy = normalizeString(data.status);
  if (legacy === "maintenance" ||
      legacy === "blocked" ||
      legacy === "unavailable") {
    return legacy;
  }
  return "available";
}

/**
 * @param {Object} room
 * @return {boolean}
 */
function roomPermanentlyUnsellable(room) {
  const data = room || {};
  if (data.enabled === false) {
    return true;
  }
  const status = roomPermanentStatus(data);
  return status === "maintenance" ||
    status === "blocked" ||
    status === "unavailable";
}

/**
 * @param {Object} room
 * @return {boolean}
 */
function roomUnavailable(room) {
  return roomPermanentlyUnsellable(room);
}

/**
 * @param {Object} room
 * @param {string} roomTypeId
 * @return {boolean}
 */
function roomMatchesType(room, roomTypeId) {
  const wanted = normalizeString(roomTypeId);
  if (!wanted) {
    return false;
  }
  return normalizeString(room && room.roomTypeId) === wanted;
}

/**
 * @param {Object} booking
 * @return {string}
 */
function unassignedTypeId(booking) {
  return normalizeString(
      (booking || {}).requestedRoomTypeId || (booking || {}).roomTypeId,
  );
}

/**
 * @param {string} roomTypeId
 * @param {string} dateKey
 * @return {string}
 */
function holdDocId(roomTypeId, dateKey) {
  return `${normalizeString(roomTypeId)}_${normalizeString(dateKey)}`;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomTypeId
 * @param {string} dateKey
 * @return {FirebaseFirestore.DocumentReference}
 */
function holdDocRef(firestore, shopId, roomTypeId, dateKey) {
  return firestore.collection("shops").doc(shopId)
      .collection("daycare_room_type_holds")
      .doc(holdDocId(roomTypeId, dateKey));
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} booking
 * @return {FirebaseFirestore.DocumentReference|null}
 */
function holdRefForBooking(firestore, booking) {
  const shopId = normalizeString(booking && booking.shopId);
  const roomTypeId = unassignedTypeId(booking);
  const dateKey = normalizeString(booking && booking.serviceDate) ||
    (toDate(booking && booking.scheduledStartAt) ?
      serviceDateKey(toDate(booking.scheduledStartAt)) : "");
  if (!shopId || !roomTypeId || !dateKey) {
    return null;
  }
  return holdDocRef(firestore, shopId, roomTypeId, dateKey);
}

/**
 * @param {Object} holdData
 * @return {Array<Object>}
 */
function listHoldEntries(holdData) {
  const data = holdData && typeof holdData === "object" ? holdData : {};
  return Array.isArray(data.holds) ?
    data.holds.filter((item) => item && typeof item === "object") : [];
}

/**
 * @param {Array<Object>} entries
 * @param {Date} startAt
 * @param {Date} endAt
 * @param {string} excludeBookingId
 * @return {Array<Object>}
 */
function overlappingHoldEntries(entries, startAt, endAt, excludeBookingId) {
  const exclude = normalizeString(excludeBookingId);
  return (Array.isArray(entries) ? entries : []).filter((item) => {
    if (normalizeString(item.bookingId) === exclude) {
      return false;
    }
    const otherStart = toDate(item.startAt);
    const otherEnd = toDate(item.endAt);
    if (!otherStart || !otherEnd) {
      return false;
    }
    return overlaps(startAt, endAt, otherStart, otherEnd);
  });
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.DocumentReference} holdRef
 * @param {string} shopId
 * @param {string} roomTypeId
 * @param {string} dateKey
 * @param {Array<Object>} entries
 */
function writeHoldEntries(
    transaction, holdRef, shopId, roomTypeId, dateKey, entries,
) {
  transaction.set(holdRef, {
    shopId,
    roomTypeId: normalizeString(roomTypeId),
    serviceDate: normalizeString(dateKey),
    holds: entries,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.DocumentReference} holdRef
 * @param {Object} holdData
 * @param {string} bookingId
 * @param {string} shopId
 * @param {string} roomTypeId
 * @param {string} dateKey
 */
function releaseHoldEntries(
    transaction, holdRef, holdData, bookingId, shopId, roomTypeId, dateKey,
) {
  const next = listHoldEntries(holdData).filter((item) => {
    return normalizeString(item.bookingId) !== normalizeString(bookingId);
  });
  writeHoldEntries(transaction, holdRef, shopId, roomTypeId, dateKey, next);
}

/**
 * @param {Object} booking
 * @param {string} bookingId
 * @param {string} shopId
 * @return {Object}
 */
function holdIdentity(booking, bookingId, shopId) {
  return {
    ...(booking || {}),
    id: bookingId || (booking && booking.id) || "",
    bookingId: bookingId || (booking && booking.bookingId) || "",
    shopId: shopId || (booking && booking.shopId) || "",
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.DocumentReference|null} holdRef
 * @param {FirebaseFirestore.DocumentSnapshot|null} holdSnap
 * @param {Object} booking
 */
function applyHoldReleaseFromSnap(transaction, holdRef, holdSnap, booking) {
  if (!holdRef || !holdSnap || !holdSnap.exists) {
    return;
  }
  const bookingId = normalizeString(booking.id || booking.bookingId);
  const dateKey = normalizeString(booking.serviceDate) ||
    (toDate(booking.scheduledStartAt) ?
      serviceDateKey(toDate(booking.scheduledStartAt)) : "");
  releaseHoldEntries(
      transaction,
      holdRef,
      holdSnap.data(),
      bookingId,
      normalizeString(booking.shopId),
      unassignedTypeId(booking),
      dateKey,
  );
}

/**
 * 可用實體房間 − 同時段未分房保留。已分房只扣該 roomId，不重複扣未分房。
 * @param {Object} params
 * @return {{remaining: number, createdCount: number, usableCount: number,
 *   reservedCount: number, zeroReason: string}}
 */
function remainingRoomsFromData(params) {
  const roomTypeId = normalizeString(params.roomTypeId);
  const startAt = params.startAt;
  const endAt = params.endAt;
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const petCount = toInt(params.petCount, 0);
  const roomTypeCapacity = toInt(params.roomTypeCapacity, 0);
  const dateKey = normalizeString(params.dateKey) ||
    (startAt ? serviceDateKey(startAt) : "");
  const rooms = Array.isArray(params.rooms) ? params.rooms : [];
  const bookings = Array.isArray(params.bookings) ? params.bookings : [];
  const occupancies = Array.isArray(params.occupancies) ?
    params.occupancies : [];
  const calendarEntries = Array.isArray(params.calendarEntries) ?
    params.calendarEntries : [];
  const holdEntries = Array.isArray(params.holdEntries) ?
    params.holdEntries : [];
  if (petCount > 0 && roomTypeCapacity > 0 && petCount > roomTypeCapacity) {
    return {
      remaining: 0,
      createdCount: 0,
      usableCount: 0,
      reservedCount: 0,
      freeCount: 0,
      zeroReason: `此房型最多容納 ${roomTypeCapacity} 隻寵物`,
    };
  }
  const typeRooms = rooms.filter((room) => roomMatchesType(room, roomTypeId))
      .map((room) => {
        return {id: normalizeString(room.id || room.roomId), ...room};
      });
  const createdCount = typeRooms.length;
  if (createdCount <= 0) {
    return {
      remaining: 0,
      createdCount: 0,
      usableCount: 0,
      reservedCount: 0,
      freeCount: 0,
      zeroReason: NO_PHYSICAL_ROOMS,
    };
  }
  let usableCount = 0;
  let free = 0;
  typeRooms.forEach((room) => {
    if (roomUnavailable(room)) {
      return;
    }
    const roomCap = toInt(room.capacity, 0) > 0 ?
      toInt(room.capacity, 0) : roomTypeCapacity;
    if (petCount > 0 && roomCap > 0 && petCount > roomCap) {
      return;
    }
    usableCount += 1;
    const roomId = normalizeString(room.id);
    if (!roomId) {
      return;
    }
    const calendarHit = calendarEntries.some((item) => {
      if (excludeBookingId &&
          normalizeString(item.bookingId) === excludeBookingId) {
        return false;
      }
      return normalizeString(item.roomId) === roomId &&
        normalizeString(item.date) === dateKey &&
        calendarBlocksRoom(item.status);
    });
    if (calendarHit) {
      return;
    }
    const occupancyHit = occupancies.some((occ) => {
      if (normalizeString(occ.roomId) !== roomId) {
        return false;
      }
      if (normalizeString(occ.bookingId) === excludeBookingId) {
        return false;
      }
      if (normalizeString(occ.status) &&
          normalizeString(occ.status) !== "active") {
        return false;
      }
      const occStart = toDate(occ.startAt);
      const occEnd = toDate(occ.endAt);
      if (!occStart || !occEnd) {
        return false;
      }
      const occMode = normalizeString(occ.occupancyMode) || "slot";
      if (occMode === "full_day") {
        return serviceDateKey(occStart) === dateKey;
      }
      return overlaps(startAt, endAt, occStart, occEnd);
    });
    if (occupancyHit) {
      return;
    }
    let busy = false;
    bookings.forEach((booking) => {
      if (busy) {
        return;
      }
      const bookingId = normalizeString(booking.id || booking.bookingId);
      if (bookingId === excludeBookingId) {
        return;
      }
      if (!occupiesInventory(booking)) {
        return;
      }
      if (normalizeString(booking.roomId) !== roomId) {
        return;
      }
      if (resolveBookingKind(booking) === BOOKING_KIND_DAYCARE) {
        const otherStart = toDate(booking.scheduledStartAt);
        const otherEnd = toDate(booking.scheduledEndAt);
        if (otherStart && otherEnd &&
            overlaps(startAt, endAt, otherStart, otherEnd)) {
          busy = true;
        }
        return;
      }
      const stayStart = toDate(booking.startDate);
      const stayEnd = toDate(booking.endDate);
      if (stayStart && stayEnd &&
          stayConflictsSlot(stayStart, stayEnd, startAt, endAt)) {
        busy = true;
      }
    });
    if (!busy) {
      free += 1;
    }
  });
  const reservedIds = new Set();
  overlappingHoldEntries(holdEntries, startAt, endAt, excludeBookingId)
      .forEach((item) => {
        const id = normalizeString(item.bookingId);
        if (id) {
          reservedIds.add(id);
        }
      });
  bookings.forEach((booking) => {
    const bookingId = normalizeString(booking.id || booking.bookingId);
    if (bookingId === excludeBookingId) {
      return;
    }
    if (!occupiesInventory(booking)) {
      return;
    }
    if (normalizeString(booking.roomId)) {
      return;
    }
    if (unassignedTypeId(booking) !== roomTypeId) {
      return;
    }
    if (resolveBookingKind(booking) === BOOKING_KIND_DAYCARE) {
      const otherStart = toDate(booking.scheduledStartAt);
      const otherEnd = toDate(booking.scheduledEndAt);
      if (otherStart && otherEnd &&
          overlaps(startAt, endAt, otherStart, otherEnd)) {
        reservedIds.add(bookingId);
      }
      return;
    }
    const stayStart = toDate(booking.startDate);
    const stayEnd = toDate(booking.endDate);
    if (stayStart && stayEnd &&
        stayConflictsSlot(stayStart, stayEnd, startAt, endAt)) {
      reservedIds.add(bookingId);
    }
  });
  const reservedCount = reservedIds.size;
  const remaining = Math.max(0, free - reservedCount);
  let zeroReason = "";
  if (remaining <= 0) {
    if (usableCount <= 0) {
      zeroReason = NO_USABLE_ROOMS;
    } else {
      zeroReason = ROOM_TYPE_SOLD_OUT;
    }
  }
  return {
    remaining,
    createdCount,
    usableCount,
    reservedCount,
    freeCount: free,
    zeroReason,
  };
}

/**
 * 臨托只占用時段。房型模式用 requestedRoomTypeId 檢查可賣實體房間。
 * 方案模式請不要傳 roomTypeId，避免誤擋。
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
    return {ok: true, reason: "", remaining: 999999};
  }
  const dateKey = serviceDateKey(startAt);
  const roomsSnap = await firestore.collection("shops").doc(shopId)
      .collection("rooms").get();
  const rooms = roomsSnap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const typeRooms = rooms.filter((room) => roomMatchesType(room, roomTypeId));
  const calendarEntries = [];
  for (const room of typeRooms) {
    const calSnap = await firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${room.id}_${dateKey}`).get();
    if (calSnap.exists) {
      calendarEntries.push({id: calSnap.id, ...(calSnap.data() || {})});
    }
  }
  const occSnap = await firestore.collection("shops").doc(shopId)
      .collection("room_occupancies").where("status", "==", "active").get();
  const occupancies = occSnap.docs.map((doc) => doc.data() || {});
  const bookingsSnap = await firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES)
      .get();
  const bookings = bookingsSnap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const holdSnap = await holdDocRef(
      firestore, shopId, roomTypeId, dateKey,
  ).get();
  const computed = remainingRoomsFromData({
    rooms,
    bookings,
    occupancies,
    calendarEntries,
    holdEntries: listHoldEntries(holdSnap.data()),
    roomTypeId,
    startAt,
    endAt,
    excludeBookingId,
    petCount: toInt(params.petCount, 0),
    roomTypeCapacity: toInt(params.roomTypeCapacity, 0),
    dateKey,
  });
  if (computed.remaining <= 0) {
    return {
      ok: false,
      reason: computed.zeroReason || ROOM_TYPE_SOLD_OUT,
      remaining: 0,
    };
  }
  return {ok: true, reason: "", remaining: computed.remaining};
}

/**
 * Transaction 內先讀後寫：只讀取並檢查可賣剩餘。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function loadRoomTypeHoldState(transaction, firestore, params) {
  const shopId = normalizeString(params.shopId);
  const roomTypeId = normalizeString(params.roomTypeId);
  const startAt = params.startAt;
  const endAt = params.endAt;
  const bookingId = normalizeString(params.bookingId);
  const dateKey = serviceDateKey(startAt);
  if (!shopId || !roomTypeId || !bookingId || !startAt || !endAt) {
    throw new Error("缺少安親房型保留資料");
  }
  const holdRef = holdDocRef(firestore, shopId, roomTypeId, dateKey);
  const roomsRef = firestore.collection("shops").doc(shopId)
      .collection("rooms");
  const occQuery = firestore.collection("shops").doc(shopId)
      .collection("room_occupancies").where("status", "==", "active");
  const bookingsQuery = firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES);
  const holdSnap = await transaction.get(holdRef);
  const roomsSnap = await transaction.get(roomsRef);
  const occSnap = await transaction.get(occQuery);
  const bookingsSnap = await transaction.get(bookingsQuery);
  const rooms = roomsSnap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const typeRooms = rooms.filter((room) => roomMatchesType(room, roomTypeId));
  const calendarEntries = [];
  for (const room of typeRooms) {
    const calRef = firestore.collection("shops").doc(shopId)
        .collection("room_calendar").doc(`${room.id}_${dateKey}`);
    const calSnap = await transaction.get(calRef);
    if (calSnap.exists) {
      calendarEntries.push({id: calSnap.id, ...(calSnap.data() || {})});
    }
  }
  const computed = remainingRoomsFromData({
    rooms,
    bookings: bookingsSnap.docs.map((doc) => {
      return {id: doc.id, ...(doc.data() || {})};
    }),
    occupancies: occSnap.docs.map((doc) => doc.data() || {}),
    calendarEntries,
    holdEntries: listHoldEntries(holdSnap.data()),
    roomTypeId,
    startAt,
    endAt,
    excludeBookingId: bookingId,
    petCount: toInt(params.petCount, 0),
    roomTypeCapacity: toInt(params.roomTypeCapacity, 0),
    dateKey,
  });
  if (computed.remaining <= 0) {
    const error = new Error(computed.zeroReason || ROOM_TYPE_SOLD_OUT);
    error.code = "failed-precondition";
    throw error;
  }
  return {
    holdRef,
    holdData: holdSnap.data() || {},
    shopId,
    roomTypeId,
    dateKey,
    startAt,
    endAt,
    bookingId,
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} state
 */
function commitRoomTypeHold(transaction, state) {
  const next = listHoldEntries(state.holdData).filter((item) => {
    return normalizeString(item.bookingId) !== state.bookingId;
  });
  next.push({
    bookingId: state.bookingId,
    startAt: state.startAt.toISOString(),
    endAt: state.endAt.toISOString(),
    occupancyMode: state.occupancyMode || "slot",
    bookingKind: state.bookingKind || BOOKING_KIND_DAYCARE,
  });
  writeHoldEntries(
      transaction,
      state.holdRef,
      state.shopId,
      state.roomTypeId,
      state.dateKey,
      next,
  );
}

/**
 * @param {Date} startDate
 * @param {Date} endDate
 * @return {Array<string>}
 */
function stayNightKeys(startDate, endDate) {
  const startKey = taipeiDateKey(startDate);
  const endKey = taipeiDateKey(endDate);
  if (!startKey || !endKey || startKey >= endKey) {
    return [];
  }
  const keys = [];
  let cursor = startKey;
  let guard = 0;
  while (cursor < endKey && guard < 400) {
    keys.push(cursor);
    cursor = addCalendarDays(cursor, 1);
    guard += 1;
  }
  return keys;
}

/**
 * 住宿夜晚不含退房日。自動清潔開啟時，blockedKeys 才另外含退房日。
 * @param {*} startDate
 * @param {*} endDate
 * @param {boolean} autoCleaning
 * @return {{nights: Array<string>, checkoutKey: string,
 *   blockedKeys: Array<string>}}
 */
function stayCalendarPlan(startDate, endDate, autoCleaning) {
  const nights = stayNightKeys(startDate, endDate);
  const endKey = taipeiDateKey(endDate);
  const checkoutKey = autoCleaning === true && endKey &&
    nights.indexOf(endKey) < 0 ? endKey : "";
  const blockedKeys = nights.slice();
  if (checkoutKey) {
    blockedKeys.push(checkoutKey);
  }
  return {nights, checkoutKey, blockedKeys};
}

/**
 * 釋放時一律含退房日，避免先前的清潔保留留下假鎖房。
 * @param {*} startDate
 * @param {*} endDate
 * @return {Array<string>}
 */
function stayReleaseDateKeys(startDate, endDate) {
  const nights = stayNightKeys(startDate, endDate);
  const endKey = taipeiDateKey(endDate);
  if (endKey && nights.indexOf(endKey) < 0) {
    return nights.concat([endKey]);
  }
  return nights;
}

/**
 * 台灣日曆日 00:00 的絕對時間。
 * @param {string} dateKey
 * @return {Date}
 */
function dateFromKey(dateKey) {
  const key = taipeiDateKey(dateKey);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) {
    return new Date(NaN);
  }
  return new Date(`${key}T00:00:00+08:00`);
}

/**
 * Transaction 內為住宿每一夜讀取同一套可賣剩餘並準備 hold。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<Array<Object>>}
 */
async function loadStayRoomTypeHoldStates(transaction, firestore, params) {
  const shopId = normalizeString(params.shopId);
  const roomTypeId = normalizeString(params.roomTypeId);
  const bookingId = normalizeString(params.bookingId);
  const plan = stayCalendarPlan(
      params.startDate,
      params.endDate,
      params.autoCleaning !== false,
  );
  const dateKeys = plan.blockedKeys;
  if (!shopId || !roomTypeId || !bookingId || plan.nights.length === 0) {
    throw new Error("缺少住宿房型保留資料");
  }
  const roomsRef = firestore.collection("shops").doc(shopId)
      .collection("rooms");
  const occQuery = firestore.collection("shops").doc(shopId)
      .collection("room_occupancies").where("status", "==", "active");
  const bookingsQuery = firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("status", "in", ACTIVE_STATUSES);
  const roomsSnap = await transaction.get(roomsRef);
  const occSnap = await transaction.get(occQuery);
  const bookingsSnap = await transaction.get(bookingsQuery);
  const rooms = roomsSnap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const typeRooms = rooms.filter((room) => roomMatchesType(room, roomTypeId));
  const bookings = bookingsSnap.docs.map((doc) => {
    return {id: doc.id, ...(doc.data() || {})};
  });
  const occupancies = occSnap.docs.map((doc) => doc.data() || {});
  const states = [];
  for (const dateKey of dateKeys) {
    const holdRef = holdDocRef(firestore, shopId, roomTypeId, dateKey);
    const holdSnap = await transaction.get(holdRef);
    const calendarEntries = [];
    for (const room of typeRooms) {
      const calRef = firestore.collection("shops").doc(shopId)
          .collection("room_calendar").doc(`${room.id}_${dateKey}`);
      const calSnap = await transaction.get(calRef);
      if (calSnap.exists) {
        calendarEntries.push({id: calSnap.id, ...(calSnap.data() || {})});
      }
    }
    const startAt = dateFromKey(dateKey);
    const endAt = dateFromKey(addCalendarDays(dateKey, 1));
    const computed = remainingRoomsFromData({
      rooms,
      bookings,
      occupancies,
      calendarEntries,
      holdEntries: listHoldEntries(holdSnap.data()),
      roomTypeId,
      startAt,
      endAt,
      excludeBookingId: bookingId,
      dateKey,
    });
    if (computed.remaining <= 0) {
      const error = new Error(computed.zeroReason || ROOM_TYPE_SOLD_OUT);
      error.code = "failed-precondition";
      throw error;
    }
    states.push({
      holdRef,
      holdData: holdSnap.data() || {},
      shopId,
      roomTypeId,
      dateKey,
      startAt,
      endAt,
      bookingId,
      occupancyMode: "full_day",
      bookingKind: BOOKING_KIND_ACCOMMODATION,
    });
  }
  return states;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} booking
 * @return {Promise<void>}
 */
async function releaseStayRoomTypeHoldsInTransaction(
    transaction, firestore, booking,
) {
  const shopId = normalizeString(booking && booking.shopId);
  const roomTypeId = unassignedTypeId(booking);
  const bookingId = normalizeString(
      (booking && (booking.id || booking.bookingId)) || "",
  );
  const dateKeys = stayReleaseDateKeys(
      booking && booking.startDate,
      booking && booking.endDate,
  );
  if (!shopId || !roomTypeId || !bookingId || dateKeys.length === 0) {
    return;
  }

  // 第一段：所有 Firestore 讀取先全部完成
  const holdStates = [];
  for (const dateKey of dateKeys) {
    const holdRef = holdDocRef(firestore, shopId, roomTypeId, dateKey);
    const holdSnap = await transaction.get(holdRef);

    if (holdSnap.exists) {
      holdStates.push({
        holdRef,
        holdData: holdSnap.data(),
        dateKey,
      });
    }
  }

  // 第二段：讀完後才開始寫入
  for (const state of holdStates) {
    releaseHoldEntries(
        transaction,
        state.holdRef,
        state.holdData,
        bookingId,
        shopId,
        roomTypeId,
        state.dateKey,
    );
  }
}

/**
 * Transaction 內重算未分房保留後才允許建單。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<void>}
 */
async function reserveRoomTypeHoldInTransaction(
    transaction, firestore, params,
) {
  const state = await loadRoomTypeHoldState(transaction, firestore, params);
  commitRoomTypeHold(transaction, state);
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} booking
 * @return {Promise<void>}
 */
async function releaseRoomTypeHoldInTransaction(
    transaction, firestore, booking,
) {
  const holdRef = holdRefForBooking(firestore, booking);
  if (!holdRef) {
    return;
  }
  const holdSnap = await transaction.get(holdRef);
  if (!holdSnap.exists) {
    return;
  }
  const bookingId = normalizeString(booking.id || booking.bookingId);
  const dateKey = normalizeString(booking.serviceDate) ||
    (toDate(booking.scheduledStartAt) ?
      serviceDateKey(toDate(booking.scheduledStartAt)) : "");
  releaseHoldEntries(
      transaction,
      holdRef,
      holdSnap.data(),
      bookingId,
      normalizeString(booking.shopId),
      unassignedTypeId(booking),
      dateKey,
  );
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
/**
 * 純函式：檢查占用紀錄是否與指定時段重疊（供測試與 Transaction 共用）
 * @param {Array<Object>} occupancies
 * @param {Date} startAt
 * @param {Date} endAt
 * @param {string} excludeBookingId
 * @param {string} occupancyMode
 * @return {boolean}
 */
function hasOverlappingOccupancy(
    occupancies, startAt, endAt, excludeBookingId, occupancyMode,
) {
  const mode = occupancyMode || "slot";
  const serviceDate = serviceDateKey(startAt);
  for (const occ of occupancies) {
    if (normalizeString(occ.bookingId) === normalizeString(excludeBookingId)) {
      continue;
    }
    if (normalizeString(occ.status) &&
        normalizeString(occ.status) !== "active") {
      continue;
    }
    const occStart = occ.startAt instanceof Date ?
      occ.startAt : toDate(occ.startAt);
    const occEnd = occ.endAt instanceof Date ? occ.endAt : toDate(occ.endAt);
    if (!occStart || !occEnd) {
      continue;
    }
    const occMode = normalizeString(occ.occupancyMode) || "slot";
    if (occMode === "full_day" || mode === "full_day") {
      if (serviceDateKey(occStart) === serviceDate) {
        return true;
      }
    } else if (overlaps(startAt, endAt, occStart, occEnd)) {
      return true;
    }
  }
  return false;
}

/**
 * Transaction 內再檢查同一房間占用，並更新房間文件作為鎖。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<void>}
 */
async function assertRoomFreeInTransaction(transaction, firestore, params) {
  const shopId = params.shopId;
  const roomId = normalizeString(params.roomId);
  const startAt = params.startAt;
  const endAt = params.endAt;
  const excludeBookingId = normalizeString(params.excludeBookingId);
  const occupancyMode = normalizeString(params.occupancyMode) || "slot";
  if (!roomId) {
    return;
  }
  const roomRef = firestore.collection("shops").doc(shopId)
      .collection("rooms").doc(roomId);
  await transaction.get(roomRef);
  const occSnap = await transaction.get(
      firestore.collection("shops").doc(shopId)
          .collection("room_occupancies")
          .where("roomId", "==", roomId)
          .where("status", "==", "active"),
  );
  const occupancies = occSnap.docs.map((doc) => doc.data() || {});
  if (hasOverlappingOccupancy(
      occupancies, startAt, endAt, excludeBookingId, occupancyMode,
  )) {
    const error = new Error("此時段房間已被占用");
    error.code = "failed-precondition";
    throw error;
  }
  transaction.update(roomRef, {
    occupancyLockAt: admin.firestore.FieldValue.serverTimestamp(),
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
  CHECKOUT_CLEANING_STATUS,
  occupiesInventory,
  stayConflictsSlot,
  autoCleaningAfterCheckout,
  isManualCalendarStatus,
  canReleaseOwnedCalendar,
  readBookingAutoCleaning,
  newStayAutoCleaningSnapshot,
  stayAutoCleaningForRebuild,
  checkoutDayOnStayCheckout,
  canApplyRoomCalendarStatus,
  stayCalendarPlan,
  stayReleaseDateKeys,
  taipeiDateKey,
  assertAvailable,
  assertRoomTypeCapacity,
  remainingRoomsFromData,
  roomUnavailable,
  roomPermanentStatus,
  roomPermanentlyUnsellable,
  roomMatchesType,
  calendarBlocksRoom,
  calendarCleaningFields,
  stayNightKeys,
  loadStayRoomTypeHoldStates,
  releaseStayRoomTypeHoldsInTransaction,
  holdDocId,
  holdDocRef,
  holdRefForBooking,
  listHoldEntries,
  overlappingHoldEntries,
  writeHoldEntries,
  reserveRoomTypeHoldInTransaction,
  loadRoomTypeHoldState,
  commitRoomTypeHold,
  releaseHoldEntries,
  applyHoldReleaseFromSnap,
  holdIdentity,
  releaseRoomTypeHoldInTransaction,
  writeOccupancy,
  loadActiveOccupancies,
  releaseOccupancyDocs,
  releaseOccupancies,
  hasOverlappingOccupancy,
  assertRoomFreeInTransaction,
  NO_PHYSICAL_ROOMS,
  NO_USABLE_ROOMS,
  ROOM_TYPE_SOLD_OUT,
};
