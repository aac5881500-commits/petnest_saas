"use strict";
/**
 * Validate a shop-confirmed location without running paid geocoding.
 * @param {Object} data Callable input.
 * @return {Object|null} Validated point or deletion request.
 */
function locationInput(data) {
  if (data.remove === true) return null;
  const lat = data.latitude;
  const lng = data.longitude;
  if (typeof lat !== "number" || typeof lng !== "number" ||
      !Number.isFinite(lat) || !Number.isFinite(lng) ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180 ||
      data.confirmed !== true) {
    throw new Error("請確認有效的緯度與經度");
  }
  return {latitude: lat, longitude: lng, confirmed: true,
    source: "owner_confirmed"};
}
module.exports = {locationInput};
