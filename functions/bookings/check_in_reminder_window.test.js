"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {checkInReminderWindow} = require("./check_in_reminder_window");

test("Taipei tomorrow includes midnight and excludes next midnight", () => {
  const {start, end} = checkInReminderWindow(new Date("2026-10-27T02:00:00Z"));
  assert.equal(start.toISOString(), "2026-10-27T16:00:00.000Z");
  assert.equal(end.toISOString(), "2026-10-28T16:00:00.000Z");
  assert.ok(new Date("2026-10-28T00:00:00+08:00") >= start);
  assert.ok(new Date("2026-10-28T23:59:59+08:00") < end);
  assert.equal(new Date("2026-10-29T00:00:00+08:00").getTime(), end.getTime());
});

test("UTC previous date and year rollover use Taipei date", () => {
  const {start, end} = checkInReminderWindow(new Date("2026-12-31T16:30:00Z"));
  assert.equal(start.toISOString(), "2027-01-01T16:00:00.000Z");
  assert.equal(end.toISOString(), "2027-01-02T16:00:00.000Z");
});

test("leap month boundary remains a complete Taipei day", () => {
  const {start, end} = checkInReminderWindow(new Date("2028-02-28T02:00:00Z"));
  assert.equal(start.toISOString(), "2028-02-28T16:00:00.000Z");
  assert.equal(end.toISOString(), "2028-02-29T16:00:00.000Z");
});
