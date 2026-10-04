// 檔案名稱：functions/bookings/campaign_usage.test.js
// 功能說明：優惠 usageLimit 的計數規則、隱私欄位與 Flutter fail closed。

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  campaignUseDenial,
  countValidCampaignBookings,
  countsCampaignUse,
  toPublicUsage,
  usageAvailable,
} = require("./campaign_usage");

const shopId = "shopA";
const campaignId = "campA";

test("TEST C1 usageLimit 10 used 9 can be used", () => {
  assert.equal(usageAvailable(9, 10), true);
  assert.equal(campaignUseDenial({
    id: campaignId,
    shopId,
    enabled: true,
    type: "limitedTime",
    usedCount: 9,
    totalUsageLimit: 10,
  }, shopId, new Date()), null);
});

test("TEST C2 usageLimit 10 used 10 is denied", () => {
  assert.equal(usageAvailable(10, 10), false);
  assert.equal(campaignUseDenial({
    id: campaignId,
    shopId,
    enabled: true,
    type: "limitedTime",
    usedCount: 10,
    totalUsageLimit: 10,
  }, shopId, new Date()), "此優惠活動已達使用上限");
});

test("TEST C3 cancelled booking does not count", () => {
  assert.equal(countsCampaignUse("cancelled"), false);
  const used = countValidCampaignBookings([
    {id: "b1", shopId, discountCampaignId: campaignId, status: "cancelled"},
    {id: "b2", shopId, discountCampaignId: campaignId, status: "pending"},
  ], shopId, campaignId, "");
  assert.equal(used, 1);
});

test("TEST C4 another shop campaign is not counted", () => {
  const used = countValidCampaignBookings([
    {
      id: "b1",
      shopId: "shopB",
      discountCampaignId: campaignId,
      status: "confirmed",
    },
    {id: "b2", shopId, discountCampaignId: campaignId, status: "confirmed"},
  ], shopId, campaignId, "");
  assert.equal(used, 1);
});

test("TEST C5 fake campaign is denied", () => {
  assert.equal(campaignUseDenial(null, shopId, new Date()), "找不到優惠活動");
});

test("TEST C6 disabled campaign is denied", () => {
  assert.equal(campaignUseDenial({
    id: campaignId,
    shopId,
    enabled: false,
    type: "limitedTime",
    totalUsageLimit: 10,
    usedCount: 0,
  }, shopId, new Date()), "優惠活動未啟用");
});

test("TEST C7 expired campaign is denied", () => {
  assert.equal(campaignUseDenial({
    id: campaignId,
    shopId,
    enabled: true,
    type: "limitedTime",
    startAt: new Date("2020-01-01T00:00:00Z"),
    endAt: new Date("2020-01-02T00:00:00Z"),
    totalUsageLimit: 10,
    usedCount: 0,
  }, shopId, new Date("2026-10-04T00:00:00Z")),
  "優惠活動已過期");
});

test("TEST C8 customer usage does not query the whole shop", () => {
  const source = fs.readFileSync(path.resolve(
      __dirname, "../../lib/core/services/discount_campaign_service.dart",
  ), "utf8");
  const start = source.indexOf("Future<Map<String, int>> getCampaignTotalUsage");
  const end = source.indexOf("Stream<Map<String, int>> streamCampaignTotalUsage");
  const body = source.slice(start, end);
  assert.equal(body.includes("httpsCallable('getCampaignUsage')"), true);
  assert.equal(body.includes(".where('shopId'"), false);
  assert.equal(body.includes("collection('bookings')"), false);
});

test("TEST C9 usage payload has no private booking fields", () => {
  const row = toPublicUsage({
    campaignId,
    usedCount: 9,
    usageLimit: 10,
    bookingId: "secret",
    userId: "secret",
    customerName: "secret",
    petIds: ["secret"],
    paymentStatus: "paid",
  });
  assert.deepEqual(Object.keys(row).sort(), [
    "available",
    "campaignId",
    "remaining",
    "usageLimit",
    "usedCount",
  ]);
  assert.equal(JSON.stringify(row).includes("secret"), false);
  assert.equal(row.usedCount, 9);
  assert.equal(row.remaining, 1);
  assert.equal(row.available, true);
});

test("TEST C10 function error is not treated as usedCount 0", () => {
  const source = fs.readFileSync(path.resolve(
      __dirname, "../../lib/core/services/discount_campaign_service.dart",
  ), "utf8");
  const start = source.indexOf("Future<Map<String, int>> getCampaignTotalUsage");
  const end = source.indexOf("Stream<Map<String, int>> streamCampaignTotalUsage");
  const body = source.slice(start, end);
  assert.equal(body.includes("permission-denied"), false);
  assert.equal(body.includes("return <String, int>{}"), false);
  assert.equal(body.includes("暫時無法取得活動資訊"), true);
  const streamStart = source.indexOf("void emit()");
  const streamEnd = source.indexOf("final StreamSubscription");
  const streamBody = source.slice(streamStart, streamEnd);
  assert.equal(streamBody.includes("usageFailed"), true);
  assert.equal(streamBody.includes("return false"), true);
});
