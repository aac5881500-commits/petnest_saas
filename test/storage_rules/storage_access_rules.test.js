// 載入專案 storage.rules，由 Storage Emulator 執行真正的 allow / deny。
const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc} = require("firebase/firestore");
const {ref, uploadBytes, getBytes} = require("firebase/storage");

const rulesPath = path.resolve(__dirname, "../../storage.rules");
const firestoreRulesPath = path.resolve(__dirname, "../../firestore.rules");
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const tooBig = new Uint8Array(5 * 1024 * 1024 + 1);
const petTooBig = new Uint8Array(6 * 1024 * 1024);
const preview =
  "daily_care_photos/shopA/bookingA/roomA/2026-10-04/1/photoA/preview.jpg";
const otherPreview =
  "daily_care_photos/shopA/bookingB/roomA/2026-10-04/1/photoB/preview.jpg";

let testEnv;

/**
 * @param {string} uid
 * @return {import("firebase/storage").FirebaseStorage}
 */
function storageAs(uid) {
  if (!uid) {
    return testEnv.unauthenticatedContext().storage();
  }
  return testEnv.authenticatedContext(uid).storage();
}

/**
 * @param {string} objectPath
 * @param {Uint8Array} bytes
 * @param {string} contentType
 * @return {Promise<void>}
 */
async function seedFile(objectPath, bytes, contentType) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), objectPath), bytes, {contentType});
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-petnest-storage",
    firestore: {rules: fs.readFileSync(firestoreRulesPath, "utf8")},
    storage: {rules: fs.readFileSync(rulesPath, "utf8")},
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "shops/shopA"), {ownerUid: "ownerA"});
    await setDoc(doc(db, "shops/shopB"), {ownerUid: "ownerB"});
    await setDoc(doc(db, "shop_members/shopA_ownerA"), {
      shopId: "shopA",
      uid: "ownerA",
      role: "owner",
      permissions: {edit_media: true, manage_room_types: true},
    });
    await setDoc(doc(db, "shop_members/shopA_managerA"), {
      shopId: "shopA",
      uid: "managerA",
      role: "staff",
      permissions: {edit_media: true, manage_room_dashboard: true},
    });
    await setDoc(doc(db, "shop_members/shopA_storeA"), {
      shopId: "shopA",
      uid: "storeA",
      role: "staff",
      permissions: {manage_store_settings: true},
    });
    await setDoc(doc(db, "shop_members/shopB_ownerB"), {
      shopId: "shopB",
      uid: "ownerB",
      role: "owner",
      permissions: {edit_media: true},
    });
    await setDoc(doc(db, "bookings/bookingA"), {
      shopId: "shopA",
      userId: "customerA",
      status: "checked_in",
    });
    await setDoc(doc(db, "bookings/bookingB"), {
      shopId: "shopA",
      userId: "customerB",
      status: "checked_in",
    });
  });
});

test("TEST 1 anonymous reads public logo", async () => {
  await seedFile("shops/shopA/logo.jpg", jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs(), "shops/shopA/logo.jpg")));
});

test("TEST 2 anonymous reads public room image", async () => {
  const objectPath = "shops/shopA/room_types/typeA/room_1.jpg";
  await seedFile(objectPath, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs(), objectPath)));
});

test("TEST 3 anonymous cannot read daily care photo", async () => {
  await seedFile(preview, jpeg, "image/jpeg");
  await assertFails(getBytes(ref(storageAs(), preview)));
});

test("TEST 4 booking owner reads own daily care preview", async () => {
  await seedFile(preview, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs("customerA"), preview)));
});

test("TEST 5 another customer cannot read that daily care photo", async () => {
  await seedFile(preview, jpeg, "image/jpeg");
  await assertFails(getBytes(ref(storageAs("customerB"), preview)));
});

test("TEST 6 shop owner reads own shop daily care photo", async () => {
  await seedFile(preview, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs("ownerA"), preview)));
});

test("TEST 7 shop A staff cannot read shop B daily care photo", async () => {
  const foreign =
    "daily_care_photos/shopB/bookingB/roomA/2026-10-04/1/photoB/preview.jpg";
  await seedFile(foreign, jpeg, "image/jpeg");
  await assertFails(getBytes(ref(storageAs("managerA"), foreign)));
});

test("TEST 8 anonymous cannot write a public logo", async () => {
  await assertFails(uploadBytes(
      ref(storageAs(), "shops/shopA/logo.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 9 customer cannot write a shop logo", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("customerA"), "shops/shopA/logo.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 10 shop media manager writes own logo", async () => {
  await assertSucceeds(uploadBytes(
      ref(storageAs("managerA"), "shops/shopA/logo.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 11 shop A manager cannot write shop B logo", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("managerA"), "shops/shopB/logo.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 12 non-image content type is denied", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("managerA"), "shops/shopA/logo.jpg"),
      jpeg,
      {contentType: "text/html"},
  ));
});

test("TEST 13 image over 5MB is denied", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("managerA"), "shops/shopA/logo.jpg"),
      tooBig,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 14 pet owner uploads own jpeg", async () => {
  await assertSucceeds(uploadBytes(
      ref(storageAs("customerA"), "pets/customerA/pet1.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 15 another customer cannot change that pet image", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("customerB"), "pets/customerA/pet1.jpg"),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST 16 customer cannot read another booking daily care photo", async () => {
  await seedFile(otherPreview, jpeg, "image/jpeg");
  await assertFails(getBytes(ref(storageAs("customerA"), otherPreview)));
});

test("anonymous cannot read an unlisted shop file", async () => {
  await seedFile("shops/shopA/private/secret.jpg", jpeg, "image/jpeg");
  await assertFails(getBytes(
      ref(storageAs(), "shops/shopA/private/secret.jpg"),
  ));
});

test("pet image at 6MB is denied", async () => {
  await assertFails(uploadBytes(
      ref(storageAs("customerA"), "pets/customerA/huge.jpg"),
      petTooBig,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S20 anonymous reads homepage banner version original", async () => {
  const objectPath = "shops/shopA/home/banners/bannerA/p_1/cover.jpg";
  await seedFile(objectPath, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs(), objectPath)));
});

test("TEST S21 homepage manager writes banner version original", async () => {
  const objectPath = "shops/shopA/home/banners/bannerA/p_1/cover.jpg";
  await assertSucceeds(uploadBytes(
      ref(storageAs("managerA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S22 other shop manager cannot write homepage banner", async () => {
  const objectPath = "shops/shopB/home/banners/bannerA/p_1/cover.jpg";
  await assertFails(uploadBytes(
      ref(storageAs("managerA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S23 anonymous reads store banner version original", async () => {
  const objectPath = "shops/shopA/store/banners/bannerA/p_1/cover.jpg";
  await seedFile(objectPath, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs(), objectPath)));
});

test("TEST S24 store manager writes store banner version original", async () => {
  const objectPath = "shops/shopA/store/banners/bannerA/p_1/cover.jpg";
  await assertSucceeds(uploadBytes(
      ref(storageAs("storeA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S25 customer cannot write store banner version original", async () => {
  const objectPath = "shops/shopA/store/banners/bannerA/p_1/cover.jpg";
  await assertFails(uploadBytes(
      ref(storageAs("customerA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S26 anonymous reads store entry card version image", async () => {
  const objectPath = "shops/shopA/home/store_entry_card/p_1/cover.jpg";
  await seedFile(objectPath, jpeg, "image/jpeg");
  await assertSucceeds(getBytes(ref(storageAs(), objectPath)));
});

test("TEST S27 homepage manager writes store entry card", async () => {
  const objectPath = "shops/shopA/home/store_entry_card/p_1/cover.jpg";
  await assertSucceeds(uploadBytes(
      ref(storageAs("managerA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("TEST S28 other shop cannot write store entry card", async () => {
  const objectPath = "shops/shopB/home/store_entry_card/p_1/cover.jpg";
  await assertFails(uploadBytes(
      ref(storageAs("managerA"), objectPath),
      jpeg,
      {contentType: "image/jpeg"},
  ));
});

test("rules file loaded", () => {
  const source = fs.readFileSync(rulesPath, "utf8");
  assert.equal(source.includes("match /shops/{shopId}/{allPaths=**}"), false);
  assert.equal(source.includes("allow read: if true;"), true);
});
