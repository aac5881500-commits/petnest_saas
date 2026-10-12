/**
 * 業務、激活碼、創店、訂閱收款與分潤的 Firestore 交易。
 * 客戶端不能自訂方案、天數、次數或業務來取得權益。
 */

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");
const {hasPlatformAccess} = require("../legal_pet/access");
const policy = require("./commercial_policy");

const FINANCE_PERMISSIONS = ["manage_subscription_finance"];
const SALES_MANAGE_PERMISSIONS = ["manage_sales"];
const CODE_PERMISSIONS = ["manage_activation_codes"];
const PLAN_PERMISSIONS = [
  "manage_shop_subscriptions",
  "manage_subscription_finance",
];

const OWNER_PERMISSIONS = [
  "manage_members",
  "edit_basic_info",
  "edit_business_info",
  "edit_media",
  "manage_environment",
  "manage_about",
  "manage_frontend_content",
  "manage_reviews",
  "manage_modules",
  "manage_bookings",
  "manage_chat",
  "manage_booking_settings",
  "manage_room_dashboard",
  "manage_room_types",
  "manage_rooms",
  "manage_devices",
  "manage_payment_settings",
  "manage_member_points",
  "manage_point_redemptions",
  "manage_addons",
  "view_inventory",
  "manage_inventory",
  "receive_inventory",
  "adjust_inventory",
  "view_inventory_cost",
  "view_store_orders",
  "manage_store_products",
  "manage_store_orders",
  "manage_store_settings",
  "manage_policy",
  "view_daycare_bookings",
  "manage_daycare_bookings",
  "manage_daycare_settings",
  "manage_daycare_pricing",
  "convert_daycare_to_accommodation",
  "adjust_daycare_price",
];

const LOCKABLE = ["cat_hotel", "dog_hotel", "grooming", "hospital", "store"];

/**
 * @param {Object} user 平台使用者
 * @param {string[]} required 權限
 */
function assertPermission(user, required) {
  if (!hasPlatformAccess(user, required)) {
    throw new HttpsError("permission-denied", "沒有這項權限");
  }
}

/**
 * null 代表清除排程欄位，空字串保留。
 * @param {Object} patch 更新
 * @return {Object}
 */
function assignmentPatch(patch) {
  const out = {};
  Object.keys(patch || {}).forEach((key) => {
    if (patch[key] == null) {
      out[key] = admin.firestore.FieldValue.delete();
    } else {
      out[key] = patch[key];
    }
  });
  return out;
}

/**
 * @param {string} dateKey 台北日期
 * @return {FirebaseFirestore.Timestamp}
 */
function taipeiEndTimestamp(dateKey) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey || "");
  if (!match) {
    return null;
  }
  return admin.firestore.Timestamp.fromDate(new Date(Date.UTC(
      Number(match[1]),
      Number(match[2]) - 1,
      Number(match[3]),
      15, 59, 59, 999,
  )));
}

/**
 * @param {string} plan 方案
 * @param {string} locked 模板
 * @return {string[]}
 */
function modulesFor(plan, locked) {
  if (plan === "pro") {
    return ["basic_info", ...LOCKABLE, "reports"];
  }
  const moduleName = LOCKABLE.indexOf(locked) >= 0 ? locked : "cat_hotel";
  return ["basic_info", moduleName, "reports"];
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} normalized 正規化代碼
 * @param {string} raw 使用者輸入
 * @return {Promise<FirebaseFirestore.QueryDocumentSnapshot|null>}
 */
async function findActivationCode(db, normalized, raw) {
  const conflict = await db.collection("activation_code_conflicts")
      .doc(normalized).get();
  if (conflict.exists && conflict.get("resolved") !== true) {
    throw new HttpsError(
        "failed-precondition",
        "這個激活碼有多筆舊資料待處理，請先處理衝突",
    );
  }
  const key = await db.collection("activation_code_keys").doc(normalized).get();
  if (key.exists && key.get("codeId")) {
    const doc = await db.collection("activation_codes")
        .doc(String(key.get("codeId"))).get();
    if (doc.exists) {
      const stored = policy.normalizeActivationCode(doc.get("code"));
      if (!doc.get("normalizedCode") || doc.get("normalizedCode") === stored) {
        return doc;
      }
    }
  }
  const byNormalized = await db.collection("activation_codes")
      .where("normalizedCode", "==", normalized)
      .limit(2)
      .get();
  if (byNormalized.size > 1) {
    throw new HttpsError("failed-precondition", "激活碼正規化後發生衝突");
  }
  if (byNormalized.size === 1) return byNormalized.docs[0];
  const values = policy.activationCodeLookupValues(raw).slice(0, 10);
  if (!values.length) return null;
  const legacy = await db.collection("activation_codes")
      .where("code", "in", values)
      .limit(2)
      .get();
  if (legacy.size > 1) {
    throw new HttpsError("failed-precondition", "找到多筆可能的舊激活碼");
  }
  return legacy.empty ? null : legacy.docs[0];
}

/**
 * @param {Object} request Callable request，auth 已由 access 確認
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function createShopWithActivation(request, data) {
  const uid = request.auth.uid;
  const name = String(data.name || "").trim();
  const city = String(data.city || "").trim();
  const district = String(data.district || "").trim();
  const requestId = String(data.requestId || "").trim();
  const rawCode = String(data.activationCode || "").trim();
  const policyVersion = Number(data.acceptedShopOwnerPolicyVersion || 0);
  if (!name || !city || !district || !rawCode) {
    throw new HttpsError("invalid-argument", "請填店名、縣市、區域與激活碼");
  }
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "缺少建立識別碼");
  }
  if (!Number.isInteger(policyVersion) || policyVersion < 1) {
    throw new HttpsError("failed-precondition", "請先同意平台店家條款");
  }
  const normalized = policy.normalizeActivationCode(rawCode);
  if (!normalized) {
    throw new HttpsError("invalid-argument", "激活碼不正確");
  }
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const requestRef = db.collection("sales_shop_create_requests")
      .doc(`${uid}_${requestId}`);
  const lockRef = db.collection("sales_owner_locks").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const counterRef = db.collection("platform_counters").doc("shops");
  const codeDoc = await findActivationCode(db, normalized, rawCode);
  if (!codeDoc) {
    throw new HttpsError("not-found", "找不到此激活碼");
  }
  const email = String((request.auth.token && request.auth.token.email) || "");

  return db.runTransaction(async (tx) => {
    const existingRequest = await tx.get(requestRef);
    if (existingRequest.exists) {
      return {
        shopId: existingRequest.get("shopId"),
        replayed: true,
      };
    }
    const lock = await tx.get(lockRef);
    if (lock.exists && lock.get("shopId")) {
      return {shopId: lock.get("shopId"), replayed: true};
    }
    const owned = await tx.get(db.collection("shop_members")
        .where("uid", "==", uid)
        .where("role", "==", "owner")
        .limit(1));
    if (!owned.empty) {
      const existingShopId = String(owned.docs[0].get("shopId") || "");
      return {shopId: existingShopId, replayed: true};
    }
    const codeSnap = await tx.get(codeDoc.ref);
    const code = codeSnap.data() || {};
    const decision = policy.canUseActivationCode(code, today);
    if (!decision.ok) {
      throw new HttpsError("failed-precondition", decision.reason);
    }
    const ownerSnap = await tx.get(userRef);
    const counterSnap = await tx.get(counterRef);
    const next = Number((counterSnap.data() || {}).current || 0) + 1;
    const shopCode = `SHOP${String(next).padStart(4, "0")}`;
    const shopRef = db.collection("shops").doc(shopCode);
    const retiredCodeRef = db.collection("retired_shop_codes").doc(shopCode);
    const shopExisting = await tx.get(shopRef);
    const retiredCode = await tx.get(retiredCodeRef);
    if (shopExisting.exists) {
      throw new HttpsError("aborted", "店家編號衝突，請再試一次");
    }
    if (retiredCode.exists) {
      throw new HttpsError(
          "aborted",
          "這個店家編號已永久停用，請再試一次",
      );
    }
    const openEventRef = db.collection("sales_summary_events")
        .doc(`open_${shopCode}`);
    const openEvent = await tx.get(openEventRef);
    const snapshot = policy.activationSourceSnapshot(
        Object.assign({id: codeSnap.id}, code),
    );
    const freeDays = snapshot.freeDays;
    const plan = ["free", "basic", "pro"].indexOf(snapshot.plan) >= 0 ?
      snapshot.plan : "free";
    const locked = LOCKABLE.indexOf(snapshot.module) >= 0 ?
      snapshot.module : "cat_hotel";
    const entitlement = freeDays > 0 ?
      policy.extendEntitlement({}, freeDays, today, "trial") :
      {paidUntilDate: "", entitlementSource: "none"};
    const paidUntil = entitlement.paidUntilDate ?
      taipeiEndTimestamp(entitlement.paidUntilDate) : null;
    const permissions = {};
    OWNER_PERMISSIONS.forEach((key) => {
      permissions[key] = true;
    });
    tx.set(counterRef, {
      current: next,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(shopRef, {
      shopId: shopCode,
      shopCode: shopCode,
      name: name,
      ownerUid: uid,
      profileLocked: true,
      lockedFields: ["name", "businessType", "city", "licenseNumber", "taxId"],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activationCode: rawCode,
      activationCodeId: codeSnap.id,
      activationFreeDays: freeDays,
      plan: plan,
      paidUntil: paidUntil,
      paidUntilDate: entitlement.paidUntilDate || "",
      trialUntil: entitlement.trialUntil || "",
      paidServiceUntil: "",
      giftUntil: "",
      entitlementSource: entitlement.entitlementSource,
      planStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedShopOwnerPolicyVersion: policyVersion,
      acceptedShopOwnerPolicyAt: admin.firestore.FieldValue.serverTimestamp(),
      businessType: locked,
      lockedModule: locked,
      phone: "",
      address: "",
      description: "",
      city: city,
      district: district,
      lineUrl: "",
      isOpen: true,
      businessHours: "",
      closedDays: [],
      serviceTypes: ["overnight"],
      isPublic: false,
      logoUrl: "",
      coverUrl: "",
      enabledModules: modulesFor(plan, locked),
      bookingEnabled: true,
      daycareEnabled: false,
      totalRooms: 1,
      depositEnabled: false,
      depositAmount: 0,
      bankName: "",
      accountName: "",
      accountNumber: "",
      paymentMethods: {cash: true, transfer: false},
      cleaningRooms: 0,
      maintenanceRooms: 0,
      maxAdvanceBookingDays: 30,
      defaultPricePerNight: 0,
      blockedDates: [],
      specialPrices: {},
    });
    tx.set(db.collection("shop_commercial").doc(shopCode), {
      shopId: shopCode,
      originSalesRepId: snapshot.salesRepId,
      currentSalesRepId: snapshot.salesRepId,
      shopSource: snapshot.shopSource,
      activationSourceSnapshot: snapshot,
      paidServiceUntil: "",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection("shop_members").doc(`${shopCode}_${uid}`), {
      shopId: shopCode,
      uid: uid,
      email: email,
      emailKey: email.trim().toLowerCase(),
      role: "owner",
      permissions: permissions,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const userPatch = {
      uid: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!ownerSnap.exists || !ownerSnap.get("email")) userPatch.email = email;
    if (!ownerSnap.exists || !ownerSnap.get("displayName")) {
      userPatch.displayName = String(
          (request.auth.token && request.auth.token.name) || "",
      );
    }
    if (!ownerSnap.exists || !ownerSnap.get("role")) userPatch.role = "user";
    if (!ownerSnap.exists || !ownerSnap.get("status")) {
      userPatch.status = "active";
    }
    if (!ownerSnap.exists) {
      userPatch.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }
    tx.set(userRef, userPatch, {merge: true});
    tx.set(shopRef.collection("policy_acceptances")
        .doc(`shop_owner_policy_v${policyVersion}`), {
      type: "shop_owner_policy",
      version: policyVersion,
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedByUid: uid,
      acceptedByEmail: email,
    });
    const used = Number(code.usedCount || 0) + 1;
    const maxUses = Number(code.maxUses || 0);
    const exhausted = maxUses > 0 && used >= maxUses;
    tx.update(codeSnap.ref, {
      usedCount: used,
      enabled: exhausted ? false : code.enabled !== false,
      status: exhausted ? "exhausted" : "active",
      normalizedCode: policy.normalizeActivationCode(code.code || rawCode),
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection("activation_code_keys")
        .doc(policy.normalizeActivationCode(code.code || rawCode)), {
      codeId: codeSnap.id,
      normalizedCode: policy.normalizeActivationCode(code.code || rawCode),
    }, {merge: true});
    tx.set(codeSnap.ref.collection("usage_logs").doc(shopCode), {
      shopId: shopCode,
      shopName: name,
      usedByUid: uid,
      usedByEmail: email,
      plan: plan,
      freeDays: freeDays,
      module: locked,
      salesRepId: snapshot.salesRepId,
      campaignName: snapshot.campaignName,
      shopSource: snapshot.shopSource,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(requestRef, {
      uid: uid,
      requestId: requestId,
      shopId: shopCode,
      codeId: codeSnap.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(lockRef, {
      uid: uid,
      shopId: shopCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (snapshot.salesRepId && !openEvent.exists) {
      tx.set(openEventRef, {
        eventId: `open_${shopCode}`,
        repId: snapshot.salesRepId,
        month: today.slice(0, 7),
        kind: "new_shop",
      });
      tx.set(db.collection("sales_month_summaries")
          .doc(`${snapshot.salesRepId}_${today.slice(0, 7)}`), {
        repId: snapshot.salesRepId,
        month: today.slice(0, 7),
        newShops: admin.firestore.FieldValue.increment(1),
      }, {merge: true});
    }
    return {shopId: shopCode, replayed: false};
  });
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function saveActivationCode(user, data) {
  assertPermission(user, CODE_PERMISSIONS);
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const codeId = String(data.codeId || "").trim();
  const rawCode = String(data.code || "").trim();
  const normalized = policy.normalizeActivationCode(rawCode);
  if (!normalized || normalized.length > 40) {
    throw new HttpsError("invalid-argument", "請輸入激活碼");
  }
  const name = String(data.name || "").trim().slice(0, 80);
  const salesRepId = String(data.salesRepId || "");
  const campaignName = String(data.campaignName || "").trim().slice(0, 80);
  const useByDate = String(data.useByDate || "");
  if (useByDate && !/^\d{4}-\d{2}-\d{2}$/.test(useByDate)) {
    throw new HttpsError("invalid-argument", "使用截止日格式不正確");
  }
  const note = String(data.note || "").trim().slice(0, 500);
  const shopSource = policy.SOURCES.indexOf(data.shopSource) >= 0 ?
    data.shopSource : (salesRepId ? "sales" : "platform_direct");
  const ref = codeId ?
    db.collection("activation_codes").doc(codeId) :
    db.collection("activation_codes").doc();
  const keyRef = db.collection("activation_code_keys").doc(normalized);
  await db.runTransaction(async (tx) => {
    const key = await tx.get(keyRef);
    if (key.exists && key.get("codeId") && key.get("codeId") !== ref.id) {
      throw new HttpsError("already-exists", "這個激活碼已經存在");
    }
    const current = codeId ? await tx.get(ref) : null;
    if (codeId && (!current || !current.exists)) {
      throw new HttpsError("not-found", "找不到激活碼");
    }
    const previous = current && current.exists ? current.data() : {};
    const previousNorm = String(previous.normalizedCode ||
      policy.normalizeActivationCode(previous.code || ""));
    const oldKeyRef = previousNorm && previousNorm !== normalized ?
      db.collection("activation_code_keys").doc(previousNorm) : null;
    const oldKey = oldKeyRef ? await tx.get(oldKeyRef) : null;
    const maxUses = codeId ?
      Number(previous.maxUses || 0) :
      Math.max(1, Number(data.maxUses || 1));
    const freeDays = codeId ?
      Number(previous.freeDays || 0) :
      Math.max(0, Number(data.freeDays || 0));
    const plan = codeId ? String(previous.plan || "free") :
      (["free", "basic", "pro"].indexOf(data.plan) >= 0 ? data.plan : "free");
    const moduleName = codeId ? String(previous.module || "cat_hotel") :
      (LOCKABLE.indexOf(data.module) >= 0 ? data.module : "cat_hotel");
    const enabled = data.enabled === false ? false : true;
    const search = policy.activationSearchFields(rawCode, name);
    const payload = {
      code: rawCode,
      normalizedCode: search.normalizedCode,
      nameNorm: search.nameNorm,
      nameGrams: search.nameGrams,
      codePrefixes: search.codePrefixes,
      name: name,
      salesRepId: salesRepId,
      campaignName: campaignName,
      shopSource: shopSource,
      useByDate: useByDate,
      note: note,
      type: "shop_create",
      plan: plan,
      module: moduleName,
      maxUses: maxUses,
      freeDays: freeDays,
      enabled: enabled,
      usedCount: Number(previous.usedCount || 0),
      status: policy.activationStatus({
        enabled: enabled,
        useByDate: useByDate,
        maxUses: maxUses,
        usedCount: previous.usedCount || 0,
      }, today),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!codeId) {
      payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      payload.createdByUid = user.uid;
    }
    tx.set(ref, payload, {merge: true});
    if (oldKey && oldKey.exists && oldKey.get("codeId") === ref.id) {
      tx.delete(oldKeyRef);
    }
    tx.set(keyRef, {codeId: ref.id, normalizedCode: normalized});
  });
  return {codeId: ref.id};
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function saveSalesRep(user, data) {
  assertPermission(user, SALES_MANAGE_PERMISSIONS);
  const db = admin.firestore();
  const repId = String(data.repId || "").trim();
  const displayName = String(data.displayName || "").trim().slice(0, 40);
  if (!displayName) {
    throw new HttpsError("invalid-argument", "請輸入業務名稱");
  }
  const ref = repId ?
    db.collection("platform_sales_reps").doc(repId) :
    db.collection("platform_sales_reps").doc();
  const platformUid = String(data.platformUid || "").trim();
  if (platformUid) {
    const account = await db.collection("platform_users")
        .doc(platformUid).get();
    if (!account.exists) {
      throw new HttpsError("not-found", "找不到要綁定的平台帳號");
    }
  }
  const payload = {
    displayName: displayName,
    platformUid: platformUid,
    phone: String(data.phone || "").trim().slice(0, 40),
    email: String(data.email || "").trim().slice(0, 80),
    enabled: data.enabled !== false,
    note: String(data.note || "").trim().slice(0, 500),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!repId) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }
  const uidRef = platformUid ?
    db.collection("platform_sales_rep_uids").doc(platformUid) : null;
  await db.runTransaction(async (tx) => {
    const current = repId ? await tx.get(ref) : null;
    const previousUid = current && current.exists ?
      String(current.get("platformUid") || "") : "";
    const previousUidRef = previousUid && previousUid !== platformUid ?
      db.collection("platform_sales_rep_uids").doc(previousUid) : null;
    const previousUidSnap = previousUidRef ?
      await tx.get(previousUidRef) : null;
    const uidSnap = uidRef ? await tx.get(uidRef) : null;
    if (uidSnap && uidSnap.exists && uidSnap.get("repId") !== ref.id) {
      throw new HttpsError("already-exists", "這個平台帳號已綁定其他業務");
    }
    if (previousUidSnap && previousUidSnap.exists &&
        previousUidSnap.get("repId") === ref.id) {
      tx.delete(previousUidRef);
    }
    if (uidRef) tx.set(uidRef, {repId: ref.id});
    tx.set(ref, payload, {merge: true});
  });
  return {repId: ref.id};
}

/**
 * @param {Object} user 平台使用者
 * @return {Promise<Object>}
 */
async function listSalesReps(user) {
  const ownOnly = !hasPlatformAccess(user, SALES_MANAGE_PERMISSIONS) &&
    !hasPlatformAccess(user, FINANCE_PERMISSIONS);
  const db = admin.firestore();
  if (ownOnly) {
    if (!hasPlatformAccess(user, ["view_own_sales"])) {
      throw new HttpsError("permission-denied", "沒有這項權限");
    }
    const snap = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    return {reps: snap.docs.map(presentRep)};
  }
  assertPermission(user, SALES_MANAGE_PERMISSIONS.concat(FINANCE_PERMISSIONS));
  const snap = await db.collection("platform_sales_reps")
      .orderBy("displayName")
      .limit(100)
      .get();
  return {reps: snap.docs.map(presentRep)};
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc 文件
 * @return {Object}
 */
function presentRep(doc) {
  const data = doc.data() || {};
  return {
    repId: doc.id,
    displayName: data.displayName || "",
    platformUid: data.platformUid || "",
    phone: data.phone || "",
    email: data.email || "",
    enabled: data.enabled !== false,
    note: data.note || "",
  };
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function registerSubscriptionPayment(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const shopId = String(data.shopId || "").trim();
  const requestId = String(data.requestId || "").trim();
  const plan = String(data.plan || "");
  const cycle = String(data.cycle || "");
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家");
  }
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "缺少收款識別碼");
  }
  let priced;
  try {
    priced = policy.planPaymentAmounts(data);
  } catch (error) {
    throw new HttpsError("invalid-argument", error.message);
  }
  const paymentDate = String(
      data.paymentDate || policy.taipeiDateKey(new Date()),
  );
  if (!/^\d{4}-\d{2}-\d{2}$/.test(paymentDate)) {
    throw new HttpsError("invalid-argument", "付款日期不正確");
  }
  const db = admin.firestore();
  const shop = await db.collection("shops").doc(shopId).get();
  if (!shop.exists) {
    throw new HttpsError("not-found", "找不到店家");
  }
  const commercial = await db.collection("shop_commercial").doc(shopId).get();
  const shopData = shop.data() || {};
  const commercialData = commercial.exists ? commercial.data() : {};
  const ref = db.collection("shop_subscription_payments")
      .doc(`reg_${user.uid}_${requestId}`);
  const existing = await ref.get();
  if (existing.exists) {
    return {
      paymentId: ref.id,
      amountDueMinor: existing.get("amountDueMinor"),
      replayed: true,
      preview: {
        serviceStart: existing.get("serviceStart") || "",
        serviceEnd: existing.get("serviceEnd") || "",
      },
    };
  }
  const preview = policy.previewPaidPeriod(
      shopData,
      paymentDate,
      cycle === "year" ? 12 : 1,
  );
  await ref.set({
    shopId: shopId,
    requestId: requestId,
    plan: plan,
    cycle: cycle,
    priceMinor: priced.standardPriceMinor,
    standardPriceMinor: priced.standardPriceMinor,
    amountDueMinor: priced.amountDueMinor,
    amountReceivedMinor: priced.amountReceivedMinor,
    differenceReason: String(data.differenceReason || "").slice(0, 200),
    grantFullPeriodDespiteShortfall: priced.shortfall,
    currency: "TWD",
    paymentDate: paymentDate,
    serviceStart: preview.start,
    serviceEnd: preview.end,
    method: String(data.method || "transfer").slice(0, 40),
    reference: String(data.reference || "").slice(0, 80),
    note: String(data.note || "").slice(0, 500),
    status: "draft",
    refundedMinor: 0,
    refundProgress: "none",
    originSalesRepId: String(
        commercialData.originSalesRepId || shopData.originSalesRepId || "",
    ),
    currentSalesRepId: String(
        commercialData.currentSalesRepId || shopData.currentSalesRepId || "",
    ),
    createdBy: user.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {
    paymentId: ref.id,
    amountDueMinor: priced.amountDueMinor,
    replayed: false,
    preview: preview,
  };
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function previewSubscriptionPayment(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const shopId = String(data.shopId || "").trim();
  const db = admin.firestore();
  const shop = await db.collection("shops").doc(shopId).get();
  if (!shop.exists) throw new HttpsError("not-found", "找不到店家");
  let priced;
  try {
    priced = policy.planPaymentAmounts(Object.assign({
      amountDueMinor: policy.catalogAmount(data.plan, data.cycle),
      amountReceivedMinor: policy.catalogAmount(data.plan, data.cycle),
    }, data));
  } catch (error) {
    throw new HttpsError("invalid-argument", error.message);
  }
  const today = String(data.paymentDate || policy.taipeiDateKey(new Date()));
  const shopData = shop.data() || {};
  const due = policy.materializeDuePlan(shopData, today);
  const shopView = due ? policy.applyPlanPatch(shopData, due.patch) : shopData;
  const preview = policy.previewPaidPeriod(
      shopView,
      today,
      data.cycle === "year" ? 12 : 1,
  );
  const schedule = policy.resolvePlanSchedule(shopView, today);
  const switching = schedule.effectivePlan &&
    schedule.effectivePlan !== data.plan && preview.start > today;
  return {
    standardPriceMinor: priced.standardPriceMinor,
    preview: preview,
    nextPlan: schedule.nextPlan || (switching ? data.plan : ""),
    nextPlanStarts: schedule.nextPlanStarts || (switching ? preview.start : ""),
  };
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function confirmSubscriptionPayment(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const paymentId = String(data.paymentId || "").trim();
  if (!paymentId) {
    throw new HttpsError("invalid-argument", "缺少收款編號");
  }
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const paymentRef = db.collection("shop_subscription_payments").doc(paymentId);
  const rulesSnap = await db.collection("commission_rules")
      .where("enabled", "==", true)
      .limit(20)
      .get();
  const rules = rulesSnap.docs.map((doc) => {
    return Object.assign({id: doc.id}, doc.data());
  });
  return db.runTransaction(async (tx) => {
    const paymentSnap = await tx.get(paymentRef);
    if (!paymentSnap.exists) {
      throw new HttpsError("not-found", "找不到收款");
    }
    const payment = Object.assign({id: paymentSnap.id}, paymentSnap.data());
    const shopRef = db.collection("shops").doc(payment.shopId);
    const shopSnap = await tx.get(shopRef);
    if (!shopSnap.exists) {
      throw new HttpsError("not-found", "找不到店家");
    }
    const shop = shopSnap.data() || {};
    const commercialRef = db.collection("shop_commercial").doc(payment.shopId);
    const commercialSnap = await tx.get(commercialRef);
    const commercial = commercialSnap.exists ?
      (commercialSnap.data() || {}) : {};
    const attribution = policy.salesAttribution(commercial, shop);
    const due = policy.materializeDuePlan(shop, today);
    const shopView = due ? policy.applyPlanPatch(shop, due.patch) : shop;
    const planned = policy.planPaymentConfirm({
      payment: payment,
      shop: shopView,
      rules: rules,
      today: today,
      attribution: attribution,
    });
    if (planned.alreadyConfirmed) {
      return {paymentId: paymentId, replayed: true};
    }
    const commissionRef = planned.commission ?
      db.collection("commission_entries").doc(planned.commission.id) :
      null;
    const eventRef = db.collection("sales_summary_events")
        .doc(`pay_${paymentId}`);
    const renewRef = db.collection("sales_summary_events")
        .doc(`renewshop_${payment.shopId}_${today.slice(0, 7)}`);
    const existingCommission = commissionRef ?
      await tx.get(commissionRef) : null;
    const eventSnap = await tx.get(eventRef);
    const renewSnap = await tx.get(renewRef);
    if (eventSnap.exists) {
      return {paymentId: paymentId, replayed: true};
    }
    if (existingCommission && existingCommission.exists) {
      planned.commission = null;
    }
    const snapshot = planned.attribution || attribution;
    tx.update(paymentRef, {
      status: "confirmed",
      serviceStart: planned.serviceStart,
      serviceEnd: planned.serviceEnd,
      originSalesRepId: snapshot.originSalesRepId,
      currentSalesRepId: snapshot.currentSalesRepId,
      shopSource: snapshot.shopSource,
      performanceRepId: snapshot.performanceRepId,
      confirmedBy: user.uid,
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const paidUntil = taipeiEndTimestamp(planned.patch.paidUntilDate);
    tx.update(shopRef, Object.assign(
        {},
        assignmentPatch(due ? due.patch : {}),
        assignmentPatch(planned.patch),
        {
          paidUntil: paidUntil,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
    ));
    tx.set(commercialRef, {
      paidServiceUntil: planned.patch.paidServiceUntil || "",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (planned.commission && commissionRef) {
      tx.set(commissionRef, Object.assign({}, planned.commission, {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }));
    }
    const repId = snapshot.performanceRepId;
    const month = today.slice(0, 7);
    if (policy.shouldApplyPaymentSummary(false, false)) {
      tx.set(eventRef, {
        eventId: `pay_${paymentId}`,
        repId: repId,
        month: month,
      });
      tx.set(db.collection("sales_month_summaries").doc(`platform_${month}`), {
        repId: "platform",
        month: month,
        collectedMinor: admin.firestore.FieldValue.increment(
            planned.summaryDelta.collectedMinor,
        ),
      }, {merge: true});
      if (repId) {
        const renewal = planned.summaryDelta.renewal ?
          policy.renewalShopDelta(renewSnap.exists) : {shops: 0, payments: 0};
        const summaryId = `${repId}_${month}`;
        tx.set(db.collection("sales_month_summaries").doc(summaryId), {
          repId: repId,
          month: month,
          collectedMinor: admin.firestore.FieldValue.increment(
              planned.summaryDelta.collectedMinor,
          ),
          firstPaidShops: admin.firestore.FieldValue.increment(
              planned.summaryDelta.firstPaid,
          ),
          renewalShops: admin.firestore.FieldValue.increment(renewal.shops),
          renewalPayments: admin.firestore.FieldValue.increment(
              renewal.payments,
          ),
        }, {merge: true});
        if (renewal.shops) tx.set(renewRef, {shopId: payment.shopId, month});
      }
      if (planned.commission) {
        const beneficiary = planned.commission.beneficiaryRepId;
        const earned = planned.commission.amountMinor;
        tx.set(db.collection("sales_month_summaries")
            .doc(`${beneficiary}_${month}`), {
          repId: beneficiary,
          month: month,
          earnedCommissionMinor: admin.firestore.FieldValue.increment(earned),
          openCommissionMinor: admin.firestore.FieldValue.increment(earned),
        }, {merge: true});
      }
    }
    return {
      paymentId: paymentId,
      replayed: false,
      serviceEnd: planned.serviceEnd,
    };
  });
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function grantShopEntitlement(user, data) {
  assertPermission(user, PLAN_PERMISSIONS);
  const shopId = String(data.shopId || "").trim();
  const days = Number(data.days || 0);
  const reason = String(data.reason || "").trim();
  if (!shopId || !Number.isInteger(days) || days < 1 || days > 366) {
    throw new HttpsError("invalid-argument", "贈送天數不正確");
  }
  if (reason.length < 2) {
    throw new HttpsError("invalid-argument", "請填寫贈送或調整原因");
  }
  const db = admin.firestore();
  const today = policy.taipeiDateKey(new Date());
  const shopRef = db.collection("shops").doc(shopId);
  const adjustmentRef = db.collection("shop_entitlement_adjustments").doc();
  await db.runTransaction(async (tx) => {
    const shopSnap = await tx.get(shopRef);
    if (!shopSnap.exists) {
      throw new HttpsError("not-found", "找不到店家");
    }
    const patch = policy.extendEntitlement(
        shopSnap.data() || {}, days, today, "gift",
    );
    tx.update(shopRef, Object.assign({}, patch, {
      paidUntil: taipeiEndTimestamp(patch.paidUntilDate),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }));
    tx.set(adjustmentRef, {
      shopId: shopId,
      days: days,
      reason: reason,
      kind: "gift",
      paidUntilDate: patch.paidUntilDate,
      createdBy: user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function assignShopSales(user, data) {
  assertPermission(user, SALES_MANAGE_PERMISSIONS);
  const shopId = String(data.shopId || "").trim();
  const mode = String(data.mode || "");
  const repId = String(data.salesRepId || "");
  const reason = String(data.reason || "").trim();
  if (!shopId || (mode !== "current" && mode !== "origin")) {
    throw new HttpsError("invalid-argument", "歸屬調整不正確");
  }
  if (mode === "origin" && reason.length < 2) {
    throw new HttpsError("invalid-argument", "更正原始開發業務需要填寫理由");
  }
  const db = admin.firestore();
  const shopRef = db.collection("shops").doc(shopId);
  await db.runTransaction(async (tx) => {
    const shopSnap = await tx.get(shopRef);
    if (!shopSnap.exists) {
      throw new HttpsError("not-found", "找不到店家");
    }
    const commercialRef = db.collection("shop_commercial").doc(shopId);
    const commercialSnap = await tx.get(commercialRef);
    const before = commercialSnap.exists ?
      commercialSnap.data() : (shopSnap.data() || {});
    const field = mode === "origin" ? "originSalesRepId" : "currentSalesRepId";
    tx.set(commercialRef, {
      shopId: shopId,
      [field]: repId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    tx.set(db.collection("shop_attribution_events").doc(), {
      shopId: shopId,
      mode: mode,
      fromRepId: String(before[field] || ""),
      toRepId: repId,
      reason: reason,
      createdBy: user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function saveCommissionRule(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const enabled = data.enabled === true;
  const mode = data.mode === "percent" ? "percent" : "fixed";
  const applies = ["first_payment", "renewal", "both"];
  const appliesTo = applies.indexOf(data.appliesTo) >= 0 ?
    data.appliesTo : "both";
  const beneficiary = data.beneficiary === "current" ? "current" : "origin";
  const db = admin.firestore();
  const ref = db.collection("commission_rules").doc();
  const latest = await db.collection("commission_rules")
      .orderBy("version", "desc")
      .limit(1)
      .get();
  const stored = latest.empty ? 0 : latest.docs[0].get("version");
  const previous = Number(stored || 0);
  const version = previous + 1;
  await ref.set({
    version: version,
    enabled: enabled,
    mode: mode,
    fixedMinor: Math.max(0, Number(data.fixedMinor || 0)),
    percentBps: Math.max(0, Number(data.percentBps || 0)),
    appliesTo: appliesTo,
    beneficiary: beneficiary,
    effectiveFrom: String(data.effectiveFrom || ""),
    effectiveUntil: String(data.effectiveUntil || ""),
    createdBy: user.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {ruleId: ref.id, version: version};
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function settleCommission(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const entryId = String(data.entryId || "").trim();
  const action = String(data.action || "");
  if (!entryId) {
    throw new HttpsError("invalid-argument", "缺少分潤");
  }
  const db = admin.firestore();
  const ref = db.collection("commission_entries").doc(entryId);
  const eventRef = db.collection("sales_summary_events")
      .doc(`settle_${entryId}_${action}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const eventSnap = await tx.get(eventRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "找不到分潤");
    }
    const status = String(snap.get("status") || "");
    if (eventSnap.exists || (status === "paid" && action === "paid") ||
        (status === "cancelled" && action === "cancelled") ||
        (status === action)) {
      return {ok: true, replayed: true, status: status};
    }
    if (!policy.canChangeCommissionStatus(status, action)) {
      throw new HttpsError("failed-precondition", "這個分潤狀態不能這樣變更");
    }
    const accrualMonth = String(snap.get("accrualMonth") || "");
    const beneficiary = String(snap.get("beneficiaryRepId") || "");
    const storedOpen = snap.get("openMinor");
    const openMinor = storedOpen == null ?
      Number(snap.get("amountMinor") || 0) :
      Number(storedOpen);
    const patch = {
      status: action,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    let move = null;
    if (action === "paid" || action === "recovered") {
      const payoutMinor = Number.isInteger(Number(data.amountMinor)) ?
        Number(data.amountMinor) : openMinor;
      try {
        move = policy.planPayoutMove({
          accrualMonth: accrualMonth,
          payoutMonth: String(data.paidOn || policy.taipeiDateKey(new Date()))
              .slice(0, 7),
          openMinor: openMinor,
          payoutMinor: payoutMinor,
          reason: data.reason || "",
        });
      } catch (error) {
        throw new HttpsError("invalid-argument", error.message);
      }
      patch.paidOn = String(data.paidOn || policy.taipeiDateKey(new Date()));
      patch.paidMonth = move.payoutMonth;
      patch.payoutReference = String(data.reference || "").slice(0, 80);
      patch.payoutMinor = payoutMinor;
      patch.payoutVarianceMinor = move.variance;
      patch.payoutVarianceReason = String(data.reason || "").slice(0, 200);
      patch.paidBy = user.uid;
      patch.openMinor = 0;
    }
    if (action === "cancelled") {
      patch.openMinor = 0;
      patch.cancelledMinor = openMinor;
    }
    tx.update(ref, patch);
    tx.set(eventRef, {entryId: entryId, action: action});
    if (beneficiary && accrualMonth && action === "cancelled") {
      tx.set(db.collection("sales_month_summaries")
          .doc(`${beneficiary}_${accrualMonth}`), {
        repId: beneficiary,
        month: accrualMonth,
        openCommissionMinor: admin.firestore.FieldValue.increment(-openMinor),
        adjustmentMinor: admin.firestore.FieldValue.increment(openMinor),
      }, {merge: true});
    }
    if (move && beneficiary) {
      tx.set(db.collection("sales_month_summaries")
          .doc(`${beneficiary}_${move.accrualMonth}`), {
        repId: beneficiary,
        month: move.accrualMonth,
        openCommissionMinor: admin.firestore.FieldValue.increment(
            move.accrualOpenDelta,
        ),
        adjustmentMinor: admin.firestore.FieldValue.increment(
            move.accrualAdjustmentDelta,
        ),
      }, {merge: true});
      tx.set(db.collection("sales_month_summaries")
          .doc(`${beneficiary}_${move.payoutMonth}`), {
        repId: beneficiary,
        month: move.payoutMonth,
        paidCommissionMinor: admin.firestore.FieldValue.increment(
            move.payoutPaidDelta,
        ),
      }, {merge: true});
    }
    return {ok: true, replayed: false, status: action};
  });
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function refundSubscriptionPayment(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const paymentId = String(data.paymentId || "").trim();
  const requestId = String(data.requestId || "").trim();
  const refundMinor = Number(data.refundMinor);
  const reason = String(data.reason || "").trim();
  if (!paymentId || reason.length < 2) {
    throw new HttpsError("invalid-argument", "退款金額與理由都要填寫");
  }
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "缺少退款識別碼");
  }
  const db = admin.firestore();
  const paymentRef = db.collection("shop_subscription_payments").doc(paymentId);
  const refundRef = db.collection("shop_subscription_payments")
      .doc(`${paymentId}_refund_${requestId}`);
  const month = policy.taipeiDateKey(new Date()).slice(0, 7);
  return db.runTransaction(async (tx) => {
    const existingRefund = await tx.get(refundRef);
    if (existingRefund.exists) {
      return {
        refundId: refundRef.id,
        replayed: true,
        refundedMinor: existingRefund.get("refundedMinorAfter") || 0,
      };
    }
    const paymentSnap = await tx.get(paymentRef);
    if (!paymentSnap.exists || paymentSnap.get("status") !== "confirmed") {
      throw new HttpsError("failed-precondition", "只有已確認收款可以退款");
    }
    if (paymentSnap.get("kind") === "refund") {
      throw new HttpsError("failed-precondition", "不能對退款紀錄再退款");
    }
    let refundPlan;
    try {
      refundPlan = policy.planRefund({
        receivedMinor: paymentSnap.get("amountReceivedMinor") || 0,
        refundedMinor: paymentSnap.get("refundedMinor") || 0,
        refundMinor: refundMinor,
      });
    } catch (error) {
      throw new HttpsError("invalid-argument", error.message);
    }
    if (refundPlan.anomaly) {
      throw new HttpsError("failed-precondition", refundPlan.reason);
    }
    const entryRef = db.collection("commission_entries")
        .doc(`pay_${paymentId}`);
    const entrySnap = await tx.get(entryRef);
    const summaryEventRef = db.collection("sales_summary_events")
        .doc(`refund_${paymentId}_${requestId}`);
    const summaryEvent = await tx.get(summaryEventRef);
    let claw = null;
    let adjustRef = null;
    if (entrySnap.exists) {
      claw = policy.planCommissionClawback(
          entrySnap.data(),
          Number(paymentSnap.get("refundedMinor") || 0),
          refundMinor,
          requestId,
      );
      if (claw && claw.adjustment) {
        adjustRef = db.collection("commission_entries").doc(claw.adjustment.id);
        const existingAdjust = await tx.get(adjustRef);
        if (existingAdjust.exists) claw.adjustment = null;
      }
    }
    tx.set(refundRef, {
      shopId: paymentSnap.get("shopId"),
      plan: paymentSnap.get("plan"),
      cycle: paymentSnap.get("cycle"),
      priceMinor: paymentSnap.get("priceMinor"),
      amountDueMinor: 0,
      amountReceivedMinor: -refundMinor,
      currency: "TWD",
      paymentDate: policy.taipeiDateKey(new Date()),
      method: paymentSnap.get("method") || "",
      reference: String(data.reference || "").slice(0, 80),
      note: reason,
      status: "confirmed",
      kind: "refund",
      refundedMinorAfter: refundPlan.refundedMinor,
      originalPaymentId: paymentId,
      originSalesRepId: paymentSnap.get("originSalesRepId") || "",
      currentSalesRepId: paymentSnap.get("currentSalesRepId") || "",
      createdBy: user.uid,
      confirmedBy: user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(paymentRef, {
      refundedMinor: refundPlan.refundedMinor,
      refundProgress: refundPlan.refundProgress,
    });
    if (claw && entrySnap.exists) {
      const entryPatch = {
        clawedMinor: claw.clawedMinor,
        openMinor: claw.openMinor,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (claw.cancelOriginal) entryPatch.status = "cancelled";
      tx.update(entryRef, entryPatch);
      if (claw.adjustment && adjustRef) {
        tx.set(adjustRef, Object.assign({}, claw.adjustment, {
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }));
      }
    }
    if (!summaryEvent.exists) {
      tx.set(summaryEventRef, {paymentId: paymentId, requestId: requestId});
      tx.set(db.collection("sales_month_summaries").doc(`platform_${month}`), {
        repId: "platform",
        month: month,
        refundMinor: admin.firestore.FieldValue.increment(refundMinor),
      }, {merge: true});
      const beneficiary = entrySnap.exists ?
        String(entrySnap.get("beneficiaryRepId") || "") : "";
      const accrualMonth = entrySnap.exists ?
        String(entrySnap.get("accrualMonth") || month) : month;
      if (beneficiary && claw) {
        const reversed = claw.cancelOriginal ?
          Number(entrySnap.get("openMinor") ||
            entrySnap.get("amountMinor") || 0) :
          (claw.adjustment ? claw.adjustment.amountMinor : 0);
        if (reversed && entrySnap.get("status") !== "paid") {
          tx.set(db.collection("sales_month_summaries")
              .doc(`${beneficiary}_${accrualMonth}`), {
            repId: beneficiary,
            month: accrualMonth,
            openCommissionMinor: admin.firestore.FieldValue
                .increment(-reversed),
            adjustmentMinor: admin.firestore.FieldValue.increment(reversed),
          }, {merge: true});
        }
        if (claw.adjustment && claw.adjustment.kind === "recovery") {
          tx.set(db.collection("sales_month_summaries")
              .doc(`${beneficiary}_${month}`), {
            repId: beneficiary,
            month: month,
            recoveryMinor: admin.firestore.FieldValue.increment(
                claw.adjustment.amountMinor,
            ),
          }, {merge: true});
        }
      }
    }
    return {
      refundId: refundRef.id,
      replayed: false,
      refundProgress: refundPlan.refundProgress,
      refundedMinor: refundPlan.refundedMinor,
    };
  });
}

/**
 * 分批標記只有 paidUntil、沒有收款的舊店。不縮短期限、不推測業務。
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function migrateShopCommercialData(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const dryRun = data.dryRun !== false;
  const limit = Math.min(200, Math.max(1, Number(data.limit || 100)));
  const db = admin.firestore();
  let query = db.collection("shops").orderBy("shopCode").limit(limit);
  if (data.cursor) {
    const cursor = await db.collection("shops").doc(String(data.cursor)).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }
  const snap = await query.get();
  let marked = 0;
  let moved = 0;
  const batch = db.batch();
  snap.docs.forEach((doc) => {
    const shop = doc.data() || {};
    const patch = policy.legacyEntitlementPatch(shop);
    const commercial = {};
    const remove = {};
    ["originSalesRepId", "currentSalesRepId", "shopSource",
      "activationSourceSnapshot"].forEach((key) => {
      if (shop[key] == null || shop[key] === "") return;
      commercial[key] = shop[key];
      remove[key] = admin.firestore.FieldValue.delete();
    });
    if (shop.paidServiceUntil) {
      commercial.paidServiceUntil = shop.paidServiceUntil;
    }
    if (patch.entitlementSource) marked += 1;
    if (!dryRun && patch.entitlementSource) {
      batch.set(doc.ref, patch, {merge: true});
    }
    if (Object.keys(commercial).length > 0) {
      moved += 1;
      if (!dryRun) {
        batch.set(db.collection("shop_commercial").doc(doc.id), commercial, {
          merge: true,
        });
        if (Object.keys(remove).length > 0) batch.update(doc.ref, remove);
      }
    }
  });
  if (!dryRun && (marked > 0 || moved > 0)) await batch.commit();
  const last = snap.docs.length ? snap.docs[snap.docs.length - 1].id : "";
  return {
    dryRun: dryRun,
    scanned: snap.docs.length,
    markedLegacy: marked,
    movedCommercial: moved,
    nextCursor: snap.docs.length < limit ? "" : last,
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} repId 業務
 * @return {Promise<string>}
 */
async function repName(db, repId) {
  if (!repId) return "";
  const doc = await db.collection("platform_sales_reps").doc(repId).get();
  return doc.exists ? String(doc.get("displayName") || "") : "";
}

/**
 * @param {Object} user 平台使用者
 * @param {string} shopId 店家
 * @return {Promise<Object|null>}
 */
async function shopCommercialSummary(user, shopId) {
  if (!shopId) return null;
  const db = admin.firestore();
  const shop = await db.collection("shops").doc(shopId).get();
  if (!shop.exists) return null;
  const data = shop.data() || {};
  const commercialSnap = await db.collection("shop_commercial")
      .doc(shopId).get();
  const commercial = commercialSnap.exists ? commercialSnap.data() : {};
  const originId = String(
      commercial.originSalesRepId || data.originSalesRepId || "",
  );
  const currentId = String(
      commercial.currentSalesRepId || data.currentSalesRepId || "",
  );
  let allowed = hasPlatformAccess(user, FINANCE_PERMISSIONS) ||
    hasPlatformAccess(user, SALES_MANAGE_PERMISSIONS) ||
    hasPlatformAccess(user, PLAN_PERMISSIONS);
  if (!allowed && hasPlatformAccess(user, ["view_own_sales"])) {
    const own = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(1)
        .get();
    const repId = own.empty ? "" : own.docs[0].id;
    allowed = repId !== "" && (
      originId === repId || currentId === repId
    );
  }
  if (!allowed) return null;
  const today = policy.taipeiDateKey(new Date());
  const finance = hasPlatformAccess(user, FINANCE_PERMISSIONS);
  const originName = await repName(db, originId);
  const currentName = originId === currentId ?
    originName : await repName(db, currentId);
  return {
    shopSource: commercial.shopSource || data.shopSource || "",
    originSalesRepId: originId,
    currentSalesRepId: currentId,
    originSalesName: originName,
    currentSalesName: currentName,
    plan: data.plan || "",
    entitlementSource: data.entitlementSource || "",
    paidUntilDate: data.paidUntilDate || "",
    paidServiceUntil: data.paidServiceUntil || "",
    trialUntil: data.trialUntil || "",
    giftUntil: data.giftUntil || "",
    listStatus: policy.subscriptionListStatus(data, today),
    renewalDue: policy.renewalDue(data, today),
    activationCode: data.activationCode || "",
    campaignName: (commercial.activationSourceSnapshot ||
      data.activationSourceSnapshot || {}).campaignName || "",
    nextPlan: data.nextPlan || "",
    nextPlanStarts: data.nextPlanStarts || "",
    financeVisible: finance,
  };
}

/**
 * 補上舊激活碼的正規化與搜尋欄位。衝突只列出，不合併。
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function migrateActivationCodes(user, data) {
  assertPermission(user, CODE_PERMISSIONS);
  const dryRun = data.dryRun !== false;
  const limit = Math.min(100, Math.max(1, Number(data.limit || 50)));
  const db = admin.firestore();
  let query = db.collection("activation_codes")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(limit);
  if (data.cursor) query = query.startAfter(String(data.cursor));
  const snap = await query.get();
  const rows = snap.docs.map((doc) => {
    const row = doc.data() || {};
    const search = policy.activationSearchFields(
        row.code || "", row.name || "",
    );
    return {
      id: doc.id,
      code: row.code || "",
      storedNormalized: row.normalizedCode || "",
      hasGrams: Array.isArray(row.nameGrams) && row.nameGrams.length > 0,
      nameNorm: search.nameNorm,
      nameGrams: search.nameGrams,
      codePrefixes: search.codePrefixes,
      useByDate: row.useByDate || policy.effectiveUseByDate(row),
    };
  });
  const owners = {};
  const norms = [];
  rows.forEach((row) => {
    const normalized = policy.normalizeActivationCode(row.code);
    if (normalized && norms.indexOf(normalized) < 0) norms.push(normalized);
  });
  for (const normalized of norms) {
    const key = await db.collection("activation_code_keys")
        .doc(normalized).get();
    if (key.exists && key.get("codeId")) {
      owners[normalized] = String(key.get("codeId"));
    }
  }
  const planned = policy.planActivationMigration(rows, owners);
  const conflicts = planned.conflicts.slice();
  let updated = 0;
  if (!dryRun) {
    for (const row of planned.updates) {
      const unchanged = row.storedNormalized === row.normalizedCode &&
        row.hasGrams && !row.bindKey;
      if (unchanged) continue;
      const keyRef = db.collection("activation_code_keys")
          .doc(row.normalizedCode);
      const codeRef = db.collection("activation_codes").doc(row.id);
      const conflictRef = db.collection("activation_code_conflicts")
          .doc(row.normalizedCode);
      const claimed = await db.runTransaction(async (tx) => {
        const keySnap = await tx.get(keyRef);
        const existingId = keySnap.exists ?
          String(keySnap.get("codeId") || "") : "";
        const claim = policy.claimActivationKey(existingId, row.id);
        if (!claim.ok) {
          tx.set(conflictRef, {
            normalizedCode: row.normalizedCode,
            codeIds: admin.firestore.FieldValue.arrayUnion(row.id, existingId),
            resolved: false,
            reason: claim.reason,
          }, {merge: true});
          return {ok: false, existingId: existingId, reason: claim.reason};
        }
        tx.set(codeRef, {
          normalizedCode: row.normalizedCode,
          nameNorm: row.nameNorm,
          nameGrams: row.nameGrams,
          codePrefixes: row.codePrefixes,
          useByDate: row.useByDate,
        }, {merge: true});
        tx.set(keyRef, {
          codeId: row.id,
          normalizedCode: row.normalizedCode,
        });
        return {ok: true};
      });
      if (!claimed.ok) {
        conflicts.push({
          codeId: row.id,
          normalizedCode: row.normalizedCode,
          reason: claimed.reason,
          otherCodeIds: [claimed.existingId],
        });
        continue;
      }
      updated += 1;
    }
    for (const conflict of planned.conflicts) {
      const ids = [conflict.codeId].concat(conflict.otherCodeIds || []);
      await db.collection("activation_code_conflicts")
          .doc(conflict.normalizedCode)
          .set({
            normalizedCode: conflict.normalizedCode,
            codeIds: admin.firestore.FieldValue.arrayUnion(...ids),
            resolved: false,
            reason: conflict.reason,
          }, {merge: true});
    }
  }
  const last = snap.docs.length ? snap.docs[snap.docs.length - 1].id : "";
  const done = snap.docs.length < limit;
  let migrationReady = false;
  if (!dryRun && done) {
    const openConflict = await db.collection("activation_code_conflicts")
        .where("resolved", "==", false)
        .limit(1)
        .get();
    migrationReady = openConflict.empty;
    await db.collection("commercial_migration").doc("activation_codes").set({
      ready: migrationReady,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  return {
    dryRun: dryRun,
    scanned: snap.docs.length,
    updated: dryRun ? planned.updates.length : updated,
    conflicts: conflicts,
    nextCursor: done ? "" : last,
    migrationReady: migrationReady,
  };
}

/**
 * 只列出超退或不一致，不改收款歷史。可分批重建分潤摘要。
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function reconcileSalesSummaries(user, data) {
  assertPermission(user, FINANCE_PERMISSIONS);
  const dryRun = data.dryRun !== false;
  const limit = Math.min(100, Math.max(1, Number(data.limit || 50)));
  const passId = String(data.passId || "current");
  const db = admin.firestore();
  if (data.source === "payments") {
    let paymentQuery = db.collection("shop_subscription_payments")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
    if (data.cursor) {
      paymentQuery = paymentQuery.startAfter(String(data.cursor));
    }
    const paymentSnap = await paymentQuery.get();
    const paymentAnomalies = [];
    paymentSnap.docs.forEach((doc) => {
      const row = doc.data() || {};
      const received = Number(row.amountReceivedMinor || 0);
      const refunded = Number(row.refundedMinor || 0);
      if (row.kind !== "refund" && refunded > received) {
        paymentAnomalies.push({
          paymentId: doc.id,
          reason: "累計退款超過實收，未改寫原收款",
        });
      }
    });
    const paymentLast = paymentSnap.docs.length ?
      paymentSnap.docs[paymentSnap.docs.length - 1].id : "";
    return {
      dryRun: true,
      source: "payments",
      scanned: paymentSnap.docs.length,
      applied: 0,
      anomalies: paymentAnomalies,
      nextCursor: paymentSnap.docs.length < limit ? "" : paymentLast,
      passId: passId,
      stage: "payments",
      reportsUpdated: false,
    };
  }
  const passRef = db.collection("sales_summary_passes").doc(passId);
  const passSnap = await passRef.get();
  if (data.stage === "publish") {
    if (!passSnap.exists || passSnap.get("status") !== "rebuilt") {
      throw new HttpsError(
          "failed-precondition",
          "請先完成分批重建，再發布到實際報表",
      );
    }
    let publishQuery = db.collection("sales_summary_rebuilds")
        .orderBy(admin.firestore.FieldPath.documentId())
        .startAt(`${passId}_`)
        .endAt(`${passId}_\uf8ff`)
        .limit(limit);
    if (data.cursor) {
      publishQuery = publishQuery.startAfter(String(data.cursor));
    }
    const publishSnap = await publishQuery.get();
    let published = 0;
    for (const doc of publishSnap.docs) {
      const wrote = await db.runTransaction(async (tx) => {
        const markerRef = passRef.collection("published").doc(doc.id);
        const marker = await tx.get(markerRef);
        const fresh = await tx.get(doc.ref);
        const plan = policy.planSummaryPublish(
            fresh.data() || {},
            marker.exists,
        );
        if (plan.skip || dryRun) return false;
        tx.set(db.collection("sales_month_summaries").doc(plan.summaryId),
            plan.patch, {merge: true});
        tx.set(markerRef, {
          summaryId: plan.summaryId,
          publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (wrote) published += 1;
    }
    const publishDone = publishSnap.docs.length < limit;
    if (!dryRun && publishDone) {
      await passRef.set({
        status: "published",
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    const publishLast = publishSnap.docs.length ?
      publishSnap.docs[publishSnap.docs.length - 1].id : "";
    return {
      dryRun: dryRun,
      stage: !dryRun && publishDone ? "published" : "publishing",
      reportsUpdated: !dryRun && publishDone,
      scanned: publishSnap.docs.length,
      applied: published,
      anomalies: [],
      nextCursor: publishDone ? "" : publishLast,
      passId: passId,
    };
  }
  if (passSnap.exists && passSnap.get("status") === "published") {
    throw new HttpsError(
        "failed-precondition",
        "這個核對批已經發布，請用新的 passId 重建",
    );
  }
  let query = db.collection("commission_entries")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(limit);
  if (data.cursor) query = query.startAfter(String(data.cursor));
  const snap = await query.get();
  const anomalies = [];
  let applied = 0;
  for (const doc of snap.docs) {
    const row = doc.data() || {};
    if (Number(row.clawedMinor || 0) > Number(row.amountMinor || 0)) {
      anomalies.push({entryId: doc.id, reason: "沖回超過原分潤，未改原分潤"});
      continue;
    }
    const seenRef = passRef.collection("seen").doc(doc.id);
    const wrote = await db.runTransaction(async (tx) => {
      const seen = await tx.get(seenRef);
      if (seen.exists) return false;
      const contributions = policy.summarizeCommissionEntry(row);
      const rebuildRefs = contributions.map((item) => {
        return db.collection("sales_summary_rebuilds")
            .doc(`${passId}_${item.repId}_${item.month}`);
      });
      if (dryRun) return true;
      for (const ref of rebuildRefs) await tx.get(ref);
      tx.set(seenRef, {entryId: doc.id});
      contributions.forEach((item, index) => {
        const patch = {repId: item.repId, month: item.month, passId: passId};
        ["earnedCommissionMinor", "openCommissionMinor", "adjustmentMinor",
          "paidCommissionMinor", "recoveryMinor"].forEach((key) => {
          if (item[key]) {
            patch[key] = admin.firestore.FieldValue.increment(item[key]);
          }
        });
        tx.set(rebuildRefs[index], patch, {merge: true});
      });
      return true;
    });
    if (wrote) applied += 1;
  }
  const last = snap.docs.length ? snap.docs[snap.docs.length - 1].id : "";
  const done = snap.docs.length < limit;
  if (!dryRun && done) {
    await passRef.set({
      status: "rebuilt",
      rebuiltAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  return {
    dryRun: dryRun,
    stage: done ? "rebuilt" : "rebuilding",
    reportsUpdated: false,
    scanned: snap.docs.length,
    applied: applied,
    anomalies: anomalies,
    nextCursor: done ? "" : last,
    passId: passId,
  };
}

/**
 * 方案切換只改方案與模組，不改收款與服務期限。
 * @param {Object} user 使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function updateShopPlan(user, data) {
  assertPermission(user, PLAN_PERMISSIONS);
  const shopId = String((data || {}).shopId || "").trim();
  const plan = String((data || {}).plan || "");
  if (!["free", "basic", "pro"].includes(plan)) {
    throw new HttpsError("invalid-argument", "方案不正確");
  }
  const db = admin.firestore();
  const ref = db.collection("shops").doc(shopId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "找不到店家");
    const locked = String(
        snap.get("lockedModule") || snap.get("businessType") || "cat_hotel",
    );
    tx.update(ref, {
      plan: plan,
      lockedModule: locked,
      enabledModules: modulesFor(plan, locked),
      nextPlan: admin.firestore.FieldValue.delete(),
      nextPlanStarts: admin.firestore.FieldValue.delete(),
      followingPlan: admin.firestore.FieldValue.delete(),
      followingPlanStarts: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  return {ok: true};
}

/**
 * 把已到生效日的下一期方案寫進店家方案與模組。
 * @param {Object|null} user 平台使用者，排程可省略
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function applyDueShopPlans(user, data) {
  if (user) assertPermission(user, PLAN_PERMISSIONS);
  const today = policy.taipeiDateKey(new Date());
  const limit = Math.min(100, Math.max(1, Number((data || {}).limit || 50)));
  const db = admin.firestore();
  let query = db.collection("shops")
      .where("nextPlanStarts", "<=", today)
      .orderBy("nextPlanStarts")
      .limit(limit);
  if (data && data.cursor) {
    const cursor = await db.collection("shops").doc(String(data.cursor)).get();
    if (cursor.exists) query = query.startAfter(cursor);
  }
  const snap = await query.get();
  let applied = 0;
  for (const doc of snap.docs) {
    const changed = await db.runTransaction(async (tx) => {
      const shopSnap = await tx.get(doc.ref);
      if (!shopSnap.exists) return false;
      const due = policy.materializeDuePlan(shopSnap.data() || {}, today);
      if (!due) return false;
      tx.update(doc.ref, Object.assign(assignmentPatch(due.patch), {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }));
      return true;
    });
    if (changed) applied += 1;
  }
  const last = snap.docs.length ? snap.docs[snap.docs.length - 1].id : "";
  return {
    applied: applied,
    scanned: snap.docs.length,
    nextCursor: snap.docs.length < limit ? "" : last,
    today: today,
  };
}

module.exports = {
  FINANCE_PERMISSIONS,
  SALES_MANAGE_PERMISSIONS,
  assertPermission,
  createShopWithActivation,
  saveActivationCode,
  saveSalesRep,
  listSalesReps,
  registerSubscriptionPayment,
  previewSubscriptionPayment,
  confirmSubscriptionPayment,
  grantShopEntitlement,
  assignShopSales,
  saveCommissionRule,
  settleCommission,
  refundSubscriptionPayment,
  migrateShopCommercialData,
  migrateActivationCodes,
  reconcileSalesSummaries,
  shopCommercialSummary,
  findActivationCode,
  updateShopPlan,
  applyDueShopPlans,
};
