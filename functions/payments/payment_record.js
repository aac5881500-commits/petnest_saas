// 檔案名稱：functions/payments/payment_record.js
// 功能說明：使用 requestId 建立固定付款紀錄
// 🧾 金流付款紀錄工具
// 並透過 Firestore Transaction 防止重複付款請求。

const crypto = require("crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const {
  normalizeInteger,
  normalizeString,
} = require("./payment_verify");

const {
  createMerchantTradeNo,
} = require("./ecpay_utils");

/**
 * 使用會員 UID 與 requestId 產生固定 paymentId
 *
 * 相同會員使用相同 requestId 時，
 * 永遠會得到相同 paymentId。
 *
 * @param {Object} params 參數
 * @param {string} params.userId 會員 UID
 * @param {string} params.requestId 前端付款請求 ID
 * @return {string}
 */
function createPaymentId({
  userId,
  requestId,
}) {
  const normalizedUserId = normalizeString(userId);
  const normalizedRequestId = normalizeString(requestId);

  if (!normalizedUserId || !normalizedRequestId) {
    throw new HttpsError(
        "invalid-argument",
        "無法建立付款識別碼。",
    );
  }

  const hash = crypto
      .createHash("sha256")
      .update(`${normalizedUserId}:${normalizedRequestId}`)
      .digest("hex");

  return `pay_${hash.substring(0, 40)}`;
}

/**
 * 解析付款用途
 *
 * 舊付款紀錄可能沒有 paymentPurpose，
 * 此時依 amountType 推算，確保舊資料仍可重試。
 *
 * @param {Object} payment 付款資料
 * @return {string}
 */
function resolvePaymentPurpose(payment) {
  const paymentPurpose = normalizeString(
      payment.paymentPurpose,
  ).toLowerCase();

  if (paymentPurpose) {
    return paymentPurpose;
  }

  const amountType = normalizeString(
      payment.amountType,
  ).toLowerCase();

  return amountType === "deposit" ?
    "deposit" :
    "full";
}

/**
 * 判斷 Payment 是否仍屬於未完成付款。
 *
 * 這些狀態代表交易尚未正式結束，
 * 不應再替同一張訂單建立另一筆相同用途的付款。
 *
 * @param {Object} payment Payment 資料
 * @return {boolean}
 */
function isDepositFamily(payment) {
  const data = payment && typeof payment === "object" ? payment : {};
  return resolvePaymentPurpose(data) === "deposit" ||
    normalizeString(data.amountType).toLowerCase() === "deposit";
}

/**
 * 將過期的 pending 結算尾款標為 superseded，不刪除。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Array} docs
 * @return {void}
 */
function supersedeStalePendingPayments(transaction, docs) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  docs.forEach((doc) => {
    transaction.set(doc.ref, {
      status: "superseded",
      gatewayStatus: "superseded_amount_changed",
      supersededReason: "settlement_amount_updated",
      supersededReasonLabel: "已失效（結算金額已更新）",
      supersededAt: now,
      updatedAt: now,
    }, {merge: true});
  });
}

/**
 * 判斷 Payment 是否仍屬於未完成付款。
 *
 * @param {Object} payment Payment 資料
 * @return {boolean}
 */
function isActivePayment(payment) {
  const status = normalizeString(
      payment.status,
  ).toLowerCase();

  return [
    "creating",
    "pending",
    "awaiting_payment",
    "processing",
  ].includes(status);
}

/**
 * 檢查既有付款紀錄是否與目前請求完全相同
 *
 * 避免同一個 requestId 被拿來支付：
 * - 不同訂單
 * - 不同店家
 * - 不同付款方式
 * - 不同付款用途
 * - 不同金額
 *
 * @param {Object} params 比對參數
 * @param {Object} params.existingPayment 既有付款資料
 * @param {Object} params.expectedPayment 本次付款資料
 * @return {void}
 */
function verifyExistingPaymentRequest({
  existingPayment,
  expectedPayment,
}) {
  const sameRequest =
    normalizeString(existingPayment.userId) ===
      normalizeString(expectedPayment.userId) &&
    normalizeString(existingPayment.bookingId) ===
      normalizeString(expectedPayment.bookingId) &&
    normalizeString(existingPayment.sourceType || "booking") ===
      normalizeString(expectedPayment.sourceType || "booking") &&
    normalizeString(existingPayment.sourceId || existingPayment.bookingId) ===
      normalizeString(expectedPayment.sourceId || expectedPayment.bookingId) &&
    normalizeString(existingPayment.shopId) ===
      normalizeString(expectedPayment.shopId) &&
    normalizeString(existingPayment.requestId) ===
      normalizeString(expectedPayment.requestId) &&
    normalizeString(existingPayment.paymentMethod) ===
      normalizeString(expectedPayment.paymentMethod) &&
    normalizeString(existingPayment.amountType) ===
      normalizeString(expectedPayment.amountType) &&
    resolvePaymentPurpose(existingPayment) ===
      resolvePaymentPurpose(expectedPayment) &&
    normalizeInteger(existingPayment.amount) ===
      normalizeInteger(expectedPayment.amount) &&
    normalizeString(existingPayment.merchantTradeNo) ===
      normalizeString(expectedPayment.merchantTradeNo);

  if (!sameRequest) {
    throw new HttpsError(
        "already-exists",
        "這個付款請求編號已被其他付款使用，請重新操作。",
    );
  }
}

/**
 * 建立或取得付款紀錄
 *
 * 使用 Firestore Transaction 防止：
 * - 會員快速連點
 * - 網路重試
 * - Callable Function 重複執行
 *
 * @param {Object} params 付款參數
 * @param {string} params.requestId 付款請求 ID
 * @param {string} params.bookingId 訂單 ID
 * @param {string} params.shopId 店家 ID
 * @param {string} params.userId 會員 UID
 * @param {string} params.paymentMethod 付款方式
 * @param {string} params.amountType 金額計算方式
 * @param {string} params.paymentPurpose 本次付款用途
 * @param {number} params.amount 本次付款金額
 * @param {number} params.totalAmount 訂單總金額
 * @param {number} params.paidAmount 建立前已付款金額
 * @return {Promise<Object>}
 */
async function createOrGetPendingPayment({
  requestId,
  bookingId = "",
  shopId,
  userId,
  paymentMethod,
  amountType,
  paymentPurpose,
  amount,
  totalAmount,
  paidAmount,
  sourceType = "booking",
  sourceId = "",
  storeOrderId = "",
  storeOrderCode = "",
  bookingCode = "",
  customerName = "",
}) {
  const normalizedRequestId = normalizeString(requestId);
  const normalizedBookingId = normalizeString(bookingId);
  const normalizedShopId = normalizeString(shopId);
  const normalizedUserId = normalizeString(userId);
  const normalizedSourceType = normalizeString(sourceType) || "booking";
  const normalizedSourceId = normalizeString(sourceId) ||
    (normalizedSourceType === "store_order" ?
      normalizeString(storeOrderId) :
      normalizedBookingId);
  const normalizedStoreOrderId = normalizeString(storeOrderId);
  const normalizedStoreOrderCode = normalizeString(storeOrderCode);

  const normalizedPaymentMethod = normalizeString(
      paymentMethod,
  ).toLowerCase();

  const normalizedAmountType = normalizeString(
      amountType,
  ).toLowerCase();

  const normalizedPaymentPurpose = normalizeString(
      paymentPurpose,
  ).toLowerCase();

  const normalizedAmount = normalizeInteger(amount);
  const normalizedTotalAmount = normalizeInteger(totalAmount);
  const normalizedPaidAmount = normalizeInteger(paidAmount);

  if (
    !normalizedRequestId ||
    !normalizedShopId ||
    !normalizedUserId ||
    !normalizedSourceId
  ) {
    throw new HttpsError(
        "invalid-argument",
        "付款紀錄資料不完整。",
    );
  }

  if (
    normalizedSourceType !== "store_order" &&
    !normalizedBookingId
  ) {
    throw new HttpsError(
        "invalid-argument",
        "付款紀錄資料不完整。",
    );
  }

  if (!normalizedPaymentMethod) {
    throw new HttpsError(
        "invalid-argument",
        "缺少付款方式。",
    );
  }

  const allowedAmountTypes = [
    "deposit",
    "full",
  ];

  if (!allowedAmountTypes.includes(normalizedAmountType)) {
    throw new HttpsError(
        "invalid-argument",
        "付款金額類型不正確。",
    );
  }

  if (normalizedAmount <= 0) {
    throw new HttpsError(
        "invalid-argument",
        "付款金額必須大於零。",
    );
  }

  const allowedPaymentPurposes = [
    "deposit",
    "balance",
    "full",
    "additional",
    "other",
  ];

  if (
    !allowedPaymentPurposes.includes(
        normalizedPaymentPurpose,
    )
  ) {
    throw new HttpsError(
        "invalid-argument",
        "付款用途不正確。",
    );
  }

  const paymentId = createPaymentId({
    userId: normalizedUserId,
    requestId: normalizedRequestId,
  });

  const merchantTradeNo = createMerchantTradeNo(
      paymentId,
  );

  const firestore = admin.firestore();

  const activeQueryField = normalizedSourceType === "store_order" ?
    "storeOrderId" :
    "bookingId";
  const activeQueryValue = normalizedSourceType === "store_order" ?
    normalizedStoreOrderId || normalizedSourceId :
    normalizedBookingId;

  const activePaymentsSnapshot = await firestore
      .collection("payments")
      .where(
          activeQueryField,
          "==",
          activeQueryValue,
      )
      .get();

  const activeDocs = activePaymentsSnapshot.docs.filter((doc) => {
    const payment = doc.data() || {};
    return isActivePayment(payment) &&
      normalizeString(payment.gateway).toLowerCase() === "ecpay";
  });

  const creatingDeposit = normalizedPaymentPurpose === "deposit" ||
    normalizedAmountType === "deposit";

  const familyDocs = activeDocs.filter((doc) => {
    const payment = doc.data() || {};
    const depositFamily = isDepositFamily(payment);
    return creatingDeposit ? depositFamily : !depositFamily;
  });

  const reusableDoc = familyDocs.find((doc) => {
    const payment = doc.data() || {};
    return normalizeString(payment.paymentMethod).toLowerCase() ===
        normalizedPaymentMethod &&
      normalizeInteger(payment.amount) === normalizedAmount;
  });

  if (reusableDoc) {
    return {
      paymentId: reusableDoc.id,
      paymentRef: reusableDoc.ref,
      payment: reusableDoc.data() || {},
      isExisting: true,
    };
  }

  const staleDocs = familyDocs;
  if (staleDocs.length > 0 && normalizedSourceType === "store_order") {
    const existingPayment = staleDocs[0].data() || {};
    throw new HttpsError(
        "already-exists",
        "此訂單已有一筆尚未完成的付款，請先確認原付款結果。",
        {
          paymentId: staleDocs[0].id,
          bookingId: normalizedBookingId,
          merchantTradeNo: normalizeString(existingPayment.merchantTradeNo),
          status: normalizeString(existingPayment.status),
        },
    );
  }

  let resolvedBookingCode = normalizeString(bookingCode);
  let resolvedCustomerName = normalizeString(customerName);

  if (normalizedSourceType !== "store_order") {
    const bookingRef = firestore
        .collection("bookings")
        .doc(normalizedBookingId);

    const bookingSnapshot = await bookingRef.get();

    if (!bookingSnapshot.exists) {
      throw new HttpsError(
          "not-found",
          "找不到付款對應的訂單。",
      );
    }

    const booking = bookingSnapshot.data() || {};
    resolvedBookingCode = normalizeString(booking.bookingCode);
    resolvedCustomerName = normalizeString(booking.customerName);
  }

  const paymentRef = firestore
      .collection("payments")
      .doc(paymentId);

  const paymentData = {
    paymentId,
    requestId: normalizedRequestId,
    bookingId: normalizedBookingId,
    shopId: normalizedShopId,
    userId: normalizedUserId,
    bookingCode: resolvedBookingCode,
    customerName: resolvedCustomerName,
    sourceType: normalizedSourceType,
    sourceId: normalizedSourceId,
    storeOrderId: normalizedStoreOrderId,
    storeOrderCode: normalizedStoreOrderCode,
    gateway: "ecpay",
    paymentMethod: normalizedPaymentMethod,
    amountType: normalizedAmountType,
    paymentPurpose: normalizedPaymentPurpose,
    amount: normalizedAmount,
    totalAmount: normalizedTotalAmount,
    paidAmountBeforePayment: normalizedPaidAmount,
    status: "creating",
    gatewayStatus: "",
    merchantTradeNo,
    paymentUrl: "",
    atmBankCode: "",
    atmAccount: "",
    atmExpireAt: null,
    cvsPaymentCode: "",
    cvsExpireAt: null,
    failureCode: "",
    failureMessage: "",
    createdAt:
      admin.firestore.FieldValue.serverTimestamp(),
    updatedAt:
      admin.firestore.FieldValue.serverTimestamp(),
  };

  const transactionResult = await firestore.runTransaction(
      async (transaction) => {
        const paymentSnapshot =
          await transaction.get(paymentRef);

        for (const stale of staleDocs) {
          const staleSnap = await transaction.get(stale.ref);
          if (!staleSnap.exists) {
            continue;
          }
          const stalePayment = staleSnap.data() || {};
          if (normalizeString(stalePayment.status).toLowerCase() === "paid") {
            continue;
          }
          if (!isActivePayment(stalePayment)) {
            continue;
          }
          supersedeStalePendingPayments(transaction, [stale]);
        }

        if (paymentSnapshot.exists) {
          const existingPayment =
            paymentSnapshot.data() || {};

          verifyExistingPaymentRequest({
            existingPayment,
            expectedPayment: paymentData,
          });

          return {
            paymentId,
            paymentRef,
            payment: existingPayment,
            isExisting: true,
          };
        }

        transaction.create(
            paymentRef,
            paymentData,
        );

        return {
          paymentId,
          paymentRef,
          payment: paymentData,
          isExisting: false,
        };
      },
  );

  return transactionResult;
}

/**
 * 以 CustomField1（paymentId）或 MerchantTradeNo 找到付款紀錄。
 *
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @param {string} params.paymentId
 * @param {string} params.merchantTradeNo
 * @return {Promise<FirebaseFirestore.DocumentSnapshot|null>}
 */
async function findPaymentForEcpayCallback(firestore, {
  paymentId,
  merchantTradeNo,
}) {
  const id = normalizeString(paymentId);
  const tradeNo = normalizeString(merchantTradeNo);
  if (id) {
    const byId = await firestore.collection("payments").doc(id).get();
    if (byId.exists) {
      return byId;
    }
  }
  if (!tradeNo) {
    return null;
  }
  const byTrade = await firestore.collection("payments")
      .where("merchantTradeNo", "==", tradeNo)
      .limit(1)
      .get();
  if (byTrade.empty) {
    return null;
  }
  return byTrade.docs[0];
}

module.exports = {
  createPaymentId,
  verifyExistingPaymentRequest,
  createOrGetPendingPayment,
  findPaymentForEcpayCallback,
};
