// 檔案名稱：functions/platform/update_platform_user.js
// 功能說明：一次更新平台人員姓名、角色、權限與啟用狀態，並寫入操作紀錄。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("./inspection_write_guard");
const policy = require("./platform_user_policy");

const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";

/**
 * @param {string} userId 操作者
 * @return {Promise<Object>}
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

  const snapshot = await admin.firestore()
      .collection("platform_users")
      .doc(userId)
      .get();
  if (!snapshot.exists) {
    throw new HttpsError("permission-denied", "你不是平台管理員。");
  }
  const data = snapshot.data() || {};
  return {
    uid: userId,
    isRoot: false,
    role: policy.normalizeString(data.role),
    enabled: data.enabled === true,
    permissions: Array.isArray(data.permissions) ? data.permissions : [],
  };
}

/**
 * 更新既有平台人員。新建帳號仍走 createPlatformUserByEmail。
 */
exports.updatePlatformUser = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入平台管理帳號。");
      }

      const operator = await loadOperator(request.auth.uid);
      const requestData = request.data || {};
      const uid = policy.normalizeString(requestData.uid);
      if (!uid) {
        throw new HttpsError("invalid-argument", "缺少平台人員。");
      }
      if (uid === ROOT_ADMIN_UID) {
        throw new HttpsError(
            "failed-precondition",
            "不能修改永久根管理員。",
        );
      }

      const firestore = admin.firestore();
      const userRef = firestore.collection("platform_users").doc(uid);
      const operatorRef = firestore.collection("platform_users")
          .doc(request.auth.uid);
      const logRef = firestore.collection("action_logs").doc();

      try {
        const result = await firestore.runTransaction(async (transaction) => {
          const currentOperator = operator.isRoot === true ?
            operator :
            await (async () => {
              const operatorSnapshot = await transaction.get(operatorRef);
              if (!operatorSnapshot.exists) {
                throw new Error("你不是平台管理員。");
              }
              const data = operatorSnapshot.data() || {};
              return {
                uid: request.auth.uid,
                isRoot: false,
                role: policy.normalizeString(data.role),
                enabled: data.enabled === true,
                permissions: Array.isArray(data.permissions) ?
                  data.permissions :
                  [],
              };
            })();
          const snapshot = await transaction.get(userRef);
          if (!snapshot.exists) {
            throw new Error("找不到平台人員資料。");
          }
          const current = snapshot.data() || {};
          const plan = policy.planPlatformUserUpdate({
            operator: currentOperator,
            target: {
              uid,
              isRoot: false,
              role: current.role,
              enabled: current.enabled === true,
              permissions: current.permissions,
            },
            name: requestData.name,
            email: requestData.email,
            role: requestData.role,
            enabled: requestData.enabled,
            permissions: requestData.permissions,
          });

          transaction.update(userRef, {
            name: plan.name,
            email: plan.email,
            role: plan.role,
            enabled: plan.enabled,
            permissions: plan.permissions,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedBy: request.auth.uid,
          });
          transaction.set(logRef, {
            shopId: "platform",
            targetType: "platform_user",
            targetId: uid,
            action: "update_platform_user",
            operatorUid: request.auth.uid,
            operatorRole: currentOperator.role,
            payload: {
              previousRole: plan.previousRole,
              nextRole: plan.role,
              previousEnabled: plan.previousEnabled,
              nextEnabled: plan.enabled,
              addedPermissions: plan.added,
              removedPermissions: plan.removed,
              targetName: plan.name,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return plan;
        });

        return {
          success: true,
          uid,
          role: result.role,
          enabled: result.enabled,
          permissions: result.permissions,
          added: result.added,
          removed: result.removed,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        const message = error && error.message ?
          error.message :
          "更新平台人員失敗，請稍後再試。";
        throw new HttpsError("failed-precondition", message);
      }
    },
);
