// 檔案名稱：functions/payments/payment_callback.js
// 功能說明：接收綠界付款通知、驗證交易資料與 CheckMacValue
// 🟢 綠界付款完成 Callback
// 並在付款成功後同步更新 payments 與 bookings 的付款狀態。
// 注意：僅使用 Callback 做驗證與必要欄位同步，
// 不永久保存完整 Callback 原始資料。

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

const {
  convertReservationToDeduct,
} = require("../store/store_inventory");

const {
  buildSuccessfulEcpayBookingPaymentUpdates,
  resolvePaymentBookingId,
} = require("./apply_booking_payment");

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
              {
                paymentId,
              },
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

        const sourceType = normalizeString(
            payment.sourceType,
        ).toLowerCase() === "store_order" ?
          "store_order" :
          "booking";

        const bookingId = resolvePaymentBookingId(payment);

        const storeOrderId = normalizeString(
            payment.storeOrderId || payment.sourceId,
        );

        if (sourceType === "booking" && !bookingId) {
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

        if (sourceType === "store_order" && !storeOrderId) {
          console.error(
              "ECPay Callback 付款紀錄缺少 storeOrderId",
              {
                paymentId,
                merchantTradeNo,
              },
          );

          sendCallbackResponse(
              res,
              "0|MissingStoreOrderId",
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

        if (sourceType === "store_order") {
          const orderRef = firestore
              .collection("shops")
              .doc(shopId)
              .collection("store_orders")
              .doc(storeOrderId);

          await firestore.runTransaction(async (transaction) => {
            const latestPaymentSnapshot =
              await transaction.get(paymentRef);
            const orderSnapshot = await transaction.get(orderRef);

            if (!latestPaymentSnapshot.exists) {
              throw new Error("付款紀錄不存在。");
            }

            if (!orderSnapshot.exists) {
              throw new Error("商城訂單不存在。");
            }

            const latestPayment = latestPaymentSnapshot.data() || {};
            const order = orderSnapshot.data() || {};
            const orderStatus = normalizeString(order.status);

            if (normalizeString(latestPayment.status) === "paid") {
              return;
            }

            if (normalizeInteger(latestPayment.amount) !== callbackAmount) {
              throw new Error("付款紀錄金額與 Callback 不一致。");
            }

            if (orderStatus === "cancelled") {
              transaction.set(paymentRef, {
                status: "paid",
                gatewayStatus: "payment_success_order_cancelled",
                gatewayRtnCode: rtnCode,
                gatewayRtnMessage: rtnMessage,
                gatewayTradeNo,
                storeOrderCode: normalizeString(order.orderCode),
                callbackAmount,
                paidAt: admin.firestore.FieldValue.serverTimestamp(),
                callbackReceivedAt:
                  admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});
              return;
            }

            if (normalizeString(order.paymentStatus) === "paid") {
              transaction.set(paymentRef, {
                status: "paid",
                gatewayStatus: "payment_success",
                gatewayRtnCode: rtnCode,
                gatewayRtnMessage: rtnMessage,
                gatewayTradeNo,
                storeOrderCode: normalizeString(order.orderCode),
                callbackAmount,
                paidAt: admin.firestore.FieldValue.serverTimestamp(),
                callbackReceivedAt:
                  admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});
              return;
            }

            await convertReservationToDeduct({
              transaction,
              shopId,
              orderId: storeOrderId,
              userId: normalizeString(order.userId),
            });

            transaction.set(paymentRef, {
              status: "paid",
              gatewayStatus: "payment_success",
              gatewayRtnCode: rtnCode,
              gatewayRtnMessage: rtnMessage,
              gatewayTradeNo,
              storeOrderCode: normalizeString(order.orderCode),
              callbackAmount,
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              callbackReceivedAt:
                admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});

            transaction.set(orderRef, {
              status: "paid",
              paymentStatus: "paid",
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
              lastPaymentId: paymentId,
              lastMerchantTradeNo: merchantTradeNo,
              lastGatewayTradeNo: gatewayTradeNo,
              lastPaymentAmount: callbackAmount,
              lastPaymentMethod: normalizeString(latestPayment.paymentMethod),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});
          });

          sendCallbackResponse(res, "1|OK");
          return;
        }

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

              const outcome =
                buildSuccessfulEcpayBookingPaymentUpdates({
                  payment: latestPayment,
                  booking,
                  paymentId,
                  merchantTradeNo,
                  gatewayTradeNo,
                  callbackAmount,
                });

              if (outcome.alreadyPaid) {
                return;
              }

              const now =
                admin.firestore.FieldValue.serverTimestamp();

              transaction.set(
                  paymentRef,
                  {
                    ...outcome.paymentUpdate,
                    gatewayRtnCode: rtnCode,
                    gatewayRtnMessage: rtnMessage,
                    paidAt: now,
                    callbackReceivedAt: now,
                    updatedAt: now,
                  },
                  {merge: true},
              );

              const bookingUpdate = {
                ...outcome.bookingUpdate,
                paymentUpdatedAt: now,
                updatedAt: now,
              };
              delete bookingUpdate.markPaidAt;
              delete bookingUpdate.markDepositPaidAt;
              delete bookingUpdate.markConfirmedAt;

              if (outcome.bookingUpdate.markPaidAt) {
                bookingUpdate.paidAt = now;
              }
              if (outcome.bookingUpdate.markDepositPaidAt) {
                bookingUpdate.depositPaidAt = now;
              }
              if (outcome.bookingUpdate.markConfirmedAt) {
                bookingUpdate.confirmedAt = now;
              }

              transaction.set(
                  bookingRef,
                  bookingUpdate,
                  {merge: true},
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
