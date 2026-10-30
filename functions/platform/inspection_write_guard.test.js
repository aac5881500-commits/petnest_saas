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
