// 檔案名稱：functions/legal_pet/codes.js
// 功能說明：農業部介接說明書 MOAOPD-API-EIR643 v1.0 的代碼對照。
// 來源：農業部 OpenData API 介接說明書-EIR643合法特定寵物業名單-v1.0.pdf
// 發行日期 2023/08/01。未列在這份對照表的代碼不得自行解釋。

const CODEBOOK = "MOAOPD-API-EIR643 v1.0";

const COUNTY_CODES = {
  A010: "臺北市",
  A020: "新北市",
  A030: "基隆市",
  A040: "高雄市",
  A060: "臺中市",
  A090: "桃園市",
  A100: "新竹市",
  A110: "新竹縣",
  A130: "苗栗縣",
  A150: "南投縣",
  A170: "彰化縣",
  A180: "雲林縣",
  A190: "嘉義市",
  A200: "嘉義縣",
  A210: "臺南市",
  A240: "屏東縣",
  A260: "宜蘭縣",
  A280: "花蓮縣",
  A300: "臺東縣",
  A310: "澎湖縣",
  A320: "金門縣",
  A330: "連江縣",
};

const BUS_ITEM_CODES = {
  A: "繁殖",
  B: "買賣",
  C: "寄養",
};

const STATE_CODES = {
  N: "營業中",
  P: "歇業",
  S: "停業",
  B: "廢止",
};

const RANK_CODES = {
  A: "優等",
  B: "甲等",
  C: "乙等",
  D: "丙等",
};

const FLAG_CODES = {
  Y: "確認",
  N: "未確認",
};

/**
 * 把單一代碼譯成顯示文字。對照表沒有的值保留原碼並標示待確認。
 * @param {Object<string, string>} table 官方對照表
 * @param {*} raw 原始代碼
 * @return {{raw: string, label: string, confirmed: boolean}}
 */
function describeCode(table, raw) {
  const value = raw === null || raw === undefined ? "" : String(raw).trim();
  if (!value) {
    return {raw: "", label: "待確認", confirmed: false};
  }
  if (Object.prototype.hasOwnProperty.call(table, value)) {
    return {raw: value, label: table[value], confirmed: true};
  }
  return {raw: value, label: value + "（待確認）", confirmed: false};
}

/**
 * 營業項目可為 A、B、C 的組合，依原文字順序逐碼解釋。
 * @param {*} raw 原始 busitem
 * @return {Object} raw、label、confirmed 與已確認的 A／B／C 旗標
 */
function describeBusItem(raw) {
  const value = raw === null || raw === undefined ? "" : String(raw).trim();
  if (!value) {
    return {
      raw: "",
      label: "待確認",
      confirmed: false,
      hasBreeding: false,
      hasSale: false,
      hasBoarding: false,
    };
  }
  const parts = [];
  let confirmed = true;
  for (const char of value) {
    if (Object.prototype.hasOwnProperty.call(BUS_ITEM_CODES, char)) {
      parts.push(BUS_ITEM_CODES[char]);
    } else {
      confirmed = false;
      parts.push(char + "（待確認）");
    }
  }
  return {
    raw: value,
    label: parts.join("、"),
    confirmed: confirmed,
    hasBreeding: confirmed && value.indexOf("A") >= 0,
    hasSale: confirmed && value.indexOf("B") >= 0,
    hasBoarding: confirmed && value.indexOf("C") >= 0,
  };
}

module.exports = {
  CODEBOOK,
  COUNTY_CODES,
  BUS_ITEM_CODES,
  STATE_CODES,
  RANK_CODES,
  FLAG_CODES,
  describeCode,
  describeBusItem,
};
