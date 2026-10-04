// 檔案名稱：functions/daycare/daycare_capacity_emulator.test.js
// 功能說明：在 Firestore Emulator 上同時搶最後一個每日名額。
// 只在 FIRESTORE_EMULATOR_HOST 有設定時執行。

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  commitDailyCapacityReserve,
  readDailyCapacityReserve,
} = require("./daycare_capacity");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.log("skip: FIRESTORE_EMULATOR_HOST is not set");
  process.exit(0);
}

if (!admin.apps.length) {
  admin.initializeApp({projectId: "demo-petnest-capacity"});
}

const db = admin.firestore();
const shopId = "shopA";
const dateKey = "2026-10-04";

/**
 * @param {string} bookingId
 * @return {Promise<void>}
 */
async function reserveOne(bookingId) {
  const bookingRef = db.collection("bookings").doc(bookingId);
  await db.runTransaction(async (transaction) => {
    const again = await transaction.get(bookingRef);
    if (again.exists) {
      return;
    }
    const plan = await readDailyCapacityReserve(transaction, db, {
      shopId,
      dateKey,
      bookingId,
      requestedPets: 1,
    });
    if (!plan.ok) {
      const error = new Error(plan.reason);
      error.code = plan.code;
      throw error;
    }
    commitDailyCapacityReserve(transaction, plan);
    transaction.set(bookingRef, {
      shopId,
      status: "pending",
      bookingKind: "daycare",
      serviceDate: dateKey,
      petIds: ["pet"],
    });
  });
}

/**
 * @return {Promise<void>}
 */
async function main() {
  await db.collection("shops").doc(shopId)
      .collection("daycare_settings").doc("main")
      .set({dailyMaxPets: 5});
  await db.collection("shops").doc(shopId)
      .collection("daycare_capacity").doc(dateKey)
      .set({
        dateKey,
        reservedPets: 4,
        initialized: true,
      });
  const results = await Promise.allSettled([
    reserveOne("race-a"),
    reserveOne("race-b"),
  ]);
  const ok = results.filter((item) => item.status === "fulfilled");
  const denied = results.filter((item) => item.status === "rejected");
  const counter = await db.collection("shops").doc(shopId)
      .collection("daycare_capacity").doc(dateKey).get();
  const reservedPets = counter.data().reservedPets;
  console.log(JSON.stringify({
    success: ok.length,
    failed: denied.length,
    reservedPets,
    failure: denied[0] && denied[0].reason && denied[0].reason.message,
  }));
  assert.equal(ok.length, 1);
  assert.equal(denied.length, 1);
  assert.equal(reservedPets, 5);
}

main().then(() => {
  process.exit(0);
}).catch((error) => {
  console.error(error);
  process.exit(1);
});
