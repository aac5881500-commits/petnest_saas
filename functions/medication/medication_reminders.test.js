/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const {reminderStage, sendMedicationReminders} = require("./medication_reminders");

test("reminders switch at the exact boundary and ignore completed tasks", () => {
  const task = {scheduledAt: "2026-11-11T01:30:00Z", result: "pending"};
  const at = Date.parse(task.scheduledAt);
  assert.equal(reminderStage(task, at - 15 * 60000 - 1), null);
  assert.equal(reminderStage(task, at - 15 * 60000), "soon");
  assert.equal(reminderStage(task, at), "due");
  assert.equal(reminderStage(task, at + 3600000), "due");
  assert.equal(reminderStage(task, at + 3600001), "overdue");
  assert.equal(reminderStage(task, at + 3 * 86400000), "overdue");
  assert.equal(reminderStage({...task, result: "partial"}, at + 3 * 86400000), "overdue");
  assert.equal(reminderStage({...task, finished: true}, at + 3 * 86400000), null);
  assert.equal(reminderStage({...task, finished: true}, at), null);
  assert.equal(reminderStage({...task, result: "failed"}, at), null);
});

test("each stage sends once to permitted staff and owner, even on repeated scans", async () => {
  const task = {id: "t0", scheduledAt: "2026-11-11T01:30:00Z", result: "pending"};
  const booking = {shopId: "s", status: "checked_in", medication: {state: "confirmed", tasks: [task]}};
  const delivered = new Set();
  const shop = {ownerUid: "owner", medicationSetting: {enabled: true}};
  const shopRef = {get: async () => ({exists: true, data: () => shop})};
  const ref = {collection: () => ({doc: (id) => ({id, delete: async () => delivered.delete(id)})})};
  const db = {
    collection: (name) => {
      if (name === "bookings") {
        return {where: () => ({get: async () => ({
          docs: [{id: "b", ref, data: () => booking}],
        })})};
      }
      if (name === "shops") return {doc: () => shopRef};
      return {where: () => ({get: async () => ({
        docs: [
          {data: () => ({uid: "owner", role: "owner"})},
          {data: () => ({uid: "worker", permissions: {manage_bookings: true}})},
          {data: () => ({uid: "other", permissions: {manage_bookings: false}})},
        ],
      })})};
    },
    runTransaction: async (handler) => handler({
      get: async (value) => {
        if (value === ref) return {data: () => booking};
        if (value === shopRef) return {data: () => shop};
        return {exists: delivered.has(value.id)};
      },
      create: (value) => delivered.add(value.id),
    }),
  };
  const pushes = [];
  const send = async (message) => pushes.push(message);
  const at = Date.parse(task.scheduledAt);
  shop.medicationSetting.enabled = false;
  await sendMedicationReminders(db, send, () => at - 60000);
  assert.equal(pushes.length, 0);
  shop.medicationSetting.enabled = true;
  await sendMedicationReminders(db, send, () => at - 60000);
  await sendMedicationReminders(db, send, () => at - 30000);
  await sendMedicationReminders(db, send, () => at);
  await sendMedicationReminders(db, send, () => at + 30000);
  assert.deepEqual(pushes.map((p) => p.userId), ["owner", "worker", "owner", "worker"]);
  assert.deepEqual(pushes.map((p) => p.title), ["用藥即將到點", "用藥即將到點", "用藥已到點", "用藥已到點"]);
  await sendMedicationReminders(db, send, () => at + 3600001);
  await sendMedicationReminders(db, send, () => at + 3600002);
  assert.equal(pushes.length, 6);
  assert.equal(pushes[4].title, "用藥逾時未登錄，請補登結果");
  await sendMedicationReminders(db, send, () => at + 86400000);
  assert.equal(pushes.length, 8);
  task.finished = true;
  await sendMedicationReminders(db, send, () => at + 2 * 86400000);
  assert.equal(pushes.length, 8);
  assert.ok(pushes.every((p) => p.data.bookingId === "b" && p.data.taskId === "t0"));
});
