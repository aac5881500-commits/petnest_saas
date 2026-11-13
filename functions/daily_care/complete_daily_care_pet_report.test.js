const {test} = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const docs = new Map();
const stamp = () => new Date();
const ref = (path) => ({
  path,
  doc: (id) => ref(path + "/" + id),
  collection: (name) => ref(path + "/" + name),
});
const firestore = Object.assign(() => ({
  collection: ref,
  runTransaction: async (run) => {
    const writes = [];
    const result = await run({
      get: async (r) => ({data: () => docs.get(r.path)}),
      set: (r, payload, options) => writes.push([r, payload, options]),
    });
    for (const [r, payload, options] of writes) {
      docs.set(r.path, options?.merge ? {...docs.get(r.path), ...payload} : payload);
    }
    return result;
  },
}), {Timestamp: {fromDate: (date) => date}, FieldValue: {serverTimestamp: stamp}});

const load = Module._load;
Module._load = function(name, parent, main) {
  if (name === "firebase-admin") return {firestore};
  if (name === "../platform/inspection_write_guard") return {
    onCall: (_, handler) => handler,
    HttpsError: class extends Error {
      constructor(code, message) { super(message); this.code = code; }
    },
  };
  if (name === "../daycare/daycare_utils") return {
    getShopMember: async (_, uid) => uid === "staff" || uid === "sales" ? {} : null,
    hasShopPermission: async (_, uid) => uid === "staff",
    isRootAdmin: () => false,
    toDate: (value) => new Date(value),
    normalizeString: (v) => String(v ?? "").trim(),
    toInt: (v, fallback) => Number.isInteger(v) ? v : fallback,
  };
  return load.call(this, name, parent, main);
};
let manage;
try { manage = require("./complete_daily_care_report").manageDailyCarePetReport; } finally {
  Module._load = load;
}

test("drafts stay private, publication exposes only the selected cat, session completes after both", async () => {
  const booking = {
    shopId: "s", roomId: "r", status: "checked_in", bookingKind: "accommodation",
    startDate: "2026-11-12", endDate: "2026-11-14",
    pets: [{petId: "a", name: "栗子"}, {petId: "b", name: "麻糬"}],
    dailyCareEntitlement: {enabled: true, finalReports: 1},
  };
  docs.set("bookings/o", booking);
  const payload = {shopId: "s", roomId: "r", bookingId: "o", recordDate: "2026-11-12", sessionIndex: 0};
  const call = (data, uid = "staff") => manage({auth: {uid}, data: {...payload, ...data}});
  const draft = (petId, note) => call({mode: "draft", petId, values: {note}, revision: 0});
  assert.deepEqual((await call({mode: "read"})).pets.map((p) => p.id), ["a", "b"]);
  await assert.rejects(call({mode: "read"}, "sales"), {code: "permission-denied"});
  await assert.rejects(call({mode: "read"}, "customer"), {code: "permission-denied"});
  await assert.rejects(draft("another-order-pet", "x"), {code: "invalid-argument"});
  assert.equal((await draft("a", "栗子草稿")).revision, 1);
  assert.equal((await draft("b", "麻糬草稿")).revision, 1);
  const drafts = [...docs].find(([path]) => path.includes("staff_only"));
  const recordPath = drafts[0].split("/staff_only/")[0];
  assert.equal(docs.has(recordPath), false);
  await assert.rejects(draft("a", "stale"), {code: "aborted"});
  await call({mode: "publish", petId: "a", revision: 1, values: {note: "栗子回報"}});
  assert.equal(docs.get(recordPath).reportStatus, "partial");
  assert.deepEqual(Object.keys(docs.get(recordPath).petReports), ["a"]);
  assert.equal(docs.get(drafts[0]).drafts.b.values.note, "麻糬草稿");
  assert.equal((await call({mode: "publish", petId: "a", revision: 1})).published, true);
  await call({mode: "publish", petId: "b", revision: 1, values: {note: "麻糬回報"}});
  assert.equal(docs.get(recordPath).reportStatus, "completed");
  assert.deepEqual(docs.get(drafts[0]).drafts, {});
  docs.set("bookings/o", {...booking, settlementConfirmed: true});
  await assert.rejects(draft("a", "locked"), {code: "failed-precondition"});
});
