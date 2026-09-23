/* eslint-disable require-jsdoc */
// 檔案名稱：functions/points/booking_points.js
// 功能說明：住宿／安親點數折抵與發點純計算；不信任前端金額。

const {
  toInt,
  remainingDue,
  refundDue,
  netCollected,
  isDaycareBooking,
} = require("../bookings/booking_settlement_math");

function pointsBalance(data) {
  const raw = data || {};
  if (raw.currentPoints != null) {
    return Math.max(0, toInt(raw.currentPoints, 0));
  }
  return Math.max(0, toInt(raw.points, 0));
}

function pointsPerNtd(setting) {
  const n = toInt(setting && setting.pointsPerNtd, 0);
  return n > 0 ? n : 1;
}

function ntdFromPoints(points, setting) {
  const n = pointsPerNtd(setting);
  return Math.floor(Math.max(0, toInt(points, 0)) / n);
}

function pointsFromNtd(ntd, setting) {
  return Math.max(0, toInt(ntd, 0)) * pointsPerNtd(setting);
}

function spendMasterEnabled(setting) {
  if (!setting || setting.enabled !== true) {
    return false;
  }
  if (setting.spendEnabled === true) {
    return true;
  }
  return setting.daycareSpendEnabled === true;
}

function canSpend(setting, channel) {
  if (!spendMasterEnabled(setting)) {
    return false;
  }
  if (channel === "stay") {
    return setting.staySpendEnabled === true;
  }
  if (channel === "daycare") {
    return setting.daycareSpendEnabled === true;
  }
  if (channel === "store") {
    return setting.storeSpendEnabled === true;
  }
  return false;
}

/**
 * 先優惠券後點數；點數不可讓應付變負。回傳折抵金額（NT$）與實際扣點。
 * @param {Object} params
 * @return {{pointAmount: number, pointsUsed: number}}
 */
function capSpend(params) {
  const setting = params.setting || {};
  const payable = Math.max(0, toInt(params.payableAfterCoupon, 0));
  const balance = Math.max(0, toInt(params.balance, 0));
  const requested = Math.max(0, toInt(params.requestedPoints, 0));
  const ntd = Math.min(
      ntdFromPoints(requested, setting),
      ntdFromPoints(balance, setting),
      payable,
  );
  return {
    pointAmount: ntd,
    pointsUsed: pointsFromNtd(ntd, setting),
  };
}

function isCancelled(booking) {
  const status = String((booking || {}).status || "").trim();
  return status === "cancelled" || status === "no_show";
}

function stayServiceEnded(booking) {
  const data = booking || {};
  const status = String(data.status || "").trim();
  return Boolean(
      data.checkOutAt ||
      data.checkedOutAt ||
      status === "checked_out" ||
      status === "completed" ||
      data.stayRoomReleased === true,
  );
}

function daycareServiceComplete(booking) {
  const data = booking || {};
  const status = String(data.status || "").trim();
  return status === "completed" ||
    data.settlementConfirmed === true ||
    data.settledAt != null;
}

function hasOpenBalance(booking) {
  return remainingDue(booking) > 0 || refundDue(booking) > 0;
}

/**
 * 完成且無待補／待退才可發點。
 * @param {Object} booking
 * @return {boolean}
 */
function canIssueEarn(booking) {
  if (!booking || isCancelled(booking)) {
    return false;
  }
  if (hasOpenBalance(booking)) {
    return false;
  }
  if (isDaycareBooking(booking)) {
    return daycareServiceComplete(booking);
  }
  return stayServiceEnded(booking);
}

function isWalkInMember(member, isAuthUser) {
  if (isAuthUser !== true) {
    return true;
  }
  const data = member || {};
  if (data.isTempAdminMember === true) {
    return true;
  }
  return false;
}

function capEarn(points, maxPoints) {
  let next = Math.max(0, toInt(points, 0));
  const max = toInt(maxPoints, 0);
  if (max > 0 && next > max) {
    next = max;
  }
  return next;
}

/**
 * 依實收淨額（或晚數）計算系統發點。折抵點數不是現金，不計入。
 * @param {Object} setting
 * @param {Object} booking
 * @param {Object} extras
 * @return {number}
 */
function computeEarnPoints(setting, booking, extras) {
  const opts = extras || {};
  if (!setting || setting.enabled !== true) {
    return 0;
  }
  if (opts.isAppMember !== true) {
    return 0;
  }
  const data = booking || {};
  const daycare = isDaycareBooking(data);
  if (daycare && setting.daycareEarnEnabled !== true) {
    return 0;
  }
  const preview = opts.preview === true;
  const net = Math.max(
      0,
      preview ?
        netCollected(data) + remainingDue(data) - refundDue(data) :
        netCollected(data),
  );
  if (daycare) {
    const min = toInt(setting.daycareMinimumOrderAmount, 0);
    if (min > 0 && net < min) {
      return 0;
    }
    const per = toInt(setting.daycareAmountPerPoint, 0) ||
      toInt(setting.amountPerPoint, 0);
    const points = per > 0 ? Math.floor(net / per) : 0;
    return capEarn(points, setting.daycareMaximumPointsPerBooking);
  }
  const minStay = toInt(setting.minimumOrderAmount, 0);
  if (minStay > 0 && net < minStay) {
    return 0;
  }
  let points = 0;
  if (String(setting.calculationType || "") === "night") {
    const nights = toInt(data.nights, 0);
    const perNight = toInt(setting.pointsPerNight, 0);
    points = nights > 0 && perNight > 0 ? nights * perNight : 0;
  } else {
    const per = toInt(setting.amountPerPoint, 0);
    points = per > 0 ? Math.floor(net / per) : 0;
  }
  return capEarn(points, setting.maximumPointsPerBooking);
}

/**
 * 店員調整後仍以系統計算為上限，避免退款後超發；未調整則用系統值。
 * @param {Object} params
 * @return {number}
 */
function resolveFinalEarn(params) {
  const systemPoints = Math.max(0, toInt(params.systemPoints, 0));
  if (params.eligible !== true) {
    return 0;
  }
  if (params.adjusted !== true) {
    return systemPoints;
  }
  return Math.min(Math.max(0, toInt(params.overridePoints, 0)), systemPoints);
}

function earnStatusOf(params) {
  if (params.isAppMember !== true) {
    return "not_eligible";
  }
  if (params.cancelled === true) {
    return params.issued > 0 || params.spentReturned === true ?
      "adjusted_after_cancel" : "not_eligible";
  }
  if (params.eligible !== true) {
    return "pending";
  }
  const issued = toInt(params.issued, 0);
  if (issued > 0) {
    return params.adjusted === true ? "issued_adjusted" : "issued";
  }
  const expected = toInt(params.expected, 0);
  if (expected > 0) {
    return "expected";
  }
  return "not_eligible";
}

function channelOfBooking(booking) {
  return isDaycareBooking(booking) ? "daycare" : "stay";
}

module.exports = {
  pointsBalance,
  pointsPerNtd,
  ntdFromPoints,
  pointsFromNtd,
  canSpend,
  capSpend,
  netCollected,
  canIssueEarn,
  hasOpenBalance,
  isWalkInMember,
  computeEarnPoints,
  resolveFinalEarn,
  earnStatusOf,
  channelOfBooking,
  toInt,
};
