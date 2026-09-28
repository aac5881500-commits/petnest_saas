/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/daily_care_entitlement.js
// 功能說明：後端重算照護權益與加購金額；每日計費依服務日期。

const PLATFORM_MAX_PHOTOS = 6;
const PHOTOS_PER_SESSION = 3;
const MAX_SESSIONS = 3;
const PHOTO_RULE_V2 = 2;
const MODE_FIXED = "included_fixed";
const MODE_BY_OFFER = "included_by_offer";
const MODE_PAID = "paid_addon";
const CHARGE_PER_DAY = "per_service_day";
const CHARGE_ONCE = "once_per_stay";
const CHARGE_PER_VISIT = "per_visit";
const CHARGE_PER_NIGHT = "per_night";
const ADDON_TYPE = "daily_care";
const STAY_PAID_ID = "stay_paid";
const DAYCARE_PAID_ID = "daycare_paid";
const PHOTO_NOTE =
  "每場回報可附最多 3 張照片；同場多隻寵物共用，不依寵物數加乘。服務結束後保留 24 小時，請及時下載。";

function toInt(value, fallback) {
  const fallbackValue = fallback == null ? 0 : fallback;
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  const parsed = Number.parseInt(String(value == null ? "" : value).trim(), 10);
  return Number.isFinite(parsed) ? parsed : fallbackValue;
}

function dateKeyFromParts(parts) {
  const month = String(parts.month).padStart(2, "0");
  const day = String(parts.day).padStart(2, "0");
  return parts.year + "/" + month + "/" + day;
}

function compareParts(left, right) {
  if (left.year !== right.year) {
    return left.year - right.year;
  }
  if (left.month !== right.month) {
    return left.month - right.month;
  }
  return left.day - right.day;
}

function addCalendarDays(parts, days) {
  const utc = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return {
    year: utc.getUTCFullYear(),
    month: utc.getUTCMonth() + 1,
    day: utc.getUTCDate(),
  };
}

function taipeiParts(date) {
  const formatted = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
  const matched = String(formatted).match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!matched) {
    return null;
  }
  return {
    year: Number(matched[1]),
    month: Number(matched[2]),
    day: Number(matched[3]),
  };
}

/**
 * 純日期字串照字面處理。Timestamp、Date、帶時區的 ISO 轉成 Asia/Taipei 年月日。
 * @param {*} value
 * @return {?{year: number, month: number, day: number}}
 */
function parseCalendarInput(value) {
  if (value == null || value === "") {
    return null;
  }
  if (typeof value === "string") {
    const literal = value.trim().match(/^(\d{4})[-/](\d{2})[-/](\d{2})$/);
    if (literal) {
      const year = Number(literal[1]);
      const month = Number(literal[2]);
      const day = Number(literal[3]);
      if (month < 1 || month > 12 || day < 1 || day > 31) {
        return null;
      }
      return {year, month, day};
    }
  }
  let date = null;
  if (value instanceof Date) {
    date = value;
  } else if (value && typeof value.toDate === "function") {
    const converted = value.toDate();
    if (converted instanceof Date && !Number.isNaN(converted.getTime())) {
      date = converted;
    }
  } else if (value && typeof value === "object") {
    const seconds = value.seconds != null ? value.seconds : value._seconds;
    if (typeof seconds === "number" && Number.isFinite(seconds)) {
      date = new Date(seconds * 1000);
    }
  } else if (typeof value === "number" && Number.isFinite(value)) {
    date = new Date(value);
  }
  if (!date && (typeof value === "string" || typeof value === "number")) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      date = parsed;
    }
  }
  if (!date || Number.isNaN(date.getTime())) {
    return null;
  }
  return taipeiParts(date);
}

function stayServiceDates(startRaw, endRaw) {
  const start = parseCalendarInput(startRaw);
  const end = parseCalendarInput(endRaw);
  if (!start || !end || compareParts(end, start) <= 0) {
    return [];
  }
  const out = [];
  let cursor = start;
  let guard = 0;
  while (compareParts(cursor, end) < 0 && guard < 400) {
    out.push(dateKeyFromParts(cursor));
    cursor = addCalendarDays(cursor, 1);
    guard += 1;
  }
  return out;
}

function daycareServiceDates(startRaw) {
  const start = parseCalendarInput(startRaw);
  return start ? [dateKeyFromParts(start)] : [];
}

function serviceDates(startRaw, endRaw) {
  return stayServiceDates(startRaw, endRaw);
}

function normalizeMode(raw) {
  const text = String(raw || "").trim();
  if (text === MODE_BY_OFFER || text === MODE_PAID) {
    return text;
  }
  return MODE_FIXED;
}

function normalizeCharge(raw, daycare) {
  const text = String(raw || "").trim();
  if (text === CHARGE_ONCE) {
    return CHARGE_ONCE;
  }
  if (text === CHARGE_PER_VISIT) {
    return CHARGE_PER_VISIT;
  }
  if (text === CHARGE_PER_NIGHT) {
    return daycare ? CHARGE_PER_VISIT : CHARGE_PER_DAY;
  }
  return daycare ? CHARGE_PER_VISIT : CHARGE_PER_DAY;
}

function clampReports(value, fallback) {
  const n = toInt(value, fallback == null ? 1 : fallback);
  if (n < 1) {
    return 1;
  }
  if (n > MAX_SESSIONS) {
    return MAX_SESSIONS;
  }
  return n;
}

function padLabels(labels, count) {
  const list = Array.isArray(labels) ? labels : [];
  const out = [];
  for (let i = 0; i < count; i++) {
    const label = String(list[i] || "").trim();
    out.push(label || ("第 " + (i + 1) + " 次照護"));
  }
  return out;
}

function readPaidPlan(raw) {
  const map = raw && typeof raw === "object" ? raw : {};
  return {
    name: String(map.name || "寵物寫真與照護回報").trim() ||
      "寵物寫真與照護回報",
    description: String(map.description || ""),
    chargeUnit: String(map.chargeUnit || CHARGE_PER_DAY),
    price: Math.max(0, toInt(map.price, 0)),
    reports: clampReports(map.reports, 1),
    sessionLabels: Array.isArray(map.sessionLabels) ? map.sessionLabels : [],
  };
}

function requestedAddonId(requestedAddons) {
  const list = Array.isArray(requestedAddons) ? requestedAddons : [];
  for (let i = 0; i < list.length; i++) {
    const item = list[i] || {};
    const type = String(item.type || "").trim();
    if (type === ADDON_TYPE || type === "dailyCare") {
      return String(item.id || item.addonId || "").trim();
    }
  }
  return String(
      (requestedAddons && requestedAddons.dailyCareAddonId) || "",
  ).trim();
}

function resolveDailyCareEntitlement(params) {
  const setting = params.setting || {};
  const isDaycare = params.isDaycare === true;
  const shopDaycareOn = params.shopDaycareOn !== false;
  const offerId = String(params.offerId || "").trim();
  const offerName = String(params.offerName || "").trim();
  const dates = isDaycare ?
    daycareServiceDates(params.startDate) :
    stayServiceDates(params.startDate, params.endDate);
  const featureOn = isDaycare ?
    setting.daycareEnabled === true && shopDaycareOn :
    setting.enabled === true;
  const mode = normalizeMode(
      isDaycare ? setting.daycareReportMode : setting.stayReportMode,
  );
  const requested = String(params.addonId || "").trim() ||
    requestedAddonId(params.requestedAddons);
  const purchase = mode === MODE_PAID &&
    explicitPurchase(requested, isDaycare);
  if (!featureOn) {
    return {
      entitlement: {
        enabled: false,
        service: isDaycare ? "daycare" : "accommodation",
        mode,
        finalReports: 0,
        finalPhotos: 0,
        photoRuleVersion: PHOTO_RULE_V2,
        photosPerSession: PHOTOS_PER_SESSION,
        serviceDates: dates,
        includeCheckInDay: true,
        includeCheckOutDay: false,
      },
      addonLine: null,
      amount: 0,
    };
  }
  let reports = 0;
  let labels = [];
  let addonId = "";
  let addonName = "";
  let addonDescription = "";
  let chargeUnit = isDaycare ? CHARGE_PER_VISIT : CHARGE_PER_DAY;
  let unitPrice = 0;
  let quantity = 0;
  let amount = 0;
  if (mode === MODE_PAID) {
    if (purchase) {
      const plan = readPaidPlan(isDaycare ?
        setting.daycarePaidPlan : setting.stayPaidPlan);
      reports = plan.reports;
      labels = padLabels(plan.sessionLabels, reports);
      addonId = isDaycare ? DAYCARE_PAID_ID : STAY_PAID_ID;
      addonName = plan.name;
      addonDescription = plan.description;
      chargeUnit = isDaycare ? CHARGE_PER_VISIT :
        normalizeCharge(plan.chargeUnit, false);
      unitPrice = plan.price;
      if (isDaycare) {
        quantity = 1;
      } else if (chargeUnit === CHARGE_ONCE) {
        quantity = 1;
      } else {
        quantity = dates.length > 0 ? dates.length :
          Math.max(1, toInt(params.nights, 1));
      }
      amount = unitPrice * quantity;
    }
  } else if (mode === MODE_BY_OFFER) {
    if (!offerId) {
      throw new Error("請先選擇房型或方案，才能確認照護回報場次。");
    }
    const quotas = isDaycare ? setting.daycareOfferQuotas :
      setting.stayOfferQuotas;
    const row = quotas && quotas[offerId];
    if (!row || row.configured === false || toInt(row.reports, 0) < 1) {
      throw new Error("此房型／方案尚未設定照護回報場次，請先完成回報規則。");
    }
    reports = clampReports(row.reports, 1);
    labels = padLabels(row.sessionLabels, reports);
  } else {
    reports = isDaycare ?
      clampReports(setting.daycareSessionCount, 1) :
      clampReports(setting.sessionCount, 2);
    labels = padLabels(isDaycare ? setting.daycareSessionLabels :
      setting.sessionLabels, reports);
  }
  if (reports > MAX_SESSIONS) {
    throw new Error("回報場次不可超過 3 場。");
  }
  const entitlement = {
    enabled: reports > 0 || mode === MODE_PAID,
    service: isDaycare ? "daycare" : "accommodation",
    mode,
    baseReports: purchase && mode === MODE_PAID ? 0 : reports,
    basePhotos: 0,
    addonId,
    addonName,
    addonDescription,
    addonReports: purchase && mode === MODE_PAID ? reports : 0,
    addonPhotos: 0,
    unitPrice,
    chargeUnit,
    quantity: addonId ? quantity : 0,
    amount: addonId ? amount : 0,
    finalReports: reports,
    finalPhotos: reports * PHOTOS_PER_SESSION,
    sessionLabels: labels,
    offerId,
    offerName,
    careDateRule: isDaycare ?
      "每筆安親服務於服務當日提供回報。" :
      (chargeUnit === CHARGE_ONCE ?
        "整筆住宿收費一次；服務日期仍每天提供設定場次。" :
        "每日費用依實際包含的服務日期計算。") +
        "回報日期依住宿晚數計算：入住日包含，退房日不包含。",
    photoShareNote: PHOTO_NOTE,
    includeCheckInDay: true,
    includeCheckOutDay: false,
    serviceDates: dates,
    photosPerSession: PHOTOS_PER_SESSION,
    photoRuleVersion: PHOTO_RULE_V2,
  };
  const addonLine = addonId ? {
    id: addonId,
    name: addonName,
    type: ADDON_TYPE,
    price: unitPrice,
    count: quantity,
    amount,
    total: amount,
    chargeUnit,
    description: addonDescription,
    serviceDates: dates,
  } : null;
  return {entitlement, addonLine, amount};
}

function explicitPurchase(requested, isDaycare) {
  const id = String(requested || "").trim();
  if (!id) {
    return false;
  }
  if (id === "1" || id === "true") {
    return true;
  }
  return id === (isDaycare ? DAYCARE_PAID_ID : STAY_PAID_ID);
}

function isDailyCareAddon(item) {
  const type = String((item && item.type) || "").trim();
  const id = String((item && (item.id || item.addonId)) || "").trim();
  return type === ADDON_TYPE || type === "dailyCare" ||
    id === STAY_PAID_ID || id === DAYCARE_PAID_ID;
}

function filterNonDailyCareAddons(addons) {
  const list = Array.isArray(addons) ? addons : [];
  return list.filter((item) => !isDailyCareAddon(item));
}

function sumDailyCareAddonAmount(addons) {
  const list = Array.isArray(addons) ? addons : [];
  let sum = 0;
  for (let index = 0; index < list.length; index++) {
    const item = list[index] || {};
    if (!isDailyCareAddon(item)) {
      continue;
    }
    sum += Math.max(0, toInt(
        item.amount != null ? item.amount : item.total,
        0,
    ));
  }
  return sum;
}

/**
 * 新建訂單用後端報價取代客戶端照護加購金額與權益。
 * @param {Object} params
 * @return {Object}
 */
function applyAuthoritativeCare(params) {
  const quoted = params && params.quoted ? params.quoted : {};
  const nextAddons = filterNonDailyCareAddons(params && params.addons);
  const amount = Math.max(0, toInt(quoted.amount, 0));
  if (quoted.addonLine) {
    nextAddons.push(quoted.addonLine);
  }
  const clientCare = sumDailyCareAddonAmount(params && params.addons);
  const base = Math.max(
      0,
      toInt(params && params.payableAfterCoupon, 0) - clientCare,
  );
  return {
    addons: nextAddons,
    payableAfterCoupon: base + amount,
    entitlement: quoted.entitlement || {},
    amount,
  };
}

/**
 * 獨立時數／方案計費不可沿用依房型提供。回報未啟用時不擋舊資料。
 * @param {Object} setting
 * @param {boolean} roomBased
 * @return {boolean}
 */
function daycareByOfferBlocked(setting, roomBased) {
  if (roomBased === true) {
    return false;
  }
  const map = setting && typeof setting === "object" ? setting : {};
  if (map.daycareEnabled !== true) {
    return false;
  }
  return normalizeMode(map.daycareReportMode) === MODE_BY_OFFER;
}

function bookingIsDaycare(booking) {
  const kind = String(
      (booking && (booking.bookingKind || booking.serviceType)) || "",
  ).trim();
  if (kind === "daycare") {
    return true;
  }
  const service = booking && booking.dailyCareEntitlement &&
    booking.dailyCareEntitlement.service;
  return service === "daycare";
}

/**
 * 以訂單上的最終權益檢查日期、場次與店家／房間。
 * 沒有 dailyCareEntitlement 的舊訂單維持舊場次上限，仍檢查服務日期。
 * @param {Object} booking
 * @param {Object} params
 * @return {{ok: boolean, message: string}}
 */
function validateDailyCareSession(booking, params) {
  const shopId = String((params && params.shopId) || "").trim();
  const bookingShop = String((booking && booking.shopId) || "").trim();
  if (shopId && bookingShop && shopId !== bookingShop) {
    return {ok: false, message: "訂單不屬於這家店"};
  }
  const snap = booking && booking.dailyCareEntitlement;
  const hasSnapshot = !!snap && typeof snap === "object" && !Array.isArray(snap);
  const reports = hasSnapshot ?
    (snap.finalReports == null || snap.finalReports === "" ?
      MAX_SESSIONS : toInt(snap.finalReports, 0)) :
    MAX_SESSIONS;
  if (hasSnapshot &&
      snap.finalReports != null &&
      snap.finalReports !== "" &&
      toInt(snap.finalReports, 0) < 1) {
    return {ok: false, message: "此訂單沒有照護回報權益"};
  }
  const sessionIndex = toInt(params && params.sessionIndex, 0);
  const allowed = Math.min(MAX_SESSIONS, Math.max(0, reports));
  if (sessionIndex < 0 || sessionIndex >= allowed) {
    return {ok: false, message: "此場次不在訂單照護權益內"};
  }
  const daycare = bookingIsDaycare(booking);
  const legal = daycare ?
    daycareServiceDates(
        booking && (
          booking.scheduledStartAt || booking.serviceDate || booking.startDate
        ),
    ) :
    stayServiceDates(
        booking && (booking.startDate || booking.checkInAt || booking.checkInDate),
        booking && (booking.endDate || booking.checkOutAt || booking.checkOutDate),
    );
  const actual = parseCalendarInput(params && params.recordDate);
  const actualKey = actual ? dateKeyFromParts(actual) : "";
  if (!actualKey || legal.indexOf(actualKey) < 0) {
    return {ok: false, message: "這個日期不在可回報範圍"};
  }
  const roomId = String((params && params.roomId) || "").trim();
  const bookingRoom = String((booking && booking.roomId) || "").trim();
  if (bookingRoom && roomId && bookingRoom !== roomId) {
    return {ok: false, message: "房間與訂單不一致"};
  }
  return {ok: true, message: ""};
}

function entitlementLooksComplete(snap) {
  const map = snap && typeof snap === "object" ? snap : {};
  const reports = toInt(map.finalReports, 0);
  const labels = Array.isArray(map.sessionLabels) ? map.sessionLabels : [];
  return map.enabled === true && reports >= 1 && labels.length >= reports;
}

/**
 * 只留給舊資料相容。新建住宿／安親訂單不可呼叫，必須直接寫後端重算結果。
 * @param {Object} incoming
 * @param {Object} resolved
 * @return {Object}
 */
function pickEntitlementSnapshot(incoming, resolved) {
  const snap = incoming && typeof incoming === "object" ? incoming : {};
  const resolvedMap = resolved && typeof resolved === "object" ? resolved : {};
  const mode = normalizeMode(snap.mode || resolvedMap.mode);
  if (mode === MODE_PAID && toInt(snap.finalReports, 0) < 1) {
    return resolvedMap;
  }
  if (entitlementLooksComplete(snap)) {
    return snap;
  }
  return resolvedMap;
}

function photoRuleVersion(booking) {
  const snap = (booking && booking.dailyCareEntitlement) || {};
  return toInt(snap.photoRuleVersion, 1);
}

function entitlementSessionCount(booking) {
  const snap = booking && booking.dailyCareEntitlement;
  if (!snap || typeof snap !== "object" || Array.isArray(snap)) {
    return MAX_SESSIONS;
  }
  if (snap.finalReports == null || snap.finalReports === "") {
    if (snap.enabled === false) {
      return 0;
    }
    return MAX_SESSIONS;
  }
  const reports = toInt(snap.finalReports, 0);
  if (reports < 1) {
    return 0;
  }
  return Math.min(MAX_SESSIONS, reports);
}

module.exports = {
  PLATFORM_MAX_PHOTOS,
  PHOTOS_PER_SESSION,
  PHOTO_RULE_V2,
  ADDON_TYPE,
  STAY_PAID_ID,
  DAYCARE_PAID_ID,
  resolveDailyCareEntitlement,
  pickEntitlementSnapshot,
  entitlementLooksComplete,
  filterNonDailyCareAddons,
  applyAuthoritativeCare,
  daycareByOfferBlocked,
  validateDailyCareSession,
  requestedAddonId,
  serviceDates,
  photoRuleVersion,
  entitlementSessionCount,
};
