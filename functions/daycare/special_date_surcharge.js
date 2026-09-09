// 檔案名稱：functions/daycare/special_date_surcharge.js
// 功能說明：特殊日期加價：舊資料僅住宿；安親命中日期加一次

const {
  normalizeString,
  toInt,
  serviceDateKey,
  toDate,
} = require("./daycare_utils");

/**
 * @param {Object} data
 * @return {Array<string>}
 */
function parseApplicableServices(data) {
  const raw = data && data.applicableServices;
  if (!Array.isArray(raw)) {
    return ["accommodation"];
  }
  const values = [...new Set(raw.map((item) => normalizeString(item))
      .filter((item) => item === "accommodation" || item === "daycare"))];
  return values.length > 0 ? values : ["accommodation"];
}

/**
 * @param {Object} data
 * @param {string} dateKey
 * @return {boolean}
 */
function matchesDate(data, dateKey) {
  const start = toDate(data.startDate);
  const end = toDate(data.endDate);
  if (!start || !end) {
    return false;
  }
  const startKey = serviceDateKey(start);
  const endKey = serviceDateKey(end);
  return dateKey >= startKey && dateKey <= endKey;
}

/**
 * @param {Array<Object>} docs
 * @param {Object} params
 * @return {{total: number, details: Array<Object>,
 *   allowCoupon: boolean, allowCampaign: boolean}}
 */
function calculateDaycareSurcharge(docs, params) {
  const dateKey = params.serviceDate;
  const isRoomBased = params.isRoomBased === true;
  const roomTypeId = normalizeString(params.roomTypeId);
  let total = 0;
  const details = [];
  let allowCoupon = true;
  let allowCampaign = true;
  for (const data of docs) {
    if (!data || data.enabled !== true) {
      continue;
    }
    const services = parseApplicableServices(data);
    if (!services.includes("daycare")) {
      continue;
    }
    if (!matchesDate(data, dateKey)) {
      continue;
    }
    const ids = Array.isArray(data.roomTypeIds) ?
      data.roomTypeIds.map((item) => normalizeString(item))
          .filter(Boolean) : [];
    if (ids.length > 0) {
      if (!isRoomBased || !ids.includes(roomTypeId)) {
        continue;
      }
    }
    const amount = toInt(data.amountPerNight, 0);
    total += amount;
    details.push({
      id: data.id || "",
      name: normalizeString(data.name),
      amount,
      allowCoupon: data.allowCoupon !== false,
      allowCampaignDiscount: data.allowCampaignDiscount !== false,
    });
    if (data.allowCoupon === false) {
      allowCoupon = false;
    }
    if (data.allowCampaignDiscount === false) {
      allowCampaign = false;
    }
  }
  return {total, details, allowCoupon, allowCampaign};
}

/**
 * 住宿每晚加價：舊資料與未標安親者不套用安親。
 * @param {Object} data
 * @return {boolean}
 */
function appliesToAccommodation(data) {
  return parseApplicableServices(data).includes("accommodation");
}

module.exports = {
  parseApplicableServices,
  calculateDaycareSurcharge,
  appliesToAccommodation,
};
