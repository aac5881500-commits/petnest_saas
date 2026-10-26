/* eslint-disable require-jsdoc */
const test = require("node:test");
const assert = require("node:assert/strict");
const cases = require("../../test/fixtures/store_access_cases.json");
const {hasStoreEntitlement, storeBusinessStatus, canAcceptStoreOrders} = require("./store_access");
const now = new Date("2026-10-26T15:59:59Z");
for (const row of cases) {
  test(row.name, () => {
    assert.equal(hasStoreEntitlement(row.shop, now), row.entitled);
    assert.equal(canAcceptStoreOrders(row.shop, row.settings, now), row.accept);
  });
}
test("台北午夜後期限屆滿", () => {
  const shop = {plan: "basic", paidUntilDate: "2026-10-26"};
  assert.equal(hasStoreEntitlement(shop, new Date("2026-10-26T16:00:00Z")), false);
});
test("舊 Timestamp 期限嚴格比較，模組欄位不影響資格", () => {
  const shop = {plan: "basic", paidUntil: {toDate: () => new Date(now.getTime() + 1)}};
  assert.equal(hasStoreEntitlement(shop, now), true);
  assert.equal(hasStoreEntitlement(shop, new Date(now.getTime() + 1)), false);
});
test("暫停與隱藏入口是不同設定", () => {
  const shop = {plan: "basic", paidUntilDate: "2027-01-01", homeAppearance: {modern: {showStoreBanner: false}}};
  assert.equal(canAcceptStoreOrders(shop, {businessStatus: "open"}, now), true);
  assert.equal(storeBusinessStatus({businessStatus: "paused"}), "paused");
});
