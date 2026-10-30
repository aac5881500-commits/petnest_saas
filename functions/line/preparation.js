/* eslint-disable max-len, require-jsdoc */
"use strict";
const {HttpsError} = require("firebase-functions/v2/https");
const USES = ["booking", "personal", "promotion"];
function normalizePreparation(raw) {
  const allowed = ["displayName", "officialAccountId", "channelId", "requestedUses"];
  if (!raw || typeof raw !== "object" || Array.isArray(raw) || Object.keys(raw).some((key) => !allowed.includes(key))) {
    throw new HttpsError("invalid-argument", "這裡只接受非機密準備資料，請勿填入 Token、Secret 或啟用參數。");
  }
  const text = (key, max) => {
    if (raw[key] != null && typeof raw[key] !== "string") throw new HttpsError("invalid-argument", "準備資料格式不正確。");
    const value = (raw[key] || "").trim();
    if (value.length > max) throw new HttpsError("invalid-argument", "準備資料長度超過限制。");
    return value;
  };
  const displayName = text("displayName", 80);
  const officialAccountId = text("officialAccountId", 65);
  const channelId = text("channelId", 20);
  if (officialAccountId && !/^@[A-Za-z0-9_.-]{1,64}$/.test(officialAccountId)) throw new HttpsError("invalid-argument", "官方帳號 ID 請使用 @ 開頭的公開 ID。");
  if (channelId && !/^\d{5,20}$/.test(channelId)) throw new HttpsError("invalid-argument", "Messaging API Channel ID 請填數字，勿填存取權杖。");
  const requestedUses = raw.requestedUses == null ? ["booking"] : raw.requestedUses;
  if (!Array.isArray(requestedUses) || requestedUses.some((use) => !USES.includes(use))) throw new HttpsError("invalid-argument", "請選擇有效的預計用途。");
  return {displayName, officialAccountId, channelId, requestedUses: [...new Set(requestedUses)].sort()};
}
function preparationStatus(record = {}) {
  const configuration = {
    displayName: typeof record.displayName === "string" ? record.displayName : "",
    officialAccountId: typeof record.officialAccountId === "string" ? record.officialAccountId : "",
    channelId: typeof record.channelId === "string" ? record.channelId : "",
    requestedUses: Array.isArray(record.requestedUses) ? record.requestedUses.filter((use) => USES.includes(use)) : ["booking"],
  };
  return {schemaVersion: 1, phase: "preparation_only", configuration,
    version: Number.isInteger(record.version) ? record.version : 0,
    // Owner-entered public ids are never proof of credentials, entitlement or binding.
    ready: false, sendingEnabled: false, billingActivated: false,
    accountDetailsSaved: !!(configuration.officialAccountId && configuration.channelId),
    credentialsVerified: false, webhookVerified: false, memberLinkingReady: false,
    billingResponsibility: "shop", accountMode: "shop_owned"};
}
function assertLineSendingEnabled() {
  throw new HttpsError("failed-precondition", "LINE 目前僅完成前置準備，尚未開通發送；App 與手機提醒可照常使用。");
}
module.exports = {normalizePreparation, preparationStatus, assertLineSendingEnabled};
