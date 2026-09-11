// 檔案名稱：functions/reports/shop_report_summary.js
// 功能說明：店家營運摘要：差額更新，同一事件重送不可重複累加。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

function toInt(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) {
    return 0;
  }
  return Math.trunc(n);
}

function bookingMoney(data) {
  const addons = data.addons;
  let addon = 0;
  if (Array.isArray(addons)) {
    for (const raw of addons) {
      if (!raw || typeof raw !== "object") {
        continue;
      }
      addon += toInt(raw.total ?? raw.price);
    }
  } else {
    addon = toInt(data.addonTotal ?? data.addonsTotal);
  }
  const surcharge = toInt(data.specialDateSurchargeAmount);
  const discount = toInt(data.discountAmount);
  const coupon = toInt(data.couponDiscountAmount);
  const extra = toInt(data.extraFee);
  const hasSettled = data.finalSettlementAmount != null;
  const order = hasSettled ?
    toInt(data.finalSettlementAmount) :
    toInt(data.finalAmount ?? data.totalPrice ?? data.totalAmount) +
      (data.finalAmount == null ? extra : 0);
  return {
    orderAmount: order < 0 ? 0 : order,
    addon,
    discount,
    coupon,
  };
}

function monthId(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${y}-${m}`;
}

function emptySummary() {
  return {
    stayOrderCount: 0,
    daycareOrderCount: 0,
    storeOrderCount: 0,
    stayRevenue: 0,
    daycareRevenue: 0,
    storeRevenue: 0,
    refundAmount: 0,
    discountAmount: 0,
    addonRevenue: 0,
    newMemberCount: 0,
    cancelledOrderCount: 0,
    completedCount: 0,
    confirmedCount: 0,
  };
}

function bookingContribution(booking) {
  const kind = String(booking.bookingKind || "") === "daycare" ?
    "daycare" : "stay";
  const status = String(booking.status || "");
  const money = bookingMoney(booking);
  const revenueStatuses = new Set(["confirmed", "checked_in", "completed"]);
  const recognized = revenueStatuses.has(status) ? money.orderAmount : 0;
  const contrib = emptySummary();
  if (kind === "daycare") {
    contrib.daycareOrderCount = 1;
    contrib.daycareRevenue = recognized;
  } else {
    contrib.stayOrderCount = 1;
    contrib.stayRevenue = recognized;
  }
  contrib.discountAmount = money.discount + money.coupon;
  contrib.addonRevenue = money.addon;
  contrib.cancelledOrderCount =
    status === "cancelled" || status === "no_show" ? 1 : 0;
  contrib.completedCount = status === "completed" ? 1 : 0;
  contrib.confirmedCount = status === "confirmed" ? 1 : 0;
  return contrib;
}

function paymentContribution(payment) {
  const contrib = emptySummary();
  const status = String(payment.status || "");
  const amount = toInt(payment.amount);
  const refund = toInt(payment.refundedAmount);
  const source = String(payment.sourceType || "");
  if (status === "paid" || status === "success") {
    if (source === "store_order") {
      contrib.storeRevenue = amount;
    }
  }
  if (status === "refunded" || status === "partially_refunded") {
    contrib.refundAmount = refund > 0 ? refund : amount;
  }
  return contrib;
}

function applyDelta(current, next, prev) {
  const out = {...current};
  for (const key of Object.keys(emptySummary())) {
    out[key] = toInt(current[key]) + (toInt(next[key]) - toInt(prev[key]));
  }
  return out;
}

/**
 * 以 contribution 文件保存已貢獻值，更新時只寫差額。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function applyReportContribution(firestore, params) {
  const shopId = String(params.shopId || "").trim();
  const sourceId = String(params.sourceId || "").trim();
  const month = String(params.monthId || monthId(new Date()));
  const next = {...emptySummary(), ...(params.next || {})};
  if (!shopId || !sourceId) {
    throw new Error("缺少店家或貢獻來源");
  }
  const summaryRef = firestore.collection("shops").doc(shopId)
      .collection("report_summaries").doc(month);
  const contribRef = firestore.collection("shops").doc(shopId)
      .collection("report_contributions").doc(sourceId);
  return firestore.runTransaction(async (transaction) => {
    const [summarySnap, contribSnap] = await Promise.all([
      transaction.get(summaryRef),
      transaction.get(contribRef),
    ]);
    const prev = contribSnap.exists ?
      {...emptySummary(), ...(contribSnap.data() || {})} :
      emptySummary();
    const current = summarySnap.exists ?
      {...emptySummary(), ...(summarySnap.data() || {})} :
      emptySummary();
    const updated = applyDelta(current, next, prev);
    updated.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    updated.monthId = month;
    transaction.set(summaryRef, updated, {merge: true});
    transaction.set(contribRef, {
      ...next,
      shopId,
      monthId: month,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {prev, next, updated};
  });
}

async function applyBookingReport(firestore, bookingId, booking) {
  const shopId = String(booking.shopId || "").trim();
  if (!shopId) {
    return;
  }
  const created = booking.createdAt && booking.createdAt.toDate ?
    booking.createdAt.toDate() : new Date();
  return applyReportContribution(firestore, {
    shopId,
    sourceId: `booking_${bookingId}`,
    monthId: monthId(created),
    next: bookingContribution(booking),
  });
}

async function applyPaymentReport(firestore, paymentId, payment) {
  const shopId = String(payment.shopId || "").trim();
  if (!shopId) {
    return;
  }
  const when = payment.paidAt && payment.paidAt.toDate ?
    payment.paidAt.toDate() :
    (payment.createdAt && payment.createdAt.toDate ?
      payment.createdAt.toDate() : new Date());
  return applyReportContribution(firestore, {
    shopId,
    sourceId: `payment_${paymentId}`,
    monthId: monthId(when),
    next: paymentContribution(payment),
  });
}

const rebuildShopReportSummary = onCall(
    {region: "asia-east1"},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const token = request.auth.token || {};
      if (token.role !== "root_admin" && token.admin !== true) {
        const user = await admin.auth().getUser(uid);
        const claims = user.customClaims || {};
        if (claims.role !== "root_admin") {
          throw new HttpsError("permission-denied", "僅平台管理員可重建報表");
        }
      }
      const shopId = String((request.data || {}).shopId || "").trim();
      const month = String((request.data || {}).monthId || "").trim();
      const dryRun = (request.data || {}).dryRun === true;
      const limit = Math.min(toInt((request.data || {}).limit) || 100, 200);
      if (!shopId || !month) {
        throw new HttpsError("invalid-argument", "請指定 shopId 與月份");
      }
      const firestore = admin.firestore();
      const start = new Date(`${month}-01T00:00:00.000Z`);
      if (Number.isNaN(start.getTime())) {
        throw new HttpsError("invalid-argument", "月份格式請用 yyyy-MM");
      }
      const end = new Date(Date.UTC(start.getUTCFullYear(),
          start.getUTCMonth() + 1, 1));
      const snap = await firestore.collection("bookings")
          .where("shopId", "==", shopId)
          .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(start))
          .where("createdAt", "<", admin.firestore.Timestamp.fromDate(end))
          .orderBy("createdAt")
          .limit(limit)
          .get();
      if (dryRun) {
        return {shopId, monthId: month, count: snap.size, dryRun: true};
      }
      let applied = 0;
      for (const doc of snap.docs) {
        await applyBookingReport(firestore, doc.id, doc.data() || {});
        applied += 1;
      }
      return {shopId, monthId: month, applied};
    },
);

const backfillBookingSearchFields = onCall(
    {region: "asia-east1"},
    async (request) => {
      return runBackfill(request, "bookings");
    },
);

const backfillMemberSearchFields = onCall(
    {region: "asia-east1"},
    async (request) => {
      return runBackfill(request, "members");
    },
);

async function assertRoot(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const user = await admin.auth().getUser(uid);
  const claims = user.customClaims || {};
  if (claims.role !== "root_admin") {
    throw new HttpsError("permission-denied", "僅平台管理員可執行回填");
  }
}

async function runBackfill(request, kind) {
  await assertRoot(request);
  const shopId = String((request.data || {}).shopId || "").trim();
  const dryRun = (request.data || {}).dryRun === true;
  const limit = Math.min(toInt((request.data || {}).limit) || 100, 200);
  if (!shopId) {
    throw new HttpsError("invalid-argument", "請指定 shopId");
  }
  const firestore = admin.firestore();
  const {bookingSearchFields, memberSearchFields} =
    require("../search/normalize_fields");
  let snap;
  if (kind === "members") {
    snap = await firestore.collection("shops").doc(shopId)
        .collection("members").limit(limit).get();
  } else {
    snap = await firestore.collection("bookings")
        .where("shopId", "==", shopId)
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();
  }
  if (dryRun) {
    return {shopId, kind, count: snap.size, dryRun: true};
  }
  let updated = 0;
  const batch = firestore.batch();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const fields = kind === "members" ?
      memberSearchFields(data) : bookingSearchFields(data);
    batch.set(doc.ref, fields, {merge: true});
    updated += 1;
  }
  if (updated > 0) {
    await batch.commit();
  }
  return {shopId, kind, updated};
}

module.exports = {
  toInt,
  bookingMoney,
  emptySummary,
  bookingContribution,
  paymentContribution,
  applyDelta,
  applyReportContribution,
  applyBookingReport,
  applyPaymentReport,
  rebuildShopReportSummary,
  backfillBookingSearchFields,
  backfillMemberSearchFields,
};
