// 檔案名稱：functions/platform/shop_deletion_policy.js
// 功能說明：店家完整刪除的模式、資料分類與安全確認規則。

"use strict";

const TEST_RESET_MODE = "test_reset";
const PERMANENT_DELETE_MODE = "permanent_delete";

// 測試重置時可刪除。所有文件仍須由後端用 shopId 精確查詢。
const TEST_DELETABLE_COLLECTIONS = new Set([
  "bookings",
  "camera_access_requests",
  "daily_care_photo_actions",
  "daily_care_photo_capacity",
  "daily_care_photo_downloads",
  "daily_care_photos",
  "daily_care_photo_reservations",
  "daily_care_photo_usage",
  "daily_care_records",
  "daycare_bookings",
  "member_link_requests",
  "notifications",
  "reports",
  "reviews",
  "shop_change_requests",
  "shop_member_invites",
  "shop_members",
  "shop_notifications",
]);

// 依法、金流或平台稽核用途保留。刪除工作只會隔離店家，不會刪除這些文件。
const RETAINED_COLLECTIONS = new Set([
  "action_logs",
  "activation_codes",
  "account_delete_requests",
  "commission_entries",
  "commercial_migration",
  "platform_contact_requests",
  "platform_counters",
  "platform_media_library",
  "payments",
  "sales_month_summaries",
  "sales_summary_events",
  "shop_attribution_events",
  "shop_commercial",
  "shop_entitlement_adjustments",
  "shop_payment_requests",
  "shop_subscription_payments",
  "users",
  "user_profiles",
]);

// 這些集合由刪除流程另外以文件 ID 或擁有者 UID 精確處理。
const SPECIAL_COLLECTIONS = new Set([
  "booking_counters",
  "payment_credentials",
  "shops",
  "sales_owner_locks",
  "sales_shop_create_requests",
  "shop_deletion_audits",
  "shop_deletion_jobs",
  "shop_deletion_locks",
  "retired_shop_codes",
]);

const TERMINAL_BOOKING_STATUSES = new Set([
  "cancelled",
  "completed",
  "checked_out",
  "no_show",
  "rejected",
  "refused",
  "expired",
]);

/**
 * @param {*} value 原始值
 * @return {string}
 */
function normalizeString(value) {
  return value === null || value === undefined ? "" : String(value).trim();
}

/**
 * @param {string} collectionId 集合名稱
 * @return {string} delete / retain / special / manual
 */
function classifyCollection(collectionId) {
  if (TEST_DELETABLE_COLLECTIONS.has(collectionId)) return "delete";
  if (RETAINED_COLLECTIONS.has(collectionId)) return "retain";
  if (SPECIAL_COLLECTIONS.has(collectionId)) return "special";
  return "manual";
}

/**
 * 測試重置仍不得碰觸真實金流、爭議或未完成交易。
 * @param {Object} summary 預覽摘要
 * @return {string[]}
 */
function testResetBlockers(summary) {
  const input = summary || {};
  const blockers = [];
  if (Number(input.paidPaymentCount || 0) > 0) {
    blockers.push("存在已付款或有金流交易編號的付款紀錄");
  }
  if (Number(input.openBookingCount || 0) > 0) {
    blockers.push("存在未結束的住宿或安親訂單");
  }
  if (Number(input.disputeCount || 0) > 0) {
    blockers.push("存在退款、爭議或申訴紀錄");
  }
  if (Number(input.subscriptionPaymentCount || 0) > 0) {
    blockers.push("存在平台訂閱收款紀錄");
  }
  if (Number(input.manualCollectionCount || 0) > 0) {
    blockers.push("存在尚未確認歸屬或刪除政策的集合");
  }
  if (Number(input.unknownStorageCount || 0) > 0) {
    blockers.push("存在無法確認歸屬的 Storage 檔案");
  }
  return blockers;
}

/**
 * @param {Object} booking 訂單
 * @return {boolean}
 */
function isOpenBooking(booking) {
  const status = normalizeString((booking || {}).status).toLowerCase();
  return !TERMINAL_BOOKING_STATUSES.has(status);
}

/**
 * 付款只要已收款、有第三方交易編號、退款或爭議，就不能當測試垃圾直接刪除。
 * @param {Object} payment 付款
 * @return {boolean}
 */
function isPaidOrExternalPayment(payment) {
  const data = payment || {};
  const amount = Number(
      data.paidAmount || data.amount || data.tradeAmount || 0,
  );
  const status = normalizeString(
      data.status || data.paymentStatus,
  ).toLowerCase();
  const externalId = normalizeString(
      data.tradeNo ||
      data.merchantTradeNo ||
      data.transactionId ||
      data.paymentIntentId,
  );
  return amount > 0 ||
    externalId.length > 0 ||
    ["paid", "success", "completed", "refunded", "partial_refund"]
        .includes(status);
}

/**
 * @param {Object} input 安全確認輸入
 * @return {string[]}
 */
function validateConfirmation(input) {
  const value = input || {};
  const errors = [];
  const shopCode = normalizeString(value.shopCode);
  if (!shopCode || normalizeString(value.typedShopCode) !== shopCode) {
    errors.push("請完整輸入店家編號");
  }
  if (normalizeString(value.reason).length < 10) {
    errors.push("刪除原因至少需要 10 個字");
  }
  if (value.irreversibleAcknowledged !== true) {
    errors.push("尚未確認不可還原警告");
  }
  if (value.mode !== TEST_RESET_MODE &&
      value.mode !== PERMANENT_DELETE_MODE) {
    errors.push("刪除模式不正確");
  }
  return errors;
}

/**
 * 正式永久刪除在資料保留政策完成前一律禁止。
 * @param {Object} input 建立工作條件
 * @return {string[]}
 */
function jobStartBlockers(input) {
  const value = input || {};
  const blockers = validateConfirmation(value);
  if (value.mode === PERMANENT_DELETE_MODE) {
    blockers.push("正式資料保留與隔離政策尚未完成，禁止永久刪除");
    return blockers;
  }
  if (value.testDataConfirmed !== true) {
    blockers.push("最高管理員尚未確認這間店及其資料為隔離測試資料");
  }
  return blockers.concat(testResetBlockers(value.summary));
}

/**
 * @param {string} shopId 店家編號
 * @param {string[]} bookingIds 訂單編號
 * @return {string[]}
 */
function storagePrefixes(shopId, bookingIds) {
  const safeShopId = normalizeString(shopId);
  const prefixes = [
    `shops/${safeShopId}/`,
    `daily_care_photos/${safeShopId}/`,
    `shop_chat/${safeShopId}/`,
    `shop_verify_requests/${safeShopId}/`,
  ];
  for (const bookingId of bookingIds || []) {
    const safeBookingId = normalizeString(bookingId);
    if (!safeBookingId) continue;
    prefixes.push(
        `booking_images/${safeBookingId}/`,
        `review_images/${safeBookingId}/`,
        `booking_extra_charges/${safeBookingId}/`,
    );
  }
  return [...new Set(prefixes)];
}

module.exports = {
  TEST_RESET_MODE,
  PERMANENT_DELETE_MODE,
  TEST_DELETABLE_COLLECTIONS,
  RETAINED_COLLECTIONS,
  SPECIAL_COLLECTIONS,
  TERMINAL_BOOKING_STATUSES,
  normalizeString,
  classifyCollection,
  testResetBlockers,
  isOpenBooking,
  isPaidOrExternalPayment,
  validateConfirmation,
  jobStartBlockers,
  storagePrefixes,
};
