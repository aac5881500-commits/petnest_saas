// 檔案名稱：functions/daycare/daycare_utils.test.js
// 功能說明：無時區 ISO 當台灣時間；Timestamp 與 UTC ISO 不加 8 小時

const test = require("node:test");
const assert = require("node:assert/strict");
const {toDate, taiwanDate} = require("./daycare_utils");

test("台灣 2026-09-13 15:40 無時區字串讀回仍是 15:40", () => {
  const parsed = toDate("2026-09-13T15:40:00.000");
  assert.ok(parsed);
  assert.equal(parsed.toISOString(), "2026-09-13T07:40:00.000Z");
  const tw = taiwanDate(parsed);
  assert.equal(tw.getUTCFullYear(), 2026);
  assert.equal(tw.getUTCMonth(), 8);
  assert.equal(tw.getUTCDate(), 13);
  assert.equal(tw.getUTCHours(), 15);
  assert.equal(tw.getUTCMinutes(), 40);
});

test("UTC ISO 結尾 Z 不再加 8 小時", () => {
  const parsed = toDate("2026-09-13T07:40:00.000Z");
  assert.equal(parsed.toISOString(), "2026-09-13T07:40:00.000Z");
  const tw = taiwanDate(parsed);
  assert.equal(tw.getUTCHours(), 15);
  assert.equal(tw.getUTCMinutes(), 40);
});

test("Firestore Timestamp.toDate 不再加 8 小時", () => {
  const stamp = {
    toDate: () => new Date("2026-09-13T07:40:00.000Z"),
  };
  const parsed = toDate(stamp);
  assert.equal(parsed.toISOString(), "2026-09-13T07:40:00.000Z");
});
