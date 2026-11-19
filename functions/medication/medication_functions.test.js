/* eslint-disable require-jsdoc, max-len */
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const logic = require("./medication_logic");
class HttpsError extends Error {
  constructor(code, message) {
    super(message); this.code = code;
  }
}
function fixture() {
  const shop = {medicationSetting: {enabled: true, mode: "visit", price: 50, types: ["oral"], windows: [{start: "00:00", end: "23:59"}], successOnly: true}};
  const booking = {shopId: "s", userId: "u", petIds: ["p"], status: "checked_in", totalPrice: 1800, originalTotal: 2000, startDate: "2026-01-01T00:00:00+08:00", endDate: "2026-01-02T00:00:00+08:00", pets: [{petId: "p", name: "麻糬"}]};
  const request = {careStart: "2026-01-01T15:00:00+08:00", careEnd: "2026-01-02T12:00:00+08:00", medicines: [{petId: "p", type: "oral", name: "A", dose: "1 顆", instruction: "原指示", schedule: "fixed", times: ["21:00", "09:00"]}]};
  booking.medication = logic.initial(request, booking, shop.medicationSetting, "u");
  const docs = {"shops/s": shop, "bookings/b": booking};
  const ref = (path) => ({path, get: async () => ({exists: !!docs[path], data: () => structuredClone(docs[path])}), update: async (patch) => Object.assign(docs[path], patch)});
  const db = {collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}), runTransaction: async (fn) => fn({get: async (r) => r.get(), set: (r, p) => {
    docs[r.path] = p;
  }, update: (r, p) => Object.assign(docs[r.path], p)})};
  const firestore = () => db; firestore.FieldValue = {serverTimestamp: () => "server-now"};
  const exports = {};
  vm.runInNewContext(fs.readFileSync(require.resolve("./medication_functions"), "utf8"), {exports, Buffer, Date, console, require: (name) => {
    if (name === "firebase-admin") return {firestore};
    if (name.includes("inspection_write_guard")) return {HttpsError, onCall: (_, fn) => fn};
    if (name.includes("daycare_utils")) return {hasShopPermission: async (_, uid, permission) => uid === "owner" || (uid === "worker" && permission === "manage_bookings")};
    if (name === "./medication_logic") return logic;
    if (name.includes("booking_settlement_math")) return require(name);
    throw new Error(`Unexpected require ${name}`);
  }});
  const call = (action, extra = {}, uid = "owner") => exports.manageBookingMedication({auth: {uid}, data: {bookingId: "b", revision: docs["bookings/b"].medication?.revision, action, ...extra}});
  return {exports, docs, call};
}
test("permissions: unauthenticated, other customer, read-only staff cannot mutate", async () => {
  const f = fixture();
  await assert.rejects(f.exports.manageBookingMedication({data: {}}), {code: "unauthenticated"});
  await assert.rejects(f.call("propose", {}, "stranger"), {code: "permission-denied"});
  await assert.rejects(f.call("accept", {}, "other"), {code: "permission-denied"});
  await assert.rejects(f.exports.saveMedicationSetting({auth: {uid: "worker"}, data: {shopId: "s", setting: {}}}), {code: "permission-denied"});
});
test("proposal, customer acceptance, records, discounted final extra and retry safety", async () => {
  const f = fixture();
  await f.call("propose"); assert.equal(f.docs["bookings/b"].medication.state, "pending_customer");
  await f.call("accept", {}, "u");
  for (const task of f.docs["bookings/b"].medication.tasks) await f.call("record", {taskId: task.id, result: "done", actualAt: task.scheduledAt});
  await f.call("finalize");
  assert.equal(f.docs["bookings/b"].quotedTotalPrice, 1800);
  assert.equal(f.docs["bookings/b"].extraCharges.length, 1);
  assert.equal(f.docs["bookings/b"].extraCharges[0].amount, 100);
  await assert.rejects(f.call("finalize"), {code: "failed-precondition"});
  assert.equal(f.docs["bookings/b"].extraCharges.length, 1);
});
test("staff arrival confirmation publishes the edited schedule and allows results without app acceptance", async () => {
  const f = fixture();
  const booking = f.docs["bookings/b"];
  booking.status = "confirmed";
  const request = structuredClone(booking.medication.request);
  request.medicines[0].dose = "2 ml";
  request.medicines[0].schedule = "dated";
  request.medicines[0].dates = [
    {date: "2026-01-01", times: ["17:00"]},
    {date: "2026-01-02", times: ["10:00"]},
  ];
  await assert.rejects(f.call("confirmAtArrival", {request}, "u"), {code: "permission-denied"});
  await f.call("confirmAtArrival", {request}, "worker");
  assert.equal(booking.medication.state, "confirmed");
  assert.equal(booking.medication.request.medicines[0].dose, "2 ml");
  assert.equal(booking.medication.tasks[0].scheduledAt, "2026-01-01T09:00:00.000Z");
  assert.equal(f.docs["bookings/b/messages/medication_2"].senderType, "shop");
  assert.equal(booking.medication.tasks.length, 2);
  const [first, second] = booking.medication.tasks;
  assert.equal(second.scheduledAt, "2026-01-02T02:00:00.000Z");
  await assert.rejects(f.call("record", {taskId: first.id, result: "done", actualAt: first.scheduledAt}), {code: "failed-precondition"});
  booking.status = "checked_in";
  await f.call("record", {taskId: first.id, result: "done", actualAt: first.scheduledAt});
  await f.call("record", {taskId: second.id, result: "failed", actualAt: second.scheduledAt, note: "未成功"});
  assert.equal(booking.medication.tasks[0].actualAt, first.scheduledAt);
  assert.equal(booking.medication.tasks[1].result, "failed");
  await assert.rejects(f.call("confirmAtArrival", {request}), {code: "failed-precondition"});
});

test("arrival can leave details blank and recording can supplement only its own medicine", async () => {
  const f = fixture();
  const booking = f.docs["bookings/b"];
  const request = structuredClone(booking.medication.request);
  Object.assign(request.medicines[0], {name: "", dose: "", instruction: ""});
  await assert.rejects(f.call("propose", {request}), {code: "failed-precondition"});
  await f.call("confirmAtArrival", {request}, "worker");
  const [first, second] = booking.medication.tasks;
  const record = {taskId: first.id, result: "done", actualAt: first.scheduledAt};
  await assert.rejects(f.call("record", {...record, medicineDetails: {other: {name: "不相關"}}}), {code: "invalid-argument"});
  await f.call("record", {...record, medicineDetails: {m0: {name: "已核對藥品"}}});
  assert.equal(booking.medication.request.medicines[0].name, "已核對藥品");
  await f.call("record", {taskId: second.id, result: "done", actualAt: second.scheduledAt,
    medicineDetails: {m0: {name: "修正後藥品", dose: "依藥袋", instruction: "已核對"}}});
  const medicine = booking.medication.request.medicines[0];
  assert.equal(medicine.name, "修正後藥品");
  assert.equal(booking.medication.tasks[0].medicineDetailsSnapshot.m0.name, "已核對藥品");
  assert.equal(medicine.dose, "依藥袋");
  assert.equal(medicine.instruction, "已核對");
});

test("stale revision and duplicate administration rejected", async () => {
  const f = fixture(); await f.call("propose");
  await assert.rejects(f.call("accept", {revision: 1}, "u"), {code: "aborted"});
  await f.call("accept", {}, "u");
  const task = f.docs["bookings/b"].medication.tasks[0];
  await f.call("record", {taskId: task.id, result: "done", actualAt: task.scheduledAt});
  await assert.rejects(f.call("record", {taskId: task.id, result: "done", actualAt: task.scheduledAt}), {code: "failed-precondition"});
  await assert.rejects(f.call("propose"), {code: "failed-precondition"});
});
test("outside hours require explicit approval plus explanation", async () => {
  const f = fixture(); f.docs["bookings/b"].medication.setting.windows = [{start: "10:00", end: "20:00"}];
  await assert.rejects(f.call("propose"), {code: "failed-precondition"});
  await f.call("propose", {allowOutside: true, note: "已確認排班可配合"});
  assert.equal(f.docs["bookings/b"].medication.state, "pending_customer");
});
test("manual quote requires consent and final amount cannot exceed agreed total", async () => {
  const f = fixture(); f.docs["bookings/b"].medication.setting.mode = "quote";
  await assert.rejects(f.call("propose"), {code: "invalid-argument"});
  await f.call("propose", {agreedAmount: 200, note: "特殊照護共兩次"});
  await f.call("accept", {}, "u");
  for (const task of f.docs["bookings/b"].medication.tasks) await f.call("record", {taskId: task.id, result: "done", actualAt: task.scheduledAt});
  await assert.rejects(f.call("finalize", {finalAmount: 201, note: "超額"}), {code: "invalid-argument"});
  await f.call("finalize", {finalAmount: 150, note: "優惠減收"});
  assert.equal(f.docs["bookings/b"].medication.finalAmount, 150);
});
test("pending/partial records block finalization; settled orders reject writes", async () => {
  const f = fixture(); await f.call("propose"); await f.call("accept", {}, "u");
  await assert.rejects(f.call("finalize"), {code: "failed-precondition"});
  f.docs["bookings/b"].settlementConfirmed = true;
  await assert.rejects(f.call("record", {}), {code: "failed-precondition"});
});
test("customer rejection returns to shop; refusal preserves audit and no fees", async () => {
  const f = fixture(); await f.call("propose"); await f.call("reject", {note: "請調整時間"}, "u");
  assert.equal(f.docs["bookings/b"].medication.state, "pending_shop");
  await f.call("decline", {note: "無法配合此時間"});
  logic.checkoutGuard(f.docs["bookings/b"]);
  assert.equal(f.docs["bookings/b"].medication.history.length, 3);
});

test("different outcomes within one visit are final and bill only once", async () => {
  const f = fixture();
  const old = f.docs["bookings/b"].medication;
  old.request.medicines.push({...old.request.medicines[0], id: "m1", name: "B"});
  old.tasks.forEach((t) => t.medicineIds.push("m1"));
  await f.call("propose"); await f.call("accept", {}, "u");
  for (const t of f.docs["bookings/b"].medication.tasks) await f.call("record", {taskId: t.id, result: "done", medicineResults: {m0: "done", m1: "failed"}, actualAt: t.scheduledAt, note: "第二項未成功，已通知家長"});
  const task = f.docs["bookings/b"].medication.tasks[0];
  assert.equal(task.result, "partial"); assert.equal(task.finished, true);
  await assert.rejects(f.call("record", {taskId: task.id, result: "done", actualAt: task.scheduledAt}), {code: "failed-precondition"});
  await f.call("finalize"); assert.equal(f.docs["bookings/b"].medication.finalAmount, 100);
});
test("accepted price snapshot survives shop changes; notifications are transactionally recorded", async () => {
  const f = fixture(); await f.call("propose");
  assert.equal(f.docs["bookings/b/messages/medication_2"].senderType, "shop");
  assert.equal(f.docs["bookings/b"].customerUnreadMessageCount, 1);
  f.docs["shops/s"].medicationSetting.price = 999;
  await f.call("accept", {}, "u");
  assert.equal(f.docs["bookings/b"].medication.setting.price, 50);
});
test("manual fee cannot contradict successful-only policy when all attempts failed", async () => {
  const f = fixture(); f.docs["bookings/b"].medication.setting.mode = "quote";
  await f.call("propose", {agreedAmount: 200, note: "特殊安排"}); await f.call("accept", {}, "u");
  for (const t of f.docs["bookings/b"].medication.tasks) await f.call("record", {taskId: t.id, result: "failed", actualAt: t.scheduledAt, note: "未成功"});
  await assert.rejects(f.call("finalize", {finalAmount: 200, note: "仍收費"}), {code: "invalid-argument"});
  await f.call("finalize", {finalAmount: 0, note: "依規則未成功不收費"});
  assert.equal(f.docs["bookings/b"].medication.finalAmount, 0);
});

test("settlement preview is read-only and shows the authoritative amount", async () => {
  const f = fixture(); await f.call("propose"); await f.call("accept", {}, "u");
  for (const t of f.docs["bookings/b"].medication.tasks) await f.call("record", {taskId: t.id, result: "done", actualAt: t.scheduledAt});
  const revision = f.docs["bookings/b"].medication.revision;
  const preview = await f.call("previewFinal");
  assert.equal(preview.amount, 100); assert.equal(preview.units, 2);
  assert.equal(f.docs["bookings/b"].medication.revision, revision);
  assert.equal(f.docs["bookings/b"].medication.finalized, false);
});

test("advance is replaced with actual medication fee, reducing balance or creating refund", async () => {
  const {expectedTotal, settlementFields} = require("../bookings/booking_settlement_math");
  for (const paid of [1000, 1900]) {
    const f = fixture();
    const booking = f.docs["bookings/b"];
    Object.assign(booking, {quotedTotalPrice: 1800, totalPrice: 1900, paidAmount: paid});
    booking.medication.advanceAmount = 100;
    assert.equal(expectedTotal(booking), 1900);
    await f.call("propose");
    await f.call("accept", {}, "u");
    const [first, second] = booking.medication.tasks;
    await f.call("record", {taskId: first.id, result: "done", actualAt: first.scheduledAt});
    await f.call("record", {taskId: second.id, result: "failed", actualAt: second.scheduledAt, note: "未完成"});
    await f.call("finalize");
    assert.equal(booking.medication.finalAmount, 50);
    assert.equal(expectedTotal(booking), 1850);
    assert.equal(booking.totalPrice, 1850);
    assert.equal(booking.remainingAmount, Math.max(0, 1850 - paid));
    assert.equal(settlementFields(booking).refundDueAmount, Math.max(0, paid - 1850));
  }
});

test("staff must explain changing the medication type even at the same time", async () => {
  const f = fixture();
  const booking = f.docs["bookings/b"];
  const {request, setting} = booking.medication;
  const preferences = [{petId: "p", types: ["eye"], dates: [
    {date: "2026-01-01", times: ["21:00"]},
    {date: "2026-01-02", times: ["09:00"]},
  ]}];
  booking.medication = logic.initial({preferences}, booking,
      {...setting, types: ["oral", "eye"]}, "u");
  await assert.rejects(f.call("propose", {request}), /類型、日期或時間不同/);
  await f.call("propose", {request, note: "已依客人交接資料調整"});
  assert.deepEqual(booking.medication.request.preferences, preferences);
});

test("legacy requests can enter confirmation without silently changing payable amounts", async () => {
  const f = fixture();
  const booking = f.docs["bookings/b"];
  booking.medicationRequest = {preferences: [{petId: "p", types: ["oral"], times: ["21:00"]}]};
  delete booking.medication;
  await assert.rejects(f.call("prepareLegacy", {}, "u"), {code: "permission-denied"});
  booking.medicationRequest.expectedAdvanceAmount = 50;
  await assert.rejects(f.call("prepareLegacy"), {code: "failed-precondition"});
  delete booking.medicationRequest.expectedAdvanceAmount;
  await f.call("prepareLegacy");
  assert.equal(booking.medication.state, "pending_shop");
  assert.equal(booking.medication.advanceAmount, 0);
  assert.equal(booking.totalPrice, 1800);
  await f.call("prepareLegacy");
  assert.equal(booking.medication.revision, 1);
});
