// 檔案名稱：functions/daycare/daycare_points.js
// 功能說明：安親點數改走共用 booking_points；保留舊 export 給既有呼叫。

const {
  computeEarnPoints: computeUnified,
  capSpend,
  canSpend: canSpendChannel,
} = require("../points/booking_points");

function computeEarnPoints(setting, booking) {
  return computeUnified(setting, booking, {isAppMember: true});
}

function canSpend(setting) {
  return canSpendChannel(setting, "daycare");
}

function capSpendAmount(params) {
  const result = capSpend({
    requestedPoints: params.requested,
    balance: params.balance,
    payableAfterCoupon: params.payableAfterCoupon,
    setting: {
      pointsPerNtd: 1,
      maximumPointsPerBooking: params.maxPerBooking,
    },
  });
  let amount = result.pointAmount;
  const maxPerBooking = params.maxPerBooking || 0;
  if (maxPerBooking > 0) {
    amount = Math.min(amount, maxPerBooking);
  }
  return Math.max(0, amount);
}

module.exports = {
  computeEarnPoints,
  capSpendAmount,
  canSpend,
};
