"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const ROOT = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
function fixture() {
  const rows = new Map([
    ["platform_inspection_rollout/current", {writeGuardsVerified: true}],
    ["platform_inspection_sessions/parent", {uid: ROOT,
      verification: "email_code_v1", touchedAt: Date.now()}],
  ]);
  const changes = [], claims = [];
  const target = {uid: "fresh-anon", firebase: {sign_in_provider: "anonymous"},
    auth_time: Math.floor(Date.now() / 1000)};
  const account = {providerData: [], metadata: {creationTime: new Date().toISOString()}};
  const auth = {verifyIdToken: async () => target, getUser: async () => account,
    setCustomUserClaims: async (uid, data) => claims.push({uid, data})};
  function doc(path) {
    return {path, id: path.split("/").pop(),
      get: async () => ({exists: rows.has(path), data: () => rows.get(path),
        get: (key) => (rows.get(path) || {})[key]}),
      set: async (data) => {changes.push(path); rows.set(path, data);},
      update: async (data) => {changes.push(path); rows.set(path, {...rows.get(path), ...data});},
      collection: () => ({select: () => ({get: async () => ({docs: [
        {id: "member-local", data: () => ({userId: "customer-app"})},
      ]})})}),
    };
  }
  const db = {doc, collection: (path) => ({doc: (id) => doc(path + "/" + id),
      where: () => ({select: () => ({get: async () => ({docs: []})})})}),
    runTransaction: async (fn) => fn({get: (ref) => ref.get(),
      update: (ref, data) => ref.update(data)})};
  const original = Module._load;
  const filename = require.resolve("./inspection_owner_preview");
  delete require.cache[filename];
  let preview;
  try {
    Module._load = function(name, ...args) {
      return name === "firebase-admin" ? {auth: () => auth, firestore: () => db} :
        original.call(this, name, ...args);
    };
    preview = require(filename);
  } finally {Module._load = original;}
  const issue = () => preview.issueOwnerPreview({db, data: {previewIdToken: "anon-id-token"},
    sessionRef: {id: "parent"}, shopId: "s1", shop: {get: () => "real-owner"}});
  return {rows, changes, claims, target, account, auth, issue, preview};
}
test("rollout must be verified before any anonymous grant is issued", async () => {
  const f = fixture(); f.rows.clear();
  await assert.rejects(f.issue(), {code: "failed-precondition"});
  assert.equal(f.claims.length, 0); assert.equal(f.changes.length, 0);
});
test("fresh anonymous identity receives shop-linked data only, owner auth untouched", async () => {
  const f = fixture(); const grant = await f.issue();
  assert.match(grant.grantId, /^[a-f0-9]{48}$/);
  const stored = f.rows.get("platform_inspection_previews/" + grant.grantId);
  assert.equal(stored.parentSession, "parent");
  assert.deepEqual(stored.allowedUserUids.sort(), ["customer-app", "member-local", "real-owner"]);
  assert.equal(f.claims[0].uid, "fresh-anon");
  assert.equal(f.claims[0].data.petnestInspection, true);
  assert.ok(f.changes.every((path) => path.startsWith("platform_inspection_previews/")));
});
test("root, existing provider, old identity and invalid auth time cannot become a preview", async () => {
  for (const alter of [
    (f) => {f.target.uid = ROOT;},
    (f) => {f.target.firebase.sign_in_provider = "password";},
    (f) => {f.account.metadata.creationTime = "2020-01-01T00:00:00Z";},
    (f) => {delete f.target.auth_time;},
  ]) {
    const f = fixture(); alter(f);
    await assert.rejects(f.issue(), {code: "permission-denied"});
    assert.equal(f.claims.length, 0);
  }
});
test("heartbeat rejects other identities and a removed parent session", async () => {
  const f = fixture(); const grant = await f.issue();
  const request = {auth: {uid: "wrong", token: {
    petnestInspection: true, inspectionGrant: grant.grantId}}, data: {}};
  await assert.rejects(f.preview.inspectionPreviewHeartbeat.run(request), {code: "unauthenticated"});
  request.auth.uid = "fresh-anon";
  f.rows.delete("platform_inspection_sessions/parent");
  await assert.rejects(f.preview.inspectionPreviewHeartbeat.run(request), {code: "unauthenticated"});
});

test("preview polling cannot extend root idle session, and end revokes grant", async () => {
  const f = fixture();
  const grant = await f.issue();
  const parent = f.rows.get("platform_inspection_sessions/parent");
  parent.touchedAt = Date.now() - 1000;
  const before = parent.touchedAt;
  const request = {auth: {uid: "fresh-anon", token: {
    petnestInspection: true, inspectionGrant: grant.grantId}}, data: {}};
  await f.preview.inspectionPreviewHeartbeat.run(request);
  assert.equal(f.rows.get("platform_inspection_sessions/parent").touchedAt, before);
  request.data.end = true;
  await f.preview.inspectionPreviewHeartbeat.run(request);
  assert.equal(f.rows.get("platform_inspection_previews/" + grant.grantId).active, false);
  assert.equal(f.rows.get("platform_inspection_sessions/parent").touchedAt, before);
});
