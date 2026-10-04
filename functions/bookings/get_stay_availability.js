// 檔案名稱：functions/bookings/get_stay_availability.js
// 功能說明：住宿可售聚合。沿用 remainingRoomsFromData 與退房清潔計畫，不回傳房務明細。

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  addCalendarDays,
  normalizeString,
  toInt,
} = require("../daycare/daycare_utils");
const {
  autoCleaningAfterCheckout,
  listHoldEntries,
  loadActiveShopBookings,
  remainingRoomsFromData,
  stayCalendarPlan,
} = require("../daycare/daycare_occupancy");

const MAX_DATES = 62;
const MAX_STAY_NIGHTS = 120;
const MAX_ID_LENGTH = 128;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const ID_PATTERN = /^[A-Za-z0-9_-]+$/;

/**
 * @param {string} dateKey
 * @return {Date}
 */
function taipeiDayStart(dateKey) {
  return new Date(`${dateKey}T00:00:00+08:00`);
}

/**
 * @param {string} value
 * @return {string}
 */
function requireDateKey(value) {
  const text = normalizeString(value);
  if (!DATE_PATTERN.test(text)) {
    throw new HttpsError("invalid-argument", "日期格式必須是 YYYY-MM-DD");
  }
  const parts = text.split("-").map((item) => Number(item));
  const checked = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
  if (checked.getUTCFullYear() !== parts[0] ||
      checked.getUTCMonth() !== parts[1] - 1 ||
      checked.getUTCDate() !== parts[2]) {
    throw new HttpsError("invalid-argument", "日期不存在");
  }
  return text;
}

/**
 * @param {string} value
 * @param {string} label
 * @return {string}
 */
function requireId(value, label) {
  const text = normalizeString(value);
  if (!text || text.length > MAX_ID_LENGTH || !ID_PATTERN.test(text)) {
    throw new HttpsError("invalid-argument", `${label}不正確`);
  }
  return text;
}

/**
 * @param {string} value
 * @return {string}
 */
function optionalRoomTypeId(value) {
  const text = normalizeString(value);
  if (!text) {
    return "";
  }
  return requireId(text, "房型");
}

/**
 * @param {Array<string>} dates
 * @return {Array<string>}
 */
function uniqueSorted(dates) {
  const unique = [];
  dates.forEach((item) => {
    if (!unique.includes(item)) {
      unique.push(item);
    }
  });
  unique.sort();
  return unique;
}

/**
 * @param {Object} data
 * @return {{dates: Array<string>, startDate: string, endDate: string}}
 */
function readRange(data) {
  const body = data || {};
  const listed = Array.isArray(body.dates) ? body.dates : [];
  const dates = uniqueSorted(listed.map((item) => requireDateKey(item)));
  const startDate = normalizeString(body.startDate) ?
    requireDateKey(body.startDate) : "";
  const endDate = normalizeString(body.endDate) ?
    requireDateKey(body.endDate) : "";
  if ((startDate && !endDate) || (!startDate && endDate)) {
    throw new HttpsError("invalid-argument", "入住與退房日期需同時提供");
  }
  if (startDate && endDate <= startDate) {
    throw new HttpsError("invalid-argument", "退房日必須晚於入住日");
  }
  if (startDate && endDate) {
    const plan = stayCalendarPlan(startDate, endDate, true);
    if (plan.nights.length < 1 || plan.nights.length > MAX_STAY_NIGHTS) {
      throw new HttpsError("invalid-argument", "住宿天數不正確");
    }
  }
  const span = dates.length > 0 ?
    dates : (startDate ? [startDate, endDate] : []);
  if (span.length < 1) {
    throw new HttpsError("invalid-argument", "缺少查詢日期");
  }
  if (dates.length > MAX_DATES) {
    throw new HttpsError("invalid-argument", "一次最多查詢 62 個日期");
  }
  return {dates, startDate, endDate};
}

/**
 * @param {Object} item
 * @param {string} shopId
 * @return {boolean}
 */
function belongsToShop(item, shopId) {
  const owner = normalizeString(item && item.shopId);
  return !owner || owner === shopId;
}

/**
 * @param {Object} computed
 * @param {string} roomTypeId
 * @return {Object}
 */
function typeSummary(computed, roomTypeId) {
  const total = Math.max(0, toInt(computed && computed.usableCount, 0));
  const remaining = Math.max(0, toInt(computed && computed.remaining, 0));
  return {
    roomTypeId,
    total,
    occupied: Math.max(0, total - remaining),
    remaining,
    available: remaining > 0,
  };
}

/**
 * @param {Array<Object>} rows
 * @return {Object}
 */
function sumRows(rows) {
  const total = rows.reduce((sum, row) => sum + row.total, 0);
  const remaining = rows.reduce((sum, row) => sum + row.remaining, 0);
  return {
    total,
    occupied: Math.max(0, total - remaining),
    remaining,
    available: remaining > 0,
  };
}

/**
 * @param {Object} item
 * @return {string}
 */
function holdDateKey(item) {
  return normalizeString(
      item && (item.date || item.dateKey || item.serviceDate),
  );
}

/**
 * @param {Array<Object>} holds
 * @param {string} roomTypeId
 * @param {string} dateKey
 * @return {Array<Object>}
 */
function holdEntriesOn(holds, roomTypeId, dateKey) {
  const row = (holds || []).find((item) => {
    return normalizeString(item.roomTypeId) === roomTypeId &&
      holdDateKey(item) === dateKey;
  });
  return listHoldEntries(row);
}

/**
 * 用與建單相同的 remainingRoomsFromData 計算每一天。
 * @param {Object} params
 * @return {Object}
 */
function projectStayAvailability(params) {
  const shopId = normalizeString(params.shopId);
  const roomTypeFilter = normalizeString(params.roomTypeId);
  const petCount = toInt(params.petCount, 0);
  const autoCleaning = autoCleaningAfterCheckout(params.shop || {});
  const rooms = (Array.isArray(params.rooms) ? params.rooms : [])
      .filter((room) => belongsToShop(room, shopId));
  const roomTypes = (Array.isArray(params.roomTypes) ? params.roomTypes : [])
      .filter((row) => belongsToShop(row, shopId));
  const bookings = (Array.isArray(params.bookings) ? params.bookings : [])
      .filter((row) => belongsToShop(row, shopId));
  const occupancies = (Array.isArray(params.occupancies) ?
    params.occupancies : []).filter((row) => belongsToShop(row, shopId));
  const calendarEntries = (Array.isArray(params.calendarEntries) ?
    params.calendarEntries : []).filter((row) => belongsToShop(row, shopId));
  const holds = (Array.isArray(params.holds) ? params.holds : [])
      .filter((row) => belongsToShop(row, shopId));
  const typeIds = [];
  roomTypes.forEach((row) => {
    const id = normalizeString(row.id || row.roomTypeId);
    if (id && !typeIds.includes(id)) {
      typeIds.push(id);
    }
  });
  rooms.forEach((room) => {
    const id = normalizeString(room.roomTypeId);
    if (id && !typeIds.includes(id)) {
      typeIds.push(id);
    }
  });
  const selectedIds = roomTypeFilter ? [roomTypeFilter] : typeIds;
  if (roomTypeFilter && !typeIds.includes(roomTypeFilter)) {
    const error = new Error("房型不屬於這間店");
    error.code = "invalid-argument";
    throw error;
  }
  const requested = uniqueSorted(params.dates || []);
  const stayPlan = params.startDate && params.endDate ?
    stayCalendarPlan(params.startDate, params.endDate, autoCleaning) :
    {nights: [], checkoutKey: "", blockedKeys: []};
  const evaluateKeys = uniqueSorted(requested.concat(stayPlan.blockedKeys));
  const capacityOf = (roomTypeId) => {
    const row = roomTypes.find((item) => {
      return normalizeString(item.id || item.roomTypeId) === roomTypeId;
    }) || {};
    return toInt(row.capacity, 0);
  };
  const byDate = {};
  evaluateKeys.forEach((dateKey) => {
    const startAt = taipeiDayStart(dateKey);
    const endAt = taipeiDayStart(addCalendarDays(dateKey, 1));
    const dayCalendar = calendarEntries.filter((item) => {
      return normalizeString(item.date) === dateKey;
    });
    const rows = selectedIds.map((roomTypeId) => {
      return typeSummary(remainingRoomsFromData({
        rooms,
        bookings,
        occupancies,
        calendarEntries: dayCalendar,
        holdEntries: holdEntriesOn(holds, roomTypeId, dateKey),
        roomTypeId,
        startAt,
        endAt,
        dateKey,
        petCount,
        roomTypeCapacity: capacityOf(roomTypeId),
      }), roomTypeId);
    });
    const summed = sumRows(rows);
    byDate[dateKey] = {
      date: dateKey,
      total: summed.total,
      occupied: summed.occupied,
      remaining: summed.remaining,
      available: summed.available,
      roomTypes: rows,
    };
  });
  const dates = requested.map((dateKey) => byDate[dateKey]);
  const response = {shopId, dates};
  if (stayPlan.nights.length > 0) {
    const blocked = stayPlan.blockedKeys
        .map((dateKey) => byDate[dateKey])
        .filter(Boolean);
    const stayRows = selectedIds.map((roomTypeId) => {
      const samples = blocked.map((day) => {
        return day.roomTypes.find((row) => row.roomTypeId === roomTypeId);
      }).filter(Boolean);
      const remaining = samples.reduce((min, row) => {
        return Math.min(min, row.remaining);
      }, samples.length > 0 ? samples[0].remaining : 0);
      const total = samples.reduce((min, row) => {
        return Math.min(min, row.total);
      }, samples.length > 0 ? samples[0].total : 0);
      const safeRemaining = Math.max(0, remaining);
      const safeTotal = Math.max(0, total);
      return {
        roomTypeId,
        total: safeTotal,
        occupied: Math.max(0, safeTotal - safeRemaining),
        remaining: safeRemaining,
        available: safeRemaining > 0,
      };
    });
    const staySum = sumRows(stayRows);
    response.roomTypes = stayRows;
    response.stay = {
      startDate: params.startDate,
      endDate: params.endDate,
      total: staySum.total,
      occupied: staySum.occupied,
      remaining: staySum.remaining,
      available: staySum.available,
    };
    response.stayAvailable = staySum.available;
  }
  return response;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {Array<string>} dateKeys
 * @return {Promise<{calendarEntries: Array<Object>, holds: Array<Object>}>}
 */
async function loadDayLocks(firestore, shopId, dateKeys) {
  if (dateKeys.length < 1) {
    return {calendarEntries: [], holds: []};
  }
  const first = dateKeys[0];
  const last = dateKeys[dateKeys.length - 1];
  const shopRef = firestore.collection("shops").doc(shopId);
  const calendarSnap = await shopRef.collection("room_calendar")
      .where("date", ">=", first)
      .where("date", "<=", last)
      .get();
  const holdSnap = await shopRef.collection("daycare_room_type_holds").get();
  const wanted = new Set(dateKeys);
  return {
    calendarEntries: calendarSnap.docs.map((doc) => {
      return {id: doc.id, ...(doc.data() || {})};
    }).filter((row) => wanted.has(normalizeString(row.date))),
    holds: holdSnap.docs.map((doc) => {
      return {id: doc.id, ...(doc.data() || {})};
    }).filter((row) => wanted.has(holdDateKey(row))),
  };
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} data
 * @return {Promise<Object>}
 */
async function buildStayAvailability(firestore, data) {
  const shopId = requireId(data && data.shopId, "店家");
  const roomTypeId = optionalRoomTypeId(data && data.roomTypeId);
  const petCount = toInt(data && data.petCount, 0);
  if (petCount < 0 || petCount > 20) {
    throw new HttpsError("invalid-argument", "寵物數量不正確");
  }
  const range = readRange(data);
  const shopSnap = await firestore.collection("shops").doc(shopId).get();
  if (!shopSnap.exists) {
    throw new HttpsError("not-found", "找不到店家");
  }
  const shopRef = firestore.collection("shops").doc(shopId);
  const [roomsSnap, typesSnap, bookings, occSnap] = await Promise.all([
    shopRef.collection("rooms").get(),
    shopRef.collection("room_types").get(),
    loadActiveShopBookings((query) => query.get(), firestore, shopId),
    shopRef.collection("room_occupancies")
        .where("status", "==", "active")
        .get(),
  ]);
  const plan = range.startDate ?
    stayCalendarPlan(
        range.startDate,
        range.endDate,
        autoCleaningAfterCheckout(shopSnap.data() || {}),
    ) : {blockedKeys: []};
  const evaluateKeys = uniqueSorted(range.dates.concat(plan.blockedKeys));
  const locks = await loadDayLocks(firestore, shopId, evaluateKeys);
  try {
    return projectStayAvailability({
      shopId,
      shop: shopSnap.data() || {},
      rooms: roomsSnap.docs.map((doc) => {
        return {id: doc.id, ...(doc.data() || {})};
      }),
      roomTypes: typesSnap.docs.map((doc) => {
        return {id: doc.id, ...(doc.data() || {})};
      }),
      bookings,
      occupancies: occSnap.docs.map((doc) => doc.data() || {}),
      calendarEntries: locks.calendarEntries,
      holds: locks.holds,
      dates: range.dates,
      startDate: range.startDate,
      endDate: range.endDate,
      roomTypeId,
      petCount,
    });
  } catch (error) {
    if (error && error.code === "invalid-argument") {
      throw new HttpsError("invalid-argument", error.message);
    }
    throw error;
  }
}

/**
 * 住宿前台可未登入瀏覽剩餘房數。只回聚合數字。
 * @param {Object} request
 * @param {FirebaseFirestore.Firestore} firestore
 * @return {Promise<Object>}
 */
async function getStayAvailabilityHandler(request, firestore) {
  return buildStayAvailability(firestore, (request && request.data) || {});
}

const getStayAvailability = onCall(
    {region: "asia-east1"},
    async (request) => {
      const admin = require("firebase-admin");
      return getStayAvailabilityHandler(request, admin.firestore());
    },
);

module.exports = {
  getStayAvailability,
  getStayAvailabilityHandler,
  buildStayAvailability,
  projectStayAvailability,
};
