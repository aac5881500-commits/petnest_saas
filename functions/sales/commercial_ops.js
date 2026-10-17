/**
 * 業務、激活碼、創店、訂閱收款與分潤的 Firestore 交易。
 * 客戶端不能自訂方案、天數、次數或業務來取得權益。
 */

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");
const {hasPlatformAccess, ROOT_ADMIN_UID} = require("../legal_pet/access");
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
  const previousSnap = codeId ?
    await db.collection("activation_codes").doc(codeId).get() : null;
  const previousCode = previousSnap && previousSnap.exists ?
    previousSnap.data() : {};
  let repExists = false;
  let repAccountExists = false;
  let repAccountEnabled = false;
  let repEnabled = false;
  let repUid = "";
  if (salesRepId) {
    const repSnap = await db.collection("platform_sales_reps")
        .doc(salesRepId).get();
    repExists = repSnap.exists;
    if (repSnap.exists) {
      repEnabled = repSnap.get("enabled") !== false;
      repUid = String(repSnap.get("platformUid") || "");
      if (repUid) {
        const account = await db.collection("platform_users").doc(repUid).get();
        repAccountExists = account.exists;
        repAccountEnabled = account.exists && account.get("enabled") !== false;
      }
    }
  }
  const binding = policy.planActivationRepBinding({
    updating: Boolean(codeId),
    salesRepId: salesRepId,
    previousSalesRepId: previousCode.salesRepId || "",
    shopSource: shopSource,
    usedCount: previousCode.usedCount || 0,
    reason: data.attributionReason,
    repExists: repExists,
    repEnabled: repEnabled,
    platformUid: repUid,
    accountExists: repAccountExists,
    accountEnabled: repAccountEnabled,
  });
  if (!binding.ok) {
    throw new HttpsError("failed-precondition", binding.error);
  }
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
    if (binding.recordAttributionChange) {
      tx.set(db.collection("activation_code_attribution_events").doc(), {
        codeId: ref.id,
        fromRepId: String(previousCode.salesRepId || ""),
        toRepId: salesRepId,
        reason: String(data.attributionReason || "").trim().slice(0, 200),
        createdBy: user.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        rewritesCommission: false,
      });
    }
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
  const ref = repId ?
    db.collection("platform_sales_reps").doc(repId) :
    db.collection("platform_sales_reps").doc();
  const platformUid = String(data.platformUid || "").trim();
  const existing = repId ? await ref.get() : null;
  if (repId && (!existing || !existing.exists)) {
    throw new HttpsError("not-found", "找不到業務");
  }
  const previousUid = existing && existing.exists ?
    String(existing.get("platformUid") || "") : "";
  let account = null;
  if (platformUid) {
    account = await db.collection("platform_users").doc(platformUid).get();
  }
  const uidRef = platformUid ?
    db.collection("platform_sales_rep_uids").doc(platformUid) : null;
  const uidSnap = uidRef ? await uidRef.get() : null;
  const plan = policy.planSalesRepWrite({
    creating: !repId,
    platformUid: platformUid,
    previousUid: previousUid,
    enabled: data.enabled !== false,
    accountExists: Boolean(account && account.exists),
    accountEnabled: Boolean(account && account.exists &&
      account.get("enabled") !== false),
    uidTaken: Boolean(uidSnap && uidSnap.exists &&
      uidSnap.get("repId") !== ref.id),
  });
  if (!plan.ok) {
    throw new HttpsError("failed-precondition", plan.error);
  }
  const accountName = account && account.exists ?
    String(account.get("name") || account.get("email") || "").trim() : "";
  const named = existing && existing.exists ?
    policy.repDisplayName(existing.data()) :
    {displayName: "", nameMissing: true};
  const displayName = (named.nameMissing ? accountName : named.displayName)
      .trim()
      .slice(0, 40);
  const phone = data.phone != null && String(data.phone).trim() ?
    String(data.phone).trim().slice(0, 40) :
    String(
        (existing && existing.exists && existing.get("phone")) ||
        (account && account.exists && account.get("phone")) ||
        "",
    ).trim().slice(0, 40);
  const email = data.email != null && String(data.email).trim() ?
    String(data.email).trim().slice(0, 80) :
    String(
        (existing && existing.exists && existing.get("email")) ||
        (account && account.exists && account.get("email")) ||
        "",
    ).trim().slice(0, 80);
  const note = Object.prototype.hasOwnProperty.call(data, "note") ?
    String(data.note || "").trim().slice(0, 500) :
    String(existing && existing.exists ? existing.get("note") || "" : "")
        .slice(0, 500);
  const payload = {
    displayName: displayName,
    platformUid: platformUid,
    phone: phone,
    email: email,
    enabled: data.enabled !== false,
    note: note,
    bindingStatus: plan.bindingStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!repId) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
    payload.createdByUid = user.uid;
  }
  await db.runTransaction(async (tx) => {
    const current = repId ? await tx.get(ref) : null;
    const currentUid = current && current.exists ?
      String(current.get("platformUid") || "") : "";
    const currentUidRef = currentUid && currentUid !== platformUid ?
      db.collection("platform_sales_rep_uids").doc(currentUid) : null;
    const currentUidSnap = currentUidRef ? await tx.get(currentUidRef) : null;
    const freshUid = uidRef ? await tx.get(uidRef) : null;
    if (freshUid && freshUid.exists && freshUid.get("repId") !== ref.id) {
      throw new HttpsError("already-exists", "這個平台帳號已綁定其他業務");
    }
    if (currentUidSnap && currentUidSnap.exists &&
        currentUidSnap.get("repId") === ref.id) {
      tx.delete(currentUidRef);
    }
    const events = current && current.exists &&
      Array.isArray(current.get("recentEvents")) ?
      current.get("recentEvents").slice(0, 7) : [];
    events.unshift({
      action: repId ? "update" : "assign",
      platformUid: platformUid,
      actorUid: user.uid,
      at: new Date().toISOString(),
    });
    payload.recentEvents = events;
    if (uidRef) tx.set(uidRef, {repId: ref.id});
    tx.set(ref, payload, {merge: true});
  });
  return {repId: ref.id, bindingStatus: plan.bindingStatus};
}

/**
 * 依文件編號分頁。缺少 displayName 的舊業務仍會出現。
 * 單次最多掃 8 批、每批 40 筆，游標與排序都使用文件編號。
 * @param {Object} user 平台使用者
 * @param {Object=} data 篩選與游標
 * @return {Promise<Object>}
 */
async function listSalesReps(user, data) {
  const request = data || {};
  const manage = hasPlatformAccess(user, SALES_MANAGE_PERMISSIONS);
  const finance = hasPlatformAccess(user, FINANCE_PERMISSIONS);
  const viewList = hasPlatformAccess(user, ["view_sales"]);
  const db = admin.firestore();
  if (!manage && !finance && !viewList) {
    if (!hasPlatformAccess(user, ["view_own_sales"])) {
      throw new HttpsError("permission-denied", "沒有這項權限");
    }
    const snap = await db.collection("platform_sales_reps")
        .where("platformUid", "==", user.uid)
        .limit(2)
        .get();
    return {
      reps: snap.docs.slice(0, 1).map((doc) => presentRep(doc, true)),
      nextCursor: "",
      conflict: snap.size > 1,
    };
  }
  const pageSize = 40;
  const status = ["enabled", "disabled", "pending"].indexOf(request.status) >= 0 ?
    request.status : "";
  const needle = String(request.query || "").trim().toLowerCase().slice(0, 40);
  let cursor = String(request.cursor || "").trim();
  const matches = [];
  let exhausted = false;
  let resume = "";
  for (let batch = 0; batch < 8 && matches.length < pageSize; batch++) {
    let query = db.collection("platform_sales_reps")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(40);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) {
      exhausted = true;
      break;
    }
    let pageFull = false;
    for (const doc of snap.docs) {
      const row = doc.data() || {};
      if (!policy.matchesSalesRep(row, {status: status, needle: needle})) {
        cursor = doc.id;
        continue;
      }
      if (matches.length >= pageSize) {
        pageFull = true;
        break;
      }
      const own = String(row.platformUid || "") === String(user.uid);
      matches.push(presentRep(doc, manage || own));
      cursor = doc.id;
      resume = doc.id;
    }
    if (pageFull) break;
    if (snap.size < 40) {
      exhausted = true;
      break;
    }
    cursor = snap.docs[snap.docs.length - 1].id;
    resume = cursor;
  }
  return {
    reps: matches,
    nextCursor: exhausted ? "" : resume,
  };
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc 文件
 * @return {Object}
 */
function presentRep(doc, revealPrivate) {
  const data = doc.data() || {};
  const named = policy.repDisplayName(data);
  const platformUid = String(data.platformUid || "").trim();
  const row = {
    repId: doc.id,
    displayName: named.displayName,
    nameMissing: named.nameMissing,
    platformUid: revealPrivate ? platformUid : "",
    bindingStatus: platformUid ? "bound" : "pending",
    enabled: data.enabled !== false,
    phone: revealPrivate ? (data.phone || "") : "",
    email: revealPrivate ? (data.email || "") : "",
    note: revealPrivate ? (data.note || "") : "",
    recentEvents: revealPrivate && Array.isArray(data.recentEvents) ?
      data.recentEvents.slice(0, 8) : [],
  };
  return row;
}

const SALES_IDENTITY_PERMISSIONS = [
  "view_own_sales",
  "view_own_activation_codes",
  "issue_own_activation_codes",
  "view_own_commission",
  "view_sales",
  "manage_sales",
  "manage_activation_codes",
  "transfer_shop_sales",
  "manage_subscription_finance",
];

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid 平台帳號
 * @return {Promise<Object>}
 */
async function findSalesRepForUid(db, uid) {
  const uidSnap = await db.collection("platform_sales_rep_uids").doc(uid).get();
  const indexedId = uidSnap.exists ? String(uidSnap.get("repId") || "") : "";
  const found = await db.collection("platform_sales_reps")
      .where("platformUid", "==", uid)
      .limit(2)
      .get();
  return {
    indexedId: indexedId,
    ids: found.docs.map((doc) => doc.id),
  };
}

/**
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function getSalesIdentity(user, data) {
  const uid = String((data || {}).uid || "").trim();
  if (!uid) {
    throw new HttpsError("invalid-argument", "缺少平台人員");
  }
  const own = uid === String(user.uid || "");
  const manage = hasPlatformAccess(user, SALES_MANAGE_PERMISSIONS);
  const viewList = hasPlatformAccess(user, ["view_sales"]);
  if (!manage && !viewList && !own) {
    throw new HttpsError("permission-denied", "沒有查看業務身分的權限");
  }
  const db = admin.firestore();
  try {
    const account = await db.collection("platform_users").doc(uid).get();
    const verifiedRoot = uid === ROOT_ADMIN_UID;
    const located = await findSalesRepForUid(db, uid);
    if (located.ids.length > 1 ||
        (located.indexedId && located.ids.length === 1 &&
          located.indexedId !== located.ids[0])) {
      return {
        exists: true,
        conflict: true,
        accountExists: account.exists,
        missingPlatformUser: !account.exists,
        verifiedRoot: verifiedRoot,
        role: account.exists ? (account.get("role") || "") :
          (verifiedRoot ? "super_admin" : ""),
        roleUnchanged: true,
      };
    }
    const repId = located.ids[0] || located.indexedId || "";
    const rep = repId ?
      await db.collection("platform_sales_reps").doc(repId).get() : null;
    const role = account.exists ?
      String(account.get("role") || "") :
      (verifiedRoot ? "super_admin" : "");
    const permissions = account.exists && Array.isArray(account.get("permissions")) ?
      account.get("permissions") : [];
    const salesPermissions = role === "super_admin" ?
      SALES_IDENTITY_PERMISSIONS.slice() :
      SALES_IDENTITY_PERMISSIONS.filter((key) => permissions.indexOf(key) >= 0);
    const base = {
      accountExists: account.exists,
      missingPlatformUser: !account.exists,
      verifiedRoot: verifiedRoot,
      role: role,
      roleUnchanged: true,
      inheritedFromRole: role === "super_admin",
      salesPermissions: manage || own ? salesPermissions : [],
      accountEnabled: verifiedRoot ||
        (account.exists && account.get("enabled") !== false),
    };
    if (!rep || !rep.exists) {
      return Object.assign({exists: false, conflict: false}, base);
    }
    const presented = presentRep(rep, manage || own);
    return Object.assign(presented, base, {
      exists: true,
      conflict: false,
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("failed-precondition", "無法讀取業務資料，請稍後再試");
  }
}

/**
 * 開啟或停用既有平台帳號的業務身分。不改角色、不刪歷史、不歸屬店家。
 * @param {Object} user 平台使用者
 * @param {Object} data 輸入
 * @return {Promise<Object>}
 */
async function setSalesIdentity(user, data) {
  assertPermission(user, SALES_MANAGE_PERMISSIONS);
  const request = data || {};
  const uid = String(request.uid || request.platformUid || "").trim();
  if (!uid) {
    throw new HttpsError("invalid-argument", "缺少平台人員");
  }
  const enabling = request.enabled === true;
  const db = admin.firestore();
  const located = await findSalesRepForUid(db, uid);
  if (located.ids.length > 1 ||
      (located.indexedId && located.ids.length === 1 &&
        located.indexedId !== located.ids[0])) {
    throw new HttpsError(
        "failed-precondition",
        "這個帳號的業務資料不一致，沒有自動合併或刪除",
    );
  }
  const accountRef = db.collection("platform_users").doc(uid);
  const uidRef = db.collection("platform_sales_rep_uids").doc(uid);
  const preferredId = located.ids[0] || located.indexedId || "";
  const verifiedRoot = uid === ROOT_ADMIN_UID;
  let authName = "";
  let authEmail = "";
  if (verifiedRoot) {
    try {
      const authUser = await admin.auth().getUser(uid);
      authName = String(authUser.displayName || "").trim().slice(0, 40);
      authEmail = String(authUser.email || "").trim().slice(0, 80);
    } catch (error) {
      authName = "";
      authEmail = "";
    }
  }
  try {
    return await db.runTransaction(async (tx) => {
      const account = await tx.get(accountRef);
      const uidSnap = await tx.get(uidRef);
      const indexedId = uidSnap.exists ? String(uidSnap.get("repId") || "") : "";
      if (preferredId && indexedId && preferredId !== indexedId) {
        throw new Error("這個帳號的業務資料不一致，沒有自動合併或刪除");
      }
      const repId = preferredId || indexedId;
      const repRef = repId ?
        db.collection("platform_sales_reps").doc(repId) :
        null;
      const repSnap = repRef ? await tx.get(repRef) : null;
      const role = account.exists ?
        String(account.get("role") || "") :
        (verifiedRoot ? "super_admin" : "");
      const rootWithoutProfile = verifiedRoot && !account.exists;
      const profileName = account.exists ?
        String(
            account.get("name") ||
            account.get("displayName") ||
            authName ||
            account.get("email") ||
            "",
        ).trim() :
        authName;
      const profileEmail = account.exists ?
        String(account.get("email") || authEmail || "").trim() :
        authEmail;
      const profilePhone = account.exists ?
        String(account.get("phone") || "").trim() :
        "";
      const plan = policy.planSalesIdentity({
        enabled: enabling,
        accountExists: account.exists,
        accountEnabled: account.exists && account.get("enabled") !== false,
        verifiedRoot: rootWithoutProfile,
        role: role,
        repExists: Boolean(repSnap && repSnap.exists),
        uidTakenByOther: false,
      });
      if (!plan.ok) throw new Error(plan.error);
      if (plan.action === "noop") {
        return {
          changed: false,
          exists: false,
          role: role,
          roleUnchanged: true,
        };
      }
      const now = new Date().toISOString();
      if (plan.action === "create") {
        const target = repRef || db.collection("platform_sales_reps").doc();
        const accountName = profileName.slice(0, 40);
        tx.set(target, {
          displayName: accountName,
          platformUid: uid,
          email: profileEmail.slice(0, 80),
          phone: profilePhone.slice(0, 40),
          enabled: true,
          bindingStatus: "bound",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdByUid: user.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          recentEvents: [{
            action: "assign",
            platformUid: uid,
            actorUid: user.uid,
            at: now,
          }],
        });
        tx.set(uidRef, {
          repId: target.id,
          boundBy: user.uid,
          boundAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
          changed: true,
          exists: true,
          repId: target.id,
          enabled: true,
          role: role,
          roleUnchanged: true,
        };
      }
      const current = repSnap.data() || {};
      const already = (current.enabled !== false) === enabling &&
        String(current.platformUid || "") === uid;
      if (already) {
        return {
          changed: false,
          exists: true,
          repId: repRef.id,
          enabled: enabling,
          role: role,
          roleUnchanged: true,
        };
      }
      const named = policy.repDisplayName(current);
      const accountName = profileName;
      const events = Array.isArray(current.recentEvents) ?
        current.recentEvents.slice(0, 7) : [];
      events.unshift({
        action: enabling ? "enable" : "disable",
        platformUid: uid,
        actorUid: user.uid,
        at: now,
      });
      tx.set(repRef, {
        displayName: named.nameMissing ? accountName : named.displayName,
        platformUid: uid,
        bindingStatus: "bound",
        enabled: enabling,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        recentEvents: events,
      }, {merge: true});
      tx.set(uidRef, {
        repId: repRef.id,
        boundBy: user.uid,
        boundAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        changed: true,
        exists: true,
        repId: repRef.id,
        enabled: enabling,
        role: role,
        roleUnchanged: true,
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error && error.message ?
      error.message :
      "更新業務身分失敗";
    throw new HttpsError("failed-precondition", message);
  }
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
  const shopId = String(data.shopId || "").trim();
  const mode = String(data.mode || "");
  const repId = String(data.salesRepId || "");
  const reason = String(data.reason || "").trim();
  const handoff = policy.planSalesHandoff({
    mode: mode,
    reason: reason,
    canManageSales: hasPlatformAccess(user, SALES_MANAGE_PERMISSIONS),
    canTransfer: hasPlatformAccess(user, ["transfer_shop_sales"]),
  });
  if (!shopId || !handoff.ok) {
    throw new HttpsError(
        "failed-precondition",
        handoff.error || "歸屬調整不正確",
    );
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

/**
 * 只給指派業務用。不建立登入帳號，也不回傳權限內容。
 * @param {Object} user 平台使用者
 * @return {Promise<Object>}
 */
async function listAssignablePlatformMembers(user, data) {
  assertPermission(user, SALES_MANAGE_PERMISSIONS);
  const request = data || {};
  const needle = String(request.query || "").trim().toLowerCase().slice(0, 80);
  const pageSize = 20;
  const db = admin.firestore();
  let cursor = String(request.cursor || "").trim();
  const matches = [];
  const seen = new Set();
  let exhausted = false;
  for (let batch = 0; batch < 8 && matches.length < pageSize; batch++) {
    let query = db.collection("platform_users")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(40);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) {
      exhausted = true;
      break;
    }
    let pageFull = false;
    for (const doc of snap.docs) {
      const row = doc.data() || {};
      const name = String(row.name || "").toLowerCase();
      const email = String(row.email || "").toLowerCase();
      if (needle && name.indexOf(needle) < 0 && email.indexOf(needle) < 0) {
        cursor = doc.id;
        continue;
      }
      if (matches.length >= pageSize) {
        pageFull = true;
        break;
      }
      if (!seen.has(doc.id)) {
        seen.add(doc.id);
        const binding = await db.collection("platform_sales_rep_uids")
            .doc(doc.id)
            .get();
        matches.push({
          uid: doc.id,
          name: row.name || "",
          email: row.email || "",
          enabled: row.enabled !== false,
          role: row.role || "",
          boundRepId: binding.exists ? String(binding.get("repId") || "") : "",
        });
      }
      cursor = doc.id;
    }
    if (pageFull) break;
    if (snap.size < 40) {
      exhausted = true;
      break;
    }
    cursor = snap.docs[snap.docs.length - 1].id;
  }
  return {
    members: matches,
    nextCursor: exhausted ? "" : cursor,
  };
}

const PREVIEW_ATTEMPT_WINDOW_MS = 15 * 60 * 1000;
const PREVIEW_ATTEMPT_LIMIT = 5;
const previewAttemptBuckets = new Map();
const PREVIEW_CODE_STATUSES = {
  "激活碼已停用": "disabled",
  "此激活碼不能用來開店": "wrong_type",
  "激活碼已用完": "exhausted",
  "激活碼已超過使用期限": "expired",
};

/**
 * 只在目前這個 Function 執行個體計數。
 * 冷啟動與其他執行個體會各自重算，不能單獨防止分散猜碼。
 * @param {string} uid 已驗證的使用者
 * @param {number=} nowMs 測試可代入的時間
 * @return {{ok: boolean, retryAfterSeconds: number}}
 */
function consumeShopActivationPreviewAttempt(uid, nowMs) {
  const now = Number(nowMs) || Date.now();
  if (previewAttemptBuckets.size > 5000) {
    for (const [key, bucket] of previewAttemptBuckets) {
      if (now - bucket.start >= PREVIEW_ATTEMPT_WINDOW_MS) {
        previewAttemptBuckets.delete(key);
      }
    }
  }
  const current = previewAttemptBuckets.get(uid);
  if (!current || now - current.start >= PREVIEW_ATTEMPT_WINDOW_MS) {
    previewAttemptBuckets.set(uid, {start: now, count: 1});
    return {ok: true, retryAfterSeconds: 0};
  }
  if (current.count >= PREVIEW_ATTEMPT_LIMIT) {
    const remain = PREVIEW_ATTEMPT_WINDOW_MS - (now - current.start);
    return {
      ok: false,
      retryAfterSeconds: Math.max(1, Math.ceil(remain / 1000)),
    };
  }
  current.count += 1;
  return {ok: true, retryAfterSeconds: 0};
}

/**
 * @param {string} status 前端可判斷的狀態
 * @param {string} message 既有中文說明
 * @return {{ok: boolean, status: string, message: string}}
 */
function previewShopActivationFailure(status, message) {
  return {ok: false, status: status, message: message};
}

/**
 * 與創店交易相同的店主資格：鎖定已有店家，或 shop_members 為 owner。
 * @param {Object} db Firestore
 * @param {string} uid 已驗證的使用者
 * @return {Promise<boolean>}
 */
async function accountAlreadyHasShop(db, uid) {
  const lock = await db.collection("sales_owner_locks").doc(uid).get();
  if (lock.exists && lock.get("shopId")) return true;
  const owned = await db.collection("shop_members")
      .where("uid", "==", uid)
      .where("role", "==", "owner")
      .limit(1)
      .get();
  return !owned.empty;
}

/**
 * 只回傳創店交易會採用的已知模板。空值或未知值不補成貓咪住宿。
 * @param {Object} code 激活碼文件
 * @return {string}
 */
function publicActivationModule(code) {
  const moduleName = String((code || {}).module || "");
  return LOCKABLE.indexOf(moduleName) >= 0 ? moduleName : "";
}

/**
 * 創店前確認激活碼與帳號資格。只讀，不建立店家，也不消耗激活碼。
 * 通過此檢查不代表創店成功；createShopWithActivation 仍會再驗證一次。
 * @param {Object} request Callable request
 * @param {Object} data 只讀 activationCode
 * @param {Object=} db 測試可注入的 Firestore
 * @return {Promise<Object>}
 */
async function validateShopActivationCode(request, data, db) {
  if (!request || !request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const uid = String(request.auth.uid);
  const rawCode = String((data || {}).activationCode || "").trim();
  const normalized = policy.normalizeActivationCode(rawCode);
  const gate = consumeShopActivationPreviewAttempt(uid);
  if (!gate.ok) {
    throw new HttpsError("resource-exhausted", "嘗試次數過多，請稍後再試");
  }
  const database = db || admin.firestore();
  if (await accountAlreadyHasShop(database, uid)) {
    return previewShopActivationFailure(
        "already_has_shop",
        "這個帳號已經有店家",
    );
  }
  if (!normalized || normalized.length > 40) {
    return previewShopActivationFailure("invalid", "激活碼不正確");
  }
  const codeDoc = await findActivationCode(database, normalized, rawCode);
  if (!codeDoc) {
    return previewShopActivationFailure("not_found", "找不到此激活碼");
  }
  const code = codeDoc.data() || {};
  const today = policy.taipeiDateKey(new Date());
  const decision = policy.canUseActivationCode(code, today);
  if (!decision.ok) {
    const status = PREVIEW_CODE_STATUSES[decision.reason] || "unavailable";
    const message = PREVIEW_CODE_STATUSES[decision.reason] ?
      decision.reason : "激活碼目前無法使用";
    return previewShopActivationFailure(status, message);
  }
  const result = {
    ok: true,
    status: "ready",
    message: "激活碼可以用於開店",
  };
  const moduleName = publicActivationModule(code);
  if (moduleName) result.module = moduleName;
  return result;
}

module.exports = {
  FINANCE_PERMISSIONS,
  SALES_MANAGE_PERMISSIONS,
  assertPermission,
  createShopWithActivation,
  saveActivationCode,
  saveSalesRep,
  listSalesReps,
  listAssignablePlatformMembers,
  getSalesIdentity,
  setSalesIdentity,
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
  validateShopActivationCode,
  updateShopPlan,
  applyDueShopPlans,
};
