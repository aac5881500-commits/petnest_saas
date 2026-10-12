// 檔案名稱：functions/legal_pet/shop_operations.js
// 功能說明：字號查核、首次地址、認證送件與平台審核交易。

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  text,
  normalizeLicense,
  lookupStatusFor,
  chooseGovernmentRecord,
  compareAddress,
  parseGovernmentAddress,
} = require("./normalize");
const {
  canReviewShopRequests,
} = require("./access");
const {
  buildInitialProfilePlan,
} = require("./profile_lock");
const {
  planCertificationSubmit,
  buildReviewPlan,
} = require("./review_policy");
const {loadPlatformUser, assertShopStaff} = require("./staff_access");
const {mirrorLicenseLink} = require("./directory_operations");

const LOOKUP_MESSAGES = {
  none: "政府名單目前沒有相符字號。這不是平台認證結果，新核發證照仍可送人工補審。",
  unavailable: "暫時無法查核政府資料，不代表字號無效。",
  stale: "政府資料同步已逾時，不能把這次結果當成查無資料。",
  multiple: "有多筆相符證照，請依地址確認，不能併成同一家。",
  expired: "找到相符資料，但許可有效日期已過。這不是平台認證。",
  matched: "以下是政府資料比對結果，不是平台已認證。",
  incomplete: "字號查核欄位尚未補齊，不能把這次結果當成政府查無資料。" +
    "請平台管理員在業者資料庫執行補齊字號查核。",
};

/**
 * @param {string} status 查核狀態
 * @param {string} reason 格式或補齊原因
 * @return {string}
 */
function lookupUserMessage(status, reason) {
  if (status === "invalid") {
    if (reason === "unrecognized_prefix" || reason === "breeding") {
      return "字號格式待確認。這不是一般特寵業字第，沒有比對政府名單，" +
        "也不能當成查無資料。";
    }
    return "請輸入完整英文字母、數字與尾碼，例如 W1070485 或 " +
      "V1140460-00。不完整或無法辨識的內容不會查核。";
  }
  return LOOKUP_MESSAGES[status] || LOOKUP_MESSAGES.unavailable;
}

/**
 * @param {Object} record 政府紀錄
 * @param {string} addressComparison 地址比對
 * @param {string} syncedAt 同步時間
 * @return {Object}
 */
function publicMatch(record, addressComparison, syncedAt) {
  return {
    govId: record.govId,
    legalname: record.legalname || "",
    legaladdress: record.legaladdress || "",
    validnum: record.validnum || "",
    validDate: record.validDate || "",
    validdateRaw: record.validdateRaw || "",
    busitem: record.busitem || "",
    busitemLabel: record.busitemLabel || "待確認",
    busitemConfirmed: record.busitemConfirmed === true,
    animaltype: record.animaltype || "",
    animalLabel: record.animalLabel || "待確認",
    animalConfirmed: record.animalConfirmed === true,
    stateFlag: record.stateFlag || "",
    stateLabel: record.stateLabel || "待確認",
    stateConfirmed: record.stateConfirmed === true,
    countyLabel: record.countyLabel || "待確認",
    countyConfirmed: record.countyConfirmed === true,
    licenseStatus: record.licenseStatus || "unknown",
    addressComparison: addressComparison,
    parsedAddress: parseGovernmentAddress(
        record.legaladdress,
        record.countyCode,
    ),
    syncedAt: syncedAt,
    resultLabel: "政府資料比對結果",
  };
}

/**
 * 只做 licenseLookupKey 完全相符。不掃描整份名單。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} key 查核鍵
 * @return {Promise<Object[]>}
 */
async function queryByLookupKey(db, key) {
  if (!key) {
    return [];
  }
  const snap = await db.collection("legal_pet_businesses")
      .where("licenseLookupKey", "==", key)
      .limit(10)
      .get();
  return snap.docs.map((doc) => {
    return doc.data();
  });
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function lookupLegalPetLicense(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const shopId = text(request.data && request.data.shopId);
  const license = text(request.data && request.data.licenseNumber);
  if (!shopId || !license) {
    throw new HttpsError("invalid-argument", "請提供店家與特寵字號");
  }
  const db = admin.firestore();
  const shopSnap = await assertShopStaff(db, request.auth.uid, shopId);
  const shop = shopSnap.data() || {};
  const syncSnap = await db.collection("legal_pet_sync").doc("current").get();
  const sync = syncSnap.data() || {};
  const nowMs = Date.now();
  const gate = lookupStatusFor({
    license: license,
    licenseLookupVersion: sync.licenseLookupVersion,
    sync: sync,
    matchCount: 0,
    nowMs: nowMs,
  });
  if (!gate.shouldQuery) {
    return {
      status: gate.status,
      message: lookupUserMessage(gate.status, gate.reason),
      syncedAt: sync.lastSuccessAt || "",
      matches: [],
    };
  }
  let matches = [];
  try {
    matches = await queryByLookupKey(db, gate.key);
  } catch (error) {
    console.error("lookup license", error);
    return {
      status: "unavailable",
      message: LOOKUP_MESSAGES.unavailable,
      syncedAt: sync.lastSuccessAt || "",
      matches: [],
    };
  }
  const status = lookupStatusFor({
    license: license,
    licenseLookupVersion: sync.licenseLookupVersion,
    sync: sync,
    matchCount: matches.length,
    licenseStatus: matches.length === 1 ? matches[0].licenseStatus : "",
    nowMs: nowMs,
  }).status;
  const place = {
    city: text(request.data.city) || text(shop.city),
    district: text(request.data.district) || text(shop.district),
    address: text(request.data.address) || text(shop.address),
  };
  return {
    status: status,
    message: LOOKUP_MESSAGES[status] || LOOKUP_MESSAGES.unavailable,
    syncedAt: sync.lastSuccessAt || "",
    matches: matches.map((record) => {
      const comparison = compareAddress(
          place,
          record.legaladdress,
          record.countyCode,
      ).result;
      return publicMatch(record, comparison, sync.lastSuccessAt || "");
    }),
  };
}

/**
 * @param {string} url 下載網址
 * @param {string} shopId 店家
 * @param {string} folder 資料夾
 * @return {boolean}
 */
function ownProof(url, shopId, folder) {
  const value = text(url);
  if (!value) {
    return false;
  }
  const plain = "shop_verify_requests/" + shopId + "/" + folder + "/";
  const encoded = "shop_verify_requests%2F" + shopId + "%2F" + folder + "%2F";
  return value.indexOf(plain) >= 0 || value.indexOf(encoded) >= 0;
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function saveShopInitialProfile(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const data = request.data || {};
  const shopId = text(data.shopId);
  if (!shopId) {
    throw new HttpsError("invalid-argument", "缺少店家");
  }
  const db = admin.firestore();
  const ref = db.collection("shops").doc(shopId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "找不到店家");
    }
    const memberRef = db.collection("shop_members")
        .doc(shopId + "_" + request.auth.uid);
    const member = await tx.get(memberRef);
    const shop = snap.data() || {};
    if (shop.ownerUid !== request.auth.uid && !member.exists) {
      throw new HttpsError("permission-denied", "沒有這間店的權限");
    }
    const planInput = {shop: shop};
    if (data.phone !== undefined && data.phone !== null) {
      planInput.phone = data.phone;
    }
    if (text(data.address)) {
      planInput.city = data.city;
      planInput.district = data.district;
      planInput.address = data.address;
    }
    const plan = buildInitialProfilePlan(planInput);
    if (plan.error) {
      throw new HttpsError("failed-precondition", plan.error);
    }
    if (Object.keys(plan.patch).length === 0) {
      return;
    }
    plan.patch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    tx.update(ref, plan.patch);
  });
  return {ok: true};
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function submitShopCertification(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const data = request.data || {};
  const shopId = text(data.shopId);
  const db = admin.firestore();
  const shopSnap = await assertShopStaff(db, request.auth.uid, shopId);
  const shop = shopSnap.data() || {};
  if (!ownProof(data.contactProofImageUrl, shopId, "identity") ||
      !ownProof(data.licenseImageUrl, shopId, "license") ||
      !ownProof(data.taxIdImageUrl, shopId, "tax_id")) {
    throw new HttpsError("invalid-argument", "請上傳這間店的證明照片");
  }
  const normalized = normalizeLicense(shop.licenseNumber);
  const syncSnap = await db.collection("legal_pet_sync").doc("current").get();
  const sync = syncSnap.data() || {};
  const nowMs = Date.now();
  const queryGate = lookupStatusFor({
    license: shop.licenseNumber,
    licenseLookupVersion: sync.licenseLookupVersion,
    sync: sync,
    matchCount: 0,
    nowMs: nowMs,
  });
  let records = [];
  let sourceFailed = false;
  if (queryGate.shouldQuery) {
    try {
      records = await queryByLookupKey(db, queryGate.key);
    } catch (error) {
      console.error("certification license recheck", error);
      sourceFailed = true;
    }
  }
  const checkResult = sourceFailed ? "unavailable" : lookupStatusFor({
    license: shop.licenseNumber,
    licenseLookupVersion: sync.licenseLookupVersion,
    sync: sync,
    sourceFailed: sourceFailed,
    matchCount: records.length,
    licenseStatus: records.length === 1 ? records[0].licenseStatus : "",
    nowMs: nowMs,
  }).status;
  const choice = chooseGovernmentRecord(records, data.governmentId);
  if (choice.error) {
    throw new HttpsError("invalid-argument", choice.error);
  }
  const chosen = choice.chosen;
  const addressComparison = sourceFailed || !chosen ?
    (checkResult === "none" ? "unavailable" : "manual") :
    compareAddress(shop, chosen.legaladdress, chosen.countyCode).result;
  const gate = planCertificationSubmit({
    checkResult: checkResult,
    addressComparison: addressComparison,
    addressDifferenceNote: data.addressDifferenceNote,
    addressProofImageUrl: data.addressProofImageUrl,
  });
  if (gate.error) {
    throw new HttpsError("failed-precondition", gate.error);
  }
  if (gate.addressComparison === "mismatch" &&
      !ownProof(data.addressProofImageUrl, shopId, "address")) {
    throw new HttpsError("failed-precondition", gate.error ||
      "地址明顯不同時，需上傳相關證明");
  }
  const linkSnap = normalized ?
    await db.collection("legal_pet_license_links").doc(normalized).get() :
    null;
  const link = linkSnap && linkSnap.exists ? linkSnap.data() : {};
  const requestRef = db.collection("shop_change_requests").doc();
  await db.runTransaction(async (tx) => {
    const pending = await tx.get(db.collection("shop_change_requests")
        .where("shopId", "==", shopId)
        .where("requestType", "==", "fullVerify")
        .where("status", "==", "pending")
        .limit(1));
    if (!pending.empty) {
      throw new HttpsError("already-exists", "此項目已有審核中的申請");
    }
    const freshShop = await tx.get(db.collection("shops").doc(shopId));
    const current = freshShop.data() || {};
    tx.set(requestRef, {
      shopId: shopId,
      shopName: text(current.name),
      requestType: "fullVerify",
      currentValue: "申請店家認證並公開於平台",
      newValue: "申請店家認證並公開於平台",
      contactName: text(data.contactName),
      contactPhone: text(data.contactPhone),
      contactTitle: text(data.contactTitle),
      contactProofImageUrl: text(data.contactProofImageUrl),
      licenseImageUrl: text(data.licenseImageUrl),
      taxIdImageUrl: text(data.taxIdImageUrl),
      addressProofImageUrl: text(data.addressProofImageUrl),
      reason: text(data.note),
      addressDifferenceNote: text(data.addressDifferenceNote),
      applicantUid: request.auth.uid,
      applicantEmail: text(request.auth.token && request.auth.token.email),
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      shopSnapshot: {
        licenseNumber: text(current.licenseNumber),
        taxId: text(current.taxId),
        name: text(current.name),
        city: text(current.city),
        district: text(current.district),
        address: text(current.address),
      },
      governmentId: chosen ? chosen.govId : "",
      governmentSnapshot: chosen ? publicMatch(
          chosen,
          addressComparison,
          sync.lastSuccessAt || "",
      ) : null,
      governmentSyncedAt: sync.lastSuccessAt || "",
      checkResult: gate.checkResult,
      addressComparison: gate.addressComparison,
      proposedAddress: text(data.proposedCity) ? {
        city: text(data.proposedCity),
        district: text(data.proposedDistrict),
        address: text(data.proposedAddress),
      } : null,
      licenseBindingShopId: text(link.certifiedShopId),
      clientCheckIgnored: true,
    });
  });
  return {ok: true, requestId: requestRef.id, checkResult: gate.checkResult};
}

/**
 * @param {FirebaseFirestore.Transaction} tx 交易
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} linkId 字號
 * @param {Object|null} patch 綁定更新
 * @param {string} shopId 店家
 */
function writeLink(tx, db, linkId, patch, shopId) {
  if (!linkId || !patch) {
    return;
  }
  const ref = db.collection("legal_pet_license_links").doc(linkId);
  const payload = {
    normalizedLicense: linkId,
    certifiedShopId: patch.certifiedShopId || "",
    transferredFromShopId: patch.transferredFromShopId || "",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (shopId) {
    payload.candidateShopIds = admin.firestore.FieldValue.arrayUnion(shopId);
  }
  tx.set(ref, payload, {merge: true});
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function reviewShopChangeRequest(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const user = await loadPlatformUser(admin.firestore(), request.auth.uid);
  if (!canReviewShopRequests(user)) {
    throw new HttpsError("permission-denied", "沒有審核店家申請的權限");
  }
  const data = request.data || {};
  const requestId = text(data.requestId);
  if (!requestId) {
    throw new HttpsError("invalid-argument", "缺少申請編號");
  }
  const db = admin.firestore();
  const licenses = await db.runTransaction(async (tx) => {
    const requestRef = db.collection("shop_change_requests").doc(requestId);
    const requestSnap = await tx.get(requestRef);
    if (!requestSnap.exists) {
      throw new HttpsError("not-found", "找不到申請");
    }
    const requestData = requestSnap.data() || {};
    const shopId = text(requestData.shopId);
    const shopRef = db.collection("shops").doc(shopId);
    const shopSnap = await tx.get(shopRef);
    if (!shopSnap.exists) {
      throw new HttpsError("not-found", "找不到店家");
    }
    const shop = Object.assign({shopId: shopId}, shopSnap.data() || {});
    const normalized = normalizeLicense(shop.licenseNumber);
    let link = {};
    let linkSnap = null;
    if (normalized) {
      linkSnap = await tx.get(
          db.collection("legal_pet_license_links").doc(normalized),
      );
      link = linkSnap.exists ? linkSnap.data() : {};
    }
    const plan = buildReviewPlan({
      action: data.action,
      request: requestData,
      shop: shop,
      shopId: shopId,
      link: link,
      actorUid: request.auth.uid,
      approveLicense: data.approveLicense === true,
      approveTaxId: data.approveTaxId === true,
      approvePublic: data.approvePublic === true,
      applyProposedAddress: data.applyProposedAddress === true,
      transferLicense: data.transferLicense === true,
      reviewNote: data.reviewNote,
    });
    if (plan.error) {
      throw new HttpsError("failed-precondition", plan.error);
    }
    const requestPatch = Object.assign({}, plan.requestPatch, {
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(requestRef, requestPatch);
    if (plan.shopPatch && Object.keys(plan.shopPatch).length > 0) {
      plan.shopPatch.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      if (plan.shopPatch.licenseVerified === true) {
        plan.shopPatch.licenseCertifiedAt =
          admin.firestore.FieldValue.serverTimestamp();
      }
      tx.update(shopRef, plan.shopPatch);
    }
    if (plan.previousShopId && plan.previousShopPatch) {
      tx.update(
          db.collection("shops").doc(plan.previousShopId),
          Object.assign({}, plan.previousShopPatch, {
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }),
      );
    }
    if (plan.clearLinkId) {
      tx.set(db.collection("legal_pet_license_links").doc(plan.clearLinkId), {
        certifiedShopId: "",
        clearedShopId: shopId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    writeLink(tx, db, plan.linkId, plan.linkPatch, shopId);
    const ids = [];
    if (normalized) {
      ids.push(normalized);
    }
    if (plan.clearLinkId && ids.indexOf(plan.clearLinkId) < 0) {
      ids.push(plan.clearLinkId);
    }
    if (plan.linkId && ids.indexOf(plan.linkId) < 0) {
      ids.push(plan.linkId);
    }
    return ids;
  });
  for (const license of licenses) {
    try {
      await mirrorLicenseLink(db, license);
    } catch (error) {
      console.error("mirror license link failed", error);
    }
  }
  return {ok: true};
}

module.exports = {
  LOOKUP_MESSAGES,
  publicMatch,
  lookupLegalPetLicense,
  saveShopInitialProfile,
  submitShopCertification,
  reviewShopChangeRequest,
};
