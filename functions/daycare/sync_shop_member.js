// 檔案名稱：functions/daycare/sync_shop_member.js
// 功能說明：安親訂單成立後，把會員與寵物快取同步到店家會員資料（不覆蓋店家維護欄位）

const {
  memberSearchFields,
} = require("../search/normalize_fields");

const SHOP_OWNED_FIELDS = [
  "tags",
  "blacklisted",
  "blacklistReason",
  "isBlocked",
  "staffNote",
  "memberLevel",
  "points",
  "adminNote",
  "adminNote1",
  "adminNote2",
  "vipNote",
];

/**
 * @param {*} value
 * @return {string}
 */
function asString(value) {
  if (value == null) {
    return "";
  }
  return String(value).trim();
}

/**
 * @param {*} raw
 * @return {string}
 */
function flattenAddress(raw) {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return [raw.city, raw.district, raw.detail]
        .map((item) => asString(item))
        .filter(Boolean)
        .join("");
  }
  return asString(raw);
}

/**
 * @param {*} raw
 * @return {Object}
 */
function asMap(raw) {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return {...raw};
  }
  return {};
}

/**
 * @param {Object} petData
 * @param {string} shopId
 * @param {Object|null} shopAnswers
 * @return {Object}
 */
function memberPetPayload(petData, shopId, shopAnswers) {
  const payload = {...asMap(petData)};
  delete payload.customFormAnswersByShop;
  payload.petId = asString(payload.petId) || asString(petData && petData.petId);
  if (shopAnswers && Object.keys(shopAnswers).length > 0) {
    const answersShopId = asString(shopAnswers.shopId) || shopId;
    if (answersShopId === shopId) {
      payload.shopFormAnswers = {
        shopId: answersShopId,
        formId: shopAnswers.formId || "",
        formType: shopAnswers.formType || "",
        formVersion: shopAnswers.formVersion || 0,
        formTitle: shopAnswers.formTitle || "",
        submittedAt: shopAnswers.submittedAt || null,
        answers: Array.isArray(shopAnswers.answers) ?
          shopAnswers.answers : [],
      };
    }
  }
  return payload;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} userId
 * @return {Promise<number>}
 */
async function countShopMemberBookings(firestore, shopId, userId) {
  const snap = await firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("userId", "==", userId)
      .get();
  return snap.size || (snap.docs ? snap.docs.length : 0);
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} userId
 * @param {string} petId
 * @param {string} shopId
 * @return {Promise<Object|null>}
 */
async function loadShopFormAnswers(firestore, userId, petId, shopId) {
  const snap = await firestore.collection("user_profiles").doc(userId)
      .collection("pets").doc(petId)
      .collection("shop_form_answers").doc(shopId)
      .get();
  if (!snap.exists) {
    return null;
  }
  const data = snap.data() || {};
  if (asString(data.shopId) && asString(data.shopId) !== shopId) {
    return null;
  }
  return data;
}

/**
 * 已存在會員使用 merge；不寫入店家維護欄位。
 * 建立訂單成功後再呼叫；失敗時由呼叫端記錄 log，不可刪單。
 *
 * @param {Object} params
 * @param {FirebaseFirestore.Firestore} params.firestore
 * @param {*} params.FieldValue
 * @param {string} params.shopId
 * @param {string} params.userId
 * @param {Object} params.customer
 * @param {Object} params.policy
 * @param {string[]} [params.selectedPetIds]
 * @return {Promise<{bookingCount: number, petCount: number}>}
 */
async function syncShopMemberCache(params) {
  const firestore = params.firestore;
  const FieldValue = params.FieldValue;
  const shopId = asString(params.shopId);
  const userId = asString(params.userId);
  const customer = params.customer || {};
  const policy = params.policy || {};
  if (!shopId || !userId) {
    throw new Error("缺少店家或會員編號");
  }

  const memberRef = firestore.collection("shops").doc(shopId)
      .collection("members").doc(userId);
  const profileSnap = await firestore.collection("user_profiles")
      .doc(userId).get();
  const profile = profileSnap.exists ? (profileSnap.data() || {}) : {};
  const memberSnap = await memberRef.get();
  const existing = memberSnap.exists ? (memberSnap.data() || {}) : {};

  const petsSnap = await firestore.collection("user_profiles").doc(userId)
      .collection("pets").get();
  const petDocs = petsSnap.docs || [];

  const bookingCount = await countShopMemberBookings(
      firestore, shopId, userId,
  );

  const payload = {
    userId,
    name: asString(customer.name) || asString(profile.name) ||
      asString(existing.name),
    email: asString(customer.email) || asString(profile.email) ||
      asString(existing.email),
    phone: asString(customer.phone) || asString(profile.phone) ||
      asString(existing.phone),
    address: flattenAddress(customer.address) ||
      flattenAddress(profile.address) || flattenAddress(existing.address),
    avatarUrl: asString(profile.avatarUrl),
    avatarStoragePath: asString(profile.avatarStoragePath),
    emergencyContact: Object.keys(asMap(customer.emergencyContact)).length > 0 ?
      asMap(customer.emergencyContact) :
      (Object.keys(asMap(profile.emergencyContact)).length > 0 ?
        asMap(profile.emergencyContact) : asMap(existing.emergencyContact)),
    bookingCount,
    lastBookingAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    policyAccepted: policy.policyVersion > 0 ||
      policy.policyAccepted === true,
    policyVersion: policy.policyVersion || existing.policyVersion || 0,
    policyTitle: asString(policy.policyTitle) ||
      asString(existing.policyTitle),
    policyAcceptedAt: policy.policyAcceptedAt ||
      existing.policyAcceptedAt || null,
    termsType: asString(policy.termsType) || asString(existing.termsType),
    termsVersion: policy.termsVersion || existing.termsVersion || 0,
    termsTitle: asString(policy.termsTitle) || asString(existing.termsTitle),
  };

  SHOP_OWNED_FIELDS.forEach((key) => {
    delete payload[key];
  });

  if (!memberSnap.exists) {
    payload.createdAt = FieldValue.serverTimestamp();
    payload.tags = [];
    payload.blacklisted = false;
    payload.blacklistReason = "";
    payload.isBlocked = false;
    payload.bookingCount = bookingCount;
  }

  const writes = [];
  for (const petDoc of petDocs) {
    const petId = petDoc.id;
    const petData = {...(petDoc.data() || {}), petId};
    const shopAnswers = await loadShopFormAnswers(
        firestore, userId, petId, shopId,
    );
    const petPayload = memberPetPayload(petData, shopId, shopAnswers);
    petPayload.updatedAt = FieldValue.serverTimestamp();
    writes.push(memberRef.collection("pets").doc(petId).set(
        petPayload, {merge: true},
    ));
  }

  payload.petCount = petDocs.length;
  Object.assign(payload, memberSearchFields({
    ...existing,
    ...payload,
    source: existing.source || existing.memberSource ||
      (payload.source || "app"),
  }));
  writes.push(memberRef.set(payload, {merge: true}));
  await Promise.all(writes);

  return {
    bookingCount,
    petCount: petDocs.length,
    preservedShopFields: SHOP_OWNED_FIELDS,
  };
}

module.exports = {
  SHOP_OWNED_FIELDS,
  memberPetPayload,
  countShopMemberBookings,
  loadShopFormAnswers,
  syncShopMemberCache,
};
