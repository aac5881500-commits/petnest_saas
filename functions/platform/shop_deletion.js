// 檔案名稱：functions/platform/shop_deletion.js
// 功能說明：最高管理員預覽、建立、分批執行與驗證店家刪除工作。

"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const policy = require("./shop_deletion_policy");
const emailCode = require("./shop_deletion_email");

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
const REGION = "asia-east1";
const MAX_QUERY_DOCS = 500;
const MAX_STORAGE_FILES = 5000;
const MAX_ACCOUNT_LINK_DOCS = 5000;
const PREVIEW_PAGE_SIZE = 250;
const PREVIEW_MAX_DOCS = 20000;
const MAX_STORAGE_BOOKING_PREFIXES = 1000;
const MAX_PROTECTED_REFERENCE_CHECKS = 200;
const MAX_PREVIEW_DETAIL_ROWS = 200;
const SCAN_SOURCE_TIMEOUT_MS = 45 * 1000;
const RECENT_AUTH_SECONDS = 10 * 60;
const PREVIEW_VALID_SECONDS = 15 * 60;
const PREVIEW_CONTRACT_VERSION = 4;
const SAFE_CLEANUP_EXECUTION_ENABLED = true;
const FORMAL_DELETION_ENABLED = false;
const JOB_COLLECTION = "shop_deletion_jobs";
const LOCK_COLLECTION = "shop_deletion_locks";
const AUDIT_COLLECTION = "shop_deletion_audits";
const RETIRED_COLLECTION = "retired_shop_codes";
const PREVIEW_GRANT_COLLECTION = "shop_deletion_preview_grants";
const EMAIL_CHALLENGE_COLLECTION = "shop_deletion_email_challenges";
const EMAIL_ACTIVE_COLLECTION = "shop_deletion_email_active";
const EMAIL_RATE_COLLECTION = "shop_deletion_email_rates";
const smtpHost = defineSecret("SHOP_DELETION_SMTP_HOST");
const smtpFrom = defineSecret("SHOP_DELETION_SMTP_FROM");
const smtpUser = defineSecret("SHOP_DELETION_SMTP_USER");
const smtpPass = defineSecret("SHOP_DELETION_SMTP_PASS");

const EXECUTABLE_DIRECT_STORAGE_PREFIXES = [
  "shops",
  "daily_care_photos",
  "shop_chat",
];

const BOOKING_STORAGE_PREFIXES = [
  "booking_images",
  "review_images",
  "booking_extra_charges",
];

const NONSTANDARD_RELATION_COLLECTIONS = new Set([
  "legal_pet_license_links",
]);

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
 * 單一掃描來源逾時後回報 deadline-exceeded，不阻塞整個預覽。
 * @param {Promise<*>} operation 掃描工作
 * @param {number} timeoutMillis 逾時毫秒
 * @param {string} source 安全來源名稱
 * @return {Promise<*>}
 */
async function withTimeout(operation, timeoutMillis, source) {
  let timer;
  const timeout = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      const error = new Error(`scan timeout: ${source}`);
      error.code = "deadline-exceeded";
      reject(error);
    }, timeoutMillis);
  });
  try {
    return await Promise.race([operation, timeout]);
  } finally {
    clearTimeout(timer);
  }
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
    const snapshot = await withTimeout(
        page.get(),
        Number(options.timeoutMillis || SCAN_SOURCE_TIMEOUT_MS),
        text(options.source || "firestore query"),
    );
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
        .includes(collectionId) ||
        NONSTANDARD_RELATION_COLLECTIONS.has(collectionId)) {
      continue;
    }
    const classification = policy.classifyCollection(collectionId);
    if (classification === "special" || classification === "shared") continue;
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
async function collectRelatedUserIds(db, shopId, shop) {
  const ids = new Set();
  const ownerUid = text((shop || {}).ownerUid);
  if (ownerUid) ids.add(ownerUid);
  const members = await scanQuery(
      db.collection("shop_members").where("shopId", "==", shopId),
      {includeDocs: true, source: "shop_members"},
  );
  for (const doc of members.docs) {
    const uid = text(doc.get("uid") || doc.get("userId"));
    if (uid) ids.add(uid);
  }
  const nestedMembers = await scanQuery(
      db.collection("shops").doc(shopId).collection("members"),
      {includeDocs: true, source: `shops/${shopId}/members`},
  );
  for (const doc of nestedMembers.docs) {
    const uid = text(doc.get("uid") || doc.get("userId") || doc.id);
    if (uid) ids.add(uid);
  }
  const linkedUsers = await scanQuery(
      db.collection("users").where("shopIds", "array-contains", shopId),
      {includeDocs: true, source: "users.shopIds"},
  );
  for (const doc of linkedUsers.docs) ids.add(doc.id);
  const complete = members.complete &&
    nestedMembers.complete &&
    linkedUsers.complete;
  return {
    ids: [...ids],
    status: complete ? "success" : "partial",
    complete,
    reason: complete ? "" : "相關會員超過安全掃描上限",
  };
}

/**
 * 用已知文件路徑統計店家關聯，不使用需要 collection group 索引的查詢。
 * 查無文件是 0，不是掃描失敗。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @param {Object} shop 店家主文件
 * @return {Promise<Object>}
 */
async function inspectUserRelatedGroups(db, shopId, shop) {
  const rows = [];
  let relatedUsers = {
    ids: [],
    status: "failed",
    complete: false,
    reason: "",
  };
  try {
    relatedUsers = await collectRelatedUserIds(db, shopId, shop);
  } catch (error) {
    const detail = publicScanError(error);
    relatedUsers.reason = detail.reason;
    relatedUsers.errorCode = detail.errorCode;
  }
  const userLookupFailed = relatedUsers.status === "failed";

  let policyCount = 0;
  let policyError = null;
  if (!userLookupFailed) {
    for (const uid of relatedUsers.ids) {
      try {
        const doc = await db.collection("users").doc(uid)
            .collection("policy_acceptances").doc(shopId).get();
        if (doc.exists) policyCount += 1;
      } catch (error) {
        policyError = error;
        break;
      }
    }
  }
  rows.push(Object.assign({
    collectionGroup: "policy_acceptances",
    path: "users/{uid}/policy_acceptances/{shopId}",
    count: userLookupFailed || policyError ? null : policyCount,
    status: userLookupFailed || policyError ? "failed" :
      relatedUsers.complete ? "success" : "partial",
    complete: !userLookupFailed && !policyError && relatedUsers.complete,
    reason: policyError ? publicScanError(policyError).reason :
      relatedUsers.reason || "依已知會員路徑讀取，沒有文件就是 0",
  }, policyError ? publicScanError(policyError) : {}));

  let formCount = 0;
  let formError = null;
  if (!userLookupFailed) {
    for (const uid of relatedUsers.ids) {
      try {
        const pets = await db.collection("user_profiles").doc(uid)
            .collection("pets").get();
        for (const pet of pets.docs) {
          const answer = await pet.ref.collection("shop_form_answers")
              .doc(shopId).get();
          if (answer.exists) formCount += 1;
        }
      } catch (error) {
        formError = error;
        break;
      }
    }
  }
  rows.push(Object.assign({
    collectionGroup: "shop_form_answers",
    path: "user_profiles/{uid}/pets/{petId}/shop_form_answers/{shopId}",
    count: userLookupFailed || formError ? null : formCount,
    status: userLookupFailed || formError ? "failed" :
      relatedUsers.complete ? "success" : "partial",
    complete: !userLookupFailed && !formError && relatedUsers.complete,
    reason: formError ? publicScanError(formError).reason :
      relatedUsers.reason || "只讀指定 shopId 的表單答案文件",
  }, formError ? publicScanError(formError) : {}));

  let usageCount = 0;
  let usageStatus = "success";
  let usageComplete = true;
  let usageBlocksDeletion = false;
  let usageReason = "店家沒有激活碼編號，沒有可定位的使用紀錄";
  let usageError = null;
  try {
    let codeId = text((shop || {}).activationCodeId || (shop || {}).codeId);
    if (!codeId) {
      const requests = await db.collection("sales_shop_create_requests")
          .where("shopId", "==", shopId).limit(5).get();
      codeId = requests.docs
          .map((doc) => text(doc.get("codeId"))).find(Boolean) || "";
    }
    if (codeId) {
      const log = await db.collection("activation_codes").doc(codeId)
          .collection("usage_logs").doc(shopId).get();
      usageCount = log.exists ? 1 : 0;
      usageBlocksDeletion = log.exists &&
        policy.hasRealCommercialObligation(log.data());
      usageReason = usageBlocksDeletion ?
        "激活紀錄包含付費方案或權益，不能直接刪除" :
        "一般或免費激活使用紀錄，不阻止刪除店家";
    }
  } catch (error) {
    usageError = publicScanError(error);
    usageStatus = "failed";
    usageComplete = false;
    usageCount = null;
    usageReason = usageError.reason;
  }
  rows.push(Object.assign({
    collectionGroup: "usage_logs",
    path: "activation_codes/{codeId}/usage_logs/{shopId}",
    count: usageCount,
    status: usageStatus,
    complete: usageComplete,
    blocksDeletion: usageBlocksDeletion,
    reason: usageReason,
  }, usageError || {}));
  return {
    rows,
    userIds: relatedUsers.ids,
    manualCollectionCount: rows.filter((row) => row.status !== "success")
        .length,
  };
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
    try {
      const result = await scanQuery(
          db.collection(collection).where("shopIds", "array-contains", shopId),
          {
            maxDocs: MAX_ACCOUNT_LINK_DOCS,
            includeDocs: true,
            source: `${collection}.shopIds`,
          },
      );
      let sharedWithOtherShopsCount = 0;
      let singleShopAdminProfileCount = 0;
      for (const doc of result.docs) {
        const data = doc.data() || {};
        const shopIds = Array.isArray(data.shopIds) ?
          [...new Set(data.shopIds.map(text).filter(Boolean))] : [];
        if (shopIds.some((id) => id !== shopId)) {
          sharedWithOtherShopsCount += 1;
        }
        const source = text(data.source || data.createdFrom).toLowerCase();
        if (collection === "user_profiles" &&
            shopIds.length === 1 && source === "admin") {
          singleShopAdminProfileCount += 1;
        }
      }
      rows.push({
        collection,
        count: result.count,
        truncated: !result.complete,
        status: result.status,
        complete: result.complete,
        errorCode: result.errorCode || "",
        classification: "shared",
        sharedWithOtherShopsCount,
        singleShopAdminProfileCount,
        reason: collection === "user_profiles" ?
          "會員主檔可能由店家手動建立或被多店共用；只可移除指定店家關聯，主檔待政策確認" :
          "平台共用帳號主檔，只可移除指定店家關聯",
      });
    } catch (error) {
      rows.push(Object.assign({
        collection,
        count: null,
        truncated: false,
        status: "failed",
        complete: false,
        classification: "shared",
        sharedWithOtherShopsCount: null,
        singleShopAdminProfileCount: null,
      }, publicScanError(error)));
    }
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
  let storeOrderCount = 0;
  let openStoreOrderCount = 0;
  let paidStoreOrderCount = 0;
  let completedStoreOrderCount = 0;
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
        const snapshot = await withTimeout(
            query.get(),
            SCAN_SOURCE_TIMEOUT_MS,
            collection.path,
        );
        byCollection[collection.id] =
          Number(byCollection[collection.id] || 0) + snapshot.size;
        for (const child of snapshot.docs) {
          const childData = child.data() || {};
          storageReferences(childData)
              .forEach((path) => references.add(path));
          if (collection.id === "store_orders") {
            storeOrderCount += 1;
            if (policy.isOpenStoreOrder(childData)) {
              openStoreOrderCount += 1;
            }
            if (policy.isCompletedService(childData)) {
              completedStoreOrderCount += 1;
            }
            if (policy.isOrderPaidOrExternal(childData) ||
                policy.hasRefundOrDispute(childData)) {
              paidStoreOrderCount += 1;
            }
          }
          count += 1;
          const evidence = activityEvidence(childData);
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
    storeOrderCount,
    openStoreOrderCount,
    paidStoreOrderCount,
    completedStoreOrderCount,
    storageReferences: [...references],
  };
}

/**
 * 遞迴統計根集合文件（例如 bookings/{bookingId}）下的子集合。
 * @param {FirebaseFirestore.DocumentReference[]} roots 已確認屬於店家的根文件
 * @param {number} maxRoots 根文件安全上限
 * @return {Promise<Object>}
 */
async function inspectRelatedDocumentTrees(roots, maxRoots) {
  let count = 0;
  let truncated = roots.length > maxRoots;
  const byCollection = {};
  const references = new Set();
  const selectedRoots = roots.slice(0, maxRoots);

  /**
   * @param {FirebaseFirestore.DocumentReference} document 父文件
   * @return {Promise<void>}
   */
  async function visit(document) {
    if (count >= PREVIEW_MAX_DOCS) {
      truncated = true;
      return;
    }
    const collections = await withTimeout(
        document.listCollections(),
        SCAN_SOURCE_TIMEOUT_MS,
        document.path,
    );
    for (const collection of collections) {
      let cursor = null;
      do {
        let query = collection.limit(PREVIEW_PAGE_SIZE);
        if (cursor) query = query.startAfter(cursor);
        const snapshot = await withTimeout(
            query.get(),
            SCAN_SOURCE_TIMEOUT_MS,
            collection.path,
        );
        byCollection[collection.id] =
          Number(byCollection[collection.id] || 0) + snapshot.size;
        for (const child of snapshot.docs) {
          storageReferences(child.data())
              .forEach((path) => references.add(path));
          count += 1;
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
  for (const root of selectedRoots) {
    await visit(root);
    if (count >= PREVIEW_MAX_DOCS) break;
  }
  return {
    status: truncated ? "partial" : "success",
    complete: !truncated,
    count,
    rootCount: selectedRoots.length,
    byCollection,
    storageReferences: [...references],
    reason: truncated ?
      "訂單子集合超過根文件或文件安全掃描上限" : "",
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
  const objectNames = [];
  const objects = [];
  const samplePaths = [];
  let pageToken;
  do {
    const [files, nextQuery] = await withTimeout(
        bucket.getFiles({
          prefix,
          autoPaginate: false,
          maxResults: Math.min(1000, limit - count),
          pageToken,
        }),
        SCAN_SOURCE_TIMEOUT_MS,
        prefix,
    );
    for (const file of files) {
      count += 1;
      const objectBytes = Number((file.metadata || {}).size || 0);
      bytes += objectBytes;
      objectNames.push(file.name);
      objects.push({name: file.name, bytes: objectBytes});
      if (samplePaths.length < 5) samplePaths.push(file.name);
      if (count >= limit) break;
    }
    pageToken = nextQuery && nextQuery.pageToken;
  } while (pageToken && count < limit);
  return {
    prefix,
    count,
    bytes,
    truncated: Boolean(pageToken),
    objectNames,
    objects,
    samplePaths,
  };
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
  const reviewBookingIds = new Set();
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
    if (["bookings", "payments", "shop_subscription_payments"]
        .includes(collectionId) ||
        NONSTANDARD_RELATION_COLLECTIONS.has(collectionId)) {
      continue;
    }
    const classification = policy.classifyCollection(collectionId);
    if (classification === "special" || classification === "shared") continue;
    try {
      const result = await scanQuery(
          collection.where("shopId", "==", shopId),
          {includeDocs: true, source: collectionId},
      );
      for (const doc of result.docs) {
        storageReferences(doc.data()).forEach((path) => references.add(path));
        if (collectionId === "reviews") {
          const bookingId = text(doc.get("bookingId"));
          if (bookingId) reviewBookingIds.add(bookingId);
        }
      }
      if (collectionId === "action_logs" && result.status === "success") {
        const auditCount = result.docs.filter((doc) =>
          policy.isRequiredAuditAction(doc.data())).length;
        const ordinaryCount = result.docs.length - auditCount;
        rows.push({
          path: collectionId,
          collection: collectionId,
          relation: "shopId == 指定店號",
          classification: "delete",
          status: result.status,
          complete: result.complete,
          count: ordinaryCount,
          reason: "一般店家操作紀錄可清理",
          latestActivityMillis: result.latestActivityMillis,
          latestActivitySource: result.latestActivitySource,
        });
        if (auditCount > 0) {
          rows.push({
            path: `${collectionId}:audit`,
            collection: collectionId,
            relation: "必要稽核紀錄",
            classification: "shared",
            status: result.status,
            complete: result.complete,
            count: auditCount,
            reason: "必要稽核紀錄保留，不阻止清理沒有真實交易的店家",
            latestActivityMillis: result.latestActivityMillis,
            latestActivitySource: result.latestActivitySource,
          });
        }
        continue;
      }
      if (collectionId === "shop_commercial" && result.status === "success") {
        const realCount = result.docs.filter((doc) =>
          policy.hasRealCommercialObligation(doc.data())).length;
        rows.push({
          path: collectionId,
          collection: collectionId,
          relation: "shopId == 指定店號",
          classification: realCount > 0 ? "retain" : "delete",
          status: result.status,
          complete: result.complete,
          count: result.count,
          blocksDeletion: realCount > 0,
          reason: realCount > 0 ?
            "有付費方案、合約、發票或應收款" :
            "尚未發生真實付費的店家方案設定",
          latestActivityMillis: result.latestActivityMillis,
          latestActivitySource: result.latestActivitySource,
        });
        continue;
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
    reviewBookingIds: [...reviewBookingIds],
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
          {includeDocs: true, source: collection},
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
  let paidBookingCount = 0;
  let completedStayCount = 0;
  let completedDaycareCount = 0;
  let cancelledBookingCount = 0;
  let otherBookingCount = 0;
  for (const doc of bookingDocs) {
    const data = doc.data() || {};
    const kind = text(data.bookingKind || data.serviceType).toLowerCase();
    const daycare = kind === "daycare";
    if (daycare) daycareBookingCount += 1;
    else stayBookingCount += 1;
    if (policy.isOrderPaidOrExternal(data) ||
        policy.hasRefundOrDispute(data)) {
      paidBookingCount += 1;
    }
    if (policy.isCompletedService(data)) {
      if (daycare) completedDaycareCount += 1;
      else completedStayCount += 1;
    } else if (policy.isCancelledOrRejectedBooking(data)) {
      cancelledBookingCount += 1;
    } else if (policy.isOpenBooking(data)) {
      openBookingCount += 1;
    } else {
      otherBookingCount += 1;
    }
  }
  let paidPaymentCount = 0;
  let unpaidPaymentCount = 0;
  let refundingPaymentCount = 0;
  let disputeCount = 0;
  let unsafePaymentCount = 0;
  const references = new Set();
  [...bookingDocs, ...paymentDocs].forEach((doc) => {
    storageReferences(doc.data()).forEach((path) => references.add(path));
  });
  for (const doc of paymentDocs) {
    const data = doc.data() || {};
    const state = [
      data.status,
      data.paymentStatus,
      data.refundStatus,
      data.disputeStatus,
    ].map(text).join(" ").toLowerCase();
    if (state.includes("dispute") || state.includes("chargeback")) {
      disputeCount += 1;
    }
    if (state.includes("refund")) refundingPaymentCount += 1;
    if (policy.isPaidOrExternalPayment(data)) paidPaymentCount += 1;
    else unpaidPaymentCount += 1;
    if (!policy.isSafeTestPayment(data)) unsafePaymentCount += 1;
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
    paidBookingCount: bookingSection && bookingSection.status !== "failed" ?
      paidBookingCount : null,
    completedStayCount: bookingSection && bookingSection.status !== "failed" ?
      completedStayCount : null,
    completedDaycareCount:
      bookingSection && bookingSection.status !== "failed" ?
        completedDaycareCount : null,
    cancelledBookingCount:
      bookingSection && bookingSection.status !== "failed" ?
        cancelledBookingCount : null,
    otherBookingCount: bookingSection && bookingSection.status !== "failed" ?
      otherBookingCount : null,
    paymentCount: paymentSection && paymentSection.status !== "failed" ?
      paymentSection.count : null,
    paidPaymentCount: paymentSection && paymentSection.status !== "failed" ?
      paidPaymentCount : null,
    unpaidPaymentCount: paymentSection && paymentSection.status !== "failed" ?
      unpaidPaymentCount : null,
    refundingPaymentCount:
      paymentSection && paymentSection.status !== "failed" ?
        refundingPaymentCount : null,
    disputeCount: paymentSection && paymentSection.status !== "failed" ?
      disputeCount : null,
    unsafePaymentCount: paymentSection && paymentSection.status !== "failed" ?
      unsafePaymentCount : null,
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
    status: warnings.length === 0 ? "success" : "partial",
    complete: warnings.length === 0 && ownerUid.length > 0,
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
 * @param {Object} context 已確認的店家、訂單、評論及檔案引用
 * @return {Promise<Object>}
 */
async function inspectStorageV2(bucket, prefixes, scanId, context) {
  const rows = [];
  for (const prefix of prefixes) {
    const ownership = policy.classifyStoragePrefix(prefix, context);
    try {
      const row = await inspectStoragePrefix(
          bucket, prefix, MAX_STORAGE_FILES,
      );
      const objectNames = row.objectNames || [];
      const objects = row.objects || [];
      delete row.objectNames;
      delete row.objects;
      let classified = ownership;
      const root = prefix.split("/")[0];
      if (["shops", "shop_chat"].includes(root) &&
          objectNames.length > 0) {
        const referencedPaths =
          new Set(context.shopStorageReferences || []);
        const unreferencedCount = objectNames
            .filter((path) => !referencedPaths.has(path)).length;
        row.confirmedReferenceCount =
          objectNames.length - unreferencedCount;
        row.unreferencedCount = unreferencedCount;
        classified = {
          category: "safe_delete",
          ownership: "confirmed",
          reason:
            `實體物件位於指定 shopId 的專屬上傳命名空間；` +
            `${unreferencedCount} 個為可回收的店家孤兒檔案`,
          affectsDeletion: false,
          ownershipEvidence: "shop-scoped-storage-namespace",
        };
      }
      if (prefix === `daily_care_photos/${context.shopId}/` &&
          objectNames.length > 0) {
        const targetBookings = new Set(context.bookingIds || []);
        const invalidCount = objectNames.filter((path) => {
          const parts = path.split("/");
          return parts.length < 4 || !targetBookings.has(parts[2]);
        }).length;
        if (invalidCount > 0) {
          classified = {
            category: "manual",
            ownership: "unknown",
            reason:
              `${invalidCount} 個檔案無法由 bookings.shopId 確認歸屬`,
            affectsDeletion: true,
          };
        } else {
          classified = Object.assign({}, ownership, {
            reason: "路徑含指定 shopId，且每個 bookingId 均已由訂單確認",
          });
          const referencedPaths =
            new Set(context.shopStorageReferences || []);
          const unreferencedCount = objectNames
              .filter((path) => !referencedPaths.has(path)).length;
          row.confirmedReferenceCount =
            objectNames.length - unreferencedCount;
          row.unreferencedCount = unreferencedCount;
          if (unreferencedCount > 0) {
            classified = {
              category: "safe_delete",
              ownership: "confirmed",
              reason:
                `${unreferencedCount} 個每日照護檔案沒有現存引用，` +
                "但 shopId 與 bookingId 均已由訂單關聯確認",
              affectsDeletion: false,
              ownershipEvidence: "shop-and-booking-scoped-namespace",
            };
          } else {
            classified = {
              category: "safe_delete",
              ownership: "confirmed",
              reason:
                "店家、訂單與 Firestore 引用均已確認",
              affectsDeletion: false,
              ownershipEvidence: "shop-booking-and-reference",
            };
          }
        }
      }
      if (BOOKING_STORAGE_PREFIXES.includes(root) &&
          objectNames.length > 0) {
        const referencedPaths = new Set(root === "review_images" ?
          (context.reviewStorageReferences || []) :
          (context.bookingStorageReferences || []));
        const referencedObjects = objects
            .filter((object) => referencedPaths.has(object.name));
        const unreferencedObjects = objects
            .filter((object) => !referencedPaths.has(object.name));
        const unreferencedCount = unreferencedObjects.length;
        row.confirmedReferenceCount = objectNames.length - unreferencedCount;
        row.unreferencedCount = unreferencedCount;
        if (unreferencedCount > 0) {
          const status = row.truncated ? "partial" : "success";
          if (referencedObjects.length > 0) {
            rows.push(Object.assign({}, row, ownership, {
              prefix,
              label: `${prefix}（已由 Firestore 引用）`,
              count: referencedObjects.length,
              bytes: referencedObjects.reduce(
                  (sum, object) => sum + object.bytes, 0,
              ),
              samplePaths:
                referencedObjects.slice(0, 5).map((object) => object.name),
              status,
              complete: !row.truncated,
              reason: row.truncated ?
                `${ownership.reason}；路徑掃描超過安全上限` :
                ownership.reason,
              confirmedReferenceCount: referencedObjects.length,
              unreferencedCount: 0,
            }));
          }
          const unknownClassification = {
            category: "manual",
            ownership: "unknown",
            reason:
              `${unreferencedCount} 個檔案找不到對應 Firestore 路徑引用；` +
              "不得只依 bookingId 資料夾判定",
            affectsDeletion: true,
          };
          rows.push(Object.assign({}, row, unknownClassification, {
            prefix,
            label: `${prefix}（無 Firestore 引用）`,
            count: unreferencedObjects.length,
            bytes: unreferencedObjects.reduce(
                (sum, object) => sum + object.bytes, 0,
            ),
            samplePaths:
              unreferencedObjects.slice(0, 5).map((object) => object.name),
            status,
            complete: !row.truncated,
            reason: row.truncated ?
              `${unknownClassification.reason}；路徑掃描超過安全上限` :
              unknownClassification.reason,
            confirmedReferenceCount: 0,
            unreferencedCount: unreferencedObjects.length,
          }));
          continue;
        }
      }
      rows.push(Object.assign({}, row, classified, {
        status: row.truncated ? "partial" : "success",
        complete: !row.truncated,
        reason: row.truncated ?
          `${classified.reason}；超過單一路徑安全掃描上限` :
          classified.reason,
      }));
    } catch (error) {
      const detail = publicScanError(error);
      rows.push(Object.assign({}, ownership, {
        prefix,
        status: "failed",
        complete: false,
        count: null,
        bytes: null,
        errorCode: detail.errorCode,
        reason: detail.reason,
        affectsDeletion: true,
      }));
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
 * 驗證店家文件所引用、但絕不可因刪店而移除的共用 Storage 物件。
 * @param {Object} bucket Storage bucket
 * @param {string[]} paths 已去重物件路徑
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function inspectProtectedStorageReferences(bucket, paths, scanId) {
  const checkedPaths = paths.slice(0, MAX_PROTECTED_REFERENCE_CHECKS);
  const rows = [];
  for (let offset = 0; offset < checkedPaths.length; offset += 20) {
    const batch = checkedPaths.slice(offset, offset + 20);
    const results = await Promise.all(batch.map(async (path) => {
      const category = path.startsWith("pets/") ?
        "retain_customer" : "retain_shared";
      try {
        const [metadata] = await withTimeout(
            bucket.file(path).getMetadata(),
            SCAN_SOURCE_TIMEOUT_MS,
            path,
        );
        return {
          path,
          status: "success",
          exists: true,
          category,
          ownership: "shared",
          bytes: Number(metadata.size || 0),
          reason: path.startsWith("pets/") ?
            "顧客原始寵物／頭像檔案；店家資料僅引用，原檔必須保留" :
            "平台或跨功能共用檔案，必須保留",
        };
      } catch (error) {
        const code = text(error.code);
        if (code === "404" || code === "not-found") {
          return {
            path,
            status: "success",
            exists: false,
            category,
            ownership: "shared",
            bytes: 0,
            reason: "Firestore 仍有引用，但 Storage 物件不存在；不列入刪除",
          };
        }
        console.error("shop deletion protected reference failed", {
          scanId,
          path,
          code,
          type: text(error.name),
        });
        return Object.assign({
          path,
          status: "failed",
          exists: null,
          category: "manual",
          ownership: "unknown",
          bytes: null,
        }, publicScanError(error));
      }
    }));
    rows.push(...results);
  }
  return {
    status: paths.length === 0 ? "success" :
      paths.length > checkedPaths.length ? "partial" :
        combineStatuses(rows.map((row) => row.status)),
    complete: paths.length <= checkedPaths.length &&
      rows.every((row) => row.status === "success"),
    totalReferenceCount: paths.length,
    checkedCount: checkedPaths.length,
    rows,
    reason: paths.length > checkedPaths.length ?
      `共用檔案引用超過 ${MAX_PROTECTED_REFERENCE_CHECKS} 筆安全檢查上限` :
      "",
  };
}

/**
 * 驗證未知路徑引用是否有實際 Storage 物件；引用數不可當作檔案數。
 * @param {Object} bucket Storage bucket
 * @param {string[]} paths 已去重物件路徑
 * @param {string} scanId 掃描識別碼
 * @return {Promise<Object>}
 */
async function inspectUnknownStorageReferences(bucket, paths, scanId) {
  const checkedPaths = paths.slice(0, MAX_PROTECTED_REFERENCE_CHECKS);
  const rows = [];
  for (let offset = 0; offset < checkedPaths.length; offset += 20) {
    const batch = checkedPaths.slice(offset, offset + 20);
    const results = await Promise.all(batch.map(async (path) => {
      try {
        const [metadata] = await withTimeout(
            bucket.file(path).getMetadata(),
            SCAN_SOURCE_TIMEOUT_MS,
            path,
        );
        return {
          path,
          status: "success",
          exists: true,
          category: "manual",
          ownership: "unknown",
          bytes: Number(metadata.size || 0),
          reason: "檔案存在，但路徑不在已確認的店家上傳規則中",
        };
      } catch (error) {
        const code = text(error.code);
        if (code === "404" || code === "not-found") {
          return {
            path,
            status: "success",
            exists: false,
            category: "manual",
            ownership: "unknown",
            bytes: 0,
            reason: "Firestore 引用存在，但 Storage 物件不存在",
          };
        }
        console.error("shop deletion unknown reference failed", {
          scanId,
          path,
          code,
          type: text(error.name),
        });
        return Object.assign({
          path,
          status: "failed",
          exists: null,
          category: "manual",
          ownership: "unknown",
          bytes: null,
        }, publicScanError(error));
      }
    }));
    rows.push(...results);
  }
  return {
    status: paths.length === 0 ? "success" :
      paths.length > checkedPaths.length ? "partial" :
        combineStatuses(rows.map((row) => row.status)),
    complete: paths.length <= checkedPaths.length &&
      rows.every((row) => row.status === "success"),
    totalReferenceCount: paths.length,
    checkedCount: checkedPaths.length,
    existingFileCount:
      rows.filter((row) => row.exists === true).length,
    existingBytes: rows.filter((row) => row.exists === true)
        .reduce((sum, row) => sum + Number(row.bytes || 0), 0),
    missingReferenceCount:
      rows.filter((row) => row.exists === false).length,
    rows,
    reason: paths.length > checkedPaths.length ?
      `未知路徑引用超過 ${MAX_PROTECTED_REFERENCE_CHECKS} 筆檢查上限` :
      "",
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
  transactions.storeOrderCount =
    tree.status === "failed" ? null : Number(tree.storeOrderCount || 0);
  transactions.openStoreOrderCount =
    tree.status === "failed" ? null : Number(tree.openStoreOrderCount || 0);
  transactions.paidStoreOrderCount =
    tree.status === "failed" ? null : Number(tree.paidStoreOrderCount || 0);
  transactions.completedStoreOrderCount =
    tree.status === "failed" ? null :
    Number(tree.completedStoreOrderCount || 0);

  let userRelated;
  try {
    userRelated = await inspectUserRelatedGroups(db, shopId, shop);
    for (const row of userRelated.rows) {
      row.status = row.status || (row.truncated ? "partial" : "success");
      row.complete = row.complete === true && row.status === "success";
      if (row.collectionGroup === "shop_form_answers" ||
          (row.collectionGroup === "usage_logs" &&
            row.blocksDeletion !== true)) {
        row.classification = "delete";
      } else if (row.collectionGroup === "policy_acceptances") {
        row.classification = "shared";
      } else {
        row.classification = "retain";
      }
      row.reason = row.reason || (row.collectionGroup ===
        "shop_form_answers" ?
        "只刪除 user_profiles/*/pets/* 下指定 shopId 的店家表單答案" :
        row.collectionGroup === "usage_logs" ?
          "一般使用紀錄不阻止刪除；付費或權益紀錄會阻擋" :
          "條款確認紀錄保留，不阻止清理沒有真實交易的店家");
      if (row.status === "failed") {
        failures.push({
          source: `collectionGroup:${row.collectionGroup}`,
          errorCode: row.errorCode,
          reason: row.reason,
        });
      }
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
      row.status = row.status || (row.truncated ? "partial" : "success");
      row.complete = row.complete === true && row.status === "success";
      if (row.status === "failed") {
        failures.push({
          source: `${row.collection}.shopIds`,
          errorCode: row.errorCode,
          reason: row.reason,
        });
      }
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
  try {
    const openEvent = await db.collection("sales_summary_events")
        .doc(`open_${shopId}`).get();
    specialRows.push({
      path: `sales_summary_events/open_${shopId}`,
      collection: "sales_summary_events",
      relation: "文件 ID == open_{shopId}",
      classification: "retain",
      status: "success",
      complete: true,
      count: openEvent.exists ? 1 : 0,
      reason: "創店業務歸因與稽核紀錄必須保留",
    });
  } catch (error) {
    const detail = publicScanError(error);
    failures.push(Object.assign({source: "sales_summary_events"}, detail));
    specialRows.push({
      path: `sales_summary_events/open_${shopId}`,
      collection: "sales_summary_events",
      relation: "文件 ID == open_{shopId}",
      classification: "retain",
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

  const legalLinkIds = new Set();
  const legalLinkStatuses = [];
  const legalLinkErrors = [];
  for (const relation of [{
    field: "certifiedShopId",
    operator: "==",
  }, {
    field: "candidateShopIds",
    operator: "array-contains",
  }]) {
    const source =
      `legal_pet_license_links.${relation.field}`;
    try {
      const result = await scanQuery(
          db.collection("legal_pet_license_links")
              .where(relation.field, relation.operator, shopId),
          {
            includeDocs: true,
            source,
          },
      );
      result.docs.forEach((doc) => legalLinkIds.add(doc.id));
      legalLinkStatuses.push(result.status);
      if (!result.complete) {
        legalLinkErrors.push(result.reason ||
          `${relation.field} 分頁未完成`);
      }
    } catch (error) {
      const detail = publicScanError(error);
      failures.push(Object.assign({source}, detail));
      legalLinkStatuses.push("failed");
      legalLinkErrors.push(`${relation.field}：${detail.reason}`);
    }
  }
  const legalLinkStatus = combineStatuses(legalLinkStatuses);
  specialRows.push({
    path: "legal_pet_license_links",
    collection: "legal_pet_license_links",
    relation:
      "certifiedShopId == 指定店號 或 candidateShopIds 包含指定店號",
    classification: "manual",
    status: legalLinkStatus,
    complete: legalLinkStatus === "success",
    count: legalLinkStatuses.every((status) => status === "failed") ?
      null : legalLinkIds.size,
    reason: legalLinkErrors.length > 0 ?
      legalLinkErrors.join("；") :
      "合法業者證照可能連結多個候選店家，需人工確認後才能變更",
    deduplicated: true,
  });

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
  let bookingTree;
  try {
    bookingTree = await inspectRelatedDocumentTrees(
        allBookingIds.map((bookingId) =>
          db.collection("bookings").doc(bookingId)),
        MAX_STORAGE_BOOKING_PREFIXES,
    );
  } catch (error) {
    const detail = Object.assign(
        {source: "bookings/{bookingId}/**"},
        publicScanError(error),
    );
    failures.push(detail);
    bookingTree = {
      status: "failed",
      complete: false,
      count: null,
      rootCount: 0,
      byCollection: {},
      storageReferences: [],
      reason: detail.reason,
      errorCode: detail.errorCode,
    };
  }
  const storageBookingIds =
    allBookingIds.slice(0, MAX_STORAGE_BOOKING_PREFIXES);
  const knownStorageReferences = [...new Set([
    ...(transactions.storageReferences || []),
    ...(top.storageReferences || []),
    ...(tree.storageReferences || []),
    ...(bookingTree.storageReferences || []),
    ...storageReferences(shop),
  ])];
  const storage = await inspectStorageV2(
      admin.storage().bucket(),
      policy.storagePrefixes(shopId, storageBookingIds),
      scanId,
      {
        shopId,
        bookingIds: storageBookingIds,
        reviewBookingIds: top.reviewBookingIds || [],
        shopStorageReferences: knownStorageReferences,
        bookingStorageReferences: knownStorageReferences,
        reviewStorageReferences: top.storageReferences || [],
      },
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
      ownership: "unknown",
      category: "manual",
      affectsDeletion: true,
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
  const rawStorageReferences = [
    ...top.storageReferences,
    ...(transactions.storageReferences || []),
    ...(tree.storageReferences || []),
    ...(bookingTree.storageReferences || []),
    ...storageReferences(shop),
  ];
  const allReferences = [...new Set(rawStorageReferences)];
  const duplicateStorageReferenceCount =
    rawStorageReferences.length - allReferences.length;
  const retainedStorageReferences = allReferences.filter((path) =>
    protectedPrefixes.some((prefix) => path.startsWith(prefix)),
  );
  const protectedStorage = await inspectProtectedStorageReferences(
      admin.storage().bucket(),
      retainedStorageReferences,
      scanId,
  );
  const unknownStorageReferences = allReferences.filter((path) =>
    !allowedPrefixes.some((prefix) => path.startsWith(prefix)) &&
    !protectedPrefixes.some((prefix) => path.startsWith(prefix)),
  );
  const unknownStorage = await inspectUnknownStorageReferences(
      admin.storage().bucket(),
      unknownStorageReferences,
      scanId,
  );
  unknownStorage.rows.filter((row) => row.status === "failed")
      .forEach((row) => failures.push({
        source: row.path,
        errorCode: row.errorCode,
        reason: row.reason,
      }));
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
    bookingTree.status,
    owner.status,
    storage.status,
    protectedStorage.status,
    unknownStorage.status,
  ];
  const unresolvedStorageRows = storage.prefixes.filter((row) =>
    row.ownership === "unknown" && Number(row.count || 0) > 0,
  );
  let complete = sectionStatuses.every((status) => status === "success") &&
    unresolvedStorageRows.length === 0 &&
    unknownStorageReferences.length === 0;
  const summary = Object.assign({}, transactions, {
    manualCollectionCount:
      top.rows.filter((row) => row.classification === "manual" &&
        Number(row.count || 0) > 0).length +
      userRelated.manualCollectionCount +
      accountLinks.filter((row) => row.truncated).length +
      (tree.truncated ? 1 : 0),
    unknownStorageCount:
      storage.prefixes
          .filter((row) => row.category === "manual" &&
            (row.status !== "success" || Number(row.count || 0) > 0))
          .reduce((sum, row) => sum +
            (row.count === null ? 1 :
              Number(row.unreferencedCount !== undefined ?
                row.unreferencedCount : row.count || 0)), 0) +
      protectedStorage.rows.filter((row) => row.status === "failed").length +
      unknownStorage.existingFileCount +
      (unknownStorage.complete ? 0 :
        unknownStorage.totalReferenceCount - unknownStorage.checkedCount),
  });
  const legacyPolicyBlockers = policy.testResetBlockers(summary);
  if (!complete) {
    legacyPolicyBlockers.push("掃描不完整，禁止建立或執行清理工作");
  }
  const safeTestTransactions =
    transactions.status === "success" &&
    Number(transactions.openBookingCount || 0) === 0 &&
    Number(transactions.paidBookingCount || 0) === 0 &&
    Number(transactions.paidPaymentCount || 0) === 0 &&
    Number(transactions.refundingPaymentCount || 0) === 0 &&
    Number(transactions.disputeCount || 0) === 0 &&
    Number(transactions.subscriptionPaymentCount || 0) === 0;
  const transactionRows = transactions.sections.map((row) => ({
    path: row.source,
    collection: row.source,
    relation: "shopId == 指定店號",
    classification:
      safeTestTransactions && ["bookings", "payments"].includes(row.source) ?
        "delete" : policy.classifyCollection(row.source),
    status: row.status,
    complete: row.complete,
    count: row.count,
    reason: row.reason || "",
    errorCode: row.errorCode || "",
  }));
  const inventoryRows = [...top.rows, ...transactionRows, ...specialRows]
      .sort((a, b) => a.collection.localeCompare(b.collection));
  const shopSubcollectionClassification = (collection) => {
    if (collection === "store_orders" &&
        Number(tree.openStoreOrderCount || 0) === 0 &&
        Number(tree.paidStoreOrderCount || 0) === 0 &&
        Number(tree.completedStoreOrderCount || 0) === 0) {
      return "delete";
    }
    return policy.classifyShopSubcollection(collection);
  };
  const retainedShopTreeCount = Object.entries(tree.byCollection || {})
      .filter(([collection]) =>
        shopSubcollectionClassification(collection) === "retain")
      .reduce((sum, entry) => sum + Number(entry[1] || 0), 0);
  const deletableShopTreeChildCount = Math.max(
      0, Number(tree.count || 0) - retainedShopTreeCount,
  );
  const firestoreDeleteCount = inventoryRows
      .filter((row) =>
        ["delete", "special"].includes(row.classification) &&
        row.status !== "failed")
      .reduce((sum, row) => sum + Number(row.count || 0),
          deletableShopTreeChildCount) +
      userRelated.rows.reduce(
          (sum, row) => sum +
            (row.classification === "delete" ? Number(row.count || 0) : 0),
          0,
      );

  const shopTreeItem = {
    source: tree.status === "success" ?
      `shops/${shopId}` : `shops/${shopId}/**`,
    dataType: "firestore",
    count: tree.count === null ? null :
      tree.status === "success" ? 1 : tree.count + 1,
    bytes: null,
    status: tree.status,
    reason: tree.status === "success" ?
      "指定店家主文件" : "店家樹掃描未完成，已找到文件全部列為待確認",
  };
  const ownershipItems = {
    safeDelete: tree.status === "success" ? [shopTreeItem] : [],
    mustRetain: [],
    shared: [],
    manual: tree.status === "success" ? [] : [shopTreeItem],
  };
  if (tree.status === "success") {
    for (const [collection, count] of
      Object.entries(tree.byCollection || {})) {
      if (Number(count || 0) === 0) continue;
      const classification = shopSubcollectionClassification(collection);
      const item = {
        source: `shops/${shopId}/…/${collection}`,
        dataType: "firestore",
        count: Number(count),
        bytes: null,
        status: "success",
        reason: classification === "retain" ?
          "商城訂單包含未完成、已完成服務、付款或退款資訊，必須保留" :
          collection === "store_orders" ?
            "商城訂單都已取消或拒絕，且沒有實際收款" :
            "指定店家專屬子集合，可隨這間店家清除",
        risk: classification === "retain" ?
          "可能涉及付款、退款及消費爭議" : "",
      };
      ownershipItems[classification === "retain" ?
        "mustRetain" : "safeDelete"].push(item);
    }
  }
  const bookingTreeItem = {
    source: "bookings/{bookingId}/**",
    dataType: "firestore",
    count: bookingTree.count,
    bytes: null,
    status: bookingTree.status,
    reason: bookingTree.reason ||
      (safeTestTransactions ?
        "來源訂單已結束且沒有付款、退款、爭議或外部交易資訊" :
        "訂單訊息及其他子集合跟隨交易保存政策，不列入自動清除"),
    risk: safeTestTransactions ? "" : "可能包含交易、溝通或申訴證據",
  };
  if (bookingTree.status === "success" &&
      Number(bookingTree.count || 0) > 0) {
    ownershipItems[safeTestTransactions ? "safeDelete" : "mustRetain"]
        .push(bookingTreeItem);
  } else if (bookingTree.status !== "success") {
    ownershipItems.manual.push(bookingTreeItem);
  }
  for (const row of inventoryRows) {
    if (row.path === `shops/${shopId}`) {
      // 店家主文件已包含在 shops/{shopId}/**，避免重複分類。
      continue;
    }
    if (row.status === "success" && Number(row.count || 0) === 0) {
      continue;
    }
    const item = {
      source: row.path || row.collection,
      dataType: "firestore",
      count: row.count,
      bytes: null,
      status: row.status,
      reason: row.reason || row.relation || "",
      risk: row.classification === "retain" ?
        "依法或政策保留，正式刪除前不得移除" :
        row.classification === "shared" ?
          "可能影響顧客或其他店家" :
          row.classification === "manual" ?
            "關聯或刪除政策不足，會阻擋後續刪除" : "",
    };
    if (row.status === "failed" || row.status === "partial") {
      ownershipItems.manual.push(Object.assign({}, item, {
        reason: row.reason || "掃描未完成，不能判定安全刪除",
      }));
    } else if (row.classification === "delete" ||
        row.classification === "special") {
      ownershipItems.safeDelete.push(item);
    } else if (row.classification === "retain") {
      ownershipItems.mustRetain.push(item);
    } else if (row.classification === "shared") {
      ownershipItems.shared.push(item);
    } else if (Number(row.count || 0) > 0) {
      ownershipItems.manual.push(item);
    }
  }
  for (const row of userRelated.rows) {
    if (row.status === "success" && Number(row.count || 0) === 0) {
      continue;
    }
    const item = {
      source: `collectionGroup:${row.collectionGroup}`,
      dataType: "firestore",
      count: row.count,
      bytes: null,
      status: row.status,
      reason: row.reason,
      risk: row.classification === "delete" ? "" :
        "條款或共用資料保存政策尚未完成",
    };
    if (row.status !== "success") ownershipItems.manual.push(item);
    else if (row.classification === "delete") {
      ownershipItems.safeDelete.push(item);
    } else if (row.classification === "shared") {
      ownershipItems.shared.push(item);
    } else {
      ownershipItems.mustRetain.push(item);
    }
  }
  for (const row of accountLinks) {
    const manualProfileCount =
      Number(row.singleShopAdminProfileCount || 0);
    if (row.status !== "success") {
      ownershipItems.manual.push({
        source: `${row.collection}.shopIds`,
        dataType: "firestore",
        count: row.count,
        bytes: null,
        status: row.status,
        reason: row.reason || "帳號關聯掃描未完成，已找到的資料全部列為待確認",
        risk: "可能影響其他店家或共用會員主檔",
      });
      continue;
    }
    const sharedCount = Math.max(
        0, Number(row.count || 0) - manualProfileCount,
    );
    if (sharedCount > 0) {
      ownershipItems.shared.push({
        source: `${row.collection}.shopIds`,
        dataType: "firestore",
        count: sharedCount,
        bytes: null,
        status: row.status,
        reason: row.reason || "共用帳號主檔，只移除指定店家關聯",
        risk: "刪除主檔會影響顧客登入或其他店家",
        sharedWithOtherShopsCount: row.sharedWithOtherShopsCount || 0,
      });
    }
    if (manualProfileCount > 0) {
      ownershipItems.shared.push({
        source: "user_profiles（只解除本店關聯）",
        dataType: "firestore",
        count: manualProfileCount,
        bytes: null,
        status: "success",
        reason: "顧客或店家建立的個人主檔保留，只移除本店 shopIds 關聯",
        risk: "不刪除 Auth、個人主檔或寵物照片",
      });
    }
  }
  const storageGroups = {};
  for (const row of storage.prefixes) {
    if (row.status === "success" && Number(row.count || 0) === 0) {
      continue;
    }
    const root = text(row.prefix).split("/")[0] || "unknown";
    const target = row.status !== "success" || row.category === "manual" ?
      "manual" : row.category === "safe_delete" ?
        "safeDelete" : "mustRetain";
    const key = [
      target,
      root,
      row.status,
      row.ownership,
      row.reason,
    ].join("|");
    const item = storageGroups[key] || {
      source: `${root}/…`,
      dataType: "storage",
      count: 0,
      bytes: 0,
      status: row.status,
      reason: row.reason,
      risk: row.category === "manual" ?
        "未完成歸屬或保存政策驗證，會阻擋後續刪除" :
        row.category === "retain" ?
          "保留，不得納入店家檔案刪除" : "",
      ownership: row.ownership,
      samplePaths: [],
      target,
      sourceCount: 0,
    };
    item.sourceCount += 1;
    if (row.count === null || item.count === null) item.count = null;
    else item.count += Number(row.count || 0);
    if (row.bytes === null || item.bytes === null) item.bytes = null;
    else item.bytes += Number(row.bytes || 0);
    for (const path of [
      row.label || row.prefix,
      ...(row.samplePaths || []),
    ]) {
      if (item.samplePaths.length < 8 &&
          !item.samplePaths.includes(path)) {
        item.samplePaths.push(path);
      }
    }
    storageGroups[key] = item;
  }
  for (const item of Object.values(storageGroups)) {
    ownershipItems[item.target].push(item);
    delete item.target;
  }
  const protectedGroups = {};
  for (const row of protectedStorage.rows) {
    const resolvedCategory = row.status === "failed" || row.exists !== true ?
      "manual" : row.category;
    const key = `${resolvedCategory}:${row.status}:${row.exists}`;
    const group = protectedGroups[key] || {
      source: row.category === "retain_customer" ?
        "pets/{uid}/（顧客原始照片引用）" : "平台／共用 Storage 引用",
      dataType: row.exists === true ? "storage" : "reference",
      count: 0,
      bytes: 0,
      status: row.status,
      reason: row.reason,
      risk: row.category === "retain_customer" ?
        "刪除會影響顧客原始寵物資料" :
        "共用或失效引用不得自動清除",
      samplePaths: [],
    };
    group.count += 1;
    if (row.bytes !== null) group.bytes += Number(row.bytes || 0);
    if (group.samplePaths.length < 5) group.samplePaths.push(row.path);
    protectedGroups[key] = group;
  }
  for (const [key, item] of Object.entries(protectedGroups)) {
    if (key.startsWith("manual:")) ownershipItems.manual.push(item);
    else ownershipItems.shared.push(item);
  }
  if (!protectedStorage.complete && protectedStorage.reason) {
    ownershipItems.manual.push({
      source: "共用 Storage 引用檢查",
      dataType: "storage",
      count: protectedStorage.totalReferenceCount -
        protectedStorage.checkedCount,
      bytes: null,
      status: "partial",
      reason: protectedStorage.reason,
    });
  }
  if (unknownStorageReferences.length > 0) {
    const existingRows = unknownStorage.rows
        .filter((row) => row.exists === true);
    if (existingRows.length > 0) {
      ownershipItems.manual.push({
        source: "未識別 Storage 實際物件",
        dataType: "storage",
        count: existingRows.length,
        bytes: existingRows.reduce(
            (sum, row) => sum + Number(row.bytes || 0), 0,
        ),
        status: unknownStorage.status,
        reason: "物件存在，但路徑與跨店歸屬尚未確認",
        risk: "可能被顧客、其他店家或平台功能引用",
        samplePaths: existingRows.slice(0, 5).map((row) => row.path),
      });
    }
    const missingRows = unknownStorage.rows
        .filter((row) => row.exists === false);
    if (missingRows.length > 0) {
      ownershipItems.manual.push({
        source: "失效的未知 Storage 引用",
        dataType: "reference",
        count: missingRows.length,
        bytes: null,
        status: "success",
        reason: "Firestore 有引用，但實際物件不存在",
        risk: "資料引用已失效，需人工確認來源文件",
        samplePaths: missingRows.slice(0, 5).map((row) => row.path),
      });
    }
  }
  if (!unknownStorage.complete) {
    ownershipItems.manual.push({
      source: "未完成的未知 Storage 引用檢查",
      dataType: "reference",
      count: unknownStorage.totalReferenceCount -
        unknownStorage.checkedCount,
      bytes: null,
      status: "partial",
      reason: unknownStorage.reason || "部分未知路徑無法完成檢查",
      samplePaths: unknownStorageReferences.slice(0, 5),
    });
  }

  /**
   * @param {Object[]} items 分類明細
   * @return {Object}
   */
  function summarizeOwnership(items) {
    let firestoreCount = 0;
    let storageCount = 0;
    let storageBytes = 0;
    let referenceCount = 0;
    let hasUnknownCount = false;
    for (const item of items) {
      if (item.count === null || item.count === undefined) {
        hasUnknownCount = true;
        continue;
      }
      if (item.dataType === "storage") {
        storageCount += Number(item.count || 0);
        storageBytes += Number(item.bytes || 0);
      } else if (item.dataType === "reference") {
        referenceCount += Number(item.count || 0);
      } else {
        firestoreCount += Number(item.count || 0);
      }
    }
    return {
      firestoreCount,
      storageCount,
      storageBytes,
      referenceCount,
      complete: !hasUnknownCount &&
        items.every((item) => item.status === "success"),
      itemCount: items.length,
      items,
    };
  }
  const ownership = {
    safeDelete: summarizeOwnership(ownershipItems.safeDelete),
    mustRetain: summarizeOwnership(ownershipItems.mustRetain),
    shared: summarizeOwnership(ownershipItems.shared),
    manual: summarizeOwnership(ownershipItems.manual),
  };

  /**
   * @param {Object} row 原始掃描列
   * @param {Object} extra 顯示補充
   * @return {Object}
   */
  function scanSource(row, extra) {
    const status = text(row.status || "not_scanned");
    const foundCount = row.count === undefined ? null : row.count;
    return Object.assign({
      source: text(row.path || row.source || row.collection ||
        row.collectionGroup || row.prefix),
      relation: text(row.relation || "依來源路徑精確關聯"),
      status,
      foundCount,
      classificationSuccessCount:
        status === "failed" ? null : foundCount,
      classificationFailedCount:
        status === "success" ? 0 : null,
      classification: text(row.classification || row.category),
      errorCode: text(row.errorCode),
      pageComplete: row.complete === true,
      reason: text(row.reason),
    }, extra || {});
  }

  const firestoreSources = [
    scanSource({
      path: `shops/${shopId}/**`,
      relation: "主文件 ID 與遞迴子集合",
      status: tree.status,
      complete: tree.complete,
      count: tree.count,
      reason: tree.reason,
      errorCode: tree.errorCode,
    }, {scope: "firestore", includesShopRoot: false}),
    scanSource({
      path: "bookings/{bookingId}/**",
      relation: "已由 bookings.shopId 確認的訂單子集合",
      status: bookingTree.status,
      complete: bookingTree.complete,
      count: bookingTree.count,
      reason: bookingTree.reason,
      errorCode: bookingTree.errorCode,
    }, {scope: "firestore"}),
    ...inventoryRows.map((row) =>
      scanSource(row, {scope: "firestore"})),
    ...userRelated.rows.map((row) => scanSource(Object.assign({}, row, {
      path: `collectionGroup:${row.collectionGroup}`,
      relation: "shopId == 指定店號",
    }), {scope: "firestore"})),
    ...accountLinks.map((row) => scanSource(Object.assign({}, row, {
      path: `${row.collection}.shopIds`,
      relation: "shopIds array-contains 指定店號",
    }), {scope: "firestore"})),
  ];
  const storageDetailRows = storage.prefixes
      .filter((row) => row.status !== "success" ||
        Number(row.count || 0) > 0);
  const storageSources = storageDetailRows
      .slice(0, MAX_PREVIEW_DETAIL_ROWS).map((row) =>
        scanSource(Object.assign({}, row, {
          path: row.label || row.prefix,
          relation: "Storage prefix 列舉與 Firestore 引用驗證",
        }), {
          scope: "storage",
          bytes: row.bytes,
          ownership: row.ownership,
          category: row.category,
        }),
      );
  if (storageDetailRows.length > MAX_PREVIEW_DETAIL_ROWS) {
    storageSources.push(scanSource({
      path: "Storage 明細摘要",
      relation: "完整統計已計入；回傳明細只保留前段及聚合分類",
      status: "success",
      complete: true,
      count: storageDetailRows.length - MAX_PREVIEW_DETAIL_ROWS,
      reason: "為避免 Callable 回應過大，其餘路徑請依聚合分類及範例路徑核對",
    }, {scope: "storage-detail"}));
  }
  const metadataSources = [scanSource({
    path: "shop owner identity",
    relation: "shops.ownerUid、shop_members owner、Firebase Auth、users",
    status: owner.status,
    complete: owner.complete,
    count: owner.ownerMemberCount,
    reason: (owner.warnings || []).join("；"),
  }, {scope: "identity"})];
  const classifiedFirestoreCount = [
    ownership.safeDelete,
    ownership.mustRetain,
    ownership.shared,
    ownership.manual,
  ].reduce((sum, group) =>
    sum + Number(group.firestoreCount || 0), 0);
  const scannedFirestoreCount = firestoreSources.reduce((sum, row) =>
    sum + Number(row.foundCount || 0), 0);
  const classifiedStorageCount = [
    ownership.safeDelete,
    ownership.mustRetain,
    ownership.shared,
    ownership.manual,
  ].reduce((sum, group) =>
    sum + Number(group.storageCount || 0), 0);
  const classifiedStorageBytes = [
    ownership.safeDelete,
    ownership.mustRetain,
    ownership.shared,
    ownership.manual,
  ].reduce((sum, group) =>
    sum + Number(group.storageBytes || 0), 0);
  const scannedStorageCount =
    storage.prefixes.reduce((sum, row) =>
      sum + Number(row.count || 0), 0) +
    protectedStorage.rows.filter((row) => row.exists === true).length +
    unknownStorage.existingFileCount;
  const scannedStorageBytes =
    storage.prefixes.reduce((sum, row) =>
      sum + Number(row.bytes || 0), 0) +
    protectedStorage.rows.filter((row) => row.exists === true)
        .reduce((sum, row) => sum + Number(row.bytes || 0), 0) +
    unknownStorage.existingBytes;
  const firestoreDifference =
    scannedFirestoreCount - classifiedFirestoreCount;
  const storageDifference = scannedStorageCount - classifiedStorageCount;
  const consistency = {
    status: firestoreDifference === 0 && storageDifference === 0 ?
      "success" : "failed",
    complete: firestoreDifference === 0 && storageDifference === 0,
    firestore: {
      scannedCount: scannedFirestoreCount,
      classifiedCount: classifiedFirestoreCount,
      unclassifiedCount: Math.max(0, firestoreDifference),
      difference: firestoreDifference,
      treeCount: tree.count,
      shopRootCount: 1,
      rootLinkedCount: inventoryRows
          .filter((row) => row.path !== `shops/${shopId}`)
          .reduce((sum, row) => sum + Number(row.count || 0), 0),
      duplicateCount: 0,
    },
    storage: {
      listedPrefixFileCount: storage.prefixes
          .reduce((sum, row) => sum + Number(row.count || 0), 0),
      protectedExistingFileCount:
        protectedStorage.rows.filter((row) => row.exists === true).length,
      unknownExistingFileCount: unknownStorage.existingFileCount,
      scannedFileCount: scannedStorageCount,
      scannedBytes: scannedStorageBytes,
      classifiedFileCount: classifiedStorageCount,
      classifiedBytes: classifiedStorageBytes,
      unclassifiedFileCount: Math.max(0, storageDifference),
      difference: storageDifference,
      duplicateReferenceCount: duplicateStorageReferenceCount,
      uniqueReferenceCount: allReferences.length,
      missingReferenceCount:
        protectedStorage.rows.filter((row) => row.exists === false).length +
        unknownStorage.missingReferenceCount,
      unresolvedOwnershipCount:
        unresolvedStorageRows.reduce(
            (sum, row) => sum + Number(row.count || 0), 0,
        ) + unknownStorage.existingFileCount,
    },
    reason: firestoreDifference === 0 && storageDifference === 0 ?
      "相同掃描範圍內的已找到資料均已唯一歸入 A／B／C" :
      "掃描數與 A／B／C 分類數不一致，禁止後續刪除",
  };
  storage.listingStatus = storage.status;
  storage.ownershipStatus =
    consistency.storage.unresolvedOwnershipCount > 0 ?
      "partial" : "success";
  storage.status = combineStatuses([
    storage.listingStatus,
    protectedStorage.status,
    unknownStorage.status,
    storage.ownershipStatus,
  ]);
  storage.complete = storage.status === "success" &&
    consistency.storage.difference === 0;
  if (!consistency.complete) complete = false;

  /**
   * @param {Object} value 阻擋或資訊項目
   * @return {Object}
   */
  function issue(value) {
    return Object.assign({
      type: "technical",
      code: "unknown",
      title: "未分類問題",
      count: null,
      source: "",
      reason: "",
      requiresManualAction: true,
      blocksTestReset: true,
      blocksInactiveCleanup: true,
      blocksPermanentDeletion: true,
    }, value);
  }
  const blockerGroups = {
    technical: [],
    retention: [],
    business: [],
    safety: [],
  };
  for (const failure of failures) {
    blockerGroups.technical.push(issue({
      type: "technical",
      code: text(failure.errorCode || "scan-failed"),
      title: "掃描來源查詢失敗",
      source: text(failure.source),
      reason: text(failure.reason),
    }));
  }
  const partialSources = [
    ...firestoreSources,
    ...storageSources,
    ...metadataSources,
  ]
      .filter((row) => row.status === "partial");
  for (const row of partialSources) {
    blockerGroups.technical.push(issue({
      type: "technical",
      code: row.scope === "identity" ?
        "owner-identity-partial" : "pagination-incomplete",
      title: row.scope === "identity" ?
        "店主身分關聯待確認" : "分頁或安全上限尚未完成",
      count: row.foundCount,
      source: row.source,
      reason: row.reason || "只取得部分結果",
    }));
  }
  if (consistency.complete !== true) {
    blockerGroups.technical.push(issue({
      type: "technical",
      code: "classification-mismatch",
      title: "掃描與分類統計不一致",
      count: Math.abs(firestoreDifference) + Math.abs(storageDifference),
      source: "preview consistency check",
      reason: consistency.reason,
    }));
  }
  if (Number(consistency.storage.unresolvedOwnershipCount || 0) > 0) {
    blockerGroups.technical.push(issue({
      type: "technical",
      code: "storage-ownership-unresolved",
      title: "Storage 歸屬尚未完成驗證",
      count: consistency.storage.unresolvedOwnershipCount,
      source: "Firebase Storage 與 Firestore 引用",
      reason: "缺少全域跨店反向引用或實際路徑歸屬證據",
    }));
  }
  for (const item of [
    ...ownershipItems.mustRetain,
    ...ownershipItems.shared,
  ]) {
    if (Number(item.count || 0) === 0) continue;
    blockerGroups.retention.push(issue({
      type: "retention",
      code: item.dataType === "storage" ?
        "retained-storage" : "retained-firestore",
      title: item.source,
      count: item.count,
      source: item.source,
      reason: item.reason,
      requiresManualAction: false,
      blocksTestReset: false,
      blocksInactiveCleanup: false,
      blocksPermanentDeletion: true,
    }));
  }
  const businessIssues = [{
    code: "open-bookings",
    title: "未結束訂單",
    count: transactions.openBookingCount,
    source: "bookings.status",
    reason: "仍有未完成的住宿或安親服務",
  }, {
    code: "unpaid-payments",
    title: "未付款紀錄",
    count: transactions.unpaidPaymentCount,
    source: "payments",
    reason: "測試重置可在確認無任何外部交易後清除；長期閒置清理則要求為 0 筆",
    blocksTestReset: false,
    blocksInactiveCleanup: true,
  }, {
    code: "refunds",
    title: "退款中／退款紀錄",
    count: transactions.refundingPaymentCount,
    source: "payments.refundStatus",
    reason: "退款及其保存義務尚待確認",
  }, {
    code: "disputes",
    title: "爭議或拒付",
    count: transactions.disputeCount,
    source: "payments.disputeStatus",
    reason: "爭議、拒付或申訴不得直接清除",
  }];
  for (const row of businessIssues) {
    if (Number(row.count || 0) <= 0) continue;
    blockerGroups.business.push(issue(Object.assign({}, row, {
      type: "business",
      requiresManualAction: true,
      blocksTestReset: row.blocksTestReset !== false,
      blocksInactiveCleanup: row.blocksInactiveCleanup !== false,
      blocksPermanentDeletion: true,
    })));
  }
  if (Number(transactions.paidPaymentCount || 0) > 0) {
    blockerGroups.retention.push(issue({
      type: "retention",
      code: "paid-transactions",
      title: "已付款／外部交易紀錄",
      count: transactions.paidPaymentCount,
      source: "payments",
      reason: "可能涉及法定保存、退款及稽核義務",
      requiresManualAction: true,
      blocksTestReset: true,
      blocksInactiveCleanup: true,
      blocksPermanentDeletion: true,
    }));
  }
  for (const row of [{
    code: "paid-bookings",
    title: "訂單本身帶有付款或外部交易資訊",
    count: transactions.paidBookingCount,
    source: "bookings",
    reason: "即使 payments 查詢為空，訂單本身的交易資訊仍必須保留",
  }, {
    code: "open-store-orders",
    title: "尚未結束的商城訂單",
    count: transactions.openStoreOrderCount,
    source: `shops/${shopId}/store_orders`,
    reason: "商城訂單尚未完成或取消",
  }, {
    code: "paid-store-orders",
    title: "已付款或帶外部交易資訊的商城訂單",
    count: transactions.paidStoreOrderCount,
    source: `shops/${shopId}/store_orders`,
    reason: "商城交易紀錄不得由測試或閒置清理移除",
  }]) {
    if (Number(row.count || 0) <= 0) continue;
    blockerGroups.business.push(issue(Object.assign({}, row, {
      type: "business",
      requiresManualAction: true,
      blocksTestReset: true,
      blocksInactiveCleanup: true,
      blocksPermanentDeletion: true,
    })));
  }
  if (!complete) {
    blockerGroups.safety.push(issue({
      type: "safety",
      code: "scan-incomplete",
      title: "掃描結果不完整",
      count: blockerGroups.technical.length,
      source: "preview scan",
      reason: "技術掃描、歸屬驗證或一致性檢查尚未全部通過",
    }));
  }
  const blockingIssues = Object.values(blockerGroups).flat();
  const retainedBookingStorageCount = storage.prefixes
      .filter((row) =>
        ["booking_images", "booking_extra_charges"]
            .includes(text(row.prefix).split("/")[0]) &&
        row.category === "retain")
      .reduce((sum, row) => sum + Number(row.count || 0), 0);
  transactions.realCommercialCount =
    inventoryRows.filter((row) => row.blocksDeletion === true)
        .reduce((sum, row) => sum + Number(row.count || 0), 0) +
    userRelated.rows.filter((row) => row.blocksDeletion === true).length;
  const executionSummary = Object.assign({}, transactions, {
    manualCollectionCount: ownership.manual.firestoreCount,
    unknownStorageCount: ownership.manual.storageCount,
    retainedBookingStorageCount,
    lastActivityMillis: lastActivityAtMillis,
  });
  const testResetBlockers = [
    ...policy.testResetBlockers(executionSummary),
    ...blockingIssues
        .filter((row) => row.blocksTestReset === true)
        .map((row) => row.title),
  ];
  const inactiveCleanupBlockers = [
    ...policy.inactiveCleanupBlockers(executionSummary),
    ...blockingIssues
        .filter((row) => row.blocksInactiveCleanup === true)
        .map((row) => row.title),
  ];
  const blockers = [...new Set([
    ...legacyPolicyBlockers,
    ...testResetBlockers,
  ])];
  const eligibility = policy.deletionEligibility(Object.assign(
      {},
      executionSummary,
      {scanComplete: complete},
  ));
  const cleanupAllowed = SAFE_CLEANUP_EXECUTION_ENABLED &&
    eligibility.allowed;
  const completedAtMillis = Date.now();
  const combinedStatus = combineStatuses(sectionStatuses);
  return {
    contractVersion: PREVIEW_CONTRACT_VERSION,
    scan: {
      scanId,
      status: complete ? "success" :
        combinedStatus === "success" ? "partial" : combinedStatus,
      complete,
      startedAtMillis,
      completedAtMillis,
      expiresAtMillis:
        completedAtMillis + PREVIEW_VALID_SECONDS * 1000,
      durationMillis: completedAtMillis - startedAtMillis,
      failures,
      sources: [
        ...firestoreSources,
        ...storageSources,
        ...metadataSources,
      ],
      warnings: [
        ...(owner.warnings || []),
        ...unknownStorageReferences.map((path) =>
          `Storage 引用無法確認擁有權：${path}`),
      ],
      projectId: text(admin.app().options.projectId),
      region: REGION,
      technicalIssueCount: blockerGroups.technical.length,
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
        accountLinksStatus,
        shopMembers.status,
        customerMembers.status,
        combineStatuses(specialRows.map((row) => row.status)),
        transactions.status,
        bookingTree.status,
      ]),
      complete: top.complete && tree.complete && userRelated.complete &&
        accountLinks.every((row) => row.status === "success") &&
        shopMembers.complete && customerMembers.complete &&
        specialRows.every((row) => row.status === "success") &&
        transactions.complete && bookingTree.complete &&
        consistency.firestore.difference === 0,
      shopTreeCount: tree.count === null ? null : tree.count + 1,
      shopTreeStatus: tree.status,
      shopSubcollections: tree.byCollection,
      bookingSubcollectionCount: bookingTree.count,
      bookingSubcollectionStatus: bookingTree.status,
      bookingSubcollections: bookingTree.byCollection,
      userRelatedCollections: userRelated.rows,
      accountShopLinks: accountLinks,
      paymentCredentialsCount,
      paymentCredentialsStatus,
      memberCounts: [customerMembers, shopMembers],
      collections: inventoryRows,
      estimatedDeleteCount: firestoreDeleteCount,
      scannedCount: consistency.firestore.scannedCount,
      classifiedCount: consistency.firestore.classifiedCount,
      unclassifiedCount: consistency.firestore.unclassifiedCount,
      rootLinkedCount: consistency.firestore.rootLinkedCount,
    },
    storage: Object.assign({}, storage, {
      prefixes: storageDetailRows.slice(0, MAX_PREVIEW_DETAIL_ROWS),
      prefixDetailCount: storageDetailRows.length,
      prefixDetailTruncated:
        storageDetailRows.length > MAX_PREVIEW_DETAIL_ROWS,
      retainedReferences: retainedStorageReferences,
      unknownReferences: unknownStorageReferences,
      protectedReferences: protectedStorage,
      unknownReferenceInspection: unknownStorage,
      candidatePrefixFileCount: storage.fileCount,
      candidatePrefixBytes: storage.totalBytes,
      scannedFileCount: consistency.storage.scannedFileCount,
      scannedBytes: consistency.storage.scannedBytes,
      classifiedFileCount: consistency.storage.classifiedFileCount,
      unresolvedOwnershipCount:
        consistency.storage.unresolvedOwnershipCount,
      duplicateReferenceCount:
        consistency.storage.duplicateReferenceCount,
    }),
    transactions,
    retained: inventoryRows
        .filter((row) => row.classification === "retain"),
    manual: inventoryRows
        .filter((row) => row.classification === "manual" &&
          (row.status === "failed" || Number(row.count || 0) > 0)),
    ownership,
    classification: ownership,
    consistency,
    blockerGroups,
    blockingIssues,
    blockers,
    relatedUserIds: userRelated.userIds || [],
    execution: {
      enabled: SAFE_CLEANUP_EXECUTION_ENABLED,
      cleanupAllowed,
      cleanupCategory: eligibility.category,
      cleanupLabel: eligibility.label,
      cleanupBlockers: eligibility.blockers,
      testResetAllowed: cleanupAllowed,
      inactiveCleanupAllowed: cleanupAllowed &&
        eligibility.category === "no_transaction",
      testResetBlockers: eligibility.blockers,
      inactiveCleanupBlockers: eligibility.blockers,
      permanentDeletionAllowed: false,
      permanentDeletionReason:
        "曾有真實交易、退款、爭議或完成服務的店家暫不支援永久刪除",
    },
    formalDeletionEnabled: FORMAL_DELETION_ENABLED,
    executionEnabled: SAFE_CLEANUP_EXECUTION_ENABLED,
    writeGuardLimitation:
      "目前 Rules 未檢查 deletionState，刪除期間無法保證阻止所有客戶端直寫。",
  };
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
let deliverDeletionEmail = sendDeletionEmail;

/**
 * 正式環境只使用已設定的 SMTP；未設定時明確失敗，不回報寄送成功。
 * @param {{to: string, subject: string, text: string}} message 郵件
 * @return {Promise<void>}
 */
function readSmtpSecret(secret) {
  try {
    return text(secret.value());
  } catch (_) {
    return "";
  }
}

async function sendDeletionEmail(message) {
  const host = readSmtpSecret(smtpHost);
  const from = readSmtpSecret(smtpFrom);
  const user = readSmtpSecret(smtpUser);
  const pass = readSmtpSecret(smtpPass);
  if (!host || !from || !user || !pass) {
    throw new HttpsError(
        "failed-precondition",
        "尚未設定店家清理驗證信服務，無法寄出驗證碼。",
        {mailConfigured: false},
    );
  }
  let nodemailer;
  try {
    nodemailer = require("nodemailer");
  } catch (_) {
    throw new HttpsError(
        "failed-precondition",
        "尚未安裝寄信元件，無法寄出驗證碼。",
        {mailConfigured: false},
    );
  }
  const port = Number(process.env.SHOP_DELETION_SMTP_PORT || 587);
  const secure = text(process.env.SHOP_DELETION_SMTP_SECURE) === "true";
  const transport = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: {user, pass},
  });
  try {
    await transport.sendMail({
      from,
      to: message.to,
      subject: message.subject,
      text: message.text,
    });
  } catch (error) {
    error.shopDeletionSmtp = emailCode.smtpAuthFailureLog(error, {
      secretsLoaded: true,
      configComplete: true,
      host,
      port,
      secure,
      user,
    });
    throw error;
  }
}

/**
 * @param {Object} preview 預覽結果
 * @return {string}
 */
function previewFingerprint(preview) {
  const execution = preview.execution || {};
  const safe = ((preview.ownership || {}).safeDelete) || {};
  return crypto.createHash("sha256").update(JSON.stringify({
    contractVersion: Number(preview.contractVersion || 0),
    complete: preview.scan && preview.scan.complete === true,
    testResetAllowed: execution.testResetAllowed === true,
    inactiveCleanupAllowed: execution.inactiveCleanupAllowed === true,
    firestoreCount: Number(safe.firestoreCount || 0),
    storageCount: Number(safe.storageCount || 0),
    storageBytes: Number(safe.storageBytes || 0),
  })).digest("hex");
}

/**
 * @param {string} uid 管理員
 * @param {string} shopId 店家
 * @param {Object} preview 預覽
 * @return {Promise<boolean>}
 */
async function savePreviewGrant(uid, shopId, preview) {
  await admin.firestore().collection(PREVIEW_GRANT_COLLECTION)
      .doc(preview.scan.scanId)
      .set({
        uid,
        shopId,
        fingerprint: previewFingerprint(preview),
        contractVersion: PREVIEW_CONTRACT_VERSION,
        expiresAtMillis: Number(preview.scan.expiresAtMillis || 0),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  return true;
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function requestEmailCodeHandler(request) {
  const operator = await requireSuperAdmin(request);
  const data = request.data || {};
  const shopId = text(data.shopId);
  const mode = text(data.mode);
  const scanId = text(data.previewScanId);
  if (!shopId || !scanId) {
    throw new HttpsError("invalid-argument", "缺少店家或掃描識別碼。");
  }
  if (![policy.TEST_RESET_MODE, policy.INACTIVE_CLEANUP_MODE].includes(mode)) {
    throw new HttpsError("invalid-argument", "清理模式不正確。");
  }
  const grant = await admin.firestore().collection(PREVIEW_GRANT_COLLECTION)
      .doc(scanId).get();
  if (!grant.exists ||
      grant.get("uid") !== operator.uid ||
      grant.get("shopId") !== shopId ||
      Number(grant.get("expiresAtMillis") || 0) < Date.now() ||
      Number(grant.get("contractVersion") || 0) !== PREVIEW_CONTRACT_VERSION) {
    throw new HttpsError(
        "failed-precondition",
        "掃描結果已過期或版本不符，請重新掃描。",
    );
  }
  let authUser;
  try {
    authUser = await admin.auth().getUser(operator.uid);
  } catch (_) {
    throw new HttpsError("failed-precondition", "無法確認最高管理員 Email。");
  }
  const recipient = text(authUser.email).toLowerCase();
  if (!recipient || authUser.emailVerified !== true) {
    throw new HttpsError(
        "failed-precondition",
        "最高管理員帳號沒有已驗證 Email，無法寄送驗證碼。",
    );
  }
  const db = admin.firestore();
  const now = Date.now();
  const rateRef = db.collection(EMAIL_RATE_COLLECTION).doc(operator.uid);
  const activeRef = db.collection(EMAIL_ACTIVE_COLLECTION)
      .doc(`${operator.uid}_${shopId}`);
  const ip = text(
      request.rawRequest &&
      (request.rawRequest.ip ||
        (request.rawRequest.headers || {})["x-forwarded-for"]),
  ).split(",")[0].trim();
  const ipRateRef = ip ?
    db.collection(EMAIL_RATE_COLLECTION)
        .doc(`ip_${crypto.createHash("sha256").update(ip).digest("hex")}`) :
    null;
  const code = emailCode.generateCode();
  const salt = emailCode.generateSalt();
  const codeHash = await emailCode.hashCode(code, salt);
  const challengeRef = db.collection(EMAIL_CHALLENGE_COLLECTION).doc();
  await db.runTransaction(async (tx) => {
    const [rate, ipRate, active] = await Promise.all([
      tx.get(rateRef),
      ipRateRef ? tx.get(ipRateRef) : Promise.resolve(null),
      tx.get(activeRef),
    ]);
    const sends = rate.exists && Array.isArray(rate.get("sentAtMillis")) ?
      rate.get("sentAtMillis").map(Number) : [];
    const blocker = emailCode.resendBlocker(
        rate.exists ? Number(rate.get("lastSentAtMillis") || 0) : 0,
        sends,
        now,
    );
    const ipSends = ipRate && ipRate.exists &&
      Array.isArray(ipRate.get("sentAtMillis")) ?
      ipRate.get("sentAtMillis").map(Number) : [];
    const ipBlocker = ipRateRef ?
      emailCode.resendBlocker(0, ipSends, now) : "";
    if (blocker || ipBlocker) {
      throw new HttpsError("resource-exhausted", blocker || ipBlocker);
    }
    if (active.exists && text(active.get("challengeId"))) {
      tx.set(db.collection(EMAIL_CHALLENGE_COLLECTION)
          .doc(text(active.get("challengeId"))), {
        revoked: true,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    tx.set(challengeRef, {
      uid: operator.uid,
      shopId,
      mode,
      scanId,
      contractVersion: PREVIEW_CONTRACT_VERSION,
      codeHash,
      salt,
      attempts: 0,
      used: false,
      revoked: false,
      expiresAtMillis: now + emailCode.EMAIL_CODE_TTL_MS,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(activeRef, {
      challengeId: challengeRef.id,
      uid: operator.uid,
      shopId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const nextSends = sends.filter((value) => now - value < 60 * 60 * 1000);
    nextSends.push(now);
    tx.set(rateRef, {
      sentAtMillis: nextSends,
      lastSentAtMillis: now,
    }, {merge: true});
    if (ipRateRef) {
      const nextIpSends = ipSends
          .filter((value) => now - value < 60 * 60 * 1000);
      nextIpSends.push(now);
      tx.set(ipRateRef, {sentAtMillis: nextIpSends}, {merge: true});
    }
  });
  try {
    await deliverDeletionEmail({
      to: recipient,
      subject: "PetNest 店家清理驗證碼",
      text: [
        "你正在確認 PetNest 平台店家清理操作。",
        `驗證碼：${code}`,
        "驗證碼 5 分鐘內有效，且只能使用一次。",
        "如果這不是你本人的操作，請忽略此信，不要把驗證碼提供給任何人。",
      ].join("\n"),
    });
  } catch (error) {
    await challengeRef.set({
      revoked: true,
      deliveryFailed: true,
    }, {merge: true});
    if (error instanceof HttpsError) throw error;
    console.error("shop deletion email delivery failed", Object.assign({
      challengeId: challengeRef.id,
    }, error.shopDeletionSmtp || {
      smtpCode: text(error.code),
      type: text(error.name),
    }));
    throw new HttpsError(
        "unavailable",
        "驗證碼寄送失敗，請稍後再試。",
        {mailConfigured: true, retryable: true},
    );
  }
  return {
    challengeId: challengeRef.id,
    expiresAtMillis: now + emailCode.EMAIL_CODE_TTL_MS,
    maskedEmail: emailCode.maskEmail(recipient),
    sent: true,
  };
}

/**
 * @param {Object} input 驗證輸入
 * @return {Promise<void>}
 */
async function consumeEmailChallenge(input) {
  const db = admin.firestore();
  const challengeRef = db.collection(EMAIL_CHALLENGE_COLLECTION)
      .doc(text(input.challengeId));
  const activeRef = db.collection(EMAIL_ACTIVE_COLLECTION)
      .doc(`${text(input.uid)}_${text(input.shopId)}`);
  let failure = "";
  await db.runTransaction(async (tx) => {
    const [challenge, active] = await Promise.all([
      tx.get(challengeRef),
      tx.get(activeRef),
    ]);
    if (!challenge.exists || !active.exists ||
        text(active.get("challengeId")) !== challengeRef.id) {
      failure = "驗證碼已失效，請重新申請。";
      return;
    }
    const submittedHash = await emailCode.hashCode(
        text(input.code),
        text(challenge.get("salt")),
    );
    const decision = emailCode.evaluateChallenge(challenge.data(), {
      uid: text(input.uid),
      shopId: text(input.shopId),
      mode: text(input.mode),
      scanId: text(input.scanId),
      codeMatches: emailCode.hashesMatch(
          submittedHash,
          text(challenge.get("codeHash")),
      ),
    }, Date.now());
    if (!decision.ok) {
      if (decision.incrementAttempt) {
        tx.update(challengeRef, {
          attempts: admin.firestore.FieldValue.increment(1),
        });
      }
      failure = decision.message;
      return;
    }
    tx.update(challengeRef, {
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.delete(activeRef);
  });
  if (failure) throw new HttpsError("failed-precondition", failure);
}

async function previewHandler(request) {
  const operator = await requireSuperAdmin(request);
  const shopId = text((request.data || {}).shopId);
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家編號。");
  }
  try {
    const preview = await buildPreview(shopId);
    try {
      await savePreviewGrant(operator.uid, shopId, preview);
      preview.authorization = {ready: true, contractVersion: PREVIEW_CONTRACT_VERSION};
    } catch (error) {
      console.error("shop deletion preview grant failed", {
        scanId: preview.scan.scanId,
        code: text(error.code),
        type: text(error.name),
      });
      preview.authorization = {
        ready: false,
        contractVersion: PREVIEW_CONTRACT_VERSION,
        reason: "無法保存本次掃描授權，請重新掃描。",
      };
    }
    return preview;
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
  const data = request.data || {};
  const operator = await requireSuperAdmin(request);
  if (!SAFE_CLEANUP_EXECUTION_ENABLED) {
    throw new HttpsError(
        "failed-precondition",
        "安全清理執行功能目前已關閉。",
        {executionEnabled: false},
    );
  }
  const shopId = text(data.shopId);
  if (text(data.mode) === policy.PERMANENT_DELETE_MODE) {
    throw new HttpsError(
        "failed-precondition",
        "曾有真實交易、退款、爭議或完成服務的店家暫不支援永久刪除。",
    );
  }
  const mode = policy.TEST_RESET_MODE;
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家編號。");
  }
  const preview = await buildPreview(shopId);
  if (preview.scan.complete !== true ||
      preview.consistency.complete !== true) {
    throw new HttpsError(
        "failed-precondition",
        "掃描未完整或分類統計不一致，禁止建立清理工作。",
        {
          scanId: preview.scan.scanId,
          blockers: preview.blockers,
        },
    );
  }
  const requestedScanId = text(data.previewScanId);
  const grant = await admin.firestore().collection(PREVIEW_GRANT_COLLECTION)
      .doc(requestedScanId).get();
  if (!grant.exists ||
      grant.get("uid") !== operator.uid ||
      grant.get("shopId") !== shopId ||
      Number(grant.get("expiresAtMillis") || 0) < Date.now() ||
      Number(grant.get("contractVersion") || 0) !== PREVIEW_CONTRACT_VERSION) {
    throw new HttpsError(
        "failed-precondition",
        "掃描授權已過期或版本不符，請重新掃描。",
    );
  }
  if (text(grant.get("fingerprint")) !== previewFingerprint(preview)) {
    throw new HttpsError(
        "failed-precondition",
        "店家資料已變更，請重新掃描後再確認。",
    );
  }
  const auditReason = text(data.reason).length >= 10 ?
    text(data.reason) : "平台管理員清理無實際交易店家";
  if (text(preview.shop.shopId) !== shopId) {
    throw new HttpsError(
        "failed-precondition",
        "刪除目標與掃描店家不一致，請重新掃描。",
    );
  }
  const confirmation = {
    shopCode: preview.shop.shopCode,
    typedShopCode: shopId,
    reason: auditReason,
    irreversibleAcknowledged: data.irreversibleAcknowledged === true,
    scopeConfirmed: data.irreversibleAcknowledged === true,
    testDataConfirmed: true,
    mode,
    summary: Object.assign({}, preview.transactions, {
      manualCollectionCount: preview.manual.length,
      unknownStorageCount:
        Number(preview.ownership.manual.storageCount || 0),
      lastActivityMillis: Number(preview.shop.lastActivityAtMillis || 0),
    }),
  };
  const execution = preview.execution || {};
  const confirmationErrors = data.irreversibleAcknowledged === true ?
    [] : ["尚未確認永久刪除此店家及其專屬資料"];
  const eligibilityBlockers = execution.cleanupAllowed === true ?
    [] : (execution.cleanupBlockers || ["此店家目前不能完整刪除"]);
  const uniqueBlockers = [...new Set(
      confirmationErrors.concat(eligibilityBlockers),
  )];
  if (uniqueBlockers.length > 0) {
    throw new HttpsError(
        "failed-precondition",
        uniqueBlockers.join("；"),
        {blockers: uniqueBlockers},
    );
  }
  if (!text(data.emailChallengeId) || !text(data.emailCode)) {
    throw new HttpsError(
        "failed-precondition",
        "請先完成 Email 六位數驗證。",
    );
  }
  await consumeEmailChallenge({
    uid: operator.uid,
    shopId,
    mode,
    scanId: requestedScanId,
    challengeId: text(data.emailChallengeId),
    code: text(data.emailCode),
  });
  const emailAuthorizedUntil = Date.now() + emailCode.EMAIL_AUTHORIZATION_MS;
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
      deletedStorageBytes: 0,
      updatedAccountLinks: 0,
      failedCount: 0,
      retainedCount:
        Number(preview.ownership.mustRetain.firestoreCount || 0) +
        Number(preview.ownership.mustRetain.storageCount || 0) +
        Number(preview.ownership.shared.firestoreCount || 0) +
        Number(preview.ownership.shared.storageCount || 0),
      retainedItems: [
        ...(preview.ownership.mustRetain.items || []),
        ...(preview.ownership.shared.items || []),
      ].slice(0, 100).map((row) => ({
        source: text(row.source),
        count: Number(row.count || 0),
        reason: text(row.reason),
      })),
      previewScanId: text(preview.scan.scanId),
      relatedUserIds: preview.relatedUserIds || [],
      cleanupCategory: text((preview.execution || {}).cleanupCategory),
      emailAuthorizedUntil,
      previewContractVersion: PREVIEW_CONTRACT_VERSION,
      expectedDeleteFirestore:
        Number(preview.ownership.safeDelete.firestoreCount || 0),
      expectedDeleteStorage:
        Number(preview.ownership.safeDelete.storageCount || 0),
      expectedDeleteStorageBytes:
        Number(preview.ownership.safeDelete.storageBytes || 0),
      previewCompletedAtMillis:
        Number(preview.scan.completedAtMillis || Date.now()),
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
/**
 * 清理一般操作紀錄、未付費商業設定與免費激活紀錄。
 * 必要稽核與真實付費資料留在原處。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} shopId 店家編號
 * @return {Promise<{deleted: number, more: boolean}>}
 */
async function deleteOperationalShopRecords(db, shopId) {
  let deleted = 0;
  const logs = await db.collection("action_logs")
      .where("shopId", "==", shopId).limit(40).get();
  for (const doc of logs.docs) {
    if (policy.isRequiredAuditAction(doc.data())) continue;
    await doc.ref.delete();
    deleted += 1;
  }
  const commercial = await db.collection("shop_commercial").doc(shopId).get();
  if (commercial.exists) {
    if (policy.hasRealCommercialObligation(commercial.data())) {
      throw new Error("偵測到必須保留的商業紀錄，已停止清理");
    }
    await commercial.ref.delete();
    deleted += 1;
  }
  const shop = await db.collection("shops").doc(shopId).get();
  let codeId = shop.exists ?
    text(shop.get("activationCodeId") || shop.get("codeId")) : "";
  if (!codeId) {
    const requests = await db.collection("sales_shop_create_requests")
        .where("shopId", "==", shopId).limit(5).get();
    codeId = requests.docs
        .map((doc) => text(doc.get("codeId"))).find(Boolean) || "";
  }
  if (codeId) {
    const log = db.collection("activation_codes").doc(codeId)
        .collection("usage_logs").doc(shopId);
    const snapshot = await log.get();
    if (snapshot.exists) {
      if (policy.hasRealCommercialObligation(snapshot.data())) {
        throw new Error("偵測到付費或權益使用紀錄，已停止清理");
      }
      await log.delete();
      deleted += 1;
    }
  }
  return {deleted, more: logs.size === 40 && deleted > 0};
}

async function deleteQueryDocuments(query, limit = 150) {
  const snapshot = await query.limit(Math.min(limit, 1)).get();
  if (snapshot.empty) return 0;
  const doc = snapshot.docs[0];
  const descendants = await inspectRelatedDocumentTrees([doc.ref], 1);
  if (!descendants.complete) {
    throw new Error(`刪除前無法完整計數 ${doc.ref.path} 的子集合`);
  }
  await admin.firestore().recursiveDelete(doc.ref);
  return 1 + Number(descendants.count || 0);
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
  let deletedBytes = 0;
  const failures = [];
  for (const file of files) {
    const bytes = Number((file.metadata || {}).size || 0);
    try {
      await file.delete({ignoreNotFound: true});
      deleted += 1;
      deletedBytes += bytes;
    } catch (error) {
      failures.push({
        storageObject: file.name,
        errorCode: text(error.code || error.name || "storage-delete-failed"),
      });
    }
  }
  return {deleted, deletedBytes, failures};
}

/**
 * @param {FirebaseFirestore.DocumentReference} jobRef 工作
 * @param {Object[]} failures Storage 失敗項目
 */
async function recordStorageFailures(jobRef, failures) {
  for (const failure of failures) {
    await jobRef.collection("failures").add({
      phase: "storage",
      message: `Storage 刪除失敗（${text(failure.errorCode)}）`,
      storageObject: text(failure.storageObject),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
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
      phase: "test_transactions",
      transactionCollectionIndex: 0,
    });
    return;
  }
  if (phase === "storage_direct") {
    const index = Number(job.storagePrefixIndex || 0);
    if (index >= EXECUTABLE_DIRECT_STORAGE_PREFIXES.length) {
      await patchJob(jobRef, {
        phase: "cross_collections",
        collectionIndex: 0,
      });
      return;
    }
    const prefix =
      `${EXECUTABLE_DIRECT_STORAGE_PREFIXES[index]}/${shopId}/`;
    const result =
      await deleteStoragePage(admin.storage().bucket(), prefix);
    if (result.deleted > 0) {
      await patchJob(jobRef, {
        deletedStorage:
          admin.firestore.FieldValue.increment(result.deleted),
        deletedStorageBytes:
          admin.firestore.FieldValue.increment(result.deletedBytes),
      });
    }
    if (result.failures.length > 0) {
      await recordStorageFailures(jobRef, result.failures);
      const error = new Error(
          `${result.failures.length} 個 Storage 檔案刪除失敗`,
      );
      error.storageObject = text(result.failures[0].storageObject);
      throw error;
    }
    if (result.deleted === 0) {
      await patchJob(jobRef, {storagePrefixIndex: index + 1});
    }
    return;
  }
  if (phase === "test_transactions") {
    const collections = ["payments", "bookings"];
    const index = Number(job.transactionCollectionIndex || 0);
    if (index >= collections.length) {
      await patchJob(jobRef, {
        phase: "storage_direct",
        storagePrefixIndex: 0,
        transactionCollectionIndex: admin.firestore.FieldValue.delete(),
      });
      return;
    }
    const collection = collections[index];
    const snapshot = await db.collection(collection)
        .where("shopId", "==", shopId).limit(1).get();
    if (snapshot.empty) {
      await patchJob(jobRef, {transactionCollectionIndex: index + 1});
      return;
    }
    if (text(job.mode) === policy.INACTIVE_CLEANUP_MODE) {
      throw new Error(`長期閒置清理偵測到新增的 ${collection} 文件`);
    }
    const document = snapshot.docs[0];
    const safe = collection === "bookings" ?
      policy.isSafeTestBooking(document.data()) :
      policy.isSafeTestPayment(document.data());
    if (!safe) {
      throw new Error(`${collection}/${document.id} 不符合測試資料安全條件`);
    }
    const descendants = await inspectRelatedDocumentTrees(
        [document.ref],
        1,
    );
    if (!descendants.complete) {
      throw new Error(`${collection}/${document.id} 子集合掃描不完整`);
    }
    await db.recursiveDelete(document.ref);
    await patchJob(jobRef, {
      deletedFirestore: admin.firestore.FieldValue.increment(
          1 + Number(descendants.count || 0),
      ),
    });
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
    if (job.operationalCleanupDone !== true) {
      const operational = await deleteOperationalShopRecords(db, shopId);
      await patchJob(jobRef, {
        operationalCleanupDone: operational.more !== true,
        deletedFirestore: admin.firestore.FieldValue.increment(
            operational.deleted,
        ),
      });
      return;
    }
    const userIds = Array.isArray(job.relatedUserIds) ?
      job.relatedUserIds.map(text).filter(Boolean) : [];
    let deleted = 0;
    for (const uid of userIds) {
      const pets = await db.collection("user_profiles").doc(uid)
          .collection("pets").get();
      for (const pet of pets.docs) {
        const answer = pet.ref.collection("shop_form_answers").doc(shopId);
        if ((await answer.get()).exists) {
          await answer.delete();
          deleted += 1;
        }
      }
    }
    await patchJob(jobRef, {
      phase: "account_shop_links",
      accountCollectionIndex: 0,
      deletedFirestore: admin.firestore.FieldValue.increment(deleted),
    });
    return;
  }
  if (phase === "account_shop_links") {
    const collections = ["users", "user_profiles"];
    const index = Number(job.accountCollectionIndex || 0);
    if (index >= collections.length) {
      await patchJob(jobRef, {phase: "delete_shop_tree"});
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
      updatedAccountLinks:
        admin.firestore.FieldValue.increment(snapshot.size),
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
      phase: "retire_shop_code",
      deletedFirestore: admin.firestore.FieldValue.increment(deleted),
    });
    return;
  }
  if (phase === "delete_shop_tree") {
    const shopRef = db.collection("shops").doc(shopId);
    if ((await shopRef.get()).exists) {
      for (const collection of ["bookings", "payments"]) {
        const recreated = await db.collection(collection)
            .where("shopId", "==", shopId).limit(1).get();
        if (!recreated.empty) {
          throw new Error(
              `清理期間重新出現 ${collection} 文件，禁止刪除店家主樹`,
          );
        }
      }
      const tree = await inspectShopTree(shopRef);
      if (tree.truncated) {
        throw new Error("刪除前店家子集合重新掃描不完整");
      }
      if (text(job.mode) === policy.INACTIVE_CLEANUP_MODE &&
          Number(tree.storeOrderCount || 0) > 0) {
        throw new Error("長期閒置清理偵測到商城訂單，禁止刪除店家樹");
      }
      if (Number(tree.openStoreOrderCount || 0) > 0 ||
          Number(tree.paidStoreOrderCount || 0) > 0 ||
          Number(tree.completedStoreOrderCount || 0) > 0) {
        throw new Error("商城訂單仍有未完成、已完成或實際交易，禁止刪除店家樹");
      }
      await db.recursiveDelete(shopRef);
      await patchJob(jobRef, {
        deletedFirestore: admin.firestore.FieldValue.increment(
            1 + Number(tree.count || 0),
        ),
      });
    }
    await patchJob(jobRef, {phase: "reset_creation_locks"});
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
  for (const uid of (Array.isArray(job.relatedUserIds) ?
    job.relatedUserIds : [])) {
    const pets = await db.collection("user_profiles").doc(text(uid))
        .collection("pets").get();
    for (const pet of pets.docs) {
      const answer = await pet.ref.collection("shop_form_answers")
          .doc(shopId).get();
      if (answer.exists) {
        residual.push(`user_profiles/${text(uid)}/pets/${pet.id}/shop_form_answers/${shopId}`);
      }
    }
  }
  for (const collection of ["bookings", "payments"]) {
    const snapshot = await db.collection(collection)
        .where("shopId", "==", shopId).limit(1).get();
    if (!snapshot.empty) residual.push(`${collection} 尚有可清理文件`);
  }
  for (const collection of ["users", "user_profiles"]) {
    const snapshot = await db.collection(collection)
        .where("shopIds", "array-contains", shopId).limit(1).get();
    if (!snapshot.empty) {
      residual.push(`${collection}.shopIds 尚有店家關聯`);
    }
  }
  for (const prefix of EXECUTABLE_DIRECT_STORAGE_PREFIXES) {
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
async function assertShopStillDeletable(shopId) {
  const db = admin.firestore();
  const shopSnap = await db.collection("shops").doc(shopId).get();
  if (!shopSnap.exists) return;
  const transactions = await inspectTransactionsV2(db, shopId, "recheck");
  const tree = await inspectShopTree(shopSnap.ref);
  if (!transactions.complete || tree.truncated) {
    throw new HttpsError(
        "failed-precondition",
        "刪除前重新檢查交易或店家子集合未完成，已停止清理。",
    );
  }
  transactions.storeOrderCount = tree.storeOrderCount;
  transactions.openStoreOrderCount = tree.openStoreOrderCount;
  transactions.paidStoreOrderCount = tree.paidStoreOrderCount;
  transactions.completedStoreOrderCount = tree.completedStoreOrderCount;
  const commercial = await db.collection("shop_commercial").doc(shopId).get();
  if (commercial.exists &&
      policy.hasRealCommercialObligation(commercial.data())) {
    transactions.realCommercialCount = 1;
  }
  const eligibility = policy.deletionEligibility(Object.assign(
      {},
      transactions,
      {scanComplete: true},
  ));
  if (!eligibility.allowed) {
    throw new HttpsError(
        "failed-precondition",
        eligibility.blockers.join("；"),
        {blockers: eligibility.blockers},
    );
  }
}

async function runJobHandler(request) {
  const operator = await requireSuperAdmin(request);
  if (!SAFE_CLEANUP_EXECUTION_ENABLED) {
    throw new HttpsError(
        "failed-precondition",
        "安全清理執行功能目前已關閉。",
        {executionEnabled: false},
    );
  }
  const jobId = text((request.data || {}).jobId);
  if (!jobId) throw new HttpsError("invalid-argument", "缺少刪除工作 ID。");
  const jobRef = admin.firestore().collection(JOB_COLLECTION).doc(jobId);
  const snapshot = await jobRef.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "找不到刪除工作。");
  const job = snapshot.data() || {};
  if (text(job.operatorUid) !== operator.uid) {
    throw new HttpsError("permission-denied", "只能由建立此工作的最高管理員執行。");
  }
  if (Number(job.emailAuthorizedUntil || 0) < Date.now()) {
    throw new HttpsError(
        "failed-precondition",
        "Email 驗證授權已逾時，請重新申請驗證碼後再執行。",
    );
  }
  if (Number(job.previewContractVersion || 0) < PREVIEW_CONTRACT_VERSION ||
      !text(job.previewScanId)) {
    throw new HttpsError(
        "failed-precondition",
        "刪除工作缺少目前版本的可信預覽憑證，禁止執行。",
    );
  }
  if (![policy.TEST_RESET_MODE, policy.INACTIVE_CLEANUP_MODE]
      .includes(text(job.mode))) {
    throw new HttpsError(
        "failed-precondition",
        "正式永久刪除尚未開放執行。",
    );
  }
  const shopId = text(job.shopId);
  const [lock, shop] = await Promise.all([
    admin.firestore().collection(LOCK_COLLECTION).doc(shopId).get(),
    admin.firestore().collection("shops").doc(shopId).get(),
  ]);
  if (!lock.exists || text(lock.get("jobId")) !== jobId) {
    throw new HttpsError(
        "failed-precondition",
        "店家清理鎖與工作不一致，禁止執行。",
    );
  }
  if (shop.exists &&
      (text(shop.get("deletionState")) !== "deleting" ||
       text(shop.get("deletionJobId")) !== jobId)) {
    throw new HttpsError(
        "failed-precondition",
        "店家未處於這個工作的安全清理狀態。",
    );
  }
  if (text(job.status) === "completed") return sanitizeJob(snapshot);
  if (shop.exists) await assertShopStillDeletable(shopId);
  const leaseToken = crypto.randomUUID();
  let completedWhileAcquiring = false;
  await admin.firestore().runTransaction(async (tx) => {
    const fresh = await tx.get(jobRef);
    if (!fresh.exists) {
      throw new HttpsError("not-found", "找不到刪除工作。");
    }
    if (![policy.TEST_RESET_MODE, policy.INACTIVE_CLEANUP_MODE]
        .includes(text(fresh.get("mode")))) {
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
    deletedStorageBytes: Number(data.deletedStorageBytes || 0),
    updatedAccountLinks: Number(data.updatedAccountLinks || 0),
    expectedDeleteFirestore: Number(data.expectedDeleteFirestore || 0),
    expectedDeleteStorage: Number(data.expectedDeleteStorage || 0),
    expectedDeleteStorageBytes:
      Number(data.expectedDeleteStorageBytes || 0),
    failedCount: Number(data.failedCount || 0),
    retainedCount: Number(data.retainedCount || 0),
    retainedItems: Array.isArray(data.retainedItems) ?
      data.retainedItems.slice(0, 100).map((row) => ({
        source: text(row.source),
        count: Number(row.count || 0),
        reason: text(row.reason),
      })) : [],
    lastError: text(data.lastError),
    previewScanId: text(data.previewScanId),
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
  const operator = await requireSuperAdmin(request);
  const jobId = text((request.data || {}).jobId);
  if (!jobId) throw new HttpsError("invalid-argument", "缺少工作 ID。");
  const job = await admin.firestore().collection(JOB_COLLECTION).doc(jobId)
      .get();
  if (!job.exists) throw new HttpsError("not-found", "找不到刪除工作。");
  if (text(job.get("operatorUid")) !== operator.uid) {
    throw new HttpsError("permission-denied", "只能由建立此工作的最高管理員驗證。");
  }
  if (Number(job.get("emailAuthorizedUntil") || 0) < Date.now()) {
    throw new HttpsError(
        "failed-precondition",
        "Email 驗證授權已逾時，請重新申請驗證碼後再執行。",
    );
  }
  return verifyDeletion(jobId, job.data());
}

const callableOptions = {
  region: REGION,
  timeoutSeconds: 540,
  memory: "1GiB",
};

exports.previewShopDeletion = onCall(callableOptions, previewHandler);
exports.requestShopDeletionEmailCode = onCall(
    Object.assign({}, callableOptions, {
      secrets: [smtpHost, smtpFrom, smtpUser, smtpPass],
    }),
    requestEmailCodeHandler,
);
exports.createShopDeletionJob = onCall(callableOptions, createJobHandler);
exports.runShopDeletionBatch = onCall(callableOptions, runJobHandler);
exports.getShopDeletionJob = onCall(callableOptions, getJobHandler);
exports.verifyShopDeletion = onCall(callableOptions, verifyHandler);

exports._test = {
  requireSuperAdmin,
  combineStatuses,
  withTimeout,
  scanQuery,
  storageReferences,
  publicScanError,
  inspectTopLevelCollections,
  inspectTopLevelCollectionsV2,
  inspectShopTree,
  inspectStorageV2,
  deleteStoragePage,
  inspectTransactionBlockers,
  buildPreview,
  verifyDeletion,
  sanitizeJob,
  previewHandler,
  requestEmailCodeHandler,
  consumeEmailChallenge,
  createJobHandler,
  setDeletionEmailSender(sender) {
    deliverDeletionEmail = sender;
  },
  runJobHandler,
  getJobHandler,
  verifyHandler,
};
