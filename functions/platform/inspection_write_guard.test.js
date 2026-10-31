"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {onCall, rejectInspectionWrite} = require("./inspection_write_guard");
test("inspection identity is rejected even when its uid claims root", async () => {
  let mutations = 0;
  const handler = onCall({region: "asia-east1"}, async () => ++mutations);
  await assert.rejects(handler.run({auth: {uid: "root", token: {petnestInspection: true}}}),
      (error) => error.code === "permission-denied");
  assert.equal(mutations, 0);
});
test("normal authenticated callable preserves result and handler", async () => {
  const handler = onCall({region: "asia-east1"}, async (request) => request.data.value);
  assert.equal(await handler.run({auth: {uid: "u", token: {}}, data: {value: 7}}), 7);
});
test("anonymous callable semantics remain delegated to original handler", () => {
  assert.doesNotThrow(() => rejectInspectionWrite({}));
});
test("normal false claim and missing claim are unaffected", () => {
  assert.doesNotThrow(() => rejectInspectionWrite({auth: {token: {petnestInspection: false}}}));
  assert.doesNotThrow(() => rejectInspectionWrite({auth: {}}));
});

test("read action allowlist never admits save, send, rotate or delete", async () => {
  const handler = onCall({inspectionReadActions: ["get"]}, () => {
    throw new Error("must not execute");
  });
  for (const action of ["save", "send", "rotate", "delete"]) {
    await assert.rejects(handler.run({auth: {uid: "preview", token: {
      petnestInspection: true}}, data: {action}}), {code: "permission-denied"});
  }
});
test("read authorization is tenant scoped and preserves readonly claim", async () => {
  const {authorizeInspectionRead} = require("./inspection_write_guard");
  const id = "a".repeat(48);
  const rows = new Map([
    ["platform_inspection_previews/" + id, {uid: "preview", active: true,
      rootUid: "7FNrECQeqAca9Vu8lBBzTSdcJcg1", expiresAt: Date.now() + 60000,
      parentSession: "parent", shopId: "s1", ownerUid: "owner"}],
    ["platform_inspection_sessions/parent", {uid: "7FNrECQeqAca9Vu8lBBzTSdcJcg1",
      verification: "email_code_v1", touchedAt: Date.now()}],
    ["bookings/b1", {shopId: "s1", userId: "customer"}],
    ["bookings/b2", {shopId: "s2", userId: "other"}],
  ]);
  const db = {doc: (path) => ({get: async () => ({data: () => rows.get(path)})})};
  const request = {auth: {uid: "preview", token: {
    petnestInspection: true, inspectionGrant: id}}, data: {shopId: "s1"}};
  const read = await authorizeInspectionRead(request, db);
  assert.equal(read.auth.uid, "owner");
  assert.equal(read.auth.token.petnestInspection, true);
  assert.equal(request.auth.uid, "preview");
  await assert.rejects(authorizeInspectionRead({...request, data: {shopId: "s2"}}, db),
      {code: "permission-denied"});
  const customer = await authorizeInspectionRead({...request, data: {bookingId: "b1"}}, db, true);
  assert.equal(customer.auth.uid, "customer");
  await assert.rejects(authorizeInspectionRead({...request, data: {bookingId: "b2"}}, db, true),
      {code: "permission-denied"});
  rows.delete("platform_inspection_sessions/parent");
  await assert.rejects(authorizeInspectionRead(request, db), {code: "unauthenticated"});
});
