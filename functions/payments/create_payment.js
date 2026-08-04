// functions/payments/create_payment.js
// 💳 建立綠界付款
// 功能：驗證登入會員、訂單付款資格與付款金額，
// 建立防重複付款紀錄，並產生綠界付款表單 HTML。

const admin = require("firebase-admin");

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  normalizeString,
  resolveDepositAmount,
  resolveRequestedPaymentAmount,
  verifyBookingForPayment,
} = require("./payment_verify");

const {
  createOrGetPendingPayment,
} = require("./payment_record");

const {
  verifyPaymentSettings,
} = require("./payment_settings");

const {
  getEcpayCredentials,
} = require("./payment_credentials");

const {
  createEcpayPaymentHtml,
} = require("./ecpay_client");

/**
 * 建立綠界付款
 *
 * 目前：
 * ✅ 驗證登入
 * ✅ 驗證請求基本資料
 * ✅ 驗證訂單存在與會員身分
 * ✅ 驗證訂單狀態與付款狀態
 * ✅ 後端計算訂金或剩餘全額
 * ✅ 驗證平台及店家金流資格
 * ✅ 建立 payments 付款紀錄
 * ✅ requestId 防止重複付款
 * ✅ 讀取店家綠界後端憑證
 * ✅ 產生綠界付款 HTML
 * ❌ 尚未完成付款 Callback 更新訂單
 */
exports.createEcpayPayment = onCall(
    {
      region: "asia-east1",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "請先登入會員。",
        );
      }

      const requestData = request.data || {};

      const bookingId = normalizeString(
          requestData.bookingId,
      );

      const shopId = normalizeString(
          requestData.shopId,
      );

      const paymentMethod = normalizeString(
          requestData.paymentMethod,
      ).toLowerCase();

      const amountType = normalizeString(
          requestData.amountType,
      ).toLowerCase();

      const requestId = normalizeString(
          requestData.requestId,
      );

      if (!bookingId) {
        throw new HttpsError(
            "invalid-argument",
            "缺少訂單編號。",
        );
      }

      if (!shopId) {
        throw new HttpsError(
            "invalid-argument",
            "缺少店家編號。",
        );
      }

      if (!requestId) {
        throw new HttpsError(
            "invalid-argument",
            "缺少付款請求編號。",
        );
      }

      const allowedPaymentMethods = [
        "credit_card",
        "atm",
        "cvs_code",
      ];

      if (!allowedPaymentMethods.includes(paymentMethod)) {
        throw new HttpsError(
            "invalid-argument",
            "不支援這個付款方式。",
        );
      }

      const allowedAmountTypes = [
        "deposit",
        "full",
      ];

      if (!allowedAmountTypes.includes(amountType)) {
        throw new HttpsError(
            "invalid-argument",
            "付款金額類型不正確。",
        );
      }

      const verifiedBooking = await verifyBookingForPayment({
        bookingId,
        userId: request.auth.uid,
        expectedShopId: shopId,
      });

      const paymentAmount = resolveRequestedPaymentAmount({
        booking: verifiedBooking.booking,
        amountType,
      });

      const depositAmount = resolveDepositAmount(
          verifiedBooking.booking,
      );

      await verifyPaymentSettings({
        shopId: verifiedBooking.shopId,
        paymentMethod,
      });

      const paymentRecord = await createOrGetPendingPayment({
        requestId,
        bookingId: verifiedBooking.bookingId,
        shopId: verifiedBooking.shopId,
        userId: verifiedBooking.userId,
        paymentMethod,
        amountType,
        amount: paymentAmount,
        totalAmount: verifiedBooking.totalAmount,
        paidAmount: verifiedBooking.paidAmount,
      });

      const savedPayment = paymentRecord.payment || {};

      const credentials = await getEcpayCredentials(
          verifiedBooking.shopId,
      );

      const merchantTradeNo = normalizeString(
          savedPayment.merchantTradeNo,
      );

      if (!merchantTradeNo) {
        throw new HttpsError(
            "failed-precondition",
            "付款紀錄缺少綠界交易編號。",
        );
      }

      const paymentHtmlResult = createEcpayPaymentHtml({
        merchantId: credentials.merchantId,
        hashKey: credentials.hashKey,
        hashIv: credentials.hashIv,
        isProduction: credentials.isProduction,
        merchantTradeNo,
        amount: paymentAmount,
        paymentMethod,
        // 🟢 綠界付款完成後的背景通知網址
        // 使用目前 Firebase 專案 petnest-saas 的正式 Function 網址
        returnUrl:
        "https://asia-east1-petnest-saas.cloudfunctions.net/" +
        "ecpayPaymentCallback",
        clientBackUrl: "",
        itemName: "PetNest 寵物住宿訂單",
        tradeDesc: "PetNest 訂單付款",
        customField1: paymentRecord.paymentId,
      });

      await paymentRecord.paymentRef.set(
          {
            status: "pending",
            gatewayStatus: "created",
            paymentHtml: paymentHtmlResult.paymentHtml,
            environment: paymentHtmlResult.environment,
            merchantTradeNo:
              paymentHtmlResult.merchantTradeNo,
            merchantTradeDate:
              paymentHtmlResult.merchantTradeDate,
            ecpayPaymentMethod:
              paymentHtmlResult.ecpayPaymentMethod,
            updatedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
      );

      return {
        success: true,
        message: paymentRecord.isExisting ?
          "已取得原本的付款紀錄" :
          "付款紀錄與綠界付款表單建立成功",

        paymentId: paymentRecord.paymentId,
        paymentHtml: paymentHtmlResult.paymentHtml,
        merchantTradeNo:
          paymentHtmlResult.merchantTradeNo,
        merchantTradeDate:
          paymentHtmlResult.merchantTradeDate,
        environment:
          paymentHtmlResult.environment,

        bookingId: verifiedBooking.bookingId,
        shopId: verifiedBooking.shopId,
        userId: verifiedBooking.userId,

        paymentMethod,
        amountType,
        amount: paymentAmount,
        status: "pending",
        requestId,

        totalAmount: verifiedBooking.totalAmount,
        depositAmount,
        paidAmount: verifiedBooking.paidAmount,
        remainingAmount:
          verifiedBooking.remainingAmount,

        isExisting: paymentRecord.isExisting,
      };
    },
);
