// 檔案名稱：functions/daycare/daycare_pricing.js
// 功能說明：臨托計價：與 Flutter DaycarePricingService 同一公式

const {
  roundMoney, toInt, normalizeString, parseBool,
} = require("./daycare_utils");

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

/**
 * 房型計費相容 room_based／roomType／room_type。
 * @param {Object} settingsOrBooking
 * @return {boolean}
 */
function isRoomBased(settingsOrBooking) {
  const mode = normalizeString(
      (settingsOrBooking && settingsOrBooking.pricingMode) || "",
  );
  return mode === PRICING_MODES.roomBased ||
    mode === "roomType" ||
    mode === "room_type";
}

/**
 * 訂金報價可預估尾款；真正入帳的尚需付款必須是總額減已付。
 * @param {number} total
 * @param {number} paid
 * @return {number}
 */
function remainingFromPaid(total, paid) {
  return Math.max(0, toInt(total, 0) - toInt(paid, 0));
}

/**
 * 與 Flutter DaycarePricingService.quoteTimeCharge 相同：
 * maxBaseCharge 只限制起步費＋超時加收，不含多寵費。
 * @param {Object} params
 * @return {Object}
 */
function quoteTimeCharge(params) {
  const durationMinutes = Math.max(0, toInt(params.durationMinutes, 0));
  const includedMinutes = Math.max(1, toInt(params.includedMinutes, 1));
  const extraBillingMinutes = toInt(params.extraBillingMinutes, 60) === 30 ?
    30 : 60;
  const extraBillingPrice = toInt(params.extraBillingPrice, 0);
  const extraPetPrice = toInt(
      params.extraPetPrice != null ? params.extraPetPrice :
        params.extraPetSurcharge,
      0,
  );
  const maxBaseCharge = Math.max(0, toInt(params.maxBaseCharge, 0));
  const petCount = Math.max(1, toInt(params.petCount, 1));
  const extraMinutes = Math.max(0, Math.min(durationMinutes - includedMinutes,
      24 * 60));
  const extraUnits = extraMinutes > 0 ?
    Math.ceil(extraMinutes / extraBillingMinutes) : 0;
  const uncappedTimeCharge = toInt(params.basePrice, 0) +
    extraUnits * extraBillingPrice;
  const timeCharge = maxBaseCharge > 0 ?
    Math.min(uncappedTimeCharge, maxBaseCharge) : uncappedTimeCharge;
  const extraPetCount = Math.max(0, petCount - 1);
  const extraPetCharge = extraPetCount * extraPetPrice;
  return {
    durationMinutes,
    includedMinutes,
    extraMinutes,
    extraUnits,
    extraBillingMinutes,
    uncappedTimeCharge,
    timeCharge,
    extraPetCount,
    extraPetCharge,
    maxBaseCharge,
  };
}

/**
 * @param {number} extraMinutes
 * @param {number} unitMinutes
 * @param {number} unitPrice
 * @param {string} roundingMode
 * @return {number}
 */
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

/**
 * @param {number} roomNightPrice
 * @param {number} extraPetNightPrice
 * @param {number} petCount
 * @param {number} surcharge
 * @return {number}
 */
function overnightStayOriginal(roomNightPrice, extraPetNightPrice, petCount,
    surcharge) {
  const extraPets = Math.max(0, toInt(petCount, 1) - 1);
  return toInt(roomNightPrice, 0) + extraPets * toInt(extraPetNightPrice, 0) +
    toInt(surcharge, 0);
}

/**
 * @param {number} amount
 * @param {string} capMode
 * @param {number} capAmount
 * @return {number}
 */
function applyCap(amount, capMode, capAmount) {
  const mode = normalizeString(capMode) || CAP_MODES.overnightRate;
  if (mode === CAP_MODES.none || toInt(capAmount, 0) <= 0) {
    return Math.max(0, amount);
  }
  return Math.max(0, Math.min(amount, toInt(capAmount, 0)));
}

/**
 * @param {Object} settings
 * @param {string} roomTypeId
 * @return {Object|null}
 */
function findRoomTypeSetting(settings, roomTypeId) {
  const list = Array.isArray(settings && settings.roomTypes) ?
    settings.roomTypes : [];
  const id = normalizeString(roomTypeId);
  return list.find((item) => normalizeString(item && item.roomTypeId) === id) ||
    null;
}

/**
 * @param {Object} params
 * @return {Object}
 */
function quoteRoom(params) {
  const startAt = params.startAt;
  const endAt = params.endAt;
  const minutes = Math.max(0, Math.round((endAt - startAt) / 60000));
  const setting = params.roomSetting || {};
  const extraBillingPrice = toInt(
      setting.extraBillingPrice != null ? setting.extraBillingPrice :
        setting.extraTimePrice,
      0,
  );
  const charge = quoteTimeCharge({
    includedMinutes: setting.includedMinutes != null ?
      setting.includedMinutes : setting.baseMinutes,
    basePrice: setting.basePrice,
    extraBillingMinutes: setting.extraBillingMinutes != null ?
      setting.extraBillingMinutes : setting.extraTimeUnitMinutes,
    extraBillingPrice,
    extraPetPrice: setting.extraPetPrice,
    maxBaseCharge: setting.maxBaseCharge,
    durationMinutes: minutes,
    petCount: params.petCount,
  });
  return {
    durationMinutes: charge.durationMinutes,
    baseAmount: toInt(setting.basePrice, 0),
    extraPetAmount: charge.extraPetCharge,
    extraTimeAmount: charge.extraUnits * extraBillingPrice,
    uncappedRoomAmount: charge.uncappedTimeCharge + charge.extraPetCharge,
    capAmount: charge.maxBaseCharge,
    cappedRoomAmount: charge.timeCharge + charge.extraPetCharge,
    roundingMode: normalizeString(setting.roundingMode) ||
      ROUNDING_MODES.ceilHour,
    capMode: normalizeString(setting.capMode) || CAP_MODES.none,
    extraMinutes: charge.extraMinutes,
    extraUnits: charge.extraUnits,
    includedMinutes: charge.includedMinutes,
    extraBillingMinutes: charge.extraBillingMinutes,
    extraPetCount: charge.extraPetCount,
    timeCharge: charge.timeCharge,
    maxBaseCharge: charge.maxBaseCharge,
    uncappedTimeCharge: charge.uncappedTimeCharge,
  };
}

/**
 * @param {Object} settings
 * @param {Date} startAt
 * @param {Date} endAt
 * @param {number} petCount
 * @return {number}
 */
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

/**
 * @param {string} mode
 * @return {string}
 */
function roundingLabel(mode) {
  if (mode === ROUNDING_MODES.ceilHalfHour) {
    return "不足半小時，以半小時計";
  }
  if (mode === ROUNDING_MODES.prorated) {
    return "依實際分鐘比例計價，四捨五入為整數元";
  }
  return "不足一小時，以整小時計";
}

/**
 * @param {number} paid
 * @param {number} total
 * @return {string}
 */
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
  const value = toInt(
      settings.depositValue != null ?
        settings.depositValue : settings.depositAmount,
      0,
  );
  if (type === DEPOSIT_TYPES.full) {
    return total;
  }
  if (type === DEPOSIT_TYPES.fixed) {
    return Math.max(0, Math.min(total, value));
  }
  if (type === DEPOSIT_TYPES.percent) {
    return Math.max(0, Math.min(
        total,
        roundMoney(total * value / 100),
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
  const plan = params.plan || {};
  const charge = quoteTimeCharge({
    includedMinutes: plan.includedMinutes,
    basePrice: plan.basePrice,
    extraBillingMinutes: plan.extraBillingMinutes,
    extraBillingPrice: plan.extraBillingPrice,
    extraPetPrice: plan.extraPetPrice != null ?
      plan.extraPetPrice : plan.extraPetSurcharge,
    maxBaseCharge: plan.maxBaseCharge,
    durationMinutes: minutes,
    petCount: params.petCount,
  });
  const extraPetAmount = charge.extraPetCharge;
  const roomTypeExtra = toInt(params.roomTypeExtra, 0);
  const addonAmount = toInt(params.addonAmount, 0);
  const surchargeAmount = toInt(params.surchargeAmount, 0);
  const discountAmount = toInt(params.discountAmount, 0);
  const couponAmount = toInt(params.couponAmount, 0);
  const pointAmount = toInt(params.pointAmount, 0);
  const overtimeAmt = toInt(params.overtimeAmount, 0);
  const manualAdjust = toInt(params.manualAdjust, 0);
  let total = charge.timeCharge + extraPetAmount + roomTypeExtra + addonAmount +
    surchargeAmount + overtimeAmt + manualAdjust -
    discountAmount - couponAmount - pointAmount;
  if (total < 0) {
    total = 0;
  }
  const deposit = depositAmount(params.settings || {}, total);
  return {
    durationMinutes: charge.durationMinutes,
    baseAmount: toInt(plan.basePrice, 0),
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
    extraTimeAmount: charge.extraUnits * toInt(plan.extraBillingPrice, 0),
    extraMinutes: charge.extraMinutes,
    extraUnits: charge.extraUnits,
    includedMinutes: charge.includedMinutes,
    extraBillingMinutes: charge.extraBillingMinutes,
    extraPetCount: charge.extraPetCount,
    timeCharge: charge.timeCharge,
    maxBaseCharge: charge.maxBaseCharge,
    uncappedTimeCharge: charge.uncappedTimeCharge,
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
 * 結算用晚接回逾時：店家 latePickup 設定，與 quoteTimeCharge／方案 overtimeFee 分開。
 * @param {Object} settings
 * @param {Date|null} scheduledEndAt
 * @param {Date} actualEndAt
 * @return {Object}
 */
function shopLatePickupBreakdown(settings, scheduledEndAt, actualEndAt) {
  const extra = (!scheduledEndAt || !actualEndAt) ? 0 : Math.max(0,
      Math.floor((actualEndAt - scheduledEndAt) / 60000));
  const grace = Math.max(0, toInt(settings.overtimeGraceMinutes, 0));
  const unitPrice = toInt(settings.latePickupPrice, 0);
  const enabled = parseBool(settings.latePickupEnabled) && unitPrice > 0;
  const unitMinutes = toInt(settings.latePickupUnitMinutes, 60) === 30 ?
    30 : 60;
  const billableRaw = extra - grace;
  const billable = billableRaw < 0 ? 0 : billableRaw;
  let units = 0;
  let amount = 0;
  if (enabled && billable > 0) {
    units = Math.ceil(billable / unitMinutes);
    amount = units * unitPrice;
  }
  let formula = "未加收";
  if (amount > 0) {
    formula = unitMinutes === 30 ?
      `${units} 個 30 分鐘 × NT$${unitPrice}` :
      `${units} 小時 × NT$${unitPrice}`;
  }
  return {
    extraMinutes: extra,
    graceMinutes: grace,
    billableMinutes: billable,
    unitMinutes,
    unitPrice,
    units,
    amount,
    enabled,
    formula,
  };
}

/**
 * @param {Object} settings
 * @param {Date} scheduledEndAt
 * @param {Date} actualEndAt
 * @return {number}
 */
function shopLatePickupFee(settings, scheduledEndAt, actualEndAt) {
  return shopLatePickupBreakdown(settings, scheduledEndAt, actualEndAt).amount;
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
  quoteTimeCharge,
  depositAmount,
  quote,
  overtimeFee,
  shopLatePickupBreakdown,
  shopLatePickupFee,
  addonLineAmount,
  isRoomBased,
  remainingFromPaid,
  extraTimeAmount,
  overnightStayOriginal,
  applyCap,
  findRoomTypeSetting,
  quoteRoom,
  estimateFromPrice,
  roundingLabel,
  paymentStatusOf,
};
