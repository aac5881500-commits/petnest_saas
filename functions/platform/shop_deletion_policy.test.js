"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const policy = require("./shop_deletion_policy");
const deletion = require("./shop_deletion")._test;

test("只有明確 allowlist 的店家集合可自動刪除", () => {
  assert.equal(policy.classifyCollection("shop_members"), "delete");
  assert.equal(policy.classifyCollection("bookings"), "retain");
  assert.equal(policy.classifyCollection("payments"), "retain");
  assert.equal(policy.classifyCollection("reviews"), "manual");
  assert.equal(policy.classifyCollection("users"), "shared");
  assert.equal(policy.classifyCollection("user_profiles"), "shared");
  assert.equal(policy.classifyCollection("platform_media_library"), "shared");
  assert.equal(policy.classifyCollection("future_unknown_data"), "manual");
  assert.equal(policy.classifyShopSubcollection("rooms"), "delete");
  assert.equal(policy.classifyShopSubcollection("store_orders"), "retain");
});

test("正式永久刪除在保留政策完成前永遠被阻止", () => {
  const blockers = policy.jobStartBlockers({
    mode: policy.PERMANENT_DELETE_MODE,
    shopCode: "SHOP9001",
    typedShopCode: "SHOP9001",
    reason: "店家正式提出資料刪除申請",
    irreversibleAcknowledged: true,
    scopeConfirmed: true,
    testDataConfirmed: true,
    summary: {},
  });
  assert.ok(blockers.some((message) => message.includes("資料保留")));
});

test("店號、原因、不可還原及測試資料確認缺一不可", () => {
  const blockers = policy.jobStartBlockers({
    mode: policy.TEST_RESET_MODE,
    shopCode: "SHOP9001",
    typedShopCode: "SHOP9002",
    reason: "短",
    irreversibleAcknowledged: false,
    scopeConfirmed: false,
    testDataConfirmed: false,
    summary: {},
  });
  assert.ok(blockers.some((message) => message.includes("店家編號")));
  assert.ok(blockers.some((message) => message.includes("10 個字")));
  assert.ok(blockers.some((message) => message.includes("不可還原")));
  assert.ok(blockers.some((message) => message.includes("隔離測試資料")));
});

test("有效交易、進行中訂單及未知資料都阻止測試重置", () => {
  const blockers = policy.testResetBlockers({
    paidBookingCount: 1,
    paidPaymentCount: 1,
    openBookingCount: 2,
    disputeCount: 1,
    paidStoreOrderCount: 1,
    openStoreOrderCount: 1,
    subscriptionPaymentCount: 1,
    retainedBookingStorageCount: 1,
    manualCollectionCount: 1,
    unknownStorageCount: 1,
  });
  assert.equal(blockers.length, 10);
});

test("付款判斷不會把真實交易當成可刪測試資料", () => {
  assert.equal(policy.isPaidOrExternalPayment({paidAmount: 100}), true);
  assert.equal(policy.isPaidOrExternalPayment({tradeNo: "T123"}), true);
  assert.equal(policy.isPaidOrExternalPayment({status: "refunded"}), true);
  assert.equal(
      policy.isPaidOrExternalPayment({status: "pending", amount: 0}),
      false,
  );
  assert.equal(
      policy.isPaidOrExternalPayment({status: "pending", amount: 500}),
      false,
  );
});

test("只有已結束訂單不會阻止測試重置", () => {
  assert.equal(policy.isOpenBooking({status: "pending"}), true);
  assert.equal(policy.isOpenBooking({status: "confirmed"}), true);
  assert.equal(policy.isOpenBooking({status: "completed"}), false);
  assert.equal(policy.isOpenBooking({status: "cancelled"}), false);
  assert.equal(
      policy.isSafeTestBooking({status: "completed", paymentStatus: "unpaid"}),
      false,
  );
  assert.equal(
      policy.isSafeTestBooking({status: "cancelled", paymentStatus: "unpaid"}),
      true,
  );
  assert.equal(
      policy.isSafeTestBooking({status: "completed", paymentStatus: "paid"}),
      false,
  );
});

test("長期閒置清理要求 180 天且完全沒有交易", () => {
  const now = Date.UTC(2026, 9, 13);
  assert.deepEqual(policy.inactiveCleanupBlockers({
    bookingCount: 0,
    paymentCount: 0,
    storeOrderCount: 0,
    lastActivityMillis: now - 181 * 24 * 60 * 60 * 1000,
  }, now), []);
  const blockers = policy.inactiveCleanupBlockers({
    bookingCount: 1,
    paymentCount: 1,
    storeOrderCount: 1,
    lastActivityMillis: now - 30 * 24 * 60 * 60 * 1000,
  }, now);
  assert.ok(blockers.some((message) => message.includes("住宿及安親訂單")));
  assert.ok(blockers.some((message) => message.includes("付款紀錄")));
  assert.ok(blockers.some((message) => message.includes("商城訂單")));
  assert.ok(blockers.some((message) => message.includes("未滿 180 天")));
});

test("Storage 僅建立店家及已確認訂單的精確 prefix", () => {
  const prefixes = policy.storagePrefixes(
      "SHOP9001",
      ["B1", "B2", "B1"],
  );
  assert.ok(prefixes.includes("shops/SHOP9001/"));
  assert.ok(prefixes.includes("daily_care_photos/SHOP9001/"));
  assert.ok(prefixes.includes("booking_images/B1/"));
  assert.ok(prefixes.includes("review_images/B2/"));
  assert.equal(prefixes.some((prefix) => prefix.startsWith("platform/")), false);
  assert.equal(new Set(prefixes).size, prefixes.length);
});

test("創店交易會檢查永久停用店號，且不會重設 counter", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "sales", "commercial_ops.js"),
      "utf8",
  );
  assert.match(source, /collection\("retired_shop_codes"\)\.doc\(shopCode\)/);
  assert.match(source, /counterSnap\.data\(\) \|\| \{\}\)\.current \|\| 0\) \+ 1/);
  assert.doesNotMatch(source, /current\s*:\s*0/);
});

test("後端 callable 每次都重新驗證 super_admin，刪除必須通過 Email 驗證碼", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "shop_deletion.js"),
      "utf8",
  );
  assert.match(source, /data\.role\) !== "super_admin"/);
  assert.match(source, /請先完成 Email 六位數驗證/);
  assert.match(source, /emailAuthorizedUntil/);
  assert.doesNotMatch(source, /requireSuperAdmin\(request, true\)/);
});

test("執行器保留會員主帳號、寵物及平台圖庫", () => {
  assert.equal(policy.TEST_DELETABLE_COLLECTIONS.has("users"), false);
  assert.equal(policy.TEST_DELETABLE_COLLECTIONS.has("user_profiles"), false);
  assert.equal(
      policy.TEST_DELETABLE_COLLECTIONS.has("platform_media_library"),
      false,
  );
  assert.equal(policy.SHARED_COLLECTIONS.has("users"), true);
  assert.equal(policy.SHARED_COLLECTIONS.has("user_profiles"), true);
});

test("Storage 擁有權分類保留顧客與交易內容", () => {
  const context = {
    shopId: "SHOP9001",
    bookingIds: ["B1", "B2"],
    reviewBookingIds: ["B2"],
  };
  assert.equal(
      policy.classifyStoragePrefix("shops/SHOP9001/", context).category,
      "safe_delete",
  );
  assert.equal(
      policy.classifyStoragePrefix("booking_images/B1/", context).category,
      "retain",
  );
  const review = policy.classifyStoragePrefix(
      "review_images/B2/", context,
  );
  assert.equal(review.category, "manual");
  assert.equal(review.ownership, "confirmed");
  const orphanReview = policy.classifyStoragePrefix(
      "review_images/B1/", context,
  );
  assert.equal(orphanReview.category, "manual");
  assert.equal(orphanReview.ownership, "unknown");
  assert.equal(
      policy.classifyStoragePrefix(
          "booking_images/OTHER/", context,
      ).ownership,
      "unknown",
  );
});

test("同一個顧客寵物檔案被多處引用時只盤點一次", () => {
  const url =
    "https://firebasestorage.googleapis.com/v0/b/test/o/" +
    "pets%2Fcustomer-1%2Fpet-1.jpg?alt=media";
  const references = deletion.storageReferences({
    memberPhoto: url,
    petSnapshot: {photoUrl: url},
    duplicateList: [url, url],
  });
  assert.deepEqual(references, ["pets/customer-1/pet-1.jpg"]);
});

test("每日照護與訂單圖片缺少實際關聯時維持待確認", async () => {
  const objects = {
    "daily_care_photos/SHOP9001/": [
      "daily_care_photos/SHOP9001/B1/a.jpg",
      "daily_care_photos/SHOP9001/OTHER/b.jpg",
    ],
    "booking_images/B1/": [
      "booking_images/B1/referenced.jpg",
      "booking_images/B1/orphan.jpg",
    ],
  };
  const bucket = {
    getFiles: async ({prefix}) => [
      (objects[prefix] || []).map((name) => ({
        name,
        metadata: {size: "10"},
      })),
      {},
    ],
  };
  const result = await deletion.inspectStorageV2(
      bucket,
      Object.keys(objects),
      "scan-test",
      {
        shopId: "SHOP9001",
        bookingIds: ["B1"],
        reviewBookingIds: [],
        shopStorageReferences: [
          "daily_care_photos/SHOP9001/B1/a.jpg",
        ],
        bookingStorageReferences: [
          "booking_images/B1/referenced.jpg",
        ],
        reviewStorageReferences: [],
      },
  );
  assert.equal(result.prefixes[0].category, "manual");
  assert.equal(result.prefixes[0].ownership, "unknown");
  assert.match(result.prefixes[0].reason, /bookings\.shopId/);
  const orphan = result.prefixes.find((row) =>
    String(row.label || "").includes("無 Firestore 引用"));
  assert.equal(orphan.category, "manual");
  assert.equal(orphan.unreferencedCount, 1);
  const referenced = result.prefixes.find((row) =>
    String(row.label || "").includes("已由 Firestore 引用"));
  assert.equal(referenced.category, "retain");
  assert.equal(referenced.count, 1);
});

test("主要住宿、安親與商城後端會拒絕正在刪除的店家", () => {
  const files = [
    path.join(__dirname, "..", "bookings", "create_stay_booking.js"),
    path.join(__dirname, "..", "daycare", "create_daycare_booking.js"),
    path.join(__dirname, "..", "store", "create_store_order.js"),
  ];
  for (const file of files) {
    const source = fs.readFileSync(file, "utf8");
    assert.match(source, /deletionState\s*===\s*"deleting"/);
  }
});

test("預覽狀態可區分成功、部分失敗、完全失敗與未掃描", () => {
  assert.equal(deletion.combineStatuses(["success", "success"]), "success");
  assert.equal(deletion.combineStatuses(["success", "failed"]), "partial");
  assert.equal(deletion.combineStatuses(["failed", "failed"]), "failed");
  assert.equal(deletion.combineStatuses([]), "not_scanned");
});

test("只開放安全清理，正式營運店家永久刪除保持鎖定", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "shop_deletion.js"),
      "utf8",
  );
  assert.match(source, /SAFE_CLEANUP_EXECUTION_ENABLED = true/);
  assert.match(source, /FORMAL_DELETION_ENABLED = false/);
  assert.match(source, /正式永久刪除尚未開放執行/);
});

test("分頁掃描達安全上限時標記 partial，不把上限當總數", async () => {
  const docs = Array.from({length: 250}, (_, index) => ({
    id: `d${index}`,
    data: () => ({}),
    ref: {path: `items/d${index}`},
  }));
  const query = {
    limit: () => query,
    startAfter: () => query,
    get: async () => ({empty: false, size: docs.length, docs}),
  };
  const result = await deletion.scanQuery(query, {maxDocs: 250});
  assert.equal(result.status, "partial");
  assert.equal(result.complete, false);
  assert.equal(result.count, 250);
});

test("掃描錯誤只公開安全錯誤類型，不回傳敏感訊息", () => {
  const result = deletion.publicScanError({
    code: "permission-denied",
    message: "private document path and token",
  });
  assert.equal(result.errorCode, "permission-denied");
  assert.doesNotMatch(result.reason, /private|token/);
});

test("單一掃描來源逾時會標示 deadline-exceeded", async () => {
  await assert.rejects(
      deletion.withTimeout(new Promise(() => {}), 5, "test-source"),
      (error) => error.code === "deadline-exceeded",
  );
  const detail = deletion.publicScanError({code: "deadline-exceeded"});
  assert.equal(detail.errorCode, "deadline-exceeded");
});

test("Storage 列舉失敗不會回傳假 0", async () => {
  const bucket = {
    getFiles: async () => {
      const error = new Error("emulator unavailable");
      error.code = "unavailable";
      throw error;
    },
  };
  const result = await deletion.inspectStorageV2(
      bucket,
      ["shops/SHOP9001/"],
      "scan-storage-failure",
      {
        shopId: "SHOP9001",
        bookingIds: [],
        reviewBookingIds: [],
        shopStorageReferences: [],
        bookingStorageReferences: [],
        reviewStorageReferences: [],
      },
  );
  assert.equal(result.status, "failed");
  assert.equal(result.complete, false);
  assert.equal(result.fileCount, null);
  assert.equal(result.prefixes[0].count, null);
  assert.equal(result.prefixes[0].errorCode, "unavailable");
});

test("Storage 分批刪除會分開統計成功容量與失敗物件", async () => {
  const bucket = {
    getFiles: async () => [[{
      name: "shops/SHOP9001/logo.jpg",
      metadata: {size: "12"},
      delete: async () => {},
    }, {
      name: "shops/SHOP9001/banner.jpg",
      metadata: {size: "20"},
      delete: async () => {
        const error = new Error("retry");
        error.code = "unavailable";
        throw error;
      },
    }]],
  };
  const result = await deletion.deleteStoragePage(
      bucket,
      "shops/SHOP9001/",
  );
  assert.equal(result.deleted, 1);
  assert.equal(result.deletedBytes, 12);
  assert.deepEqual(result.failures, [{
    storageObject: "shops/SHOP9001/banner.jpg",
    errorCode: "unavailable",
  }]);
});

/**
 * @param {Object} extra 覆寫欄位
 * @return {Object}
 */
function eligibilityInput(extra) {
  return Object.assign({
    scanComplete: true,
    bookingCount: 0,
    paymentCount: 0,
    storeOrderCount: 0,
    paidBookingCount: 0,
    paidPaymentCount: 0,
    paidStoreOrderCount: 0,
    refundingPaymentCount: 0,
    disputeCount: 0,
    completedStayCount: 0,
    completedDaycareCount: 0,
    completedStoreOrderCount: 0,
    subscriptionPaymentCount: 0,
    openBookingCount: 0,
    openStoreOrderCount: 0,
    otherBookingCount: 0,
    unsafePaymentCount: 0,
    manualCollectionCount: 0,
    unknownStorageCount: 0,
  }, extra || {});
}

test("無交易店家可以刪除，完成服務、收款、退款與爭議必須阻擋", () => {
  assert.equal(
      policy.deletionEligibility(eligibilityInput()).category,
      "no_transaction",
  );
  assert.equal(policy.deletionEligibility(eligibilityInput()).allowed, true);
  const cancelled = policy.deletionEligibility(eligibilityInput({
    bookingCount: 2,
    paymentCount: 1,
    storeOrderCount: 1,
    unsafePaymentCount: 0,
  }));
  assert.equal(cancelled.category, "cancelled_orders_only");
  assert.equal(cancelled.allowed, true);
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        bookingCount: 1,
        paidBookingCount: 1,
        paidPaymentCount: 1,
      })).blockers.join(" "),
      /成功收款/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        paymentCount: 1,
        refundingPaymentCount: 1,
      })).blockers.join(" "),
      /退款/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        bookingCount: 1,
        completedStayCount: 1,
      })).blockers.join(" "),
      /完成住宿/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        bookingCount: 1,
        completedDaycareCount: 1,
      })).blockers.join(" "),
      /完成安親/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        storeOrderCount: 1,
        completedStoreOrderCount: 1,
      })).blockers.join(" "),
      /商城交易/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        paymentCount: 1,
        disputeCount: 1,
      })).blockers.join(" "),
      /爭議/,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        bookingCount: 1,
        openBookingCount: 1,
      })).blockers.join(" "),
      /未完成訂單/,
  );
  assert.equal(
      policy.isSafeTestBooking({
        status: "rejected",
        paymentStatus: "unpaid",
      }),
      true,
  );
  assert.equal(
      policy.isSafeTestBooking({
        status: "cancelled",
        paymentStatus: "paid",
        paidAmount: 100,
      }),
      false,
  );
  assert.equal(
      policy.isPaidOrExternalPayment({
        status: "pending",
        merchantTradeNo: "M123",
        amount: 500,
      }),
      false,
  );
  assert.equal(
      policy.isPaidOrExternalPayment({gatewayRtnCode: "1"}),
      true,
  );
  assert.equal(policy.hasRefundOrDispute({refundAmount: 20}), true);
});

test("一般操作紀錄與未付費商業設定不構成真實交易", () => {
  assert.equal(policy.isRequiredAuditAction({action: "test-created"}), false);
  assert.equal(
      policy.isRequiredAuditAction({action: "subscription_payment_confirmed"}),
      true,
  );
  assert.equal(
      policy.hasRealCommercialObligation({
        paidServiceUntil: "",
        plan: "free",
      }),
      false,
  );
  assert.equal(
      policy.hasRealCommercialObligation({paidServiceUntil: "2026-12-31"}),
      true,
  );
  assert.equal(
      policy.hasRealCommercialObligation({plan: "pro"}),
      true,
  );
  assert.match(
      policy.deletionEligibility(eligibilityInput({
        realCommercialCount: 1,
      })).blockers.join(" "),
      /商業紀錄/,
  );
  assert.equal(
      policy.deletionEligibility(eligibilityInput({})).allowed,
      true,
  );
});
