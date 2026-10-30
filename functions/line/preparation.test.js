"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {normalizePreparation, preparationStatus} = require("./preparation");
const {verifyLineSignature} = require("./webhook_signature");

test("preparation validates public ids and selected use cases", () => {
  const config = normalizePreparation({officialAccountId: " @sample ", channelId: "1234567890", requestedUses: ["personal", "booking", "personal"]});
  assert.equal(config.officialAccountId, "@sample");
  assert.deepEqual(config.requestedUses, ["booking", "personal"]);
  for (const raw of [{channelId: "token-not-id"}, {officialAccountId: "sample"}, {requestedUses: ["unlimited"]}, {channelSecret: "hidden"}, []]) {
    assert.throws(() => normalizePreparation(raw), {code: "invalid-argument"});
  }
});

test("public details can never become proof of verified connection", () => {
  const result = preparationStatus({officialAccountId: "@sample", channelId: "1234567890", ready: true, webhookVerified: true});
  assert.equal(result.accountDetailsSaved, true);
  assert.equal(result.ready, false); assert.equal(result.webhookVerified, false);
});

test("webhook utility verifies original bytes and rejects modifications", () => {
  const body = Buffer.from("{\"events\":[],\"destination\":\"test\"}");
  const signature = crypto.createHmac("sha256", "test-secret").update(body).digest("base64");
  assert.equal(verifyLineSignature(body, "test-secret", signature), true);
  assert.equal(verifyLineSignature(Buffer.from("{ \"events\":[],\"destination\":\"test\"}"), "test-secret", signature), false);
  assert.equal(verifyLineSignature(body, "wrong", signature), false);
});

test("webhook utility fails closed on missing or malformed input", () => {
  for (const value of ["", "not-base64", undefined]) assert.equal(verifyLineSignature(Buffer.from("{}"), "test-secret", value), false);
  assert.equal(verifyLineSignature("{}", "test-secret", "A".repeat(43) + "="), false);
  assert.equal(verifyLineSignature(Buffer.from("{}"), "", "A".repeat(43) + "="), false);
});
