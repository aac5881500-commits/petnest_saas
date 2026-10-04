// 檔案名稱：functions/bookings/campaign_usage.js
// 功能說明：優惠 totalUsageLimit 的原子計數。客戶不能讀整店訂單。
// 一張有效訂單算一次。cancelled 與其他狀態不計，取消後歸還。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {
  getShopMember,
  isRootAdmin,
  normalizeString,
  toInt,
} = require("../daycare/daycare_utils");
const {isOrderWindowOpen} = require("../daycare/discount_campaign");

const COUNTING_STATUSES = new Set([
  "pending",
  "confirmed",
  "checked_in",
  "completed",
]);

const USAGE_FULL_MESSAGE = "此優惠活動已達使用上限";

/**
 * @param {string} status
 * @return {boolean}
 */
function countsCampaignUse(status) {
  return COUNTING_STATUSES.has(normalizeString(status));
}

/**
 * totalUsageLimit <= 0 或空值代表不限次數。
 * @param {*} limit
 * @return {boolean}
 */
function isUnlimitedLimit(limit) {
  return toInt(limit, 0) <= 0;
}

/**
 * @param {number} used
 * @param {*} limit
 * @return {boolean}
 */
function usageAvailable(used, limit) {
  if (isUnlimitedLimit(limit)) {
    return true;
  }
  return toInt(used, 0) < toInt(limit, 0);
}

/**
 * @param {Object|null} campaign
 * @param {string} shopId
 * @param {Date} now
 * @return {string|null}
 */
function campaignUseDenial(campaign, shopId, now) {
  if (!campaign) {
    return "找不到優惠活動";
  }
  const ownerShop = normalizeString(campaign.shopId);
  if (ownerShop && ownerShop !== shopId) {
    return "此優惠不屬於這間店";
  }
  if (campaign.enabled !== true) {
    return "優惠活動未啟用";
  }
  if (!isOrderWindowOpen(campaign, now || new Date())) {
    return "優惠活動已過期";
  }
  if (!usageAvailable(campaign.usedCount, campaign.totalUsageLimit)) {
    return USAGE_FULL_MESSAGE;
  }
  return null;
}

/**
 * 只輸出活動用量。不含訂單、會員、寵物或付款。
 * @param {Object} row
 * @return {Object}
 */
function toPublicUsage(row) {
  const usedCount = Math.max(0, toInt(row.usedCount, 0));
  const unlimited = isUnlimitedLimit(row.usageLimit);
  const usageLimit = unlimited ? null : toInt(row.usageLimit, 0);
  const available = unlimited || usedCount < usageLimit;
  return {
    campaignId: normalizeString(row.campaignId),
    usedCount,
    usageLimit,
    remaining: unlimited ? null : Math.max(0, usageLimit - usedCount),
    available,
  };
}

/**
 * @param {Array<Object>} bookings
 * @param {string} shopId
 * @param {string} campaignId
 * @param {string} exceptBookingId
 * @return {number}
 */
function countValidCampaignBookings(
    bookings,
    shopId,
    campaignId,
    exceptBookingId,
) {
  let used = 0;
  (Array.isArray(bookings) ? bookings : []).forEach((booking) => {
    const row = booking || {};
    const id = normalizeString(row.id || row.bookingId);
    if (exceptBookingId && id === exceptBookingId) {
      return;
    }
    const rowShop = normalizeString(row.shopId);
    if (rowShop && rowShop !== shopId) {
      return;
    }
    const rowCampaign = normalizeString(row.discountCampaignId);
    if (rowCampaign !== campaignId) {
      return;
    }
    if (!countsCampaignUse(row.status)) {
      return;
    }
    used += 1;
  });
  return used;
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} campaignId
 * @return {FirebaseFirestore.DocumentReference}
 */
function usageRef(firestore, shopId, campaignId) {
  return firestore.collection("shops").doc(shopId)
      .collection("campaign_usage").doc(campaignId);
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} campaignId
 * @param {string} bookingId
 * @return {FirebaseFirestore.DocumentReference}
 */
function reservationRef(firestore, shopId, campaignId, bookingId) {
  return usageRef(firestore, shopId, campaignId)
      .collection("reservations").doc(bookingId);
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} campaignId
 * @return {FirebaseFirestore.Query}
 */
function campaignBookingQuery(firestore, shopId, campaignId) {
  return firestore.collection("bookings")
      .where("shopId", "==", shopId)
      .where("discountCampaignId", "==", campaignId);
}

/**
 * 顯示用。counter 尚未初始化時，用既有有效訂單當起點，不把錯誤當成 0。
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} campaignId
 * @return {Promise<number>}
 */
async function readCampaignUsedCount(firestore, shopId, campaignId) {
  const counter = await usageRef(firestore, shopId, campaignId).get();
  if (counter.exists && counter.get("initialized") === true) {
    return Math.max(0, toInt(counter.get("usedCount"), 0));
  }
  const snap = await campaignBookingQuery(firestore, shopId, campaignId).get();
  return countValidCampaignBookings(
      snap.docs.map((doc) => ({id: doc.id, ...(doc.data() || {})})),
      shopId,
      campaignId,
      "",
  );
}

/**
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {Array<Object>} campaigns
 * @return {Promise<void>}
 */
async function attachTotalUsage(firestore, shopId, campaigns) {
  const list = Array.isArray(campaigns) ? campaigns : [];
  await Promise.all(list.map(async (campaign) => {
    const id = normalizeString(campaign && campaign.id);
    if (!id) {
      return;
    }
    campaign.usedCount = await readCampaignUsedCount(firestore, shopId, id);
  }));
}

/**
 * 與 booking 同一筆 transaction。已占用的重送不重複加一。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} input
 * @return {Promise<{usedCount: number, reused: boolean}>}
 */
async function readCampaignUsageReserve(transaction, firestore, input) {
  const shopId = normalizeString(input.shopId);
  const campaignId = normalizeString(input.campaignId);
  const bookingId = normalizeString(input.bookingId);
  const limit = toInt(input.limit, 0);
  const counterSnap = await transaction.get(
      usageRef(firestore, shopId, campaignId),
  );
  const reservedSnap = await transaction.get(
      reservationRef(firestore, shopId, campaignId, bookingId),
  );
  const reservedStatus = normalizeString(reservedSnap.get("status"));
  if (reservedSnap.exists && reservedStatus === "active") {
    return {
      ok: true,
      reused: true,
      shopId,
      campaignId,
      bookingId,
      limit,
      usedCount: Math.max(0, toInt(counterSnap.get("usedCount"), 0)),
    };
  }
  let used = 0;
  if (counterSnap.exists && counterSnap.get("initialized") === true) {
    used = Math.max(0, toInt(counterSnap.get("usedCount"), 0));
  } else {
    const existing = await transaction.get(
        campaignBookingQuery(firestore, shopId, campaignId),
    );
    used = countValidCampaignBookings(
        existing.docs.map((doc) => ({id: doc.id, ...(doc.data() || {})})),
        shopId,
        campaignId,
        bookingId,
    );
  }
  if (!usageAvailable(used, limit)) {
    throw new HttpsError("failed-precondition", USAGE_FULL_MESSAGE);
  }
  return {
    ok: true,
    reused: false,
    shopId,
    campaignId,
    bookingId,
    limit,
    usedCount: used + 1,
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} plan
 * @return {void}
 */
function commitCampaignUsageReserve(transaction, firestore, plan) {
  if (!plan || plan.reused) {
    return;
  }
  transaction.set(usageRef(firestore, plan.shopId, plan.campaignId), {
    shopId: plan.shopId,
    campaignId: plan.campaignId,
    usedCount: plan.usedCount,
    totalUsageLimit: isUnlimitedLimit(plan.limit) ? null : plan.limit,
    initialized: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  transaction.set(
      reservationRef(firestore, plan.shopId, plan.campaignId, plan.bookingId),
      {
        shopId: plan.shopId,
        campaignId: plan.campaignId,
        bookingId: plan.bookingId,
        status: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
  );
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} input
 * @return {Promise<{usedCount: number, reused: boolean}>}
 */
async function reserveCampaignUsage(transaction, firestore, input) {
  const plan = await readCampaignUsageReserve(transaction, firestore, input);
  commitCampaignUsageReserve(transaction, firestore, plan);
  return {usedCount: plan.usedCount, reused: plan.reused};
}

/**
 * 取消後歸還一次。重複取消不再減。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} input
 * @return {Promise<void>}
 */
async function releaseCampaignUsage(transaction, firestore, input) {
  const shopId = normalizeString(input.shopId);
  const campaignId = normalizeString(input.campaignId);
  const bookingId = normalizeString(input.bookingId);
  if (!shopId || !campaignId || !bookingId) {
    return;
  }
  const counterSnap = await transaction.get(
      usageRef(firestore, shopId, campaignId),
  );
  const reservedSnap = await transaction.get(
      reservationRef(firestore, shopId, campaignId, bookingId),
  );
  const reservedStatus = normalizeString(reservedSnap.get("status"));
  if (reservedSnap.exists && reservedStatus === "released") {
    return;
  }
  let used = 0;
  if (reservedSnap.exists && reservedStatus === "active") {
    used = Math.max(0, toInt(counterSnap.get("usedCount"), 0) - 1);
  } else if (counterSnap.exists && counterSnap.get("initialized") === true) {
    used = Math.max(0, toInt(counterSnap.get("usedCount"), 0) - 1);
  } else {
    const existing = await transaction.get(
        campaignBookingQuery(firestore, shopId, campaignId),
    );
    used = countValidCampaignBookings(
        existing.docs.map((doc) => ({id: doc.id, ...(doc.data() || {})})),
        shopId,
        campaignId,
        bookingId,
    );
  }
  transaction.set(usageRef(firestore, shopId, campaignId), {
    shopId,
    campaignId,
    usedCount: used,
    initialized: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  transaction.set(reservationRef(firestore, shopId, campaignId, bookingId), {
    shopId,
    campaignId,
    bookingId,
    status: "released",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * 狀態回到有效訂單時補回次數，讓計數跟正式規則一致。
 * 已寫入的狀態變更不在這裡拒絕，避免計數少算。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {Object} input
 * @return {Promise<void>}
 */
async function restoreCampaignUsage(transaction, firestore, input) {
  const shopId = normalizeString(input.shopId);
  const campaignId = normalizeString(input.campaignId);
  const bookingId = normalizeString(input.bookingId);
  const counterSnap = await transaction.get(
      usageRef(firestore, shopId, campaignId),
  );
  const reservedSnap = await transaction.get(
      reservationRef(firestore, shopId, campaignId, bookingId),
  );
  if (normalizeString(reservedSnap.get("status")) === "active") {
    return;
  }
  let used = 0;
  if (counterSnap.exists && counterSnap.get("initialized") === true) {
    used = Math.max(0, toInt(counterSnap.get("usedCount"), 0));
  } else {
    const existing = await transaction.get(
        campaignBookingQuery(firestore, shopId, campaignId),
    );
    used = countValidCampaignBookings(
        existing.docs.map((doc) => ({id: doc.id, ...(doc.data() || {})})),
        shopId,
        campaignId,
        bookingId,
    );
  }
  transaction.set(usageRef(firestore, shopId, campaignId), {
    shopId,
    campaignId,
    usedCount: used + 1,
    initialized: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  transaction.set(reservationRef(firestore, shopId, campaignId, bookingId), {
    shopId,
    campaignId,
    bookingId,
    status: "active",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * 交易內重讀活動文件。不相信客戶傳來的上限或金額。
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {FirebaseFirestore.Firestore} firestore
 * @param {string} shopId
 * @param {string} campaignId
 * @param {Date} now
 * @return {Promise<Object>}
 */
async function readCampaignForUse(
    transaction,
    firestore,
    shopId,
    campaignId,
    now,
) {
  const snap = await transaction.get(
      firestore.collection("shops").doc(shopId)
          .collection("discount_campaigns").doc(campaignId),
  );
  if (!snap.exists) {
    throw new HttpsError("failed-precondition", "找不到優惠活動");
  }
  const data = snap.data() || {};
  const ownerShop = normalizeString(data.shopId);
  if (ownerShop && ownerShop !== shopId) {
    throw new HttpsError("failed-precondition", "此優惠不屬於這間店");
  }
  if (data.enabled !== true) {
    throw new HttpsError("failed-precondition", "優惠活動未啟用");
  }
  const campaign = {
    id: snap.id,
    ...data,
    startAt: data.startAt && data.startAt.toDate ?
      data.startAt.toDate() : data.startAt,
    endAt: data.endAt && data.endAt.toDate ? data.endAt.toDate() : data.endAt,
  };
  const denial = campaignUseDenial(campaign, shopId, now || new Date());
  if (denial && denial !== USAGE_FULL_MESSAGE) {
    throw new HttpsError("failed-precondition", denial);
  }
  return campaign;
}

const getCampaignUsage = onCall(
    {region: "asia-east1"},
    async (request) => {
      const shopId = normalizeString((request.data || {}).shopId);
      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家");
      }
      const firestore = admin.firestore();
      let includeDisabled = false;
      const uid = request.auth && request.auth.uid;
      if (uid) {
        const member = await getShopMember(shopId, uid);
        includeDisabled = isRootAdmin(uid) || !!member;
        if (!includeDisabled) {
          const shop = await firestore.collection("shops").doc(shopId).get();
          includeDisabled = normalizeString((shop.data() || {}).ownerUid) ===
            uid;
        }
      }
      const snap = await firestore.collection("shops").doc(shopId)
          .collection("discount_campaigns").get();
      const campaigns = [];
      for (const doc of snap.docs) {
        const data = doc.data() || {};
        if (!includeDisabled && data.enabled !== true) {
          continue;
        }
        const usedCount = await readCampaignUsedCount(
            firestore, shopId, doc.id,
        );
        campaigns.push(toPublicUsage({
          campaignId: doc.id,
          usedCount,
          usageLimit: data.totalUsageLimit,
        }));
      }
      return {campaigns};
    },
);

const releaseCampaignUsageOnBooking = onDocumentUpdated(
    {
      document: "bookings/{bookingId}",
      region: "asia-east1",
    },
    async (event) => {
      const before = event.data.before.data() || {};
      const after = event.data.after.data() || {};
      const bookingId = event.params.bookingId;
      const beforeId = normalizeString(before.discountCampaignId);
      const afterId = normalizeString(after.discountCampaignId);
      const beforeCounts = countsCampaignUse(before.status);
      const afterCounts = countsCampaignUse(after.status);
      const same = beforeId === afterId && beforeCounts === afterCounts;
      if (same) {
        return;
      }
      const firestore = admin.firestore();
      await firestore.runTransaction(async (transaction) => {
        if (beforeId && beforeCounts &&
            (beforeId !== afterId || !afterCounts)) {
          await releaseCampaignUsage(transaction, firestore, {
            shopId: before.shopId,
            campaignId: beforeId,
            bookingId,
          });
        }
        if (afterId && afterCounts &&
            (afterId !== beforeId || !beforeCounts)) {
          await restoreCampaignUsage(transaction, firestore, {
            shopId: after.shopId,
            campaignId: afterId,
            bookingId,
          });
        }
      });
    },
);

module.exports = {
  COUNTING_STATUSES,
  USAGE_FULL_MESSAGE,
  countsCampaignUse,
  isUnlimitedLimit,
  usageAvailable,
  campaignUseDenial,
  toPublicUsage,
  countValidCampaignBookings,
  readCampaignUsedCount,
  attachTotalUsage,
  readCampaignUsageReserve,
  commitCampaignUsageReserve,
  reserveCampaignUsage,
  releaseCampaignUsage,
  restoreCampaignUsage,
  readCampaignForUse,
  getCampaignUsage,
  releaseCampaignUsageOnBooking,
};
