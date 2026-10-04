// 檔案名稱：functions/daycare/get_daycare_availability.js
// 功能說明：登入後查詢安親剩餘名額，只回傳聚合數字，不回傳其他顧客訂單。

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  isDaycareEnabled,
  normalizeString,
  serviceDateKey,
  toDate,
  toInt,
} = require("./daycare_utils");
const {persistPricingMode} = require("./daycare_pricing");
const {
  assertRoomTypeCapacity,
  dailyPetAvailability,
  loadActiveShopBookings,
} = require("./daycare_occupancy");
const {
  readAuthoritativeOccupied,
} = require("./daycare_capacity");

const MAX_DATES = 31;
const MAX_ID_LENGTH = 128;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

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
 * @param {Object} data
 * @return {Array<string>}
 */
function readDates(data) {
  const body = data || {};
  const many = Array.isArray(body.dates) ? body.dates : [];
  const single = normalizeString(body.date);
  const raw = many.length > 0 ? many : (single ? [single] : []);
  if (raw.length < 1 || raw.length > MAX_DATES) {
    throw new HttpsError("invalid-argument", "一次最多查詢 31 個日期");
  }
  const unique = [];
  raw.forEach((item) => {
    const key = requireDateKey(item);
    if (!unique.includes(key)) {
      unique.push(key);
    }
  });
  unique.sort();
  return unique;
}

/**
 * @param {string} value
 * @param {string} label
 * @return {string}
 */
function optionalId(value, label) {
  const text = normalizeString(value);
  if (!text) {
    return "";
  }
  if (text.length > MAX_ID_LENGTH || !/^[A-Za-z0-9_-]+$/.test(text)) {
    throw new HttpsError("invalid-argument", `${label}不正確`);
  }
  return text;
}

/**
 * @param {Object} data
 * @param {Array<string>} dates
 * @return {Object}
 */
function readSlot(data, dates) {
  const startText = normalizeString(data.startAt);
  const endText = normalizeString(data.endAt);
  if (!startText && !endText) {
    return {startAt: null, endAt: null};
  }
  const startAt = toDate(startText);
  const endAt = toDate(endText);
  if (!startAt || !endAt || endAt.getTime() <= startAt.getTime()) {
    throw new HttpsError("invalid-argument", "安親時段不正確");
  }
  const span = endAt.getTime() - startAt.getTime();
  if (span > 24 * 60 * 60 * 1000) {
    throw new HttpsError("invalid-argument", "安親時段不可超過 24 小時");
  }
  const startKey = serviceDateKey(startAt);
  if (!dates.includes(startKey)) {
    throw new HttpsError("invalid-argument", "時段日期與查詢日期不一致");
  }
  return {startAt, endAt};
}

/**
 * @param {Object} settings
 * @param {string} roomTypeId
 * @return {boolean}
 */
function settingsContainRoomType(settings, roomTypeId) {
  const rows = Array.isArray(settings.roomTypes) ? settings.roomTypes : [];
  return rows.some((row) => {
    return normalizeString(row && row.roomTypeId) === roomTypeId;
  });
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {Object} settings
 * @param {string} roomTypeId
 * @return {Promise<void>}
 */
async function assertRoomTypeBelongs(firestore, shopId, settings, roomTypeId) {
  if (!roomTypeId) {
    return;
  }
  if (settingsContainRoomType(settings, roomTypeId)) {
    return;
  }
  const typeSnap = await firestore.collection("shops").doc(shopId)
      .collection("room_types").doc(roomTypeId).get();
  if (typeSnap.exists) {
    const data = typeSnap.data() || {};
    const owner = normalizeString(data.shopId);
    if (!owner || owner === shopId) {
      return;
    }
  }
  const roomsSnap = await firestore.collection("shops").doc(shopId)
      .collection("rooms").where("roomTypeId", "==", roomTypeId).limit(1)
      .get();
  if (!roomsSnap.empty) {
    return;
  }
  throw new HttpsError("invalid-argument", "房型不屬於這間店");
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<Array<Object>>}
 */
async function roomTypeSummaries(firestore, params) {
  if (!params.roomBased || !params.startAt || !params.endAt) {
    return [];
  }
  const configured = Array.isArray(params.settings.roomTypes) ?
    params.settings.roomTypes : [];
  const ids = params.roomTypeId ? [params.roomTypeId] : configured
      .map((row) => normalizeString(row && row.roomTypeId))
      .filter(Boolean);
  const summaries = [];
  for (const roomTypeId of ids) {
    const checked = await assertRoomTypeCapacity(firestore, {
      shopId: params.shopId,
      roomTypeId,
      startAt: params.startAt,
      endAt: params.endAt,
      petCount: params.petCount,
    });
    if (checked.summary) {
      summaries.push(checked.summary);
    }
  }
  return summaries;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} data
 * @return {Promise<Object>}
 */
async function buildDaycareAvailability(firestore, data) {
  const shopId = optionalId(data.shopId, "店家");
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家編號");
  }
  const dates = readDates(data);
  const roomTypeId = optionalId(data.roomTypeId, "房型");
  const slot = readSlot(data, dates);
  const petCount = toInt(data.petCount, 0);
  if (petCount < 0 || petCount > 20) {
    throw new HttpsError("invalid-argument", "寵物數量不正確");
  }
  const shopSnap = await firestore.collection("shops").doc(shopId).get();
  if (!shopSnap.exists) {
    throw new HttpsError("not-found", "找不到店家");
  }
  const shop = shopSnap.data() || {};
  const settingsSnap = await firestore.collection("shops").doc(shopId)
      .collection("daycare_settings").doc("main").get();
  const settings = settingsSnap.data() || {};
  if (!isDaycareEnabled(shop, settings)) {
    throw new HttpsError("failed-precondition", "這間店目前沒有開放安親");
  }
  await assertRoomTypeBelongs(firestore, shopId, settings, roomTypeId);
  const bookings = await loadActiveShopBookings(
      (query) => query.get(), firestore, shopId,
  );
  const capacity = toInt(settings.dailyMaxPets, 0);
  const pricingMode = persistPricingMode(settings);
  const days = [];
  for (const date of dates) {
    const occupied = await readAuthoritativeOccupied(
        firestore, shopId, date, bookings,
    );
    const daily = dailyPetAvailability({capacity, occupied});
    days.push({
      date,
      capacity: daily.capacity,
      occupied: daily.occupied,
      remaining: daily.remaining,
      available: daily.available,
      unlimited: daily.unlimited,
    });
  }
  const roomTypes = await roomTypeSummaries(firestore, {
    shopId,
    settings,
    roomBased: pricingMode === "roomType",
    roomTypeId,
    startAt: slot.startAt,
    endAt: slot.endAt,
    petCount,
  });
  return {
    shopId,
    pricingMode,
    days,
    roomTypes,
  };
}

/**
 * @param {Object} request
 * @param {FirebaseFirestore.Firestore} firestore
 * @return {Promise<Object>}
 */
async function getDaycareAvailabilityHandler(request, firestore) {
  if (!request || !request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  return buildDaycareAvailability(firestore, (request && request.data) || {});
}

const getDaycareAvailability = onCall(
    {region: "asia-east1"},
    async (request) => {
      const admin = require("firebase-admin");
      return getDaycareAvailabilityHandler(request, admin.firestore());
    },
);

module.exports = {
  getDaycareAvailability,
  getDaycareAvailabilityHandler,
  buildDaycareAvailability,
};
