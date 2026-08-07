// functions/payments/payment_callback.js
// 🟢 綠界付款完成 Callback
// 功能：接收綠界付款通知、驗證交易資料與 CheckMacValue，
// 並在付款成功後同步更新 payments 與 bookings 的付款狀態。

const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const {
  normalizeInteger,
  normalizeString,
} = require("./payment_verify");

const {
  getEcpayCredentials,
} = require("./payment_credentials");

const {
  verifyCheckMacValue,
} = require("./ecpay_mac");

/**
 * 回覆綠界通知結果
 *
 * @param {Object} res Express response
 * @param {string} value 回覆內容
 * @return {void}
 */
function sendCallbackResponse(res, value) {
  res
      .status(200)
      .type("text/plain")
      .send(value);
}

/**
 * 綠界付款完成通知
 */
exports.ecpayPaymentCallback = onRequest(
    {
      region: "asia-east1",

      /*
       * 綠界 Callback 是由綠界伺服器直接呼叫，
       * 不會攜帶 Firebase Auth Token。
       *
       * 因此必須允許公開呼叫，
       * 實際安全性由 CheckMacValue、交易編號、
       * Payment ID 與付款金額驗證負責。
       */
      invoker: "public",
    },
    async (req, res) => {
      try {
        if (req.method !== "POST") {
          res
              .status(405)
              .type("text/plain")
              .send("Method Not Allowed");
          return;
        }

        const callbackData = req.body || {};

        const paymentId = normalizeString(
            callbackData.CustomField1,
        );

        const merchantTradeNo = normalizeString(
            callbackData.MerchantTradeNo,
        );

        if (!paymentId) {
          console.error(
              "ECPay Callback 缺少 CustomField1",
              callbackData,
          );

          sendCallbackResponse(
              res,
              "0|MissingPaymentId",
          );
          return;
        }

        if (!merchantTradeNo) {
          console.error(
              "ECPay Callback 缺少 MerchantTradeNo",
              callbackData,
          );

          sendCallbackResponse(
              res,
              "0|MissingTradeNo",
          );
          return;
        }

        const firestore = admin.firestore();

        const paymentRef = firestore
            .collection("payments")
            .doc(paymentId);

        const paymentSnapshot = await paymentRef.get();

        if (!paymentSnapshot.exists) {
          console.error(
              "ECPay Callback 找不到付款紀錄",
              {
                paymentId,
                merchantTradeNo,
              },
          );

          sendCallbackResponse(
              res,
              "0|PaymentNotFound",
          );
          return;
        }

        const payment = paymentSnapshot.data() || {};

        const savedMerchantTradeNo = normalizeString(
            payment.merchantTradeNo,
        );

        if (
          !savedMerchantTradeNo ||
          savedMerchantTradeNo !== merchantTradeNo
        ) {
          console.error(
              "ECPay Callback 交易編號不一致",
              {
                paymentId,
                merchantTradeNo,
                savedMerchantTradeNo,
              },
          );

          sendCallbackResponse(
              res,
              "0|TradeNoMismatch",
          );
          return;
        }

        const shopId = normalizeString(
            payment.shopId,
        );

        if (!shopId) {
          console.error(
              "ECPay Callback 付款紀錄缺少 shopId",
              {
                paymentId,
                merchantTradeNo,
              },
          );

          sendCallbackResponse(
              res,
              "0|MissingShopId",
          );
          return;
        }

        const credentials = await getEcpayCredentials(
            shopId,
        );

        const checkMacValueValid = verifyCheckMacValue({
          data: callbackData,
          hashKey: credentials.hashKey,
          hashIv: credentials.hashIv,
        });

        if (!checkMacValueValid) {
          console.error(
              "ECPay Callback CheckMacValue 驗證失敗",
              {
                paymentId,
                merchantTradeNo,
                shopId,
              },
          );

          await paymentRef.set(
              {
                gatewayStatus:
                  "invalid_check_mac_value",
                callbackReceivedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
                updatedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
              },
              {
                merge: true,
              },
          );

          sendCallbackResponse(
              res,
              "0|CheckMacValueError",
          );
          return;
        }

        const rtnCode = normalizeString(
            callbackData.RtnCode,
        );

        const rtnMessage = normalizeString(
            callbackData.RtnMsg,
        );

        const gatewayTradeNo = normalizeString(
            callbackData.TradeNo,
        );

        const callbackAmount = normalizeInteger(
            callbackData.TradeAmt,
        );

        const expectedAmount = normalizeInteger(
            payment.amount,
        );

        const bookingId = normalizeString(
            payment.bookingId,
        );

        if (!bookingId) {
          console.error(
              "ECPay Callback 付款紀錄缺少 bookingId",
              {
                paymentId,
                merchantTradeNo,
              },
          );

          sendCallbackResponse(
              res,
              "0|MissingBookingId",
          );
          return;
        }

        if (
          callbackAmount <= 0 ||
          callbackAmount !== expectedAmount
        ) {
          console.error(
              "ECPay Callback 付款金額不一致",
              {
                paymentId,
                merchantTradeNo,
                callbackAmount,
                expectedAmount,
              },
          );

          await paymentRef.set(
              {
                gatewayStatus: "amount_mismatch",
                callbackAmount,
                expectedAmount,
                callbackData,
                callbackReceivedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
                updatedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
              },
              {
                merge: true,
              },
          );

          sendCallbackResponse(
              res,
              "0|AmountMismatch",
          );
          return;
        }

        /*
         * 綠界 RtnCode = 1 才代表付款成功。
         * 其他狀態只更新付款紀錄，不增加訂單已付款金額。
         */
        if (rtnCode !== "1") {
          await paymentRef.set(
              {
                status: "failed",
                gatewayStatus: "payment_failed",
                gatewayRtnCode: rtnCode,
                gatewayRtnMessage: rtnMessage,
                gatewayTradeNo,
                callbackAmount,
                callbackData,
                callbackReceivedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
                updatedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
              },
              {
                merge: true,
              },
          );

          /*
           * Callback 已成功收到並完成驗證，
           * 即使付款失敗，也回覆 1|OK，
           * 避免綠界持續重送同一筆通知。
           */
          sendCallbackResponse(
              res,
              "1|OK",
          );
          return;
        }

        const bookingRef = firestore
            .collection("bookings")
            .doc(bookingId);

        await firestore.runTransaction(
            async (transaction) => {
              const latestPaymentSnapshot =
                await transaction.get(paymentRef);

              const bookingSnapshot =
                await transaction.get(bookingRef);

              if (!latestPaymentSnapshot.exists) {
                throw new Error(
                    "付款紀錄不存在。",
                );
              }

              if (!bookingSnapshot.exists) {
                throw new Error(
                    "訂單不存在。",
                );
              }

              const latestPayment =
                latestPaymentSnapshot.data() || {};

              const booking =
                bookingSnapshot.data() || {};

              /*
               * 綠界可能重複發送 Callback。
               * 已付款完成時直接結束，
               * 不再次增加 booking.paidAmount。
               */
              if (
                normalizeString(
                    latestPayment.status,
                ) === "paid"
              ) {
                return;
              }

              const latestMerchantTradeNo =
                normalizeString(
                    latestPayment.merchantTradeNo,
                );

              if (
                latestMerchantTradeNo !==
                merchantTradeNo
              ) {
                throw new Error(
                    "交易編號已變更，停止更新訂單。",
                );
              }

              const latestExpectedAmount =
                normalizeInteger(
                    latestPayment.amount,
                );

              if (
                latestExpectedAmount !==
                callbackAmount
              ) {
                throw new Error(
                    "付款紀錄金額與 Callback 不一致。",
                );
              }

              const rawBookingTotalAmount =
  booking.totalPayableAmount !== undefined &&
  booking.totalPayableAmount !== null ?
    booking.totalPayableAmount :
    booking.totalPrice !== undefined &&
    booking.totalPrice !== null ?
      booking.totalPrice :
      booking.totalAmount !== undefined &&
      booking.totalAmount !== null ?
        booking.totalAmount :
        booking.total;

              const bookingTotalAmount = normalizeInteger(
                  rawBookingTotalAmount,
              );

              if (bookingTotalAmount <= 0) {
                throw new Error(
                    "訂單總金額不正確，停止更新付款彙總。",
                );
              }
              const currentPaidAmount =
                normalizeInteger(
                    booking.paidAmount,
                );

              const newPaidAmount =
                currentPaidAmount +
                callbackAmount;

              const safePaidAmount =
                bookingTotalAmount > 0 ?
                  Math.min(
                      newPaidAmount,
                      bookingTotalAmount,
                  ) :
                  newPaidAmount;

              const remainingAmount =
                bookingTotalAmount > 0 ?
                  Math.max(
                      bookingTotalAmount -
                      safePaidAmount,
                      0,
                  ) :
                  0;

              const paymentStatus =
                remainingAmount <= 0 ?
                  "paid" :
                  "partially_paid";

              transaction.set(
                  paymentRef,
                  {
                    status: "paid",
                    gatewayStatus:
                      "payment_success",
                    gatewayRtnCode: rtnCode,
                    gatewayRtnMessage:
                      rtnMessage,
                    gatewayTradeNo,
                    callbackAmount,
                    callbackData,
                    paidAt:
                      admin.firestore.FieldValue
                          .serverTimestamp(),
                    callbackReceivedAt:
                      admin.firestore.FieldValue
                          .serverTimestamp(),
                    updatedAt:
                      admin.firestore.FieldValue
                          .serverTimestamp(),
                  },
                  {
                    merge: true,
                  },
              );

              const lastPaymentMethod =
                normalizeString(
                    latestPayment.paymentMethod,
                );

              const lastPaymentPurpose =
                normalizeString(
                    latestPayment.paymentPurpose,
                );

              const bookingUpdate = {
                paidAmount: safePaidAmount,
                remainingAmount,
                paymentStatus,

                /*
                 * 最近一筆成功付款摘要。
                 *
                 * Booking 只保存付款彙總，
                 * 完整付款資料仍以 payments 集合為準。
                 */
                lastPaymentId: paymentId,
                lastMerchantTradeNo:
                  merchantTradeNo,
                lastPaymentAmount:
                  callbackAmount,
                lastPaymentMethod,
                lastPaymentPurpose,

                paymentUpdatedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
                updatedAt:
                  admin.firestore.FieldValue
                      .serverTimestamp(),
              };

              if (remainingAmount <= 0) {
                bookingUpdate.paidAt =
                  admin.firestore.FieldValue
                      .serverTimestamp();
              }

              transaction.set(
                  bookingRef,
                  bookingUpdate,
                  {
                    merge: true,
                  },
              );
            },
        );

        sendCallbackResponse(
            res,
            "1|OK",
        );
      } catch (error) {
        console.error(
            "ECPay Callback 發生錯誤",
            error,
        );

        sendCallbackResponse(
            res,
            "0|Error",
        );
      }
    },
);
