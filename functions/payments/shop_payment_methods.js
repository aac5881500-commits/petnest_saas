// 檔案名稱：functions/payments/shop_payment_methods.js
// 功能說明：店家客戶可用付款方式解析（與 Flutter ShopPaymentMethods 對齊）

const {normalizeString} = require("./payment_verify");

/**
 * @param {*} value
 * @param {boolean=} fallback
 * @return {boolean}
 */
function normalizeBoolean(value, fallback = false) {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value === 1;
  }
  const normalizedValue = normalizeString(value).toLowerCase();
  if (
    normalizedValue === "true" ||
    normalizedValue === "1" ||
    normalizedValue === "yes" ||
    normalizedValue === "enabled"
  ) {
    return true;
  }
  if (
    normalizedValue === "false" ||
    normalizedValue === "0" ||
    normalizedValue === "no" ||
    normalizedValue === "disabled"
  ) {
    return false;
  }
  return fallback;
}

const KEEP_ONE_MESSAGE = "請至少保留一種收款方式。";
const BANK_INCOMPLETE_MESSAGE = "請先補齊銀行名稱、戶名與帳號。";

/**
 * @param {Object} shop
 * @return {boolean}
 */
function isBankAccountComplete(shop) {
  const data = shop && typeof shop === "object" ? shop : {};
  return Boolean(
      normalizeString(data.bankName) &&
      normalizeString(data.accountName) &&
      normalizeString(data.accountNumber),
  );
}

/**
 * @param {Object} operationSettings
 * @return {boolean}
 */
function isCashEnabled(operationSettings) {
  const ops = operationSettings && typeof operationSettings === "object" ?
    operationSettings : {};
  if (ops.cashPaymentEnabled === undefined || ops.cashPaymentEnabled === null) {
    return true;
  }
  return normalizeBoolean(ops.cashPaymentEnabled, true);
}

/**
 * @param {Object} paymentSetting
 * @param {Object} operationSettings
 * @return {boolean}
 */
function ecpayMasterUsable(paymentSetting, operationSettings) {
  const setting = paymentSetting && typeof paymentSetting === "object" ?
    paymentSetting : {};
  const ops = operationSettings && typeof operationSettings === "object" ?
    operationSettings : {};
  const reviewStatus = normalizeString(setting.reviewStatus).toLowerCase();
  if (reviewStatus !== "approved") {
    return false;
  }
  if (normalizeBoolean(setting.platformSuspended) ||
      normalizeBoolean(setting.shopDisabled)) {
    return false;
  }
  return normalizeBoolean(ops.ecpayEnabled);
}

/**
 * @param {Object} paymentSetting
 * @param {string} enabledKey
 * @param {string} settingKey
 * @param {string=} altKey
 * @return {boolean}
 */
function approvedOnlineMethod(paymentSetting, enabledKey, settingKey, altKey) {
  const setting = paymentSetting && typeof paymentSetting === "object" ?
    paymentSetting : {};
  const enabledMethods = setting.enabledMethods &&
    typeof setting.enabledMethods === "object" &&
    !Array.isArray(setting.enabledMethods) ?
      setting.enabledMethods : {};
  return normalizeBoolean(enabledMethods[enabledKey]) ||
    normalizeBoolean(setting[settingKey]) ||
    (altKey ? normalizeBoolean(setting[altKey]) : false);
}

/**
 * @param {Object} shop
 * @param {Object=} opsOverride
 * @return {string[]}
 */
function effectiveMethodIds(shop, opsOverride) {
  const data = shop && typeof shop === "object" ? shop : {};
  const paymentSetting = data.paymentSetting &&
    typeof data.paymentSetting === "object" &&
    !Array.isArray(data.paymentSetting) ?
      data.paymentSetting : {};
  const operationSettings = opsOverride || (
    paymentSetting.operationSettings &&
    typeof paymentSetting.operationSettings === "object" ?
      paymentSetting.operationSettings : {}
  );
  const ids = [];
  if (isCashEnabled(operationSettings)) {
    ids.push("cash");
  }
  const bankOn = operationSettings.bankTransferEnabled === undefined ||
    operationSettings.bankTransferEnabled === null ?
    true :
    normalizeBoolean(operationSettings.bankTransferEnabled, true);
  if (bankOn && isBankAccountComplete(data)) {
    ids.push("transfer");
  }
  if (ecpayMasterUsable(paymentSetting, operationSettings)) {
    if (normalizeBoolean(operationSettings.creditCardEnabled) &&
        approvedOnlineMethod(
            paymentSetting, "creditCard", "creditCardEnabled")) {
      ids.push("credit_card");
    }
    if (normalizeBoolean(operationSettings.atmEnabled) &&
        approvedOnlineMethod(paymentSetting, "atm", "atmEnabled")) {
      ids.push("atm");
    }
    if (normalizeBoolean(operationSettings.cvsCodeEnabled) &&
        approvedOnlineMethod(
            paymentSetting,
            "cvsCode",
            "cvsCodeEnabled",
            "convenienceStoreCodeEnabled",
        )) {
      ids.push("cvs_code");
    }
  }
  return ids;
}

/**
 * @param {Object} params
 * @return {{ok: boolean, message: string}}
 */
function validateOperationSettings({
  shop,
  cashPaymentEnabled,
  bankTransferEnabled,
  ecpayEnabled,
  creditCardEnabled,
  atmEnabled,
  cvsCodeEnabled,
}) {
  if (bankTransferEnabled && !isBankAccountComplete(shop)) {
    return {ok: false, message: BANK_INCOMPLETE_MESSAGE};
  }
  const counted = effectiveMethodIds(shop, {
    cashPaymentEnabled,
    bankTransferEnabled,
    ecpayEnabled,
    creditCardEnabled,
    atmEnabled,
    cvsCodeEnabled,
  });
  if (!counted.length) {
    return {ok: false, message: KEEP_ONE_MESSAGE};
  }
  return {ok: true, message: ""};
}

/**
 * @param {string} paymentMethod
 * @return {string}
 */
function normalizeMethodId(paymentMethod) {
  const raw = normalizeString(paymentMethod).toLowerCase();
  if (raw === "pay_at_store" || raw === "onsite") {
    return "cash";
  }
  if (raw === "bank_transfer") {
    return "transfer";
  }
  if (raw === "ecpay_credit") {
    return "credit_card";
  }
  if (raw === "ecpay_atm") {
    return "atm";
  }
  if (raw === "ecpay_cvs") {
    return "cvs_code";
  }
  return raw;
}

/**
 * @param {Object} shop
 * @param {string} paymentMethod
 * @return {boolean}
 */
function isCustomerMethodAvailable(shop, paymentMethod) {
  const id = normalizeMethodId(paymentMethod);
  return effectiveMethodIds(shop).includes(id);
}

/**
 * 手動建單可提交的方式：到店付款、銀行轉帳。
 * @param {string} paymentMethod
 * @return {boolean}
 */
function isAdminCreateSelectable(paymentMethod) {
  const id = normalizeMethodId(paymentMethod);
  return id === "cash" || id === "transfer";
}

function isSettlementTopUpMethod(paymentMethod) {
  const id = normalizeMethodId(paymentMethod);
  return id === "cash" ||
    id === "transfer" ||
    id === "credit_card" ||
    id === "atm";
}

function isSettlementTopUpMethodAvailable(shop, paymentMethod) {
  const id = normalizeMethodId(paymentMethod);
  return isSettlementTopUpMethod(id) &&
    effectiveMethodIds(shop).includes(id);
}

module.exports = {
  KEEP_ONE_MESSAGE,
  BANK_INCOMPLETE_MESSAGE,
  isBankAccountComplete,
  isCashEnabled,
  ecpayMasterUsable,
  effectiveMethodIds,
  validateOperationSettings,
  normalizeMethodId,
  isCustomerMethodAvailable,
  isAdminCreateSelectable,
  isSettlementTopUpMethod,
  isSettlementTopUpMethodAvailable,
};
