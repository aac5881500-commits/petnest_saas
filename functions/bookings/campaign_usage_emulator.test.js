// 檔案名稱：functions/bookings/campaign_usage_emulator.test.js
// 功能說明：兩個請求同時搶優惠最後一次，只能成功一筆。
// 只在 FIRESTORE_EMULATOR_HOST 有設定時執行。

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");
const {
  commitCampaignUsageReserve,
  readCampaignUsageReserve,
  releaseCampaignUsage,
} = require("./campaign_usage");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.log("skip: FIRESTORE_EMULATOR_HOST is not set");
  process.exit(0);
}

if (!admin.apps.length) {
  admin.initializeApp({projectId: "demo-petnest-campaign"});
}

const db = admin.firestore();
const shopId = "shopA";
const campaignId = "campLimit";

/**
 * @param {string} bookingId
 * @param {number} limit
 * @return {Promise<void>}
 */
async function reserveOne(bookingId, limit) {
  const bookingRef = db.collection("bookings").doc(bookingId);
  await db.runTransaction(async (transaction) => {
    const again = await transaction.get(bookingRef);
    if (again.exists) {
      return;
    }
    const plan = await readCampaignUsageReserve(transaction, db, {
      shopId,
      campaignId,
      bookingId,
      limit,
    });
    commitCampaignUsageReserve(transaction, db, plan);
    transaction.set(bookingRef, {
      shopId,
      discountCampaignId: campaignId,
      status: "pending",
      userId: bookingId,
    });
  });
}

test("campaign usage concurrency", async () => {
  await db.recursiveDelete(db.collection("shops").doc(shopId));
  await db.recursiveDelete(db.collection("bookings"));
  await db.collection("shops").doc(shopId)
      .collection("discount_campaigns").doc(campaignId).set({
        shopId,
        enabled: true,
        type: "limitedTime",
        totalUsageLimit: 10,
      });
  const seeds = [];
  for (let i = 0; i < 9; i += 1) {
    seeds.push(db.collection("bookings").doc(`seed${i}`).set({
      shopId,
      discountCampaignId: campaignId,
      status: "pending",
      userId: `user${i}`,
    }));
  }
  await Promise.all(seeds);

  const results = await Promise.allSettled([
    reserveOne("raceA", 10),
    reserveOne("raceB", 10),
  ]);
  const success = results.filter((item) => item.status === "fulfilled");
  const failed = results.filter((item) => item.status === "rejected");
  const counter = await db.collection("shops").doc(shopId)
      .collection("campaign_usage").doc(campaignId).get();
  assert.equal(success.length, 1);
  assert.equal(failed.length, 1);
  assert.equal(counter.get("usedCount"), 10);

  const winnerId = success[0].status === "fulfilled" ?
    (await db.collection("bookings").doc("raceA").get()).exists ?
      "raceA" : "raceB" :
    "";
  const beforeRetry = counter.get("usedCount");
  await reserveOne(winnerId, 10);
  const retried = await db.collection("shops").doc(shopId)
      .collection("campaign_usage").doc(campaignId).get();
  assert.equal(retried.get("usedCount"), beforeRetry);

  await db.recursiveDelete(db.collection("shops").doc(shopId)
      .collection("campaign_usage"));
  await db.recursiveDelete(db.collection("bookings"));
  await db.collection("bookings").doc("oldBooking").set({
    shopId,
    discountCampaignId: campaignId,
    status: "confirmed",
    userId: "oldUser",
  });
  await reserveOne("freshBooking", 10);
  const initialized = await db.collection("shops").doc(shopId)
      .collection("campaign_usage").doc(campaignId).get();
  assert.equal(initialized.get("usedCount"), 2);
  await db.runTransaction(async (transaction) => {
    await releaseCampaignUsage(transaction, db, {
      shopId,
      campaignId,
      bookingId: "oldBooking",
    });
  });
  const released = await db.collection("shops").doc(shopId)
      .collection("campaign_usage").doc(campaignId).get();
  assert.equal(released.get("usedCount"), 1);
});
