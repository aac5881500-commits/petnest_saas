// 檔案名稱：functions/daycare/daycare_capacity.js
// 功能說明：安親每日名額的原子計數。檢查與占用同一筆 transaction。

const admin = require("firebase-admin");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {
  BOOKING_KIND_DAYCARE,
  normalizeString,
  resolveBookingKind,
  toInt,
} = require("./daycare_utils");
const {
  bookingServiceDate,
  loadActiveShopBookings,
  occupiedPetsForDate,
  occupiesInventory,
  petSlotsOf,
} = require("./daycare_occupancy");

const CAPACITY_FULL_MESSAGE = "此日期安親名額已滿，請選擇其他日期。";

/**
 * @param {string} shopId
 * @param {string} dateKey
 * @return {string}
 */
function capacityDocPath(shopId, dateKey) {
  return `shops/${shopId}/daycare_capacity/${dateKey}`;
}

/**
 * @param {string} shopId
 * @param {string} dateKey
 * @param {string} bookingId
 * @return {string}
 */
function capacityReservationPath(shopId, dateKey, bookingId) {
  return `${capacityDocPath(shopId, dateKey)}/reservations/${bookingId}`;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} dateKey
 * @return {FirebaseFirestore.DocumentReference}
 */
function capacityDocRef(firestore, shopId, dateKey) {
  return firestore.collection("shops").doc(shopId)
      .collection("daycare_capacity").doc(dateKey);
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} dateKey
 * @param {string} bookingId
 * @return {FirebaseFirestore.DocumentReference}
 */
function capacityReservationRef(firestore, shopId, dateKey, bookingId) {
  return capacityDocRef(firestore, shopId, dateKey)
      .collection("reservations").doc(bookingId);
}

/**
 * 既有有效安親訂單。取消、其他店、其他日期不計入。
 * @param {Array<Object>} bookings
 * @param {string} shopId
 * @param {string} dateKey
 * @return {Array<{bookingId: string, pets: number}>}
 */
function seedReservations(bookings, shopId, dateKey) {
  const rows = [];
  (Array.isArray(bookings) ? bookings : []).forEach((booking) => {
    const row = booking || {};
    const rowShop = normalizeString(row.shopId);
    if (rowShop && rowShop !== shopId) {
      return;
    }
    if (!occupiesInventory(row)) {
      return;
    }
    if (resolveBookingKind(row) !== BOOKING_KIND_DAYCARE) {
      return;
    }
    if (bookingServiceDate(row) !== dateKey) {
      return;
    }
    const bookingId = normalizeString(row.id || row.bookingId);
    const pets = petSlotsOf(row);
    if (!bookingId || pets <= 0) {
      return;
    }
    rows.push({bookingId, pets});
  });
  return rows;
}

/**
 * @param {Object} input
 * @return {Object}
 */
function planDailyCapacityReserve(input) {
  const params = input || {};
  const dailyMaxPets = toInt(params.dailyMaxPets, 0);
  const requested = Math.max(0, toInt(params.requestedPets, 0));
  const shopId = normalizeString(params.shopId);
  const dateKey = normalizeString(params.dateKey);
  const bookingId = normalizeString(params.bookingId);
  const capacity = dailyMaxPets > 0 ? dailyMaxPets : 0;
  if (requested < 1 || !shopId || !dateKey || !bookingId) {
    return {
      ok: false,
      write: false,
      code: "invalid-argument",
      reason: "安親名額資料不正確",
      reservedPets: 0,
      capacity,
    };
  }
  if (params.reservation) {
    const reservedPets = Math.max(0, toInt(params.reservedPets, 0));
    return {
      ok: true,
      write: false,
      idempotent: true,
      unlimited: capacity <= 0,
      reservedPets,
      capacity,
      shopId,
      dateKey,
    };
  }
  let reserved = Math.max(0, toInt(params.reservedPets, 0));
  let seeds = [];
  if (!params.counterExists) {
    seeds = seedReservations(params.seedBookings, shopId, dateKey)
        .filter((row) => row.bookingId !== bookingId);
    reserved = seeds.reduce((sum, row) => sum + row.pets, 0);
  }
  const next = reserved + requested;
  if (capacity > 0 && next > capacity) {
    return {
      ok: false,
      write: false,
      code: "resource-exhausted",
      reason: CAPACITY_FULL_MESSAGE,
      reservedPets: reserved,
      capacity,
      shopId,
      dateKey,
    };
  }
  return {
    ok: true,
    write: true,
    unlimited: capacity <= 0,
    reservedPets: next,
    capacity,
    shopId,
    dateKey,
    seeds,
    reservation: {bookingId, pets: requested},
  };
}

/**
 * @param {Object} input
 * @return {Object}
 */
function planDailyCapacityRelease(input) {
  const params = input || {};
  const reserved = Math.max(0, toInt(params.reservedPets, 0));
  if (!params.counterExists || !params.reservation) {
    return {write: false, reservedPets: reserved};
  }
  const pets = Math.max(0, toInt(params.reservation.pets, 0));
  return {
    write: true,
    reservedPets: Math.max(0, reserved - pets),
    releasedPets: pets,
  };
}

/**
 * @param {Object} plan
 * @return {Array<Object>}
 */
function capacityReservationWrites(plan) {
  if (!plan || plan.write !== true) {
    return [];
  }
  const writes = [];
  (plan.seeds || []).forEach((seed) => {
    writes.push({
      path: capacityReservationPath(plan.shopId, plan.dateKey, seed.bookingId),
      data: {pets: seed.pets},
    });
  });
  writes.push({
    path: capacityReservationPath(
        plan.shopId, plan.dateKey, plan.reservation.bookingId,
    ),
    data: {pets: plan.reservation.pets},
  });
  writes.push({
    path: capacityDocPath(plan.shopId, plan.dateKey),
    data: {
      dateKey: plan.dateKey,
      reservedPets: plan.reservedPets,
      initialized: true,
    },
  });
  return writes;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Array<Object>} writes
 */
function commitCapacityWrites(transaction, writes) {
  const stamped = admin.firestore.FieldValue.serverTimestamp();
  writes.forEach((write) => {
    transaction.set(write.ref, {
      ...write.data,
      updatedAt: stamped,
    }, {merge: true});
  });
}

/**
 * 只讀。dailyMaxPets 從店家設定重讀，不採用呼叫端傳入的上限。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function readDailyCapacityReserve(transaction, firestore, params) {
  const shopId = normalizeString(params.shopId);
  const dateKey = normalizeString(params.dateKey);
  const bookingId = normalizeString(params.bookingId);
  const settingsSnap = await transaction.get(
      firestore.collection("shops").doc(shopId)
          .collection("daycare_settings").doc("main"),
  );
  const dailyMaxPets = toInt(
      (settingsSnap.data() || {}).dailyMaxPets, 0,
  );
  const counterRef = capacityDocRef(firestore, shopId, dateKey);
  const reservationRef = capacityReservationRef(
      firestore, shopId, dateKey, bookingId,
  );
  const counterSnap = await transaction.get(counterRef);
  const reservationSnap = await transaction.get(reservationRef);
  let seedBookings = [];
  if (!counterSnap.exists) {
    seedBookings = await loadActiveShopBookings(
        (query) => transaction.get(query), firestore, shopId,
    );
  }
  const reservedPets = counterSnap.exists ?
    (counterSnap.data() || {}).reservedPets : 0;
  const plan = planDailyCapacityReserve({
    dailyMaxPets,
    requestedPets: params.requestedPets,
    shopId,
    dateKey,
    bookingId,
    counterExists: counterSnap.exists,
    reservedPets,
    reservation: reservationSnap.exists ?
      (reservationSnap.data() || {}) : null,
    seedBookings,
  });
  const writes = capacityReservationWrites(plan).map((write) => {
    const reservationId = write.path.split("/").pop();
    const ref = write.path.indexOf("/reservations/") >= 0 ?
      capacityReservationRef(firestore, shopId, dateKey, reservationId) :
      counterRef;
    return {ref, data: write.data};
  });
  return {...plan, writes};
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} plan
 */
function commitDailyCapacityReserve(transaction, plan) {
  if (!plan || !plan.write) {
    return;
  }
  commitCapacityWrites(transaction, plan.writes || []);
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} booking
 * @return {Promise<Object>}
 */
async function readDailyCapacityRelease(transaction, firestore, booking) {
  const row = booking || {};
  const shopId = normalizeString(row.shopId);
  const bookingId = normalizeString(row.id || row.bookingId);
  const dateKey = bookingServiceDate(row);
  if (!shopId || !bookingId || !dateKey) {
    return {write: false, reservedPets: 0, writes: []};
  }
  const counterRef = capacityDocRef(firestore, shopId, dateKey);
  const reservationRef = capacityReservationRef(
      firestore, shopId, dateKey, bookingId,
  );
  const counterSnap = await transaction.get(counterRef);
  const reservationSnap = await transaction.get(reservationRef);
  const plan = planDailyCapacityRelease({
    counterExists: counterSnap.exists,
    reservedPets: counterSnap.exists ?
      (counterSnap.data() || {}).reservedPets : 0,
    reservation: reservationSnap.exists ?
      (reservationSnap.data() || {}) : null,
  });
  return {
    ...plan,
    counterRef,
    reservationRef,
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} plan
 */
function commitDailyCapacityRelease(transaction, plan) {
  if (!plan || !plan.write) {
    return;
  }
  transaction.delete(plan.reservationRef);
  transaction.set(plan.counterRef, {
    reservedPets: plan.reservedPets,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

/**
 * 有初始化過的 counter 就以它為準。還沒有才回退到既有訂單加總。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} dateKey
 * @param {Array<Object>} fallbackBookings
 * @return {Promise<number>}
 */
async function readAuthoritativeOccupied(
    firestore, shopId, dateKey, fallbackBookings,
) {
  const snap = await capacityDocRef(firestore, shopId, dateKey).get();
  const data = snap.exists ? (snap.data() || {}) : null;
  if (data && data.initialized === true) {
    return Math.max(0, toInt(data.reservedPets, 0));
  }
  return occupiedPetsForDate(fallbackBookings, {shopId, serviceDate: dateKey});
}

/**
 * 顧客直接把訂單改成取消時，Function 的取消交易不會跑到。
 * 這裡用同一個 release，重複執行不會再減一次。
 * @param {Object} event
 * @return {Promise<void>}
 */
async function releaseDaycareCapacityOnBookingChange(event) {
  if (!event || !event.data) {
    return;
  }
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const beforeKind = resolveBookingKind(before);
  const afterKind = resolveBookingKind(after);
  if (beforeKind !== BOOKING_KIND_DAYCARE &&
      afterKind !== BOOKING_KIND_DAYCARE) {
    return;
  }
  if (occupiesInventory(after)) {
    return;
  }
  if (!occupiesInventory(before)) {
    return;
  }
  const bookingId = event.params && event.params.bookingId;
  const booking = {...after, id: bookingId, bookingId};
  await admin.firestore().runTransaction(async (transaction) => {
    const plan = await readDailyCapacityRelease(
        transaction, admin.firestore(), booking,
    );
    commitDailyCapacityRelease(transaction, plan);
  });
}

const releaseDaycareCapacityOnBooking = onDocumentUpdated(
    {
      document: "bookings/{bookingId}",
      region: "asia-east1",
    },
    releaseDaycareCapacityOnBookingChange,
);

module.exports = {
  CAPACITY_FULL_MESSAGE,
  capacityDocPath,
  capacityReservationPath,
  seedReservations,
  planDailyCapacityReserve,
  planDailyCapacityRelease,
  capacityReservationWrites,
  readDailyCapacityReserve,
  commitDailyCapacityReserve,
  readDailyCapacityRelease,
  commitDailyCapacityRelease,
  readAuthoritativeOccupied,
  releaseDaycareCapacityOnBookingChange,
  releaseDaycareCapacityOnBooking,
};
