// 檔案名稱：functions/daycare/daycare_pricing.js
// 功能說明：臨托計價：與 Flutter DaycarePricingService 同一公式

const {roundMoney, toInt, normalizeString, parseBool} = require("./daycare_utils");

const PLAN_TYPES = {
  hourly: "hourly",
  halfHourly: "half_hourly",
  fixedHours: "fixed_hours",
  morning: "morning",
  afternoon: "afternoon",
  fullDay: "full_day",
  custom: "custom",
};

const SELECTABLE_PLAN_TYPES = [PLAN_TYPES.hourly, PLAN_TYPES.halfHourly];

const OVERTIME_MODES = {
  hourly: "hourly",
  halfHourly: "half_hourly",
  none: "none",
};

const DEPOSIT_TYPES = {
  none: "none",
  fixed: "fixed",
  percent: "percent",
  full: "full",
  staffDecide: "staff_decide",
};

const PRICING_MODES = {
  roomBased: "room_based",
  timeBased: "time_based",
};

const ROUNDING_MODES = {
  ceilHour: "ceil_hour",
  ceilHalfHour: "ceil_half_hour",
  prorated: "prorated",
};

const CAP_MODES = {
  overnightRate: "overnight_rate",
  fixedAmount: "fixed_amount",
  none: "none",
};

function isRoomBased(settingsOrBooking) {
  const mode = normalizeString(
      (settingsOrBooking && settingsOrBooking.pricingMode) || "",
  );
  return mode === PRICING_MODES.roomBased;
}

function extraTimeAmount(extraMinutes, unitMinutes, unitPrice, roundingMode) {
  if (extraMinutes <= 0 || unitPrice <= 0) {
    return 0;
  }
  const unit = (unitMinutes === 15 || unitMinutes === 30 ||
    unitMinutes === 60) ? unitMinutes : 60;
  const mode = normalizeString(roundingMode) || ROUNDING_MODES.ceilHour;
  if (mode === ROUNDING_MODES.prorated) {
    return roundMoney(extraMinutes / unit * unitPrice);
  }
  if (mode === ROUNDING_MODES.ceilHalfHour) {
    const pricePerHalf = unit === 30 ? unitPrice :
      roundMoney(unitPrice * 30 / unit);
    return Math.ceil(extraMinutes / 30) * pricePerHalf;
  }
  const pricePerHour = unit === 60 ? unitPrice :
    roundMoney(unitPrice * 60 / unit);
  return Math.ceil(extraMinutes / 60) * pricePerHour;
}

function overnightStayOriginal(roomNightPrice, extraPetNightPrice, petCount,
    surcharge) {
  const extraPets = Math.max(0, toInt(petCount, 1) - 1);
  return toInt(roomNightPrice, 0) + extraPets * toInt(extraPetNightPrice, 0) +
    toInt(surcharge, 0);
}

function applyCap(amount, capMode, capAmount) {
  const mode = normalizeString(capMode) || CAP_MODES.overnightRate;
  if (mode === CAP_MODES.none || toInt(capAmount, 0) <= 0) {
    return Math.max(0, amount);
  }
  return Math.max(0, Math.min(amount, toInt(capAmount, 0)));
}

function findRoomTypeSetting(settings, roomTypeId) {
  const list = Array.isArray(settings && settings.roomTypes) ?
    settings.roomTypes : [];
  const id = normalizeString(roomTypeId);
  return list.find((item) => normalizeString(item && item.roomTypeId) === id) ||
    null;
}

function quoteRoom(params) {
  const startAt = params.startAt;
  const endAt = params.endAt;
  const minutes = Math.max(0, Math.round((endAt - startAt) / 60000));
  const setting = params.roomSetting || {};
  const petCount = Math.max(1, toInt(params.petCount, 1));
  const extraPets = Math.max(0, petCount - 1);
  const extraTime = extraTimeAmount(
      Math.max(0, minutes - toInt(setting.baseMinutes, 240)),
      toInt(setting.extraTimeUnitMinutes, 60),
      toInt(setting.extraTimePrice, 0),
      setting.roundingMode,
  );
  const extraPetAmount = extraPets * toInt(setting.extraPetPrice, 0);
  const baseAmount = toInt(setting.basePrice, 0);
  const uncapped = baseAmount + extraPetAmount + extraTime;
  const capMode = normalizeString(setting.capMode) || CAP_MODES.overnightRate;
  const cap = capMode === CAP_MODES.fixedAmount ?
    toInt(setting.fixedCapAmount, 0) : toInt(params.overnightCapAmount, 0);
  const capped = applyCap(uncapped, capMode, cap);
  return {
    durationMinutes: minutes,
    baseAmount,
    extraPetAmount,
    extraTimeAmount: extraTime,
    uncappedRoomAmount: uncapped,
    capAmount: capMode === CAP_MODES.none ? 0 : cap,
    cappedRoomAmount: capped,
    roundingMode: normalizeString(setting.roundingMode) ||
      ROUNDING_MODES.ceilHour,
    capMode,
  };
}

function estimateFromPrice(settings, startAt, endAt, petCount) {
  const list = Array.isArray(settings && settings.roomTypes) ?
    settings.roomTypes.filter((item) => item && parseBool(item.enabled)) : [];
  if (!list.length) {
    return 0;
  }
  let min = null;
  list.forEach((item) => {
    const q = quoteRoom({
      roomSetting: item,
      startAt,
      endAt,
      petCount,
    });
    min = min == null ? q.cappedRoomAmount :
      Math.min(min, q.cappedRoomAmount);
  });
  return min || 0;
}

function roundingLabel(mode) {
  if (mode === ROUNDING_MODES.ceilHalfHour) {
    return "不足半小時，以半小時計";
  }
  if (mode === ROUNDING_MODES.prorated) {
    return "依實際分鐘比例計價，四捨五入為整數元";
  }
  return "不足一小時，以整小時計";
}

function paymentStatusOf(paid, total) {
  const p = toInt(paid, 0);
  const t = toInt(total, 0);
  if (t <= 0 && p <= 0) {
    return "unpaid";
  }
  if (p <= 0) {
    return "unpaid";
  }
  if (p >= t) {
    return "paid";
  }
  return "partial";
}

/**
 * @param {Object} plan
 * @param {number} minutes
 * @return {number}
 */
function baseAmount(plan, minutes) {
  const type = normalizeString(plan.type) || PLAN_TYPES.hourly;
  const price = toInt(plan.basePrice, 0);
  const minUnits = Math.max(1, toInt(plan.minChargeUnits, 1));
  const included = toInt(plan.includedMinutes, 60);
  const overtimeMode = normalizeString(plan.overtimeMode) ||
    OVERTIME_MODES.hourly;
  const overtimePrice = toInt(plan.overtimeUnitPrice, 0);

  if (type === PLAN_TYPES.halfHourly) {
    const units = Math.max(minUnits, Math.ceil(minutes / 30));
    return units * price;
  }
  if (type === PLAN_TYPES.hourly) {
    const units = Math.max(minUnits, Math.ceil(minutes / 60));
    return units * price;
  }
  let amount = price;
  if (minutes > included && overtimeMode !== OVERTIME_MODES.none) {
    const extra = minutes - included;
    if (overtimeMode === OVERTIME_MODES.halfHourly) {
      amount += Math.ceil(extra / 30) * overtimePrice;
    } else {
      amount += Math.ceil(extra / 60) * overtimePrice;
    }
  }
  return amount;
}

/**
 * @param {Object} settings
 * @param {number} total
 * @return {number}
 */
function depositAmount(settings, total) {
  const type = normalizeString(settings.depositType) || DEPOSIT_TYPES.none;
  if (type === DEPOSIT_TYPES.full) {
    return total;
  }
  if (type === DEPOSIT_TYPES.fixed) {
    return Math.max(0, Math.min(total, toInt(settings.depositValue, 0)));
  }
  if (type === DEPOSIT_TYPES.percent) {
    return Math.max(0, Math.min(
        total,
        roundMoney(total * toInt(settings.depositValue, 0) / 100),
    ));
  }
  return 0;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quote(params) {
  const startAt = params.startAt;
  const endAt = params.endAt;
  const minutes = Math.max(0, Math.round((endAt - startAt) / 60000));
  const petCount = Math.max(1, toInt(params.petCount, 1));
  const extraPets = Math.max(0, petCount - 1);
  const extraPetAmount = extraPets * toInt(params.plan.extraPetSurcharge, 0);
  const computedBase = baseAmount(params.plan, minutes);
  const roomTypeExtra = toInt(params.roomTypeExtra, 0);
  const addonAmount = toInt(params.addonAmount, 0);
  const surchargeAmount = toInt(params.surchargeAmount, 0);
  const discountAmount = toInt(params.discountAmount, 0);
  const couponAmount = toInt(params.couponAmount, 0);
  const pointAmount = toInt(params.pointAmount, 0);
  const overtimeAmt = toInt(params.overtimeAmount, 0);
  const manualAdjust = toInt(params.manualAdjust, 0);
  let total = computedBase + extraPetAmount + roomTypeExtra + addonAmount +
    surchargeAmount + overtimeAmt + manualAdjust -
    discountAmount - couponAmount - pointAmount;
  if (total < 0) {
    total = 0;
  }
  const deposit = depositAmount(params.settings || {}, total);
  return {
    durationMinutes: minutes,
    baseAmount: computedBase,
    extraPetAmount,
    roomTypeExtra,
    addonAmount,
    surchargeAmount,
    discountAmount,
    couponAmount,
    pointAmount,
    overtimeAmount: overtimeAmt,
    manualAdjust,
    totalAmount: total,
    depositAmount: deposit,
    remainingAmount: Math.max(0, total - deposit),
  };
}

/**
 * @param {Object} plan
 * @param {Object} settings
 * @param {Date} scheduledEndAt
 * @param {Date} actualEndAt
 * @return {number}
 */
function overtimeFee(plan, settings, scheduledEndAt, actualEndAt) {
  const extra = Math.max(0, Math.round(
      (actualEndAt - scheduledEndAt) / 60000,
  ));
  const grace = toInt(settings.overtimeGraceMinutes, 15);
  const billable = extra - grace;
  const mode = normalizeString(plan.overtimeMode) || OVERTIME_MODES.hourly;
  if (billable <= 0 || mode === OVERTIME_MODES.none) {
    return 0;
  }
  const unitPrice = toInt(plan.overtimeUnitPrice, 0);
  if (mode === OVERTIME_MODES.halfHourly) {
    return Math.ceil(billable / 30) * unitPrice;
  }
  return Math.ceil(billable / 60) * unitPrice;
}

/**
 * @param {Object} addon
 * @param {number} minutes
 * @param {number} petCount
 * @return {number}
 */
function addonLineAmount(addon, minutes, petCount) {
  const price = toInt(addon.price, 0);
  const mode = normalizeString(addon.daycareChargeMode) || "per_order";
  const qty = Math.max(1, toInt(addon.count, 1));
  if (mode === "per_pet") {
    return price * Math.max(1, petCount);
  }
  if (mode === "per_hour") {
    return price * Math.max(1, Math.ceil(minutes / 60));
  }
  if (mode === "per_slot") {
    return price * Math.max(1, toInt(addon.slotCount, 1));
  }
  if (mode === "custom") {
    return price * qty;
  }
  return price;
}

module.exports = {
  PLAN_TYPES,
  SELECTABLE_PLAN_TYPES,
  OVERTIME_MODES,
  DEPOSIT_TYPES,
  PRICING_MODES,
  ROUNDING_MODES,
  CAP_MODES,
  baseAmount,
  depositAmount,
  quote,
  overtimeFee,
  addonLineAmount,
  isRoomBased,
  extraTimeAmount,
  overnightStayOriginal,
  applyCap,
  findRoomTypeSetting,
  quoteRoom,
  estimateFromPrice,
  roundingLabel,
  paymentStatusOf,
};
