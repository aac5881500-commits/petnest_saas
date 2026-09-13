// 檔案名稱：functions/bookings/settlement_payment_direction.js
// 功能說明：結算後只依待補／待退顯示補款或退款，減免本身不決定方向

const ALLOWED_REFUND = ["cash", "transfer", "other"];

/**
 * @param {number} remainingAmount
 * @param {number} refundDueAmount
 * @return {{showTopUp: boolean, showRefund: boolean}}
 */
function settlementMoneyDirection(remainingAmount, refundDueAmount) {
  const remaining = Math.max(0, Number(remainingAmount) || 0);
  const refund = Math.max(0, Number(refundDueAmount) || 0);
  if (remaining > 0) {
    return {showTopUp: true, showRefund: false};
  }
  if (refund > 0) {
    return {showTopUp: false, showRefund: true};
  }
  return {showTopUp: false, showRefund: false};
}

/**
 * @param {Object} params
 * @return {Object}
 */
function applySettlementPaymentDirection(params) {
  const remaining = Math.max(0, Number(params.remainingAmount) || 0);
  const refund = Math.max(0, Number(params.refundDueAmount) || 0);
  const topUpMethod = (params.topUpMethod || "").toString().trim();
  const refundMethod = (params.refundMethod || "").toString().trim();
  const refundNote = (params.refundNote || "").toString().trim();
  const direction = settlementMoneyDirection(remaining, refund);
  if (direction.showTopUp) {
    return {
      ...direction,
      settlementTopUpMethod: topUpMethod,
      settlementTopUpStatus: topUpMethod === "transfer" ?
        "awaiting_proof" : (topUpMethod ? "selected" : ""),
      settlementRefundMethod: "",
      settlementRefundNote: "",
      appTopUpRequested: remaining > 0 && topUpMethod !== "cash",
    };
  }
  if (direction.showRefund) {
    return {
      ...direction,
      settlementTopUpMethod: "",
      settlementTopUpStatus: "none",
      settlementRefundMethod: refundMethod,
      settlementRefundNote: refundMethod === "other" ? refundNote : "",
      appTopUpRequested: false,
    };
  }
  return {
    ...direction,
    settlementTopUpMethod: "",
    settlementTopUpStatus: "none",
    settlementRefundMethod: "",
    settlementRefundNote: "",
    appTopUpRequested: false,
  };
}

/**
 * @param {string} method
 * @param {string=} note
 * @return {string}
 */
function assertRefundMethod(method, note) {
  const id = (method || "").toString().trim();
  if (!ALLOWED_REFUND.includes(id)) {
    const error = new Error("請選擇退款方式");
    error.code = "invalid-argument";
    throw error;
  }
  if (id === "other" && !(note || "").toString().trim()) {
    const error = new Error("其他退款請填寫註記");
    error.code = "invalid-argument";
    throw error;
  }
  return id;
}

module.exports = {
  ALLOWED_REFUND,
  settlementMoneyDirection,
  applySettlementPaymentDirection,
  assertRefundMethod,
};
