// functions/payments/ecpay_client.js
// 🟢 綠界付款 Client
// 功能：使用綠界官方 Node.js SDK 建立信用卡、ATM、
// 超商代碼付款表單 HTML，供前端導向綠界付款頁。
// 除錯期間會將 SDK 最終產生的付款表單輸出到 Functions Log。

const {HttpsError} = require("firebase-functions/v2/https");
const ECPayment = require("ecpay_aio_nodejs");

const {
  normalizeInteger,
  normalizeString,
} = require("./payment_verify");

/**
 * 將日期格式化為綠界要求的 yyyy/MM/dd HH:mm:ss
 *
 * @param {Date=} date 日期
 * @return {string}
 */
function formatMerchantTradeDate(date = new Date()) {
  const formatter = new Intl.DateTimeFormat(
      "zh-TW",
      {
        timeZone: "Asia/Taipei",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false,
      },
  );

  const parts = formatter.formatToParts(date);
  const valueMap = {};

  for (const part of parts) {
    if (part.type !== "literal") {
      valueMap[part.type] = part.value;
    }
  }

  return `${valueMap.year}/${valueMap.month}/${valueMap.day}` +
    ` ${valueMap.hour}:${valueMap.minute}:${valueMap.second}`;
}

/**
 * 將 PetNest 付款方式轉為綠界付款方式
 *
 * @param {string} paymentMethod PetNest 付款方式
 * @return {string}
 */
function resolveEcpayPaymentMethod(paymentMethod) {
  const normalizedMethod = normalizeString(
      paymentMethod,
  ).toLowerCase();

  if (normalizedMethod === "credit_card") {
    return "Credit";
  }

  if (normalizedMethod === "atm") {
    return "ATM";
  }

  if (normalizedMethod === "cvs_code") {
    return "CVS";
  }

  throw new HttpsError(
      "invalid-argument",
      "不支援這個綠界付款方式。",
  );
}

/**
 * 建立綠界 SDK 設定
 *
 * @param {Object} params 設定參數
 * @param {string} params.merchantId 商店代號
 * @param {string} params.hashKey HashKey
 * @param {string} params.hashIv HashIV
 * @param {boolean} params.isProduction 是否正式環境
 * @return {Object}
 */
function createEcpayOptions({
  merchantId,
  hashKey,
  hashIv,
  isProduction,
}) {
  const normalizedMerchantId = normalizeString(merchantId);
  const normalizedHashKey = normalizeString(hashKey);
  const normalizedHashIv = normalizeString(hashIv);

  if (
    !normalizedMerchantId ||
    !normalizedHashKey ||
    !normalizedHashIv
  ) {
    throw new HttpsError(
        "failed-precondition",
        "綠界商店代號、HashKey 或 HashIV 尚未設定完整。",
    );
  }

  return {
    OperationMode: isProduction ?
      "Production" :
      "Test",
    MercProfile: {
      MerchantID: normalizedMerchantId,
      HashKey: normalizedHashKey,
      HashIV: normalizedHashIv,
    },
    IgnorePayment: [],
    IsProjectContractor: false,
  };
}

/**
 * 建立綠界付款 HTML
 *
 * @param {Object} params 建立付款參數
 * @param {string} params.merchantId 商店代號
 * @param {string} params.hashKey HashKey
 * @param {string} params.hashIv HashIV
 * @param {boolean} params.isProduction 是否正式環境
 * @param {string} params.merchantTradeNo 綠界交易編號
 * @param {number} params.amount 本次付款金額
 * @param {string} params.paymentMethod 付款方式
 * @param {string} params.returnUrl 綠界背景通知網址
 * @param {string} params.clientBackUrl 返回 App 網址
 * @param {string=} params.itemName 商品名稱
 * @param {string=} params.tradeDesc 交易描述
 * @param {string=} params.customField1 自訂欄位
 * @return {Object}
 */
function createEcpayPaymentHtml({
  merchantId,
  hashKey,
  hashIv,
  isProduction = false,
  merchantTradeNo,
  amount,
  paymentMethod,
  returnUrl,
  clientBackUrl,
  itemName = "PetNest 寵物住宿訂單",
  tradeDesc = "PetNest 訂單付款",
  customField1 = "",
}) {
  const normalizedMerchantTradeNo = normalizeString(
      merchantTradeNo,
  );

  const normalizedAmount = normalizeInteger(amount);

  const normalizedReturnUrl = normalizeString(
      returnUrl,
  );

  const normalizedClientBackUrl = normalizeString(
      clientBackUrl,
  );

  if (!normalizedMerchantTradeNo) {
    throw new HttpsError(
        "invalid-argument",
        "缺少綠界交易編號。",
    );
  }

  if (normalizedAmount <= 0) {
    throw new HttpsError(
        "invalid-argument",
        "綠界付款金額必須大於零。",
    );
  }

  if (!normalizedReturnUrl) {
    throw new HttpsError(
        "failed-precondition",
        "缺少綠界付款結果通知網址。",
    );
  }

  const ecpayPaymentMethod = resolveEcpayPaymentMethod(
      paymentMethod,
  );

  const options = createEcpayOptions({
    merchantId,
    hashKey,
    hashIv,
    isProduction,
  });

  const payment = new ECPayment(options);

  const baseParameters = {
    MerchantTradeNo: normalizedMerchantTradeNo,
    MerchantTradeDate: formatMerchantTradeDate(),
    TotalAmount: String(normalizedAmount),
    TradeDesc: normalizeString(tradeDesc),
    ItemName: normalizeString(itemName),
    ReturnURL: normalizedReturnUrl,
    ChoosePayment: ecpayPaymentMethod,
    EncryptType: 1,
    NeedExtraPaidInfo: "Y",
    CustomField1: normalizeString(customField1),
  };

  if (normalizedClientBackUrl) {
    baseParameters.ClientBackURL =
      normalizedClientBackUrl;
  }

  let paymentHtml = "";

  if (ecpayPaymentMethod === "Credit") {
    paymentHtml =
      payment.payment_client
          .aio_check_out_credit_onetime(
              baseParameters,
              {},
          );
  } else if (ecpayPaymentMethod === "ATM") {
    paymentHtml =
      payment.payment_client
          .aio_check_out_atm(
              baseParameters,
          );
  } else if (ecpayPaymentMethod === "CVS") {
    paymentHtml =
      payment.payment_client
          .aio_check_out_cvs(
              baseParameters,
          );
  }

  /*
   * 暫時除錯紀錄：
   * 印出 SDK 最終產生的付款 HTML，
   * 用來核對 MerchantID、交易編號、金額與 CheckMacValue。
   *
   * 注意：
   * 找到問題後必須移除此區塊，避免正式環境長期紀錄付款資料。
   */
  console.log("========== ECPAY PAYMENT DEBUG ==========");
  console.log({
    environment: isProduction ?
      "production" :
      "test",
    merchantId: normalizeString(merchantId),
    merchantTradeNo: normalizedMerchantTradeNo,
    merchantTradeDate: baseParameters.MerchantTradeDate,
    amount: normalizedAmount,
    paymentMethod: ecpayPaymentMethod,
    returnUrl: normalizedReturnUrl,
    hasClientBackUrl: Boolean(normalizedClientBackUrl),
  });

  console.log("========== ECPAY HTML ==========");
  console.log(paymentHtml);
  console.log("=========================================");
  console.log("===== ECPAY HTML START =====");
  console.log(paymentHtml);
  console.log("===== ECPAY HTML END =====");

  if (!normalizeString(paymentHtml)) {
    throw new HttpsError(
        "internal",
        "綠界付款表單建立失敗。",
    );
  }

  return {
    paymentHtml,
    merchantTradeNo: normalizedMerchantTradeNo,
    merchantTradeDate:
      baseParameters.MerchantTradeDate,
    ecpayPaymentMethod,
    amount: normalizedAmount,
    environment: isProduction ?
      "production" :
      "test",
  };
}

module.exports = {
  formatMerchantTradeDate,
  resolveEcpayPaymentMethod,
  createEcpayOptions,
  createEcpayPaymentHtml,
};
