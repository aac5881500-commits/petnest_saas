/* eslint-disable require-jsdoc */
// 檔案名稱：functions/daily_care/quote_daily_care.js
// 功能說明：後端重算照護加購報價，供住宿下單與付款前核對。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {normalizeString, parseBool, toInt} =
  require("../daycare/daycare_utils");
const {resolveDailyCareEntitlement} = require("./daily_care_entitlement");

async function quoteDailyCare(params) {
  const firestore = admin.firestore();
  const shopSnap = await firestore.collection("shops").doc(params.shopId).get();
  if (!shopSnap.exists) {
    throw new HttpsError("not-found", "找不到店家");
  }
  const shop = shopSnap.data() || {};
  const setting = shop.dailyCareSetting || {};
  return resolveDailyCareEntitlement({
    setting,
    isDaycare: params.isDaycare === true,
    shopDaycareOn: parseBool(shop.daycareEnabled, true),
    offerId: params.offerId,
    offerName: params.offerName,
    nights: toInt(params.nights, 1),
    addonId: params.addonId,
    startDate: params.startDate,
    endDate: params.endDate,
  });
}

exports.quoteDailyCareAddon = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const data = request.data || {};
      const shopId = normalizeString(data.shopId);
      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家");
      }
      const quoted = await quoteDailyCare({
        shopId,
        isDaycare: data.isDaycare === true,
        offerId: normalizeString(data.offerId),
        offerName: normalizeString(data.offerName),
        nights: toInt(data.nights, 1),
        addonId: normalizeString(data.addonId),
        startDate: data.startDate,
        endDate: data.endDate,
      });
      return {ok: true, ...quoted};
    },
);

exports.quoteDailyCare = quoteDailyCare;
