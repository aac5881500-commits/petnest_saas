// 檔案名稱：functions/legal_pet/staff_access.js
// 功能說明：讀取平台人員，並確認店家成員身份。

const {HttpsError} = require("firebase-functions/v2/https");
const {ROOT_ADMIN_UID} = require("./access");

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid 使用者
 * @return {Promise<Object>}
 */
async function loadPlatformUser(db, uid) {
  if (uid === ROOT_ADMIN_UID) {
    return {
      uid: uid,
      enabled: true,
      role: "super_admin",
      permissions: ["all"],
    };
  }
  const snap = await db.collection("platform_users").doc(uid).get();
  if (!snap.exists) {
    return {uid: uid, enabled: false, permissions: []};
  }
  const data = snap.data() || {};
  data.uid = uid;
  return data;
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid 使用者
 * @param {string} shopId 店家
 * @return {Promise<FirebaseFirestore.DocumentSnapshot>}
 */
async function assertShopStaff(db, uid, shopId) {
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家");
  }
  const shop = await db.collection("shops").doc(shopId).get();
  if (!shop.exists) {
    throw new HttpsError("not-found", "找不到店家");
  }
  if ((shop.data() || {}).ownerUid === uid) {
    return shop;
  }
  const member = await db.collection("shop_members")
      .doc(shopId + "_" + uid)
      .get();
  if (!member.exists) {
    throw new HttpsError("permission-denied", "沒有這間店的權限");
  }
  return shop;
}

module.exports = {
  loadPlatformUser,
  assertShopStaff,
};
