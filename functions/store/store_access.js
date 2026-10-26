"use strict";

const {
  resolvePlanSchedule, taipeiDateKey,
} = require("../sales/commercial_policy");

/**
 * 商城沿用平台已確認的方案與可用期限，不依賴 enabledModules。
 * @param {Object} shop 店家
 * @param {Date=} now 目前時間
 * @return {boolean} 可用資格
 */
function hasStoreEntitlement(shop, now = new Date()) {
  if (!shop || shop.deletionState === "deleting") return false;
  const today = taipeiDateKey(now);
  const plan = resolvePlanSchedule(shop, today).effectivePlan;
  if (plan !== "basic" && plan !== "pro") return false;
  if (typeof shop.paidUntilDate === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(shop.paidUntilDate)) {
    return shop.paidUntilDate >= today;
  }
  const until = shop.paidUntil;
  const end = until && typeof until.toDate === "function" ?
    until.toDate() : until instanceof Date ? until : null;
  return end !== null && end.getTime() > now.getTime();
}

/**
 * 保留既有商城狀態；未設定的新商城預設準備中。
 * @param {Object} settings 商城設定
 * @return {string} 營業狀態
 */
function storeBusinessStatus(settings) {
  const statuses = ["preparing", "open", "paused"];
  if (settings && statuses.includes(settings.businessStatus)) {
    return settings.businessStatus;
  }
  if (!settings || (!Object.hasOwn(settings, "storefrontEnabled") &&
      !Object.hasOwn(settings, "acceptNewOrders")) ||
      settings.storefrontEnabled === false) return "preparing";
  return settings.acceptNewOrders === false ? "paused" : "open";
}

/**
 * @param {Object} shop 店家
 * @param {Object} settings 商城設定
 * @param {Date=} now 目前時間
 * @return {boolean} 能否建立新訂單
 */
function canAcceptStoreOrders(shop, settings, now = new Date()) {
  return hasStoreEntitlement(shop, now) && !!settings &&
    settings.storefrontEnabled !== false &&
    settings.acceptNewOrders !== false &&
    storeBusinessStatus(settings) === "open";
}

module.exports = {
  hasStoreEntitlement, storeBusinessStatus, canAcceptStoreOrders,
};
