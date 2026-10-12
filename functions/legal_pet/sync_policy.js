// 檔案名稱：functions/legal_pet/sync_policy.js
// 功能說明：決定政府名單是否可以寫入。失敗或不完整時保留上次成功資料。

const crypto = require("crypto");

const DROP_GUARD_MIN_COUNT = 200;
const MAX_DROP_RATIO = 0.15;
const MANUAL_COOLDOWN_MS = 15 * 60 * 1000;
const LOCK_TTL_MS = 15 * 60 * 1000;

/**
 * @param {Object} input 下載結果與上次成功筆數
 * @return {Object}
 */
function planSync(input) {
  const empty = {
    commit: false,
    reason: "",
    records: [],
    deletes: [],
    touchesContacts: false,
  };
  if (input.error) {
    empty.reason = textReason(input.error);
    return empty;
  }
  if (!Array.isArray(input.rows)) {
    empty.reason = "政府資料不是陣列，已保留上次成功資料";
    return empty;
  }
  const seen = new Set();
  let invalid = 0;
  input.rows.forEach((row) => {
    const id = row && row.ID !== undefined && row.ID !== null ?
      String(row.ID).trim() :
      "";
    if (!row || typeof row !== "object" || !id || id.indexOf("/") >= 0) {
      invalid += 1;
      return;
    }
    if (seen.has(id)) {
      invalid += 1;
      return;
    }
    seen.add(id);
  });
  if (input.rows.length === 0 || seen.size === 0) {
    empty.reason = "政府名單是空的，已保留上次成功資料";
    return empty;
  }
  if (invalid > 0) {
    empty.reason = "政府資料格式異常，已保留上次成功資料";
    return empty;
  }
  const previous = Number(input.previousSuccessCount) || 0;
  if (previous >= DROP_GUARD_MIN_COUNT &&
      seen.size < previous * (1 - MAX_DROP_RATIO)) {
    empty.reason = "本次筆數比上次成功少太多，已保留上次成功資料";
    return empty;
  }
  return {
    commit: true,
    reason: "",
    records: input.rows,
    deletes: [],
    touchesContacts: false,
  };
}

/**
 * @param {*} error 錯誤
 * @return {string}
 */
function textReason(error) {
  if (!error) {
    return "同步失敗，已保留上次成功資料";
  }
  if (typeof error === "string") {
    return error;
  }
  if (error.message) {
    return String(error.message);
  }
  return "同步失敗，已保留上次成功資料";
}

/**
 * 整份來源指紋。排序、空白與 JSON 排版不改變結果。
 * 不含抓取時間、目錄衍生欄位或人工聯繫。
 * @param {Object[]} rows 已驗證的政府列
 * @return {string}
 */
function sourceFingerprint(rows) {
  const lines = (Array.isArray(rows) ? rows : []).map((row) => {
    const source = row || {};
    const id = source.ID === undefined || source.ID === null ?
      "" :
      String(source.ID).trim();
    const body = {};
    Object.keys(source).sort().forEach((key) => {
      const value = source[key];
      body[key] = value === null || value === undefined ?
        "" :
        String(value).normalize("NFKC").replace(/\s+/g, "");
    });
    return id + "\n" + JSON.stringify(body);
  }).sort();
  return crypto.createHash("sha256").update(lines.join("\n")).digest("hex");
}

/**
 * @param {Object} input 現在、觸發來源與同步文件
 * @return {Object}
 */
function decideSyncEntry(input) {
  const now = Number(input.nowMs) || 0;
  const previous = input.previous || {};
  const until = Date.parse(previous.runningUntil || "");
  if (previous.running === true && Number.isFinite(until) && until > now) {
    return {
      action: "locked",
      summary: "已有同步進行中，未更動政府資料與聯繫紀錄",
    };
  }
  if (input.trigger === "manual") {
    const checked = Date.parse(previous.lastSuccessAt || "");
    const cooled = previous.lastResult === "success" ||
      previous.lastResult === "unchanged";
    if (cooled && Number.isFinite(checked) &&
        now - checked < MANUAL_COOLDOWN_MS) {
      return {
        action: "cooldown",
        summary: "剛完成同步，請稍後再試",
      };
    }
  }
  return {
    action: "run",
    workId: input.workId || "",
    runningUntil: new Date(now + LOCK_TTL_MS).toISOString(),
  };
}

/**
 * 舊工作不能清掉新工作的鎖。
 * @param {string} currentWorkId 文件上的工作識別
 * @param {string} callerWorkId 這次工作識別
 * @return {boolean}
 */
function canReleaseLock(currentWorkId, callerWorkId) {
  const current = currentWorkId || "";
  if (!current) {
    return true;
  }
  return current === callerWorkId;
}

/**
 * 沒有舊指紋時要完整比對。指紋相同就不要讀遍政府文件。
 * @param {string} previousFingerprint 上次成功指紋
 * @param {string} nextFingerprint 這次指紋
 * @return {boolean}
 */
function shouldCompareBusinesses(previousFingerprint, nextFingerprint) {
  if (!previousFingerprint) {
    return true;
  }
  return previousFingerprint !== nextFingerprint;
}

/**
 * @param {string} reason 失敗原因
 * @param {number} nowMs 現在
 * @return {Object}
 */
function failureStatusPatch(reason, nowMs) {
  return {
    lastResult: "failed",
    lastErrorSummary: reason || "同步失敗，已保留上次成功資料",
    lastFailureAt: new Date(nowMs).toISOString(),
  };
}

module.exports = {
  DROP_GUARD_MIN_COUNT,
  MAX_DROP_RATIO,
  MANUAL_COOLDOWN_MS,
  LOCK_TTL_MS,
  planSync,
  sourceFingerprint,
  decideSyncEntry,
  canReleaseLock,
  shouldCompareBusinesses,
  failureStatusPatch,
};
