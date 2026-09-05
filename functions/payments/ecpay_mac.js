// 檔案名稱：functions/payments/ecpay_mac.js
// 功能說明：依綠界規格產生與驗證 CheckMacValue
// 🔐 綠界 CheckMacValue 工具
// 防止建立付款與付款通知資料遭到竄改。

const crypto = require("crypto");
const {HttpsError} = require("firebase-functions/v2/https");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 將資料轉成綠界 CheckMacValue 使用的字串
 *
 * @param {*} value 原始值
 * @return {string}
 */
function normalizeMacValue(value) {
  if (value === null || value === undefined) {
    return "";
  }

  if (typeof value === "boolean") {
    return value ? "1" : "0";
  }

  return String(value);
}

/**
 * 依綠界規則進行 URL Encode
 *
 * Node.js encodeURIComponent 與綠界規格存在部分差異，
 * 因此需要補做字元轉換。
 *
 * @param {string} value 原始字串
 * @return {string}
 */
function ecpayUrlEncode(value) {
  return encodeURIComponent(value)
      .replace(/%20/g, "+")
      .replace(/%2D/gi, "-")
      .replace(/%5F/gi, "_")
      .replace(/%2E/gi, ".")
      .replace(/%21/gi, "!")
      .replace(/%2A/gi, "*")
      .replace(/%28/gi, "(")
      .replace(/%29/gi, ")")
      .toLowerCase();
}

/**
 * 建立 CheckMacValue 計算用明文
 *
 * 計算前會：
 * 1. 排除 CheckMacValue
 * 2. 依欄位名稱排序
 * 3. 組成 key=value&key=value
 * 4. 前後加入 HashKey、HashIV
 *
 * @param {Object} params 參數
 * @param {Object} params.data 綠界交易參數
 * @param {string} params.hashKey 綠界 HashKey
 * @param {string} params.hashIv 綠界 HashIV
 * @return {string}
 */
function createMacRawValue({
  data,
  hashKey,
  hashIv,
}) {
  const normalizedHashKey = normalizeString(hashKey);
  const normalizedHashIv = normalizeString(hashIv);

  if (!normalizedHashKey || !normalizedHashIv) {
    throw new HttpsError(
        "failed-precondition",
        "綠界 HashKey 或 HashIV 尚未設定。",
    );
  }

  if (
    !data ||
    typeof data !== "object" ||
    Array.isArray(data)
  ) {
    throw new HttpsError(
        "invalid-argument",
        "綠界檢查碼資料格式不正確。",
    );
  }

  const sortedKeys = Object.keys(data)
      .filter((key) => {
        return key.toLowerCase() !== "checkmacvalue";
      })
      .sort((firstKey, secondKey) => {
        return firstKey
            .toLowerCase()
            .localeCompare(secondKey.toLowerCase());
      });

  const queryString = sortedKeys
      .map((key) => {
        const value = normalizeMacValue(data[key]);

        return `${key}=${value}`;
      })
      .join("&");

  return `HashKey=${normalizedHashKey}` +
    `&${queryString}` +
    `&HashIV=${normalizedHashIv}`;
}

/**
 * 產生綠界 CheckMacValue
 *
 * @param {Object} params 參數
 * @param {Object} params.data 綠界交易參數
 * @param {string} params.hashKey 綠界 HashKey
 * @param {string} params.hashIv 綠界 HashIV
 * @return {string}
 */
function createCheckMacValue({
  data,
  hashKey,
  hashIv,
}) {
  const rawValue = createMacRawValue({
    data,
    hashKey,
    hashIv,
  });

  const encodedValue = ecpayUrlEncode(rawValue);

  return crypto
      .createHash("sha256")
      .update(encodedValue)
      .digest("hex")
      .toUpperCase();
}

/**
 * 使用 timingSafeEqual 安全比較兩個檢查碼
 *
 * @param {string} firstValue 第一個值
 * @param {string} secondValue 第二個值
 * @return {boolean}
 */
function safeCompareMacValue(
    firstValue,
    secondValue,
) {
  const normalizedFirstValue = normalizeString(
      firstValue,
  ).toUpperCase();

  const normalizedSecondValue = normalizeString(
      secondValue,
  ).toUpperCase();

  if (
    !normalizedFirstValue ||
    !normalizedSecondValue
  ) {
    return false;
  }

  const firstBuffer = Buffer.from(
      normalizedFirstValue,
      "utf8",
  );

  const secondBuffer = Buffer.from(
      normalizedSecondValue,
      "utf8",
  );

  if (firstBuffer.length !== secondBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(
      firstBuffer,
      secondBuffer,
  );
}

/**
 * 驗證綠界回傳的 CheckMacValue
 *
 * @param {Object} params 參數
 * @param {Object} params.data 綠界回傳資料
 * @param {string} params.hashKey 綠界 HashKey
 * @param {string} params.hashIv 綠界 HashIV
 * @return {boolean}
 */
function verifyCheckMacValue({
  data,
  hashKey,
  hashIv,
}) {
  const receivedCheckMacValue = normalizeString(
      data && data.CheckMacValue,
  );

  if (!receivedCheckMacValue) {
    return false;
  }

  const calculatedCheckMacValue = createCheckMacValue({
    data,
    hashKey,
    hashIv,
  });

  return safeCompareMacValue(
      receivedCheckMacValue,
      calculatedCheckMacValue,
  );
}

module.exports = {
  normalizeMacValue,
  ecpayUrlEncode,
  createMacRawValue,
  createCheckMacValue,
  safeCompareMacValue,
  verifyCheckMacValue,
};
