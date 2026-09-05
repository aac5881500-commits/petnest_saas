// 檔案名稱：functions/payments/submit_payment_setting.js
// 功能說明：驗證店主權限後，安全儲存綠界密鑰與店家金流設定
// 📝 店家綠界金流設定送審
// 並將店家金流狀態更新為等待平台審核。

const admin = require("firebase-admin");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  normalizeString,
} = require("./payment_verify");

/**
 * 將未知資料安全轉成布林值
 *
 * @param {*} value 原始資料
 * @return {boolean}
 */
function normalizeBoolean(value) {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "number") {
    return value === 1;
  }

  const normalizedValue = normalizeString(value).toLowerCase();

  return (
    normalizedValue === "true" ||
    normalizedValue === "1" ||
    normalizedValue === "yes" ||
    normalizedValue === "enabled"
  );
}

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
        "只有店主可以設定綠界金流。",
    );
  }
}

/**
 * 店家送出綠界金流設定審核
 */
exports.submitEcpayPaymentSetting = onCall(
    {
      region: "asia-east1",
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

      const merchantName = normalizeString(
          requestData.merchantName,
      );

      const merchantId = normalizeString(
          requestData.merchantId,
      );

      const hashKey = normalizeString(
          requestData.hashKey,
      );

      const hashIv = normalizeString(
          requestData.hashIv,
      );

      const environment = normalizeString(
          requestData.environment,
      ).toLowerCase();

      const creditCardEnabled = normalizeBoolean(
          requestData.creditCardEnabled,
      );

      const atmEnabled = normalizeBoolean(
          requestData.atmEnabled,
      );

      const cvsCodeEnabled = normalizeBoolean(
          requestData.cvsCodeEnabled,
      );

      if (!shopId) {
        throw new HttpsError(
            "invalid-argument",
            "缺少店家編號。",
        );
      }

      if (!merchantName) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入綠界商店名稱。",
        );
      }

      if (!merchantId) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入 MerchantID。",
        );
      }

      if (!hashKey) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入 HashKey。",
        );
      }

      if (!hashIv) {
        throw new HttpsError(
            "invalid-argument",
            "請輸入 HashIV。",
        );
      }

      if (
        environment !== "test" &&
        environment !== "production"
      ) {
        throw new HttpsError(
            "invalid-argument",
            "綠界環境必須是 test 或 production。",
        );
      }

      if (
        !creditCardEnabled &&
        !atmEnabled &&
        !cvsCodeEnabled
      ) {
        throw new HttpsError(
            "invalid-argument",
            "請至少選擇一種付款方式。",
        );
      }

      await verifyShopOwner({
        shopId,
        userId: request.auth.uid,
      });

      const firestore = admin.firestore();

      const shopRef = firestore
          .collection("shops")
          .doc(shopId);

      const credentialsRef = firestore
          .collection("payment_credentials")
          .doc(shopId);

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

        const currentPaymentSetting =
          rawPaymentSetting &&
          typeof rawPaymentSetting === "object" &&
          !Array.isArray(rawPaymentSetting) ?
            rawPaymentSetting :
            {};

        const previousReviewStatus = normalizeString(
            currentPaymentSetting.reviewStatus,
        ).toLowerCase();

        // 🔐 敏感金流憑證只存放於後端專用集合
        transaction.set(
            credentialsRef,
            {
              shopId,
              merchantId,
              hashKey,
              hashIv,
              environment,
              submittedBy: request.auth.uid,
              updatedAt:
                admin.firestore.FieldValue.serverTimestamp(),
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        );

        // ⚙️ 店家文件只存放可供前台判斷與平台審核的資料
        transaction.set(
            shopRef,
            {
              paymentSetting: {
                provider: "ecpay",
                merchantName,
                merchantId,
                environment,

                reviewStatus: "pending",
                enabled: false,

                enabledMethods: {
                  creditCard: creditCardEnabled,
                  atm: atmEnabled,
                  cvsCode: cvsCodeEnabled,
                },

                creditCardEnabled,
                atmEnabled,
                cvsCodeEnabled,

                previousReviewStatus,
                rejectionReason: null,

                submittedBy: request.auth.uid,
                submittedAt:
                  admin.firestore.FieldValue.serverTimestamp(),

                reviewedBy: null,
                reviewedAt: null,

                updatedAt:
                  admin.firestore.FieldValue.serverTimestamp(),
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
        reviewStatus: "pending",
        message: "綠界金流設定已送出平台審核。",
      };
    },
);
