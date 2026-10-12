// 檔案名稱：functions/legal_pet/directory_index.js
// 功能說明：業者名單的名稱片段索引、篩選與台北時間顯示。不掃描整份名單。

const {describeBusItem, COUNTY_CODES} = require("./codes");
const {describeAnimal, normalizeLicense, text} = require("./normalize");
const {
  districtsByCountyCode,
  officialDistrictsByName,
} = require("./directory_places");

const DIRECTORY_VERSION = 3;
const DIRECTORY_API_VERSION = 3;
const NAME_INDEX_CHARS = 32;
const MIN_GRAM = 1;
const MAX_GRAM = 4;
const MAX_GRAMS = 160;
const PUNCTUATION = /[，,。．.、·・\-－—~～()（）[\]「」『』#＃/／]/g;

const GOVERNMENT_PATCH_KEYS = [
  "directoryVersion",
  "nameNorm",
  "nameGrams",
  "businessState",
  "validity",
  "hasBreeding",
  "hasSale",
  "hasBoarding",
  "hasCat",
  "hasDog",
  "districtKey",
  "districtLabel",
  "districtPending",
  "licenseCore",
  "licensePrefixes",
];

/**
 * @param {*} value 名稱或搜尋詞
 * @return {string}
 */
function normalizeSearchName(value) {
  return text(value)
      .normalize("NFKC")
      .toLowerCase()
      .replace(/\s+/g, "")
      .replace(PUNCTUATION, "");
}

/**
 * @param {*} value 電話
 * @return {string}
 */
function phoneDigits(value) {
  return text(value).replace(/\D/g, "").slice(0, 20);
}

/**
 * 只給目錄搜尋用。不改認證用的完整字號，也不合併不同證照。
 * @param {string} normalized normalizeLicense 結果
 * @return {string}
 */
function extractLicenseCore(normalized) {
  const compact = text(normalized).toUpperCase();
  if (/^[A-Z]$/.test(compact)) {
    return compact;
  }
  if (/^[A-Z][A-Z0-9]*$/.test(compact) && /[0-9]/.test(compact)) {
    return compact;
  }
  const matches = compact.match(/[A-Z][A-Z0-9]*[0-9][A-Z0-9]*/g);
  if (!matches || matches.length === 0) {
    return "";
  }
  return matches[matches.length - 1];
}

/**
 * @param {string} core 字號核心
 * @return {string[]}
 */
function buildLicensePrefixes(core) {
  const token = text(core).toUpperCase();
  const prefixes = [];
  const limit = Math.min(token.length, 32);
  for (let size = 1; size <= limit; size += 1) {
    prefixes.push(token.slice(0, size));
  }
  return prefixes;
}

/**
 * 單一英文字母、英文字母接數字，或明確許可證文字。
 * 兩個字以上的純英文留給店名，避免英文店名被當成字號。
 * @param {string} normalized normalizeLicense 結果
 * @return {boolean}
 */
function isLicenseSearchText(normalized) {
  const compact = text(normalized).toUpperCase();
  if (/特寵|字第|字號/.test(compact)) {
    return true;
  }
  if (/^[A-Z]$/.test(compact)) {
    return true;
  }
  return /^[A-Z][A-Z0-9]*$/.test(compact) && /[0-9]/.test(compact);
}

/**
 * 只從政府登記名稱取 1～4 字片段，含單字與名稱中間。
 * @param {*} name 政府登記名稱 legalname
 * @return {string[]}
 */
function buildNameGrams(name) {
  const source = normalizeSearchName(name).slice(0, NAME_INDEX_CHARS);
  const seen = new Set();
  const grams = [];
  for (let size = MIN_GRAM; size <= MAX_GRAM; size += 1) {
    for (let index = 0; index + size <= source.length; index += 1) {
      const gram = source.slice(index, index + size);
      if (seen.has(gram)) {
        continue;
      }
      seen.add(gram);
      grams.push(gram);
      if (grams.length >= MAX_GRAMS) {
        return grams;
      }
    }
  }
  return grams;
}

/**
 * 超過 4 字時取搜尋詞中段，避免只拿開頭冒充任意片段。
 * @param {string} norm 已正規化的搜尋詞
 * @return {string}
 */
function pickNameGram(norm) {
  if (norm.length <= MAX_GRAM) {
    return norm;
  }
  let start = Math.floor((norm.length - MAX_GRAM) / 2);
  if (start === 0) {
    start = 1;
  }
  return norm.slice(start, start + MAX_GRAM);
}

/**
 * 空白不限制。中文與一般店名做包含搜尋；完整字號另走精確比對。
 * 不把數字當成電話，也不搜尋寵物種類、地址或備註。
 * @param {*} raw 搜尋框文字
 * @return {Object}
 */
function planDirectorySearch(raw) {
  const trimmed = text(raw);
  if (!trimmed) {
    return {kind: "none"};
  }
  const license = normalizeLicense(trimmed);
  if (isLicenseSearchText(license)) {
    const core = extractLicenseCore(license);
    if (!core) {
      return {kind: "license", error: "請輸入較完整的許可證字號"};
    }
    const wrapped = /特寵|字第|字號/.test(license);
    return {
      kind: "license",
      field: "licensePrefixes",
      op: "array-contains",
      prefix: core,
      value: core,
      exactNormalized: wrapped ? license : "",
    };
  }
  const norm = normalizeSearchName(trimmed);
  if (!norm) {
    return {kind: "name", error: "請輸入店名或許可證字號"};
  }
  if (norm.length > NAME_INDEX_CHARS) {
    return {kind: "name", error: "店名搜尋請不要超過 32 個字"};
  }
  return {
    kind: "name",
    field: "nameGrams",
    op: "array-contains",
    gram: pickNameGram(norm),
    needle: norm,
  };
}

/**
 * @param {Object} data 查詢參數
 * @return {Object}
 */
function readDirectoryFilters(data) {
  const input = data || {};
  const countyCode = text(input.countyCode);
  const district = text(input.district);
  let bus = text(input.bus);
  if (!bus && text(input.boarding) === "yes") {
    bus = "boarding";
  }
  let districtKey = "";
  let districtPending = false;
  if (district === "pending") {
    districtPending = true;
    if (countyCode) {
      districtKey = countyCode + "|pending";
    }
  } else if (district && countyCode) {
    districtKey = countyCode + "|" + district;
  }
  return {
    countyCode: countyCode,
    district: district,
    districtKey: districtKey,
    districtPending: districtPending,
    animal: text(input.animal),
    bus: bus,
    businessState: text(input.businessState),
    validity: text(input.validity),
    linkStatus: text(input.linkStatus),
    contactStatus: text(input.contactStatus),
  };
}

/**
 * @param {Object} filters 篩選
 * @param {Object} search 搜尋
 * @return {boolean}
 */
function filtersNeedDirectoryIndex(filters, search) {
  if (search && search.kind && search.kind !== "none") {
    return true;
  }
  const row = filters || {};
  return Boolean(
      row.district || row.animal || row.bus || row.businessState ||
      row.validity || row.linkStatus || row.contactStatus,
  );
}

/**
 * @param {Object} search 搜尋
 * @param {Object} filters 篩選
 * @param {boolean} directoryReady 目錄欄位是否已補到本版
 * @return {Object|null}
 */
function primaryConstraint(search, filters, directoryReady) {
  const query = search || {kind: "none"};
  const row = filters || {};
  const ready = directoryReady === true;
  if (query.kind === "name") {
    return {field: "nameGrams", op: "array-contains", value: query.gram};
  }
  if (query.kind === "license") {
    return {
      field: "licensePrefixes",
      op: "array-contains",
      value: query.prefix,
    };
  }
  if (row.linkStatus === "certified") {
    return {field: "linkStatus", op: "eq", value: "certified"};
  }
  if (ready && row.districtKey) {
    return {field: "districtKey", op: "eq", value: row.districtKey};
  }
  if (ready && row.districtPending && !row.countyCode) {
    return {field: "districtPending", op: "eq", value: true};
  }
  if (row.countyCode) {
    return {field: "countyCode", op: "eq", value: row.countyCode};
  }
  if (row.linkStatus) {
    return {field: "linkStatus", op: "eq", value: row.linkStatus};
  }
  if (row.contactStatus) {
    return {field: "contactStatus", op: "eq", value: row.contactStatus};
  }
  if (row.animal === "cat" || row.animal === "both") {
    return {field: "hasCat", op: "eq", value: true};
  }
  if (row.animal === "dog") {
    return {field: "hasDog", op: "eq", value: true};
  }
  if (row.bus === "boarding") {
    return {field: "hasBoarding", op: "eq", value: true};
  }
  if (ready && row.bus === "sale") {
    return {field: "hasSale", op: "eq", value: true};
  }
  if (ready && row.bus === "breeding") {
    return {field: "hasBreeding", op: "eq", value: true};
  }
  if (ready && row.businessState) {
    return {field: "businessState", op: "eq", value: row.businessState};
  }
  if (ready && row.validity) {
    return {field: "validity", op: "eq", value: row.validity};
  }
  return null;
}

/**
 * 無法正確套用時回傳補齊，不可改成不篩選的全部名單。
 * 已認證綁定可直接查 certified，缺少欄位時自然是零筆。
 * @param {Object} search 搜尋
 * @param {Object} filters 篩選
 * @param {boolean} directoryReady 目錄是否已補到本版
 * @return {boolean}
 */
function filterRequiresBackfill(search, filters, directoryReady) {
  if (directoryReady === true) {
    return false;
  }
  const query = search || {kind: "none"};
  const row = filters || {};
  if (query.kind === "name" || query.kind === "license") {
    return true;
  }
  if (row.district || row.districtPending) {
    return true;
  }
  return false;
}

/**
 * @param {Object} record 政府文件
 * @return {string}
 */
function businessStateOf(record) {
  const row = record || {};
  if (row.stateConfirmed !== true) {
    return "unknown";
  }
  if (row.stateFlag === "N") {
    return "operating";
  }
  if (row.stateFlag === "P") {
    return "closed";
  }
  if (row.stateFlag === "S") {
    return "suspended";
  }
  if (row.stateFlag === "B") {
    return "revoked";
  }
  return "unknown";
}

/**
 * @param {Object} record 政府文件
 * @param {string} today 台北今日
 * @return {string}
 */
function validityOf(record, today) {
  const row = record || {};
  const date = text(row.validDate);
  if (row.validDateConfirmed === false || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return "unknown";
  }
  if (date < today) {
    return "expired";
  }
  return "valid";
}

/**
 * @param {string} address 政府地址
 * @param {string} countyCode 官方縣市代碼
 * @return {Object}
 */
function parseDirectoryDistrict(address, countyCode) {
  const code = text(countyCode);
  const countyName = COUNTY_CODES[code] || "";
  const pending = {
    districtLabel: "",
    districtKey: code ? code + "|pending" : "pending",
    districtPending: true,
  };
  if (!countyName) {
    return pending;
  }
  const byName = officialDistrictsByName();
  const districts = byName[countyName] || [];
  const folded = text(address)
      .normalize("NFKC")
      .replace(/\s+/g, "")
      .replace(/台/g, "臺");
  if (!folded) {
    return pending;
  }
  const countyNames = Object.keys(byName).sort((left, right) => {
    return right.length - left.length;
  });
  for (const name of countyNames) {
    if (folded.indexOf(name) === 0 && name !== countyName) {
      return pending;
    }
  }
  let rest = folded;
  if (rest.indexOf(countyName) === 0) {
    rest = rest.slice(countyName.length);
  }
  const ordered = districts.slice().sort((left, right) => {
    return right.length - left.length;
  });
  for (const district of ordered) {
    if (rest.indexOf(district) === 0) {
      return {
        districtLabel: district,
        districtKey: code + "|" + district,
        districtPending: false,
      };
    }
  }
  return pending;
}

/**
 * 已補齊的結果沿用寫入值；舊文件則依地址現算，避免空白被顯示成待確認。
 * @param {Object} data 政府文件
 * @return {Object}
 */
function resolveDistrict(data) {
  const row = data || {};
  const version = Number(row.directoryVersion) || 0;
  if (version >= DIRECTORY_VERSION &&
      (text(row.districtLabel) || row.districtPending === true)) {
    const label = row.districtPending === true ? "" : text(row.districtLabel);
    return {
      districtLabel: label,
      districtKey: text(row.districtKey),
      districtPending: row.districtPending === true,
    };
  }
  return parseDirectoryDistrict(row.legaladdress, row.countyCode);
}

/**
 * 只含政府衍生欄位。不含聯繫電話、進度、備註或綁定。
 * @param {Object} record 已保存的政府文件
 * @param {string} today 台北今日
 * @return {Object}
 */
function governmentDirectoryPatch(record, today) {
  const row = record || {};
  const bus = describeBusItem(row.busitem);
  const animal = describeAnimal(row.animaltype);
  const place = parseDirectoryDistrict(row.legaladdress, row.countyCode);
  const license = text(row.normalizedLicense) ||
    normalizeLicense(row.validnum);
  const licenseCore = extractLicenseCore(license);
  return {
    directoryVersion: DIRECTORY_VERSION,
    nameNorm: normalizeSearchName(row.legalname),
    nameGrams: buildNameGrams(row.legalname),
    licenseCore: licenseCore,
    licensePrefixes: buildLicensePrefixes(licenseCore),
    businessState: businessStateOf(row),
    validity: validityOf(row, today),
    hasBreeding: bus.hasBreeding,
    hasSale: bus.hasSale,
    hasBoarding: bus.hasBoarding,
    hasCat: animal.hasCat,
    hasDog: animal.hasDog,
    districtKey: place.districtKey,
    districtLabel: place.districtLabel,
    districtPending: place.districtPending,
  };
}

/**
 * @param {Object} record 政府文件
 * @return {Object}
 */
function animalFlags(record) {
  const row = record || {};
  if (text(row.animaltype)) {
    const animal = describeAnimal(row.animaltype);
    return {hasCat: animal.hasCat === true, hasDog: animal.hasDog === true};
  }
  return {hasCat: row.hasCat === true, hasDog: row.hasDog === true};
}

/**
 * @param {Object} record 政府文件
 * @return {Object}
 */
function busFlags(record) {
  const row = record || {};
  if (text(row.busitem)) {
    return describeBusItem(row.busitem);
  }
  return {
    hasBreeding: row.hasBreeding === true,
    hasSale: row.hasSale === true,
    hasBoarding: row.hasBoarding === true,
  };
}

/**
 * 店名只比對 legalname。寵物、營業項目與狀態全部要同時成立。
 * @param {Object} record 政府文件
 * @param {Object} filters 篩選
 * @param {Object} search 搜尋
 * @param {string} today 台北今日
 * @return {boolean}
 */
function matchesDirectoryFilters(record, filters, search, today) {
  const row = record || {};
  const wanted = filters || {};
  const query = search || {kind: "none"};
  const animals = animalFlags(row);
  const bus = busFlags(row);
  if (query.kind === "name") {
    const name = normalizeSearchName(row.legalname);
    if (!query.needle || name.indexOf(query.needle) < 0) {
      return false;
    }
  }
  if (query.kind === "license") {
    const core = text(row.licenseCore) ||
      extractLicenseCore(text(row.normalizedLicense));
    if (!query.prefix || core.indexOf(query.prefix) !== 0) {
      return false;
    }
    if (query.exactNormalized &&
        text(row.normalizedLicense) !== query.exactNormalized) {
      return false;
    }
  }
  if (wanted.countyCode && text(row.countyCode) !== wanted.countyCode) {
    return false;
  }
  if (wanted.districtKey && text(row.districtKey) !== wanted.districtKey) {
    return false;
  }
  if (wanted.districtPending && !wanted.countyCode &&
      row.districtPending !== true) {
    return false;
  }
  if (wanted.animal === "cat" && animals.hasCat !== true) {
    return false;
  }
  if (wanted.animal === "dog" && animals.hasDog !== true) {
    return false;
  }
  if (wanted.animal === "both" &&
      (animals.hasCat !== true || animals.hasDog !== true)) {
    return false;
  }
  if (wanted.bus === "boarding" && bus.hasBoarding !== true) {
    return false;
  }
  if (wanted.bus === "sale" && bus.hasSale !== true) {
    return false;
  }
  if (wanted.bus === "breeding" && bus.hasBreeding !== true) {
    return false;
  }
  if (wanted.businessState &&
      storedBusinessState(row) !== wanted.businessState) {
    return false;
  }
  if (wanted.validity && validityOf(row, today) !== wanted.validity) {
    return false;
  }
  if (wanted.linkStatus && text(row.linkStatus) !== wanted.linkStatus) {
    return false;
  }
  if (wanted.contactStatus &&
      text(row.contactStatus) !== wanted.contactStatus) {
    return false;
  }
  return true;
}

/**
 * 營業狀態以文件上的代碼為準；日期有效性另計。
 * businessStateOf 需要 stateConfirmed。篩選時若已有 businessState 欄位，
 * 仍用代碼重算，避免日期過期被誤當成歇業。
 * @param {Object} record 文件
 * @return {string}
 */
function storedBusinessState(record) {
  const row = record || {};
  if (row.stateFlag) {
    return businessStateOf(row);
  }
  return text(row.businessState) || "unknown";
}

/**
 * @param {string} iso ISO 時間
 * @return {string} 台北 YYYY/MM/DD HH:mm
 */
function formatTaipeiDateTime(iso) {
  const date = new Date(text(iso));
  if (!Number.isFinite(date.getTime())) {
    return "";
  }
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const pick = (type) => {
    const found = parts.find((part) => part.type === type);
    return found ? found.value : "";
  };
  return pick("year") + "/" + pick("month") + "/" + pick("day") +
    " " + pick("hour") + ":" + pick("minute");
}

/**
 * @param {Object} data 同步文件
 * @param {number} nowMs 現在
 * @return {Object}
 */
function presentSync(data, nowMs) {
  const row = data || {};
  const running = row.running === true &&
    Date.parse(row.runningUntil || "") > nowMs;
  const successText = formatTaipeiDateTime(row.lastSuccessAt || "");
  let phase = "never";
  if (running) {
    phase = "running";
  } else if (row.lastResult === "failed") {
    phase = "failed";
  } else if (row.lastSuccessAt) {
    phase = "success";
  }
  const checkedAt = row.lastCheckedAt || row.lastSuccessAt || "";
  return {
    phase: phase,
    successText: successText,
    checkedText: formatTaipeiDateTime(checkedAt),
    contentChangedText: formatTaipeiDateTime(row.lastContentChangedAt || ""),
    sourceUnchanged: row.lastResult === "unchanged",
    lastSuccessAt: row.lastSuccessAt || "",
    lastFailureAt: row.lastFailureAt || "",
    errorSummary: phase === "failed" ? (row.lastErrorSummary || "") : "",
    directoryReady: Number(row.directoryIndexVersion) >= DIRECTORY_VERSION,
  };
}

/**
 * @param {Object} input 列表結果
 * @return {string}
 */
function listOutcome(input) {
  const row = input || {};
  if (row.error) {
    return "query_failed";
  }
  if (row.needsBackfill) {
    return "needs_backfill";
  }
  if (row.phase === "never" && !row.itemCount) {
    return "not_synced";
  }
  if (!row.itemCount && row.hasMore) {
    return "continue";
  }
  if (!row.itemCount) {
    return "empty";
  }
  return "results";
}

/**
 * 政府內容有變才寫入。目錄版本升級只走 backfill，不同步整份補齊。
 * @param {Object} input 比對結果
 * @return {Object}
 */
function planDirectoryWrite(input) {
  const row = input || {};
  const base = {touchesContact: false, deletes: false};
  if (!row.hashMatch) {
    return Object.assign(base, {action: "content"});
  }
  return Object.assign(base, {action: "skip"});
}

/**
 * @param {Object[]} records 已依 govSort 排序的文件
 * @param {Object} options 篩選、游標與本批上限
 * @return {Object}
 */
function scanDirectoryRecords(records, options) {
  const list = Array.isArray(records) ? records : [];
  const settings = options || {};
  const pageSize = settings.pageSize || 30;
  const scanLimit = settings.scanLimit || 500;
  const today = settings.today || "";
  const matched = [];
  let scanned = 0;
  let seenCursor = !settings.cursor;
  let lastSort = text(settings.cursor);
  let exhausted = true;
  for (let index = 0; index < list.length; index += 1) {
    const row = list[index] || {};
    const sort = text(row.govSort) || String(index);
    if (!seenCursor) {
      if (sort === text(settings.cursor)) {
        seenCursor = true;
      }
      continue;
    }
    scanned += 1;
    lastSort = sort;
    const matchedRow = matchesDirectoryFilters(
        row,
        settings.filters,
        settings.search,
        today,
    );
    if (matchedRow) {
      matched.push(row);
    }
    if (matched.length >= pageSize || scanned >= scanLimit) {
      exhausted = index >= list.length - 1;
      break;
    }
  }
  return {
    items: matched.slice(0, pageSize),
    nextCursor: exhausted ? "" : lastSort,
    hasMore: !exhausted,
    scanned: scanned,
  };
}

/**
 * @param {Object} row 既有文件
 * @param {Object} patch 新目錄欄位
 * @return {boolean}
 */
function directoryFieldsCurrent(row, patch) {
  const current = row || {};
  const next = patch || {};
  if ((Number(current.directoryVersion) || 0) < DIRECTORY_VERSION) {
    return false;
  }
  if (!Array.isArray(current.nameGrams)) {
    return false;
  }
  const name = normalizeSearchName(current.legalname);
  if (name && current.nameGrams.indexOf(pickNameGram(name)) < 0) {
    return false;
  }
  const license = text(current.normalizedLicense) ||
    normalizeLicense(current.validnum);
  const core = extractLicenseCore(license);
  if (core && (!Array.isArray(current.licensePrefixes) ||
      current.licensePrefixes.indexOf(core) < 0)) {
    return false;
  }
  if (Object.prototype.hasOwnProperty.call(next, "linkStatus") &&
      text(current.linkStatus) !== text(next.linkStatus)) {
    return false;
  }
  if (Object.prototype.hasOwnProperty.call(next, "contactStatus") &&
      text(current.contactStatus) !== text(next.contactStatus)) {
    return false;
  }
  return text(current.nameNorm) === text(next.nameNorm) &&
    text(current.districtKey) === text(next.districtKey) &&
    Boolean(current.districtPending) === Boolean(next.districtPending) &&
    text(current.validity) === text(next.validity) &&
    text(current.businessState) === text(next.businessState);
}

/**
 * 只補政府衍生欄位與聯繫鏡像。不回寫備註、網站或認證文件。
 * @param {Object} row 政府文件
 * @param {Object|null} contact 人工聯繫，可為 null
 * @param {Object|null} link 字號綁定，可為 null
 * @param {string} today 台北今日
 * @return {Object}
 */
function buildBackfillPatch(row, contact, link, today) {
  const current = row || {};
  const patch = governmentDirectoryPatch(current, today);
  if (contact) {
    patch.contactStatus = text(contact.contactStatus) || "not_contacted";
    patch.contactPhoneDigits = phoneDigits(contact.phone);
  }
  if (link) {
    const certified = text(link.certifiedShopId);
    const candidates = Array.isArray(link.candidateShopIds) ?
      link.candidateShopIds.filter(Boolean) :
      [];
    patch.candidateCount = candidates.length;
    if (certified) {
      patch.linkStatus = "certified";
    } else if (candidates.length > 0) {
      patch.linkStatus = "candidate";
    } else {
      patch.linkStatus = "none";
    }
  } else if (!text(current.linkStatus)) {
    patch.linkStatus = "none";
    patch.candidateCount = 0;
  }
  return patch;
}

/**
 * 與 Firestore 查詢相同的條件。測試用這個規格執行，不只做記憶體過濾。
 * @param {Object} search 搜尋
 * @param {Object} filters 篩選
 * @param {boolean} directoryReady 目錄是否就緒
 * @return {Object}
 */
function directoryQuerySpec(search, filters, directoryReady) {
  return {
    constraint: primaryConstraint(search, filters, directoryReady),
    orderBy: "govSort",
  };
}

/**
 * @param {Object} row 文件
 * @param {Object|null} constraint 索引條件
 * @return {boolean}
 */
function matchesQueryConstraint(row, constraint) {
  if (!constraint) {
    return true;
  }
  const value = row[constraint.field];
  if (constraint.op === "array-contains") {
    return Array.isArray(value) && value.indexOf(constraint.value) >= 0;
  }
  if (constraint.op === "eq") {
    return value === constraint.value;
  }
  return false;
}

/**
 * 模擬索引查詢：先套 constraint 與 govSort cursor，再做記憶體 AND 過濾。
 * @param {Object[]} records 文件
 * @param {Object} spec directoryQuerySpec
 * @param {Object} options 游標、篩選與上限
 * @return {Object}
 */
function executeDirectoryQuery(records, spec, options) {
  const settings = options || {};
  const querySpec = spec || {constraint: null, orderBy: "govSort"};
  const pageSize = settings.pageSize || 30;
  const scanLimit = settings.scanLimit || 500;
  const list = Array.isArray(records) ? records : [];
  const sorted = list.slice().sort((leftRow, rightRow) => {
    const left = text(leftRow.govSort);
    const right = text(rightRow.govSort);
    if (left < right) {
      return -1;
    }
    if (left > right) {
      return 1;
    }
    return 0;
  });
  const cursor = text(settings.cursor);
  const matched = [];
  let scanned = 0;
  let seenCursor = !cursor;
  let lastSort = cursor;
  let stopIndex = sorted.length - 1;
  let stoppedEarly = false;
  for (let index = 0; index < sorted.length; index += 1) {
    const row = sorted[index] || {};
    const sort = text(row.govSort) || String(index);
    if (!seenCursor) {
      if (sort === cursor) {
        seenCursor = true;
      }
      continue;
    }
    if (!matchesQueryConstraint(row, querySpec.constraint)) {
      continue;
    }
    scanned += 1;
    lastSort = sort;
    stopIndex = index;
    if (matchesDirectoryFilters(
        row,
        settings.filters,
        settings.search,
        settings.today || "",
    )) {
      matched.push(row);
    }
    if (matched.length >= pageSize || scanned >= scanLimit) {
      stoppedEarly = index < sorted.length - 1;
      break;
    }
  }
  let hasMore = false;
  if (stoppedEarly) {
    for (let index = stopIndex + 1; index < sorted.length; index += 1) {
      if (matchesQueryConstraint(sorted[index], querySpec.constraint)) {
        hasMore = true;
        break;
      }
    }
  }
  return {
    items: matched.slice(0, pageSize),
    nextCursor: hasMore ? lastSort : "",
    hasMore: hasMore,
    candidateReads: scanned,
  };
}

module.exports = {
  DIRECTORY_VERSION,
  DIRECTORY_API_VERSION,
  NAME_INDEX_CHARS,
  GOVERNMENT_PATCH_KEYS,
  normalizeSearchName,
  phoneDigits,
  buildNameGrams,
  pickNameGram,
  planDirectorySearch,
  extractLicenseCore,
  buildLicensePrefixes,
  isLicenseSearchText,
  directoryQuerySpec,
  executeDirectoryQuery,
  readDirectoryFilters,
  filtersNeedDirectoryIndex,
  primaryConstraint,
  filterRequiresBackfill,
  businessStateOf,
  validityOf,
  parseDirectoryDistrict,
  resolveDistrict,
  governmentDirectoryPatch,
  matchesDirectoryFilters,
  storedBusinessState,
  formatTaipeiDateTime,
  presentSync,
  listOutcome,
  planDirectoryWrite,
  scanDirectoryRecords,
  directoryFieldsCurrent,
  buildBackfillPatch,
  districtsByCountyCode,
};
