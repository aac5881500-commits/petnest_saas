"use strict";
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {createRequire} = require("node:module");
const testRequire = createRequire(path.resolve(__dirname, "../../test/firestore_rules/package.json"));
const {initializeTestEnvironment, assertFails, assertSucceeds} = testRequire("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc, getDocs, query, collection, where, updateDoc, deleteDoc} = testRequire("firebase/firestore");
const ROOT = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
let env;
test.before(async () => {
  env = await initializeTestEnvironment({projectId: "demo-inspection-readonly", firestore: {
    host: "127.0.0.1", port: 8299,
    rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
  }});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const rows = {
      "platform_inspection_sessions/parent": {uid: ROOT, verification: "email_code_v1", touchedAt: Date.now()},
      "platform_inspection_previews/grant": {uid: "preview", rootUid: ROOT, active: true,
        expiresAt: Date.now() + 3600000, parentSession: "parent", shopId: "s1", allowedUserUids: ["customer", "owner"]},
      "shops/s1": {ownerUid: "owner", isPublic: false, name: "Selected"},
      "shops/s2": {ownerUid: "other", isPublic: false},
      "shops/s1/members/customer": {userId: "customer", name: "Customer"},
      "bookings/b1": {shopId: "s1", status: "confirmed"},
      "bookings/b2": {shopId: "s2", status: "confirmed"},
      "bookings/b1/messages/m1": {text: "selected conversation"},
      "bookings/b2/messages/m2": {text: "other conversation"},
      "user_profiles/owner": {name: "Owner"},
      "user_profiles/owner/pets/p1": {name: "Owner pet"},
      "daily_care_photo_downloads/d1": {shopId: "s1", bookingId: "b1"},
      "daily_care_photos/no-download-yet": {shopId: "s1", bookingId: "b1"},
      "payments/p1": {shopId: "s1", amount: 100},
      "users/customer": {name: "Customer"}, "users/unrelated": {name: "Other"},
    };
    for (const [key, value] of Object.entries(rows)) await setDoc(doc(db, key), value);
  });
});
test.after(async () => {if (env) await env.cleanup();});
const preview = () => env.authenticatedContext("preview", {
  petnestInspection: true, inspectionGrant: "grant",
}).firestore();
test("selected shop, linked customer and selected transactions are readable", async () => {
  for (const key of ["shops/s1", "shops/s1/members/customer", "bookings/b1", "payments/p1", "users/customer"]) {
    await assertSucceeds(getDoc(doc(preview(), key)));
  }
});
test("other shop, unrelated user and inspection secrets remain inaccessible", async () => {
  for (const key of ["shops/s2", "bookings/b2", "users/unrelated", "platform_inspection_sessions/parent", "platform_inspection_previews/grant"]) {
    await assertFails(getDoc(doc(preview(), key)));
  }
});
test("preview cannot edit, delete, refund or send chat", async () => {
  const db = preview();
  await assertFails(updateDoc(doc(db, "shops/s1"), {name: "Changed"}));
  await assertFails(deleteDoc(doc(db, "shops/s1/members/customer")));
  await assertFails(updateDoc(doc(db, "payments/p1"), {refundedAmount: 100}));
  await assertFails(setDoc(doc(db, "shops/s1/chat_threads/customer/messages/new"), {
    shopId: "s1", threadId: "customer", senderUid: "preview", senderType: "shop", text: "Must not send",
  }));
});
test("normal root account still reads and edits selected shop", async () => {
  const db = env.authenticatedContext(ROOT).firestore();
  await assertSucceeds(getDoc(doc(db, "shops/s1")));
  await assertSucceeds(updateDoc(doc(db, "shops/s1"), {name: "Root updated"}));
});
test("booking subrecords and linked owner pet profiles are readable", async () => {
  for (const key of ["bookings/b1/messages/m1", "user_profiles/owner", "user_profiles/owner/pets/p1"]) {
    await assertSucceeds(getDoc(doc(preview(), key)));
  }
  await assertFails(getDoc(doc(preview(), "bookings/b2/messages/m2")));
  const wrong = env.authenticatedContext("wrong", {petnestInspection: true, inspectionGrant: "grant"}).firestore();
  await assertFails(getDoc(doc(wrong, "shops/s1")));
});
test("download list query explicitly scoped to selected shop succeeds", async () => {
  await assertSucceeds(getDoc(doc(preview(), "daily_care_photo_downloads/no-download-yet")));
  await assertSucceeds(getDocs(query(collection(preview(), "daily_care_photo_downloads"),
    where("bookingId", "==", "b1"), where("shopId", "==", "s1"))));
});
test("removing parent root session locks existing preview identity", async () => {
  await env.withSecurityRulesDisabled(async (context) => deleteDoc(doc(context.firestore(), "platform_inspection_sessions/parent")));
  await assertFails(getDoc(doc(preview(), "shops/s1")));
});
