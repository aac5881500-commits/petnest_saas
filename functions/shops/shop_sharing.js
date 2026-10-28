"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {ROOT_ADMIN_UID} = require("../legal_pet/access");

const options = {region: "asia-east1"};
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const normalizeCode = (value) => String(value || "").trim().toUpperCase();
/**
 * @param {string} value Search code
 * @return {boolean} Whether the code is allowed
 */
function validCode(value) {
  return /^[A-Z0-9][A-Z0-9_-]{7,31}$/.test(value) && !/^SHOP\d+$/i.test(value);
}
/**
 * @param {Object} shop Shop document
 * @param {Object|undefined} member Staff membership
 * @param {string} uid Actor
 * @return {boolean} Whether sharing settings may be managed
 */
function canManage(shop, member, uid) {
  return uid === ROOT_ADMIN_UID || shop.ownerUid === uid ||
    (member && (member.role === "owner" ||
      (member.permissions || {}).edit_business_info === true));
}
/**
 * @param {Object} request Callable request
 * @return {string} Authenticated actor
 */
function requireAuth(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "請先登入再使用店家分享入口");
  return request.auth.uid;
}
/**
 * @param {unknown} value Shop ID
 * @return {string} Valid document ID
 */
function documentId(value) {
  if (typeof value !== "string" || !value ||
      value.length > 128 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "店家資料不正確");
  }
  return value;
}

// Sharing secrets and the lookup index are server-only.
exports.manageShopSharing = onCall(options, async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};
  const shopId = documentId(data.shopId);
  const action = data.action || "get";
  if (!["get", "save", "rotate", "disable"].includes(action)) {
    throw new HttpsError("invalid-argument", "不支援的操作");
  }
  const db = admin.firestore();
  return db.runTransaction(async (tx) => {
    const shopRef = db.doc(`shops/${shopId}`);
    const configRef = db.doc(`shop_sharing/${shopId}`);
    const [shopSnap, memberSnap, configSnap] = await Promise.all([
      tx.get(shopRef),
      tx.get(db.doc(`shop_members/${shopId}_${uid}`)),
      tx.get(configRef),
    ]);
    const shop = shopSnap.data();
    if (!shop || !canManage(shop, memberSnap.data(), uid)) {
      throw new HttpsError("permission-denied", "需要修改營業資訊的權限");
    }
    const old = configSnap.data() || {};
    if (action === "get") {
      return {enabled: old.enabled === true,
        searchCode: old.searchCode || "", qrToken: old.qrToken || ""};
    }
    const searchCode = action === "save" ?
      normalizeCode(data.searchCode) : old.searchCode || "";
    if (action === "save" && searchCode && !validCode(searchCode)) {
      throw new HttpsError("invalid-argument",
          "搜尋碼需為 8–32 位英文字母、數字、底線或連字號，不能使用平台流水號");
    }
    const enabled = action !== "disable";
    const qrToken = action === "rotate" || !old.enabled || !old.qrToken ?
      crypto.randomBytes(24).toString("hex") : old.qrToken;
    const keys = new Set(
        [old.searchCode, old.qrToken, searchCode, qrToken].filter(Boolean));
    const docs = new Map();
    for (const key of keys) {
      docs.set(key, await tx.get(db.doc(`shop_share_keys/${hash(key)}`)));
    }
    for (const key of [searchCode, qrToken].filter(Boolean)) {
      const existing = docs.get(key).data();
      if (enabled && existing && existing.shopId !== shopId) {
        throw new HttpsError("already-exists", "這組搜尋碼已被使用，請換一組");
      }
    }
    for (const key of [old.searchCode, old.qrToken].filter(Boolean)) {
      if ((docs.get(key).data() || {}).shopId === shopId) {
        tx.delete(db.doc(`shop_share_keys/${hash(key)}`));
      }
    }
    const version = (old.version || 0) + 1;
    if (enabled) {
      for (const key of [searchCode, qrToken].filter(Boolean)) {
        tx.set(db.doc(`shop_share_keys/${hash(key)}`), {shopId, version});
      }
    }
    tx.set(configRef, {enabled, searchCode, qrToken, version,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    return {enabled, searchCode, qrToken};
  });
});

exports.resolveShopSharing = onCall(options, async (request) => {
  const uid = requireAuth(request);
  const raw = String((request.data || {}).code || "").trim();
  const code = /^[a-f0-9]{48}$/.test(raw) ? raw : normalizeCode(raw);
  const db = admin.firestore();
  // Count failures as well as successes, per account and per network address.
  const identities = [
    "uid:" + uid, "ip:" + (request.rawRequest.ip || "unknown"),
  ];
  await db.runTransaction(async (tx) => {
    const now = Date.now();
    const refs = identities.map(
        (id) => db.doc(`shop_share_limits/${hash(id)}`));
    const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
    snaps.forEach((snap, index) => {
      const old = snap.data() || {};
      const fresh = !old.startedAt || now - old.startedAt >= 600000;
      const count = fresh ? 0 : old.count || 0;
      if (count >= (index === 0 ? 15 : 60)) {
        throw new HttpsError("resource-exhausted",
            "嘗試次數過多，請於 10 分鐘後再試");
      }
      tx.set(refs[index], {
        startedAt: fresh ? now : old.startedAt, count: count + 1,
        expiresAt: admin.firestore.Timestamp.fromMillis(now + 600000)});
    });
  });
  if (code.length > 128 || !code) {
    throw new HttpsError("not-found", "搜尋碼不存在或已失效");
  }
  return db.runTransaction(async (tx) => {
    const key = await tx.get(db.doc(`shop_share_keys/${hash(code)}`));
    const target = key.data();
    if (!target) throw new HttpsError("not-found", "搜尋碼不存在或已失效");
    const [configSnap, shopSnap] = await Promise.all([
      tx.get(db.doc(`shop_sharing/${target.shopId}`)),
      tx.get(db.doc(`shops/${target.shopId}`)),
    ]);
    const config = configSnap.data();
    if (!config || !config.enabled || config.version !== target.version ||
        !shopSnap.exists ||
        shopSnap.data().deletionState === "deleting") {
      throw new HttpsError("not-found", "搜尋碼不存在或已失效");
    }
    tx.set(db.doc(`shop_share_access/${target.shopId}/users/${uid}`), {
      version: config.version,
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000),
    });
    return {shopId: target.shopId};
  });
});

exports.policy = {normalizeCode, validCode, canManage};
