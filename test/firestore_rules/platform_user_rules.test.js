const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");

const rulesPath = path.resolve(__dirname, "../../firestore.rules");
const rootUid = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-petnest-platform-user",
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
    await setDoc(doc(db, "platform_users/staffA"), {
      uid: "staffA",
      name: "員工",
      email: "staff@example.com",
      role: "platform_staff",
      enabled: true,
      permissions: ["view_shops", "legacy_custom_key"],
    });
    await setDoc(doc(db, "platform_users/managerA"), {
      uid: "managerA",
      name: "管理員",
      email: "manager@example.com",
      role: "platform_admin",
      enabled: true,
      permissions: ["manage_platform_admins", "view_shops", "view_platform_logs"],
    });
    await setDoc(doc(db, "platform_users/disabledA"), {
      uid: "disabledA",
      name: "停用",
      email: "disabled@example.com",
      role: "platform_admin",
      enabled: false,
      permissions: ["manage_platform_admins", "manage_payment_settings"],
    });
    await setDoc(doc(db, "platform_users/allOnly"), {
      uid: "allOnly",
      name: "全部標記",
      email: "all@example.com",
      role: "platform_staff",
      enabled: true,
      permissions: ["all"],
    });
    await setDoc(doc(db, "platform_users/mediaA"), {
      uid: "mediaA",
      name: "圖庫",
      email: "media@example.com",
      role: "platform_staff",
      enabled: true,
      permissions: ["manage_platform_media"],
    });
    await setDoc(doc(db, "shops/shopA"), {ownerUid: "ownerA"});
    await setDoc(doc(db, "shop_members/shopA_ownerA"), {
      shopId: "shopA",
      uid: "ownerA",
      role: "owner",
      permissions: {},
    });
    await setDoc(doc(db, "bookings/bookingA"), {
      shopId: "shopA",
      userId: "customerA",
      status: "pending",
    });
    await setDoc(doc(db, "platform_media_library/assetA"), {
      enabled: true,
      name: "背景",
    });
    await setDoc(doc(db, "action_logs/platformLog"), {
      shopId: "platform",
      targetType: "platform_user",
      targetId: "staffA",
      action: "update_platform_user",
      operatorUid: "managerA",
      createdAt: new Date(),
    });
    await setDoc(doc(db, "action_logs/shopLog"), {
      shopId: "shopA",
      targetType: "booking",
      targetId: "bookingA",
      action: "note",
      operatorUid: "ownerA",
      createdAt: new Date(),
    });
    await setDoc(doc(db, "activation_codes/codeA"), {code: "ABC"});
    await setDoc(doc(db, "activation_codes/codeA/usage_logs/logA"), {
      uid: "customerA",
    });
  });
});

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("平台員工不能修改自己的權限文件", async () => {
  await assertFails(updateDoc(doc(db("staffA"), "platform_users/staffA"), {
    role: "platform_admin",
  }));
});

test("平台管理員不能直接寫入其他平台人員", async () => {
  await assertFails(updateDoc(doc(db("managerA"), "platform_users/staffA"), {
    uid: "staffA",
    role: "super_admin",
    enabled: true,
    permissions: ["all"],
  }));
});

test("停用帳號不能讀取其他平台人員", async () => {
  await assertFails(getDoc(doc(db("disabledA"), "platform_users/staffA")));
});

test("有管理權限的啟用帳號可以讀取其他平台人員", async () => {
  await assertSucceeds(getDoc(doc(db("managerA"), "platform_users/staffA")));
});

test("平台員工不能讀取其他平台人員", async () => {
  await assertFails(getDoc(doc(db("staffA"), "platform_users/managerA")));
});

test("根管理員可以更新員工且保留呼叫端送出的一般欄位", async () => {
  await assertSucceeds(updateDoc(doc(db(rootUid), "platform_users/staffA"), {
    uid: "staffA",
    name: "員工",
    email: "staff@example.com",
    role: "platform_admin",
    enabled: true,
    permissions: ["view_shops", "legacy_custom_key"],
  }));
});

test("根管理員不能把員工提升為最高管理員", async () => {
  await assertFails(updateDoc(doc(db(rootUid), "platform_users/staffA"), {
    uid: "staffA",
    role: "super_admin",
    enabled: true,
    permissions: ["view_shops"],
  }));
});

test("根管理員不能新增加入金流專屬權限", async () => {
  await assertFails(updateDoc(doc(db(rootUid), "platform_users/staffA"), {
    uid: "staffA",
    role: "platform_staff",
    enabled: true,
    permissions: ["view_shops", "manage_payment_settings"],
  }));
});

test("全部權限標記不能讓非最高管理員讀取跨店訂單", async () => {
  await assertFails(getDoc(doc(db("allOnly"), "bookings/bookingA")));
  await assertSucceeds(getDoc(doc(db("staffA"), "bookings/bookingA")));
});

test("全部權限標記不能管理平台圖庫，明確授權可以", async () => {
  await assertFails(updateDoc(doc(db("allOnly"), "platform_media_library/assetA"), {
    enabled: false,
  }));
  await assertSucceeds(updateDoc(doc(db("mediaA"), "platform_media_library/assetA"), {
    enabled: false,
  }));
});

test("全部權限標記不能讀取激活碼使用紀錄", async () => {
  await assertFails(getDoc(doc(
      db("allOnly"),
      "activation_codes/codeA/usage_logs/logA",
  )));
});

test("平台人員可以讀取平台權限紀錄，不能讀取店家紀錄", async () => {
  await assertSucceeds(getDoc(doc(db("managerA"), "action_logs/platformLog")));
  await assertFails(getDoc(doc(db("staffA"), "action_logs/platformLog")));
  await assertSucceeds(getDoc(doc(db("ownerA"), "action_logs/shopLog")));
  await assertFails(getDoc(doc(db("staffA"), "action_logs/shopLog")));
});
