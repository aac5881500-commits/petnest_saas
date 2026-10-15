"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");

const canRun = Boolean(
    process.env.FIRESTORE_EMULATOR_HOST &&
    process.env.FIREBASE_STORAGE_EMULATOR_HOST &&
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
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

/**
 * 用注入的寄信函式取得綁定本次掃描的六位數驗證碼。
 * @param {string} uid 最高管理員
 * @param {string} shopId 店家
 * @param {string} scanId 掃描
 * @return {Promise<{emailChallengeId: string, emailCode: string}>}
 */
async function issueDeletionCode(uid, shopId, scanId) {
  try {
    const user = await admin.auth().getUser(uid);
    if (user.emailVerified !== true) {
      await admin.auth().updateUser(uid, {
        email: user.email || `${uid}@example.test`,
        emailVerified: true,
      });
    }
  } catch (error) {
    if (textCode(error) !== "auth/user-not-found") throw error;
    await admin.auth().createUser({
      uid,
      email: `${uid}@example.test`,
      emailVerified: true,
    });
  }
  let code = "";
  deletion.setDeletionEmailSender(async (message) => {
    const match = String(message.text).match(/驗證碼：(\d{6})/);
    code = match ? match[1] : "";
  });
  const issued = await deletion.requestEmailCodeHandler(request(uid, {
    shopId,
    mode: "test_reset",
    previewScanId: scanId,
  }));
  if (!/^\d{6}$/.test(code)) {
    throw new Error("測試寄信沒有取得驗證碼");
  }
  return {emailChallengeId: issued.challengeId, emailCode: code};
}

function textCode(error) {
  return error && error.code ? String(error.code) : "";
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
        .collection("pets").doc("pet1").set({
          name: "保留寵物",
          photoUrl:
            `https://firebasestorage.googleapis.com/v0/b/test/o/` +
            `pets%2F${ownerUid}%2Fpet1.jpg?alt=media`,
        }),
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
      logoUrl:
        `https://firebasestorage.googleapis.com/v0/b/test/o/` +
        `shops%2F${shopId}%2Flogo.jpg?alt=media`,
      platformImageUrl:
        `https://firebasestorage.googleapis.com/v0/b/test/o/` +
        `platform%2Fmedia_library%2Fshared_${suffix}%2Fcover.jpg?alt=media`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection("shops").doc(shopId)
        .collection("rooms").doc("room1").set({name: "測試房"}),
    db.collection("shops").doc(shopId)
        .collection("store_orders").doc("order1").set({
          shopId,
          paymentStatus: "paid",
          totalAmount: 100,
        }),
    ...[1, 2, 3, 4].map((index) =>
      db.collection("shops").doc(shopId)
          .collection("members").doc(`member_${index}`).set({
            userId: `member_${index}`,
          })),
    db.collection("shops").doc(shopId).collection("members").doc("member_1")
        .collection("pets").doc("pet1").set({
          name: "店家快取寵物",
          photoUrl:
            `https://firebasestorage.googleapis.com/v0/b/test/o/` +
            `pets%2F${ownerUid}%2Fpet1.jpg?alt=media`,
        }),
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
      paymentProofs: [{
        storagePath: `booking_images/${bookingId}/proof.jpg`,
      }],
    }),
    db.collection("reviews").doc(`review_${suffix}`).set({
      shopId,
      bookingId,
      userId: ownerUid,
      imageUrls: [
        `https://firebasestorage.googleapis.com/v0/b/test/o/` +
          `review_images%2F${bookingId}%2Freview.jpg?alt=media`,
      ],
    }),
    db.collection("reviews").doc(`other_review_${suffix}`).set({
      shopId: otherShopId,
      bookingId,
      userId: otherOwnerUid,
      imageUrls: [
        `https://firebasestorage.googleapis.com/v0/b/test/o/` +
          `review_images%2F${bookingId}%2Freview.jpg?alt=media`,
      ],
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
    db.collection("legal_pet_license_links").doc(`license_${suffix}`).set({
      certifiedShopId: shopId,
      candidateShopIds: [shopId, otherShopId],
    }),
    db.collection("legal_pet_license_links")
        .doc(`candidate_license_${suffix}`).set({
          certifiedShopId: otherShopId,
          candidateShopIds: [shopId],
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
    bucket.file(`booking_images/${bookingId}/orphan.jpg`)
        .save(Buffer.from("orphan")),
    bucket.file(`review_images/${bookingId}/review.jpg`)
        .save(Buffer.from("review")),
    bucket.file(`pets/${ownerUid}/pet1.jpg`).save(Buffer.from("pet")),
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
  assert.equal(preview.storage.complete, false);
  assert.equal(preview.consistency.complete, true);
  assert.equal(preview.consistency.firestore.difference, 0);
  assert.equal(preview.consistency.storage.difference, 0);
  assert.equal(preview.consistency.storage.unresolvedOwnershipCount, 1);
  assert.equal(preview.scan.projectId, "petnest-saas-test");
  assert.equal(preview.scan.region, "asia-east1");
  assert.equal(preview.transactions.bookingCount, 1);
  assert.equal(preview.transactions.stayBookingCount, 1);
  assert.equal(preview.transactions.daycareBookingCount, 0);
  assert.equal(preview.firestore.bookingSubcollectionCount, 1);
  assert.equal(preview.firestore.bookingSubcollections.messages, 1);
  const legalLinks = preview.firestore.collections
      .find((row) => row.collection === "legal_pet_license_links");
  assert.equal(legalLinks.count, 2);
  assert.equal(legalLinks.classification, "manual");
  assert.equal(legalLinks.deduplicated, true);
  assert.equal(
      preview.ownership.mustRetain.items
          .find((row) => row.source.endsWith("/store_orders")).count,
      1,
  );
  assert.equal(
      preview.firestore.memberCounts
          .find((row) => row.label === "店家會員").count,
      4,
  );
  assert.ok(preview.storage.fileCount >= 2);
  assert.equal(
      preview.ownership.mustRetain.items
          .find((row) => row.source === "booking_images/…").count,
      1,
  );
  assert.equal(
      preview.ownership.manual.items
          .find((row) => row.source === "review_images/…").ownership,
      "confirmed",
  );
  assert.equal(
      preview.ownership.manual.items
          .find((row) => row.source === "booking_images/…").count,
      1,
  );
  assert.equal(
      preview.ownership.safeDelete.items
          .find((row) => row.source === "shops/…").count,
      1,
  );
  assert.equal(
      preview.ownership.shared.items
          .find((row) => row.source.startsWith("pets/{uid}/")).count,
      1,
  );
  assert.equal(
      preview.ownership.shared.items
          .find((row) => row.source === "平台／共用 Storage 引用").count,
      1,
  );
  assert.equal(
      preview.ownership.shared.items
          .find((row) => row.source === "user_profiles.shopIds")
          .sharedWithOtherShopsCount,
      1,
  );
  assert.equal(preview.execution.testResetAllowed, false);

  await assert.rejects(
      deletion.createJobHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        previewScanId: preview.scan.scanId,
        reason: "Emulator 不完整掃描不可建立刪除工作",
        typedShopCode: shopId,
        irreversibleAcknowledged: true,
        scopeConfirmed: true,
        testDataConfirmed: true,
      })),
      /掃描未完整|人工確認|Storage/,
  );
  await assert.rejects(
      deletion.runJobHandler(request(superUid, {jobId: "never-created"})),
      /找不到刪除工作/,
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

test("Emulator：安全測試店可分批清理且保留共用帳號與照片", {
  skip: !canRun,
  timeout: 120000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `cleanup_super_${suffix}`;
  const ownerUid = `cleanup_owner_${suffix}`;
  const shopId = `CLEAN${suffix}`;
  const otherShopId = `KEEP${suffix}`;
  const bookingId = `clean_booking_${suffix}`;
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  await admin.auth().createUser({
    uid: ownerUid,
    email: `${ownerUid}@example.test`,
  });
  await Promise.all([
    db.collection("platform_users").doc(superUid).set({
      role: "super_admin",
      enabled: true,
    }),
    db.collection("shops").doc(shopId).set({
      shopId,
      shopCode: shopId,
      name: "可安全清理測試店",
      ownerUid,
      status: "active",
      activationCodeId: `code_${suffix}`,
      logoUrl:
        `https://firebasestorage.googleapis.com/v0/b/test/o/` +
        `shops%2F${shopId}%2Flogo.jpg?alt=media`,
    }),
    db.collection("shops").doc(shopId)
        .collection("rooms").doc("room1").set({name: "測試房"}),
    db.collection("shops").doc(shopId)
        .collection("store_orders").doc("test_order").set({
          status: "cancelled",
          paymentStatus: "unpaid",
        }),
    db.collection("shops").doc(shopId)
        .collection("members").doc(ownerUid).set({
          userId: ownerUid,
          photoUrl:
            `https://firebasestorage.googleapis.com/v0/b/test/o/` +
            `pets%2F${ownerUid}%2Fpet.jpg?alt=media`,
        }),
    db.collection("shop_members").doc(`${shopId}_${ownerUid}`).set({
      shopId,
      uid: ownerUid,
      role: "owner",
    }),
    db.collection("users").doc(ownerUid).set({
      email: `${ownerUid}@example.test`,
      shopIds: [shopId, otherShopId],
    }),
    db.collection("user_profiles").doc(ownerUid).set({
      shopIds: [shopId, otherShopId],
    }),
    db.collection("shops").doc(otherShopId).set({
      shopId: otherShopId,
      shopCode: otherShopId,
      name: "必須保留的其他店家",
      ownerUid,
    }),
    db.collection("bookings").doc(bookingId).set({
      shopId,
      userId: ownerUid,
      status: "cancelled",
      paymentStatus: "unpaid",
    }),
    db.collection("bookings").doc(bookingId)
        .collection("messages").doc("m1").set({text: "測試訊息"}),
    db.collection("payments").doc(`pending_${suffix}`).set({
      shopId,
      bookingId,
      amount: 500,
      status: "pending",
    }),
    db.collection("daily_care_photos").doc(`photo_${suffix}`).set({
      shopId,
      bookingId,
      previewStoragePath:
        `daily_care_photos/${shopId}/${bookingId}/room/date/0/p1/preview.jpg`,
    }),
    db.collection("action_logs").doc(`audit_${suffix}`).set({
      shopId,
      action: "subscription_payment_confirmed",
    }),
    db.collection("action_logs").doc(`ops_${suffix}`).set({
      shopId,
      action: "test-created",
    }),
    db.collection("shop_commercial").doc(shopId).set({
      shopId,
      paidServiceUntil: "",
      plan: "free",
    }),
    db.collection("activation_codes").doc(`code_${suffix}`)
        .collection("usage_logs").doc(shopId).set({
          shopId,
          plan: "free",
        }),
    db.collection("sales_owner_locks").doc(ownerUid).set({
      shopId,
      uid: ownerUid,
    }),
    bucket.file(`shops/${shopId}/logo.jpg`).save(Buffer.from("shop-logo")),
    bucket.file(
        `daily_care_photos/${shopId}/${bookingId}/room/date/0/p1/preview.jpg`,
    ).save(Buffer.from("daily-care")),
    bucket.file(`pets/${ownerUid}/pet.jpg`).save(Buffer.from("customer-pet")),
  ]);

  const preview = await deletion.previewHandler(
      request(superUid, {shopId}),
  );
  assert.equal(
      preview.scan.complete,
      true,
      JSON.stringify({
        status: preview.scan.status,
        failures: preview.scan.failures,
        warnings: preview.scan.warnings,
        shop: preview.shop,
        blockers: preview.blockers,
        issues: preview.blockingIssues,
      }),
  );
  assert.equal(preview.execution.testResetAllowed, true);
  assert.ok(preview.ownership.safeDelete.firestoreCount > 0);
  assert.equal(preview.ownership.safeDelete.storageCount, 2);

  await assert.rejects(
      deletion.createJobHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        previewScanId: preview.scan.scanId,
        reason: "尚未完成 Email 驗證不得建立工作",
        typedShopCode: shopId,
        irreversibleAcknowledged: true,
        scopeConfirmed: true,
        testDataConfirmed: true,
      })),
      /Email 六位數驗證/,
  );
  const proof = await issueDeletionCode(
      superUid,
      shopId,
      preview.scan.scanId,
  );
  const created = await deletion.createJobHandler(request(superUid, {
    shopId,
    mode: "test_reset",
    previewScanId: preview.scan.scanId,
    reason: "Emulator 隔離測試店完整清理驗證",
    typedShopCode: shopId,
    irreversibleAcknowledged: true,
    scopeConfirmed: true,
    testDataConfirmed: true,
    emailChallengeId: proof.emailChallengeId,
    emailCode: proof.emailCode,
  }));
  let job = created;
  for (let index = 0;
    index < 100 && job.status !== "completed";
    index += 1) {
    job = await deletion.runJobHandler(
        request(superUid, {jobId: created.jobId}),
    );
  }
  assert.equal(job.status, "completed");
  assert.ok(job.deletedFirestore >= 8);
  assert.equal(job.deletedStorage, 2);
  assert.ok(job.deletedStorageBytes > 0);
  const repeated = await deletion.runJobHandler(
      request(superUid, {jobId: created.jobId}),
  );
  assert.equal(repeated.status, "completed");
  assert.equal(repeated.deletedFirestore, job.deletedFirestore);
  assert.equal(repeated.deletedStorage, job.deletedStorage);
  assert.equal((await db.collection("shops").doc(shopId).get()).exists, false);
  assert.equal((await db.collection("bookings").doc(bookingId).get()).exists,
      false);
  assert.equal((await db.collection("payments")
      .doc(`pending_${suffix}`).get()).exists, false);
  assert.equal((await db.collection("action_logs")
      .doc(`audit_${suffix}`).get()).exists, true);
  assert.equal((await db.collection("action_logs")
      .doc(`ops_${suffix}`).get()).exists, false);
  assert.equal((await db.collection("shop_commercial").doc(shopId).get())
      .exists, false);
  assert.equal((await db.collection("activation_codes").doc(`code_${suffix}`)
      .collection("usage_logs").doc(shopId).get()).exists, false);
  assert.equal((await db.collection("sales_owner_locks").doc(ownerUid).get())
      .exists, false);
  assert.equal((await db.collection("user_profiles").doc(ownerUid).get())
      .exists, true);
  assert.equal((await db.collection("users").doc(ownerUid).get()).exists, true);
  assert.deepEqual(
      (await db.collection("users").doc(ownerUid).get()).get("shopIds"),
      [otherShopId],
  );
  assert.deepEqual(
      (await db.collection("user_profiles").doc(ownerUid).get()).get("shopIds"),
      [otherShopId],
  );
  assert.equal((await db.collection("shops").doc(otherShopId).get()).exists,
      true);
  assert.equal((await bucket.file(`pets/${ownerUid}/pet.jpg`).exists())[0],
      true);
  assert.equal(
      (await db.collection("retired_shop_codes").doc(shopId).get()).exists,
      true,
  );
});

test("Emulator：180 天以上且零交易的閒置店可安全清理", {
  skip: !canRun,
  timeout: 120000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `idle_super_${suffix}`;
  const ownerUid = `idle_owner_${suffix}`;
  const shopId = `IDLE${suffix}`;
  const oldActivity = admin.firestore.Timestamp.fromMillis(
      Date.now() - 200 * 24 * 60 * 60 * 1000,
  );
  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  await admin.auth().createUser({
    uid: ownerUid,
    email: `${ownerUid}@example.test`,
  });
  await Promise.all([
    db.collection("platform_users").doc(superUid).set({
      role: "super_admin",
      enabled: true,
    }),
    db.collection("shops").doc(shopId).set({
      shopId,
      shopCode: shopId,
      name: "長期閒置測試店",
      ownerUid,
      lastActivityAt: oldActivity,
    }),
    db.collection("shop_members").doc(`${shopId}_${ownerUid}`).set({
      shopId,
      uid: ownerUid,
      role: "owner",
    }),
    db.collection("users").doc(ownerUid).set({
      email: `${ownerUid}@example.test`,
      shopIds: [shopId],
    }),
    db.collection("user_profiles").doc(ownerUid).set({shopIds: [shopId]}),
    bucket.file(`shops/${shopId}/old-banner.jpg`)
        .save(Buffer.from("idle-banner")),
  ]);

  const preview = await deletion.previewHandler(
      request(superUid, {shopId}),
  );
  assert.equal(preview.scan.complete, true);
  assert.equal(preview.execution.inactiveCleanupAllowed, true);
  const proof = await issueDeletionCode(
      superUid,
      shopId,
      preview.scan.scanId,
  );
  const created = await deletion.createJobHandler(request(superUid, {
    shopId,
    mode: "inactive_cleanup",
    previewScanId: preview.scan.scanId,
    reason: "Emulator 長期閒置且零交易店家清理",
    typedShopCode: shopId,
    irreversibleAcknowledged: true,
    scopeConfirmed: true,
    testDataConfirmed: false,
    emailChallengeId: proof.emailChallengeId,
    emailCode: proof.emailCode,
  }));
  let job = created;
  for (let index = 0;
    index < 100 && job.status !== "completed";
    index += 1) {
    job = await deletion.runJobHandler(
        request(superUid, {jobId: created.jobId}),
    );
  }
  assert.equal(job.status, "completed");
  assert.equal((await db.collection("shops").doc(shopId).get()).exists, false);
  assert.equal((await db.collection("users").doc(ownerUid).get()).exists, true);
  assert.deepEqual(
      (await db.collection("users").doc(ownerUid).get()).get("shopIds"),
      [],
  );
  assert.equal(
      (await bucket.file(`shops/${shopId}/old-banner.jpg`).exists())[0],
      false,
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
        previewScanId: preview.scan.scanId,
        reason: "未知集合應該阻止完整刪除工作",
        typedShopCode: shopId,
        irreversibleAcknowledged: true,
        scopeConfirmed: true,
        testDataConfirmed: true,
      })),
      /掃描未完整|尚未確認歸屬/,
  );
});

test("Emulator：Email 驗證碼綁定店家且不可重用", {
  skip: !canRun,
  timeout: 120000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `mail_super_${suffix}`;
  const shopId = `MAIL${suffix}`;
  const otherShopId = `OTHERMAIL${suffix}`;
  const db = admin.firestore();
  await db.collection("platform_users").doc(superUid).set({
    role: "super_admin",
    enabled: true,
  });
  await db.collection("platform_users").doc(`staff_${suffix}`).set({
    role: "platform_admin",
    enabled: true,
  });
  await admin.auth().createUser({
    uid: superUid,
    email: `${superUid}@example.test`,
    emailVerified: true,
  });
  const scanId = `scan_${suffix}`;
  await db.collection("shop_deletion_preview_grants").doc(scanId).set({
    uid: superUid,
    shopId,
    fingerprint: "test-fingerprint",
    contractVersion: 4,
    expiresAtMillis: Date.now() + 10 * 60 * 1000,
  });
  let sentCode = "";
  deletion.setDeletionEmailSender(async (message) => {
    const match = String(message.text).match(/驗證碼：(\d{6})/);
    sentCode = match ? match[1] : "";
  });
  try {
    await assert.rejects(
        deletion.requestEmailCodeHandler(request(`staff_${suffix}`, {
          shopId,
          mode: "test_reset",
          previewScanId: scanId,
        })),
        /最高管理員/,
    );
    const issued = await deletion.requestEmailCodeHandler(request(superUid, {
      shopId,
      mode: "test_reset",
      previewScanId: scanId,
      rawRequest: {ip: "203.0.113.10"},
    }));
    assert.equal(issued.sent, true);
    assert.match(sentCode, /^\d{6}$/);
    assert.equal(JSON.stringify(issued).includes(sentCode), false);
    const stored = await db.collection("shop_deletion_email_challenges")
        .doc(issued.challengeId).get();
    assert.equal(JSON.stringify(stored.data()).includes(sentCode), false);
    await assert.rejects(
        deletion.requestEmailCodeHandler(request(superUid, {
          shopId,
          mode: "test_reset",
          previewScanId: scanId,
        })),
        /頻繁/,
    );
    await assert.rejects(
        deletion.consumeEmailChallenge({
          uid: superUid,
          shopId: otherShopId,
          mode: "test_reset",
          scanId,
          challengeId: issued.challengeId,
          code: sentCode,
        }),
        /失效|不正確/,
    );
    for (let index = 0; index < 5; index += 1) {
      await assert.rejects(
          deletion.consumeEmailChallenge({
            uid: superUid,
            shopId,
            mode: "test_reset",
            scanId,
            challengeId: issued.challengeId,
            code: "000000",
          }),
          /不正確|錯誤次數/,
      );
    }
    await assert.rejects(
        deletion.consumeEmailChallenge({
          uid: superUid,
          shopId,
          mode: "test_reset",
          scanId,
          challengeId: issued.challengeId,
          code: sentCode,
        }),
        /錯誤次數/,
    );
    await db.collection("shop_deletion_email_rates").doc(superUid).set({
      lastSentAtMillis: Date.now() - 61 * 1000,
      sentAtMillis: [],
    });
    const replacement = await deletion.requestEmailCodeHandler(
        request(superUid, {
          shopId,
          mode: "test_reset",
          previewScanId: scanId,
        }),
    );
    assert.notEqual(replacement.challengeId, issued.challengeId);
    await assert.rejects(
        deletion.consumeEmailChallenge({
          uid: superUid,
          shopId,
          mode: "test_reset",
          scanId,
          challengeId: issued.challengeId,
          code: sentCode,
        }),
        /失效/,
    );
    const currentCode = sentCode;
    await deletion.consumeEmailChallenge({
      uid: superUid,
      shopId,
      mode: "test_reset",
      scanId,
      challengeId: replacement.challengeId,
      code: currentCode,
    });
    await assert.rejects(
        deletion.consumeEmailChallenge({
          uid: superUid,
          shopId,
          mode: "test_reset",
          scanId,
          challengeId: replacement.challengeId,
          code: currentCode,
        }),
        /失效/,
    );
    const expiredId = `expired_${suffix}`;
    await db.collection("shop_deletion_email_challenges").doc(expiredId).set({
      uid: superUid,
      shopId,
      mode: "test_reset",
      scanId,
      codeHash: "abc",
      salt: "def",
      attempts: 0,
      used: false,
      revoked: false,
      expiresAtMillis: Date.now() - 1000,
    });
    await db.collection("shop_deletion_email_active")
        .doc(`${superUid}_${shopId}`).set({challengeId: expiredId});
    await assert.rejects(
        deletion.consumeEmailChallenge({
          uid: superUid,
          shopId,
          mode: "test_reset",
          scanId,
          challengeId: expiredId,
          code: currentCode,
        }),
        /過期/,
    );
  } finally {
    deletion.setDeletionEmailSender(async () => {
      throw new Error("mail sender reset");
    });
  }
});

test("Emulator：無交易與取消訂單可刪，已知路徑掃描不會失敗", {
  skip: !canRun,
  timeout: 120000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `path_super_${suffix}`;
  const ownerUid = `path_owner_${suffix}`;
  const shopId = `PATH${suffix}`;
  const db = admin.firestore();
  const bucket = admin.storage().bucket();
  await db.collection("platform_users").doc(superUid).set({
    role: "super_admin",
    enabled: true,
  });
  await Promise.all([
    db.collection("shops").doc(shopId).set({
      shopId,
      shopCode: shopId,
      name: "只有取消訂單的店",
      ownerUid,
      status: "active",
      activationCodeId: `code_${suffix}`,
    }),
    db.collection("shop_commercial").doc(shopId).set({
      shopId,
      paidServiceUntil: "",
    }),
    db.collection("action_logs").doc(`ops_${suffix}`).set({
      shopId,
      action: "room-updated",
    }),
    db.collection("activation_codes").doc(`code_${suffix}`)
        .collection("usage_logs").doc(shopId).set({
          shopId,
          plan: "free",
        }),
    db.collection("shops").doc(shopId).collection("rooms").doc("r1")
        .set({name: "房型"}),
    db.collection("shops").doc(shopId).collection("room_types").doc("t1")
        .set({name: "套房"}),
    db.collection("shops").doc(shopId).collection("home_sections").doc("hero")
        .set({title: "首頁海報"}),
    db.collection("shop_members").doc(`${shopId}_${ownerUid}`).set({
      shopId,
      uid: ownerUid,
      role: "owner",
    }),
    db.collection("users").doc(ownerUid).set({shopIds: [shopId]}),
    db.collection("users").doc(ownerUid)
        .collection("policy_acceptances").doc(shopId)
        .set({shopId, acceptedVersion: 1}),
    db.collection("user_profiles").doc(ownerUid).set({shopIds: [shopId]}),
    db.collection("user_profiles").doc(ownerUid).collection("pets")
        .doc("pet1").set({name: "測試寵物"}),
    db.collection("user_profiles").doc(ownerUid).collection("pets")
        .doc("pet1").collection("shop_form_answers").doc(shopId)
        .set({shopId, answers: []}),
    db.collection("bookings").doc(`stay_${suffix}`).set({
      shopId,
      bookingKind: "accommodation",
      status: "rejected",
      paymentStatus: "unpaid",
    }),
    db.collection("bookings").doc(`care_${suffix}`).set({
      shopId,
      bookingKind: "daycare",
      status: "cancelled",
      paymentStatus: "unpaid",
    }),
    bucket.file(`shops/${shopId}/logo.jpg`).save(Buffer.from("logo")),
    bucket.file(`shops/${shopId}/poster.jpg`).save(Buffer.from("poster")),
  ]);
  const preview = await deletion.previewHandler(request(superUid, {shopId}));
  assert.equal(preview.scan.complete, true, JSON.stringify({
    failures: preview.scan.failures,
    blockers: preview.execution.cleanupBlockers,
  }));
  const related = preview.firestore.userRelatedCollections || [];
  for (const name of [
    "policy_acceptances",
    "shop_form_answers",
    "usage_logs",
  ]) {
    const row = related.find((item) => item.collectionGroup === name);
    assert.equal(row && row.status, "success", name);
  }
  assert.equal(
      related.find((item) => item.collectionGroup === "policy_acceptances")
          .count,
      1,
  );
  assert.equal(
      related.find((item) => item.collectionGroup === "shop_form_answers")
          .count,
      1,
  );
  assert.equal(
      related.find((item) => item.collectionGroup === "usage_logs").count,
      1,
  );
  assert.equal(
      related.find((item) => item.collectionGroup === "usage_logs")
          .classification,
      "delete",
  );
  assert.equal(preview.execution.cleanupCategory, "cancelled_orders_only");
  assert.equal(preview.execution.cleanupAllowed, true);
  const plainShopId = `PLAIN${suffix}`;
  await db.collection("shops").doc(plainShopId).set({
    shopId: plainShopId,
    shopCode: plainShopId,
    name: "只有設定與照片",
    ownerUid,
  });
  await bucket.file(`shops/${plainShopId}/background.jpg`)
      .save(Buffer.from("bg"));
  const plain = await deletion.previewHandler(
      request(superUid, {shopId: plainShopId}),
  );
  assert.equal(plain.execution.cleanupCategory, "no_transaction");
  assert.equal(plain.execution.cleanupAllowed, true);
  assert.ok(Number(plain.storage.fileCount || 0) >= 1);
});

test("Emulator：寄信失敗不能建立刪除工作", {
  skip: !canRun,
  timeout: 60000,
}, async () => {
  const suffix = Date.now().toString();
  const superUid = `mail_super_${suffix}`;
  const shopId = `MAIL${suffix}`;
  const db = admin.firestore();
  await db.collection("platform_users").doc(superUid).set({
    role: "super_admin",
    enabled: true,
  });
  await admin.auth().createUser({
    uid: superUid,
    email: `${superUid}@example.test`,
    emailVerified: true,
  });
  await db.collection("shops").doc(shopId).set({
    shopId,
    shopCode: shopId,
    name: "寄信失敗測試店",
    ownerUid: `owner_${suffix}`,
  });
  const preview = await deletion.previewHandler(
      request(superUid, {shopId}),
  );
  assert.equal(preview.execution.cleanupAllowed, true);
  deletion.setDeletionEmailSender(async () => {
    throw new Error("smtp down");
  });
  await assert.rejects(
      deletion.requestEmailCodeHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        previewScanId: preview.scan.scanId,
      })),
      /寄送失敗|尚未設定|尚未安裝/,
  );
  await assert.rejects(
      deletion.createJobHandler(request(superUid, {
        shopId,
        mode: "test_reset",
        previewScanId: preview.scan.scanId,
        irreversibleAcknowledged: true,
        emailChallengeId: "missing",
        emailCode: "000000",
      })),
      /失效|不正確|Email/,
  );
});
