// functions/payments/payment_settings.js
// ⚙️ 金流設定驗證工具
// 功能：驗證平台金流總開關、店家資格、金流審核狀態，
// 以及信用卡、ATM、超商代碼等付款方式是否可以使用。

const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 將未知資料安全轉成布林值
 *
 * 支援：
 * true、false、1、0、"true"、"false"
 *
 * @param {*} value 原始資料
 * @param {boolean} fallback 預設值
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

/**
 * 取得平台金流設定
 *
 * 預設讀取：
 * platform_settings/payment
 *
 * @return {Promise<Object>}
 */
async function getPlatformPaymentSetting() {
  const settingSnapshot = await admin
      .firestore()
      .collection("platform_settings")
      .doc("payment")
      .get();

  if (!settingSnapshot.exists) {
    throw new HttpsError(
        "failed-precondition",
        "平台尚未建立金流設定。",
    );
  }

  return {
    settingRef: settingSnapshot.ref,
    setting: settingSnapshot.data() || {},
  };
}

/**
 * 取得店家資料與金流設定
 *
 * 店家金流設定預設存放於：
 * shops/{shopId}.paymentSetting
 *
 * @param {string} shopId 店家 ID
 * @return {Promise<Object>}
 */
async function getShopPaymentSetting(shopId) {
  const normalizedShopId = normalizeString(shopId);

  if (!normalizedShopId) {
    throw new HttpsError(
        "invalid-argument",
        "缺少店家編號。",
    );
  }

  const shopSnapshot = await admin
      .firestore()
      .collection("shops")
      .doc(normalizedShopId)
      .get();

  if (!shopSnapshot.exists) {
    throw new HttpsError(
        "not-found",
        "找不到指定的店家。",
    );
  }

  const shop = shopSnapshot.data() || {};
  const rawPaymentSetting = shop.paymentSetting;

  const paymentSetting =
    rawPaymentSetting &&
    typeof rawPaymentSetting === "object" &&
    !Array.isArray(rawPaymentSetting) ?
      rawPaymentSetting :
      {};

  return {
    shopRef: shopSnapshot.ref,
    shop,
    paymentSetting,
  };
}

/**
 * 判斷店家認證是否完成
 *
 * 相容可能存在的欄位：
 * isVerified
 * verified
 * verificationStatus
 * verifyStatus
 *
 * @param {Object} shop 店家資料
 * @return {boolean}
 */
function isShopVerified(shop) {
  if (
    normalizeBoolean(shop.isVerified) ||
    normalizeBoolean(shop.verified)
  ) {
    return true;
  }

  const verificationStatus = normalizeString(
      shop.verificationStatus || shop.verifyStatus,
  ).toLowerCase();

  return (
    verificationStatus === "approved" ||
    verificationStatus === "verified"
  );
}

/**
 * 判斷指定付款方式是否開啟
 *
 * 相容欄位：
 * enabledMethods.creditCard
 * enabledMethods.atm
 * enabledMethods.cvsCode
 *
 * 以及：
 * creditCardEnabled
 * atmEnabled
 * cvsCodeEnabled
 *
 * @param {Object} paymentSetting 店家金流設定
 * @param {string} paymentMethod 付款方式
 * @return {boolean}
 */
function isPaymentMethodEnabled(
    paymentSetting,
    paymentMethod,
) {
  const normalizedMethod = normalizeString(
      paymentMethod,
  ).toLowerCase();

  const rawEnabledMethods = paymentSetting.enabledMethods;

  const enabledMethods =
    rawEnabledMethods &&
    typeof rawEnabledMethods === "object" &&
    !Array.isArray(rawEnabledMethods) ?
      rawEnabledMethods :
      {};

  if (normalizedMethod === "credit_card") {
    const creditCardValue =
      enabledMethods.creditCard !== undefined ?
        enabledMethods.creditCard :
        paymentSetting.creditCardEnabled;

    return normalizeBoolean(creditCardValue);
  }

  if (normalizedMethod === "atm") {
    const atmValue =
      enabledMethods.atm !== undefined ?
        enabledMethods.atm :
        paymentSetting.atmEnabled;

    return normalizeBoolean(atmValue);
  }

  if (normalizedMethod === "cvs_code") {
    const cvsCodeValue =
      enabledMethods.cvsCode !== undefined ?
        enabledMethods.cvsCode :
        paymentSetting.cvsCodeEnabled;

    return normalizeBoolean(cvsCodeValue);
  }

  return false;
}

/**
 * 驗證平台及店家是否可以建立付款
 *
 * @param {Object} params 驗證參數
 * @param {string} params.shopId 店家 ID
 * @param {string} params.paymentMethod 付款方式
 * @return {Promise<Object>}
 */
async function verifyPaymentSettings({
  shopId,
  paymentMethod,
}) {
  const normalizedShopId = normalizeString(shopId);

  const normalizedPaymentMethod = normalizeString(
      paymentMethod,
  ).toLowerCase();

  const [
    platformResult,
    shopResult,
  ] = await Promise.all([
    getPlatformPaymentSetting(),
    getShopPaymentSetting(normalizedShopId),
  ]);

  const platformSetting = platformResult.setting;
  const shop = shopResult.shop;
  const paymentSetting = shopResult.paymentSetting;

  const platformPaymentValue =
    platformSetting.enabled !== undefined ?
      platformSetting.enabled :
      platformSetting.paymentEnabled;

  const platformPaymentEnabled = normalizeBoolean(
      platformPaymentValue,
  );

  if (!platformPaymentEnabled) {
    throw new HttpsError(
        "unavailable",
        "平台目前暫停線上付款服務。",
    );
  }

  const ecpayEnabled = normalizeBoolean(
      platformSetting.ecpayEnabled,
      true,
  );

  if (!ecpayEnabled) {
    throw new HttpsError(
        "unavailable",
        "平台目前暫停綠界付款服務。",
    );
  }

  const accountStatus = normalizeString(
      shop.accountStatus,
  ).toLowerCase();

  if (
    accountStatus === "suspended" ||
    accountStatus === "disabled" ||
    accountStatus === "blocked"
  ) {
    throw new HttpsError(
        "permission-denied",
        "店家帳號目前無法使用線上付款。",
    );
  }

  if (!isShopVerified(shop)) {
    throw new HttpsError(
        "failed-precondition",
        "店家尚未完成認證，無法使用線上付款。",
    );
  }

  const reviewStatus = normalizeString(
      paymentSetting.reviewStatus ||
      paymentSetting.status,
  ).toLowerCase();

  if (reviewStatus !== "approved") {
    throw new HttpsError(
        "failed-precondition",
        "店家金流尚未通過平台審核。",
    );
  }

  const paymentEnabledValue =
    paymentSetting.enabled !== undefined ?
      paymentSetting.enabled :
      paymentSetting.onlinePaymentEnabled;

  const paymentEnabled = normalizeBoolean(
      paymentEnabledValue,
  );

  if (!paymentEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "店家目前未開啟線上付款。",
    );
  }

  if (
    !isPaymentMethodEnabled(
        paymentSetting,
        normalizedPaymentMethod,
    )
  ) {
    throw new HttpsError(
        "failed-precondition",
        "店家目前未開啟這個付款方式。",
    );
  }

  const merchantId = normalizeString(
      paymentSetting.merchantId,
  );

  if (!merchantId) {
    throw new HttpsError(
        "failed-precondition",
        "店家缺少綠界商店代號，暫時無法付款。",
    );
  }

  return {
    platformSettingRef: platformResult.settingRef,
    platformSetting,
    shopRef: shopResult.shopRef,
    shop,
    paymentSetting,
    shopId: normalizedShopId,
    paymentMethod: normalizedPaymentMethod,
    merchantId,
  };
}

module.exports = {
  normalizeBoolean,
  getPlatformPaymentSetting,
  getShopPaymentSetting,
  isShopVerified,
  isPaymentMethodEnabled,
  verifyPaymentSettings,
};
