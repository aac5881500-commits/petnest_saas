"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const email = require("./shop_deletion_email");

test("驗證碼為六位數字且雜湊不可還原明文", async () => {
  const code = email.generateCode();
  assert.match(code, /^\d{6}$/);
  const salt = email.generateSalt();
  const hash = await email.hashCode(code, salt);
  assert.notEqual(hash, code);
  assert.equal(email.hashesMatch(hash, await email.hashCode(code, salt)), true);
  assert.equal(
      email.hashesMatch(hash, await email.hashCode("000000", salt)),
      code === "000000",
  );
});

test("驗證碼過期、錯誤次數與重送限制", () => {
  const now = 1_000_000;
  const challenge = {
    uid: "admin",
    shopId: "SHOP1",
    mode: "test_reset",
    scanId: "scan-1",
    attempts: 0,
    expiresAtMillis: now + 1000,
  };
  const attempt = {
    uid: "admin",
    shopId: "SHOP1",
    mode: "test_reset",
    scanId: "scan-1",
    codeMatches: true,
  };
  assert.equal(email.evaluateChallenge(challenge, attempt, now).ok, true);
  assert.equal(
      email.evaluateChallenge(
          challenge,
          Object.assign({}, attempt, {codeMatches: false}),
          now,
      ).incrementAttempt,
      true,
  );
  assert.match(
      email.evaluateChallenge(
          Object.assign({}, challenge, {expiresAtMillis: now - 1}),
          attempt,
          now,
      ).message,
      /過期/,
  );
  assert.match(
      email.evaluateChallenge(
          Object.assign({}, challenge, {attempts: 5}),
          attempt,
          now,
      ).message,
      /錯誤次數/,
  );
  assert.match(
      email.evaluateChallenge(
          challenge,
          Object.assign({}, attempt, {shopId: "SHOP2"}),
          now,
      ).message,
      /不正確/,
  );
  assert.match(email.resendBlocker(now - 1000, [], now), /頻繁/);
  assert.equal(email.resendBlocker(now - 61_000, [], now), "");
  assert.match(
      email.resendBlocker(0, [now, now, now, now, now], now),
      /上限/,
  );
});

test("已使用或已撤銷的驗證碼不能再次通過", () => {
  const challenge = {
    uid: "admin",
    shopId: "SHOP1",
    mode: "inactive_cleanup",
    scanId: "scan-1",
    used: true,
    expiresAtMillis: Date.now() + 1000,
  };
  const result = email.evaluateChallenge(challenge, {
    uid: "admin",
    shopId: "SHOP1",
    mode: "inactive_cleanup",
    scanId: "scan-1",
    codeMatches: true,
  }, Date.now());
  assert.equal(result.ok, false);
  assert.equal(result.incrementAttempt, false);
});

test("SMTP 驗證失敗只記錄代碼與信箱形狀", () => {
  const mailbox = "a@example.com";
  const repeated = mailbox + mailbox + mailbox;
  const password = "abcdefghijklmnop";
  const verificationCode = "123456";
  const log = email.smtpAuthFailureLog({
    code: "EAUTH",
    responseCode: 535,
    command: "AUTH PLAIN",
    response: `535 5.7.8 Username and Password not accepted ${password}`,
    message: `Authentication failed ${verificationCode} ${password}`,
  }, {
    secretsLoaded: true,
    configComplete: true,
    host: "smtp.gmail.com",
    port: 587,
    secure: false,
    user: repeated,
  });
  assert.equal(log.smtpCode, "EAUTH");
  assert.equal(log.responseCode, 535);
  assert.equal(log.command, "AUTH PLAIN");
  assert.equal(log.category, "credentials-rejected");
  assert.equal(log.secretsLoaded, true);
  assert.equal(log.configComplete, true);
  assert.equal(log.host, "smtp.gmail.com");
  assert.equal(log.port, 587);
  assert.equal(log.secure, false);
  assert.equal(log.singleMailbox, false);
  assert.equal(log.mailboxAtCount, 3);
  assert.equal(log.mailboxMasked, "");
  const serialized = JSON.stringify(log);
  assert.equal(serialized.includes(password), false);
  assert.equal(serialized.includes(verificationCode), false);
  assert.equal(serialized.includes(repeated), false);
  assert.equal(email.smtpAuthFailureLog({
    code: "EAUTH",
    responseCode: 534,
    command: "AUTH",
  }, {
    secretsLoaded: true,
    configComplete: true,
    host: "smtp.gmail.com",
    port: 587,
    secure: false,
    user: mailbox,
  }).category, "app-password-required");
  assert.deepEqual(email.describeMailbox(mailbox), {
    singleMailbox: true,
    atCount: 1,
    masked: "a***@example.com",
  });
});
