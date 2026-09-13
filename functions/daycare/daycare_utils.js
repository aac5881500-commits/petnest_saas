// 檔案名稱：functions/daycare/daycare_utils.js
// 功能說明：臨托共用工具：登入、店家、權限、金額、時間、操作紀錄

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

/**
 * 將輸入值安全轉換為整數。
 * @param {*} value 原始值
 * @param {number} fallback 轉換失敗時的預設值
 * @return {number} 整數結果
 */
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
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?$/.test(
        trimmed,
    )) {
      return new Date(`${trimmed}+08:00`);
    }
    const parsed = new Date(trimmed);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
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
  if (!override) {
    return true;
  }

  if (Object.prototype.hasOwnProperty.call(override, "isOpen")) {
    return override.isOpen === true;
  }

  if (override.closed === true || override.isClosed === true) {
    return false;
  }

  return true;
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
  if (member) {
    if (normalizeString(member.role) === "owner") {
      return true;
    }
    const permissions = member.permissions && typeof member.permissions ===
      "object" ? member.permissions : {};
    if (permissions[permissionKey] === true) {
      return true;
    }
  }
  const shopSnap = await admin.firestore().collection("shops").doc(shopId).get();
  return shopSnap.exists &&
    normalizeString((shopSnap.data() || {}).ownerUid) === uid;
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
 * @param {*} raw
 * @return {number}
 */
function parsePolicyVersion(raw) {
  if (raw == null || raw === "") {
    return 0;
  }
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return Math.round(raw);
  }
  const match = String(raw).match(/(\d+)/);
  if (!match) {
    return 0;
  }
  const parsed = Number.parseInt(match[1], 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * @param {Object|null} acc
 * @param {string} serviceType
 * @return {number}
 */
function acceptedServiceVersion(acc, serviceType) {
  const data = acc || {};
  const byService = data.acceptedVersions &&
    typeof data.acceptedVersions === "object" ?
      data.acceptedVersions : {};
  const mapped = parsePolicyVersion(byService[serviceType]);
  if (mapped > 0) {
    return mapped;
  }
  if (serviceType === "accommodation") {
    return parsePolicyVersion(data.acceptedVersion);
  }
  if (normalizeString(data.lastAcceptedServiceType) === serviceType) {
    return parsePolicyVersion(data.acceptedVersion);
  }
  return 0;
}

/**
 * @param {Object|null} data
 * @return {number}
 */
function submittedServicePolicyVersion(data) {
  const payload = data || {};
  const fromPolicy = parsePolicyVersion(payload.policyVersion);
  if (fromPolicy > 0) {
    return fromPolicy;
  }
  return parsePolicyVersion(payload.termsVersion);
}

/**
 * @param {Object} policy
 * @param {string} serviceType
 * @return {number}
 */
function servicePolicyVersion(policy, serviceType) {
  if (!policy) {
    return 0;
  }
  const serviceVersions = policy.serviceVersions &&
    typeof policy.serviceVersions === "object" ?
      policy.serviceVersions : {};
  const mapped = parsePolicyVersion(serviceVersions[serviceType]);
  if (mapped > 0) {
    return mapped;
  }
  if (serviceType === "daycare") {
    const daycareVersion = parsePolicyVersion(policy.daycareVersion);
    if (daycareVersion > 0) {
      return daycareVersion;
    }
    const texts = policy.sectionTextsByService &&
      typeof policy.sectionTextsByService === "object" ?
        policy.sectionTextsByService : {};
    const daycareTexts = texts.daycare && typeof texts.daycare === "object" ?
      texts.daycare : {};
    if (Object.keys(daycareTexts).length > 0) {
      return 1;
    }
    return parsePolicyVersion(policy.version);
  }
  return parsePolicyVersion(policy.accommodationVersion) ||
    parsePolicyVersion(policy.version);
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
  const version = servicePolicyVersion(policy, serviceType);
  const textsByService = policy.sectionTextsByService &&
    typeof policy.sectionTextsByService === "object" ?
      policy.sectionTextsByService : {};
  const serviceTexts = textsByService[serviceType] &&
    typeof textsByService[serviceType] === "object" ?
      textsByService[serviceType] : null;
  let hasContent = false;
  if (serviceTexts && Object.keys(serviceTexts).length > 0) {
    const enabledByService = policy.enabledByService &&
      typeof policy.enabledByService === "object" ?
        policy.enabledByService : {};
    const serviceEnabled = enabledByService[serviceType] &&
      typeof enabledByService[serviceType] === "object" ?
        enabledByService[serviceType] : {};
    Object.keys(serviceTexts).forEach((key) => {
      if (serviceEnabled[key] === false) {
        return;
      }
      if (String(serviceTexts[key] || "").trim()) {
        hasContent = true;
      }
    });
    const customByService = policy.customPoliciesByService &&
      typeof policy.customPoliciesByService === "object" ?
        policy.customPoliciesByService : {};
    const serviceCustom = customByService[serviceType] &&
      typeof customByService[serviceType] === "object" ?
        customByService[serviceType] : {};
    []
        .concat(serviceCustom.page1 || [])
        .concat(serviceCustom.page2 || [])
        .forEach((item) => {
          if (typeof item === "string" && item.trim()) {
            hasContent = true;
            return;
          }
          if (item && String(item.text || item).trim()) {
            hasContent = true;
          }
        });
    return {
      required: hasContent,
      version,
      title: serviceType === "daycare" ? "安親須知" : "入住須知",
    };
  }
  const sections = policy.sections || {};
  const enabled = policy.enabled || {};
  const sectionServices = policy.sectionApplicableServices || {};
  hasContent = false;
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
    title: serviceType === "daycare" ? "安親須知" : "入住須知",
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
  if (Object.prototype.hasOwnProperty.call(shop, "daycareEnabled") &&
      shop.daycareEnabled !== null &&
      String(shop.daycareEnabled).trim() !== "") {
    return parseBool(shop.daycareEnabled);
  }
  return parseBool(settings && settings.enabled);
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
 * @return {Promise<{uid: string, email: string, displayName: string}>}
 */
async function resolveOperatorIdentity(params) {
  const uid = normalizeString(params.operatorUid);
  let email = normalizeString(params.operatorEmail);
  let displayName = normalizeString(params.operatorDisplayName);
  if (uid && (!email || !displayName)) {
    try {
      const user = await admin.auth().getUser(uid);
      if (!email) {
        email = normalizeString(user.email);
      }
      if (!displayName) {
        displayName = normalizeString(user.displayName);
      }
    } catch (_) {
      // 找不到 Auth 帳號時改讀 shop member，不把 UID 當顯示值。
    }
  }
  if (uid && !email && params.shopId) {
    try {
      const memberSnap = await admin.firestore()
          .collection("shops").doc(params.shopId)
          .collection("members").doc(uid).get();
      if (memberSnap.exists) {
        const member = memberSnap.data() || {};
        if (!email) {
          email = normalizeString(member.email);
        }
        if (!displayName) {
          displayName = normalizeString(member.name || member.displayName);
        }
      }
    } catch (_) {
      // 找不到店員資料時仍寫入 UID 供內部追蹤，畫面不顯示 UID。
    }
  }
  return {uid, email, displayName};
}

/**
 * @param {Object} params
 * @param {{uid: string, email: string, displayName: string}} identity
 * @return {Object}
 */
function actionLogFields(params, identity) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  return {
    shopId: params.shopId || "",
    targetType: params.targetType || "booking",
    targetId: params.targetId || "",
    action: params.action || "",
    type: params.type || params.action || "",
    bookingId: params.bookingId || params.targetId || "",
    bookingKind: params.bookingKind || BOOKING_KIND_DAYCARE,
    operatorUid: identity.uid || "",
    operatorEmail: identity.email || "",
    operatorDisplayName: identity.displayName || "",
    operatorRole: params.operatorRole || "",
    operatedAt: now,
    payload: params.payload || {},
    createdAt: now,
  };
}

/**
 * @param {Object} params
 * @return {Promise<void>}
 */
async function writeActionLog(params) {
  const identity = await resolveOperatorIdentity(params);
  await admin.firestore().collection("action_logs").add(
      actionLogFields(params, identity),
  );
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @param {{uid: string, email: string, displayName: string}=} identity
 * @return {void}
 */
function writeActionLogInTransaction(transaction, params, identity) {
  const ref = admin.firestore().collection("action_logs").doc();
  transaction.set(ref, actionLogFields(params, identity || {
    uid: normalizeString(params.operatorUid),
    email: normalizeString(params.operatorEmail),
    displayName: normalizeString(params.operatorDisplayName),
  }));
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
    const applicable = Array.isArray(data.applicableServices) ?
      data.applicableServices.map((item) => normalizeString(item)) : [];
    if (applicable.length > 0 && !applicable.includes("accommodation")) {
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
  parsePolicyVersion,
  acceptedServiceVersion,
  submittedServicePolicyVersion,
  servicePolicyVersion,
  summarizePolicyForService,
  generateBookingCode,
  resolveOperatorIdentity,
  writeActionLog,
  writeActionLogInTransaction,
  overlaps,
  ADDON_GROUP_KEYS,
  flattenAddonCatalog,
  overnightCapForRoom,
};
