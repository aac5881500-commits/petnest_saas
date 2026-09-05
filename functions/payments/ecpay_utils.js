// 檔案名稱：functions/payments/ecpay_utils.js
// 功能說明：產生符合綠界格式的 MerchantTradeNo
// 🟢 綠界金流共用工具
// 確保交易編號僅包含英數字、長度不超過 20 碼。

const crypto = require("crypto");
const {HttpsError} = require("firebase-functions/v2/https");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 產生綠界 MerchantTradeNo
 *
 * 綠界限制：
 * - 最長 20 碼
 * - 使用英數字
 * - 每筆交易不可重複
 *
 * 使用 paymentId 建立固定雜湊，
 * 相同 paymentId 永遠會得到相同交易編號。
 *
 * 格式：
 * PN + 18 碼大寫雜湊
 *
 * @param {string} paymentId PetNest 付款紀錄 ID
 * @return {string}
 */
function createMerchantTradeNo(paymentId) {
  const normalizedPaymentId = normalizeString(paymentId);

  if (!normalizedPaymentId) {
    throw new HttpsError(
        "invalid-argument",
        "缺少付款紀錄編號，無法建立綠界交易編號。",
    );
  }

  const hash = crypto
      .createHash("sha256")
      .update(normalizedPaymentId)
      .digest("hex")
      .toUpperCase();

  return `PN${hash.substring(0, 18)}`;
}

/**
 * 驗證 MerchantTradeNo 格式
 *
 * @param {string} merchantTradeNo 綠界交易編號
 * @return {boolean}
 */
function isValidMerchantTradeNo(merchantTradeNo) {
  const normalizedValue = normalizeString(
      merchantTradeNo,
  );

  if (!normalizedValue) {
    return false;
  }

  if (normalizedValue.length > 20) {
    return false;
  }

  return /^[A-Za-z0-9]+$/.test(normalizedValue);
}

module.exports = {
  createMerchantTradeNo,
  isValidMerchantTradeNo,
};
