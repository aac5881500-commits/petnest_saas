// functions/daycare/daycare_utils.js
// 🐾 臨托共用工具：登入、店家、權限、金額、時間、操作紀錄

const admin = require("firebase-admin");

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";

const BOOKING_KIND_ACCOMMODATION = "accommodation";
const BOOKING_KIND_DAYCARE = "daycare";

const ACTIVE_STATUSES = ["pending", "confirmed", "checked_in"];

/**
 * @param {*} value
 * @return {string}
 */
function normalizeString(value) {
  return String(value || "").trim();
}

/**
 * @param {*} value
 * @param {boolean=} fallback
 * @return {boolean}
 */
function parseBool(value, fallback = false) {
  if (value === true || value === 1 || value === "1" || value === "true") {
    return true;
  }
  if (value === false || value === 0 || value === "0" || value === "false" ||
      value == null || value === "") {
    return false;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true" || normalized === "1") {
      return true;
    }
    if (normalized === "false" || normalized === "0") {
      return false;
    }
  }
  return fallback;
}

function toInt(value, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  const parsed = Number.parseInt(String(value || ""), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * @param {number} value
 * @return {number}
 */
function roundMoney(value) {
  return Math.round(Number(value) || 0);
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (typeof value === "number") {
    return new Date(value);
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * @param {Date} date
 * @return {Date}
 */
function taiwanDate(date) {
  return new Date(date.getTime() + 8 * 60 * 60 * 1000);
}

/**
 * @param {Date} date
 * @return {string} YYYY-MM-DD in Taiwan
 */
function serviceDateKey(date) {
  const local = taiwanDate(date);
  const y = local.getUTCFullYear();
  const m = String(local.getUTCMonth() + 1).padStart(2, "0");
  const d = String(local.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/**
 * @param {string} hhmm
 * @return {number}
 */
function minutesOf(hhmm) {
  const parts = String(hhmm || "").split(":");
  const hour = toInt(parts[0], 0);
  const minute = toInt(parts[1], 0);
  return hour * 60 + minute;
}

/**
 * @param {Date} date
 * @return {number} 1-7 ISO weekday in Taiwan
 */
function weekdayTaiwan(date) {
  const local = taiwanDate(date);
  const utcDay = local.getUTCDay();
  return utcDay === 0 ? 7 : utcDay;
}

/**
 * @param {Date} date
 * @return {string} yyyyMMdd
 */
function overrideDocId(date) {
  return serviceDateKey(date).replace(/-/g, "");
}

/**
 * @param {string} value
 * @return {string}
 */
function optionalTime(value) {
  const text = normalizeString(value);
  return /^\d{2}:\d{2}$/.test(text) ? text : "";
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {Date} date
 * @return {Promise<Object|null>}
 */
async function loadDateOverride(firestore, shopId, date) {
  const snap = await firestore.collection("shops").doc(shopId)
      .collection("daycare_date_overrides").doc(overrideDocId(date)).get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() || {};
}

/**
 * @param {Object} settings
 * @param {Object|null} override
 * @param {Date} date
 * @return {boolean}
 */
function isDateOpen(settings, override, date) {
  if (override) {
    return override.isOpen === true;
  }
  const weekdays = Array.isArray(settings.weekdays) ?
    settings.weekdays.map((item) => toInt(item, 0)) :
    [1, 2, 3, 4, 5, 6, 7];
  return weekdays.includes(weekdayTaiwan(date));
}

/**
 * @param {Object} settings
 * @param {Object|null} override
 * @return {number}
 */
function resolveDailyMaxPets(settings, override) {
  const overrideMax = toInt(override && override.maxPets, 0);
  if (overrideMax > 0) {
    return overrideMax;
  }
  return toInt(settings.dailyMaxPets, 0);
}

/**
 * @param {Object} settings
 * @param {Object|null} override
 * @return {{openTime: string, closeTime: string, earliestDropOff: string,
 *   latestPickUp: string, latestDropoffTime: string}}
 */
function resolveDayHours(settings, override) {
  const openTime = optionalTime(override && override.openTime) ||
    (settings.openTime || "09:00");
  const closeTime = optionalTime(override && override.closeTime) ||
    (settings.closeTime || "18:00");
  const latestPickup = optionalTime(override && override.latestPickupTime) ||
    optionalTime(override && override.closeTime) ||
    (settings.latestPickUp || closeTime);
  return {
    openTime,
    closeTime,
    earliestDropOff: optionalTime(override && override.openTime) ||
      (settings.earliestDropOff || openTime),
    latestPickUp: latestPickup,
    latestDropoffTime: optionalTime(override && override.latestDropoffTime),
  };
}

/**
 * @param {Object|null} data
 * @return {string}
 */
function resolveBookingKind(data) {
  const kind = normalizeString(data && data.bookingKind);
  if (kind === BOOKING_KIND_DAYCARE) {
    return BOOKING_KIND_DAYCARE;
  }
  if (kind === BOOKING_KIND_ACCOMMODATION) {
    return BOOKING_KIND_ACCOMMODATION;
  }
  if (normalizeString(data && data.serviceType) === BOOKING_KIND_DAYCARE) {
    return BOOKING_KIND_DAYCARE;
  }
  return BOOKING_KIND_ACCOMMODATION;
}

/**
 * @param {string} uid
 * @return {boolean}
 */
function isRootAdmin(uid) {
  return uid === ROOT_ADMIN_UID;
}

/**
 * @param {string} shopId
 * @param {string} uid
 * @return {Promise<Object|null>}
 */
async function getShopMember(shopId, uid) {
  const snap = await admin.firestore()
      .collection("shop_members")
      .doc(`${shopId}_${uid}`)
      .get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() || {};
}

/**
 * @param {string} shopId
 * @param {string} uid
 * @param {string} permissionKey
 * @return {Promise<boolean>}
 */
async function hasShopPermission(shopId, uid, permissionKey) {
  if (isRootAdmin(uid)) {
    return true;
  }
  const member = await getShopMember(shopId, uid);
  if (!member) {
    return false;
  }
  if (normalizeString(member.role) === "owner") {
    return true;
  }
  const permissions = member.permissions && typeof member.permissions ===
    "object" ? member.permissions : {};
  return permissions[permissionKey] === true;
}

/**
 * @param {*} raw
 * @param {string} serviceType
 * @return {boolean}
 */
function policyAppliesTo(raw, serviceType) {
  if (!Array.isArray(raw) || raw.length === 0) {
    return serviceType === "accommodation";
  }
  return raw.map((item) => String(item)).includes(serviceType);
}

/**
 * @param {Object} policy
 * @param {string} serviceType
 * @return {{required: boolean, version: number, title: string}}
 */
function summarizePolicyForService(policy, serviceType) {
  if (!policy) {
    return {required: false, version: 0, title: ""};
  }
  const version = toInt(policy.version, 0);
  const sections = policy.sections || {};
  const enabled = policy.enabled || {};
  const sectionServices = policy.sectionApplicableServices || {};
  let hasContent = false;
  Object.keys(sections).forEach((key) => {
    if (enabled[key] === false) {
      return;
    }
    if (!policyAppliesTo(sectionServices[key], serviceType)) {
      return;
    }
    if (String(sections[key] || "").trim()) {
      hasContent = true;
    }
  });
  const customs = []
      .concat(policy.customPoliciesPage1 || [])
      .concat(policy.customPoliciesPage2 || []);
  customs.forEach((item) => {
    if (typeof item === "string") {
      if (serviceType === "accommodation" && item.trim()) {
        hasContent = true;
      }
      return;
    }
    if (item && policyAppliesTo(item.applicableServices, serviceType) &&
        String(item.text || "").trim()) {
      hasContent = true;
    }
  });
  return {
    required: hasContent,
    version,
    title: serviceType === "daycare" ? "臨托須知" : "入住須知",
  };
}

/**
 * @param {Object} shopData
 * @return {boolean}
 */
function shopHasCatHotel(shopData) {
  const modules = Array.isArray(shopData.enabledModules) ?
    shopData.enabledModules.map((item) => String(item)) : [];
  return modules.includes("cat_hotel");
}

/**
 * 臨托唯一啟用來源：shops/{shopId}.daycareEnabled。
 * 舊資料尚未寫入該欄時，才讀取 daycare_settings.enabled。
 * @param {Object} shopData
 * @param {Object} settings
 * @return {boolean}
 */
function isDaycareEnabled(shopData, settings) {
  const shop = shopData || {};
  return parseBool(shop.daycareEnabled) || parseBool(settings && settings.enabled);
}

/** @deprecated 請改用 isDaycareEnabled
 * @param {Object} shopData
 * @return {boolean}
 */
function shopHasDaycareModule(shopData) {
  return shopHasCatHotel(shopData);
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {string} shopId
 * @return {Promise<string>}
 */
async function generateBookingCode(transaction, shopId) {
  const counterRef = admin.firestore()
      .collection("booking_counters")
      .doc(shopId);
  const snapshot = await transaction.get(counterRef);
  const current = snapshot.exists ? toInt(snapshot.data().current, 0) : 0;
  const next = current + 1;
  transaction.set(counterRef, {
    current: next,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return `${shopId}-B${String(next).padStart(6, "0")}`;
}

/**
 * @param {Object} params
 * @return {Promise<void>}
 */
async function writeActionLog(params) {
  await admin.firestore().collection("action_logs").add({
    shopId: params.shopId || "",
    targetType: params.targetType || "booking",
    targetId: params.targetId || "",
    action: params.action || "",
    type: params.action || "",
    bookingId: params.targetId || "",
    bookingKind: BOOKING_KIND_DAYCARE,
    operatorUid: params.operatorUid || "",
    operatorRole: params.operatorRole || "",
    payload: params.payload || {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * @param {Date} start
 * @param {Date} end
 * @param {Date} otherStart
 * @param {Date} otherEnd
 * @return {boolean}
 */
function overlaps(start, end, otherStart, otherEnd) {
  return start.getTime() < otherEnd.getTime() &&
    otherStart.getTime() < end.getTime();
}

const ADDON_GROUP_KEYS = [
  "timeOptions",
  "valueServices",
  "customServices",
  "dailyTimedServices",
];

/**
 * @param {Object|null} data
 * @return {Array<Object>}
 */
function flattenAddonCatalog(data) {
  if (!data) {
    return [];
  }
  if (Object.prototype.hasOwnProperty.call(data, "enabled") &&
      !parseBool(data.enabled)) {
    return [];
  }
  const out = [];
  for (const key of ADDON_GROUP_KEYS) {
    const list = Array.isArray(data[key]) ? data[key] : [];
    for (const item of list) {
      const id = normalizeString(item && item.id);
      if (!id) {
        continue;
      }
      if (item && typeof item === "object" &&
          Object.prototype.hasOwnProperty.call(item, "enabled") &&
          !parseBool(item.enabled)) {
        continue;
      }
      out.push({
        id,
        name: normalizeString((item && (item.name || item.label)) || ""),
        type: normalizeString(item && item.type) || key,
        price: toInt(item && item.price, 0),
        daycareChargeMode: normalizeString(item && item.daycareChargeMode) ||
          "per_order",
        count: 1,
        slotCount: toInt(item && item.slotCount, 1),
      });
    }
  }
  return out;
}

/**
 * 一晚住宿原價上限：房型價＋多寵物加價＋特殊日期加價，不含優惠券／活動／點數。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} roomTypeId
 * @param {number} petCount
 * @param {Date} stayDate
 * @return {Promise<number>}
 */
async function overnightCapForRoom(
    firestore, shopId, roomTypeId, petCount, stayDate,
) {
  const id = normalizeString(roomTypeId);
  if (!id) {
    return 0;
  }
  const roomTypeSnap = await firestore.collection("shops").doc(shopId)
      .collection("room_types").doc(id).get();
  const roomType = roomTypeSnap.data() || {};
  const extraPets = Math.max(0, toInt(petCount, 1) - 1);
  let amount = toInt(roomType.price, 0) +
    extraPets * toInt(roomType.extraPrice, 0);
  const surSnap = await firestore.collection("shops").doc(shopId)
      .collection("special_date_surcharges")
      .where("enabled", "==", true).get();
  const key = serviceDateKey(stayDate);
  surSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const start = toDate(data.startDate);
    const end = toDate(data.endDate);
    if (!start || !end) {
      return;
    }
    const ids = Array.isArray(data.roomTypeIds) ?
      data.roomTypeIds.map((item) => normalizeString(item)) : [];
    if (ids.length > 0 && !ids.includes(id)) {
      return;
    }
    const startKey = serviceDateKey(start);
    const endKey = serviceDateKey(end);
    if (key >= startKey && key <= endKey) {
      amount += toInt(data.amountPerNight, 0);
    }
  });
  return amount;
}

module.exports = {
  ROOT_ADMIN_UID,
  BOOKING_KIND_ACCOMMODATION,
  BOOKING_KIND_DAYCARE,
  ACTIVE_STATUSES,
  normalizeString,
  toInt,
  parseBool,
  roundMoney,
  toDate,
  taiwanDate,
  serviceDateKey,
  minutesOf,
  weekdayTaiwan,
  overrideDocId,
  loadDateOverride,
  isDateOpen,
  resolveDailyMaxPets,
  resolveDayHours,
  resolveBookingKind,
  isRootAdmin,
  getShopMember,
  hasShopPermission,
  shopHasDaycareModule,
  shopHasCatHotel,
  isDaycareEnabled,
  policyAppliesTo,
  summarizePolicyForService,
  generateBookingCode,
  writeActionLog,
  overlaps,
  flattenAddonCatalog,
  overnightCapForRoom,
};
