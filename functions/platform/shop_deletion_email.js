// 檔案名稱：functions/platform/shop_deletion_email.js
// 功能說明：店家清理 Email 六位數驗證碼的產生、雜湊、期限與嘗試次數規則。

"use strict";

const crypto = require("crypto");

const EMAIL_CODE_TTL_MS = 5 * 60 * 1000;
const EMAIL_CODE_MAX_ATTEMPTS = 5;
const EMAIL_RESEND_COOLDOWN_MS = 60 * 1000;
const EMAIL_MAX_SENDS_PER_HOUR = 5;
const EMAIL_AUTHORIZATION_MS = 30 * 60 * 1000;

/**
 * @return {string} 六位數驗證碼
 */
function generateCode() {
  return crypto.randomInt(0, 1000000).toString().padStart(6, "0");
}

/**
 * @return {string} 每次驗證碼獨立使用的鹽值
 */
function generateSalt() {
  return crypto.randomBytes(16).toString("hex");
}

/**
 * @param {string} code 明文驗證碼
 * @param {string} salt 鹽值
 * @return {Promise<string>}
 */
function hashCode(code, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(String(code), String(salt), 32, (error, key) => {
      if (error) reject(error);
      else resolve(key.toString("hex"));
    });
  });
}

/**
 * @param {string} actual 計算後的雜湊
 * @param {string} expected 已儲存雜湊
 * @return {boolean}
 */
function hashesMatch(actual, expected) {
  const left = Buffer.from(String(actual), "hex");
  const right = Buffer.from(String(expected), "hex");
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

/**
 * @param {number} lastSentMillis 上次寄送時間
 * @param {number[]} recentSends 一小時內寄送時間
 * @param {number} now 目前時間
 * @return {string}
 */
function resendBlocker(lastSentMillis, recentSends, now) {
  if (Number(lastSentMillis || 0) > 0 &&
      now - Number(lastSentMillis) < EMAIL_RESEND_COOLDOWN_MS) {
    return "驗證碼寄送過於頻繁，請稍後再試。";
  }
  const recent = (recentSends || [])
      .map(Number)
      .filter((value) => now - value < 60 * 60 * 1000);
  if (recent.length >= EMAIL_MAX_SENDS_PER_HOUR) {
    return "一小時內驗證碼申請次數已達上限。";
  }
  return "";
}

/**
 * @param {Object} challenge 驗證挑戰
 * @param {Object} attempt 本次輸入
 * @param {number} now 目前時間
 * @return {{ok: boolean, message: string, incrementAttempt: boolean}}
 */
function evaluateChallenge(challenge, attempt, now) {
  const record = challenge || {};
  const input = attempt || {};
  if (record.revoked === true || record.used === true) {
    return {ok: false, message: "驗證碼已失效，請重新申請。", incrementAttempt: false};
  }
  if (Number(record.expiresAtMillis || 0) < now) {
    return {ok: false, message: "驗證碼已過期，請重新申請。", incrementAttempt: false};
  }
  if (Number(record.attempts || 0) >= EMAIL_CODE_MAX_ATTEMPTS) {
    return {ok: false, message: "驗證碼錯誤次數過多，請重新申請。", incrementAttempt: false};
  }
  const sameIntent = record.uid === input.uid &&
    record.shopId === input.shopId &&
    record.mode === input.mode &&
    record.scanId === input.scanId;
  if (!sameIntent || input.codeMatches !== true) {
    const remaining = EMAIL_CODE_MAX_ATTEMPTS - Number(record.attempts || 0) - 1;
    return {
      ok: false,
      message: remaining > 0 ?
        `驗證碼不正確，尚可再試 ${remaining} 次。` :
        "驗證碼錯誤次數過多，請重新申請。",
      incrementAttempt: true,
    };
  }
  return {ok: true, message: "", incrementAttempt: false};
}

/**
 * @param {string} email 已驗證 Email
 * @return {string}
 */
function maskEmail(email) {
  const value = String(email || "");
  const at = value.indexOf("@");
  if (at <= 0) return "";
  return `${value.slice(0, 1)}***${value.slice(at)}`;
}

/**
 * 只描述信箱形狀。超過一個 @ 時不遮罩，避免把重複貼上的後半段寫進日誌。
 * @param {string} email SMTP 帳號
 * @return {{singleMailbox: boolean, atCount: number, masked: string}}
 */
function describeMailbox(email) {
  const value = String(email || "").trim();
  const parts = value.split("@");
  const atCount = Math.max(0, parts.length - 1);
  if (atCount !== 1 || !parts[0] || !parts[1] || /\s/.test(value)) {
    return {singleMailbox: false, atCount, masked: ""};
  }
  return {
    singleMailbox: true,
    atCount: 1,
    masked: `${parts[0].slice(0, 1)}***@${parts[1]}`,
  };
}

/**
 * SMTP 失敗的安全診斷。不複製 response、message、密碼或驗證碼。
 * @param {Object} error 寄信錯誤
 * @param {Object} config 已載入的 SMTP 形狀
 * @return {Object}
 */
function smtpAuthFailureLog(error, config) {
  const failure = error || {};
  const settings = config || {};
  const responseCode = Number(failure.responseCode) || 0;
  const smtpCode = String(failure.code || "");
  let category = "smtp-rejected";
  if (responseCode === 535) category = "credentials-rejected";
  else if (responseCode === 534) category = "app-password-required";
  else if (smtpCode === "EAUTH") category = "auth-rejected";
  const mailbox = describeMailbox(settings.user);
  const host = String(settings.host || "").trim();
  const command = String(failure.command || "").slice(0, 32);
  return {
    smtpCode,
    responseCode,
    command,
    category,
    secretsLoaded: settings.secretsLoaded === true,
    configComplete: settings.configComplete === true,
    host: /^[a-z0-9.-]+$/i.test(host) ? host : "unexpected-characters",
    port: Number(settings.port) || 0,
    secure: settings.secure === true,
    singleMailbox: mailbox.singleMailbox,
    mailboxAtCount: mailbox.atCount,
    mailboxMasked: mailbox.masked,
  };
}

module.exports = {
  EMAIL_CODE_TTL_MS,
  EMAIL_CODE_MAX_ATTEMPTS,
  EMAIL_RESEND_COOLDOWN_MS,
  EMAIL_MAX_SENDS_PER_HOUR,
  EMAIL_AUTHORIZATION_MS,
  generateCode,
  generateSalt,
  hashCode,
  hashesMatch,
  resendBlocker,
  evaluateChallenge,
  maskEmail,
  describeMailbox,
  smtpAuthFailureLog,
};
