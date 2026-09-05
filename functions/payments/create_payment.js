// 檔案名稱：functions/payments/create_payment.js
// 功能說明：驗證登入會員、訂單付款資格與付款金額
// 💳 建立綠界付款
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
  verifyStoreOrderForPayment,
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

const {
  prepareReservationForPayment,
} = require("../store/store_inventory");

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
 * ✅ 付款 Callback 更新付款與訂單彙總狀態
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

      const sourceTypeRaw = normalizeString(
          requestData.sourceType,
      ).toLowerCase();

      const sourceType = sourceTypeRaw === "store_order" ?
        "store_order" :
        "booking";

      const sourceId = normalizeString(
          requestData.sourceId,
      ) || (sourceType === "store_order" ? "" : bookingId);

      const shopId = normalizeString(
          requestData.shopId,
      );

      const paymentMethod = normalizeString(
          requestData.paymentMethod,
      ).toLowerCase();

      const amountType = normalizeString(
          requestData.amountType,
      ).toLowerCase();

      const requestedPaymentPurpose = normalizeString(
          requestData.paymentPurpose,
      ).toLowerCase();

      const paymentPurpose = requestedPaymentPurpose ||
        (amountType === "deposit" ? "deposit" : "full");

      const requestId = normalizeString(
          requestData.requestId,
      );

      if (sourceType === "store_order") {
        if (!sourceId) {
          throw new HttpsError(
              "invalid-argument",
              "缺少商城訂單編號。",
          );
        }
      } else if (!bookingId) {
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

      const allowedPaymentPurposes = [
        "deposit",
        "balance",
        "full",
        "additional",
        "other",
      ];

      if (!allowedPaymentPurposes.includes(paymentPurpose)) {
        throw new HttpsError(
            "invalid-argument",
            "付款用途不正確。",
        );
      }

      let verifiedShopId = "";
      let verifiedUserId = "";
      let paymentAmount = 0;
      let totalAmount = 0;
      let paidAmount = 0;
      let itemName = "PetNest Booking";
      let storeOrderId = "";
      let storeOrderCode = "";
      let resolvedBookingId = bookingId;
      let resolvedAmountType = amountType;
      let resolvedPaymentPurpose = paymentPurpose;

      if (sourceType === "store_order") {
        const verifiedOrder = await verifyStoreOrderForPayment({
          shopId,
          orderId: sourceId,
          userId: request.auth.uid,
        });

        verifiedShopId = verifiedOrder.shopId;
        verifiedUserId = verifiedOrder.userId;
        paymentAmount = verifiedOrder.totalAmount;
        totalAmount = verifiedOrder.totalAmount;
        paidAmount = 0;
        itemName = "PetNest Store";
        storeOrderId = verifiedOrder.orderId;
        storeOrderCode = verifiedOrder.orderCode;
        resolvedBookingId = "";
        resolvedAmountType = "full";
        resolvedPaymentPurpose = "full";

        const extraMinutes = paymentMethod === "credit_card" ? 30 : 3 * 24 * 60;
        const reservationOutcome = await admin.firestore()
            .runTransaction(async (transaction) => {
              return prepareReservationForPayment({
                transaction,
                shopId: verifiedShopId,
                orderId: storeOrderId,
                expireAt: new Date(Date.now() + extraMinutes * 60 * 1000),
                userId: request.auth.uid,
              });
            });
        if (!reservationOutcome.held) {
          throw new HttpsError(
              "deadline-exceeded",
              "庫存保留已過期，請重新下單。",
          );
        }
      } else {
        const verifiedBooking = await verifyBookingForPayment({
          bookingId,
          userId: request.auth.uid,
          expectedShopId: shopId,
        });

        paymentAmount = resolveRequestedPaymentAmount({
          booking: verifiedBooking.booking,
          amountType,
        });

        resolveDepositAmount(verifiedBooking.booking);

        verifiedShopId = verifiedBooking.shopId;
        verifiedUserId = verifiedBooking.userId;
        totalAmount = verifiedBooking.totalAmount;
        paidAmount = verifiedBooking.paidAmount;
        resolvedBookingId = verifiedBooking.bookingId;
      }

      await verifyPaymentSettings({
        shopId: verifiedShopId,
        paymentMethod,
      });

      const paymentRecord = await createOrGetPendingPayment({
        requestId,
        bookingId: resolvedBookingId,
        shopId: verifiedShopId,
        userId: verifiedUserId,
        paymentMethod,
        amountType: resolvedAmountType,
        paymentPurpose: resolvedPaymentPurpose,
        amount: paymentAmount,
        totalAmount,
        paidAmount,
        sourceType,
        sourceId: sourceType === "store_order" ?
          storeOrderId :
          resolvedBookingId,
        storeOrderId,
        storeOrderCode,
      });

      const savedPayment = paymentRecord.payment || {};

      const credentials = await getEcpayCredentials(
          verifiedShopId,
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
        itemName,
        tradeDesc: "PetNest Payment",
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

        bookingId: resolvedBookingId,
        shopId: verifiedShopId,
        userId: verifiedUserId,
        sourceType,
        sourceId: sourceType === "store_order" ?
          storeOrderId :
          resolvedBookingId,
        storeOrderId,
        storeOrderCode,

        paymentMethod,
        amountType: resolvedAmountType,
        paymentPurpose: resolvedPaymentPurpose,
        amount: paymentAmount,
        status: "pending",
        requestId,

        totalAmount,
        paidAmount,
        remainingAmount: Math.max(totalAmount - paidAmount, 0),

        isExisting: paymentRecord.isExisting,
      };
    },
);
