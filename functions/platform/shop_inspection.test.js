"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const ROOT = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
/** @return {Object} Isolated in-memory callable fixture. */
function fixture() {
  const rows = new Map([["shops/s1", {name: "Store"}], ["bookings/b1", {shopId: "s1", userId: "u1"}], ["bookings/b2", {shopId: "s2", userId: "u1"}], ["shops/s1/members/u1", {userId: "u1"}], ["shops/s1/chat_threads/u1", {customerUid: "u1"}], ["shops/s1/chat_threads/u1/messages/m1", {text: "Evidence"}]]);
  const writes = [];
  const messages = [];
  const deliveryState = {fail: false};
  const account = {uid: ROOT, email: "root@example.test", emailVerified: true, disabled: false};
  /**
   * @param {string} path Document path.
   * @return {Object} Document fake.
   */
  function document(path) {
    const ref = {path, id: path.split("/").pop()};
    ref.get = async () => ({id: ref.id, ref, exists: rows.has(path), data: () => rows.get(path), get: (key) => (rows.get(path) || {})[key]});
    ref.set = async (data) => {
      writes.push(path); rows.set(path, data);
    };
    ref.listCollections = async () => [...new Set([...rows.keys()].filter((k) => k.startsWith(path + "/")).map((k) => k.split("/").slice(0, path.split("/").length + 1).join("/")))].map((p) => collection(p));
    return ref;
  }
  /**
   * @param {string} path Collection path.
   * @param {?Array} filter Equality filter.
   * @param {number} count Limit.
   * @param {?string} cursor Continuation.
   * @return {Object} Query fake.
   */
  function collection(path, filter = null, count = 999, cursor = null) {
    return {path, doc: (id) => document(path + "/" + (id || "auto" + rows.size)),
      add: async (data) => {
        writes.push(path); rows.set(path + "/log" + writes.length, data);
      },
      where: (key, op, value) => collection(path, [key, value], count, cursor),
      orderBy: () => collection(path, filter, count, cursor),
      limit: (n) => collection(path, filter, n, cursor),
      startAfter: (id) => collection(path, filter, count, id),
      get: async () => {
        const paths = [...rows.keys()].filter((p) => p.startsWith(path + "/") && p.split("/").length === path.split("/").length + 1 && (!filter || rows.get(p)[filter[0]] === filter[1]) && (!cursor || p.split("/").pop() > cursor)).sort().slice(0, count);
        return {size: paths.length, docs: await Promise.all(paths.map((p) => document(p).get()))};
      }};
  }
  let transactions = Promise.resolve();
  const db = {doc: document, collection, runTransaction: (fn) => {
    const pending = transactions.then(async () => {
      const staged = [];
      const result = await fn({get: (ref) => ref.get(),
        set: (ref, value) => staged.push([ref.path, value]),
        update: (ref, value) => staged.push([ref.path,
          {...rows.get(ref.path), ...value}]),
        delete: (ref) => staged.push([ref.path, null])});
      for (const [path, value] of staged) {
        writes.push(path);
        if (value === null) rows.delete(path);
        else rows.set(path, value);
      }
      return result;
    });
    transactions = pending.catch(() => {});
    return pending;
  }};
  /** Callable error fake. */
  class HttpsError extends Error {
    /**
     * @param {string} code Error code.
     * @param {string} message Error message.
     */
    constructor(code, message) {
      super(message); this.code = code;
    }
  }
  const firestore = () => db;
  firestore.FieldValue = {serverTimestamp: () => 123};
  firestore.FieldPath = {documentId: () => "__name__"};
  const result = {};
  const fakeAdmin = {firestore, auth: () => ({getUser: async () => account})};
  vm.runInNewContext(fs.readFileSync(__dirname + "/shop_inspection.js", "utf8"), {
    exports: result, Buffer, require: (name) => {
      if (name === "firebase-admin") return fakeAdmin;
      if (name === "firebase-functions/v2/https") {
        return {onCall: (_, fn) => fn, HttpsError};
      }
      if (name === "./inspection_mailer") {
        return {secrets: [], sendInspectionEmail: async (message) => {
          if (deliveryState.fail) throw new Error("SMTP-private-diagnostic");
          messages.push(message);
        }};
      }
      return require(name);
    },
  });
  const auth = {uid: ROOT, token: {auth_time: Math.floor(Date.now()/1000)}};
  const call = (data, identity = auth) => result.inspectShop({data, auth: identity});
  const code = () => messages[messages.length - 1].text
      .match(/驗證碼：(\d{6})/)[1];
  const unlock = async () => {
    const sent = await call({action: "send_code"});
    return call({action: "verify_code", challengeId: sent.challengeId,
      code: code()});
  };
  return {call, auth, rows, writes, messages, account, deliveryState, code,
    unlock, policy: result._policy};
}
test("rejects anonymous and non-root including claimed super-admin", async () => {
  const f = fixture();
  for (const auth of [null, {uid: "other", token: {role: "super_admin"}}]) await assert.rejects(f.call({action: "begin"}, auth), {code: "permission-denied"});
  assert.equal(f.writes.length, 0);
});
test("rejects the old re-login bypass and forged sessions", async () => {
  const f = fixture();
  await assert.rejects(f.call({action: "begin"}, {...f.auth, token: {auth_time: 1}}), {code: "invalid-argument"});
  await assert.rejects(f.call({action: "shops", token: "forged"}), {code: "unauthenticated"});
});
test("session works across shops; read cannot cross shop ownership", async () => {
  const f = fixture(); const {token} = await f.unlock();
  assert.equal((await f.call({action: "shops", token})).records.length, 1);
  const result = await f.call({action: "read", token, shopId: "s1", path: "bookings"});
  assert.equal(result.records.length, 1);
  await assert.rejects(f.call({action: "read", token, shopId: "s1", path: "bookings/b2/messages"}), {code: "permission-denied"});
  await assert.rejects(f.call({action: "read", token, shopId: "s1", path: "shops/s2"}), {code: "permission-denied"});
  await assert.rejects(f.call({action: "update", token}), {code: "invalid-argument"});
  assert.ok(f.writes.every((path) => path.startsWith("platform_inspection_")));
});
test("idle, changed login and explicit lock invalidate sessions", async () => {
  const f = fixture(); const {token} = await f.unlock();
  const path = [...f.rows.keys()].find((p) => p.startsWith("platform_inspection_sessions/"));
  const original = {...f.rows.get(path)};
  f.rows.set(path, {...original, touchedAt: Date.now() - 1800000});
  await assert.rejects(f.call({action: "shops", token}), {code: "unauthenticated"});
  f.rows.set(path, original);
  await assert.rejects(f.call({action: "shops", token}, {...f.auth, token: {auth_time: f.auth.token.auth_time + 1}}), {code: "unauthenticated"});
  await f.call({action: "end", token});
  await assert.rejects(f.call({action: "shops", token}), {code: "unauthenticated"});
});
test("customer bundle includes nested conversations, excludes other shop, writes audit only", async () => {
  const f = fixture(); const {token} = await f.unlock();
  const result = await f.call({action: "export", token, shopId: "s1", customerId: "u1"});
  assert.equal(result.complete, true);
  assert.ok(result.records.some((r) => r.path.endsWith("messages/m1")));
  assert.ok(result.records.some((r) => r.path === "bookings/b1"));
  assert.ok(!result.records.some((r) => r.path === "bookings/b2"));
  assert.ok(f.writes.every((path) => path.startsWith("platform_inspection_")));
});
test("truncation is explicitly reported", async () => {
  const f = fixture();
  for (let i=0; i<201; i++) f.rows.set("shops/s1/store_orders/o" + String(i).padStart(3, "0"), {userId: "u1"});
  const {token} = await f.unlock();
  const result = await f.call({action: "export", token, shopId: "s1", customerId: "u1"});
  assert.equal(result.complete, false);
  assert.ok(result.incomplete.includes("shops/s1/store_orders"));
});

test("finds customer transactions beyond unrelated early records", async () => {
  const f = fixture();
  for (let i=0; i<210; i++) {
    f.rows.set("bookings/a" + i, {shopId: "s1", userId: "another"});
  }
  f.rows.set("bookings/zz", {shopId: "s1", userId: "u1"});
  const {token} = await f.unlock();
  const result = await f.call({action: "export", token,
    shopId: "s1", customerId: "u1"});
  assert.ok(result.records.some((r) => r.path === "bookings/zz"));
  assert.ok(!result.records.some((r) => r.data.userId === "another"));
});


test("sends only to verified root mailbox and never returns plain code", async () => {
  const f = fixture();
  f.auth.token.auth_time = 1; // Existing login need not be repeated.
  const response = await f.call({action: "send_code", to: "attacker@test"});
  assert.equal(f.messages[0].to, "root@example.test");
  assert.equal(response.maskedEmail, "r***@example.test");
  assert.equal(JSON.stringify(response).includes(f.code()), false);
  const challenge = f.rows.get("platform_inspection_email_codes/" + ROOT);
  assert.equal(challenge.code, undefined);
  assert.equal(challenge.codeHash.length, 64);
  const result = await f.call({action: "verify_code",
    challengeId: response.challengeId, code: f.code()});
  assert.ok(result.token);
  await assert.rejects(f.call({action: "verify_code",
    challengeId: response.challengeId, code: f.code()}),
  {code: "failed-precondition"});
});

test("rejects unverified mailbox and does not claim failed mail was sent", async () => {
  const f = fixture(); f.account.emailVerified = false;
  await assert.rejects(f.call({action: "send_code"}),
      {code: "failed-precondition"});
  assert.equal(f.messages.length, 0);
  f.account.emailVerified = true; f.deliveryState.fail = true;
  await assert.rejects(f.call({action: "send_code"}), (error) =>
    error.code === "unavailable" && !error.message.includes("SMTP-private"));
  assert.equal(f.rows.get("platform_inspection_email_codes/" + ROOT)
      .revoked, true);
});

test("limits resend frequency and sends per hour", async () => {
  const f = fixture(); await f.call({action: "send_code"});
  await assert.rejects(f.call({action: "send_code"}),
      {code: "resource-exhausted"});
  const limit = "platform_inspection_email_limits/" + ROOT;
  for (let i = 1; i < 5; i++) {
    f.rows.get(limit).lastSentAt = 0;
    await f.call({action: "send_code"});
  }
  f.rows.get(limit).lastSentAt = 0;
  await assert.rejects(f.call({action: "send_code"}),
      {code: "resource-exhausted"});
  assert.equal(f.messages.length, 5);
});

test("wrong attempts persist, lock at five and expiry blocks correct code", async () => {
  const f = fixture(); const sent = await f.call({action: "send_code"});
  const code = f.code(); const wrong = code === "000000" ? "000001" : "000000";
  for (let i = 0; i < 5; i++) {
    await assert.rejects(f.call({action: "verify_code",
      challengeId: sent.challengeId, code: wrong}),
    {code: "failed-precondition"});
  }
  const path = "platform_inspection_email_codes/" + ROOT;
  assert.equal(f.rows.get(path).attempts, 5);
  await assert.rejects(f.call({action: "verify_code",
    challengeId: sent.challengeId, code}), {code: "failed-precondition"});
  const g = fixture(); const fresh = await g.call({action: "send_code"});
  g.rows.get(path).expiresAtMillis = Date.now() - 1;
  await assert.rejects(g.call({action: "verify_code",
    challengeId: fresh.challengeId, code: g.code()}),
  {code: "failed-precondition"});
});

test("resending invalidates previous code; challenge bound to login and mailbox", async () => {
  const f = fixture(); const old = await f.call({action: "send_code"});
  f.rows.get("platform_inspection_email_limits/" + ROOT).lastSentAt = 0;
  const fresh = await f.call({action: "send_code"});
  await assert.rejects(f.call({action: "verify_code",
    challengeId: old.challengeId, code: f.code()}),
  {code: "failed-precondition"});
  f.auth.token.auth_time += 1;
  await assert.rejects(f.call({action: "verify_code",
    challengeId: fresh.challengeId, code: f.code()}),
  {code: "failed-precondition"});
  f.auth.token.auth_time -= 1; f.account.email = "changed@example.test";
  await assert.rejects(f.call({action: "verify_code",
    challengeId: fresh.challengeId, code: f.code()}),
  {code: "failed-precondition"});
});

test("concurrent code verification creates exactly one session", async () => {
  const f = fixture(); const sent = await f.call({action: "send_code"});
  const input = {action: "verify_code", challengeId: sent.challengeId,
    code: f.code()};
  const results = await Promise.allSettled([f.call(input), f.call(input)]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal([...f.rows.keys()].filter((k) =>
    k.startsWith("platform_inspection_sessions/")).length, 1);
});

test("legacy password-unlocked sessions cannot read inspection data", async () => {
  const f = fixture(); const {token} = await f.unlock();
  const path = [...f.rows.keys()].find((p) =>
    p.startsWith("platform_inspection_sessions/"));
  delete f.rows.get(path).verification;
  await assert.rejects(f.call({action: "shops", token}),
      {code: "unauthenticated"});
});
