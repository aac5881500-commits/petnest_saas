// 檔案名稱：functions/legal_pet/sync_job.js
// 功能說明：下載農業部名單。來源沒變時不讀遍政府文件，也不重寫。

const crypto = require("crypto");
const admin = require("firebase-admin");
const {
  planSync,
  sourceFingerprint,
  decideSyncEntry,
  canReleaseLock,
  shouldCompareBusinesses,
  failureStatusPatch,
} = require("./sync_policy");
const {
  buildGovernmentRecord,
  taipeiDateKey,
  governmentDocId,
} = require("./normalize");
const {
  governmentDirectoryPatch,
  planDirectoryWrite,
} = require("./directory_index");

const SOURCE_URL = "https://data.moa.gov.tw/Service/OpenData/TransService.aspx" +
  "?IsTransData=1&UnitId=fNT9RMo8PQRO";
const PAGE_SIZE = 1000;
const MAX_PAGES = 40;
const EXPIRY_BATCH = 200;
const EXPIRY_ROUNDS = 5;

/**
 * 分頁下載沒有整份名單的 ETag，不能用單頁條件請求代表全部內容。
 * @param {number} skip 略過筆數
 * @return {Promise<Object[]>}
 */
async function fetchPage(skip) {
  const url = SOURCE_URL + "&$top=" + PAGE_SIZE + "&$skip=" + skip;
  const response = await fetch(url, {
    signal: AbortSignal.timeout(45000),
  });
  if (!response.ok) {
    throw new Error("政府資料服務回應 " + response.status);
  }
  const payload = await response.json();
  if (!Array.isArray(payload)) {
    throw new Error("政府資料格式不是陣列");
  }
  return payload;
}

/**
 * @return {Promise<Object[]>}
 */
async function fetchGovernmentRows() {
  const rows = [];
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const batch = await fetchPage(page * PAGE_SIZE);
    if (batch.length === 0) {
      break;
    }
    batch.forEach((row) => {
      rows.push(row);
    });
    if (batch.length < PAGE_SIZE) {
      break;
    }
  }
  return rows;
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @return {Promise<Object>}
 */
async function loadSyncState(db) {
  const states = new Map();
  const documentId = admin.firestore.FieldPath.documentId();
  let query = db.collection("legal_pet_businesses")
      .orderBy(documentId)
      .select("contentHash", "directoryVersion", "validity")
      .limit(400);
  let last = null;
  let reads = 0;
  for (;;) {
    const page = last ? query.startAfter(last) : query;
    const snap = await page.get();
    reads += snap.size;
    if (snap.empty) {
      break;
    }
    snap.docs.forEach((doc) => {
      states.set(doc.id, {
        hash: doc.get("contentHash") || "",
        version: Number(doc.get("directoryVersion")) || 0,
        validity: doc.get("validity") || "",
      });
    });
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < 400) {
      break;
    }
    query = db.collection("legal_pet_businesses")
        .orderBy(documentId)
        .select("contentHash", "directoryVersion", "validity")
        .limit(400);
  }
  return {states: states, reads: reads};
}

/**
 * 只把已標有效、但日期已過的資料改成已過期。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} today 台北今日
 * @return {Promise<Object>}
 */
async function refreshExpiredValidity(db, today) {
  let reads = 0;
  let updated = 0;
  for (let round = 0; round < EXPIRY_ROUNDS; round += 1) {
    const snap = await db.collection("legal_pet_businesses")
        .where("validity", "==", "valid")
        .where("validDate", "<", today)
        .limit(EXPIRY_BATCH)
        .get();
    reads += snap.size;
    if (snap.empty) {
      break;
    }
    const writer = db.bulkWriter();
    snap.docs.forEach((doc) => {
      writer.set(doc.ref, {validity: "expired"}, {merge: true});
    });
    await writer.close();
    updated += snap.size;
    if (snap.size < EXPIRY_BATCH) {
      break;
    }
  }
  return {reads: reads, updated: updated};
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @return {Object}
 */
function firestoreSyncIo(db) {
  const ref = db.collection("legal_pet_sync").doc("current");
  return {
    async acquire(input) {
      return db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const previous = snap.exists ? snap.data() : {};
        const decision = decideSyncEntry({
          nowMs: input.nowMs,
          trigger: input.trigger,
          previous: previous,
          workId: input.workId,
        });
        if (decision.action !== "run") {
          return Object.assign({acquired: false, previous: previous}, decision);
        }
        tx.set(ref, {
          running: true,
          runningUntil: decision.runningUntil,
          lockWorkId: input.workId,
          lastAttemptAt: new Date(input.nowMs).toISOString(),
          lastTrigger: input.trigger,
        }, {merge: true});
        return {
          acquired: true,
          previous: previous,
          workId: input.workId,
          summary: "",
        };
      });
    },
    fetchRows: fetchGovernmentRows,
    loadStates() {
      return loadSyncState(db);
    },
    async writeChanges(changes) {
      if (!changes.length) {
        return;
      }
      const writer = db.bulkWriter();
      changes.forEach((change) => {
        writer.set(
            db.collection("legal_pet_businesses").doc(change.id),
            change.payload,
            {merge: true},
        );
      });
      await writer.close();
    },
    async refreshExpiry(today) {
      return refreshExpiredValidity(db, today);
    },
    async finish(workId, patch) {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const current = snap.exists ? snap.data() : {};
        if (!canReleaseLock(current.lockWorkId, workId)) {
          return;
        }
        tx.set(ref, Object.assign({
          running: false,
          runningUntil: "",
          lockWorkId: "",
        }, patch), {merge: true});
      });
    },
    logUsage(usage) {
      console.log(JSON.stringify(Object.assign({
        event: "legal_pet_sync",
      }, usage)));
    },
  };
}

/**
 * @param {Object[]} records 已驗證政府列
 * @param {Map<string, Object>} states 既有雜湊
 * @param {string} today 台北今日
 * @param {string} nowIso 寫入時間
 * @return {Object}
 */
function planGovernmentChanges(records, states, today, nowIso) {
  const changes = [];
  let created = 0;
  let updated = 0;
  let skipped = 0;
  const seen = new Set();
  records.forEach((row) => {
    const record = buildGovernmentRecord(row, today);
    const docId = governmentDocId(record.govId);
    if (!docId || seen.has(docId)) {
      return;
    }
    seen.add(docId);
    const state = states.get(docId);
    const directory = governmentDirectoryPatch(record, today);
    const write = planDirectoryWrite({
      hashMatch: Boolean(state) && state.hash === record.contentHash,
    });
    if (write.action === "skip") {
      skipped += 1;
      return;
    }
    const payload = Object.assign({}, record, directory, {
      contentUpdatedAt: nowIso,
    });
    if (!state) {
      payload.firstSeenAt = nowIso;
      payload.contactStatus = "not_contacted";
      payload.contactPhoneDigits = "";
      payload.linkStatus = "none";
      payload.candidateCount = 0;
      created += 1;
    } else {
      updated += 1;
    }
    changes.push({id: docId, payload: payload});
  });
  return {
    changes: changes,
    created: created,
    updated: updated,
    skipped: skipped,
    seen: seen.size,
  };
}

/**
 * @param {boolean} ok 是否成功
 * @param {string} summary 給畫面的句子
 * @param {Object} usage 用量
 * @return {Object}
 */
function syncResult(ok, summary, usage) {
  return {
    ok: ok,
    keptPrevious: ok !== true,
    summary: summary,
    usage: usage,
  };
}

/**
 * @param {Object} options io、觸發來源與時間
 * @return {Promise<Object>}
 */
async function performLegalPetSync(options) {
  const settings = options || {};
  const io = settings.io;
  const trigger = settings.trigger || "manual";
  const nowMs = Number(settings.nowMs) || Date.now();
  const workId = settings.workId || crypto.randomBytes(8).toString("hex");
  const nowIso = new Date(nowMs).toISOString();
  const emptyUsage = {
    sourceCount: 0,
    sourceChanged: false,
    businessReads: 0,
    created: 0,
    updated: 0,
    skipped: 0,
    expiryReads: 0,
    skippedBy: "",
  };
  const entry = await io.acquire({
    trigger: trigger,
    workId: workId,
    nowMs: nowMs,
  });
  if (!entry.acquired) {
    const usage = Object.assign({}, emptyUsage, {skippedBy: entry.action});
    io.logUsage(usage);
    return syncResult(false, entry.summary, usage);
  }
  const previous = entry.previous || {};
  try {
    const rows = await io.fetchRows();
    const decision = planSync({
      rows: rows,
      previousSuccessCount: previous.recordCount || 0,
    });
    if (!decision.commit) {
      await io.finish(workId, failureStatusPatch(decision.reason, nowMs));
      const usage = Object.assign({}, emptyUsage, {
        sourceCount: Array.isArray(rows) ? rows.length : 0,
      });
      io.logUsage(usage);
      return syncResult(false, decision.reason, usage);
    }
    const fingerprint = sourceFingerprint(decision.records);
    const today = taipeiDateKey(new Date(nowMs));
    if (!shouldCompareBusinesses(previous.sourceFingerprint, fingerprint)) {
      await io.finish(workId, {
        lastResult: "unchanged",
        lastSuccessAt: nowIso,
        lastCheckedAt: nowIso,
        lastErrorSummary: "",
        sourceChanged: false,
        recordCount: decision.records.length,
      });
      let expiryReads = 0;
      try {
        const expiry = await io.refreshExpiry(today);
        expiryReads = expiry.reads || 0;
      } catch (expiryError) {
        console.error("legal pet validity refresh skipped", expiryError);
      }
      const usage = Object.assign({}, emptyUsage, {
        sourceCount: decision.records.length,
        sourceChanged: false,
        businessReads: 0,
        skipped: decision.records.length,
        expiryReads: expiryReads,
      });
      io.logUsage(usage);
      return syncResult(true, "政府名單沒有變動，未重寫政府文件", usage);
    }
    const loaded = await io.loadStates();
    const planned = planGovernmentChanges(
        decision.records,
        loaded.states,
        today,
        nowIso,
    );
    await io.writeChanges(planned.changes);
    await io.finish(workId, {
      lastResult: "success",
      lastSuccessAt: nowIso,
      lastCheckedAt: nowIso,
      lastContentChangedAt: nowIso,
      lastErrorSummary: "",
      sourceFingerprint: fingerprint,
      sourceChanged: true,
      recordCount: planned.seen,
      updatedCount: planned.updated,
      createdCount: planned.created,
      unchangedCount: planned.skipped,
    });
    let expiryReads = 0;
    try {
      const expiry = await io.refreshExpiry(today);
      expiryReads = expiry.reads || 0;
    } catch (expiryError) {
      console.error("legal pet validity refresh skipped", expiryError);
    }
    const usage = {
      sourceCount: decision.records.length,
      sourceChanged: true,
      businessReads: loaded.reads,
      created: planned.created,
      updated: planned.updated,
      skipped: planned.skipped,
      expiryReads: expiryReads,
      skippedBy: "",
    };
    io.logUsage(usage);
    const summary = "已同步 " + planned.seen + " 筆，新增 " +
      planned.created + " 筆，更新 " + planned.updated + " 筆";
    return syncResult(true, summary, usage);
  } catch (error) {
    const decision = planSync({
      error: error,
      rows: null,
      previousSuccessCount: previous.recordCount || 0,
    });
    try {
      await io.finish(workId, failureStatusPatch(decision.reason, nowMs));
    } catch (finishError) {
      console.error("legal pet sync finish failed", finishError);
    }
    const usage = Object.assign({}, emptyUsage);
    io.logUsage(usage);
    return syncResult(false, decision.reason, usage);
  }
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} trigger 手動或排程
 * @return {Promise<Object>}
 */
async function runLegalPetSync(db, trigger) {
  return performLegalPetSync({
    io: firestoreSyncIo(db),
    trigger: trigger,
    nowMs: Date.now(),
  });
}

module.exports = {
  SOURCE_URL,
  fetchGovernmentRows,
  runLegalPetSync,
  performLegalPetSync,
  planGovernmentChanges,
};
