/* eslint-disable max-len, require-jsdoc */
"use strict";
const {createCheckMacValue, verifyCheckMacValue} = require("../payments/ecpay_mac");
const {formatMerchantTradeDate} = require("../payments/ecpay_client");
const {HttpsError} = require("firebase-functions/v2/https");
const ROOTS = {test: "https://payment-stage.ecpay.com.tw", production: "https://payment.ecpay.com.tw"};
const escape = (value) => String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
function gateway(config, transport = fetch) {
  if (!ROOTS[config.environment] || !/^\d{5,10}$/.test(config.merchantId) || !config.hashKey || !config.hashIv) throw new HttpsError("failed-precondition", "平台綠界尚未設定完整");
  const sign = (data) => ({...data, CheckMacValue: createCheckMacValue({data, hashKey: config.hashKey, hashIv: config.hashIv})});
  const verify = (data) => verifyCheckMacValue({data, hashKey: config.hashKey, hashIv: config.hashIv});
  async function post(path, fields, json = false) {
    const data = sign({MerchantID: config.merchantId, PlatformID: "", TimeStamp: Math.floor(Date.now() / 1000), ...fields});
    const response = await transport(ROOTS[config.environment] + path, {
      method: "POST", headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams(data).toString(), redirect: "error", signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new HttpsError("unavailable", "綠界暫時無法確認，請稍後查詢");
    const text = await response.text();
    if (text.length > 300000) throw new HttpsError("unavailable", "綠界回覆格式不正確");
    let result;
    try {
      result = json ? JSON.parse(text.replace(/^\uFEFF/, "")) : Object.fromEntries(new URLSearchParams(text));
    } catch (_) {
      throw new HttpsError("unavailable", "綠界回覆格式不正確");
    }
    if (!result || Array.isArray(result) || typeof result !== "object" ||
        String(result.MerchantID) !== config.merchantId || result.MerchantTradeNo !== fields.MerchantTradeNo ||
        (!json && !verify(result))) throw new HttpsError("unavailable", "綠界回覆驗證失敗，尚未變更收費狀態");
    return result;
  }
  return {
    config,
    verify,
    form(order, nonce) {
      if (order.environment !== config.environment || order.merchantId !== config.merchantId) throw new HttpsError("failed-precondition", "此筆付款環境已變更，請聯絡平台");
      const data = {MerchantID: config.merchantId, MerchantTradeNo: order.id,
        MerchantTradeDate: formatMerchantTradeDate(), PaymentType: "aio",
        TotalAmount: order.amountMinor / 100, TradeDesc: "PetNest平台方案使用費",
        ItemName: `PetNest ${order.plan === "pro" ? "旗艦版" : "專業版"} ${order.cycle === "year" ? "年繳" : "月繳"}`,
        ReturnURL: config.callbackUrl, ChoosePayment: "Credit", EncryptType: 1,
        NeedExtraPaidInfo: "N", BindingCard: 0, ClientBackURL: config.publicOrigin,
      };
      if (order.recurring) {
        Object.assign(data, {PeriodAmount: data.TotalAmount,
          PeriodType: order.periodType, Frequency: 1, ExecTimes: order.executionLimit,
          PeriodReturnURL: config.periodicUrl});
      }
      const signed = sign(data);
      return `<!doctype html><meta charset="utf-8"><title>前往綠界付款</title><form method="post" action="${ROOTS[config.environment]}/Cashier/AioCheckOut/V5">` +
        Object.entries(signed).map(([key, value]) => `<input type="hidden" name="${escape(key)}" value="${escape(value)}">`).join("") +
        `<button type=submit>前往綠界付款</button></form><script nonce="${escape(nonce)}">document.forms[0].submit();</script>`;
    },
    async cancel(order) {
      const data = await post("/Cashier/CreditCardPeriodAction", {MerchantTradeNo: order.id, Action: "Cancel"});
      if (Number(data.RtnCode) !== 1) throw new HttpsError("unavailable", "綠界尚未確認終止，系統會繼續確認，請勿重複訂閱");
    },
    query(order) {
      return post(order.recurring ? "/Cashier/QueryCreditCardPeriodInfo" : "/Cashier/QueryTradeInfo/V5", {MerchantTradeNo: order.id}, order.recurring);
    },
  };
}
module.exports = {gateway};
