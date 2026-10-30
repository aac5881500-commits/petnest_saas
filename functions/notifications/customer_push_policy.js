/* eslint-disable max-len */
"use strict";
/**
 * Only system transactional/important notices bypass optional preferences.
 * Shop overrides can further mute a category but never override a global mute.
 * @param {Object} classified Trusted notification classification.
 * @param {Object} settings Global settings including per-shop overrides.
 * @param {string} shopId Source shop id.
 * @return {boolean} Whether to attempt FCM delivery.
 */
function customerPushAllowed(classified, settings, shopId = "") {
  const setting = settings || {};
  const category = classified.category;
  const shopCategory = category === "shop_notice" || category === "shop_marketing";
  if ((classified.isMandatory && !shopCategory) || category === "transactional" || category === "platform_important") return true;
  if (setting.enabled === false) return false;
  const key = {shop_notice: "shopNotice", shop_marketing: "shopMarketing", platform_marketing: "platformMarketing"}[category];
  if (!key) return true;
  if (setting[key] === false) return false;
  const overrides = setting.shopOverrides || {};
  const local = shopCategory && Object.prototype.hasOwnProperty.call(overrides, shopId) ? overrides[shopId] : null;
  return !local || local[key] !== false;
}
module.exports = {customerPushAllowed};
