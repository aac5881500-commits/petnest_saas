// 檔案名稱：functions/legal_pet/profile_lock.js
// 功能說明：電話與地址首次設定分開鎖定，既有資料保守視為已完成。

const {text} = require("./normalize");
const {TAIWAN_PLACES} = require("./taiwan_places");

/**
 * @param {Object} shop 店家資料
 * @return {boolean}
 */
function isAddressLocked(shop) {
  const data = shop || {};
  if (data.addressSetupCompleted === true) {
    return true;
  }
  return text(data.address).length > 0;
}

/**
 * @param {Object} shop 店家資料
 * @return {boolean}
 */
function isPhoneLocked(shop) {
  const data = shop || {};
  if (data.phoneSetupCompleted === true) {
    return true;
  }
  return text(data.phone).length > 0;
}

/**
 * 只寫入本次首次設定的電話或地址，不改店名、統編、認證。
 * @param {Object} input 目前店家與表單
 * @return {{error: string, patch: Object}}
 */
function buildInitialProfilePlan(input) {
  const shop = input.shop || {};
  const patch = {};
  const addressProvided = input.city !== undefined ||
    input.district !== undefined ||
    input.address !== undefined;
  if (addressProvided) {
    if (isAddressLocked(shop)) {
      return {error: "地址已完成首次設定，請改走重要資料修改申請", patch: {}};
    }
    const city = text(input.city);
    const district = text(input.district);
    const address = text(input.address);
    const districts = TAIWAN_PLACES[city];
    if (!districts || districts.indexOf(district) < 0 || !address) {
      return {error: "縣市、區域或地址無法可靠儲存", patch: {}};
    }
    patch.city = city;
    patch.district = district;
    patch.address = address;
    patch.addressSetupCompleted = true;
  }
  if (input.phone !== undefined) {
    const phone = text(input.phone);
    if (isPhoneLocked(shop) && phone !== text(shop.phone)) {
      return {error: "電話已完成首次設定，請改走重要資料修改申請", patch: {}};
    }
    if (!isPhoneLocked(shop) && phone) {
      patch.phone = phone;
      patch.phoneSetupCompleted = true;
    }
  }
  const forbidden = [
    "name",
    "taxId",
    "licenseNumber",
    "licenseVerified",
    "taxIdVerified",
    "isPublic",
  ];
  forbidden.forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(patch, key)) {
      delete patch[key];
    }
  });
  return {error: "", patch: patch};
}

/**
 * @param {*} value 時間戳或測試用標記
 * @return {string}
 */
function stampKey(value) {
  if (value === undefined || value === null || value === "") {
    return "";
  }
  if (typeof value.toMillis === "function") {
    return String(value.toMillis());
  }
  return String(value);
}

/**
 * 字號或地址已變，且這次寫入沒有重新核准時，清掉舊認證。
 * @param {Object} before 變更前
 * @param {Object} after 變更後
 * @return {Object} clearLicense、previousLicense、nextLicense
 */
function guardShopCertification(before, after) {
  const previous = before || {};
  const next = after || {};
  const previousLicense = text(previous.licenseNumber);
  const nextLicense = text(next.licenseNumber);
  const licenseChanged = previousLicense !== nextLicense;
  const placeChanged = text(previous.city) !== text(next.city) ||
    text(previous.district) !== text(next.district) ||
    text(previous.address) !== text(next.address);
  const stayedVerified = previous.licenseVerified === true &&
    next.licenseVerified === true;
  const refreshed = stampKey(next.licenseCertifiedAt) !== "" &&
    stampKey(next.licenseCertifiedAt) !== stampKey(previous.licenseCertifiedAt);
  return {
    clearLicense: stayedVerified &&
      (licenseChanged || placeChanged) &&
      !refreshed,
    previousLicense: previousLicense,
    nextLicense: nextLicense,
  };
}

module.exports = {
  isAddressLocked,
  isPhoneLocked,
  buildInitialProfilePlan,
  guardShopCertification,
};
