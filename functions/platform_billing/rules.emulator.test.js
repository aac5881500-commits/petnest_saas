/* eslint-disable max-len */
"use strict";
const test = require("node:test");
const path = require("node:path");
const fs = require("node:fs");
const {createRequire} = require("node:module");
const testRequire = createRequire(path.resolve(__dirname, "../../test/firestore_rules/package.json"));
const {initializeTestEnvironment, assertFails} = testRequire("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc} = testRequire("firebase/firestore");
let env;
const collections = ["platform_billing_orders", "platform_billing_accounts", "platform_billing_requests", "platform_billing_test_receipts", "platform_billing_state"];
test.before(async () => {
  env = await initializeTestEnvironment({projectId: "demo-platform-billing", firestore: {host: "127.0.0.1", port: 8312,
    rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8")}});
  await env.withSecurityRulesDisabled(async (context) => {
    for (const name of collections) await setDoc(doc(context.firestore(), name + "/private"), {shopId: "s1", ownerUid: "owner", launchHash: "not-a-real-hash"});
  });
});
test.after(async () => {
  if (env) await env.cleanup();
});
for (const uid of [null, "owner", "staff", "7FNrECQeqAca9Vu8lBBzTSdcJcg1"]) {
  test(`private billing data cannot be directly read or forged by ${uid || "guest"}`, async () => {
    const db = uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
    for (const name of collections) {
      await assertFails(getDoc(doc(db, name + "/private")));
      await assertFails(setDoc(doc(db, name + "/forged"), {shopId: "s1", status: "confirmed", amountMinor: 1}));
    }
  });
}
