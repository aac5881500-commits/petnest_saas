// functions/payments/review_payment_setting.js
// ✅ 平台綠界金流審核 Function
// 功能：驗證平台管理權限後，核准店家的綠界金流申請，
// 並記錄審核人、審核時間與操作紀錄。

const admin = require("firebase-admin");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const PLATFORM_PERMISSION_ALL = "all";
const REVIEW_PAYMENT_PERMISSION = "review_payment_applications";
const SUPER_ADMIN_ROLE = "super_admin";

// 👑 PetNest 永久最高管理員 UID
// 功能：即使 platform_users 文件遺失，根管理員仍可執行平台操作。
// 注意：此 UID 必須與 Flutter 的 PlatformRootAdmin.uid 保持一致。
const ROOT_ADMIN_UID = "7FNrECQeqAca9Vu8lBBzTSdcJcg1";
/**
 * 將未知資料安全轉為字串
 *
 * @param {*} value 原始資料
 * @return {string}
 */
function normalizeString(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return value.toString().trim();
}

/**
 * 將權限資料安全轉為字串陣列
 *
 * @param {*} value 原始權限資料
 * @return {string[]}
 */
function normalizePermissions(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
      .map((permission) => normalizeString(permission))
      .filter((permission) => permission.length > 0);
}

/**
 * 驗證目前登入者是否有金流審核權限
 *
 * 權限來源：
 * 1. 永久 Root Admin UID
 * 2. platform_users/{uid}
 *
 * @param {string} userId Firebase Auth UID
 * @return {Promise<void>}
 */
async function verifyPaymentReviewer(userId) {
  // 👑 永久最高管理員直接具有全部平台權限
  if (userId === ROOT_ADMIN_UID) {
    return;
  }

  // 🔐 讀取目前正式的平台管理員資料
  const adminSnapshot = await admin
      .firestore()
      .collection("platform_users")
      .doc(userId)
      .get();

  if (!adminSnapshot.exists) {
    throw new HttpsError(
        "permission-denied",
        "你不是平台管理員。",
    );
  }

  const platformAdmin = adminSnapshot.data() || {};

  // 🚫 已停用的平台帳號不可進行審核
  if (platformAdmin.enabled !== true) {
    throw new HttpsError(
        "permission-denied",
        "你的平台管理權限目前已停用。",
    );
  }

  const role = normalizeString(
      platformAdmin.role,
  ).toLowerCase();

  const permissions = normalizePermissions(
      platformAdmin.permissions,
  );

  // ✅ 最高管理員、全部權限或金流審核權限皆可核准
  const hasPermission =
    role === SUPER_ADMIN_ROLE ||
    permissions.includes(PLATFORM_PERMISSION_ALL) ||
    permissions.includes(REVIEW_PAYMENT_PERMISSION);

  if (!hasPermission) {
    throw new HttpsError(
        "permission-denied",
        "你沒有審核店家金流申請的權限。",
    );
  }
}

/**
 * 核准店家的綠界金流申請
 */
exports.approveEcpayPaymentSetting = onCall(
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

      const requestData = request.data || {};

      const shopId = normalizeString(
          requestData.shopId,
      );

      if (!shopId) {
        throw new HttpsError(
            "invalid-argument",
            "缺少店家編號。",
        );
      }

      await verifyPaymentReviewer(
          request.auth.uid,
      );

      const firestore = admin.firestore();

      const shopRef = firestore
          .collection("shops")
          .doc(shopId);

      const reviewLogRef = firestore
          .collection("payment_review_logs")
          .doc();

      await firestore.runTransaction(async (transaction) => {
        const shopSnapshot = await transaction.get(shopRef);

        if (!shopSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "找不到指定的店家。",
          );
        }

        const shop = shopSnapshot.data() || {};

        const rawPaymentSetting = shop.paymentSetting;

        const paymentSetting =
          rawPaymentSetting &&
          typeof rawPaymentSetting === "object" &&
          !Array.isArray(rawPaymentSetting) ?
            rawPaymentSetting :
            {};

        const reviewStatus = normalizeString(
            paymentSetting.reviewStatus,
        ).toLowerCase();

        if (reviewStatus !== "pending") {
          throw new HttpsError(
              "failed-precondition",
              "只有等待審核中的申請可以核准。",
          );
        }

        const now =
          admin.firestore.FieldValue.serverTimestamp();

        // ✅ 更新店家金流審核狀態
        transaction.update(shopRef, {
          "paymentSetting.reviewStatus": "approved",
          "paymentSetting.enabled": true,
          "paymentSetting.reviewedBy": request.auth.uid,
          "paymentSetting.reviewedAt": now,
          "paymentSetting.approvedBy": request.auth.uid,
          "paymentSetting.approvedAt": now,
          "paymentSetting.rejectionReason": null,
          "paymentSetting.updatedAt": now,
          "updatedAt": now,
        });

        // 📜 保留平台金流審核紀錄
        transaction.set(reviewLogRef, {
          shopId,
          action: "approved",
          previousStatus: reviewStatus,
          newStatus: "approved",
          operatedBy: request.auth.uid,
          createdAt: now,
        });
      });

      return {
        success: true,
        shopId,
        reviewStatus: "approved",
        message: "店家綠界金流已核准。",
      };
    },
);
