/* eslint-disable max-len, require-jsdoc */
"use strict";
const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const commercial = require("../sales/commercial_policy");
const TERMS = "platform_subscription_v1";
const PRICE_VERSION = crypto.createHash("sha256").update(JSON.stringify([commercial.catalogAmount("basic", "month"), commercial.catalogAmount("pro", "month"), TERMS, "month_only", 12])).digest("hex");
function fail(message) {
  throw new HttpsError("failed-precondition", message);
}
function quote(shop, plan, cycle, recurring, now = Date.now()) {
  if (cycle !== "month") fail("平台僅提供每月999元或1999元方案，請重新選擇月繳");
  let amountMinor;
  try {
    amountMinor = commercial.catalogAmount(plan, cycle);
  } catch (_) {
    fail("請選擇有效的平台方案與付款週期");
  }
  if (typeof recurring !== "boolean") fail("請確認是否啟用自動續訂");
  const today = commercial.taipeiDateKey(now);
  const period = commercial.previewPaidPeriod(shop, today, cycle === "year" ? 12 : 1);
  const entitlementEnds = [shop.paidUntilDate || ""];
  if (shop.paidUntil && typeof shop.paidUntil.toDate === "function") entitlementEnds.push(commercial.taipeiDateKey(shop.paidUntil.toDate()));
  const lastEntitlement = entitlementEnds.filter((date) => /^\d{4}-\d{2}-\d{2}$/.test(date)).sort().pop();
  const recurringAvailableFrom = lastEntitlement && lastEntitlement >= today ? commercial.addDays(lastEntitlement, 1) : period.start;
  return {plan, cycle, recurring, amountMinor, amount: amountMinor / 100,
    priceVersion: PRICE_VERSION, recurringExecutionLimit: cycle === "year" ? 2 : 12,
    executionLimit: recurring ? (cycle === "year" ? 2 : 12) : 1,
    periodType: cycle === "year" ? "Y" : "M", frequency: 1,
    serviceStart: period.start, serviceEnd: period.end,
    canStartRecurring: period.start === today && recurringAvailableFrom <= today, recurringAvailableFrom, termsVersion: TERMS};
}
function checkoutInput(data) {
  const allowed = ["shopId", "plan", "cycle", "recurring", "requestId", "termsVersion", "consent", "priceVersion"];
  if (!data || Object.keys(data).some((key) => !allowed.includes(key)) ||
      typeof data.shopId !== "string" || !/^[A-Za-z0-9_-]{1,100}$/.test(data.shopId) ||
      !/^[A-Za-z0-9_-]{16,80}$/.test(String(data.requestId || ""))) {
    throw new HttpsError("invalid-argument", "付款請求不正確；請勿傳送信用卡或自訂金額");
  }
  if (!/^[a-f0-9]{64}$/.test(String(data.priceVersion || ""))) fail("方案價格已更新，請重新確認");
  if (data.cycle !== "month") fail("平台僅提供月繳方案，請重新載入");
  if (data.consent !== true || data.termsVersion !== TERMS) fail("請先確認付款金額、週期與續訂授權");
  return data;
}
function orderId(uid, requestId) {
  return "PB" + crypto.createHash("sha256").update(uid + ":" + requestId).digest("hex").slice(0, 18).toUpperCase();
}
function paymentDate(value, order, now) {
  const match = /^(\d{4})[/-](\d{2})[/-](\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(String(value || ""));
  if (!match) fail("綠界付款時間格式不正確");
  const iso = `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}+08:00`;
  const ms = Date.parse(iso);
  if (!Number.isFinite(ms) || commercial.taipeiDateKey(ms) !== iso.slice(0, 10) ||
      ms < order.createdAtMs - 300000 || ms > now + 300000) fail("綠界付款時間不在有效範圍");
  return {date: iso.slice(0, 10), at: ms};
}
function receipt(order, data, periodic, now = Date.now()) {
  if (String(data.MerchantID) !== order.merchantId || data.MerchantTradeNo !== order.id) fail("綠界交易或特店編號不符");
  if (String(data.SimulatePaid || "0") !== "0") fail("模擬通知不能延長正式方案");
  if (!/^\d{1,10}$/.test(String(data.RtnCode))) fail("綠界交易狀態不正確");
  if (periodic && (!order.recurring || data.PeriodType !== order.periodType ||
      Number(data.Frequency) !== 1 || Number(data.ExecTimes) !== order.executionLimit)) fail("定期定額設定不符");
  if (Number(data.RtnCode) !== 1) return {success: false, code: String(data.RtnCode)};
  const amount = Number(periodic ? data.Amount : data.TradeAmt);
  if (!Number.isSafeInteger(amount) || amount !== order.amountMinor / 100) fail("綠界收款金額不符");
  if (!periodic && !/^Credit/.test(String(data.PaymentType || ""))) fail("平台方案僅接受綠界信用卡付款");
  const sequence = periodic ? Number(data.TotalSuccessTimes) : 1;
  if (!Number.isInteger(sequence) || sequence < (periodic ? 2 : 1) || sequence > order.executionLimit) fail("綠界成功扣款期數不正確");
  const reference = String(periodic ? data.gwsr : data.TradeNo || "");
  if (!/^[A-Za-z0-9]{1,32}$/.test(reference)) fail("缺少綠界交易識別碼");
  const when = paymentDate(periodic ? data.ProcessDate : data.PaymentDate, order, now);
  // Explicit allowlist: never persist the callback, card fragments, expiry,
  // authorization code, MAC, token, or free-form gateway message.
  return {success: true, sequence, amountMinor: order.amountMinor,
    gatewayReference: reference, paymentDate: when.date, paidAtMs: when.at};
}
function queryReceipts(order, data, now = Date.now()) {
  if (String(data.MerchantID) !== order.merchantId || data.MerchantTradeNo !== order.id) fail("綠界查詢交易不符");
  if (!order.recurring) {
    if (String(data.TradeStatus) !== "1") return [];
    return [receipt(order, {...data, RtnCode: 1}, false, now)];
  }
  if (Number(data.RtnCode) !== 1) return [];
  if (data.PeriodType !== order.periodType || Number(data.Frequency) !== 1 ||
      Number(data.ExecTimes) !== order.executionLimit || Number(data.PeriodAmount) * 100 !== order.amountMinor) fail("綠界查詢週期或金額不符");
  const logs = (Array.isArray(data.ExecLog) ? data.ExecLog : []).filter((row) => Number(row.RtnCode) === 1)
      .slice().sort((a, b) => String(a.process_date).localeCompare(String(b.process_date)) || Number(a.gwsr) - Number(b.gwsr));
  if (logs.length !== Number(data.TotalSuccessTimes) || logs.length > order.executionLimit ||
      new Set(logs.map((row) => String(row.gwsr))).size !== logs.length ||
      logs.reduce((sum, row) => sum + Number(row.amount), 0) !== Number(data.TotalSuccessAmount)) fail("綠界明細不完整，暫不更新方案");
  return logs.map((row, index) => receipt(order, index === 0 ? {
    MerchantID: data.MerchantID, MerchantTradeNo: data.MerchantTradeNo,
    RtnCode: row.RtnCode, TradeAmt: row.amount, PaymentType: "Credit_CreditCard",
    TradeNo: row.TradeNo, PaymentDate: row.process_date,
  } : {MerchantID: data.MerchantID, MerchantTradeNo: data.MerchantTradeNo,
    RtnCode: row.RtnCode, Amount: row.amount, PeriodType: data.PeriodType,
    Frequency: data.Frequency, ExecTimes: data.ExecTimes, TotalSuccessTimes: index + 1,
    gwsr: row.gwsr, ProcessDate: row.process_date}, index > 0, now));
}
function recurringPeriod(anchor, paidDate, cycle) {
  const months = cycle === "year" ? 12 : 1;
  const distance = (Number(paidDate.slice(0, 4)) - Number(anchor.slice(0, 4))) * 12 + Number(paidDate.slice(5, 7)) - Number(anchor.slice(5, 7));
  let slot = Math.floor(distance / months);
  if (commercial.addCalendarMonths(anchor, slot * months) > paidDate) slot--;
  if (slot < 0) fail("付款日期早於首次授權");
  return {start: commercial.addCalendarMonths(anchor, slot * months), end: commercial.addDays(commercial.addCalendarMonths(anchor, (slot + 1) * months), -1)};
}
function publicOrder(order) {
  if (!order) return null;
  const fields = ["id", "priceVersion", "plan", "cycle", "recurring", "amountMinor", "executionLimit", "state", "settledCount", "lastServiceEnd", "lastErrorCode", "termsVersion", "createdAtMs", "launchIssuedAtMs"];
  const view = Object.fromEntries(fields.filter((key) => order[key] !== undefined).map((key) => [key, order[key]]));
  if (order.recurring && order.state === "active" && order.lastServiceEnd) view.nextBillingDate = commercial.addDays(order.lastServiceEnd, 1);
  return view;
}
module.exports = {TERMS, PRICE_VERSION, quote, checkoutInput, orderId, receipt, queryReceipts, recurringPeriod, publicOrder};
