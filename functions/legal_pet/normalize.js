// 檔案名稱：functions/legal_pet/normalize.js
// 功能說明：字號、純日期、地址比對與政府紀錄正規化。
// 日期只取來源字串上的年月日，不經過 UTC 轉換。

const crypto = require("crypto");
const {
  CODEBOOK,
  COUNTY_CODES,
  STATE_CODES,
  RANK_CODES,
  FLAG_CODES,
  describeCode,
  describeBusItem,
} = require("./codes");
const {TAIWAN_PLACES} = require("./taiwan_places");

const PUNCTUATION = /[，,。．.、·・\-－—~～()（）[\]「」『』#＃/／]/g;

/**
 * @param {*} value 原始值
 * @return {string}
 */
function text(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value).trim();
}

/**
 * 空白、全形英數與大小寫正規化。保留中文及可區分證照的內容。
 * @param {*} value 原始字號
 * @return {string}
 */
function normalizeLicense(value) {
  const folded = text(value).normalize("NFKC");
  return folded.replace(/\s+/g, "").toUpperCase();
}

const LOOKUP_KEY_VERSION = 1;
const STANDARD_PREFIX = "特寵業字第";
const BREEDING_PREFIX = "特寵業繁字第";
const LICENSE_CORE = /^[A-Z]{1,2}[0-9]{7}(?:-[0-9]{2})?$/;

/**
 * 查核用折疊。NFKC、去空白、英文大寫。不刪中文。
 * @param {*} value 原始字號
 * @return {string}
 */
function foldLicenseText(value) {
  return text(value).normalize("NFKC").replace(/[\s\u3000]+/g, "")
      .toUpperCase();
}

/**
 * @param {boolean} ok 是否可做成查核鍵
 * @param {string} kind standard、breeding、unrecognized 或 invalid
 * @param {string} key 查核鍵
 * @param {string} core 英數核心
 * @param {string} reason 失敗原因
 * @return {Object}
 */
function lookupResult(ok, kind, key, core, reason) {
  return {
    ok: ok,
    kind: kind,
    key: key,
    core: core,
    reason: reason,
  };
}

/**
 * 政府字號與客戶輸入共用。只拿掉明確前綴與末尾一個「號」。
 * 繁字與一般字號分開，無法辨識時不猜成同一證照。
 * @param {*} value 原始字號
 * @return {Object}
 */
function parseLicenseLookup(value) {
  const folded = foldLicenseText(value);
  if (!folded) {
    return lookupResult(false, "invalid", "", "", "empty");
  }
  let body = folded;
  let prefixed = "";
  if (body.indexOf(BREEDING_PREFIX) === 0) {
    body = body.slice(BREEDING_PREFIX.length);
    prefixed = "breeding";
  } else if (body.indexOf(STANDARD_PREFIX) === 0) {
    body = body.slice(STANDARD_PREFIX.length);
    prefixed = "standard";
  }
  if (body.slice(-1) === "號") {
    body = body.slice(0, -1);
  }
  if (!prefixed && /[\u3400-\u9FFF]/.test(body)) {
    return lookupResult(
        false,
        "unrecognized",
        "",
        "",
        "unrecognized_prefix",
    );
  }
  const extraCjk = /[\u3400-\u9FFF]/.test(body);
  if (body.indexOf("號") >= 0 || extraCjk || !LICENSE_CORE.test(body)) {
    const kind = prefixed === "breeding" ? "breeding" : "invalid";
    return lookupResult(false, kind, "", "", "invalid_format");
  }
  if (prefixed === "breeding") {
    return lookupResult(true, "breeding", "繁字:" + body, body, "");
  }
  return lookupResult(true, "standard", body, body, "");
}

/**
 * 查核欄位的來源字串。只讀 validnum，沒有時才用既有正規化字號當解析輸入。
 * @param {Object} row 政府文件
 * @return {string}
 */
function licenseLookupSource(row) {
  const data = row || {};
  if (text(data.validnum)) {
    return text(data.validnum);
  }
  return text(data.normalizedLicense);
}

/**
 * 只含查核衍生欄位。不覆寫 validnum、normalizedLicense 或綁定。
 * @param {Object} row 政府文件
 * @return {Object}
 */
function licenseLookupFields(row) {
  const parsed = parseLicenseLookup(licenseLookupSource(row));
  return {
    licenseLookupKey: parsed.ok ? parsed.key : "",
    licenseLookupKind: parsed.kind,
    licenseLookupVersion: LOOKUP_KEY_VERSION,
  };
}

/**
 * 衍生欄位已是目前版本且內容相同才跳過。
 * @param {Object} row 既有文件
 * @param {Object} patch 預計寫入
 * @return {boolean}
 */
function licenseLookupCurrent(row, patch) {
  const data = row || {};
  const next = patch || {};
  const version = Number(data.licenseLookupVersion) || 0;
  return version >= LOOKUP_KEY_VERSION &&
    text(data.licenseLookupKey) === text(next.licenseLookupKey) &&
    text(data.licenseLookupKind) === text(next.licenseLookupKind);
}

/**
 * @param {Object[]} rows 含 id 的政府文件
 * @return {{updates: Object[], skipped: number}}
 */
function selectLicenseLookupWrites(rows) {
  const updates = [];
  let skipped = 0;
  (Array.isArray(rows) ? rows : []).forEach((row) => {
    const patch = licenseLookupFields(row);
    if (licenseLookupCurrent(row, patch)) {
      skipped += 1;
      return;
    }
    updates.push({
      id: text(row && row.id),
      patch: patch,
    });
  });
  return {updates: updates, skipped: skipped};
}

/**
 * 寫入失敗不可標完成。未到最後一頁只記游標。
 * @param {Object} input 這一批結果
 * @return {{saveCursor: boolean, markReady: boolean, failed: boolean}}
 */
function planLookupBackfillResult(input) {
  const data = input || {};
  if (data.writeFailed === true) {
    return {saveCursor: false, markReady: false, failed: true};
  }
  if (data.done !== true) {
    return {saveCursor: true, markReady: false, failed: false};
  }
  if (data.canFinish !== true) {
    return {saveCursor: false, markReady: false, failed: false};
  }
  return {saveCursor: false, markReady: true, failed: false};
}

/**
 * 決定要不要查詢。資料未補齊與格式不符都不當成查無。
 * @param {Object} input 字號、版本與相符筆數
 * @return {Object}
 */
function lookupStatusFor(input) {
  const data = input || {};
  const parsed = data.parsed || parseLicenseLookup(data.license);
  if (!parsed.ok || parsed.kind !== "standard") {
    return {
      status: "invalid",
      key: "",
      shouldQuery: false,
      reason: parsed.reason || parsed.kind,
    };
  }
  const version = Number(data.licenseLookupVersion) || 0;
  if (version < LOOKUP_KEY_VERSION) {
    return {
      status: "incomplete",
      key: parsed.key,
      shouldQuery: false,
      reason: "not_backfilled",
    };
  }
  if (data.sourceFailed === true) {
    return {
      status: "unavailable",
      key: parsed.key,
      shouldQuery: false,
      reason: "source_failed",
    };
  }
  return {
    status: classifyLookup({
      sync: data.sync || {},
      matchCount: data.matchCount || 0,
      licenseStatus: data.licenseStatus || "",
      nowMs: data.nowMs,
    }),
    key: parsed.key,
    shouldQuery: true,
    reason: "",
  };
}

/**
 * 多筆相符時不取第一筆。有指定 govId 才選那一筆。
 * @param {Object[]} records 查核結果
 * @param {string} governmentId 客戶指定的政府文件
 * @return {Object}
 */
function chooseGovernmentRecord(records, governmentId) {
  const list = Array.isArray(records) ? records : [];
  const wanted = text(governmentId);
  if (wanted) {
    for (let index = 0; index < list.length; index += 1) {
      if (text(list[index].govId) === wanted) {
        return {chosen: list[index], error: ""};
      }
    }
    if (list.length > 1) {
      return {
        chosen: null,
        error: "請選擇本次查到的其中一筆政府資料",
      };
    }
    return {chosen: null, error: ""};
  }
  if (list.length === 1) {
    return {chosen: list[0], error: ""};
  }
  return {chosen: null, error: ""};
}

/**
 * @param {Date} date 時間點
 * @return {string} 台北日曆日 YYYY-MM-DD
 */
function taipeiDateKey(date) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

/**
 * 由來源字串取出純日期。無法辨識時不猜測。
 * @param {*} value 政府有效日期
 * @return {{date: string, confirmed: boolean}}
 */
function parseSourceDate(value) {
  const source = text(value);
  const iso = source.match(/^(\d{4})-(\d{2})-(\d{2})/);
  const slash = source.match(/^(\d{4})\/(\d{1,2})\/(\d{1,2})/);
  const match = iso || slash;
  if (!match) {
    return {date: "", confirmed: false};
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const probe = new Date(Date.UTC(year, month - 1, day));
  const valid = probe.getUTCFullYear() === year &&
    probe.getUTCMonth() === month - 1 &&
    probe.getUTCDate() === day;
  if (!valid) {
    return {date: "", confirmed: false};
  }
  const monthText = String(month).padStart(2, "0");
  const dayText = String(day).padStart(2, "0");
  return {date: year + "-" + monthText + "-" + dayText, confirmed: true};
}

/**
 * @param {string} value 地址片段
 * @return {string}
 */
function normalizeAddressText(value) {
  return text(value)
      .normalize("NFKC")
      .replace(/\s+/g, "")
      .replace(/台/g, "臺")
      .replace(PUNCTUATION, "");
}

/**
 * 官方縣市名對到 App 下拉用的寫法。對不到就不套用。
 * @param {string} officialName 官方縣市名
 * @return {string}
 */
function toAppCity(officialName) {
  const folded = text(officialName).replace(/臺/g, "台");
  if (Object.prototype.hasOwnProperty.call(TAIWAN_PLACES, folded)) {
    return folded;
  }
  return "";
}

/**
 * 只有縣市、區域都能對上 App 清單時才視為可套用。
 * @param {string} rawAddress 政府地址
 * @param {string} countyCode 官方縣市代碼
 * @return {Object}
 */
function parseGovernmentAddress(rawAddress, countyCode) {
  const raw = text(rawAddress);
  const county = describeCode(COUNTY_CODES, countyCode);
  const expectedCity = county.confirmed ? toAppCity(county.label) : "";
  const folded = raw.replace(/\s+/g, "").replace(/臺/g, "台");
  if (!folded) {
    return {reliable: false, city: "", district: "", detail: "", raw: raw};
  }
  const cities = Object.keys(TAIWAN_PLACES).sort((a, b) => {
    return b.length - a.length;
  });
  let city = "";
  for (const name of cities) {
    if (folded.indexOf(name) === 0) {
      city = name;
      break;
    }
  }
  if (!city || (expectedCity && city !== expectedCity)) {
    return {reliable: false, city: "", district: "", detail: "", raw: raw};
  }
  let rest = folded.slice(city.length);
  if (rest.indexOf(city) === 0) {
    rest = rest.slice(city.length);
  }
  const districts = TAIWAN_PLACES[city].slice().sort((a, b) => {
    return b.length - a.length;
  });
  let district = "";
  for (const name of districts) {
    if (rest.indexOf(name) === 0) {
      district = name;
      break;
    }
  }
  if (!district) {
    return {reliable: false, city: "", district: "", detail: "", raw: raw};
  }
  rest = rest.slice(district.length);
  const repeated = city + district;
  if (rest.indexOf(repeated) === 0) {
    rest = rest.slice(repeated.length);
  } else if (rest.indexOf(city) === 0) {
    rest = rest.slice(city.length);
  }
  if (!rest) {
    return {reliable: false, city: "", district: "", detail: "", raw: raw};
  }
  return {
    reliable: true,
    city: city,
    district: district,
    detail: rest,
    raw: raw,
  };
}

/**
 * @param {Object} shop 店家縣市、區域、地址
 * @param {string} governmentAddress 政府地址
 * @param {string} countyCode 官方縣市代碼
 * @return {{result: string}}
 */
function compareAddress(shop, governmentAddress, countyCode) {
  const city = text(shop && shop.city);
  const district = text(shop && shop.district);
  const address = text(shop && shop.address);
  const government = text(governmentAddress);
  if (!city || !district || !address || !government) {
    return {result: "manual"};
  }
  const full = normalizeAddressText(city + district + address);
  const detailOnly = normalizeAddressText(address);
  const gov = normalizeAddressText(government);
  if (full === gov || detailOnly === gov) {
    return {result: "match"};
  }
  const parsed = parseGovernmentAddress(government, countyCode);
  if (!parsed.reliable) {
    return {result: "manual"};
  }
  const shopCity = normalizeAddressText(city);
  const govCity = normalizeAddressText(parsed.city);
  const shopDistrict = normalizeAddressText(district);
  const govDistrict = normalizeAddressText(parsed.district);
  let shopDetail = address.replace(/\s+/g, "").replace(/臺/g, "台");
  const prefix = city.replace(/臺/g, "台") + district;
  if (shopDetail.indexOf(prefix) === 0) {
    shopDetail = shopDetail.slice(prefix.length);
  }
  const sameDetail = normalizeAddressText(shopDetail) ===
    normalizeAddressText(parsed.detail);
  if (shopCity === govCity && shopDistrict === govDistrict && sameDetail) {
    return {result: "match"};
  }
  return {result: "mismatch"};
}

/**
 * 寵物種類沒有 EIR643 代碼表。原文含貓或狗才做篩選，其餘不推測。
 * @param {*} raw 原始 animaltype
 * @return {Object}
 */
function describeAnimal(raw) {
  const value = text(raw);
  if (!value) {
    return {
      raw: "",
      label: "待確認",
      confirmed: false,
      hasCat: false,
      hasDog: false,
    };
  }
  return {
    raw: value,
    label: value,
    confirmed: true,
    hasCat: value.indexOf("貓") >= 0,
    hasDog: value.indexOf("狗") >= 0,
  };
}

/**
 * @param {Object} input 狀態與日期
 * @return {string}
 */
function licenseStatusOf(input) {
  if (!input.stateConfirmed) {
    return "unknown";
  }
  if (input.stateFlag === "P") {
    return "closed";
  }
  if (input.stateFlag === "S") {
    return "suspended";
  }
  if (input.stateFlag === "B") {
    return "revoked";
  }
  if (input.stateFlag !== "N") {
    return "unknown";
  }
  if (!input.validDateConfirmed) {
    return "unknown";
  }
  if (input.validDate < input.today) {
    return "expired";
  }
  return "operating";
}

/**
 * @param {*} rawId 政府 ID
 * @return {string}
 */
function governmentDocId(rawId) {
  const value = text(rawId).replace(/\//g, "_");
  return value;
}

/**
 * @param {Object} row 政府原始列
 * @param {string} today 台北今日
 * @return {Object}
 */
function buildGovernmentRecord(row, today) {
  const source = row || {};
  const govId = governmentDocId(source.ID);
  const county = describeCode(COUNTY_CODES, source.legaltype);
  const bus = describeBusItem(source.busitem);
  const animal = describeAnimal(source.animaltype);
  const state = describeCode(STATE_CODES, source.state_flag);
  const rank = describeCode(RANK_CODES, source.rank_code);
  const rankFlag1 = describeCode(FLAG_CODES, source.rank_flag_1);
  const rankFlag2 = describeCode(FLAG_CODES, source.rank_flag_2);
  const valid = parseSourceDate(source.validdate);
  const status = licenseStatusOf({
    stateFlag: state.raw,
    stateConfirmed: state.confirmed,
    validDate: valid.date,
    validDateConfirmed: valid.confirmed,
    today: today,
  });
  const raw = {};
  Object.keys(source).sort().forEach((key) => {
    raw[key] = source[key] === null || source[key] === undefined ?
      "" :
      String(source[key]);
  });
  const contentHash = crypto
      .createHash("sha256")
      .update(JSON.stringify(raw))
      .digest("hex");
  const lookup = licenseLookupFields({validnum: text(source.validnum)});
  return {
    govId: govId,
    govSort: govId.padStart(8, "0"),
    raw: raw,
    countyCode: county.raw,
    countyName: county.confirmed ? county.label : "",
    countyLabel: county.label,
    countyConfirmed: county.confirmed,
    legalname: text(source.legalname),
    legaladdress: text(source.legaladdress),
    busitem: bus.raw,
    busitemLabel: bus.label,
    busitemConfirmed: bus.confirmed,
    hasBoarding: bus.hasBoarding,
    animaltype: animal.raw,
    animalLabel: animal.label,
    animalConfirmed: animal.confirmed,
    hasCat: animal.hasCat,
    hasDog: animal.hasDog,
    validnum: text(source.validnum),
    normalizedLicense: normalizeLicense(source.validnum),
    licenseLookupKey: lookup.licenseLookupKey,
    licenseLookupKind: lookup.licenseLookupKind,
    licenseLookupVersion: lookup.licenseLookupVersion,
    validdateRaw: text(source.validdate),
    validDate: valid.date,
    validDateConfirmed: valid.confirmed,
    stateFlag: state.raw,
    stateLabel: state.label,
    stateConfirmed: state.confirmed,
    licenseStatus: status,
    ownName: text(source.own_name),
    bosName: text(source.bos_name),
    rankYear: text(source.rank_year),
    rankCode: rank.raw,
    rankLabel: rank.label,
    rankConfirmed: rank.confirmed,
    rankFlag1Label: rankFlag1.label,
    rankFlag2Label: rankFlag2.label,
    rankText: text(source.rank_text),
    contentHash: contentHash,
    codebook: CODEBOOK,
    sourceName: "農業部合法特定寵物業名單",
  };
}

/**
 * 查核狀態。過期、無相符、來源不可用分開，不混成查無資料。
 * @param {Object} input 同步狀態與相符筆數
 * @return {string}
 */
function classifyLookup(input) {
  const sync = input.sync || {};
  if (!sync.lastSuccessAt) {
    return "unavailable";
  }
  const successMs = Date.parse(sync.lastSuccessAt);
  if (!Number.isFinite(successMs)) {
    return "unavailable";
  }
  const staleMs = 36 * 60 * 60 * 1000;
  if (input.nowMs - successMs > staleMs) {
    return "stale";
  }
  const count = input.matchCount || 0;
  if (count <= 0) {
    return "none";
  }
  if (count > 1) {
    return "multiple";
  }
  if (input.licenseStatus === "expired") {
    return "expired";
  }
  return "matched";
}

module.exports = {
  text,
  normalizeLicense,
  LOOKUP_KEY_VERSION,
  parseLicenseLookup,
  licenseLookupFields,
  licenseLookupCurrent,
  selectLicenseLookupWrites,
  planLookupBackfillResult,
  lookupStatusFor,
  chooseGovernmentRecord,
  taipeiDateKey,
  parseSourceDate,
  normalizeAddressText,
  toAppCity,
  parseGovernmentAddress,
  compareAddress,
  describeAnimal,
  licenseStatusOf,
  governmentDocId,
  buildGovernmentRecord,
  classifyLookup,
};
