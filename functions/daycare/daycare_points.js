// 檔案名稱：functions/daycare/daycare_points.js
// 功能說明：安親點數發放與折抵計算（後端重算，不信任前端）

const {toInt} = require("./daycare_utils");

/**
 * @param {Object} setting
 * @param {Object} booking
 * @return {number}
 */
function computeEarnPoints(setting, booking) {
  if (!setting || setting.enabled !== true ||
      setting.daycareEarnEnabled !== true) {
    return 0;
  }
  if (setting.issueAfterCompleted === false) {
    return 0;
  }
  let amount = toInt(booking.finalSettlementAmount, 0) ||
    toInt(booking.paidAmount, 0) || toInt(booking.totalPrice, 0);
  if (setting.daycareIncludeAddons === false) {
    const addons = Array.isArray(booking.addons) ? booking.addons : [];
    const addonSum = addons.reduce((sum, item) => {
      const raw = item && item.amount != null ? item.amount :
        item && item.price;
      return sum + toInt(raw, 0);
    }, 0);
    amount -= addonSum;
  }
  if (setting.daycareIncludeSurcharge !== true &&
      setting.daycareIncludeSurcharge !== false) {
    // 舊資料缺欄：預設包含特殊日期加價
  }
  if (setting.daycareIncludeSurcharge === false) {
    amount -= toInt(booking.specialDateSurchargeAmount, 0);
  }
  if (setting.daycareIncludeOvertime !== true) {
    amount -= toInt(booking.overtimeAmount, 0);
  }
  amount = Math.max(0, amount);
  const minAmount = toInt(setting.daycareMinimumOrderAmount, 0);
  if (minAmount > 0 && amount < minAmount) {
    return 0;
  }
  let points = 0;
  if (setting.daycareCalculationType === "fixed") {
    points = toInt(setting.daycarePointsPerOrder, 0);
  } else {
    const per = toInt(setting.daycareAmountPerPoint, 0);
    points = per > 0 ? Math.floor(amount / per) : 0;
  }
  const maxPoints = toInt(setting.daycareMaximumPointsPerBooking, 0);
  if (maxPoints > 0 && points > maxPoints) {
    points = maxPoints;
  }
  return Math.max(0, points);
}

/**
 * 1 點折抵 1 元；不可超過餘額、應付與單筆上限。
 * @param {Object} params
 * @return {number}
 */
function capSpendAmount(params) {
  const requested = Math.max(0, toInt(params.requested, 0));
  const balance = Math.max(0, toInt(params.balance, 0));
  const payable = Math.max(0, toInt(params.payableAfterCoupon, 0));
  const maxPerBooking = toInt(params.maxPerBooking, 0);
  let amount = Math.min(requested, balance, payable);
  if (maxPerBooking > 0) {
    amount = Math.min(amount, maxPerBooking);
  }
  return Math.max(0, amount);
}

/**
 * @param {Object} setting
 * @return {boolean}
 */
function canSpend(setting) {
  return setting && setting.enabled === true &&
    setting.daycareSpendEnabled === true;
}

module.exports = {
  computeEarnPoints,
  capSpendAmount,
  canSpend,
};
