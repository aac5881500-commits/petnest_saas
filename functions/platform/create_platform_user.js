// 檔案名稱：functions/platform/create_platform_user.js
// 功能說明：由具備平台人員管理權限的管理員輸入 Email
// ➕ 使用 Email 新增平台人員
// 後端透過 Firebase Authentication 查找 UID，
// 再建立 platform_users/{uid} 權限資料。

const admin = require("firebase-admin");

const {
  onCall,
  HttpsError,
} = require("./inspection_write_guard");

const policy = require("./platform_user_policy");

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";

/**
 * 將未知資料安全轉成字串
 *
 * @param {*} value 原始資料
 * @return {string}
 */
function normalizeString(value) {
  return policy.normalizeString(value);
}

/**
 * 將 Email 正規化
 *
 * @param {*} value 原始 Email
 * @return {string}
 */
function normalizeEmail(value) {
  return normalizeString(value).toLowerCase();
}

/**
 * 驗證目前登入者是否可管理平台人員
 *
 * @param {string} userId 操作者 Firebase UID
 * @return {Promise<void>}
 */
async function loadOperator(userId) {
  if (userId === ROOT_ADMIN_UID) {
    return {
      uid: userId,
      isRoot: true,
      role: policy.SUPER_ADMIN_ROLE,
      enabled: true,
      permissions: [],
    };
  }

  const snapshot = await admin
      .firestore()
      .collection("platform_users")
      .doc(userId)
      .get();

  if (!snapshot.exists) {
    throw new HttpsError(
        "permission-denied",
        "你不是平台管理員。",
    );
  }

  const platformAdmin = snapshot.data() || {};
  const operator = {
    uid: userId,
    isRoot: false,
    role: normalizeString(platformAdmin.role),
    enabled: platformAdmin.enabled === true,
    permissions: Array.isArray(platformAdmin.permissions) ?
      platformAdmin.permissions :
      [],
  };

  if (operator.enabled !== true) {
    throw new HttpsError(
        "permission-denied",
        "你的平台管理帳號目前已停用。",
    );
  }

  if (!policy.canManagePlatformUsers(operator)) {
    throw new HttpsError(
        "permission-denied",
        "你沒有管理平台人員的權限。",
    );
  }

  return operator;
}

/**
 * 使用 Email 新增平台人員
 */
exports.createPlatformUserByEmail = onCall(
    {
      region: "asia-east1",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "請先登入平台管理帳號。",
        );
      }

      const operator = await loadOperator(
          request.auth.uid,
      );

      const requestData = request.data || {};

      const email = normalizeEmail(
          requestData.email,
      );

      const name = normalizeString(
          requestData.name,
      );

      const role = normalizeString(
          requestData.role,
      );

      const enabled = requestData.enabled === true;

      const permissions = policy.grantablePermissions(
          operator,
          requestData.permissions,
      );

      if (!email) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入員工 Email。",
        );
      }

      const emailPattern =
        /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

      if (!emailPattern.test(email)) {
        throw new HttpsError(
            "invalid-argument",
            "Email 格式不正確。",
        );
      }

      if (!name) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入姓名或稱呼。",
        );
      }

      if (!policy.ALLOWED_ROLES.includes(role)) {
        throw new HttpsError(
            "invalid-argument",
            "平台角色不正確。",
        );
      }

      let authUser;

      try {
        authUser = await admin
            .auth()
            .getUserByEmail(email);
      } catch (error) {
        if (
          error &&
          error.code === "auth/user-not-found"
        ) {
          throw new HttpsError(
              "not-found",
              "找不到此 Email 的 PetNest 帳號，請先請員工完成註冊。",
          );
        }

        console.error(
            "查詢 Firebase Authentication 使用者失敗",
            error,
        );

        throw new HttpsError(
            "internal",
            "查詢員工帳號失敗，請稍後再試。",
        );
      }

      const uid = authUser.uid;

      if (uid === ROOT_ADMIN_UID) {
        throw new HttpsError(
            "failed-precondition",
            "此帳號已是永久根管理員，不需要再次新增。",
        );
      }

      const firestore = admin.firestore();

      const platformUserRef = firestore
          .collection("platform_users")
          .doc(uid);

      await firestore.runTransaction(
          async (transaction) => {
            const existingSnapshot =
              await transaction.get(platformUserRef);

            if (existingSnapshot.exists) {
              throw new HttpsError(
                  "already-exists",
                  "此帳號已經是平台人員，請改到編輯頁修改權限。",
              );
            }

            const now =
              admin.firestore.FieldValue
                  .serverTimestamp();

            transaction.create(
                platformUserRef,
                {
                  uid,
                  name,
                  email:
                    normalizeEmail(
                        authUser.email || email,
                    ),
                  role,
                  enabled,
                  permissions,
                  createdAt: now,
                  createdBy: request.auth.uid,
                  updatedAt: now,
                  updatedBy: request.auth.uid,
                },
            );
          },
      );

      return {
        success: true,
        uid,
        email:
          normalizeEmail(
              authUser.email || email,
          ),
        displayName:
          normalizeString(
              authUser.displayName,
          ),
        message: "平台人員已建立。",
      };
    },
);
