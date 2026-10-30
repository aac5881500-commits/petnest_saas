/**
 * 業務、激活碼、創店、訂閱收款與分潤的 Cloud Functions。
 */

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("../platform/inspection_write_guard");
const {loadPlatformUser} = require("../legal_pet/staff_access");
const {hasPlatformAccess} = require("../legal_pet/access");
const ops = require("./commercial_ops");
const policy = require("./commercial_policy");

const options = {region: "asia-east1", timeoutSeconds: 60, memory: "256MiB"};

/**
 * @param {Object} request Callable request
 * @param {string[]} permissions 需要其中一項
 * @return {Promise<Object>}
 */
async function platformUser(request, permissions) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const user = await loadPlatformUser(admin.firestore(), request.auth.uid);
  if (permissions && !hasPlatformAccess(user, permissions)) {
    throw new HttpsError("permission-denied", "沒有這項權限");
  }
  return user;
}

const createShopWithActivation = onCall(options, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  return ops.createShopWithActivation(request, request.data || {});
});

const validateShopActivationCode = onCall(options, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  return ops.validateShopActivationCode(request, request.data || {});
});

const saveSalesRep = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.saveSalesRep(user, request.data || {});
});

const listSalesReps = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.listSalesReps(user, request.data || {});
});

const listAssignablePlatformMembers = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.listAssignablePlatformMembers(user, request.data || {});
});

const getSalesIdentity = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.getSalesIdentity(user, request.data || {});
});

const setSalesIdentity = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.setSalesIdentity(user, request.data || {});
});

const saveActivationCode = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.saveActivationCode(user, request.data || {});
});

const listActivationCodes = onCall(options, async (request) => {
  const user = await platformUser(request);
  const manageCodes = hasPlatformAccess(user, ["manage_activation_codes"]);
  const ownCodes = hasPlatformAccess(user, ["view_own_activation_codes"]);
  if (!manageCodes && !ownCodes) {
    throw new HttpsError("permission-denied", "沒有這項權限");
  }
  const data = request.data || {};
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const migration = await db.collection("commercial_migration")
      .doc("activation_codes").get();
  let salesRepId = String(data.salesRepId || "");
  if (!manageCodes) {
    const own = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    if (own.empty) {
      throw new HttpsError("permission-denied", "這個帳號沒有綁定業務");
    }
    salesRepId = own.docs[0].id;
  }
  const textQuery = String(data.query || "").trim();
  const nameQuery = /[^\u0020-\u007e]/.test(textQuery);
  const nameNeedle = textQuery.normalize("NFKC").toLowerCase()
      .replace(/\s+/g, "");
  const filters = {
    status: String(data.status || ""),
    salesRepId: salesRepId,
    source: String(data.source || ""),
    nameNeedle: nameQuery ? nameNeedle : "",
  };
  const items = [];
  let cursorCode = "";
  let cursorId = "";
  if (data.cursor && String(data.cursor).includes("|")) {
    const parts = String(data.cursor).split("|");
    cursorCode = parts[0];
    cursorId = parts.slice(1).join("|");
  }
  let exhausted = false;
  let last = null;
  const pageSize = 30;
  const batchSize = 40;
  for (let round = 0; round < 8 && items.length < pageSize; round += 1) {
    let query = db.collection("activation_codes");
    if (textQuery && nameQuery) {
      query = query.where(
          "nameGrams",
          "array-contains",
          policy.activationNameGram(textQuery),
      );
    } else if (textQuery) {
      query = query.where(
          "codePrefixes",
          "array-contains",
          policy.normalizeActivationCode(textQuery),
      );
    } else if (salesRepId) {
      query = query.where("salesRepId", "==", salesRepId);
    }
    query = query.orderBy("normalizedCode").orderBy(
        admin.firestore.FieldPath.documentId(),
    ).limit(batchSize);
    if (cursorId) query = query.startAfter(cursorCode, cursorId);
    const snap = await query.get();
    if (snap.empty) {
      exhausted = true;
      break;
    }
    let pageFull = false;
    for (let index = 0; index < snap.docs.length; index += 1) {
      const doc = snap.docs[index];
      last = doc;
      cursorCode = String(doc.get("normalizedCode") || "");
      cursorId = doc.id;
      const row = doc.data() || {};
      if (!policy.matchesActivationFilters(row, filters, today)) continue;
      const maxUses = Number(row.maxUses || 0);
      const usedCount = Number(row.usedCount || 0);
      items.push({
        codeId: doc.id,
        code: row.code || "",
        name: row.name || "",
        plan: row.plan || "",
        salesRepId: row.salesRepId || "",
        campaignName: row.campaignName || "",
        freeDays: Number(row.freeDays || 0),
        usedCount: usedCount,
        maxUses: maxUses,
        remainingUses: Math.max(0, maxUses - usedCount),
        status: policy.activationStatus(row, today),
        useByDate: policy.effectiveUseByDate(row),
        note: row.note || "",
        enabled: row.enabled !== false,
        module: row.module || "",
        shopSource: row.shopSource || "",
        normalizedCode: row.normalizedCode || "",
      });
      if (items.length >= pageSize) {
        pageFull = true;
        break;
      }
    }
    if (pageFull) break;
    if (snap.size < batchSize) {
      exhausted = true;
      break;
    }
  }
  const hasMore = !exhausted;
  return {
    items: items,
    hasMore: hasMore,
    nextCursor: hasMore && last ? `${cursorCode}|${cursorId}` : "",
    migrationReady: migration.exists && migration.get("ready") === true,
    exhausted: exhausted,
  };
});

const registerSubscriptionPayment = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.registerSubscriptionPayment(user, request.data || {});
});

const confirmSubscriptionPayment = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.confirmSubscriptionPayment(user, request.data || {});
});

const refundSubscriptionPayment = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.refundSubscriptionPayment(user, request.data || {});
});

const grantShopEntitlement = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.grantShopEntitlement(user, request.data || {});
});

const assignShopSales = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.assignShopSales(user, request.data || {});
});

const saveCommissionRule = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.saveCommissionRule(user, request.data || {});
});

const settleCommission = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.settleCommission(user, request.data || {});
});

const migrateShopCommercialData = onCall({
  region: "asia-east1",
  timeoutSeconds: 120,
  memory: "256MiB",
}, async (request) => {
  const user = await platformUser(request);
  return ops.migrateShopCommercialData(user, request.data || {});
});

const listSubscriptionShops = onCall(options, async (request) => {
  await platformUser(request, [
    "manage_subscription_finance",
    "manage_shop_subscriptions",
  ]);
  const data = request.data || {};
  const status = String(data.status || "paid_active");
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const month = today.slice(0, 7);
  let query = db.collection("shops");
  if (status === "trial") {
    query = query.where("entitlementSource", "==", "trial")
        .where("trialUntil", ">=", today)
        .orderBy("trialUntil");
  } else if (status === "expired") {
    query = query.where("entitlementSource", "==", "paid")
        .where("paidServiceUntil", "<", today)
        .orderBy("paidServiceUntil");
  } else if (status === "legacy_unconfirmed") {
    query = query.where("entitlementSource", "==", "legacy_unconfirmed");
  } else if (status === "expiring") {
    query = query.where("paidServiceUntil", ">=", today)
        .where("paidServiceUntil", "<=", policy.addDays(today, 30))
        .orderBy("paidServiceUntil");
  } else {
    query = query.where("paidServiceUntil", ">=", today)
        .orderBy("paidServiceUntil");
  }
  query = query.orderBy(admin.firestore.FieldPath.documentId()).limit(31);
  if (data.cursor) {
    const cursorDoc = await db.collection("shops")
        .doc(String(data.cursor)).get();
    if (cursorDoc.exists) query = query.startAfter(cursorDoc);
  }
  const snap = await query.get();
  const page = snap.docs.slice(0, 30);
  const paidCount = await db.collection("shops")
      .where("paidServiceUntil", ">=", today)
      .count()
      .get();
  const dueCount = await db.collection("shops")
      .where("paidServiceUntil", ">=", today)
      .where("paidServiceUntil", "<=", policy.addDays(today, 30))
      .count()
      .get();
  const platform = await db.collection("sales_month_summaries")
      .doc(`platform_${month}`)
      .get();
  const summary = platform.data() || {};
  return {
    paidActiveCount: paidCount.data().count,
    dueCount: dueCount.data().count,
    pageCount: page.length,
    hasMore: snap.size > 30,
    nextCursor: snap.size > 30 ? page[page.length - 1].id : "",
    monthCollectedMinor: Number(summary.collectedMinor || 0),
    monthRefundMinor: Number(summary.refundMinor || 0),
    items: page.map((doc) => {
      const row = doc.data() || {};
      return {
        shopId: doc.id,
        name: row.name || "",
        plan: row.plan || "",
        listStatus: policy.subscriptionListStatus(row, today),
        renewalDue: policy.renewalDue(row, today),
        paidServiceUntil: row.paidServiceUntil || "",
        trialUntil: row.trialUntil || "",
        paidUntilDate: row.paidUntilDate || "",
      };
    }),
  };
});

const listSubscriptionPayments = onCall(options, async (request) => {
  await platformUser(request, ["manage_subscription_finance"]);
  const data = request.data || {};
  const db = admin.firestore();
  let query = db.collection("shop_subscription_payments")
      .orderBy("createdAt", "desc")
      .orderBy(admin.firestore.FieldPath.documentId(), "desc");
  if (data.shopId) {
    query = db.collection("shop_subscription_payments")
        .where("shopId", "==", String(data.shopId))
        .orderBy("createdAt", "desc")
        .orderBy(admin.firestore.FieldPath.documentId(), "desc");
  }
  query = query.limit(31);
  if (data.cursor) {
    const cursorDoc = await db.collection("shop_subscription_payments")
        .doc(String(data.cursor))
        .get();
    if (cursorDoc.exists) query = query.startAfter(cursorDoc);
  }
  const snap = await query.get();
  const page = snap.docs.slice(0, 30);
  return {
    hasMore: snap.size > 30,
    nextCursor: snap.size > 30 ? page[page.length - 1].id : "",
    pageCount: page.length,
    items: page.map((doc) => {
      const row = doc.data() || {};
      return {
        paymentId: doc.id,
        shopId: row.shopId || "",
        plan: row.plan || "",
        cycle: row.cycle || "",
        amountReceivedMinor: Number(row.amountReceivedMinor || 0),
        status: row.status || "",
        kind: row.kind || "payment",
        serviceStart: row.serviceStart || "",
        serviceEnd: row.serviceEnd || "",
        paymentDate: row.paymentDate || "",
        method: row.method || "",
        reference: row.reference || "",
      };
    }),
  };
});

const getShopCommercial = onCall(options, async (request) => {
  const user = await platformUser(request);
  const shopId = String((request.data || {}).shopId || "").trim();
  const summary = await ops.shopCommercialSummary(user, shopId);
  if (!summary) {
    throw new HttpsError("permission-denied", "沒有查看這間店財務資料的權限");
  }
  return summary;
});

const listResponsibleShops = onCall(options, async (request) => {
  const user = await platformUser(request);
  const data = request.data || {};
  const db = admin.firestore();
  let repId = String(data.repId || "");
  const manage = hasPlatformAccess(user, ["manage_sales"]) ||
    hasPlatformAccess(user, ["manage_subscription_finance"]);
  if (!manage) {
    if (!hasPlatformAccess(user, ["view_own_sales"])) {
      throw new HttpsError("permission-denied", "沒有這項權限");
    }
    const own = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    if (own.empty) {
      throw new HttpsError("permission-denied", "這個帳號沒有綁定業務");
    }
    repId = own.docs[0].id;
  } else if (!repId) {
    throw new HttpsError("invalid-argument", "請選擇要查看的業務");
  }
  const today = policy.taipeiDateKey(new Date());
  const dueEnd = policy.addDays(today, 30);
  let query = db.collection("shop_commercial")
      .where("currentSalesRepId", "==", repId)
      .where("paidServiceUntil", ">=", today)
      .orderBy("paidServiceUntil")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(31);
  if (data.cursor && String(data.cursor).includes("|")) {
    const parts = String(data.cursor).split("|");
    query = query.startAfter(parts[0], parts.slice(1).join("|"));
  }
  const snap = await query.get();
  const page = snap.docs.slice(0, 30);
  const names = await Promise.all(page.map(async (doc) => {
    const shop = await db.collection("shops").doc(doc.id).get();
    return shop.exists ? String(shop.get("name") || "") : "";
  }));
  const total = await db.collection("shop_commercial")
      .where("currentSalesRepId", "==", repId)
      .where("paidServiceUntil", ">=", today)
      .count()
      .get();
  const due = await db.collection("shop_commercial")
      .where("currentSalesRepId", "==", repId)
      .where("paidServiceUntil", ">=", today)
      .where("paidServiceUntil", "<=", dueEnd)
      .count()
      .get();
  const hasMore = snap.size > 30;
  const last = page[page.length - 1];
  return {
    queriedRepId: repId,
    total: total.data().count,
    dueCount: due.data().count,
    pageCount: page.length,
    hasMore: hasMore,
    nextCursor: hasMore && last ?
      `${last.get("paidServiceUntil") || ""}|${last.id}` : "",
    items: page.map((doc, index) => {
      const row = doc.data() || {};
      return {
        shopId: doc.id,
        name: names[index] || "",
        paidServiceUntil: row.paidServiceUntil || "",
        renewalDue: policy.renewalDue(row, today),
      };
    }),
  };
});

const listCommissionEntries = onCall(options, async (request) => {
  const user = await platformUser(request);
  const data = request.data || {};
  const db = admin.firestore();
  const manage = hasPlatformAccess(user, ["manage_subscription_finance"]);
  let repId = String(data.repId || "");
  if (!manage) {
    if (!hasPlatformAccess(user, ["view_own_sales", "view_own_commission"])) {
      throw new HttpsError("permission-denied", "沒有這項權限");
    }
    const own = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    if (own.empty) throw new HttpsError("permission-denied", "沒有綁定業務");
    repId = own.docs[0].id;
  }
  let query = db.collection("commission_entries");
  if (repId) {
    query = query.where("beneficiaryRepId", "==", repId);
  } else if (data.month) {
    query = query.where("accrualMonth", "==", String(data.month));
  } else if (!manage) {
    throw new HttpsError("invalid-argument", "請選擇業務");
  }
  query = query.orderBy(admin.firestore.FieldPath.documentId()).limit(80);
  if (data.cursor) query = query.startAfter(String(data.cursor));
  const snap = await query.get();
  const month = String(data.month || "");
  const status = String(data.status || "");
  const items = [];
  let cursorDoc = null;
  snap.docs.forEach((doc) => {
    if (items.length >= 30) return;
    cursorDoc = doc;
    const row = doc.data() || {};
    if (month && row.accrualMonth !== month) return;
    if (status && row.status !== status) return;
    if (repId && row.beneficiaryRepId !== repId) return;
    items.push(Object.assign({entryId: doc.id}, row));
  });
  const tail = snap.docs[snap.docs.length - 1];
  const stoppedEarly = cursorDoc && tail && cursorDoc.id !== tail.id;
  const hasMore = snap.size === 80 || stoppedEarly;
  const nextDoc = stoppedEarly ? cursorDoc : tail;
  return {
    queriedRepId: repId,
    hasMore: hasMore,
    nextCursor: hasMore && nextDoc ? nextDoc.id : "",
    pageCount: items.length,
    items: items,
  };
});

const listCommissionRules = onCall(options, async (request) => {
  await platformUser(request, ["manage_subscription_finance"]);
  const snap = await admin.firestore().collection("commission_rules")
      .orderBy("version", "desc")
      .limit(30)
      .get();
  return {
    items: snap.docs.map((doc) => Object.assign({ruleId: doc.id}, doc.data())),
  };
});

const migrateActivationCodes = onCall({
  region: "asia-east1",
  timeoutSeconds: 120,
  memory: "256MiB",
}, async (request) => {
  const user = await platformUser(request);
  return ops.migrateActivationCodes(user, request.data || {});
});

const reconcileSalesSummaries = onCall({
  region: "asia-east1",
  timeoutSeconds: 120,
  memory: "256MiB",
}, async (request) => {
  const user = await platformUser(request);
  return ops.reconcileSalesSummaries(user, request.data || {});
});

const updateShopPlan = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.updateShopPlan(user, request.data || {});
});

const applyDueShopPlans = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.applyDueShopPlans(user, request.data || {});
});

const previewSubscriptionPayment = onCall(options, async (request) => {
  const user = await platformUser(request);
  return ops.previewSubscriptionPayment(user, request.data || {});
});

const salesMonthSummary = onCall(options, async (request) => {
  const user = await platformUser(request);
  const month = String((request.data || {}).month || "");
  if (!/^\d{4}-\d{2}$/.test(month)) {
    throw new HttpsError("invalid-argument", "請用 YYYY-MM");
  }
  const manage = hasPlatformAccess(user, ["manage_sales"]) ||
    hasPlatformAccess(user, ["manage_subscription_finance"]);
  const db = admin.firestore();
  if (!manage) {
    if (!hasPlatformAccess(user, ["view_own_sales", "view_own_commission"])) {
      throw new HttpsError("permission-denied", "沒有這項權限");
    }
    const own = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    if (own.empty) {
      throw new HttpsError("permission-denied", "這個帳號沒有綁定業務");
    }
    const repId = own.docs[0].id;
    const doc = await db.collection("sales_month_summaries")
        .doc(`${repId}_${month}`).get();
    const row = doc.data() || {};
    const ownMoney = hasPlatformAccess(user, [
      "view_own_commission",
      "view_own_sales",
      "manage_subscription_finance",
    ]);
    return {items: [Object.assign({repId: repId, month: month}, row, {
      displayName: own.docs[0].get("displayName") || "",
      commissionVisible: ownMoney,
    })]};
  }
  const finance = hasPlatformAccess(user, ["manage_subscription_finance"]);
  const snap = await db.collection("sales_month_summaries")
      .where("month", "==", month)
      .limit(100)
      .get();
  return {
    items: snap.docs.map((doc) => {
      const row = Object.assign({}, doc.data());
      if (!finance) {
        delete row.earnedCommissionMinor;
        delete row.openCommissionMinor;
        delete row.paidCommissionMinor;
        delete row.adjustmentMinor;
        delete row.recoveryMinor;
      }
      row.commissionVisible = finance;
      return row;
    }),
  };
});

module.exports = {
  createShopWithActivation,
  validateShopActivationCode,
  saveSalesRep,
  listSalesReps,
  listAssignablePlatformMembers,
  getSalesIdentity,
  setSalesIdentity,
  saveActivationCode,
  listActivationCodes,
  registerSubscriptionPayment,
  confirmSubscriptionPayment,
  refundSubscriptionPayment,
  grantShopEntitlement,
  assignShopSales,
  saveCommissionRule,
  settleCommission,
  migrateShopCommercialData,
  listSubscriptionShops,
  listSubscriptionPayments,
  getShopCommercial,
  listResponsibleShops,
  listCommissionEntries,
  listCommissionRules,
  migrateActivationCodes,
  reconcileSalesSummaries,
  previewSubscriptionPayment,
  updateShopPlan,
  applyDueShopPlans,
  salesMonthSummary,
};
