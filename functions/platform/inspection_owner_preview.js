"use strict";
const admin = require("firebase-admin");
const {randomBytes} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {METHOD} = require("./inspection_email_auth");
const ROOT = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
const IDLE = 30 * 60 * 1000;
/**
 * Bind a fresh anonymous identity to an audited root inspection session.
 * Never mint or share an owner's login token or modify the owner's account.
 * @param {Object} args Root-validated grant arguments.
 * @return {Promise<Object>} Non-secret preview grant metadata.
 */
async function issueOwnerPreview({db, data, sessionRef, shopId, shop}) {
  const rollout = await db.doc("platform_inspection_rollout/current").get();
  if (!rollout.exists || rollout.get("writeGuardsVerified") !== true) {
    throw new HttpsError("failed-precondition",
        "完整唯讀權限尚未驗證啟用，無法發放後台查核身分");
  }
  const target = await admin.auth()
      .verifyIdToken(String(data.previewIdToken || ""));
  if ((target.firebase || {}).sign_in_provider !== "anonymous" ||
      target.uid === ROOT || target.petnestInspection === true ||
      !Number.isFinite(target.auth_time) ||
      target.auth_time * 1000 < Date.now() - 120000) {
    throw new HttpsError("permission-denied", "必須使用本次獨立視窗的新查核身分");
  }
  const id = randomBytes(24).toString("hex");
  const ownerUid = String(shop.get("ownerUid") || "");
  if (!ownerUid) throw new HttpsError("failed-precondition", "店家缺少店主識別碼");
  const account = await admin.auth().getUser(target.uid);
  const createdAt = Date.parse(account.metadata.creationTime);
  if (account.providerData.length !== 0 || !Number.isFinite(createdAt) ||
      createdAt < Date.now() - 120000) {
    throw new HttpsError("permission-denied", "查核身分必須為本次新建立");
  }
  const allowedUserUids = new Set([ownerUid]);
  const members = await db.collection("shops").doc(shopId)
      .collection("members").select("uid", "userId", "customerUid").get();
  for (const member of members.docs) {
    const value = member.data();
    for (const uid of [member.id, value.uid, value.userId, value.customerUid]) {
      if (typeof uid === "string" && uid && !uid.includes("/")) {
        allowedUserUids.add(uid);
      }
    }
  }
  if (allowedUserUids.size > 10000) {
    throw new HttpsError("resource-exhausted", "關聯會員過多，需分批查核");
  }
  const ref = db.collection("platform_inspection_previews").doc(id);
  await ref.set({uid: target.uid, rootUid: ROOT, shopId, ownerUid,
    allowedUserUids: [...allowedUserUids],
    parentSession: sessionRef.id, active: true,
    createdAt: Date.now(), expiresAt: Date.now() + 8 * 60 * 60 * 1000});
  try {
    await admin.auth().setCustomUserClaims(target.uid,
        {petnestInspection: true, inspectionGrant: id});
  } catch (error) {
    await ref.update({active: false});
    throw error;
  }
  return {grantId: id, shopId, ownerUid};
}
/** Validate grant and parent root session on each preview heartbeat. */
const inspectionPreviewHeartbeat = onCall({region: "asia-east1"},
    async (request) => {
      const claims = (request.auth && request.auth.token) || {};
      if (claims.petnestInspection !== true ||
      !/^[a-f0-9]{48}$/.test(String(claims.inspectionGrant || ""))) {
        throw new HttpsError("permission-denied", "不是唯讀查核身分");
      }
      const db = admin.firestore();
      return db.runTransaction(async (tx) => {
        const grantRef = db.collection("platform_inspection_previews")
            .doc(claims.inspectionGrant);
        const grantSnap = await tx.get(grantRef);
        const grant = grantSnap.data();
        if (!grant || grant.uid !== request.auth.uid ||
            grant.rootUid !== ROOT ||
        grant.active !== true || grant.expiresAt <= Date.now()) {
          throw new HttpsError("unauthenticated", "查核已鎖定");
        }
        const sessionRef = db.collection("platform_inspection_sessions")
            .doc(grant.parentSession);
        const sessionSnap = await tx.get(sessionRef);
        const session = sessionSnap.data();
        if (!session || session.uid !== ROOT ||
            session.verification !== METHOD ||
        Date.now() - session.touchedAt >= IDLE) {
          throw new HttpsError("unauthenticated", "查核已鎖定");
        }
        if ((request.data || {}).end === true) {
          tx.update(grantRef, {active: false});
        } else {
          tx.update(sessionRef, {touchedAt: Date.now()});
        }
        return {active: (request.data || {}).end !== true, shopId: grant.shopId,
          ownerUid: grant.ownerUid};
      });
    });
module.exports = {issueOwnerPreview, inspectionPreviewHeartbeat};
