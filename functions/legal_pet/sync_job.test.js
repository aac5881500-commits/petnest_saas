// 檔案名稱：functions/legal_pet/sync_job.test.js
// 功能說明：來源指紋、同步鎖、冷卻與失敗不提交指紋。

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  sourceFingerprint,
  decideSyncEntry,
  canReleaseLock,
  failureStatusPatch,
  MANUAL_COOLDOWN_MS,
} = require("./sync_policy");
const {performLegalPetSync} = require("./sync_job");

/**
 * @param {string} id 政府 ID
 * @param {string} name 店名
 * @param {string} license 字號
 * @return {Object}
 */
function governmentRow(id, name, license) {
  return {
    ID: id,
    legalname: name,
    legaladdress: "高雄市鼓山區中華一路2220號",
    legaltype: "A040",
    busitem: "C",
    animaltype: "狗",
    validnum: license,
    validdate: "2027-01-01",
    state_flag: "N",
  };
}

/**
 * @param {Object} options 假資料與失敗開關
 * @return {Object}
 */
function memoryIo(options) {
  const settings = options || {};
  const state = {
    running: false,
    runningUntil: "",
    lockWorkId: "",
    lastSuccessAt: settings.lastSuccessAt || "",
    lastResult: settings.lastResult || "",
    sourceFingerprint: settings.sourceFingerprint || "",
    recordCount: settings.recordCount || 0,
    lastContentChangedAt: "",
  };
  const businesses = new Map();
  const writes = [];
  let loadCalls = 0;
  let fetchCalls = 0;
  let rows = settings.rows || [];
  return {
    state: state,
    writes: writes,
    businesses: businesses,
    loadCalls() {
      return loadCalls;
    },
    fetchCalls() {
      return fetchCalls;
    },
    setRows(next) {
      rows = next;
    },
    async acquire(input) {
      const previous = Object.assign({}, state);
      const decision = decideSyncEntry({
        nowMs: input.nowMs,
        trigger: input.trigger,
        previous: previous,
        workId: input.workId,
      });
      if (decision.action !== "run") {
        return Object.assign({
          acquired: false,
          previous: previous,
        }, decision);
      }
      state.running = true;
      state.runningUntil = decision.runningUntil;
      state.lockWorkId = input.workId;
      return {acquired: true, previous: previous, summary: ""};
    },
    async fetchRows() {
      fetchCalls += 1;
      return rows;
    },
    async loadStates() {
      loadCalls += 1;
      return {states: businesses, reads: businesses.size};
    },
    async writeChanges(changes) {
      if (settings.failWrite) {
        throw new Error("write failed");
      }
      changes.forEach((change) => {
        writes.push(change);
        businesses.set(change.id, {
          hash: change.payload.contentHash,
          version: change.payload.directoryVersion,
        });
      });
    },
    async refreshExpiry() {
      return {reads: 2, updated: 0};
    },
    async finish(workId, patch) {
      if (!canReleaseLock(state.lockWorkId, workId)) {
        return;
      }
      Object.assign(state, patch, {
        running: false,
        runningUntil: "",
        lockWorkId: "",
      });
    },
    logUsage() {},
  };
}

describe("來源指紋與同步讀取", () => {
  const now = Date.parse("2026-10-08T01:00:00.000Z");
  const rows = [
    governmentRow("2", "後面商行", "特寵業字第V2000001號"),
    governmentRow("1", "宜鴻商行", "特寵業字第W1070151號"),
  ];

  it("排序和空白不改變指紋，一筆變動才需要比對", () => {
    const first = sourceFingerprint(rows);
    const reordered = sourceFingerprint(rows.slice().reverse());
    const spaced = sourceFingerprint([
      governmentRow("2", "後面商行", "特寵業字第 V2000001 號"),
      governmentRow("1", "宜鴻 商行", "特寵業字第W1070151號"),
    ]);
    assert.equal(reordered, first);
    assert.equal(spaced, first);
    const changed = sourceFingerprint([
      rows[0],
      governmentRow("1", "宜鴻商行改名", "特寵業字第W1070151號"),
    ]);
    assert.notEqual(changed, first);
  });

  it("第二次來源相同不讀政府文件，變動只寫那一筆", async () => {
    const io = memoryIo({rows: rows});
    const first = await performLegalPetSync({
      io: io,
      trigger: "schedule",
      nowMs: now,
      workId: "job-1",
    });
    assert.equal(first.ok, true);
    assert.equal(first.usage.sourceChanged, true);
    assert.equal(first.usage.created, 2);
    assert.equal(io.loadCalls(), 1);
    assert.equal(io.writes.length, 2);
    assert.equal(io.writes[0].payload.note, undefined);
    assert.equal(io.writes[0].payload.website, undefined);
    const second = await performLegalPetSync({
      io: io,
      trigger: "schedule",
      nowMs: now + 60000,
      workId: "job-2",
    });
    assert.equal(second.usage.sourceChanged, false);
    assert.equal(second.usage.businessReads, 0);
    assert.equal(io.loadCalls(), 1);
    assert.equal(second.usage.expiryReads, 2);
    assert.equal(io.state.lastResult, "unchanged");
    assert.ok(io.state.lastCheckedAt);
    const changedRows = [
      rows[0],
      governmentRow("1", "宜鴻商行改名", "特寵業字第W1070151號"),
    ];
    io.setRows(changedRows);
    const third = await performLegalPetSync({
      io: io,
      trigger: "schedule",
      nowMs: now + 120000,
      workId: "job-3",
    });
    assert.equal(third.usage.sourceChanged, true);
    assert.equal(third.usage.updated, 1);
    assert.equal(third.usage.created, 0);
    assert.equal(io.writes.length, 3);
    const last = io.writes[io.writes.length - 1];
    assert.equal(last.payload.legalname, "宜鴻商行改名");
    assert.equal(last.payload.contactStatus, undefined);
    assert.equal(last.payload.note, undefined);
  });

  it("寫入失敗不提交新指紋，鎖與冷卻會擋下重複同步", async () => {
    const previous = sourceFingerprint(rows);
    const io = memoryIo({
      rows: [
        rows[0],
        governmentRow("1", "宜鴻商行改名", "特寵業字第W1070151號"),
      ],
      sourceFingerprint: previous,
      lastSuccessAt: new Date(now).toISOString(),
      lastResult: "success",
      recordCount: 2,
      failWrite: true,
    });
    const failed = await performLegalPetSync({
      io: io,
      trigger: "schedule",
      nowMs: now + MANUAL_COOLDOWN_MS + 1000,
      workId: "job-fail",
    });
    assert.equal(failed.ok, false);
    assert.equal(io.state.sourceFingerprint, previous);
    assert.equal(io.state.lastSuccessAt, new Date(now).toISOString());
    assert.equal(io.state.lastResult, "failed");
    assert.equal(failureStatusPatch("失敗", now).sourceFingerprint, undefined);
    const locked = decideSyncEntry({
      nowMs: now,
      trigger: "manual",
      previous: {
        running: true,
        runningUntil: new Date(now + 60000).toISOString(),
      },
    });
    assert.equal(locked.action, "locked");
    assert.equal(canReleaseLock("new-job", "old-job"), false);
    assert.equal(canReleaseLock("same", "same"), true);
    const cooled = decideSyncEntry({
      nowMs: now + 60000,
      trigger: "manual",
      previous: {
        lastResult: "unchanged",
        lastSuccessAt: new Date(now).toISOString(),
      },
    });
    assert.equal(cooled.action, "cooldown");
    assert.equal(cooled.summary, "剛完成同步，請稍後再試");
    const scheduled = decideSyncEntry({
      nowMs: now + 60000,
      trigger: "schedule",
      previous: {
        lastResult: "success",
        lastSuccessAt: new Date(now).toISOString(),
      },
    });
    assert.equal(scheduled.action, "run");
    const cooledRun = await performLegalPetSync({
      io: memoryIo({
        rows: rows,
        lastSuccessAt: new Date(now).toISOString(),
        lastResult: "success",
      }),
      trigger: "manual",
      nowMs: now + 60000,
      workId: "cooled",
    });
    assert.equal(cooledRun.usage.skippedBy, "cooldown");
    assert.equal(cooledRun.usage.businessReads, 0);
    assert.equal(cooledRun.summary, "剛完成同步，請稍後再試");
  });
});
