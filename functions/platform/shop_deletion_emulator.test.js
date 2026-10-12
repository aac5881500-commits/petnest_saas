"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");

const canRun = Boolean(
    process.env.FIRESTORE_EMULATOR_HOST &&
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
);

if (admin.apps.length === 0) {
  const projectId = process.env.GCLOUD_PROJECT || "petnest-saas-test";
  admin.initializeApp({
    projectId,
    storageBucket: `${projectId}.appspot.com`,
  });
}

const deletion = require("./shop_deletion")._test;

/**
 * @param {string} uid 管理員 UID
 * @param {Object} data Callable data
 * @return {Object}
 */
function request(uid, data) {
  return {
    auth: {
      uid,
      token: {
        auth_time: Math.floor(Date.now() / 1000),
        email: `${uid}@example.test`,
      },
    },
    data: data || {},
  };
}

test("Emulator：可信預覽區分 Auth 未掃描且不變更任何資料", {
  skip: !canRun,
  timeout: 120000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `super_${suffix}`;
  const ownerUid = `owner_${suffix}`;
  const otherOwnerUid = `other_${suffix}`;
  const shopId = `TEST${suffix}`;
  const otherShopId = `OTHER${suffix}`;
  const bookingId = `booking_${suffix}`;
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  await Promise.all([
    db.collection("platform_users").doc(superUid).set({
      role: "super_admin",
      enabled: true,
    }),
    db.collection("users").doc(ownerUid).set({
      email: `${ownerUid}@example.test`,
      shopIds: [shopId, otherShopId],
    }),
    db.collection("user_profiles").doc(ownerUid).set({
      displayName: "保留會員",
      shopIds: [shopId, otherShopId],
    }),
    db.collection("user_profiles").doc(ownerUid)
        .collection("pets").doc("pet1").set({name: "保留寵物"}),
    db.collection("users").doc(ownerUid)
        .collection("policy_acceptances").doc(shopId).set({
          shopId,
          userId: ownerUid,
        }),
    db.collection("user_profiles").doc(ownerUid)
        .collection("pets").doc("pet1")
        .collection("shop_form_answers").doc(shopId).set({
          shopId,
          answers: [],
        }),
    db.collection("shops").doc(shopId).set({
      shopId,
      shopCode: shopId,
      name: "隔離測試店",
      ownerUid,
      status: "active",
      isOpen: true,
      bookingEnabled: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection("shops").doc(shopId)
        .collection("rooms").doc("room1").set({name: "測試房"}),
    ...[1, 2, 3, 4].map((index) =>
      db.collection("shops").doc(shopId)
          .collection("members").doc(`member_${index}`).set({
            userId: `member_${index}`,
          })),
    db.collection("shop_members").doc(`${shopId}_${ownerUid}`).set({
      shopId,
      uid: ownerUid,
      role: "owner",
    }),
    db.collection("bookings").doc(bookingId).set({
      shopId,
      userId: ownerUid,
      status: "completed",
      paymentStatus: "unpaid",
    }),
    db.collection("bookings").doc(bookingId)
        .collection("messages").doc("m1").set({text: "測試訊息"}),
    db.collection("payments").doc(`pay_${suffix}`).set({
      shopId,
      bookingId,
      amount: 0,
      status: "pending",
    }),
    db.collection("reports").doc(`report_${suffix}`).set({
      shopId,
      bookingId,
    }),
    db.collection("daily_care_photo_usage").doc(`usage_${suffix}`).set({
      shopId,
      bookingId,
      used: 1,
    }),
    db.collection("booking_counters").doc(shopId).set({current: 9}),
    db.collection("payment_credentials").doc(shopId).set({
      merchantId: "TEST_ONLY",
    }),
    db.collection("sales_owner_locks").doc(ownerUid).set({
      uid: ownerUid,
      shopId,
    }),
    db.collection("sales_shop_create_requests").doc(`req_${suffix}`).set({
      uid: ownerUid,
      shopId,
    }),
    db.collection("shops").doc(otherShopId).set({
      shopId: otherShopId,
      shopCode: otherShopId,
      name: "其他店家",
      ownerUid: otherOwnerUid,
    }),
    db.collection("shop_members").doc(`${otherShopId}_${otherOwnerUid}`).set({
      shopId: otherShopId,
      uid: otherOwnerUid,
      role: "owner",
    }),
    db.collection("platform_media_library").doc(`shared_${suffix}`).set({
      storagePath: `platform/media_library/shared_${suffix}/cover.jpg`,
      enabled: true,
    }),
    bucket.file(`shops/${shopId}/logo.jpg`).save(Buffer.from("shop")),
    bucket.file(`booking_images/${bookingId}/proof.jpg`)
        .save(Buffer.from("booking")),
    bucket.file(`platform/media_library/shared_${suffix}/cover.jpg`)
        .save(Buffer.from("shared")),
  ]);

  const preview = await deletion.previewHandler(
      request(superUid, {shopId}),
  );
  assert.equal(preview.shop.shopId, shopId);
  assert.equal(preview.scan.complete, false);
  assert.equal(preview.scan.status, "partial");
  assert.equal(preview.firestore.complete, true);
  assert.equal(preview.storage.complete, true);
  assert.equal(preview.scan.projectId, "petnest-saas-test");
  assert.equal(preview.scan.region, "asia-east1");
  assert.equal(preview.transactions.bookingCount, 1);
  assert.equal(preview.transactions.stayBookingCount, 1);
  assert.equal(preview.transactions.daycareBookingCount, 0);
  assert.equal(
      preview.firestore.memberCounts
          .find((row) => row.label === "店家會員").count,
      4,
  );
  assert.ok(preview.storage.fileCount >= 2);
  assert.ok(preview.blockers.some((row) => row.includes("第一階段")));

  await assert.rejects(
      deletion.createJobHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        reason: "Emulator 第一階段不可建立刪除工作",
        typedShopCode: shopId,
        irreversibleAcknowledged: true,
        testDataConfirmed: true,
      })),
      /第一階段只開放可信預覽/,
  );
  await assert.rejects(
      deletion.runJobHandler(request(superUid, {jobId: "never-created"})),
      /第一階段禁止執行/,
  );

  assert.equal((await db.collection("shops").doc(shopId).get()).exists, true);
  assert.equal((await db.collection("bookings").doc(bookingId).get()).exists,
      true);
  assert.equal((await db.collection("payment_credentials")
      .doc(shopId).get()).exists, true);
  assert.deepEqual(
      (await db.collection("users").doc(ownerUid).get()).get("shopIds"),
      [shopId, otherShopId],
  );
  assert.equal(
      (await db.collection("shops").doc(otherShopId).get()).exists,
      true,
  );
  assert.equal(
      (await db.collection("shop_members")
          .doc(`${otherShopId}_${otherOwnerUid}`).get()).exists,
      true,
  );
  assert.equal(
      (await bucket.file(
          `platform/media_library/shared_${suffix}/cover.jpg`,
      ).exists())[0],
      true,
  );
});

test("Emulator：非最高管理員不能預覽或執行", {
  skip: !canRun,
  timeout: 30000,
}, async () => {
  const suffix = Date.now().toString();
  const staffUid = `staff_${suffix}`;
  await admin.firestore().collection("platform_users").doc(staffUid).set({
    role: "platform_staff",
    enabled: true,
  });
  await assert.rejects(
      deletion.previewHandler(request(staffUid, {shopId: "NONE"})),
      /只有平台最高管理員/,
  );
  await assert.rejects(
      deletion.runJobHandler(request(staffUid, {jobId: "NONE"})),
      /只有平台最高管理員/,
  );
});

test("Emulator：未知 shopId 集合會阻止刪除", {
  skip: !canRun,
  timeout: 30000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `super_unknown_${suffix}`;
  const shopId = `UNKNOWN${suffix}`;
  const db = admin.firestore();
  await Promise.all([
    db.collection("platform_users").doc(superUid).set({
      role: "super_admin",
      enabled: true,
    }),
    db.collection("shops").doc(shopId).set({
      shopId,
      shopCode: shopId,
      name: "未知集合測試店",
      status: "active",
    }),
    db.collection("future_unknown_data").doc(`u_${suffix}`).set({shopId}),
  ]);
  const preview = await deletion.previewHandler(
      request(superUid, {shopId}),
  );
  assert.ok(preview.manual.length > 0);
  await assert.rejects(
      deletion.createJobHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        reason: "未知集合應該阻止完整刪除工作",
        typedShopCode: shopId,
        irreversibleAcknowledged: true,
        testDataConfirmed: true,
      })),
      /第一階段只開放可信預覽/,
  );
});
