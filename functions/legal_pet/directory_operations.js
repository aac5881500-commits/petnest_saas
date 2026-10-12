// 檔案名稱：functions/legal_pet/directory_operations.js
// 功能說明：平台搜尋、篩選業者名單，並分開保存人工聯繫紀錄。

const admin = require("firebase-admin");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  text,
  taipeiDateKey,
  LOOKUP_KEY_VERSION,
  selectLicenseLookupWrites,
  planLookupBackfillResult,
} = require("./normalize");
const {canViewDirectory, hasPlatformAccess} = require("./access");
const {shopCommercialSummary} = require("../sales/commercial_ops");
const {loadPlatformUser} = require("./staff_access");
const {COUNTY_CODES} = require("./codes");
const {
  DIRECTORY_VERSION,
  DIRECTORY_API_VERSION,
  phoneDigits,
  planDirectorySearch,
  readDirectoryFilters,
  primaryConstraint,
  filterRequiresBackfill,
  matchesDirectoryFilters,
  presentSync,
  listOutcome,
  validityOf,
  districtsByCountyCode,
  resolveDistrict,
  buildBackfillPatch,
  directoryFieldsCurrent,
} = require("./directory_index");

const PAGE_SIZE = 30;
const BATCH_SIZE = 80;
const SCAN_LIMIT = 500;
const BACKFILL_BATCH = 80;
const CONTACT_STATUSES = [
  "not_contacted",
  "contacted",
  "follow_up",
  "no_interest",
];

/**
 * @param {Object} link 字號連結
 * @return {string}
 */
function linkStatus(link) {
  const data = link || {};
  if (text(data.certifiedShopId)) {
    return "certified";
  }
  const candidates = Array.isArray(data.candidateShopIds) ?
    data.candidateShopIds :
    [];
  if (candidates.length > 0) {
    return "candidate";
  }
  return "none";
}

/**
 * @param {Object} link 字號連結
 * @return {number}
 */
function candidateCountOf(link) {
  const data = link || {};
  return Array.isArray(data.candidateShopIds) ?
    data.candidateShopIds.filter(Boolean).length :
    0;
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function assertDirectoryUser(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入");
  }
  const user = await loadPlatformUser(admin.firestore(), request.auth.uid);
  if (!canViewDirectory(user)) {
    throw new HttpsError("permission-denied", "沒有查看業者資料庫的權限");
  }
  return user;
}

/**
 * @param {Error} error 查詢錯誤
 * @return {HttpsError}
 */
function readableQueryError(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  const message = error && error.message ? String(error.message) : "";
  console.error("legal pet directory query", message);
  if (message.indexOf("index") >= 0 ||
      message.indexOf("FAILED_PRECONDITION") >= 0) {
    return new HttpsError(
        "failed-precondition",
        "業者名單索引尚未就緒。請部署 Firestore 索引，等建立完成後再查",
    );
  }
  return new HttpsError("internal", "查詢業者名單失敗，請稍後重試");
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {Object|null} primary 主要條件
 * @return {FirebaseFirestore.Query}
 */
function baseQuery(db, primary) {
  let query = db.collection("legal_pet_businesses");
  if (primary && primary.op === "array-contains") {
    query = query.where(primary.field, "array-contains", primary.value);
  } else if (primary && primary.op === "eq") {
    query = query.where(primary.field, "==", primary.value);
  }
  return query.orderBy("govSort");
}

/**
 * @param {FirebaseFirestore.DocumentSnapshot} doc 政府文件
 * @param {boolean} directoryReady 是否已補齊
 * @param {string} today 台北今日
 * @return {Object}
 */
function listItem(doc, directoryReady, today) {
  const data = doc.data() || {};
  const place = resolveDistrict(data);
  const link = text(data.linkStatus);
  const contact = text(data.contactStatus);
  return {
    govId: doc.id,
    govSort: data.govSort || "",
    legalname: data.legalname || "",
    legaladdress: data.legaladdress || "",
    countyCode: data.countyCode || "",
    countyLabel: data.countyLabel || "待確認",
    districtLabel: place.districtLabel || "",
    districtPending: place.districtPending === true,
    validnum: data.validnum || "",
    validDate: data.validDate || "",
    busitemLabel: data.busitemLabel || "待確認",
    animalLabel: data.animalLabel || "待確認",
    stateLabel: data.stateLabel || "待確認",
    businessState: data.businessState || "unknown",
    validity: validityOf(data, today),
    linkStatus: link || (directoryReady ? "none" : "unknown"),
    candidateCount: Number(data.candidateCount) || 0,
    contactStatus: contact || (directoryReady ? "not_contacted" : "unknown"),
  };
}

/**
 * @param {Object} sync 同步顯示
 * @param {boolean} needsBackfill 是否需要補齊
 * @return {Object}
 */
function emptyPage(sync, needsBackfill) {
  return {
    directoryApiVersion: DIRECTORY_API_VERSION,
    items: [],
    nextCursor: "",
    hasMore: false,
    needsBackfill: needsBackfill,
    candidateReads: 0,
    outcome: listOutcome({
      needsBackfill: needsBackfill,
      phase: sync.phase,
      itemCount: 0,
      hasMore: false,
    }),
    sync: sync,
    counties: COUNTY_CODES,
    districts: districtsByCountyCode(),
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {Object} search 搜尋
 * @param {Object} filters 篩選
 * @param {string} startCursor 游標
 * @param {string} today 台北今日
 * @param {boolean} directoryReady 補齊完成
 * @return {Promise<Object>}
 */
async function collectPage(
    db,
    search,
    filters,
    startCursor,
    today,
    directoryReady,
) {
  const primary = primaryConstraint(search, filters, directoryReady);
  let query = baseQuery(db, primary);
  if (startCursor) {
    query = query.startAfter(startCursor);
  }
  const matched = [];
  let cursor = startCursor;
  let scanned = 0;
  let exhausted = false;
  while (matched.length < PAGE_SIZE && scanned < SCAN_LIMIT) {
    const snap = await query.limit(BATCH_SIZE).get();
    if (snap.empty) {
      exhausted = true;
      break;
    }
    let stop = false;
    snap.docs.forEach((doc) => {
      if (stop) {
        return;
      }
      scanned += 1;
      const data = doc.data() || {};
      cursor = data.govSort || doc.id;
      if (matchesDirectoryFilters(data, filters, search, today)) {
        matched.push(doc);
      }
      if (matched.length >= PAGE_SIZE || scanned >= SCAN_LIMIT) {
        stop = true;
      }
    });
    const last = snap.docs[snap.docs.length - 1];
    const lastSort = (last.data() || {}).govSort || last.id;
    if (matched.length >= PAGE_SIZE || scanned >= SCAN_LIMIT) {
      exhausted = cursor === lastSort && snap.size < BATCH_SIZE;
      break;
    }
    if (snap.size < BATCH_SIZE) {
      exhausted = true;
      break;
    }
    query = baseQuery(db, primary).startAfter(cursor);
  }
  const hasMore = !exhausted;
  return {
    items: matched.map((doc) => listItem(doc, directoryReady, today)),
    nextCursor: hasMore ? cursor : "",
    hasMore: hasMore,
    candidateReads: scanned,
  };
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function listLegalPetBusinesses(request) {
  await assertDirectoryUser(request);
  const data = request.data || {};
  const search = planDirectorySearch(data.query);
  if (search.error) {
    throw new HttpsError("invalid-argument", search.error);
  }
  const filters = readDirectoryFilters(data);
  const db = admin.firestore();
  const syncSnap = await db.collection("legal_pet_sync").doc("current").get();
  const sync = presentSync(syncSnap.data() || {}, Date.now());
  const needsBackfill = filterRequiresBackfill(
      search,
      filters,
      sync.directoryReady,
  );
  if (needsBackfill) {
    return emptyPage(sync, true);
  }
  try {
    const today = taipeiDateKey(new Date());
    const page = await collectPage(
        db,
        search,
        filters,
        text(data.cursor),
        today,
        sync.directoryReady,
    );
    return Object.assign(page, {
      directoryApiVersion: DIRECTORY_API_VERSION,
      candidateReads: page.candidateReads,
      needsBackfill: false,
      outcome: listOutcome({
        phase: sync.phase,
        itemCount: page.items.length,
        hasMore: page.hasMore,
      }),
      sync: sync,
      counties: COUNTY_CODES,
      districts: districtsByCountyCode(),
    });
  } catch (error) {
    throw readableQueryError(error);
  }
}

/**
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string[]} shopIds 店家
 * @param {string} certifiedId 已認證店
 * @return {Promise<Object[]>}
 */
async function activityForShops(db, shopIds, certifiedId) {
  const unique = [];
  shopIds.filter(Boolean).forEach((id) => {
    if (unique.indexOf(id) < 0 && unique.length < 20) {
      unique.push(id);
    }
  });
  if (unique.length === 0) {
    return [];
  }
  const shops = await db.getAll(...unique.map((id) => {
    return db.collection("shops").doc(id);
  }));
  const result = [];
  for (const shop of shops) {
    if (!shop.exists) {
      continue;
    }
    const data = shop.data() || {};
    let lastActiveAt = "";
    if (data.ownerUid) {
      const user = await db.collection("users").doc(data.ownerUid).get();
      const stamp = (user.data() || {}).lastActiveAt;
      if (stamp && stamp.toDate) {
        lastActiveAt = stamp.toDate().toISOString();
      }
    }
    result.push({
      shopId: shop.id,
      shopName: data.name || "",
      relation: shop.id === certifiedId ? "certified" : "candidate",
      isPublic: data.isPublic === true,
      licenseVerified: data.licenseVerified === true,
      createdAt: data.createdAt && data.createdAt.toDate ?
        data.createdAt.toDate().toISOString() :
        "",
      lastActiveAt: lastActiveAt,
      activitySource: "PetNest 店家與店主活動",
    });
  }
  return result;
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function getLegalPetBusiness(request) {
  const user = await assertDirectoryUser(request);
  const govId = text(request.data && request.data.govId);
  if (!govId) {
    throw new HttpsError("invalid-argument", "缺少政府資料 ID");
  }
  const db = admin.firestore();
  const doc = await db.collection("legal_pet_businesses").doc(govId).get();
  if (!doc.exists) {
    throw new HttpsError("not-found", "找不到這筆政府資料");
  }
  const data = doc.data() || {};
  const contactSnap = await db.collection("legal_pet_business_contacts")
      .doc(govId)
      .get();
  const license = text(data.normalizedLicense);
  const linkSnap = license ?
    await db.collection("legal_pet_license_links").doc(license).get() :
    null;
  const link = linkSnap && linkSnap.exists ? linkSnap.data() : {};
  const certifiedId = text(link.certifiedShopId);
  const shopIds = [];
  if (certifiedId) {
    shopIds.push(certifiedId);
  }
  (link.candidateShopIds || []).forEach((id) => {
    if (shopIds.indexOf(id) < 0) {
      shopIds.push(id);
    }
  });
  const place = resolveDistrict(data);
  const today = taipeiDateKey(new Date());
  const contactData = contactSnap.exists ? contactSnap.data() : {
    contactStatus: "not_contacted",
    source: "",
    phone: "",
    website: "",
    note: "",
    nextFollowUpDate: "",
    salesRepId: "",
  };
  const commercial = certifiedId ?
    await shopCommercialSummary(user, certifiedId) : null;
  const prospectRep = text(contactData.salesRepId);
  const originRep = commercial ? text(commercial.originSalesRepId) : "";
  const mismatch = prospectRep && originRep && prospectRep !== originRep;
  const attributionWarning = mismatch ?
    "潛客負責業務與店家開發業務不同，請平台確認，不會自動覆蓋。" : "";
  return {
    directoryApiVersion: DIRECTORY_API_VERSION,
    government: Object.assign({}, data, {
      districtLabel: place.districtLabel,
      districtKey: place.districtKey,
      districtPending: place.districtPending,
      validity: validityOf(data, today),
    }),
    contact: contactData,
    linkStatus: linkStatus(link),
    commercial: commercial,
    attributionWarning: attributionWarning,
    candidateCount: candidateCountOf(link),
    certifiedShopId: certifiedId,
    activities: await activityForShops(db, shopIds, certifiedId),
  };
}

/**
 * 綁定變更後，只更新這個字號對到的政府文件，不掃全部店家。
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} normalizedLicense 正規化字號
 * @return {Promise<void>}
 */
async function mirrorLicenseLink(db, normalizedLicense) {
  const license = text(normalizedLicense);
  if (!license) {
    return;
  }
  const linkSnap = await db.collection("legal_pet_license_links")
      .doc(license)
      .get();
  const link = linkSnap.exists ? linkSnap.data() : {};
  const snap = await db.collection("legal_pet_businesses")
      .where("normalizedLicense", "==", license)
      .limit(30)
      .get();
  if (snap.empty) {
    return;
  }
  const batch = db.batch();
  snap.docs.forEach((doc) => {
    batch.set(doc.ref, {
      linkStatus: linkStatus(link),
      candidateCount: candidateCountOf(link),
    }, {merge: true});
  });
  await batch.commit();
}

/**
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function updateLegalPetContact(request) {
  const user = await assertDirectoryUser(request);
  const data = request.data || {};
  const govId = text(data.govId);
  const status = text(data.contactStatus) || "not_contacted";
  if (!govId || CONTACT_STATUSES.indexOf(status) < 0) {
    throw new HttpsError("invalid-argument", "聯繫狀態不正確");
  }
  const follow = text(data.nextFollowUpDate);
  if (follow && !/^\d{4}-\d{2}-\d{2}$/.test(follow)) {
    throw new HttpsError("invalid-argument", "下次跟進請用 YYYY-MM-DD");
  }
  const db = admin.firestore();
  const government = db.collection("legal_pet_businesses").doc(govId);
  const governmentSnap = await government.get();
  if (!governmentSnap.exists) {
    throw new HttpsError("not-found", "找不到政府業者");
  }
  const digits = phoneDigits(data.phone);
  const contact = {
    govId: govId,
    contactStatus: status,
    phone: text(data.phone).slice(0, 40),
    website: text(data.website).slice(0, 300),
    note: text(data.note).slice(0, 2000),
    nextFollowUpDate: follow,
    source: "platform_staff",
    updatedBy: user.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const governmentPatch = {
    contactStatus: status,
    contactPhoneDigits: digits,
  };
  if (hasPlatformAccess(user, ["manage_sales"])) {
    const salesRepId = text(data.salesRepId);
    contact.salesRepId = salesRepId;
    governmentPatch.salesRepId = salesRepId;
  }
  const batch = db.batch();
  batch.set(
      db.collection("legal_pet_business_contacts").doc(govId),
      contact,
      {merge: true},
  );
  batch.set(government, governmentPatch, {merge: true});
  await batch.commit();
  return {ok: true, contactStatus: status, contactPhoneDigits: digits};
}

/**
 * 分批補上搜尋與分類欄位。不刪政府資料、不改店家、不覆蓋聯繫內容。
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function backfillLegalPetDirectory(request) {
  await assertDirectoryUser(request);
  const data = request.data || {};
  const db = admin.firestore();
  const today = taipeiDateKey(new Date());
  const force = data.force === true;
  const syncRef = db.collection("legal_pet_sync").doc("current");
  const syncSnap = await syncRef.get();
  const savedPass = text((syncSnap.data() || {}).directoryBackfillPassId);
  let passId = text(data.passId);
  const beginning = !text(data.cursor);
  if (beginning) {
    passId = String(Date.now());
    await syncRef.set({
      directoryBackfillPassId: passId,
      directoryBackfillTarget: DIRECTORY_VERSION,
    }, {merge: true});
  }
  const canFinish = beginning || (passId && passId === savedPass);
  const documentId = admin.firestore.FieldPath.documentId();
  let query = db.collection("legal_pet_businesses")
      .orderBy(documentId)
      .limit(BACKFILL_BATCH);
  if (text(data.cursor)) {
    query = query.startAfter(text(data.cursor));
  }
  const snap = await query.get();
  if (snap.empty) {
    if (canFinish) {
      await syncRef.set({
        directoryIndexVersion: DIRECTORY_VERSION,
        directoryBackfillCursor: "",
        directoryBackfillPassId: "",
      }, {merge: true});
    }
    return {
      directoryApiVersion: DIRECTORY_API_VERSION,
      updated: 0,
      skipped: 0,
      nextCursor: "",
      done: true,
      ready: canFinish,
      passId: passId,
    };
  }
  const ids = snap.docs.map((doc) => doc.id);
  const licenses = [];
  snap.docs.forEach((doc) => {
    const license = text((doc.data() || {}).normalizedLicense);
    if (license && licenses.indexOf(license) < 0) {
      licenses.push(license);
    }
  });
  const contacts = await db.getAll(...ids.map((id) => {
    return db.collection("legal_pet_business_contacts").doc(id);
  }));
  const contactById = {};
  contacts.forEach((item) => {
    contactById[item.id] = item.exists ? item.data() : null;
  });
  const linkById = {};
  if (licenses.length > 0) {
    const links = await db.getAll(...licenses.map((id) => {
      return db.collection("legal_pet_license_links").doc(id);
    }));
    links.forEach((item) => {
      linkById[item.id] = item.exists ? item.data() : {};
    });
  }
  const writer = db.bulkWriter();
  let updated = 0;
  let skipped = 0;
  snap.docs.forEach((doc) => {
    const row = doc.data() || {};
    const contact = contactById[doc.id];
    const license = text(row.normalizedLicense);
    const patch = buildBackfillPatch(
        row,
        contact,
        license &&
          Object.prototype.hasOwnProperty.call(linkById, license) ?
          linkById[license] :
          null,
        today,
    );
    if (directoryFieldsCurrent(row, patch) && !force) {
      skipped += 1;
      return;
    }
    writer.set(doc.ref, patch, {merge: true});
    updated += 1;
  });
  await writer.close();
  const last = snap.docs[snap.docs.length - 1].id;
  const done = snap.size < BACKFILL_BATCH;
  if (done && canFinish) {
    await syncRef.set({
      directoryIndexVersion: DIRECTORY_VERSION,
      directoryBackfillCursor: "",
      directoryBackfillPassId: "",
    }, {merge: true});
  } else if (!done) {
    await syncRef.set({
      directoryBackfillCursor: last,
      directoryBackfillPassId: passId,
    }, {merge: true});
  }
  return {
    directoryApiVersion: DIRECTORY_API_VERSION,
    updated: updated,
    skipped: skipped,
    nextCursor: done ? "" : last,
    done: done,
    ready: done && canFinish,
    passId: passId,
  };
}

/**
 * 分批補上字號查核鍵。不刪政府文件，不改聯繫、業務歸屬、認證或綁定。
 * 只有整批寫入成功才前進；全部成功才標查核欄位版本。
 * @param {Object} request Callable request
 * @return {Promise<Object>}
 */
async function backfillLicenseLookupKeys(request) {
  await assertDirectoryUser(request);
  const data = request.data || {};
  const db = admin.firestore();
  const syncRef = db.collection("legal_pet_sync").doc("current");
  const syncSnap = await syncRef.get();
  const savedPass = text((syncSnap.data() || {}).licenseLookupBackfillPassId);
  let passId = text(data.passId);
  const beginning = !text(data.cursor);
  if (beginning) {
    passId = String(Date.now());
    await syncRef.set({
      licenseLookupBackfillPassId: passId,
      licenseLookupBackfillTarget: LOOKUP_KEY_VERSION,
    }, {merge: true});
  }
  const canFinish = beginning || (passId && passId === savedPass);
  const documentId = admin.firestore.FieldPath.documentId();
  let query = db.collection("legal_pet_businesses")
      .orderBy(documentId)
      .limit(BACKFILL_BATCH);
  if (text(data.cursor)) {
    query = query.startAfter(text(data.cursor));
  }
  const snap = await query.get();
  if (snap.empty) {
    const finish = planLookupBackfillResult({
      writeFailed: false,
      done: true,
      canFinish: canFinish,
    });
    if (finish.markReady) {
      await syncRef.set({
        licenseLookupVersion: LOOKUP_KEY_VERSION,
        licenseLookupBackfillCursor: "",
        licenseLookupBackfillPassId: "",
      }, {merge: true});
    }
    return {
      updated: 0,
      skipped: 0,
      nextCursor: "",
      done: true,
      ready: finish.markReady,
      passId: passId,
      licenseLookupVersion: finish.markReady ? LOOKUP_KEY_VERSION : 0,
    };
  }
  const planned = selectLicenseLookupWrites(snap.docs.map((doc) => {
    return Object.assign({id: doc.id}, doc.data() || {});
  }));
  const byId = {};
  snap.docs.forEach((doc) => {
    byId[doc.id] = doc;
  });
  const writer = db.bulkWriter();
  let writeFailed = false;
  writer.onWriteError((error) => {
    writeFailed = true;
    console.error("license lookup backfill write", error);
    return false;
  });
  planned.updates.forEach((item) => {
    const doc = byId[item.id];
    if (!doc) {
      return;
    }
    writer.set(doc.ref, item.patch, {merge: true});
  });
  try {
    await writer.close();
  } catch (error) {
    writeFailed = true;
    console.error("license lookup backfill close", error);
  }
  const done = snap.size < BACKFILL_BATCH;
  const finish = planLookupBackfillResult({
    writeFailed: writeFailed,
    done: done,
    canFinish: canFinish,
  });
  if (finish.failed) {
    throw new HttpsError(
        "internal",
        "字號查核欄位寫入失敗，這一批沒有標成完成，請再執行一次",
    );
  }
  const last = snap.docs[snap.docs.length - 1].id;
  if (finish.markReady) {
    await syncRef.set({
      licenseLookupVersion: LOOKUP_KEY_VERSION,
      licenseLookupBackfillCursor: "",
      licenseLookupBackfillPassId: "",
    }, {merge: true});
  } else if (finish.saveCursor) {
    await syncRef.set({
      licenseLookupBackfillCursor: last,
      licenseLookupBackfillPassId: passId,
    }, {merge: true});
  }
  return {
    updated: planned.updates.length,
    skipped: planned.skipped,
    nextCursor: finish.markReady ? "" : last,
    done: done,
    ready: finish.markReady,
    passId: passId,
    licenseLookupVersion: finish.markReady ? LOOKUP_KEY_VERSION : 0,
  };
}

module.exports = {
  PAGE_SIZE,
  CONTACT_STATUSES,
  linkStatus,
  listLegalPetBusinesses,
  getLegalPetBusiness,
  updateLegalPetContact,
  backfillLegalPetDirectory,
  backfillLicenseLookupKeys,
  mirrorLicenseLink,
};
