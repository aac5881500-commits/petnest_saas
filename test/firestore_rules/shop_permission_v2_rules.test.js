const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc, deleteDoc} = require("firebase/firestore");

const rulesPath = path.resolve(__dirname, "../../firestore.rules");

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-petnest-permission-v2",
    firestore: {rules: fs.readFileSync(rulesPath, "utf8")},
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "shops/shopA"), {ownerUid: "ownerA"});
    await setDoc(doc(db, "shop_members/shopA_ownerA"), {
      shopId: "shopA",
      uid: "ownerA",
      role: "owner",
      permissions: {},
    });
    await setDoc(doc(db, "shop_members/shopA_managerA"), {
      shopId: "shopA",
      uid: "managerA",
      role: "manager",
      permissions: {manage_staff: true, manage_bookings: true},
    });
    await setDoc(doc(db, "shop_members/shopA_staffA"), {
      shopId: "shopA",
      uid: "staffA",
      role: "staff",
      email: "staff@example.com",
      permissions: {manage_bookings: true},
    });
    await setDoc(doc(db, "shop_notifications/pay1"), {
      shopId: "shopA",
      type: "payment_failed",
      audience: "owner",
      title: "付款失敗",
      content: "secret",
      status: "unread",
    });
    await setDoc(doc(db, "shop_notifications/sys1"), {
      shopId: "shopA",
      type: "system",
      audience: "everyone",
      title: "維護",
      content: "ok",
      status: "unread",
    });
    await setDoc(doc(db, "shop_member_invites/shopA_new@example.com"), {
      shopId: "shopA",
      emailKey: "new@example.com",
      role: "staff",
      status: "pending",
    });
  });
});

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("員工不能修改自己的權限", async () => {
  await assertFails(updateDoc(doc(db("staffA"), "shop_members/shopA_staffA"), {
    role: "owner",
    permissions: {manage_payment_settings: true},
  }));
});

test("店長不能把自己改成老闆，也不能打開金流權限", async () => {
  await assertFails(updateDoc(doc(db("managerA"), "shop_members/shopA_managerA"), {
    shopId: "shopA",
    uid: "managerA",
    role: "owner",
    permissions: {manage_staff: true},
  }));
  await assertFails(updateDoc(doc(db("managerA"), "shop_members/shopA_staffA"), {
    shopId: "shopA",
    uid: "staffA",
    role: "staff",
    permissions: {manage_payment_settings: true},
  }));
});

test("店長可以更新一般員工的非核心權限", async () => {
  await assertSucceeds(updateDoc(doc(db("managerA"), "shop_members/shopA_staffA"), {
    shopId: "shopA",
    uid: "staffA",
    role: "staff",
    email: "staff@example.com",
    permissions: {manage_bookings: true, manage_payment_settings: false, manage_staff: false},
  }));
});

test("店長可以取消一般員工邀請，員工不可以", async () => {
  await assertSucceeds(getDoc(doc(db("managerA"), "shop_member_invites/shopA_new@example.com")));
  await assertFails(deleteDoc(doc(db("staffA"), "shop_member_invites/shopA_new@example.com")));
  await assertSucceeds(deleteDoc(doc(db("managerA"), "shop_member_invites/shopA_new@example.com")));
});

test("員工讀不到老闆專屬通知，但讀得到一般通知", async () => {
  await assertFails(getDoc(doc(db("staffA"), "shop_notifications/pay1")));
  const visible = await assertSucceeds(getDoc(doc(db("staffA"), "shop_notifications/sys1")));
  assert.equal(visible.data().title, "維護");
  const ownerVisible = await assertSucceeds(getDoc(doc(db("ownerA"), "shop_notifications/pay1")));
  assert.equal(ownerVisible.data().audience, "owner");
});
