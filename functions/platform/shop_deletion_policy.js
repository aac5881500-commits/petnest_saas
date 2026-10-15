// 檔案名稱：functions/platform/shop_deletion_policy.js
// 功能說明：店家完整刪除的模式、資料分類與安全確認規則。

"use strict";

const TEST_RESET_MODE = "test_reset";
const INACTIVE_CLEANUP_MODE = "inactive_cleanup";
const PERMANENT_DELETE_MODE = "permanent_delete";
const INACTIVE_MIN_AGE_DAYS = 180;

// 測試重置時可刪除。所有文件仍須由後端用 shopId 精確查詢。
const TEST_DELETABLE_COLLECTIONS = new Set([
  "camera_access_requests",
  "daily_care_photo_actions",
  "daily_care_photo_capacity",
  "daily_care_photo_downloads",
  "daily_care_photos",
  "daily_care_photo_reservations",
  "daily_care_photo_usage",
  "daily_care_records",
  "member_link_requests",
  "notifications",
  "reports",
  "shop_member_invites",
  "shop_members",
  "shop_notifications",
]);

// 依法、金流或平台稽核用途保留。刪除工作只會隔離店家，不會刪除這些文件。
const RETAINED_COLLECTIONS = new Set([
  "activation_codes",
  "account_delete_requests",
  "commission_entries",
  "commercial_migration",
  "daycare_bookings",
  "platform_contact_requests",
  "platform_counters",
  "bookings",
  "payments",
  "sales_month_summaries",
  "sales_summary_events",
  "shop_attribution_events",
  "shop_entitlement_adjustments",
  "shop_payment_requests",
  "shop_subscription_payments",
]);

// 跨店或跨產品共用主檔。店家關聯可另行處理，但主文件不得列入店家刪除。
const SHARED_COLLECTIONS = new Set([
  "platform_media_library",
  "users",
  "user_profiles",
]);

// 店家樹內仍屬交易主體的文件，不因位於 shops/{shopId} 下就自動可刪。
const RETAINED_SHOP_SUBCOLLECTIONS = new Set([
  "store_orders",
]);

// 這些集合由刪除流程另外以文件 ID 或擁有者 UID 精確處理。
const SPECIAL_COLLECTIONS = new Set([
  "booking_counters",
  "payment_credentials",
  "shops",
  "sales_owner_locks",
  "sales_shop_create_requests",
  "shop_deletion_audits",
  "shop_deletion_email_active",
  "shop_deletion_email_challenges",
  "shop_deletion_email_rates",
  "shop_deletion_jobs",
  "shop_deletion_locks",
  "shop_deletion_preview_grants",
  "retired_shop_codes",
]);

const TERMINAL_BOOKING_STATUSES = new Set([
  "cancelled",
  "canceled",
  "completed",
  "checked_out",
  "checkedout",
  "no_show",
  "rejected",
  "refused",
  "declined",
  "expired",
]);

const CANCELLED_OR_REJECTED_STATUSES = new Set([
  "cancelled",
  "canceled",
  "rejected",
  "refused",
  "declined",
]);

const COMPLETED_SERVICE_STATUSES = new Set([
  "completed",
  "checked_out",
  "checkedout",
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
  if (SHARED_COLLECTIONS.has(collectionId)) return "shared";
  if (RETAINED_COLLECTIONS.has(collectionId)) return "retain";
  if (SPECIAL_COLLECTIONS.has(collectionId)) return "special";
  return "manual";
}

/**
 * @param {string} collectionId shops/{shopId} 下任一層集合名稱
 * @return {string} delete / retain
 */
function classifyShopSubcollection(collectionId) {
  return RETAINED_SHOP_SUBCOLLECTIONS.has(collectionId) ?
    "retain" : "delete";
}

/**
 * @param {Object} value 訂單或付款
 * @return {string}
 */
function recordStatus(value) {
  return normalizeString((value || {}).status).toLowerCase();
}

/**
 * @param {Object} booking 住宿或安親訂單
 * @return {boolean}
 */
function isCancelledOrRejectedBooking(booking) {
  return CANCELLED_OR_REJECTED_STATUSES.has(recordStatus(booking));
}

/**
 * @param {Object} booking 住宿或安親訂單
 * @return {boolean}
 */
function isCompletedService(booking) {
  return COMPLETED_SERVICE_STATUSES.has(recordStatus(booking));
}

/**
 * 付款、退款、發票、合約與分潤紀錄必須留下，一般操作紀錄可以清理。
 * @param {Object} value 操作紀錄
 * @return {boolean}
 */
function isRequiredAuditAction(value) {
  const data = value || {};
  const blob = [
    data.action,
    data.type,
    data.targetType,
    data.category,
  ].map(normalizeString).join(" ").toLowerCase();
  return /payment|refund|invoice|commission|dispute|contract|subscription|payout|chargeback/
      .test(blob);
}

/**
 * 只有實際付費、合約、發票或應收款才算必須留下的商業資料。
 * @param {Object} value 商業或激活紀錄
 * @return {boolean}
 */
function hasRealCommercialObligation(value) {
  const data = value || {};
  if (normalizeString(data.paidServiceUntil)) return true;
  if (normalizeString(
      data.invoiceNo || data.invoiceNumber || data.contractId,
  )) {
    return true;
  }
  const amount = Number(
      data.receivableAmount || data.paidAmount || data.amountPaid || 0,
  );
  if (amount > 0) return true;
  const plan = normalizeString(data.plan).toLowerCase();
  return plan === "basic" || plan === "pro";
}

/**
 * 依實際路徑與已確認關聯分類 Storage 擁有權；不只靠檔名猜測。
 * @param {string} prefix Storage prefix
 * @param {Object} context 已確認的店家／訂單／評論關聯
 * @return {Object}
 */
function classifyStoragePrefix(prefix, context) {
  const value = context || {};
  const shopId = normalizeString(value.shopId);
  const bookingIds = new Set(value.bookingIds || []);
  const reviewBookingIds = new Set(value.reviewBookingIds || []);
  if (prefix === `shops/${shopId}/` ||
      prefix === `daily_care_photos/${shopId}/` ||
      prefix === `shop_chat/${shopId}/`) {
    return {
      category: "safe_delete",
      ownership: "confirmed",
      reason: "路徑含指定 shopId，且上傳規則以該店權限限制寫入",
      affectsDeletion: false,
    };
  }
  if (prefix === `shop_verify_requests/${shopId}/`) {
    return {
      category: "manual",
      ownership: "confirmed",
      reason: "屬指定店家，但可能是認證證件與稽核附件，保存政策未確認",
      affectsDeletion: true,
    };
  }
  const parts = prefix.split("/").filter(Boolean);
  const root = parts[0] || "";
  const bookingId = parts[1] || "";
  if (["booking_images", "booking_extra_charges"].includes(root)) {
    const confirmed = bookingIds.has(bookingId);
    return {
      category: confirmed ? "retain" : "manual",
      ownership: confirmed ? "confirmed" : "unknown",
      reason: confirmed ?
        "已由 bookings.shopId 確認歸屬，但屬付款／加收費用證據" :
        "找不到可確認 shopId 的訂單",
      affectsDeletion: !confirmed,
    };
  }
  if (root === "review_images") {
    const bookingConfirmed = bookingIds.has(bookingId);
    const reviewConfirmed = reviewBookingIds.has(bookingId);
    return {
      category: "manual",
      ownership: bookingConfirmed && reviewConfirmed ?
        "confirmed" : "unknown",
      reason: bookingConfirmed && reviewConfirmed ?
        "訂單與評論皆屬指定店家，但圖片是顧客產生內容，刪除政策未確認" :
        "訂單或評論關聯不完整，不能只依 bookingId 路徑判定",
      affectsDeletion: true,
    };
  }
  return {
    category: "manual",
    ownership: "unknown",
    reason: "路徑不在已確認的店家上傳規則中",
    affectsDeletion: true,
  };
}

/**
 * 測試重置仍不得碰觸真實金流、爭議或未完成交易。
 * @param {Object} summary 預覽摘要
 * @return {string[]}
 */
function testResetBlockers(summary) {
  const input = summary || {};
  const blockers = [];
  if (Number(input.paidBookingCount || 0) > 0) {
    blockers.push("存在已付款或帶外部交易編號的住宿／安親訂單");
  }
  if (Number(input.paidPaymentCount || 0) > 0) {
    blockers.push("存在已付款或有金流交易編號的付款紀錄");
  }
  if (Number(input.openBookingCount || 0) > 0) {
    blockers.push("存在未結束的住宿或安親訂單");
  }
  if (Number(input.refundingPaymentCount || 0) > 0 ||
      Number(input.disputeCount || 0) > 0) {
    blockers.push("存在退款、爭議或申訴紀錄");
  }
  if (Number(input.paidStoreOrderCount || 0) > 0) {
    blockers.push("存在已付款或帶外部交易編號的商城訂單");
  }
  if (Number(input.openStoreOrderCount || 0) > 0) {
    blockers.push("存在尚未結束的商城訂單");
  }
  if (Number(input.subscriptionPaymentCount || 0) > 0) {
    blockers.push("存在平台訂閱收款紀錄");
  }
  if (Number(input.retainedBookingStorageCount || 0) > 0) {
    blockers.push("訂單仍有付款證明或加收費用附件，不能移除其來源訂單");
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
 * 長期閒置清理只處理從未正式營運、沒有任何訂單或付款的店家。
 * @param {Object} summary 預覽摘要
 * @param {number} nowMillis 目前時間
 * @return {string[]}
 */
function inactiveCleanupBlockers(summary, nowMillis = Date.now()) {
  const input = summary || {};
  const blockers = testResetBlockers(input);
  if (Number(input.bookingCount || 0) > 0) {
    blockers.push("長期閒置清理要求住宿及安親訂單為 0 筆");
  }
  if (Number(input.paymentCount || 0) > 0) {
    blockers.push("長期閒置清理要求付款紀錄為 0 筆");
  }
  if (Number(input.storeOrderCount || 0) > 0) {
    blockers.push("長期閒置清理要求商城訂單為 0 筆");
  }
  const lastActivityMillis = Number(input.lastActivityMillis || 0);
  if (lastActivityMillis <= 0) {
    blockers.push("缺少可靠的最後活動時間，不能判定為長期閒置店家");
  } else {
    const minimumAge =
      INACTIVE_MIN_AGE_DAYS * 24 * 60 * 60 * 1000;
    if (nowMillis - lastActivityMillis < minimumAge) {
      blockers.push(`店家最後活動未滿 ${INACTIVE_MIN_AGE_DAYS} 天`);
    }
  }
  return [...new Set(blockers)];
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
 * @param {Object} order 商城訂單
 * @return {boolean}
 */
function isOpenStoreOrder(order) {
  const status = normalizeString((order || {}).status).toLowerCase();
  return !["cancelled", "completed"].includes(status);
}

/**
 * 綠界、ATM、超商或轉帳必須有成功收款證據，不能只因建立了商店交易編號。
 * @param {Object} value 付款或訂單
 * @return {boolean}
 */
function hasGatewaySuccess(value) {
  const data = value || {};
  const code = normalizeString(
      data.gatewayRtnCode || data.rtnCode || data.RtnCode,
  );
  const gatewayTradeNo = normalizeString(
      data.gatewayTradeNo ||
      data.tradeNo ||
      data.ecpayTradeNo ||
      data.TradeNo,
  );
  return code === "1" || gatewayTradeNo.length > 0;
}

/**
 * 付款只要已收款、有成功的第三方交易、退款或爭議，就不能直接刪除。
 * @param {Object} payment 付款
 * @return {boolean}
 */
function isPaidOrExternalPayment(payment) {
  const data = payment || {};
  const paidAmount = Number(
      data.paidAmount ||
      data.receivedAmount ||
      data.actualPaidAmount ||
      data.totalPaid ||
      0,
  );
  const status = normalizeString(
      data.status || data.paymentStatus,
  ).toLowerCase();
  return paidAmount > 0 ||
    hasGatewaySuccess(data) ||
    ["paid", "success", "completed", "refunded", "partial_refund"]
        .includes(status);
}

/**
 * @param {Object} value 交易或訂單
 * @return {boolean}
 */
function hasRefundOrDispute(value) {
  const data = value || {};
  const state = [
    data.status,
    data.paymentStatus,
    data.refundStatus,
    data.disputeStatus,
  ].map(normalizeString).join(" ").toLowerCase();
  const refundAmount = Number(data.refundAmount || data.refundedAmount || 0);
  return refundAmount > 0 ||
    state.includes("refund") ||
    state.includes("dispute") ||
    state.includes("chargeback");
}

/**
 * 由交易掃描結果決定是否可完整刪除。不看店家年齡或設定數量。
 * @param {Object} summary 交易與掃描摘要
 * @return {{allowed: boolean, category: string, label: string, blockers: string[]}}
 */
function deletionEligibility(summary) {
  const input = summary || {};
  const blockers = [];
  const missing = ["bookingCount", "paymentCount", "storeOrderCount"]
      .filter((key) => input[key] === null || input[key] === undefined);
  if (input.scanComplete === false || missing.length > 0) {
    blockers.push("掃描結果不完整，無法確認是否可以刪除。");
  }
  if (Number(input.manualCollectionCount || 0) > 0) {
    blockers.push("存在尚未確認歸屬的店家外部資料。");
  }
  if (Number(input.unknownStorageCount || 0) > 0) {
    blockers.push("存在無法確認歸屬的 Storage 檔案。");
  }
  if (Number(input.paidBookingCount || 0) > 0 ||
      Number(input.paidPaymentCount || 0) > 0 ||
      Number(input.paidStoreOrderCount || 0) > 0) {
    blockers.push("此店家曾成功收款，暫不支援永久刪除。");
  }
  if (Number(input.refundingPaymentCount || 0) > 0) {
    blockers.push("此店家曾有退款紀錄，暫不支援永久刪除。");
  }
  if (Number(input.disputeCount || 0) > 0) {
    blockers.push("此店家曾發生付款爭議，暫不支援永久刪除。");
  }
  if (Number(input.completedStayCount || 0) > 0) {
    blockers.push("此店家曾完成住宿服務，暫不支援永久刪除。");
  }
  if (Number(input.completedDaycareCount || 0) > 0) {
    blockers.push("此店家曾完成安親服務，暫不支援永久刪除。");
  }
  if (Number(input.completedStoreOrderCount || 0) > 0) {
    blockers.push("此店家有已完成的商城交易，暫不支援永久刪除。");
  }
  if (Number(input.subscriptionPaymentCount || 0) > 0) {
    blockers.push("此店家有平台訂閱收款紀錄，暫不支援永久刪除。");
  }
  if (Number(input.openBookingCount || 0) > 0) {
    blockers.push("此店家仍有未完成訂單，暫不支援永久刪除。");
  }
  if (Number(input.openStoreOrderCount || 0) > 0) {
    blockers.push("此店家仍有未完成商城訂單，暫不支援永久刪除。");
  }
  if (Number(input.otherBookingCount || 0) > 0) {
    blockers.push("此店家有非取消或拒絕的訂單，暫不支援永久刪除。");
  }
  if (Number(input.unsafePaymentCount || 0) > 0) {
    blockers.push("此店家有無法確認的付款紀錄，暫不支援永久刪除。");
  }
  if (Number(input.realCommercialCount || 0) > 0) {
    blockers.push("此店家有付費方案、合約或必須保存的商業紀錄，暫不支援永久刪除。");
  }
  const unique = [...new Set(blockers)];
  if (unique.length > 0) {
    return {
      allowed: false,
      category: "blocked",
      label: "",
      blockers: unique,
    };
  }
  const hasOrders = Number(input.bookingCount || 0) > 0 ||
    Number(input.storeOrderCount || 0) > 0;
  const hasPayments = Number(input.paymentCount || 0) > 0;
  if (!hasOrders && hasPayments) {
    return {
      allowed: false,
      category: "blocked",
      label: "",
      blockers: ["此店家有付款文件但沒有可核對的取消訂單，暫不支援永久刪除。"],
    };
  }
  if (!hasOrders && !hasPayments) {
    return {
      allowed: true,
      category: "no_transaction",
      label: "無交易店家",
      blockers: [],
    };
  }
  return {
    allowed: true,
    category: "cancelled_orders_only",
    label: "僅有取消訂單、無實際交易",
    blockers: [],
  };
}

/**
 * 訂單的 status 是履約狀態，不能把 completed 誤當付款完成。
 * @param {Object} value 住宿／安親／商城訂單
 * @return {boolean}
 */
function isOrderPaidOrExternal(value) {
  const data = value || {};
  const paymentStatus = normalizeString(data.paymentStatus).toLowerCase();
  const paidAmount = Number(
      data.paidAmount || data.totalPaid || data.netPaid || 0,
  );
  return paidAmount > 0 ||
    hasGatewaySuccess(data) ||
    ["paid", "success", "partially_paid", "partial",
      "refunded", "partial_refund"].includes(paymentStatus);
}

/**
 * @param {Object} booking 住宿／安親訂單
 * @return {boolean}
 */
function isSafeTestBooking(booking) {
  return isCancelledOrRejectedBooking(booking) &&
    !isOrderPaidOrExternal(booking) &&
    !hasRefundOrDispute(booking);
}

/**
 * @param {Object} payment 付款文件
 * @return {boolean}
 */
function isSafeTestPayment(payment) {
  return !isPaidOrExternalPayment(payment) &&
    !hasRefundOrDispute(payment);
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
      value.mode !== INACTIVE_CLEANUP_MODE &&
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
  if (value.scopeConfirmed !== true) {
    blockers.push("最高管理員尚未確認本次清理用途與資料範圍");
  }
  if (value.mode === TEST_RESET_MODE && value.testDataConfirmed !== true) {
    blockers.push("最高管理員尚未確認這間店及其資料為隔離測試資料");
  }
  if (value.mode === INACTIVE_CLEANUP_MODE) {
    return blockers.concat(inactiveCleanupBlockers(value.summary));
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
  INACTIVE_CLEANUP_MODE,
  PERMANENT_DELETE_MODE,
  INACTIVE_MIN_AGE_DAYS,
  TEST_DELETABLE_COLLECTIONS,
  RETAINED_COLLECTIONS,
  SHARED_COLLECTIONS,
  RETAINED_SHOP_SUBCOLLECTIONS,
  SPECIAL_COLLECTIONS,
  TERMINAL_BOOKING_STATUSES,
  normalizeString,
  classifyCollection,
  classifyShopSubcollection,
  classifyStoragePrefix,
  testResetBlockers,
  inactiveCleanupBlockers,
  isOpenBooking,
  isOpenStoreOrder,
  isCancelledOrRejectedBooking,
  isCompletedService,
  isRequiredAuditAction,
  hasRealCommercialObligation,
  hasGatewaySuccess,
  isPaidOrExternalPayment,
  isOrderPaidOrExternal,
  hasRefundOrDispute,
  isSafeTestBooking,
  isSafeTestPayment,
  validateConfirmation,
  jobStartBlockers,
  deletionEligibility,
  storagePrefixes,
};
