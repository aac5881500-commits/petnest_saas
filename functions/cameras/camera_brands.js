// 檔案名稱：functions/cameras/camera_brands.js
// 功能說明：外部攝影機品牌目錄。第一版只開放小米／米家，未知品牌不當成小米。

const XIAOMI = "xiaomi";

const brands = {
  xiaomi: {
    id: XIAOMI,
    label: "小米／米家",
    appName: "米家",
    released: true,
    accountShare: true,
    accountLabel: "米家帳號",
    accountHint:
      "可填手機號碼、Email 或小米帳號。實際格式以米家分享畫面為準，不代表所有型號相同。",
    searchName: "米家",
    androidStoreUrl:
      "https://play.google.com/store/apps/details?id=com.xiaomi.smarthome",
    iosStoreUrl: "",
    launchSupported: false,
    guide: [
      "安裝並登入要接受分享的米家帳號。",
      "在 PetNest 填寫該帳號，不要填密碼。",
      "店家到米家手動分享設備。",
      "顧客在米家接受邀請。PetNest 只記錄處理狀態。",
    ],
  },
};

/**
 * @param {*} providerId 品牌
 * @return {Object|null}
 */
function brandById(providerId) {
  const id = String(providerId || "").trim();
  const brand = brands[id];
  if (!brand || brand.released !== true) {
    return null;
  }
  return brand;
}

/**
 * @return {Array<Object>}
 */
function releasedBrands() {
  return Object.keys(brands)
      .map((id) => brands[id])
      .filter((brand) => brand.released === true);
}

/**
 * @param {*} providerId 品牌
 * @return {boolean}
 */
function brandSupportsAccountShare(providerId) {
  const brand = brandById(providerId);
  return Boolean(brand && brand.accountShare === true);
}

/**
 * @param {*} providerId 品牌
 * @param {*} raw 帳號
 * @return {boolean}
 */
function plausibleBrandAccount(providerId, raw) {
  const brand = brandById(providerId);
  if (!brand || brand.accountShare !== true) {
    return false;
  }
  if (brand.id === XIAOMI) {
    return plausibleXiaomiAccount(raw);
  }
  return false;
}

/**
 * @param {*} raw 帳號
 * @return {boolean}
 */
function plausibleXiaomiAccount(raw) {
  const value = String(raw || "").trim();
  if (value.length < 3 || value.length > 80) {
    return false;
  }
  if (/\s/.test(value)) {
    return false;
  }
  return /^[0-9A-Za-z@.+_-]+$/.test(value);
}

/**
 * @param {*} providerId 品牌
 * @return {string}
 */
function brandLabel(providerId) {
  const brand = brandById(providerId);
  return brand ? brand.label : "";
}

module.exports = {
  XIAOMI,
  brandById,
  releasedBrands,
  brandSupportsAccountShare,
  plausibleBrandAccount,
  plausibleXiaomiAccount,
  brandLabel,
};
