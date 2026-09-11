// 檔案名稱：functions/reports/shop_report_summary.test.js
// 功能說明：營運摘要差額更新；重複事件不可重複累加。

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  bookingMoney,
  bookingContribution,
  applyDelta,
  emptySummary,
} = require("./shop_report_summary");

test("bookingMoney 沿用結算金額優先", () => {
  assert.equal(bookingMoney({
    finalSettlementAmount: 1200,
    totalPrice: 900,
    extraFee: 50,
  }).orderAmount, 1200);
  assert.equal(bookingMoney({
    totalPrice: 900,
    extraFee: 50,
  }).orderAmount, 950);
});

test("同一訂單貢獻重送差額為 0", () => {
  const booking = {
    bookingKind: "accommodation",
    status: "confirmed",
    totalPrice: 1000,
    discountAmount: 100,
  };
  const next = bookingContribution(booking);
  const prev = bookingContribution(booking);
  const updated = applyDelta(emptySummary(), next, prev);
  assert.equal(updated.stayRevenue, 0);
  assert.equal(updated.stayOrderCount, 0);
});

test("狀態從 confirmed 改 completed 只補差額", () => {
  const prev = bookingContribution({
    bookingKind: "daycare",
    status: "confirmed",
    totalPrice: 800,
  });
  const next = bookingContribution({
    bookingKind: "daycare",
    status: "completed",
    totalPrice: 800,
  });
  const current = applyDelta(emptySummary(), prev, emptySummary());
  const updated = applyDelta(current, next, prev);
  assert.equal(updated.daycareRevenue, 800);
  assert.equal(updated.daycareOrderCount, 1);
  assert.equal(updated.completedCount, 1);
  assert.equal(updated.confirmedCount, 0);
});
