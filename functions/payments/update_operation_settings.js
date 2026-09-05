// 檔案名稱：functions/payments/update_operation_settings.js
// 功能說明：由店主安全更新銀行轉帳與綠界付款營運開關
// ⚙️ 店家收款方式營運設定
// 到店付款固定啟用，綠界未核准時不得啟用線上付款。

const admin = require("firebase-admin");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 驗證目前登入使用者是否為店主
 *
 * Firestore：
 * shop_members/{shopId}_{uid}
 *
 * @param {string} shopId 店家 ID
 * @param {string} userId Firebase Auth UID
 * @return {Promise<void>}
 */
async function verifyShopOwner({
  shopId,
  userId,
}) {
  const memberId = `${shopId}_${userId}`;

  const memberSnapshot = await admin
      .firestore()
      .collection("shop_members")
      .doc(memberId)
      .get();

  if (!memberSnapshot.exists) {
    throw new HttpsError(
        "permission-denied",
        "你不是這間店家的成員。",
    );
  }

  const member = memberSnapshot.data() || {};

  const role = normalizeString(
      member.role,
  ).toLowerCase();

  if (role !== "owner") {
    throw new HttpsError(
        "permission-denied",
        "只有店主可以修改收款方式。",
    );
  }
}

/**
 * 更新店家收款方式營運設定
 */
exports.updatePaymentOperationSettings = onCall(
    {
      region: "asia-east1",
      invoker: "public",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "請先登入店家帳號。",
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

      await verifyShopOwner({
        shopId,
        userId: request.auth.uid,
      });

      const bankTransferEnabled =
        requestData.bankTransferEnabled === true;

      const requestedEcpayEnabled =
        requestData.ecpayEnabled === true;

      const creditCardEnabled =
        requestData.creditCardEnabled === true;

      const atmEnabled =
        requestData.atmEnabled === true;

      const cvsCodeEnabled =
        requestData.cvsCodeEnabled === true;

      const shopRef = admin
          .firestore()
          .collection("shops")
          .doc(shopId);

      await admin.firestore().runTransaction(async (transaction) => {
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

        const platformSuspended =
          paymentSetting.platformSuspended === true;

        const shopDisabled =
          paymentSetting.shopDisabled === true;

        if (
          requestedEcpayEnabled &&
          reviewStatus !== "approved"
        ) {
          throw new HttpsError(
              "failed-precondition",
              "綠界尚未通過平台審核，無法啟用線上付款。",
          );
        }

        if (
          requestedEcpayEnabled &&
          (platformSuspended || shopDisabled)
        ) {
          throw new HttpsError(
              "failed-precondition",
              "綠界金流目前已停用，無法啟用線上付款。",
          );
        }

        transaction.set(
            shopRef,
            {
              paymentSetting: {
                operationSettings: {
                  // 🏪 到店付款固定啟用
                  cashPaymentEnabled: true,

                  bankTransferEnabled,

                  ecpayEnabled:
                    requestedEcpayEnabled,

                  creditCardEnabled,
                  atmEnabled,
                  cvsCodeEnabled,

                  updatedAt:
                    admin.firestore.FieldValue.serverTimestamp(),
                },
              },
              updatedAt:
                admin.firestore.FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );
      });

      return {
        success: true,
        shopId,
      };
    },
);
