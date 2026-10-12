"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const policy = require("./shop_deletion_policy");
const deletion = require("./shop_deletion")._test;

test("只有明確 allowlist 的店家集合可自動刪除", () => {
  assert.equal(policy.classifyCollection("shop_members"), "delete");
  assert.equal(policy.classifyCollection("bookings"), "delete");
  assert.equal(policy.classifyCollection("payments"), "retain");
  assert.equal(policy.classifyCollection("users"), "retain");
  assert.equal(policy.classifyCollection("user_profiles"), "retain");
  assert.equal(policy.classifyCollection("platform_media_library"), "retain");
  assert.equal(policy.classifyCollection("future_unknown_data"), "manual");
});

test("正式永久刪除在保留政策完成前永遠被阻止", () => {
  const blockers = policy.jobStartBlockers({
    mode: policy.PERMANENT_DELETE_MODE,
    shopCode: "SHOP9001",
    typedShopCode: "SHOP9001",
    reason: "店家正式提出資料刪除申請",
    irreversibleAcknowledged: true,
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
    testDataConfirmed: false,
    summary: {},
  });
  assert.ok(blockers.some((message) => message.includes("店家編號")));
  assert.ok(blockers.some((message) => message.includes("10 個字")));
  assert.ok(blockers.some((message) => message.includes("不可還原")));
  assert.ok(blockers.some((message) => message.includes("隔離測試資料")));
});

test("有效付款、進行中訂單、爭議及未知資料都阻止測試重置", () => {
  const blockers = policy.testResetBlockers({
    paidPaymentCount: 1,
    openBookingCount: 2,
    disputeCount: 1,
    subscriptionPaymentCount: 1,
    manualCollectionCount: 1,
    unknownStorageCount: 1,
  });
  assert.equal(blockers.length, 6);
});

test("付款判斷不會把真實交易當成可刪測試資料", () => {
  assert.equal(policy.isPaidOrExternalPayment({paidAmount: 100}), true);
  assert.equal(policy.isPaidOrExternalPayment({tradeNo: "T123"}), true);
  assert.equal(policy.isPaidOrExternalPayment({status: "refunded"}), true);
  assert.equal(
      policy.isPaidOrExternalPayment({status: "pending", amount: 0}),
      false,
  );
});

test("只有已結束訂單不會阻止測試重置", () => {
  assert.equal(policy.isOpenBooking({status: "pending"}), true);
  assert.equal(policy.isOpenBooking({status: "confirmed"}), true);
  assert.equal(policy.isOpenBooking({status: "completed"}), false);
  assert.equal(policy.isOpenBooking({status: "cancelled"}), false);
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

test("後端 callable 每次都重新驗證 super_admin 並要求近期驗證", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "shop_deletion.js"),
      "utf8",
  );
  assert.match(source, /data\.role\) !== "super_admin"/);
  assert.match(source, /request\.auth\.token\.auth_time/);
  assert.match(source, /requireSuperAdmin\(request, true\)/);
});

test("執行器保留會員主帳號、寵物及平台圖庫", () => {
  assert.equal(policy.TEST_DELETABLE_COLLECTIONS.has("users"), false);
  assert.equal(policy.TEST_DELETABLE_COLLECTIONS.has("user_profiles"), false);
  assert.equal(
      policy.TEST_DELETABLE_COLLECTIONS.has("platform_media_library"),
      false,
  );
  assert.equal(policy.RETAINED_COLLECTIONS.has("users"), true);
  assert.equal(policy.RETAINED_COLLECTIONS.has("user_profiles"), true);
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

test("第一階段在前後端都不可建立或執行刪除工作", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "shop_deletion.js"),
      "utf8",
  );
  assert.match(source, /PHASE_ONE_PREVIEW_ONLY = true/);
  assert.match(source, /禁止建立任何刪除工作/);
  assert.match(source, /禁止執行或重試任何刪除工作/);
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
