// 檔案名稱：functions/legal_pet/directory_places.js
// 功能說明：業者資料庫用的官方縣市區域。含 App 選單沒有的基隆市、新竹市。
// 只在地址開頭能對上時採用，對不上就標區域待確認。

const {COUNTY_CODES} = require("./codes");
const {TAIWAN_PLACES} = require("./taiwan_places");

// 內政部現行之區，僅補 App 縣市清單沒有的兩個市。不從店名或路名推測。
const EXTRA_OFFICIAL_DISTRICTS = {
  "基隆市": ["仁愛區", "信義區", "中正區", "中山區", "安樂區", "暖暖區", "七堵區"],
  "新竹市": ["東區", "北區", "香山區"],
};

/**
 * @return {Object<string, string[]>} 官方縣市名對區域
 */
function officialDistrictsByName() {
  const map = {};
  Object.keys(TAIWAN_PLACES).forEach((city) => {
    const official = city.replace(/台/g, "臺");
    map[official] = TAIWAN_PLACES[city].map((district) => {
      return district.replace(/台/g, "臺");
    });
  });
  Object.keys(EXTRA_OFFICIAL_DISTRICTS).forEach((city) => {
    map[city] = EXTRA_OFFICIAL_DISTRICTS[city].slice();
  });
  return map;
}

/**
 * @return {Object<string, string[]>} 縣市代碼對區域
 */
function districtsByCountyCode() {
  const byName = officialDistrictsByName();
  const result = {};
  Object.keys(COUNTY_CODES).forEach((code) => {
    result[code] = (byName[COUNTY_CODES[code]] || []).slice();
  });
  return result;
}

module.exports = {
  EXTRA_OFFICIAL_DISTRICTS,
  officialDistrictsByName,
  districtsByCountyCode,
};
