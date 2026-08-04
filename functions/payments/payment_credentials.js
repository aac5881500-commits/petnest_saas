// functions/payments/payment_credentials.js
// 🔐 綠界後端密鑰讀取工具
// 功能：從 payment_credentials/{shopId} 讀取綠界 MerchantID、
// HashKey、HashIV 與環境設定，避免敏感資料放在公開店家文件中。

const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 讀取店家綠界後端密鑰
 *
 * Firestore 路徑：
 * payment_credentials/{shopId}
 *
 * 預期欄位：
 * merchantId
 * hashKey
 * hashIv
 * environment：test 或 production
 *
 * @param {string} shopId 店家 ID
 * @return {Promise<Object>}
 */
async function getEcpayCredentials(shopId) {
  const normalizedShopId = normalizeString(shopId);

  if (!normalizedShopId) {
    throw new HttpsError(
        "invalid-argument",
        "缺少店家編號。",
    );
  }

  const credentialsSnapshot = await admin
      .firestore()
      .collection("payment_credentials")
      .doc(normalizedShopId)
      .get();

  if (!credentialsSnapshot.exists) {
    throw new HttpsError(
        "failed-precondition",
        "店家尚未建立綠界後端金流憑證。",
    );
  }

  const credentials = credentialsSnapshot.data() || {};

  const merchantId = normalizeString(
      credentials.merchantId,
  );

  const hashKey = normalizeString(
      credentials.hashKey,
  );

  const hashIv = normalizeString(
      credentials.hashIv,
  );

  const environment = normalizeString(
      credentials.environment,
  ).toLowerCase();

  if (!merchantId) {
    throw new HttpsError(
        "failed-precondition",
        "店家缺少綠界 MerchantID。",
    );
  }

  if (!hashKey) {
    throw new HttpsError(
        "failed-precondition",
        "店家缺少綠界 HashKey。",
    );
  }

  if (!hashIv) {
    throw new HttpsError(
        "failed-precondition",
        "店家缺少綠界 HashIV。",
    );
  }

  if (
    environment !== "test" &&
    environment !== "production"
  ) {
    throw new HttpsError(
        "failed-precondition",
        "綠界環境設定必須是 test 或 production。",
    );
  }

  return {
    credentialsRef: credentialsSnapshot.ref,
    shopId: normalizedShopId,
    merchantId,
    hashKey,
    hashIv,
    environment,
    isProduction: environment === "production",
  };
}

module.exports = {
  getEcpayCredentials,
};
