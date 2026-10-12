// 檔案名稱：functions/platform/shop_deletion.js
// 功能說明：最高管理員預覽、建立、分批執行與驗證店家刪除工作。

"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const policy = require("./shop_deletion_policy");

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
const REGION = "asia-east1";
const MAX_QUERY_DOCS = 500;
const MAX_STORAGE_FILES = 5000;
const PREVIEW_PAGE_SIZE = 250;
const PREVIEW_MAX_DOCS = 20000;
const MAX_STORAGE_BOOKING_PREFIXES = 1000;
const RECENT_AUTH_SECONDS = 10 * 60;
const PHASE_ONE_PREVIEW_ONLY = true;
const JOB_COLLECTION = "shop_deletion_jobs";
const LOCK_COLLECTION = "shop_deletion_locks";
const AUDIT_COLLECTION = "shop_deletion_audits";
const RETIRED_COLLECTION = "retired_shop_codes";

const DIRECT_STORAGE_PREFIXES = [
  "shops",
  "daily_care_photos",
  "shop_chat",
  "shop_verify_requests",
];

const BOOKING_STORAGE_PREFIXES = [
  "booking_images",
  "review_images",
  "booking_extra_charges",
];

const USER_RELATED_COLLECTION_GROUPS = [
  "policy_acceptances",
  "shop_form_answers",
];

/**
 * @param {*} value 原始值
 * @return {string}
 */
function text(value) {
  return policy.normalizeString(value);
}

/**
 * 每一個 callable 都重新讀取後端平台身分，不相信前端角色。
 * @param {Object} request Callable request
 * @param {boolean} requireRecent 是否要求近期重新驗證
 * @return {Promise<Object>}
 */
async function requireSuperAdmin(request, requireRecent = false) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入平台最高管理員。");
  }
  const uid = request.auth.uid;
  let operator = null;
  if (uid === ROOT_ADMIN_UID) {
    operator = {uid, role: "super_admin", enabled: true, isRoot: true};
  } else {
    const snapshot = await admin.firestore()
        .collection("platform_users").doc(uid).get();
    const data = snapshot.data() || {};
    if (!snapshot.exists ||
        data.enabled !== true ||
        text(data.role) !== "super_admin") {
      throw new HttpsError(
          "permission-denied",
          "只有平台最高管理員可以使用完整刪除功能。",
      );
    }
    operator = {
      uid,
      role: "super_admin",
      enabled: true,
      isRoot: false,
    };
  }
  if (requireRecent) {
    const authTime = Number(request.auth.token.auth_time || 0);
    const now = Math.floor(Date.now() / 1000);
    if (!authTime || now - authTime > RECENT_AUTH_SECONDS) {
      throw new HttpsError(
          "failed-precondition",
          "安全驗證已逾時，請重新登入最高管理員帳號後再執行。",
      );
    }
  }
  return operator;
}

/**
 * @param {*} value Timestamp / Date
 * @return {number}
 */
function milliseconds(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return 0;
}

/**
 * @param {Object} data 文件資料
 * @return {number}
 */
function activityMillis(data) {
  const value = data || {};
  return Math.max(
      milliseconds(value.updatedAt),
      milliseconds(value.lastActivityAt),
      milliseconds(value.createdAt),
  );
}

/**
 * @param {Object} data 文件資料
 * @return {{millis: number, field: string}}
 */
function activityEvidence(data) {
  const value = data || {};
  const candidates = [
    ["lastActivityAt", milliseconds(value.lastActivityAt)],
    ["updatedAt", milliseconds(value.updatedAt)],
    ["createdAt", milliseconds(value.createdAt)],
  ];
  candidates.sort((a, b) => b[1] - a[1]);
  return {
    field: candidates[0][1] > 0 ? candidates[0][0] : "",
    millis: candidates[0][1],
  };
}

/**
 * @param {string[]} statuses 掃描狀態
 * @return {string}
 */
function combineStatuses(statuses) {
  if (statuses.length === 0) return "not_scanned";
  if (statuses.every((status) => status === "success")) return "success";
  if (statuses.every((status) => status === "failed")) return "failed";
  return "partial";
}

/**
 * 分頁讀取 query；到達安全上限時明確標示 partial，不把上限當總數。
 * @param {FirebaseFirestore.Query} query 查詢
 * @param {Object=} options 設定
 * @return {Promise<Object>}
 */
async function scanQuery(query, options = {}) {
  const maxDocs = Number(options.maxDocs || PREVIEW_MAX_DOCS);
  const includeDocs = options.includeDocs === true;
  const docs = [];
  let count = 0;
  let latestActivityMillis = 0;
  let latestActivitySource = "";
  let cursor = null;
  while (count < maxDocs) {
    let page = query.limit(Math.min(PREVIEW_PAGE_SIZE, maxDocs - count));
    if (cursor) page = page.startAfter(cursor);
    const snapshot = await page.get();
    if (snapshot.empty) {
      return {
        status: "success",
        count,
        complete: true,
        docs,
        latestActivityMillis,
        latestActivitySource,
      };
    }
    for (const doc of snapshot.docs) {
      count += 1;
      if (includeDocs) docs.push(doc);
      const evidence = activityEvidence(doc.data());
      if (evidence.millis > latestActivityMillis) {
        latestActivityMillis = evidence.millis;
        latestActivitySource = evidence.field ?
          `${doc.ref.path}.${evidence.field}` : "";
      }
    }
    cursor = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < PREVIEW_PAGE_SIZE) {
      return {
        status: "success",
        count,
        complete: true,
        docs,
        latestActivityMillis,
        latestActivitySource,
      };
    }
  }
  return {
    status: "partial",
    count,
    complete: false,
    docs,
    reason: `超過安全掃描上限 ${maxDocs} 筆`,
    latestActivityMillis,
    latestActivitySource,
  };
}

/**
 * 找出文件內明確的 Storage path 或 Firebase Storage download URL。
 * 一般外部圖片網址不視為可刪除物件。
 * @param {*} value 文件內容
 * @return {string[]}
 */
function storageReferences(value) {
  const output = new Set();
  /**
   * @param {*} item 欄位值
   * @param {string} key 欄位名稱
   */
  function visit(item, key) {
    if (Array.isArray(item)) {
      item.forEach((child) => visit(child, key));
      return;
    }
    if (item && typeof item === "object" &&
        typeof item.toMillis !== "function") {
      Object.entries(item).forEach(([childKey, child]) => {
        visit(child, childKey);
      });
      return;
    }
    if (typeof item !== "string") return;
    const raw = item.trim();
    if (!raw) return;
    const keyName = key.toLowerCase();
    if (keyName.includes("storagepath") ||
        keyName === "path" ||
        keyName.endsWith("imagepath")) {
      output.add(raw.replace(/^\/+/, ""));
      return;
    }
    if (raw.startsWith("gs://")) {
      const slash = raw.indexOf("/", 5);
      if (slash >= 0) output.add(raw.substring(slash + 1));
      return;
    }
    if (raw.includes("firebasestorage.googleapis.com") ||
        raw.includes("storage.googleapis.com")) {
      const match = /\/o\/([^?]+)/.exec(raw);
      if (match) {
        try {
          output.add(decodeURIComponent(match[1]).replace(/^\/+/, ""));
        } catch (_) {
          output.add(match[1].replace(/^\/+/, ""));
        }
        return;
      }
      try {
        const url = new URL(raw);
        if (url.hostname === "storage.googleapis.com") {
          const parts = url.pathname.split("/").filter(Boolean);
          if (parts.length > 1) {
            output.add(decodeURIComponent(parts.slice(1).join("/")));
          }
        }
      } catch (_) {
        // 非合法 URL 不列入可自動判定的 Storage path。
      }
    }
  }
  visit(value, "");
  return [...output];
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @return {Promise<Object>}
 */
async function inspectTopLevelCollections(db, shopId) {
  const collections = await db.listCollections();
  const rows = [];
  let manualCollectionCount = 0;
  let latestActivityMillis = 0;
  let latestActivitySource = "";
  const references = new Set();
  for (const collection of collections) {
    const collectionId = collection.id;
    if (["bookings", "payments", "shop_subscription_payments"]
        .includes(collectionId)) {
      continue;
    }
    const classification = policy.classifyCollection(collectionId);
    if (classification === "special") continue;
    let snapshot;
    try {
      snapshot = await collection.where("shopId", "==", shopId)
          .limit(MAX_QUERY_DOCS + 1).get();
    } catch (error) {
      rows.push({
        collection: collectionId,
        classification: "manual",
        count: null,
        reason: `無法查詢 shopId：${text(error.message)}`,
      });
      manualCollectionCount += 1;
      continue;
    }
    if (snapshot.empty) continue;
    const truncated = snapshot.size > MAX_QUERY_DOCS;
    if (classification === "manual" || truncated) {
      manualCollectionCount += 1;
    }
    for (const doc of snapshot.docs.slice(0, MAX_QUERY_DOCS)) {
      storageReferences(doc.data()).forEach((path) => references.add(path));
      const at = activityMillis(doc.data());
      if (at > latestActivityMillis) {
        latestActivityMillis = at;
        latestActivitySource =
          `${collectionId}/${doc.id} 的 updatedAt/lastActivityAt/createdAt`;
      }
    }
    rows.push({
      collection: collectionId,
      classification: truncated ? "manual" : classification,
      count: snapshot.size,
      truncated,
      reason: truncated ? `超過安全預覽上限 ${MAX_QUERY_DOCS}` : "",
    });
  }
  rows.sort((a, b) => a.collection.localeCompare(b.collection));
  return {
    rows,
    manualCollectionCount,
    latestActivityMillis,
    latestActivitySource,
    storageReferences: [...references],
  };
}

/**
 * 保留會員與寵物主文件，只統計其中明確屬於店家的子文件。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @return {Promise<Object>}
 */
async function inspectUserRelatedGroups(db, shopId) {
  const rows = [];
  let manualCollectionCount = 0;
  for (const collection of USER_RELATED_COLLECTION_GROUPS) {
    try {
      const snapshot = await db.collectionGroup(collection)
          .where("shopId", "==", shopId).limit(MAX_QUERY_DOCS + 1).get();
      const truncated = snapshot.size > MAX_QUERY_DOCS;
      rows.push({
        collectionGroup: collection,
        count: snapshot.size,
        truncated,
      });
      if (truncated) manualCollectionCount += 1;
    } catch (error) {
      rows.push({
        collectionGroup: collection,
        count: null,
        truncated: false,
        reason: `無法查詢 shopId：${text(error.message)}`,
      });
      manualCollectionCount += 1;
    }
  }
  return {rows, manualCollectionCount};
}

/**
 * 統計會員文件中的店家索引；執行時只 arrayRemove 指定店號。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @return {Promise<Object[]>}
 */
async function inspectAccountShopLinks(db, shopId) {
  const rows = [];
  for (const collection of ["users", "user_profiles"]) {
    const snapshot = await db.collection(collection)
        .where("shopIds", "array-contains", shopId)
        .limit(MAX_QUERY_DOCS + 1).get();
    rows.push({
      collection,
      count: snapshot.size,
      truncated: snapshot.size > MAX_QUERY_DOCS,
    });
  }
  return rows;
}

/**
 * 遞迴統計 shops/{shopId} 下所有文件。超過上限就列人工確認。
 * @param {FirebaseFirestore.DocumentReference} root 店家文件
 * @return {Promise<Object>}
 */
async function inspectShopTree(root) {
  let count = 0;
  let truncated = false;
  let latestActivityMillis = 0;
  let latestActivitySource = "";
  const byCollection = {};
  const references = new Set();

  /**
   * @param {FirebaseFirestore.DocumentReference} document 父文件
   * @return {Promise<void>}
   */
  async function visit(document) {
    if (truncated) return;
    const collections = await document.listCollections();
    for (const collection of collections) {
      let cursor = null;
      do {
        let query = collection.limit(PREVIEW_PAGE_SIZE);
        if (cursor) query = query.startAfter(cursor);
        const snapshot = await query.get();
        byCollection[collection.id] =
          Number(byCollection[collection.id] || 0) + snapshot.size;
        for (const child of snapshot.docs) {
          storageReferences(child.data())
              .forEach((path) => references.add(path));
          count += 1;
          const evidence = activityEvidence(child.data());
          if (evidence.millis > latestActivityMillis) {
            latestActivityMillis = evidence.millis;
            latestActivitySource = evidence.field ?
              `${child.ref.path}.${evidence.field}` : "";
          }
          if (count >= PREVIEW_MAX_DOCS) {
            truncated = true;
            return;
          }
          await visit(child.ref);
        }
        cursor = snapshot.empty ?
          null : snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < PREVIEW_PAGE_SIZE) cursor = null;
      } while (cursor);
    }
  }
  await visit(root);
  return {
    count,
    truncated,
    byCollection,
    latestActivityMillis,
    latestActivitySource,
    storageReferences: [...references],
  };
}

/**
 * @param {Object} bucket Storage bucket
 * @param {string} prefix Storage prefix
 * @param {number} limit 上限
 * @return {Promise<Object>}
 */
async function inspectStoragePrefix(bucket, prefix, limit) {
  let count = 0;
  let bytes = 0;
  let pageToken;
  do {
    const [files, nextQuery] = await bucket.getFiles({
      prefix,
      autoPaginate: false,
      maxResults: Math.min(1000, limit - count),
      pageToken,
    });
    for (const file of files) {
      count += 1;
      bytes += Number((file.metadata || {}).size || 0);
      if (count >= limit) break;
    }
    pageToken = nextQuery && nextQuery.pageToken;
  } while (pageToken && count < limit);
  return {prefix, count, bytes, truncated: Boolean(pageToken)};
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @return {Promise<Object>}
 */
async function inspectTransactionBlockers(db, shopId) {
  const bookings = await db.collection("bookings")
      .where("shopId", "==", shopId).limit(MAX_QUERY_DOCS + 1).get();
  let openBookingCount = 0;
  for (const doc of bookings.docs.slice(0, MAX_QUERY_DOCS)) {
    if (policy.isOpenBooking(doc.data())) openBookingCount += 1;
  }
  const payments = await db.collection("payments")
      .where("shopId", "==", shopId).limit(MAX_QUERY_DOCS + 1).get();
  let paidPaymentCount = 0;
  let disputeCount = 0;
  for (const doc of payments.docs.slice(0, MAX_QUERY_DOCS)) {
    const data = doc.data() || {};
    if (policy.isPaidOrExternalPayment(data)) paidPaymentCount += 1;
    const state = text(
        data.disputeStatus || data.refundStatus || data.status,
    ).toLowerCase();
    if (state.includes("dispute") ||
        state.includes("refund") ||
        state.includes("chargeback")) {
      disputeCount += 1;
    }
  }
  const subscriptions = await db.collection("shop_subscription_payments")
      .where("shopId", "==", shopId).limit(1).get();
  return {
    bookingCount: bookings.size,
    openBookingCount,
    bookingTruncated: bookings.size > MAX_QUERY_DOCS,
    paymentCount: payments.size,
    paidPaymentCount,
    paymentTruncated: payments.size > MAX_QUERY_DOCS,
    disputeCount,
    subscriptionPaymentCount: subscriptions.size,
  };
}

/**
 * @param {*} error 錯誤
 * @return {Object}
 */
function publicScanError(error) {
  const code = text(error && error.code) || "unknown";
  const known = {
    "7": "permission-denied",
    "8": "resource-exhausted",
    "9": "failed-precondition",
    "13": "internal",
    "14": "unavailable",
    "permission-denied": "permission-denied",
    "resource-exhausted": "resource-exhausted",
    "failed-precondition": "failed-precondition",
    "unavailable": "unavailable",
    "deadline-exceeded": "deadline-exceeded",
  };
  return {
    errorCode: known[code] || code,
    reason: "掃描失敗，請稍後重新掃描；詳細錯誤已記錄於 Functions 日誌。",
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function inspectTopLevelCollectionsV2(db, shopId, scanId) {
  const rows = [];
  const references = new Set();
  let collections;
  try {
    collections = await db.listCollections();
  } catch (error) {
    console.error("shop deletion preview listCollections failed", {
      scanId,
      code: text(error.code),
      type: text(error.name),
    });
    return {
      status: "failed",
      complete: false,
      rows,
      storageReferences: [],
      failures: [Object.assign({source: "firestore.collections"},
          publicScanError(error))],
    };
  }
  const failures = [];
  for (const collection of collections) {
    const collectionId = collection.id;
    const classification = policy.classifyCollection(collectionId);
    if (classification === "special") continue;
    try {
      const result = await scanQuery(
          collection.where("shopId", "==", shopId),
          {includeDocs: true},
      );
      for (const doc of result.docs) {
        storageReferences(doc.data()).forEach((path) => references.add(path));
      }
      rows.push({
        path: collectionId,
        collection: collectionId,
        relation: "shopId == 指定店號",
        classification,
        status: result.status,
        complete: result.complete,
        count: result.count,
        reason: result.reason || "",
        latestActivityMillis: result.latestActivityMillis,
        latestActivitySource: result.latestActivitySource,
      });
    } catch (error) {
      const detail = Object.assign({
        source: collectionId,
      }, publicScanError(error));
      failures.push(detail);
      rows.push({
        path: collectionId,
        collection: collectionId,
        relation: "shopId == 指定店號",
        classification,
        status: "failed",
        complete: false,
        count: null,
        reason: detail.reason,
        errorCode: detail.errorCode,
      });
      console.error("shop deletion preview collection failed", {
        scanId,
        collection: collectionId,
        code: text(error.code),
        type: text(error.name),
      });
    }
  }
  rows.sort((a, b) => a.collection.localeCompare(b.collection));
  const successfulRows = rows.filter((row) => row.status !== "failed");
  return {
    status: failures.length === 0 &&
      rows.every((row) => row.status === "success") ? "success" :
      successfulRows.length > 0 ? "partial" : "failed",
    complete: failures.length === 0 &&
      rows.every((row) => row.status === "success"),
    rows,
    failures,
    storageReferences: [...references],
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function inspectTransactionsV2(db, shopId, scanId) {
  const sections = [];
  let bookingDocs = [];
  let paymentDocs = [];
  let latestActivityMillis = 0;
  let latestActivitySource = "";
  for (const collection of ["bookings", "payments"]) {
    try {
      const result = await scanQuery(
          db.collection(collection).where("shopId", "==", shopId),
          {includeDocs: true},
      );
      sections.push({
        source: collection,
        status: result.status,
        complete: result.complete,
        count: result.count,
        reason: result.reason || "",
      });
      if (collection === "bookings") bookingDocs = result.docs;
      if (collection === "payments") paymentDocs = result.docs;
      if (result.latestActivityMillis > latestActivityMillis) {
        latestActivityMillis = result.latestActivityMillis;
        latestActivitySource = result.latestActivitySource;
      }
    } catch (error) {
      const detail = publicScanError(error);
      sections.push({
        source: collection,
        status: "failed",
        complete: false,
        count: null,
        errorCode: detail.errorCode,
        reason: detail.reason,
      });
      console.error("shop deletion preview transaction failed", {
        scanId,
        collection,
        code: text(error.code),
        type: text(error.name),
      });
    }
  }
  const bookingSection = sections.find((row) => row.source === "bookings");
  const paymentSection = sections.find((row) => row.source === "payments");
  let stayBookingCount = 0;
  let daycareBookingCount = 0;
  let openBookingCount = 0;
  for (const doc of bookingDocs) {
    const data = doc.data() || {};
    const kind = text(data.bookingKind || data.serviceType).toLowerCase();
    if (kind === "daycare") daycareBookingCount += 1;
    else stayBookingCount += 1;
    if (policy.isOpenBooking(data)) openBookingCount += 1;
  }
  let paidPaymentCount = 0;
  let disputeCount = 0;
  const references = new Set();
  [...bookingDocs, ...paymentDocs].forEach((doc) => {
    storageReferences(doc.data()).forEach((path) => references.add(path));
  });
  for (const doc of paymentDocs) {
    const data = doc.data() || {};
    if (policy.isPaidOrExternalPayment(data)) paidPaymentCount += 1;
    const state = text(
        data.disputeStatus || data.refundStatus || data.status,
    ).toLowerCase();
    if (state.includes("dispute") || state.includes("refund") ||
        state.includes("chargeback")) {
      disputeCount += 1;
    }
  }
  return {
    status: combineStatuses(sections.map((row) => row.status)),
    complete: sections.every((row) => row.status === "success"),
    sections,
    bookingIds: bookingDocs.map((doc) => doc.id),
    bookingCount: bookingSection && bookingSection.status !== "failed" ?
      bookingSection.count : null,
    stayBookingCount: bookingSection && bookingSection.status !== "failed" ?
      stayBookingCount : null,
    daycareBookingCount: bookingSection &&
      bookingSection.status !== "failed" ? daycareBookingCount : null,
    openBookingCount: bookingSection && bookingSection.status !== "failed" ?
      openBookingCount : null,
    paymentCount: paymentSection && paymentSection.status !== "failed" ?
      paymentSection.count : null,
    paidPaymentCount,
    disputeCount,
    subscriptionPaymentCount: null,
    storageReferences: [...references],
    latestActivityMillis,
    latestActivitySource,
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {FirebaseFirestore.DocumentSnapshot} shopSnapshot 店家
 * @param {string} shopId 店家編號
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function resolveOwnerV2(db, shopSnapshot, shopId, scanId) {
  const shop = shopSnapshot.data() || {};
  const declaredUid = text(shop.ownerUid);
  const warnings = [];
  let ownerMembers = [];
  try {
    const result = await scanQuery(
        db.collection("shop_members")
            .where("shopId", "==", shopId)
            .where("role", "==", "owner"),
        {includeDocs: true, maxDocs: 20},
    );
    ownerMembers = result.docs.map((doc) => ({
      uid: text(doc.get("uid")),
      email: text(doc.get("email")),
      path: doc.ref.path,
    }));
  } catch (error) {
    console.error("shop deletion preview owner members failed", {
      scanId,
      code: text(error.code),
      type: text(error.name),
    });
    return Object.assign({
      status: "failed",
      complete: false,
      ownerUid: declaredUid,
      ownerEmail: "",
      source: "shops.ownerUid；shop_members 查詢失敗",
      warnings,
    }, publicScanError(error));
  }
  const memberUids = [...new Set(ownerMembers.map((row) => row.uid)
      .filter(Boolean))];
  if (declaredUid && memberUids.length > 0 &&
      !memberUids.includes(declaredUid)) {
    warnings.push("shops.ownerUid 與 shop_members owner 不一致");
  }
  if (memberUids.length > 1) warnings.push("找到多位 owner，需人工確認");
  const ownerUid = declaredUid ||
    (memberUids.length === 1 ? memberUids[0] : "");
  let ownerEmail = "";
  const sources = [];
  if (declaredUid) sources.push("shops.ownerUid");
  if (memberUids.includes(ownerUid)) sources.push("shop_members owner");
  if (ownerUid) {
    try {
      const authUser = await admin.auth().getUser(ownerUid);
      ownerEmail = text(authUser.email);
      sources.push("Firebase Auth");
    } catch (error) {
      if (text(error.code) !== "auth/user-not-found") {
        warnings.push("Firebase Auth 店主資料無法讀取");
      }
    }
    try {
      const user = await db.collection("users").doc(ownerUid).get();
      const userEmail = user.exists ? text(user.get("email")) : "";
      if (!ownerEmail) ownerEmail = userEmail;
      if (userEmail) sources.push("users/{uid}");
      if (ownerEmail && userEmail &&
          ownerEmail.toLowerCase() !== userEmail.toLowerCase()) {
        warnings.push("Firebase Auth 與 users Email 不一致");
      }
    } catch (_) {
      warnings.push("users 店主資料無法讀取");
    }
  } else {
    warnings.push("沒有可唯一確認的店主 UID");
  }
  return {
    status: warnings.isEmpty ? "success" : "partial",
    complete: warnings.isEmpty && ownerUid.isNotEmpty,
    ownerUid,
    ownerEmail,
    source: sources.join("、"),
    ownerMemberCount: ownerMembers.length,
    warnings,
  };
}

/**
 * @param {Object} bucket Storage bucket
 * @param {string[]} prefixes 精確前綴
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function inspectStorageV2(bucket, prefixes, scanId) {
  const rows = [];
  for (const prefix of prefixes) {
    try {
      const row = await inspectStoragePrefix(
          bucket, prefix, MAX_STORAGE_FILES,
      );
      rows.push(Object.assign({}, row, {
        status: row.truncated ? "partial" : "success",
        complete: !row.truncated,
        ownership: "confirmed",
        reason: row.truncated ? "超過單一路徑安全掃描上限" : "",
      }));
    } catch (error) {
      const detail = publicScanError(error);
      rows.push({
        prefix,
        status: "failed",
        complete: false,
        count: null,
        bytes: null,
        ownership: "confirmed",
        errorCode: detail.errorCode,
        reason: detail.reason,
      });
      console.error("shop deletion preview storage prefix failed", {
        scanId,
        prefix,
        code: text(error.code),
        type: text(error.name),
      });
    }
  }
  const knownRows = rows.filter((row) => row.status !== "failed");
  return {
    status: combineStatuses(rows.map((row) => row.status)),
    complete: rows.every((row) => row.status === "success"),
    prefixes: rows,
    fileCount: rows.some((row) => row.status === "failed") ? null :
      knownRows.reduce((sum, row) => sum + Number(row.count || 0), 0),
    totalBytes: rows.some((row) => row.status === "failed") ? null :
      knownRows.reduce((sum, row) => sum + Number(row.bytes || 0), 0),
  };
}

/**
 * @param {string} shopId 店家編號
 * @return {Promise<Object>}
 */
async function buildPreview(shopId) {
  const scanId = crypto.randomUUID();
  const startedAtMillis = Date.now();
  const db = admin.firestore();
  const shopRef = db.collection("shops").doc(shopId);
  let shopSnapshot;
  try {
    shopSnapshot = await shopRef.get();
  } catch (error) {
    console.error("shop deletion preview shop read failed", {
      scanId,
      code: text(error.code),
      type: text(error.name),
    });
    throw new HttpsError(
        "unavailable",
        "無法讀取店家主文件，請稍後重新掃描。",
        {scanId, stage: "shop", retryable: true},
    );
  }
  if (!shopSnapshot.exists) {
    throw new HttpsError("not-found", "找不到指定店家。");
  }
  const shop = shopSnapshot.data() || {};
  const failures = [];
  const [top, transactions, owner] = await Promise.all([
    inspectTopLevelCollectionsV2(db, shopId, scanId),
    inspectTransactionsV2(db, shopId, scanId),
    resolveOwnerV2(db, shopSnapshot, shopId, scanId),
  ]);
  failures.push(...(top.failures || []));

  let tree;
  try {
    const value = await inspectShopTree(shopRef);
    tree = Object.assign({}, value, {
      status: value.truncated ? "partial" : "success",
      complete: !value.truncated,
      reason: value.truncated ? "店家子集合超過安全掃描上限" : "",
    });
  } catch (error) {
    const detail = Object.assign(
        {source: `shops/${shopId}/**`},
        publicScanError(error),
    );
    failures.push(detail);
    tree = {
      status: "failed",
      complete: false,
      count: null,
      byCollection: {},
      storageReferences: [],
      latestActivityMillis: 0,
      latestActivitySource: "",
      reason: detail.reason,
      errorCode: detail.errorCode,
    };
  }

  let userRelated;
  try {
    userRelated = await inspectUserRelatedGroups(db, shopId);
    for (const row of userRelated.rows) {
      row.status = row.reason ? "failed" :
        row.truncated ? "partial" : "success";
      row.complete = row.status === "success";
    }
    userRelated.status = combineStatuses(
        userRelated.rows.map((row) => row.status),
    );
    if (userRelated.status === "not_scanned") userRelated.status = "success";
    userRelated.complete =
      userRelated.rows.every((row) => row.status === "success");
  } catch (error) {
    const detail = Object.assign(
        {source: "member-related collection groups"},
        publicScanError(error),
    );
    failures.push(detail);
    userRelated = {
      status: "failed",
      complete: false,
      rows: [],
      manualCollectionCount: 1,
    };
  }

  let accountLinks;
  try {
    accountLinks = await inspectAccountShopLinks(db, shopId);
    accountLinks.forEach((row) => {
      row.status = row.truncated ? "partial" : "success";
      row.complete = !row.truncated;
    });
  } catch (error) {
    const detail = Object.assign(
        {source: "users/user_profiles.shopIds"},
        publicScanError(error),
    );
    failures.push(detail);
    accountLinks = [{
      collection: "users / user_profiles",
      status: "failed",
      complete: false,
      count: null,
      reason: detail.reason,
      errorCode: detail.errorCode,
    }];
  }

  let paymentCredentialsCount = null;
  let paymentCredentialsStatus = "not_scanned";
  try {
    const paymentCredentials = await db.collection("payment_credentials")
        .doc(shopId).get();
    paymentCredentialsCount = paymentCredentials.exists ? 1 : 0;
    paymentCredentialsStatus = "success";
  } catch (error) {
    const detail = Object.assign(
        {source: `payment_credentials/${shopId}`},
        publicScanError(error),
    );
    failures.push(detail);
    paymentCredentialsStatus = "failed";
  }

  /**
   * @param {FirebaseFirestore.Query} query 查詢
   * @param {string} label 顯示名稱
   * @param {string} source 資料來源
   * @return {Promise<Object>}
   */
  async function memberCount(query, label, source) {
    try {
      const result = await scanQuery(query);
      return {
        status: result.status,
        complete: result.complete,
        count: result.count,
        label,
        source,
        reason: result.reason || "",
      };
    } catch (error) {
      const detail = publicScanError(error);
      failures.push(Object.assign({source}, detail));
      return Object.assign({
        status: "failed",
        complete: false,
        count: null,
        label,
        source,
      }, detail);
    }
  }
  const [shopMembers, customerMembers] = await Promise.all([
    memberCount(
        db.collection("shop_members").where("shopId", "==", shopId),
        "店主／員工權限",
        "shop_members.shopId",
    ),
    memberCount(
        shopRef.collection("members"),
        "店家會員",
        `shops/${shopId}/members`,
    ),
  ]);

  const specialRows = [{
    path: `shops/${shopId}`,
    collection: "shops",
    relation: "文件 ID == 指定店號",
    classification: "special",
    status: "success",
    complete: true,
    count: 1,
    reason: "",
  }, {
    path: `payment_credentials/${shopId}`,
    collection: "payment_credentials",
    relation: "文件 ID == 指定店號",
    classification: "special",
    status: paymentCredentialsStatus,
    complete: paymentCredentialsStatus === "success",
    count: paymentCredentialsCount,
    reason: paymentCredentialsStatus === "failed" ?
      "敏感憑證文件掃描失敗" : "",
  }];
  try {
    const counter = await db.collection("booking_counters").doc(shopId).get();
    specialRows.push({
      path: `booking_counters/${shopId}`,
      collection: "booking_counters",
      relation: "文件 ID == 指定店號",
      classification: "special",
      status: "success",
      complete: true,
      count: counter.exists ? 1 : 0,
      reason: "",
    });
  } catch (error) {
    const detail = publicScanError(error);
    failures.push(Object.assign({source: "booking_counters"}, detail));
    specialRows.push({
      path: `booking_counters/${shopId}`,
      collection: "booking_counters",
      relation: "文件 ID == 指定店號",
      classification: "special",
      status: "failed",
      complete: false,
      count: null,
      reason: detail.reason,
      errorCode: detail.errorCode,
    });
  }
  for (const collection of [
    "sales_owner_locks",
    "sales_shop_create_requests",
  ]) {
    try {
      const result = await scanQuery(
          db.collection(collection).where("shopId", "==", shopId),
      );
      specialRows.push({
        path: collection,
        collection,
        relation: "shopId == 指定店號",
        classification: "special",
        status: result.status,
        complete: result.complete,
        count: result.count,
        reason: result.reason || "",
      });
    } catch (error) {
      const detail = publicScanError(error);
      failures.push(Object.assign({source: collection}, detail));
      specialRows.push({
        path: collection,
        collection,
        relation: "shopId == 指定店號",
        classification: "special",
        status: "failed",
        complete: false,
        count: null,
        reason: detail.reason,
        errorCode: detail.errorCode,
      });
    }
  }

  try {
    const subscription = await scanQuery(
        db.collection("shop_subscription_payments")
            .where("shopId", "==", shopId),
    );
    transactions.subscriptionPaymentCount = subscription.count;
    transactions.sections.push({
      source: "shop_subscription_payments",
      status: subscription.status,
      complete: subscription.complete,
      count: subscription.count,
      reason: subscription.reason || "",
    });
  } catch (error) {
    const detail = publicScanError(error);
    transactions.subscriptionPaymentCount = null;
    transactions.sections.push(Object.assign({
      source: "shop_subscription_payments",
      status: "failed",
      complete: false,
      count: null,
    }, detail));
    transactions.status = transactions.status === "failed" ?
      "failed" : "partial";
    transactions.complete = false;
    failures.push(Object.assign({
      source: "shop_subscription_payments",
    }, detail));
  }
  transactions.status = combineStatuses(
      transactions.sections.map((row) => row.status),
  );
  transactions.complete =
    transactions.sections.every((row) => row.status === "success");

  const allBookingIds = transactions.bookingIds || [];
  const storageBookingIds =
    allBookingIds.slice(0, MAX_STORAGE_BOOKING_PREFIXES);
  const storage = await inspectStorageV2(
      admin.storage().bucket(),
      policy.storagePrefixes(shopId, storageBookingIds),
      scanId,
  );
  if (allBookingIds.length > storageBookingIds.length) {
    storage.status = "partial";
    storage.complete = false;
    storage.fileCount = null;
    storage.totalBytes = null;
    storage.prefixes.push({
      prefix: "booking_images|review_images|booking_extra_charges/{bookingId}",
      status: "partial",
      complete: false,
      count: null,
      bytes: null,
      ownership: "confirmed",
      reason:
        `訂單數超過 ${MAX_STORAGE_BOOKING_PREFIXES}，其餘路徑未掃描`,
    });
  }
  storage.prefixes.filter((row) => row.status === "failed")
      .forEach((row) => failures.push({
        source: row.prefix,
        errorCode: row.errorCode,
        reason: row.reason,
      }));

  const allowedPrefixes = storage.prefixes.map((row) => row.prefix);
  const protectedPrefixes = [
    "platform/",
    "pets/",
    "platform_contact_requests/",
  ];
  const allReferences = [...new Set([
    ...top.storageReferences,
    ...(transactions.storageReferences || []),
    ...(tree.storageReferences || []),
    ...storageReferences(shop),
  ])];
  const retainedStorageReferences = allReferences.filter((path) =>
    protectedPrefixes.some((prefix) => path.startsWith(prefix)),
  );
  const unknownStorageReferences = allReferences.filter((path) =>
    !allowedPrefixes.some((prefix) => path.startsWith(prefix)) &&
    !protectedPrefixes.some((prefix) => path.startsWith(prefix)),
  );
  let lastActivityAtMillis = milliseconds(shop.lastActivityAt);
  let lastActivityBasis = lastActivityAtMillis > 0 ?
    `shops/${shopId}.lastActivityAt` : "";
  for (const row of top.rows) {
    if (Number(row.latestActivityMillis || 0) > lastActivityAtMillis) {
      lastActivityAtMillis = Number(row.latestActivityMillis);
      lastActivityBasis = row.latestActivitySource;
    }
  }
  if (Number(tree.latestActivityMillis || 0) > lastActivityAtMillis) {
    lastActivityAtMillis = Number(tree.latestActivityMillis);
    lastActivityBasis = tree.latestActivitySource;
  }
  if (Number(transactions.latestActivityMillis || 0) >
      lastActivityAtMillis) {
    lastActivityAtMillis = Number(transactions.latestActivityMillis);
    lastActivityBasis = transactions.latestActivitySource;
  }
  const createdAtMillis = milliseconds(shop.createdAt) ||
    milliseconds(shopSnapshot.createTime);
  const updatedAtMillis = milliseconds(shop.updatedAt) ||
    milliseconds(shopSnapshot.updateTime);
  const accountLinksStatus = combineStatuses(
      accountLinks.map((row) => row.status),
  );
  const sectionStatuses = [
    top.status,
    tree.status,
    userRelated.status,
    accountLinksStatus,
    paymentCredentialsStatus,
    shopMembers.status,
    customerMembers.status,
    combineStatuses(specialRows.map((row) => row.status)),
    transactions.status,
    owner.status,
    storage.status,
  ];
  const complete = sectionStatuses.every((status) => status === "success") &&
    unknownStorageReferences.length === 0;
  const summary = Object.assign({}, transactions, {
    manualCollectionCount:
      top.rows.filter((row) => row.classification === "manual" &&
        Number(row.count || 0) > 0).length +
      userRelated.manualCollectionCount +
      accountLinks.filter((row) => row.truncated).length +
      (tree.truncated ? 1 : 0),
    unknownStorageCount:
      storage.prefixes.filter((row) => row.status !== "success").length +
      unknownStorageReferences.length,
  });
  const blockers = policy.testResetBlockers(summary);
  if (!complete) {
    blockers.push("掃描不完整，第一階段禁止建立或執行刪除工作");
  }
  blockers.push("第一階段僅提供可信預覽，所有刪除工作入口均已鎖定");
  const transactionRows = transactions.sections.map((row) => ({
    path: row.source,
    collection: row.source,
    relation: "shopId == 指定店號",
    classification: policy.classifyCollection(row.source),
    status: row.status,
    complete: row.complete,
    count: row.count,
    reason: row.reason || "",
    errorCode: row.errorCode || "",
  }));
  const inventoryRows = [...top.rows, ...transactionRows, ...specialRows]
      .sort((a, b) => a.collection.localeCompare(b.collection));
  const firestoreDeleteCount = inventoryRows
      .filter((row) => row.classification === "delete" &&
        row.status !== "failed")
      .reduce((sum, row) => sum + Number(row.count || 0),
          Number(tree.count || 0) + 1) +
      userRelated.rows.reduce(
          (sum, row) => sum + Number(row.count || 0), 0,
      ) +
      accountLinks.reduce((sum, row) => sum + Number(row.count || 0), 0) +
      Number(paymentCredentialsCount || 0);
  const completedAtMillis = Date.now();
  const combinedStatus = combineStatuses(sectionStatuses);
  return {
    scan: {
      scanId,
      status: complete ? "success" :
        combinedStatus === "success" ? "partial" : combinedStatus,
      complete,
      startedAtMillis,
      completedAtMillis,
      durationMillis: completedAtMillis - startedAtMillis,
      failures,
      warnings: [
        ...(owner.warnings || []),
        ...unknownStorageReferences.map((path) =>
          `Storage 引用無法確認擁有權：${path}`),
      ],
      projectId: text(admin.app().options.projectId),
      region: REGION,
    },
    shop: {
      shopId,
      shopCode: text(shop.shopCode || shopId),
      name: text(shop.name),
      ownerUid: owner.ownerUid,
      ownerEmail: owner.ownerEmail,
      ownerResolutionStatus: owner.status,
      ownerResolutionSource: owner.source,
      ownerWarnings: owner.warnings,
      status: text(shop.status || "active"),
      createdAtMillis,
      createdAtSource: milliseconds(shop.createdAt) > 0 ?
        "shops.createdAt" : "Firestore document createTime",
      updatedAtMillis,
      updatedAtSource: milliseconds(shop.updatedAt) > 0 ?
        "shops.updatedAt" : "Firestore document updateTime",
      lastActivityAtMillis,
      lastActivityBasis: lastActivityBasis || "無可靠活動時間欄位",
    },
    firestore: {
      status: combineStatuses([
        top.status,
        tree.status,
        userRelated.status,
        shopMembers.status,
        customerMembers.status,
        combineStatuses(specialRows.map((row) => row.status)),
      ]),
      complete: top.complete && tree.complete && userRelated.complete &&
        shopMembers.complete && customerMembers.complete &&
        specialRows.every((row) => row.status === "success"),
      shopTreeCount: tree.count === null ? null : tree.count + 1,
      shopTreeStatus: tree.status,
      shopSubcollections: tree.byCollection,
      userRelatedCollections: userRelated.rows,
      accountShopLinks: accountLinks,
      paymentCredentialsCount,
      paymentCredentialsStatus,
      memberCounts: [customerMembers, shopMembers],
      collections: inventoryRows,
      estimatedDeleteCount: firestoreDeleteCount,
    },
    storage: Object.assign({}, storage, {
      retainedReferences: retainedStorageReferences,
      unknownReferences: unknownStorageReferences,
    }),
    transactions,
    retained: inventoryRows
        .filter((row) => row.classification === "retain"),
    manual: inventoryRows
        .filter((row) => row.classification === "manual" &&
          (row.status === "failed" || Number(row.count || 0) > 0)),
    blockers,
    formalDeletionEnabled: false,
    executionEnabled: false,
    writeGuardLimitation:
      "目前 Rules 未檢查 deletionState，刪除期間無法保證阻止所有客戶端直寫。",
  };
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function previewHandler(request) {
  await requireSuperAdmin(request);
  const shopId = text((request.data || {}).shopId);
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家編號。");
  }
  try {
    return await buildPreview(shopId);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const scanId = crypto.randomUUID();
    console.error("shop deletion preview unexpected failure", {
      scanId,
      shopId,
      code: text(error.code),
      type: text(error.name),
    });
    throw new HttpsError(
        "internal",
        "預覽掃描發生未預期錯誤，請使用掃描識別碼查閱 Functions 日誌。",
        {scanId, stage: "preview", retryable: true},
    );
  }
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function createJobHandler(request) {
  const operator = await requireSuperAdmin(request, true);
  if (PHASE_ONE_PREVIEW_ONLY) {
    throw new HttpsError(
        "failed-precondition",
        "第一階段只開放可信預覽，禁止建立任何刪除工作。",
        {phaseOnePreviewOnly: true},
    );
  }
  const data = request.data || {};
  const shopId = text(data.shopId);
  const mode = text(data.mode);
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家編號。");
  }
  const preview = await buildPreview(shopId);
  const confirmation = {
    shopCode: preview.shop.shopCode,
    typedShopCode: text(data.typedShopCode),
    reason: text(data.reason),
    irreversibleAcknowledged: data.irreversibleAcknowledged === true,
    testDataConfirmed: data.testDataConfirmed === true,
    mode,
    summary: Object.assign({}, preview.transactions, {
      manualCollectionCount: preview.manual.length,
      unknownStorageCount:
        preview.storage.prefixes.filter((row) => row.truncated).length +
        preview.storage.unknownReferences.length,
    }),
  };
  const blockers = policy.jobStartBlockers(confirmation)
      .concat(preview.blockers);
  const uniqueBlockers = [...new Set(blockers)];
  if (uniqueBlockers.length > 0) {
    throw new HttpsError(
        "failed-precondition",
        uniqueBlockers.join("；"),
        {blockers: uniqueBlockers},
    );
  }
  const db = admin.firestore();
  const jobRef = db.collection(JOB_COLLECTION).doc();
  const lockRef = db.collection(LOCK_COLLECTION).doc(shopId);
  const auditRef = db.collection(AUDIT_COLLECTION).doc(jobRef.id);
  const shopRef = db.collection("shops").doc(shopId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.runTransaction(async (tx) => {
    const [shopSnapshot, lockSnapshot] = await Promise.all([
      tx.get(shopRef),
      tx.get(lockRef),
    ]);
    if (!shopSnapshot.exists) {
      throw new HttpsError("not-found", "店家已不存在。");
    }
    if (lockSnapshot.exists &&
        text(lockSnapshot.get("status")) !== "failed") {
      throw new HttpsError(
          "already-exists",
          "這間店已有刪除工作，不能重複建立。",
      );
    }
    const shop = shopSnapshot.data() || {};
    tx.create(jobRef, {
      jobId: jobRef.id,
      shopId,
      shopCode: preview.shop.shopCode,
      shopName: preview.shop.name,
      ownerUid: preview.shop.ownerUid,
      mode,
      reason: confirmation.reason,
      operatorUid: operator.uid,
      status: "pending",
      phase: "revoke_access",
      deletedFirestore: 0,
      deletedStorage: 0,
      failedCount: 0,
      retainedCount: preview.retained.reduce(
          (sum, row) => sum + Number(row.count || 0), 0,
      ),
      previousShopState: {
        status: text(shop.status || "active"),
        ownerUid: text(shop.ownerUid),
        isOpen: shop.isOpen !== false,
        bookingEnabled: shop.bookingEnabled !== false,
      },
      createdAt: now,
      updatedAt: now,
      completedAt: null,
    });
    tx.set(lockRef, {
      shopId,
      jobId: jobRef.id,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });
    tx.create(auditRef, {
      jobId: jobRef.id,
      operatorUid: operator.uid,
      shopCode: preview.shop.shopCode,
      reason: confirmation.reason,
      mode,
      result: "started",
      startedAt: now,
      completedAt: null,
      failureSummary: "",
    });
    tx.update(shopRef, {
      deletionState: "deleting",
      deletionJobId: jobRef.id,
      status: "suspended",
      isOpen: false,
      bookingEnabled: false,
      previousOwnerUid: text(shop.ownerUid),
      ownerUid: admin.firestore.FieldValue.delete(),
      updatedAt: now,
    });
  });
  return {jobId: jobRef.id, status: "pending", phase: "revoke_access"};
}

/**
 * @param {FirebaseFirestore.Query} query 查詢
 * @param {number} limit 上限
 * @return {Promise<number>}
 */
async function deleteQueryDocuments(query, limit = 150) {
  const snapshot = await query.limit(Math.min(limit, 25)).get();
  if (snapshot.empty) return 0;
  // recursiveDelete 也會移除未知的子集合，避免留下 orphan documents。
  for (const doc of snapshot.docs) {
    await admin.firestore().recursiveDelete(doc.ref);
  }
  return snapshot.size;
}

/**
 * @param {Object} bucket Storage bucket
 * @param {string} prefix prefix
 * @return {Promise<number>}
 */
async function deleteStoragePage(bucket, prefix) {
  const [files] = await bucket.getFiles({
    prefix,
    autoPaginate: false,
    maxResults: 250,
  });
  let deleted = 0;
  for (const file of files) {
    try {
      await file.delete({ignoreNotFound: true});
      deleted += 1;
    } catch (error) {
      error.storageObject = file.name;
      throw error;
    }
  }
  return deleted;
}

/**
 * @param {FirebaseFirestore.DocumentReference} jobRef 工作
 * @param {Object} patch 更新
 */
async function patchJob(jobRef, patch) {
  await jobRef.set(Object.assign({}, patch, {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }), {merge: true});
}

/**
 * @param {FirebaseFirestore.DocumentReference} jobRef 工作
 * @param {Object} job 工作資料
 * @return {Promise<void>}
 */
async function runJobStep(jobRef, job) {
  const db = admin.firestore();
  const shopId = text(job.shopId);
  const phase = text(job.phase);
  if (phase === "revoke_access") {
    const count = await deleteQueryDocuments(
        db.collection("shop_members").where("shopId", "==", shopId),
    );
    if (count > 0) {
      await patchJob(jobRef, {
        deletedFirestore: admin.firestore.FieldValue.increment(count),
      });
      return;
    }
    await patchJob(jobRef, {
      phase: "storage_direct",
      storagePrefixIndex: 0,
    });
    return;
  }
  if (phase === "storage_direct") {
    const index = Number(job.storagePrefixIndex || 0);
    if (index >= DIRECT_STORAGE_PREFIXES.length) {
      await patchJob(jobRef, {
        phase: "storage_booking",
        currentBookingId: "",
        bookingPrefixIndex: 0,
      });
      return;
    }
    const prefix = `${DIRECT_STORAGE_PREFIXES[index]}/${shopId}/`;
    const deleted = await deleteStoragePage(admin.storage().bucket(), prefix);
    if (deleted === 0) {
      await patchJob(jobRef, {storagePrefixIndex: index + 1});
    } else {
      await patchJob(jobRef, {
        deletedStorage: admin.firestore.FieldValue.increment(deleted),
      });
    }
    return;
  }
  if (phase === "storage_booking") {
    let bookingId = text(job.currentBookingId);
    if (!bookingId) {
      const bookings = await db.collection("bookings")
          .where("shopId", "==", shopId).limit(1).get();
      bookingId = bookings.empty ? "" : bookings.docs[0].id;
    }
    if (!bookingId) {
      await patchJob(jobRef, {
        phase: "cross_collections",
        collectionIndex: 0,
        currentBookingId: admin.firestore.FieldValue.delete(),
        bookingPrefixIndex: admin.firestore.FieldValue.delete(),
      });
      return;
    }
    const prefixIndex = Number(job.bookingPrefixIndex || 0);
    if (prefixIndex >= BOOKING_STORAGE_PREFIXES.length) {
      const bookingRef = db.collection("bookings").doc(bookingId);
      if ((await bookingRef.get()).exists) {
        await db.recursiveDelete(bookingRef);
      }
      await patchJob(jobRef, {
        currentBookingId: admin.firestore.FieldValue.delete(),
        bookingPrefixIndex: 0,
        deletedFirestore: admin.firestore.FieldValue.increment(1),
      });
      return;
    }
    const prefix =
      `${BOOKING_STORAGE_PREFIXES[prefixIndex]}/${bookingId}/`;
    const deleted = await deleteStoragePage(admin.storage().bucket(), prefix);
    if (deleted === 0) {
      await patchJob(jobRef, {
        currentBookingId: bookingId,
        bookingPrefixIndex: prefixIndex + 1,
      });
    } else {
      await patchJob(jobRef, {
        currentBookingId: bookingId,
        deletedStorage: admin.firestore.FieldValue.increment(deleted),
      });
    }
    return;
  }
  if (phase === "cross_collections") {
    const collections = [...policy.TEST_DELETABLE_COLLECTIONS]
        .filter((id) => id !== "shop_members").sort();
    const index = Number(job.collectionIndex || 0);
    if (index >= collections.length) {
      await patchJob(jobRef, {
        phase: "user_related_collections",
        relatedCollectionIndex: 0,
      });
      return;
    }
    const collectionId = collections[index];
    const count = await deleteQueryDocuments(
        db.collection(collectionId).where("shopId", "==", shopId),
    );
    if (count === 0) {
      await patchJob(jobRef, {collectionIndex: index + 1});
    } else {
      await patchJob(jobRef, {
        deletedFirestore: admin.firestore.FieldValue.increment(count),
      });
    }
    return;
  }
  if (phase === "user_related_collections") {
    const index = Number(job.relatedCollectionIndex || 0);
    if (index >= USER_RELATED_COLLECTION_GROUPS.length) {
      await patchJob(jobRef, {
        phase: "account_shop_links",
        accountCollectionIndex: 0,
      });
      return;
    }
    const collection = USER_RELATED_COLLECTION_GROUPS[index];
    const count = await deleteQueryDocuments(
        db.collectionGroup(collection).where("shopId", "==", shopId),
    );
    if (count === 0) {
      await patchJob(jobRef, {relatedCollectionIndex: index + 1});
    } else {
      await patchJob(jobRef, {
        deletedFirestore: admin.firestore.FieldValue.increment(count),
      });
    }
    return;
  }
  if (phase === "account_shop_links") {
    const collections = ["users", "user_profiles"];
    const index = Number(job.accountCollectionIndex || 0);
    if (index >= collections.length) {
      await patchJob(jobRef, {phase: "reset_creation_locks"});
      return;
    }
    const snapshot = await db.collection(collections[index])
        .where("shopIds", "array-contains", shopId).limit(25).get();
    if (snapshot.empty) {
      await patchJob(jobRef, {accountCollectionIndex: index + 1});
      return;
    }
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.update(doc.ref, {
        shopIds: admin.firestore.FieldValue.arrayRemove(shopId),
      });
    }
    await batch.commit();
    await patchJob(jobRef, {
      deletedFirestore: admin.firestore.FieldValue.increment(snapshot.size),
    });
    return;
  }
  if (phase === "reset_creation_locks") {
    const ownerUid = text(job.ownerUid);
    let deleted = 0;
    const paymentCredentials =
      db.collection("payment_credentials").doc(shopId);
    if ((await paymentCredentials.get()).exists) {
      await paymentCredentials.delete();
      deleted += 1;
    }
    const bookingCounter = db.collection("booking_counters").doc(shopId);
    if ((await bookingCounter.get()).exists) {
      await bookingCounter.delete();
      deleted += 1;
    }
    if (ownerUid) {
      const ownerLock = db.collection("sales_owner_locks").doc(ownerUid);
      const lock = await ownerLock.get();
      if (lock.exists && text(lock.get("shopId")) === shopId) {
        await ownerLock.delete();
        deleted += 1;
      }
    }
    deleted += await deleteQueryDocuments(
        db.collection("sales_shop_create_requests")
            .where("shopId", "==", shopId),
    );
    await patchJob(jobRef, {
      phase: "delete_shop_tree",
      deletedFirestore: admin.firestore.FieldValue.increment(deleted),
    });
    return;
  }
  if (phase === "delete_shop_tree") {
    const shopRef = db.collection("shops").doc(shopId);
    if ((await shopRef.get()).exists) {
      await db.recursiveDelete(shopRef);
      await patchJob(jobRef, {
        deletedFirestore: admin.firestore.FieldValue.increment(1),
      });
    }
    await patchJob(jobRef, {phase: "retire_shop_code"});
    return;
  }
  if (phase === "retire_shop_code") {
    await db.collection(RETIRED_COLLECTION).doc(text(job.shopCode || shopId))
        .set({
          shopCode: text(job.shopCode || shopId),
          deletionJobId: jobRef.id,
          mode: text(job.mode),
          retiredAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: false});
    await patchJob(jobRef, {phase: "verify"});
    return;
  }
  if (phase === "verify") {
    const result = await verifyDeletion(jobRef.id, job);
    if (!result.complete) {
      throw new Error(`殘留驗證未通過：${result.residual.join("；")}`);
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(jobRef);
      if (!fresh.exists) return;
      tx.update(jobRef, {
        status: "completed",
        phase: "completed",
        lastError: admin.firestore.FieldValue.delete(),
        completedAt: now,
        updatedAt: now,
      });
      tx.set(db.collection(LOCK_COLLECTION).doc(shopId), {
        status: "completed",
        completedAt: now,
        updatedAt: now,
      }, {merge: true});
      tx.set(db.collection(AUDIT_COLLECTION).doc(jobRef.id), {
        result: "completed",
        completedAt: now,
        failureSummary: "",
      }, {merge: true});
    });
  }
}

/**
 * @param {string} jobId 工作 ID
 * @param {Object=} knownJob 已讀工作
 * @return {Promise<Object>}
 */
async function verifyDeletion(jobId, knownJob) {
  const db = admin.firestore();
  const jobRef = db.collection(JOB_COLLECTION).doc(jobId);
  const job = knownJob || (await jobRef.get()).data() || {};
  const shopId = text(job.shopId);
  if (!shopId) return {complete: false, residual: ["工作缺少 shopId"]};
  const residual = [];
  if ((await db.collection("shops").doc(shopId).get()).exists) {
    residual.push(`shops/${shopId}`);
  }
  for (const collectionId of policy.TEST_DELETABLE_COLLECTIONS) {
    const snapshot = await db.collection(collectionId)
        .where("shopId", "==", shopId).limit(1).get();
    if (!snapshot.empty) residual.push(`${collectionId} 尚有文件`);
  }
  for (const collection of USER_RELATED_COLLECTION_GROUPS) {
    const snapshot = await db.collectionGroup(collection)
        .where("shopId", "==", shopId).limit(1).get();
    if (!snapshot.empty) {
      residual.push(`${collection} 集合群組尚有文件`);
    }
  }
  for (const collection of ["users", "user_profiles"]) {
    const snapshot = await db.collection(collection)
        .where("shopIds", "array-contains", shopId).limit(1).get();
    if (!snapshot.empty) {
      residual.push(`${collection}.shopIds 尚有店家關聯`);
    }
  }
  for (const prefix of DIRECT_STORAGE_PREFIXES) {
    const [files] = await admin.storage().bucket().getFiles({
      prefix: `${prefix}/${shopId}/`,
      maxResults: 1,
      autoPaginate: false,
    });
    if (files.length > 0) residual.push(`${prefix}/${shopId}/ 尚有檔案`);
  }
  const ownerUid = text(job.ownerUid);
  if (ownerUid) {
    const lock = await db.collection("sales_owner_locks").doc(ownerUid).get();
    if (lock.exists && text(lock.get("shopId")) === shopId) {
      residual.push("sales_owner_locks 尚未清除");
    }
  }
  const request = await db.collection("sales_shop_create_requests")
      .where("shopId", "==", shopId).limit(1).get();
  if (!request.empty) residual.push("sales_shop_create_requests 尚未清除");
  if ((await db.collection("booking_counters").doc(shopId).get()).exists) {
    residual.push("booking_counters 尚未清除");
  }
  if ((await db.collection("payment_credentials").doc(shopId).get()).exists) {
    residual.push("payment_credentials 尚未清除");
  }
  return {complete: residual.length === 0, residual};
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function runJobHandler(request) {
  await requireSuperAdmin(request, true);
  if (PHASE_ONE_PREVIEW_ONLY) {
    throw new HttpsError(
        "failed-precondition",
        "第一階段禁止執行或重試任何刪除工作。",
        {phaseOnePreviewOnly: true},
    );
  }
  const jobId = text((request.data || {}).jobId);
  if (!jobId) throw new HttpsError("invalid-argument", "缺少刪除工作 ID。");
  const jobRef = admin.firestore().collection(JOB_COLLECTION).doc(jobId);
  const snapshot = await jobRef.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "找不到刪除工作。");
  const job = snapshot.data() || {};
  if (text(job.mode) !== policy.TEST_RESET_MODE) {
    throw new HttpsError(
        "failed-precondition",
        "正式永久刪除尚未開放執行。",
    );
  }
  if (text(job.status) === "completed") return sanitizeJob(snapshot);
  const leaseToken = crypto.randomUUID();
  let completedWhileAcquiring = false;
  await admin.firestore().runTransaction(async (tx) => {
    const fresh = await tx.get(jobRef);
    if (!fresh.exists) {
      throw new HttpsError("not-found", "找不到刪除工作。");
    }
    if (text(fresh.get("mode")) !== policy.TEST_RESET_MODE) {
      throw new HttpsError(
          "failed-precondition",
          "正式永久刪除尚未開放執行。",
      );
    }
    if (text(fresh.get("status")) === "completed") {
      completedWhileAcquiring = true;
      return;
    }
    if (text(fresh.get("status")) === "running" &&
        milliseconds(fresh.get("leaseUntil")) > Date.now()) {
      throw new HttpsError("aborted", "另一個批次正在執行，請稍後重試。");
    }
    tx.set(jobRef, {
      status: "running",
      leaseToken,
      lastError: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.Timestamp.fromMillis(
          Date.now() + 10 * 60 * 1000,
      ),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });
  if (completedWhileAcquiring) return sanitizeJob(await jobRef.get());
  try {
    for (let step = 0; step < 12; step += 1) {
      const fresh = await jobRef.get();
      const current = fresh.data() || {};
      if (text(current.status) === "completed") break;
      await runJobStep(jobRef, current);
    }
    const fresh = await jobRef.get();
    if (text(fresh.get("status")) !== "completed") {
      await patchJob(jobRef, {
        status: "pending",
        leaseToken: admin.firestore.FieldValue.delete(),
        leaseUntil: admin.firestore.FieldValue.delete(),
      });
    }
    return sanitizeJob(await jobRef.get());
  } catch (error) {
    const message = text(error.message || error);
    await jobRef.collection("failures").add({
      phase: text((await jobRef.get()).get("phase")),
      message,
      storageObject: text(error.storageObject),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await patchJob(jobRef, {
      status: "failed",
      failedCount: admin.firestore.FieldValue.increment(1),
      lastError: message,
      leaseToken: admin.firestore.FieldValue.delete(),
      leaseUntil: admin.firestore.FieldValue.delete(),
    });
    await admin.firestore().collection(AUDIT_COLLECTION).doc(jobId).set({
      result: "failed",
      failureSummary: message,
    }, {merge: true});
    throw new HttpsError(
        "internal",
        "刪除批次失敗，可從原工作安全重試。",
        {jobId, phase: text((await jobRef.get()).get("phase"))},
    );
  }
}

/**
 * @param {FirebaseFirestore.DocumentSnapshot} snapshot 工作
 * @return {Object}
 */
function sanitizeJob(snapshot) {
  const data = snapshot.data() || {};
  return {
    jobId: snapshot.id,
    shopId: text(data.shopId),
    shopCode: text(data.shopCode),
    shopName: text(data.shopName),
    mode: text(data.mode),
    status: text(data.status),
    phase: text(data.phase),
    deletedFirestore: Number(data.deletedFirestore || 0),
    deletedStorage: Number(data.deletedStorage || 0),
    failedCount: Number(data.failedCount || 0),
    retainedCount: Number(data.retainedCount || 0),
    lastError: text(data.lastError),
    createdAtMillis: milliseconds(data.createdAt),
    completedAtMillis: milliseconds(data.completedAt),
  };
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function getJobHandler(request) {
  await requireSuperAdmin(request);
  const data = request.data || {};
  const jobId = text(data.jobId);
  const shopId = text(data.shopId);
  let snapshot;
  if (jobId) {
    snapshot = await admin.firestore().collection(JOB_COLLECTION)
        .doc(jobId).get();
  } else if (shopId) {
    const lock = await admin.firestore().collection(LOCK_COLLECTION)
        .doc(shopId).get();
    const lockedJobId = lock.exists ? text(lock.get("jobId")) : "";
    if (!lockedJobId) return {job: null, failures: []};
    snapshot = await admin.firestore().collection(JOB_COLLECTION)
        .doc(lockedJobId).get();
  } else {
    throw new HttpsError("invalid-argument", "缺少店家或工作 ID。");
  }
  if (!snapshot.exists) return {job: null, failures: []};
  const failures = await snapshot.ref.collection("failures")
      .orderBy("createdAt", "desc").limit(20).get();
  return {
    job: sanitizeJob(snapshot),
    failures: failures.docs.map((doc) => ({
      id: doc.id,
      phase: text(doc.get("phase")),
      message: text(doc.get("message")),
      storageObject: text(doc.get("storageObject")),
      createdAtMillis: milliseconds(doc.get("createdAt")),
    })),
  };
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function verifyHandler(request) {
  await requireSuperAdmin(request, true);
  const jobId = text((request.data || {}).jobId);
  if (!jobId) throw new HttpsError("invalid-argument", "缺少工作 ID。");
  const job = await admin.firestore().collection(JOB_COLLECTION).doc(jobId)
      .get();
  if (!job.exists) throw new HttpsError("not-found", "找不到刪除工作。");
  return verifyDeletion(jobId, job.data());
}

const callableOptions = {
  region: REGION,
  timeoutSeconds: 540,
  memory: "1GiB",
};

exports.previewShopDeletion = onCall(callableOptions, previewHandler);
exports.createShopDeletionJob = onCall(callableOptions, createJobHandler);
exports.runShopDeletionBatch = onCall(callableOptions, runJobHandler);
exports.getShopDeletionJob = onCall(callableOptions, getJobHandler);
exports.verifyShopDeletion = onCall(callableOptions, verifyHandler);

exports._test = {
  requireSuperAdmin,
  combineStatuses,
  scanQuery,
  publicScanError,
  inspectTopLevelCollections,
  inspectTopLevelCollectionsV2,
  inspectShopTree,
  inspectTransactionBlockers,
  buildPreview,
  verifyDeletion,
  sanitizeJob,
  previewHandler,
  createJobHandler,
  runJobHandler,
  getJobHandler,
  verifyHandler,
};
