// 檔案名稱：functions/daycare/daycare_supply.js
// 功能說明：安親開始時依服務耗材設定扣中央庫存，取消已開始的安親才返還。
// 舊文件沒有 appliesToDaycare 時不扣安親。幂等 ID 使用 ds_，與住宿 bs_ 分開。

const {HttpsError} = require("firebase-functions/v2/https");
const {roundQuantity} = require("../inventory/inventory_cost");
const {
  consumptionId,
  prepareMergedDeduct,
  prepareReturnFromDeduct,
} = require("../inventory/inventory_consumption");

const DAYCARE_DEDUCT_NOTE = "開始安親扣除耗材";
const DAYCARE_RETURN_TEXT = "取消安親返還耗材";

/**
 * @param {string} bookingId
 * @return {string}
 */
function daycareSupplyDeductId(bookingId) {
  return consumptionId("ds", bookingId, "deduct");
}

/**
 * @param {string} bookingId
 * @return {string}
 */
function daycareSupplyReturnId(bookingId) {
  return consumptionId("ds", bookingId, "return");
}

/**
 * @param {*} value
 * @return {number}
 */
function readQuantity(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue) || numberValue < 0) {
    return 0;
  }
  return numberValue;
}

/**
 * @param {Object} data
 * @return {Object}
 */
function parseSupplySetting(data) {
  const source = data || {};
  const legacyQuantity = readQuantity(source.quantityPerUnit);
  const legacyMode = String(source.deductionMode || "perRoomPerNight");
  const hasAppliesStay = Object.prototype.hasOwnProperty.call(
      source, "appliesToStay",
  );
  const hasStayQuantity = Object.prototype.hasOwnProperty.call(
      source, "stayQuantityPerUnit",
  );
  const hasStayMode = Object.prototype.hasOwnProperty.call(
      source, "stayDeductionMode",
  );
  const hasDaycareQuantity = Object.prototype.hasOwnProperty.call(
      source, "daycareQuantityPerUnit",
  );
  return {
    name: String(source.name || "").trim(),
    enabled: source.enabled !== false,
    useInventory: source.useInventory === true,
    inventoryItemId: String(source.inventoryItemId || "").trim(),
    appliesToStay: hasAppliesStay ? source.appliesToStay === true : true,
    appliesToDaycare: source.appliesToDaycare === true,
    stayQuantityPerUnit: hasStayQuantity ?
      readQuantity(source.stayQuantityPerUnit) : legacyQuantity,
    stayDeductionMode: hasStayMode ?
      String(source.stayDeductionMode || legacyMode) : legacyMode,
    daycareQuantityPerUnit: hasDaycareQuantity ?
      readQuantity(source.daycareQuantityPerUnit) : 1,
    daycareDeductionMode: String(
        source.daycareDeductionMode || "perRoomPerVisit",
    ),
  };
}

/**
 * @param {Object} setting
 * @return {boolean}
 */
function shouldDeductForStay(setting) {
  return setting.enabled === true &&
    setting.useInventory === true &&
    String(setting.inventoryItemId || "").trim() !== "" &&
    setting.appliesToStay === true;
}

/**
 * @param {Object} setting
 * @return {boolean}
 */
function shouldDeductForDaycare(setting) {
  return setting.enabled === true &&
    setting.useInventory === true &&
    String(setting.inventoryItemId || "").trim() !== "" &&
    setting.appliesToDaycare === true;
}

/**
 * @param {Object} booking
 * @return {number}
 */
function bookingPetCount(booking) {
  const source = booking || {};
  if (Array.isArray(source.petIds) && source.petIds.length > 0) {
    return source.petIds.length;
  }
  if (Array.isArray(source.pets) && source.pets.length > 0) {
    return source.pets.length;
  }
  return 1;
}

/**
 * @param {Object} booking
 * @return {number}
 */
function bookingNightCount(booking) {
  const nights = Number((booking || {}).nights);
  if (Number.isFinite(nights) && nights > 0) {
    return Math.floor(nights);
  }
  return 1;
}

/**
 * @param {Object} setting
 * @param {number} nights
 * @param {number} petCount
 * @return {number}
 */
function stayDeductQuantity(setting, nights, petCount) {
  const safeNights = nights > 0 ? nights : 1;
  const safePets = petCount > 0 ? petCount : 1;
  let multiplier = 1;
  switch (setting.stayDeductionMode) {
    case "perRoomPerStay":
      multiplier = 1;
      break;
    case "perPetPerNight":
      multiplier = safePets * safeNights;
      break;
    case "perPetPerStay":
      multiplier = safePets;
      break;
    case "perRoomPerNight":
    default:
      multiplier = safeNights;
      break;
  }
  return roundQuantity(setting.stayQuantityPerUnit * multiplier);
}

/**
 * @param {Object} setting
 * @param {number} petCount
 * @return {number}
 */
function daycareDeductQuantity(setting, petCount) {
  const safePets = petCount > 0 ? petCount : 1;
  const multiplier = setting.daycareDeductionMode === "perPetPerVisit" ?
    safePets : 1;
  return roundQuantity(setting.daycareQuantityPerUnit * multiplier);
}

/**
 * @param {Array<Object>} settings
 * @param {Object} booking
 * @return {Array<Object>}
 */
function buildDaycareSupplyLines(settings, booking) {
  const petCount = bookingPetCount(booking);
  const lines = [];
  (settings || []).forEach((setting) => {
    if (!shouldDeductForDaycare(setting)) {
      return;
    }
    const quantity = daycareDeductQuantity(setting, petCount);
    if (quantity <= 0) {
      return;
    }
    const name = setting.name || "未命名耗材";
    lines.push({
      inventoryItemId: setting.inventoryItemId,
      quantity,
      reason: `安親耗材「${name}」`,
      note: DAYCARE_DEDUCT_NOTE,
    });
  });
  return lines;
}

/**
 * @param {Array<Object>} settings
 * @param {Object} booking
 * @return {Array<Object>}
 */
function buildStaySupplyLines(settings, booking) {
  const nights = bookingNightCount(booking);
  const petCount = bookingPetCount(booking);
  const lines = [];
  (settings || []).forEach((setting) => {
    if (!shouldDeductForStay(setting)) {
      return;
    }
    const quantity = stayDeductQuantity(setting, nights, petCount);
    if (quantity <= 0) {
      return;
    }
    lines.push({
      inventoryItemId: setting.inventoryItemId,
      quantity,
      reason: `住宿耗材「${setting.name || ""}」`,
      note: "入住扣除住宿耗材",
    });
  });
  return lines;
}

/**
 * 已開始且尚未結算的安親才返還。未開始、已完成、已結算都不返還。
 * @param {Object} booking
 * @return {boolean}
 */
function shouldReturnDaycareSupplies(booking) {
  const source = booking || {};
  if (String(source.status || "").trim() !== "checked_in") {
    return false;
  }
  if (source.settlementConfirmed === true || source.settledAt != null) {
    return false;
  }
  if (source.settlementLocked === true) {
    return false;
  }
  return true;
}

/**
 * 訂單已取消後，若當初有扣過且尚未結算，才允許走返還入口。
 * @param {Object} booking
 * @return {boolean}
 */
function canReturnDaycareSuppliesAfterCancel(booking) {
  const source = booking || {};
  if (source.settlementConfirmed === true || source.settledAt != null) {
    return false;
  }
  if (source.settlementLocked === true) {
    return false;
  }
  if (String(source.status || "").trim() === "completed") {
    return false;
  }
  return true;
}

/**
 * @param {boolean} consumptionExists
 * @param {number} lineCount
 * @return {boolean}
 */
function shouldSkipSupplyDeduct(consumptionExists, lineCount) {
  return consumptionExists === true || lineCount <= 0;
}

/**
 * @param {boolean} returnExists
 * @param {boolean} deductExists
 * @return {boolean}
 */
function shouldSkipSupplyReturn(returnExists, deductExists) {
  return returnExists === true || deductExists !== true;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareDaycareSupplyDeduct(transaction, params) {
  const lines = buildDaycareSupplyLines(params.settings, params.booking);
  return prepareMergedDeduct(transaction, {
    shopId: params.shopId,
    consumptionId: daycareSupplyDeductId(params.bookingId),
    sourceType: "bookingSupply",
    sourceId: params.bookingId,
    movementType: "bookingSupply",
    note: DAYCARE_DEDUCT_NOTE,
    lines,
  });
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareDaycareSupplyReturn(transaction, params) {
  const prepared = await prepareReturnFromDeduct(transaction, {
    shopId: params.shopId,
    deductId: daycareSupplyDeductId(params.bookingId),
    returnId: daycareSupplyReturnId(params.bookingId),
    sourceType: "return",
    sourceId: params.bookingId,
    movementType: "return",
    note: DAYCARE_RETURN_TEXT,
  });
  if (prepared && Array.isArray(prepared.lines)) {
    prepared.lines.forEach((line) => {
      line.reason = DAYCARE_RETURN_TEXT;
      line.note = DAYCARE_RETURN_TEXT;
    });
  }
  if (prepared) {
    prepared.note = DAYCARE_RETURN_TEXT;
  }
  return prepared;
}

/**
 * @param {Object} error
 * @param {string} fallback
 * @return {HttpsError}
 */
function toDaycareSupplyError(error, fallback) {
  if (error instanceof HttpsError) {
    return error;
  }
  const message = error && error.message ? String(error.message).trim() : "";
  const safe = message &&
    message.length <= 160 &&
    !message.includes("\n") &&
    !/stack|firebase|exception/i.test(message);
  return new HttpsError(
      "failed-precondition",
      safe ? message : fallback,
  );
}

module.exports = {
  daycareSupplyDeductId,
  daycareSupplyReturnId,
  parseSupplySetting,
  shouldDeductForStay,
  shouldDeductForDaycare,
  bookingPetCount,
  buildDaycareSupplyLines,
  buildStaySupplyLines,
  shouldReturnDaycareSupplies,
  canReturnDaycareSuppliesAfterCancel,
  shouldSkipSupplyDeduct,
  shouldSkipSupplyReturn,
  prepareDaycareSupplyDeduct,
  prepareDaycareSupplyReturn,
  toDaycareSupplyError,
};
