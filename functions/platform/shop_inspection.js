"use strict";
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {createHash} = require("node:crypto");
const mailer = require("./inspection_mailer");
const {createInspectionEmailGate, METHOD} =
  require("./inspection_email_auth");
const ROOT = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
const TOP = ["bookings", "payments", "daily_care_records",
  "daily_care_photos", "reviews", "action_logs", "shop_members"];
const IDLE = 30 * 60 * 1000;
/**
 * Require the permanent root identity, independent of assigned platform roles.
 * @param {Object} auth Verified callable authentication.
 */
function rootOnly(auth) {
  if (!auth || auth.uid !== ROOT) {
    throw new HttpsError("permission-denied",
        "僅最高權限帳號可查核");
  }
}
/**
 * Check Firestore path segments.
 * @param {string} path Requested path.
 * @return {boolean} Whether the path is safe.
 */
function validPath(path) {
  return typeof path === "string" && path.length < 1500 &&
    path.split("/").every((s) => /^[^/.][^/]*$/.test(s));
}
/**
 * Serialize Firestore values without losing timestamps or reference paths.
 * @param {*} value Stored value.
 * @return {*} JSON-compatible value.
 */
function encode(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value.path && value.firestore) return {reference: value.path};
  if (Array.isArray(value)) return value.map(encode);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, encode(v)]));
  }
  return value;
}
/**
 * Validate the tenant of a document or its descendants.
 * @param {Object} db Admin Firestore.
 * @param {string} path Requested path.
 * @param {string} shopId Selected tenant.
 */
async function scope(db, path, shopId) {
  if (!validPath(path) || !validPath(shopId) ||
      shopId.includes("/")) throw new HttpsError("invalid-argument", "路徑無效");
  const parts = path.split("/");
  if (parts[0] === "shops" && parts[1] === shopId) return;
  if (TOP.includes(parts[0]) && parts.length >= 2) {
    const doc = await db.doc(parts.slice(0, 2).join("/")).get();
    if (doc.exists && doc.get("shopId") === shopId) return;
  }
  throw new HttpsError("permission-denied", "資料不屬於指定店家");
}
const emailGate = createInspectionEmailGate({admin,
  send: mailer.sendInspectionEmail, HttpsError, root: ROOT});
exports.inspectShop = onCall({region: "asia-east1", timeoutSeconds: 120,
  secrets: mailer.secrets},
async (request) => {
  rootOnly(request.auth);
  const db = admin.firestore();
  const data = request.data || {};
  const action = data.action;
  const now = Date.now();
  const authTime = Number(request.auth.token.auth_time) * 1000;
  if (!["send_code", "verify_code", "end", "shops", "read",
    "export", "owner_preview"].includes(action)) {
    throw new HttpsError("invalid-argument",
        "不支援的操作");
  }
  const logs = db.collection("platform_inspection_logs");
  if (action === "send_code" || action === "verify_code") {
    return emailGate(request);
  }
  const token = typeof data.token === "string" ? data.token : "";
  const sessionRef = db.collection("platform_inspection_sessions")
      .doc(createHash("sha256").update(token).digest("hex"));
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    const session = snap.data();
    if (!session || session.verification !== METHOD ||
        session.uid !== request.auth.uid ||
        session.authTime !== authTime || now - session.touchedAt >= IDLE) {
      throw new HttpsError("unauthenticated", "查核已鎖定，請重新驗證");
    }
    if (action === "end") tx.delete(sessionRef);
    else tx.update(sessionRef, {touchedAt: now});
  });
  if (action === "end") return {locked: true};
  if (!["shops", "read",
    "export", "owner_preview"].includes(action)) {
    throw new HttpsError("invalid-argument",
        "不支援的操作");
  }
  const shopId = data.shopId || "";
  const path = data.path || "";
  // Record access before any business data is returned. No business
  // writes exist here.
  await logs.add({uid: ROOT, action, shopId, path,
    customerId: data.customerId || "",
    at: admin.firestore.FieldValue.serverTimestamp()});
  /**
   * Read a bounded page with an explicit continuation cursor.
   * @param {Object} query Scoped query.
   * @return {Promise<Object>} Page and cursor.
   */
  async function page(query) {
    let q = query.orderBy(admin.firestore.FieldPath.documentId());
    if (data.cursor) q = q.startAfter(data.cursor);
    const snap = await q.limit(51).get();
    return {records: snap.docs.slice(0, 50).map((d) => ({path: d.ref.path,
      data: encode(d.data())})),
    next: snap.size > 50 ? snap.docs[49].id : null};
  }
  if (action === "shops") return page(db.collection("shops"));
  await scope(db, `shops/${shopId}`, shopId);
  const shop = await db.doc(`shops/${shopId}`).get();
  if (!shop.exists) throw new HttpsError("not-found", "店家不存在");
  if (action === "owner_preview") {
    return require("./inspection_owner_preview").issueOwnerPreview({
      db, data, sessionRef, shopId, shop});
  }
  if (action === "read") {
    if (TOP.includes(path)) {
      return page(db.collection(path).where("shopId",
          "==", shopId));
    }
    await scope(db, path, shopId);
    if (path.split("/").length % 2 === 1) return page(db.collection(path));
    const doc = await db.doc(path).get();
    return {records: doc.exists ? [{path, data: encode(doc.data())}] : [],
      collections: (await doc.ref.listCollections()).map((c) => c.path)};
  }
  const customerId = String(data.customerId || "").trim();
  if (!customerId ||
      customerId.includes("/")) {
    throw new HttpsError("invalid-argument",
        "請選擇客戶識別碼");
  }
  const identities = new Set([customerId]);
  const memberRef = db.collection(`shops/${shopId}/members`);
  const member = await memberRef.doc(customerId).get();
  if (member.exists) {
    for (const key of ["userId", "uid", "memberId", "customerUid"]) {
      if (typeof member.get(key) === "string" &&
          member.get(key)) identities.add(member.get(key));
    }
  }
  const linked = await memberRef.where("userId", "==",
      customerId).limit(20).get();
  for (const doc of linked.docs) identities.add(doc.id);
  const records = [];
  const visited = new Set();
  const incomplete = linked.size > 20 ? [memberRef.path] : [];
  let scanned = 0;
  const deadline = Date.now() + 80000;
  const keys = ["userId", "uid", "memberId", "customerId", "customerUid",
    "userUid"];
  /**
   * Match known customer identities.
   * @param {Object} doc Snapshot.
   * @return {boolean} Whether it belongs to the selected customer.
   */
  function matches(doc) {
    const v = doc.data();
    return identities.has(doc.id) || keys.some((k) => identities.has(v[k]));
  }
  /**
   * Traverse a bounded evidence tree without updating business documents.
   * @param {Object} ref Collection or query.
   * @param {boolean} inherited Parent belongs to the selected customer.
   * @param {number} depth Current depth.
   * @param {string} sourcePath Source for incomplete coverage reporting.
   */
  async function visit(ref, inherited, depth, sourcePath = ref.path) {
    if (Date.now() >= deadline || depth > 6 || scanned >= 2000 ||
        records.length >= 1000) {
      incomplete.push(sourcePath); return;
    }
    const snap = await ref.orderBy(admin.firestore.FieldPath.documentId())
        .limit(201).get();
    if (snap.size > 200) incomplete.push(sourcePath);
    for (const doc of snap.docs.slice(0, 200)) {
      if (Date.now() >= deadline || ++scanned > 2000 ||
          records.length >= 1000) {
        incomplete.push(sourcePath); break;
      }
      if (TOP.includes(sourcePath) && doc.get("shopId") !== shopId) {
        continue;
      }
      if (visited.has(doc.ref.path)) continue;
      visited.add(doc.ref.path);
      const included = inherited || matches(doc);
      if (included) {
        records.push({path: doc.ref.path,
          data: encode(doc.data())});
      }
      // Never include unrelated customers; descend only through collection
      // containers or matching records.
      if (included || sourcePath.startsWith(`shops/${shopId}/`)) {
        for (const child of await doc.ref.listCollections()) {
          await visit(child, included, depth + 1);
        }
      }
    }
  }
  // Query customer identities directly, so a busy store's unrelated early
  // orders cannot hide the selected customer's later transactions.
  const customerCollections = new Set([
    "members", "chat_threads", "store_orders", "member_points",
    "member_point_logs", "member_coupons", "point_redemptions",
    "service_requests",
  ]);
  const collections = await shop.ref.listCollections();
  const targets = collections.filter((ref) =>
    customerCollections.has(ref.path.split("/").pop()));
  for (const ref of targets.concat(TOP.map((n) => db.collection(n)))) {
    for (const identity of identities) {
      if (!TOP.includes(ref.path)) {
        const direct = await ref.doc(identity).get();
        if (direct.exists && !visited.has(direct.ref.path)) {
          visited.add(direct.ref.path);
          records.push({path: direct.ref.path,
            data: encode(direct.data())});
          for (const child of await direct.ref.listCollections()) {
            await visit(child, true, 1);
          }
        }
      }
      for (const key of keys) {
        if (Date.now() >= deadline || scanned >= 2000 ||
                records.length >= 1000) {
          incomplete.push(ref.path);
          break;
        }
        await visit(ref.where(key, "==", identity), false, 0, ref.path);
      }
    }
  }
  for (const ref of collections) {
    if (!customerCollections.has(ref.path.split("/").pop())) {
      await visit(ref, false, 0);
    }
  }
  const report = {shopId, customerId, matchedIdentities: [...identities],
    generatedAt: new Date().toISOString(), records,
    complete: incomplete.length === 0, incomplete: [...new Set(incomplete)],
    coverage: "店家子集合及訂單、付款、照護、評價、操作紀錄、店家人員；" +
          "僅現存資料，附件保留原始連結。" +
          "每集合最多200筆，總掃描2000筆、匯出1000筆。"};
  if (Buffer.byteLength(JSON.stringify(report)) > 8 * 1024 * 1024) {
    throw new HttpsError("resource-exhausted", "資料量過大，請分批查閱");
  }
  report.summary = {};
  for (const record of records) {
    const parts = record.path.split("/");
    const group = parts[0] === "shops" ? parts[2] : parts[0];
    report.summary[group] = (report.summary[group] || 0) + 1;
  }
  report.sha256 = createHash("sha256")
      .update(JSON.stringify(report)).digest("hex");
  await logs.add({uid: ROOT, action: "export_completed", shopId,
    customerId, count: records.length, complete: report.complete,
    sha256: report.sha256,
    at: admin.firestore.FieldValue.serverTimestamp()});
  return report;
});
exports._policy = {rootOnly, validPath, encode};
