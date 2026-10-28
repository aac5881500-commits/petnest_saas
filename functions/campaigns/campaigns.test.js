/* eslint-disable max-len, require-jsdoc */
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {createCampaignFunctions} = require("./index");
const policy = require("./policy");
class Stamp {
  toMillis() {
    return 1000;
  }
}
function fixture() {
  const store = new Map();
  let serial = Promise.resolve();
  const snapshot = (ref) => ({id: ref.id, ref, exists: store.has(ref.path), data: () => store.get(ref.path)});
  class Query {
    constructor(path, filters = [], cap = Infinity, order = null) {
      Object.assign(this, {path, filters, cap, order});
    }
    doc(value) {
      return new Ref(`${this.path}/${value}`);
    }
    where(field, op, value) {
      return new Query(this.path, [...this.filters, [field, op, value]], this.cap, this.order);
    }
    limit(value) {
      return new Query(this.path, this.filters, value, this.order);
    }
    orderBy(field, direction) {
      return new Query(this.path, this.filters, this.cap, [field, direction]);
    }
    async get() {
      let docs = [...store.keys()].filter((path) => path.startsWith(`${this.path}/`) && !path.slice(this.path.length + 1).includes("/"))
          .map((path) => snapshot(new Ref(path))).filter((doc) => this.filters.every(([key, op, value]) => op === "in" ? value.includes(doc.data()[key]) : doc.data()[key] === value));
      if (this.order) docs.sort((a, b) => (a.data()[this.order[0]] - b.data()[this.order[0]]) * (this.order[1] === "desc" ? -1 : 1));
      docs = docs.slice(0, this.cap);
      return {docs, size: docs.length, empty: !docs.length};
    }
  }
  class Ref {
    constructor(path) {
      this.path = path; this.id = path.split("/").at(-1);
    }
    collection(name) {
      return new Query(`${this.path}/${name}`);
    }
    async get() {
      return snapshot(this);
    }
    async set(data) {
      store.set(this.path, data);
    }
    async update(data) {
      assert(store.has(this.path)); store.set(this.path, {...store.get(this.path), ...data});
    }
    async delete() {
      store.delete(this.path);
    }
  }
  const db = {collection: (path) => new Query(path), runTransaction(fn) {
    const pending = serial.then(async () => {
      const writes = [];
      const result = await fn({get: (ref) => ref.get(),
        set: (ref, data) => writes.push(() => ref.set(data)),
        create: (ref, data) => {
          assert(!store.has(ref.path)); writes.push(() => ref.set(data));
        },
        update: (ref, data) => writes.push(() => ref.update(data))});
      for (const write of writes) await write();
      return result;
    });
    serial = pending.catch(() => {}); return pending;
  }};
  const pushes = [];
  let failPush = false;
  const firestore = () => db;
  firestore.FieldValue = {serverTimestamp: () => new Stamp()};
  const admin = {firestore,
    auth: () => ({getUsers: async (users) => ({users: users.filter((u) => store.has(`users/${u.uid}`)).map((u) => ({uid: u.uid, ...store.get(`users/${u.uid}`)}))})}),
    messaging: () => ({sendEachForMulticast: async (args) => {
      pushes.push(args); if (failPush) throw new Error("unknown result");
      return {successCount: args.tokens.length, failureCount: 0, responses: args.tokens.map(() => ({success: true}))};
    }})};
  const api = createCampaignFunctions({admin, customerPushAllowed: (kind, prefs) => prefs.enabled !== false && prefs[kind.category === "shop_notice" ? "shopNotice" : "shopMarketing"] !== false});
  store.set("shops/s", {ownerUid: "owner", name: "Test shop"});
  store.set("shops/other", {ownerUid: "other"});
  for (const uid of ["u1", "u2"]) {
    store.set(`shops/s/members/${uid}`, {userId: uid, name: uid, source: "app", tags: uid === "u1" ? ["vip"] : []});
    store.set(`users/${uid}`, {});
    store.set(`users/${uid}/fcm_tokens/token-${uid}`, {enabled: true});
  }
  store.set("shops/s/members/manual", {name: "Manual", source: "admin"});
  const request = (action, data = {}, uid = "owner", shopId = "s") => api.manageShopCampaign.run({auth: {uid, token: {name: uid}}, data: {action, shopId, ...data}});
  const draft = {title: "Announcement", body: "Real content", category: "shop_marketing", channel: "push", audience: "all", memberIds: []};
  async function prepare(id = "c", override = {}) {
    return request("preview", {campaignId: id, draft: {...draft, ...override}, version: 0});
  }
  async function send(id = "c", override = {}) {
    const p = await prepare(id, override);
    await request("send", {campaignId: id, revision: p.preview.revision});
    return db.collection("shop_campaigns").doc(id);
  }
  return {store, db, api, request, draft, prepare, send, pushes, fail: () => {
    failPush = true;
  }};
}
test("only owner or explicitly authorized active staff can access", async () => {
  const f = fixture();
  await assert.rejects(f.request("bootstrap", {}, "stranger"), {code: "permission-denied"});
  f.store.set("shop_members/s_staff", {uid: "staff", shopId: "other", role: "staff", permissions: {send_member_campaigns: true}});
  await assert.rejects(f.request("bootstrap", {}, "staff"), {code: "permission-denied"});
  assert.equal(policy.permissions({ownerUid: "o"}, {uid: "staff", shopId: "s", role: "staff", active: false, permissions: {send_member_campaigns: true}}, "staff").send, false);
});
test("draft permission does not imply sending; no forced category allowed", async () => {
  const f = fixture();
  f.store.set("shop_members/s_staff", {uid: "staff", shopId: "s", role: "staff", permissions: {manage_campaign_drafts: true}});
  const p = await f.prepare();
  await assert.rejects(f.request("send", {campaignId: "c", revision: p.preview.revision}, "staff"), {code: "permission-denied"});
  assert.throws(() => policy.normalize({...f.draft, category: "transactional"}), {code: "invalid-argument"});
  assert.equal(policy.normalize({...f.draft, isMandatory: true}).isMandatory, undefined);
});
test("preview excludes manual, blacklisted and missing or disabled auth accounts", async () => {
  const f = fixture();
  f.store.set("shops/s/members/u3", {source: "app", userId: "u3", blacklisted: true});
  f.store.set("shops/s/members/u4", {source: "app", userId: "u4"});
  f.store.set("users/u4", {disabled: true});
  f.store.set("shops/s/members/u5", {source: "app", userId: "u5"});
  const result = await f.prepare();
  assert.equal(result.preview.count, 2); assert.equal(result.preview.excluded, 4);
  await assert.rejects(f.prepare("foreign", {audience: "selected", memberIds: ["other-shop-member"]}), {code: "failed-precondition"});
});
test("VIP and selected audiences resolve only within this shop", async () => {
  const f = fixture();
  assert.equal((await f.prepare("vip", {audience: "vip"})).preview.count, 1);
  assert.equal((await f.prepare("selected", {audience: "selected", memberIds: ["u2", "u2"]})).preview.count, 1);
});
test("stale content or recipient changes invalidate preview", async () => {
  const f = fixture(); const p = await f.prepare();
  f.store.delete("shops/s/members/u2");
  await assert.rejects(f.request("send", {campaignId: "c", revision: p.preview.revision}), {code: "failed-precondition"});
  await assert.rejects(f.request("save", {campaignId: "c", version: 0, draft: f.draft}), {code: "aborted"});
});
test("unpublished or deleted announcement cannot be promoted", async () => {
  const f = fixture();
  f.store.set("shops/s/announcements/a", {isPublished: false});
  await assert.rejects(f.prepare("a", {announcementId: "a"}), {code: "failed-precondition"});
  f.store.set("shops/s/announcements/a", {isPublished: true});
  const p = await f.prepare("b", {announcementId: "a"});
  f.store.delete("shops/s/announcements/a");
  await assert.rejects(f.request("send", {campaignId: "b", revision: p.preview.revision}), {code: "failed-precondition"});
});
test("repeat confirmation and duplicate worker invocation do not duplicate inbox or push", async () => {
  const f = fixture(); const ref = await f.send();
  await f.request("send", {campaignId: "c", revision: "retry-after-timeout"});
  await Promise.all([f.api.processForTest(ref), f.api.processForTest(ref)]);
  await f.api.processForTest(ref);
  assert.equal(f.pushes.length, 2);
  assert.equal([...f.store.keys()].filter((key) => key.startsWith("notifications/")).length, 2);
  assert.equal(f.store.get("shop_campaigns/c").counts.inbox, 2);
  assert.equal(f.store.get("notifications/campaign_c_u1").isMandatory, false);
});
test("push opt-out still creates inbox; inbox-only never calls FCM", async () => {
  const f = fixture(); f.store.set("users/u1/notification_settings/global", {shopMarketing: false});
  f.store.delete("users/u2/fcm_tokens/token-u2");
  await f.api.processForTest(await f.send());
  assert.equal(f.pushes.length, 0);
  assert.deepEqual(f.store.get("shop_campaigns/c").counts.opted_out, 1);
  assert.equal(f.store.get("shop_campaigns/c").counts.no_token, 1);
  await f.api.processForTest(await f.send("inbox", {channel: "inbox"}));
  assert.equal(f.pushes.length, 0); assert.equal(f.store.get("shop_campaigns/inbox").counts.inbox, 2);
});
test("removed member after confirmation is skipped; ambiguous push is not replayed", async () => {
  const f = fixture(); const ref = await f.send(); f.store.delete("shops/s/members/u2"); f.fail();
  await f.api.processForTest(ref); await f.api.processForTest(ref);
  assert.equal(f.store.get("shop_campaigns/c").counts.skipped, 1);
  assert.equal(f.store.get("shop_campaigns/c").counts.unknown, 1); assert.equal(f.pushes.length, 1);
});
test("cross-shop draft ID reuse and reading history are rejected", async () => {
  const f = fixture(); await f.prepare();
  await assert.rejects(f.request("detail", {campaignId: "c"}, "other", "other"), {code: "not-found"});
  await assert.rejects(f.request("save", {campaignId: "c", draft: f.draft, version: 1}, "other", "other"), {code: "failed-precondition"});
});

test("large audience continues in bounded chunks without duplicate inbox records", async () => {
  const f = fixture();
  for (let i = 3; i <= 106; i++) {
    const uid = `u${i}`;
    f.store.set(`shops/s/members/${uid}`, {userId: uid, source: "app"});
    f.store.set(`users/${uid}`, {});
  }
  const ref = await f.send("large", {channel: "inbox"});
  await f.api.processForTest(ref);
  assert.equal(f.store.get("shop_campaigns/large").status, "queued");
  assert.equal([...f.store.keys()].filter((key) => key.startsWith("notifications/")).length, 100);
  await f.api.processForTest(ref);
  assert.equal(f.store.get("shop_campaigns/large").status, "completed");
  assert.equal(f.store.get("shop_campaigns/large").counts.inbox, 106);
});
test("recovery preserves an uncertain prior push attempt instead of replaying it", async () => {
  const f = fixture(); const ref = await f.send();
  f.store.set("shop_campaigns/c/deliveries/u1", {inbox: "created", push: "attempting"});
  f.store.set("notifications/campaign_c_u1", {userId: "u1"});
  await f.api.processForTest(ref);
  assert.equal(f.pushes.length, 1);
  assert.equal(f.store.get("shop_campaigns/c").counts.unknown, 1);
  assert.equal(f.store.get("shop_campaigns/c").counts.inbox, 2);
});
