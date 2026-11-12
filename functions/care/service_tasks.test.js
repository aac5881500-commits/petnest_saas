/* eslint-disable require-jsdoc, max-len */
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs"); const vm = require("node:vm");
const {serviceTasks} = require("./service_tasks");
const {stageOf, sendServiceReminders} = require("./service_task_reminders");
const booking = () => ({shopId: "s", userId: "customer", status: "checked_in", startDate: "2026-01-01", totalPrice: 1800,
  addons: [{serviceId: "play", name: "陪玩", type: "daily_timed", selections: [{petId: "p1", dates: [{date: "2026-01-01", slotIds: ["s1"], slotLabels: ["09:30"]}]}]}]});
class HttpsError extends Error {
  constructor(code, message) {
    super(message); this.code = code;
  }
}
function fixture() {
  const docs = {"bookings/b": booking(), "shops/s": {ownerUid: "owner"}, "shops/s/addons/main": {enabled: true, dailyTimedServices: [{id: "play"}]}};
  const ref = (path) => ({path, get: async () => ({exists: !!docs[path], data: () => structuredClone(docs[path])}),
    collection: (name) => ({doc: (id) => ref(`${path}/${name}/${id}`)}), delete: async () => {
      delete docs[path];
    }});
  const db = {collection: (name) => ({doc: (id) => ref(`${name}/${id}`), where: () => ({get: async () => ({docs: name === "bookings" ? [{id: "b", ref: ref("bookings/b"), data: () => docs["bookings/b"]}] : [
    {data: () => ({uid: "worker", permissions: {manage_bookings: true}})}, {data: () => ({uid: "readonly", permissions: {}})},
  ]})})}), runTransaction: async (fn) => {
    const writes = []; const result = await fn({get: (r) => r.get(), set: (r, p) => writes.push(() => docs[r.path] = p), create: (r, p) => writes.push(() => docs[r.path] = p), update: (r, p) => writes.push(() => Object.assign(docs[r.path], p))}); writes.forEach((write) => write()); return result;
  }};
  const firestore = () => db; firestore.FieldValue = {serverTimestamp: () => "server-now"};
  const exports = {};
  vm.runInNewContext(fs.readFileSync(require.resolve("./service_task_functions"), "utf8"), {exports, Buffer, Date, require: (name) => {
    if (name === "firebase-admin") return {firestore};
    if (name.includes("inspection_write_guard")) return {onCall: (_, fn) => fn, HttpsError};
    if (name.includes("daycare_utils")) return {hasShopPermission: async (_, uid, permission) => ["owner", "worker"].includes(uid) && permission === "manage_bookings"};
    if (name === "./service_tasks") return require(name);
    throw Error(name);
  }});
  const task = serviceTasks(docs["bookings/b"])[0];
  const call = (data = {}, uid = "worker") => exports.recordBookingServiceTask({auth: uid ? {uid} : null, data: {bookingId: "b", taskId: task.id, scheduledAt: task.scheduledAt, result: "done", actualAt: task.scheduledAt, ...data}});
  return {docs, db, task, call};
}
test("stable service key separates pets, deduplicates slots and supports daycare midnight", () => {
  const b = booking(); const task = serviceTasks(b)[0];
  assert.deepEqual(JSON.parse(Buffer.from(task.id, "base64url").toString()), ["play", "p1", "2026-01-01", "s1"]);
  b.addons[0].selections.push({...b.addons[0].selections[0], petId: "p2"});
  b.addons.push(structuredClone(b.addons[0])); assert.equal(serviceTasks(b).length, 2);
  const d = serviceTasks({scheduledStartAt: "2026-11-10T22:00:00+08:00", addons: [{type: "dailyTimedServices", id: "p", selectedPetIds: ["p1"], selectedTimeSlots: [{id: "s", label: "01:00"}]}]});
  assert.equal(d[0].scheduledAt, "2026-11-10T17:00:00.000Z");
});
test("customer, unrelated shop and unauthenticated caller cannot record", async () => {
  const f = fixture(); for (const uid of [null, "customer", "other", "readonly"]) await assert.rejects(f.call({}, uid), {code: uid ? "permission-denied" : "unauthenticated"});
  assert.equal(f.docs["bookings/b"].careServiceRecords, undefined);
});
test("record once, notify once, share results without report and keep fees unchanged", async () => {
  const f = fixture(); await f.call();
  assert.equal(f.docs["bookings/b"].careServiceRecords[f.task.id].result, "done");
  assert.equal(f.docs["bookings/b"].totalPrice, 1800);
  assert.equal(f.docs["bookings/b"].customerUnreadMessageCount, 1);
  assert.equal(f.docs[`bookings/b/messages/care_${f.task.id}`].source, "care_service");
  await assert.rejects(f.call(), {code: "already-exists"});
  assert.equal(f.docs["bookings/b"].customerUnreadMessageCount, 1);
});
test("reject stale task, future/predating actual time and missing explanation", async () => {
  const f = fixture();
  await assert.rejects(f.call({scheduledAt: "2026-02-01"}), {code: "failed-precondition"});
  await assert.rejects(f.call({taskId: "another"}), {code: "failed-precondition"});
  await assert.rejects(f.call({actualAt: "2099-01-01"}), {code: "invalid-argument"});
  await assert.rejects(f.call({actualAt: "2020-01-01"}), {code: "invalid-argument"});
  await assert.rejects(f.call({result: "partial"}), {code: "invalid-argument"});
  await assert.rejects(f.call({result: "skipped"}), {code: "invalid-argument"});
  await f.call({result: "skipped", note: "家長要求取消，待確認費用"});
  assert.equal(serviceTasks(f.docs["bookings/b"])[0].record.result, "skipped");
  assert.equal(f.docs["bookings/b"].totalPrice, 1800);
});
test("records in the same check-in minute and distinguishes earlier or future times", async () => {
  const f = fixture();
  f.docs["bookings/b"].checkInAt = "2026-01-01T09:30:35+08:00";
  await assert.rejects(f.call({actualAt: "2026-01-01T09:29:00+08:00"}), /早於入住時間/);
  await assert.rejects(f.call({actualAt: "2099-01-01T09:30:00+08:00"}), /晚於現在/);
  await f.call();
  assert.equal(f.docs["bookings/b"].careServiceRecords[f.task.id].actualAt, f.task.scheduledAt);
});
test("cancelled, checkout and finalized bookings cannot accept new results", async () => {
  for (const status of ["cancelled", "checked_out", "completed", "pending", "confirmed"]) {
    const f = fixture(); f.docs["bookings/b"].status = status; await assert.rejects(f.call(), {code: "failed-precondition"});
  }
  for (const flag of ["settlementConfirmed", "settlementLocked", "settledAt"]) {
    const f = fixture(); f.docs["bookings/b"][flag] = true; await assert.rejects(f.call(), {code: "failed-precondition"});
  }
});
test("future services cannot be pre-completed; skipping requires a reason", async () => {
  const f = fixture(); f.docs["bookings/b"].addons[0].selections[0].dates[0].date = "2099-01-01";
  const t = serviceTasks(f.docs["bookings/b"])[0];
  await assert.rejects(f.call({taskId: t.id, scheduledAt: t.scheduledAt}), {code: "failed-precondition"});
  await f.call({taskId: t.id, scheduledAt: t.scheduledAt, result: "skipped", note: "已取消此項"});
});
test("soon/due transitions and completion stop service reminders", () => {
  const t = serviceTasks(booking())[0]; const at = Date.parse(t.scheduledAt);
  assert.equal(stageOf(t, at - 900001), null); assert.equal(stageOf(t, at - 900000), "soon");
  assert.equal(stageOf(t, at), "due"); assert.equal(stageOf(t, at + 3600001), null);
  assert.equal(stageOf({...t, record: {result: "skipped"}}, at), null);
});
test("reminders respect disabled setting, staff permission, dedup and fresh result", async () => {
  const f = fixture(); const sent = []; const send = async (p) => sent.push(p); const at = Date.parse(f.task.scheduledAt);
  f.docs["shops/s/addons/main"].enabled = false;
  await sendServiceReminders(f.db, send, () => at - 60000); assert.equal(sent.length, 0);
  f.docs["shops/s/addons/main"].enabled = true;
  await sendServiceReminders(f.db, send, () => at - 60000);
  await sendServiceReminders(f.db, send, () => at - 30000);
  await sendServiceReminders(f.db, send, () => at);
  await sendServiceReminders(f.db, send, () => at + 30000);
  assert.deepEqual(sent.map((p) => p.userId), ["owner", "worker", "owner", "worker"]);
  assert.ok(sent.every((p) => p.data.type === "staff_service_task" && p.data.taskId === f.task.id));
  await f.call(); await sendServiceReminders(f.db, send, () => at); assert.equal(sent.length, 4);
});
test("failed push releases its claim for retry", async () => {
  const f = fixture(); const at = Date.parse(f.task.scheduledAt); let attempts = 0;
  await sendServiceReminders(f.db, async () => {
    attempts++; throw Object.assign(new Error("Delivery unavailable"), {code: "unavailable"});
  }, () => at);
  await sendServiceReminders(f.db, async () => attempts++, () => at);
  assert.equal(attempts, 4);
});

test("legacy names resolve only when unique, and changing stay dates cannot orphan scheduled services", () => {
  const b = booking(); b.pets = [{petId: "p1", name: "小布"}];
  delete b.addons[0].selections[0].petId; b.addons[0].selections[0].petName = "小布";
  assert.equal(serviceTasks(b)[0].petId, "p1");
  const {fitsStayDates} = require("./service_tasks");
  assert.equal(fitsStayDates(b, "2026-01-01", "2026-01-02"), true);
  assert.equal(fitsStayDates(b, "2026-01-02", "2026-01-03"), false);
  b.pets.push({petId: "p2", name: "小布"}); assert.equal(serviceTasks(b)[0].petId, "");
});
