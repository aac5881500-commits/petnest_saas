/* eslint-disable require-jsdoc */
const {test} = require("node:test");
const assert = require("node:assert/strict");
const L = require("./medication_logic");
const setting = L.settings({enabled: true, types: ["oral", "eye"], mode: "visit", price: 50, mixFree: true, successOnly: true, windows: [{start: "09:00", end: "21:00"}]});
const booking = {shopId: "s", petIds: ["p", "q"], startDate: "2026-11-10T00:00:00+08:00", endDate: "2026-11-12T00:00:00+08:00", nights: 2};
function request() {
  return {careStart: "2026-11-10T15:00:00+08:00", careEnd: "2026-11-12T12:00:00+08:00", medicines: [{petId: "p", name: "A", type: "oral", dose: "1 顆", instruction: "按原指示", pills: 1, schedule: "fixed", times: ["09:00", "21:00"]}]};
}
function build(raw = request(), s = setting) {
  return L.initial(raw, booking, s, "u");
}
test("Taipei arrival and departure clip first/last day to four events", () => {
  const m = build(); assert.equal(m.tasks.length, 4); assert.equal(m.estimate.amount, 200);
  assert.equal(m.tasks[0].scheduledAt, "2026-11-10T13:00:00.000Z");
  assert.equal(m.tasks.at(-1).scheduledAt, "2026-11-12T01:00:00.000Z");
});
test("simultaneous medicines grouped, different cats separate, split types configurable", () => {
  const r = request(); r.medicines.push({...r.medicines[0], name: "B", type: "eye"});
  assert.equal(build(r).tasks.length, 4);
  assert.equal(build(r, {...setting, splitTypes: true}).tasks.length, 8);
  r.medicines[1].petId = "q"; assert.equal(build(r).tasks.length, 8);
});
test("mix-free does not hide paid medicine in same visit", () => {
  const r = request(); r.medicines[0].mix = true; assert.equal(build(r).estimate.amount, 0);
  r.medicines.push({...r.medicines[0], mix: false}); assert.equal(build(r).estimate.amount, 200);
});
test("success only excludes failures; skipped never charged; partial and mixed block final", () => {
  const m = build(); m.tasks.forEach((t) => t.result = "done"); m.tasks[0].result = "failed";
  assert.equal(L.quote(m.request, setting, m.tasks, booking, true).amount, 150);
  m.tasks[1].result = "skipped"; assert.equal(L.quote(m.request, setting, m.tasks, booking, true).amount, 100);
  for (const result of ["pending", "partial", "mixed"]) {
    m.tasks[2].result = result; assert.throws(() => L.quote(m.request, setting, m.tasks, booking, true), /待辦/);
  }
});
test("day, night, type and per-day thresholds", () => {
  assert.equal(build(request(), {...setting, mode: "day"}).estimate.amount, 100);
  assert.equal(build(request(), {...setting, mode: "night"}).estimate.amount, 100);
  assert.equal(build(request(), {...setting, includedTimes: 1}).estimate.manual, true);
  assert.equal(build(request(), {...setting, includedTimes: 2}).estimate.manual, false);
  const r = request(); r.medicines[0].pills = 4;
  assert.equal(build(r, {...setting, includedPills: 3}).estimate.manual, true);
});
test("interval starts at explicit boundary and outside hours require review", () => {
  const r = request(); r.medicines[0].schedule = "interval"; r.medicines[0].intervalHours = 12;
  const m = build(r); assert.equal(m.tasks.length, 4); assert.equal(m.tasks[0].scheduledAt, "2026-11-10T07:00:00.000Z"); assert.ok(m.issues.length);
});
test("custom schedules require a real proposal and cannot yield automatic amount", () => {
  const r = request(); r.medicines[0].schedule = "custom"; r.medicines[0].custom = "請聯繫";
  const m = build(r); assert.equal(m.tasks.length, 0); assert.equal(m.estimate.amount, null);
});
test("reject malformed, other-cat, unsupported type, cross-stay, foreign photo and disabled settings", () => {
  for (const modify of [(r) => r.medicines[0].petId = "x", (r) => r.medicines[0].type = "injection", (r) => r.medicines[0].times = ["25:00"], (r) => r.careStart = "2026-11-09T15:00:00+08:00", (r) => r.medicines[0].photoPath = "medication_uploads/other/s/a.jpg", (r) => r.medicines[0].dose = ""]) {
    const r = request(); modify(r); assert.throws(() => build(r));
  }
  assert.throws(() => build(request(), {...setting, enabled: false}));
});
test("medication period clips individual drug; empty schedule and reversed dates rejected", () => {
  const r = request(); r.medicines[0].from = "2026-11-11T00:00:00+08:00"; r.medicines[0].until = "2026-11-11T23:00:00+08:00";
  assert.equal(build(r).tasks.length, 2);
  r.careEnd = r.careStart; assert.throws(() => build(r));
});
test("checkout guard blocks unfinalized needs but permits refused or finalized", () => {
  assert.throws(() => L.checkoutGuard({medication: build()}));
  for (const medication of [null, {state: "declined"}, {state: "cancelled"}, {state: "confirmed", finalized: true}]) L.checkoutGuard({medication});
});
test("input size and automatic task count bounded", () => {
  const r = request(); r.medicines = Array(21).fill(r.medicines[0]); assert.throws(() => build(r));
  assert.throws(() => L.settings({...setting, price: -1}));
  assert.throws(() => L.settings({...setting, windows: [{start: "21:00", end: "09:00"}]}));
});

test("new daily pricing uses lodging days and preserves legacy snapshot calculations", () => {
  const m = build(request(), {...setting, mode: "day"});
  assert.equal(m.setting.dayRule, "stay_days");
  assert.equal(m.estimate.units, 2); assert.equal(m.estimate.amount, 100);
  const old = {...setting, mode: "day", dayRule: "service_dates"};
  assert.equal(L.quote(m.request, old, m.tasks, booking).amount, 150);
  assert.equal(L.quote(m.request, {...old, dayRule: "all_dates"}, m.tasks, booking).amount, 150);
  assert.equal(build(request(), {...setting, mode: "night"}).setting.mode, "day");
});
test("partial-period daily care charges only lodging days with eligible service", () => {
  const r = request(); r.medicines[0].from = "2026-11-11T00:00:00+08:00"; r.medicines[0].until = "2026-11-11T23:00:00+08:00";
  const m = build(r, {...setting, mode: "day"}); assert.equal(m.estimate.amount, 50);
  m.tasks.forEach((t) => t.result = "failed");
  assert.equal(L.quote(m.request, m.setting, m.tasks, booking, true).amount, 0);
});

test("booking time preferences require handover before any billable plan", () => {
  const raw = {preferences: [{petId: "p", times: ["21:00", "09:30", "09:30"]}]};
  const m = build(raw);
  assert.equal(m.state, "pending_shop");
  assert.deepEqual(m.request.preferences, [{petId: "p", times: ["09:30", "21:00"]}]);
  assert.deepEqual(m.request.medicines, []);
  assert.deepEqual(m.tasks, []);
  assert.equal(m.estimate.amount, null);
  assert.equal(L.validateRequest(m.request, booking, setting, "u"), null);
  for (const preference of [
    {petId: "x", times: ["09:00"]},
    {petId: "p", times: []},
    {petId: "p", times: ["09:15"]},
    {petId: "p", times: ["21:30"]},
  ]) {
    assert.throws(() => build({preferences: [preference]}));
  }
  assert.throws(() => build(raw, {...setting, enabled: false}));
});

test("preference pricing follows visit, lodging-day, split, and manual settings", () => {
  const raw = {preferences: [{petId: "p", times: ["09:30", "18:00"], types: ["oral", "eye"]}]};
  assert.equal(build(raw).estimate.amount, 200);
  assert.equal(build(raw, {...setting, mode: "day"}).estimate.amount, 100);
  assert.equal(build(raw, {...setting, splitTypes: true}).estimate.amount, 400);
  assert.equal(build(raw, {...setting, splitTypes: true, mode: "day"}).estimate.amount, 200);
  assert.equal(build(raw, {...setting, includedTimes: 1}).estimate.amount, null);
  assert.equal(build(raw, {...setting, mode: "quote"}).estimate.amount, null);
  assert.equal(build(raw, {...setting, mode: "free", includedTimes: 1}).estimate.amount, 0);
  assert.throws(() => build({preferences: [{...raw.preferences[0], types: ["unsupported"]}]}));
  assert.deepEqual(build(raw).tasks, []);
});

test("dated preferences charge only requested dates or times and preserve checkout day", () => {
  const one = {date: "2026-11-11", times: ["09:00", "13:00"]};
  const preference = {petId: "p", types: ["oral"], dates: [one]};
  const raw = {preferences: [preference]};
  const prepay = build(raw, {...setting, paymentTiming: "advance"});
  assert.equal(prepay.estimate.amount, 100);
  assert.equal(prepay.advanceAmount, 100);
  assert.equal(prepay.request.careStart, "2026-11-11T00:00:00+08:00");
  assert.equal(build(raw, {...setting, mode: "day"}).estimate.amount, 50);
  assert.equal(build(raw, {...setting, mode: "day"}).advanceAmount, 0);
  assert.equal(build(raw, {...setting, mode: "quote", paymentTiming: "advance"}).advanceAmount, 0);
  assert.equal(build(raw, {...setting, includedTimes: 1, paymentTiming: "advance"}).advanceAmount, 0);
  const checkout = {date: "2026-11-12", times: ["09:00"]};
  assert.equal(build({preferences: [{...preference, dates: [one, checkout]}]},
      {...setting, mode: "day"}).estimate.amount, 100);
  for (const dates of [[one, one], [{...one, date: "2026-11-13"}], [{...one, times: []}]]) {
    assert.throws(() => build({preferences: [{...preference, dates}]}));
  }
});

test("boundary days only use care windows even for legacy settings with handover limits", () => {
  const dates = [
    {date: "2026-11-10", times: ["09:00"]},
    {date: "2026-11-12", times: ["20:00"]},
  ];
  const raw = {preferences: [{petId: "p", types: ["oral"], dates}]};
  const order = build(raw, {...setting, checkInFrom: "15:30", checkOutUntil: "11:30"});
  assert.deepEqual(order.request.preferences[0].dates, dates);
  assert.equal(order.estimate.amount, 100);
  dates[1].times = ["21:30"];
  assert.throws(() => build(raw), /用藥時段已變更/);
});

test("multiple dated medicines per cat retain separate schedules and group billable visits", () => {
  const entry = (petId, type, times, extra = {}) => ({
    petId, types: [type], dates: [{date: "2026-11-11", times}], ...extra,
  });
  const oral = entry("p", "oral", ["09:00", "16:00"], {name: " 藥品 A ", dose: "原標示", note: "到店確認"});
  const eye = entry("p", "eye", ["09:00", "17:00"]);
  const secondOral = entry("p", "oral", ["09:00"]);
  const otherCat = entry("q", "eye", ["09:00"]);
  const raw = {preferences: [oral, eye, secondOral, otherCat]};
  const order = build(raw, {...setting, paymentTiming: "advance"});
  assert.equal(order.estimate.amount, 200);
  assert.equal(order.advanceAmount, 200);
  assert.deepEqual(order.request.preferences[0], {...oral, name: "藥品 A"});
  assert.equal(build(raw, {...setting, splitTypes: true}).estimate.amount, 250);
  assert.equal(build(raw, {...setting, mode: "day"}).estimate.amount, 100);
  assert.equal(build(raw, {...setting, mode: "day", splitTypes: true}).estimate.amount, 150);
  assert.equal(build(raw, {...setting, includedTimes: 2}).estimate.amount, null);
  assert.equal(build(raw, {...setting, includedTimes: 2, splitTypes: true}).estimate.amount, 250);
  assert.throws(() => build({preferences: Array(21).fill(oral)}), /二十筆/);
});
