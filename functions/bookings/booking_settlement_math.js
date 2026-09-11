/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/booking_settlement_math.js
// 功能說明：住宿／安親共用結算：最終應收、實收淨額、待補／待退。

function toInt(value, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }
  const parsed = Number.parseInt(String(value == null ? "" : value).trim(), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function extraChargeSum(booking) {
  const data = booking || {};
  let sum = 0;
  if (Array.isArray(data.extraCharges)) {
    data.extraCharges.forEach((item) => {
      if (item && typeof item === "object") {
        sum += toInt(item.amount, 0);
      }
    });
  }
  if (sum <= 0) {
    sum = toInt(data.extraFee, 0);
  }
  return sum;
}

function quotedTotal(booking) {
  const data = booking || {};
  const stored = toInt(
      data.quotedTotalPrice || data.originalTotal || data.estimateTotalPrice,
      0,
  );
  if (stored > 0) {
    return stored;
  }
  const total = toInt(
      data.totalPayableAmount || data.totalPrice || data.totalAmount,
      0,
  );
  const extras = extraChargeSum(data) + toInt(data.manualAdjust, 0);
  return Math.max(0, total - extras);
}

function expectedTotal(booking, manualAdjustOverride) {
  const data = booking || {};
  const quoted = quotedTotal(data);
  const extra = extraChargeSum(data);
  const overtime = toInt(data.overtimeAmount, 0);
  const manual = manualAdjustOverride == null ?
    toInt(data.manualAdjust, 0) : toInt(manualAdjustOverride, 0);
  return Math.max(0, quoted + extra + overtime + manual);
}

function paidAmount(booking) {
  const data = booking || {};
  const paid = toInt(data.paidAmount, 0);
  if (paid > 0) {
    return paid;
  }
  const paymentPaid = toInt(data.paymentPaidAmount, 0);
  if (paymentPaid > 0) {
    return paymentPaid;
  }
  if (data.depositPaid === true ||
      String(data.depositStatus || "").trim() === "confirmed") {
    return toInt(data.depositAmount, 0);
  }
  return 0;
}

function isSettlementConfirmed(booking) {
  const data = booking || {};
  return data.settlementConfirmed === true ||
    data.settledAt != null ||
    data.finalSettlementAmount != null;
}

function isSettlementLocked(booking) {
  return (booking || {}).settlementLocked === true;
}

function canLock(booking) {
  if (!isSettlementConfirmed(booking) || isSettlementLocked(booking)) {
    return false;
  }
  return remainingDue(booking) <= 0 && refundDue(booking) <= 0;
}

function refundedAmount(booking) {
  return toInt((booking || {}).refundAmount, 0);
}

function netCollected(booking) {
  return Math.max(0, paidAmount(booking) - refundedAmount(booking));
}

function remainingDue(booking, manualAdjustOverride) {
  return Math.max(
      0,
      expectedTotal(booking, manualAdjustOverride) - netCollected(booking),
  );
}

function refundDue(booking, manualAdjustOverride) {
  return Math.max(
      0,
      netCollected(booking) - expectedTotal(booking, manualAdjustOverride),
  );
}

function paymentStatusOf(expected, net) {
  const remain = Math.max(0, expected - net);
  const refund = Math.max(0, net - expected);
  if (remain > 0) {
    return net > 0 ? "partial" : "unpaid";
  }
  if (refund > 0) {
    return "refund_pending";
  }
  return expected > 0 || net > 0 ? "paid" : "unpaid";
}

function settlementFields(booking, manualAdjustOverride) {
  const expected = expectedTotal(booking, manualAdjustOverride);
  const paid = paidAmount(booking);
  const refunded = refundedAmount(booking);
  const net = Math.max(0, paid - refunded);
  return {
    quotedTotalPrice: quotedTotal(booking),
    extraChargeSum: extraChargeSum(booking),
    expectedTotal: expected,
    totalPayableAmount: expected,
    totalPrice: expected,
    totalAmount: expected,
    paidAmount: paid,
    refundAmount: refunded,
    remainingAmount: Math.max(0, expected - net),
    refundDueAmount: Math.max(0, net - expected),
    paymentStatus: paymentStatusOf(expected, net),
  };
}

module.exports = {
  toInt,
  extraChargeSum,
  quotedTotal,
  expectedTotal,
  paidAmount,
  refundedAmount,
  netCollected,
  remainingDue,
  refundDue,
  paymentStatusOf,
  settlementFields,
  isSettlementConfirmed,
  isSettlementLocked,
  canLock,
};
