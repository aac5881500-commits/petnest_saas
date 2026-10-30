"use strict";
const {randomBytes, createHash} = require("node:crypto");
const email = require("./shop_deletion_email");
const METHOD = "email_code_v1";
/**
 * Construct an injectable email gate. No business data is written here.
 * @param {Object} deps Trusted Firebase, delivery and error dependencies.
 * @return {Function} Handler for send_code/verify_code.
 */
function createInspectionEmailGate({admin, send, HttpsError,
  root, now = Date.now}) {
  return async (request) => {
    if (!request.auth || request.auth.uid !== root) {
      throw new HttpsError("permission-denied", "僅最高權限帳號可查核");
    }
    const data = request.data || {};
    const action = data.action;
    const authTime = Number(request.auth.token.auth_time) * 1000;
    if (!Number.isFinite(authTime)) {
      throw new HttpsError("unauthenticated", "登入狀態無效，請重新開啟 APP。");
    }
    const account = await admin.auth().getUser(root);
    if (account.disabled || account.emailVerified !== true || !account.email) {
      throw new HttpsError("failed-precondition", "最高權限帳號需有已驗證 Email。");
    }
    const mailbox = account.email.trim().toLowerCase();
    const db = admin.firestore();
    const challengeRef = db.collection("platform_inspection_email_codes")
        .doc(root);
    const limitRef = db.collection("platform_inspection_email_limits")
        .doc(root);
    const logs = db.collection("platform_inspection_logs");
    if (action === "send_code") {
      const time = now();
      const code = email.generateCode();
      const salt = email.generateSalt();
      const codeHash = await email.hashCode(code, salt);
      const id = randomBytes(16).toString("hex");
      await db.runTransaction(async (tx) => {
        const limit = (await tx.get(limitRef)).data() || {};
        const recent = (limit.recent || []).filter((t) =>
          time - t < 60 * 60 * 1000);
        const blocked = email.resendBlocker(limit.lastSentAt, recent, time);
        if (blocked) throw new HttpsError("resource-exhausted", blocked);
        tx.set(limitRef, {lastSentAt: time, recent: [...recent, time]});
        tx.set(challengeRef, {id, uid: root, email: mailbox, authTime,
          salt, codeHash, attempts: 0, used: false, revoked: false,
          delivered: false, expiresAtMillis: time + email.EMAIL_CODE_TTL_MS});
      });
      try {
        await send({to: mailbox, subject: "PetNest 唯讀查核驗證碼",
          text: `你的店家唯讀查核驗證碼：${code}\n` +
            "5 分鐘內有效，僅能使用一次。\n" +
            "驗證後可跨店查閱，閒置 30 分鐘後鎖定。\n" +
            "若不是你本人操作，請勿提供此驗證碼。"});
      } catch (error) {
        await db.runTransaction(async (tx) => {
          const current = await tx.get(challengeRef);
          if (current.get("id") === id) {
            tx.update(challengeRef, {revoked: true});
          }
        });
        if (error.code === "failed-precondition") throw error;
        throw new HttpsError("unavailable", "驗證碼寄送失敗，請稍後再試。");
      }
      await db.runTransaction(async (tx) => {
        const current = await tx.get(challengeRef);
        if (current.get("id") !== id || current.get("revoked") === true) {
          throw new HttpsError("aborted", "驗證碼已被更新，請使用最新一封信。");
        }
        tx.update(challengeRef, {delivered: true});
      });
      await logs.add({uid: root, action: "email_code_sent",
        at: admin.firestore.FieldValue.serverTimestamp()});
      return {challengeId: id, maskedEmail: email.maskEmail(mailbox),
        expiresInSeconds: 300, retryAfterSeconds: 60};
    }
    if (action !== "verify_code" ||
        !/^[a-f0-9]{32}$/.test(String(data.challengeId || "")) ||
        !/^\d{6}$/.test(String(data.code || ""))) {
      throw new HttpsError("invalid-argument", "請輸入 Email 收到的六位數驗證碼。");
    }
    const first = (await challengeRef.get()).data();
    if (!first || first.id !== data.challengeId) {
      throw new HttpsError("failed-precondition", "驗證碼已失效，請重新寄送。");
    }
    const candidate = await email.hashCode(data.code, first.salt);
    const token = randomBytes(32).toString("hex");
    const sessionRef = db.collection("platform_inspection_sessions")
        .doc(createHash("sha256").update(token).digest("hex"));
    const failure = await db.runTransaction(async (tx) => {
      const c = (await tx.get(challengeRef)).data();
      if (!c || c.id !== data.challengeId || c.uid !== root ||
          c.email !== mailbox || c.authTime !== authTime ||
          c.used || c.revoked || !c.delivered) {
        return "驗證碼已失效，請重新寄送。";
      }
      if (c.expiresAtMillis <= now()) return "驗證碼已過期，請重新寄送。";
      if (c.attempts >= email.EMAIL_CODE_MAX_ATTEMPTS) {
        return "驗證碼錯誤次數過多，請重新寄送。";
      }
      if (!email.hashesMatch(candidate, c.codeHash)) {
        // Return rather than throw inside the transaction so attempts commit.
        tx.update(challengeRef, {attempts: c.attempts + 1,
          revoked: c.attempts + 1 >= email.EMAIL_CODE_MAX_ATTEMPTS});
        return "驗證碼不正確，請確認最新一封信。";
      }
      tx.update(challengeRef, {used: true});
      tx.set(sessionRef, {uid: root, authTime, touchedAt: now(),
        verification: METHOD});
      tx.set(logs.doc(), {uid: root, action: "email_code_verified",
        at: admin.firestore.FieldValue.serverTimestamp()});
      return "";
    });
    if (failure) throw new HttpsError("failed-precondition", failure);
    return {token};
  };
}
module.exports = {createInspectionEmailGate, METHOD};
