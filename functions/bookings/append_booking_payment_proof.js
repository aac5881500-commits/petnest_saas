/* eslint-disable require-jsdoc */
// 檔案名稱：functions/bookings/append_booking_payment_proof.js
// 功能說明：客戶／店家追加付款回傳照片紀錄（不覆蓋既有單張欄位與舊檔）

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  hasShopPermission,
  isRootAdmin,
  normalizeString,
  toInt,
} = require("../daycare/daycare_utils");

function normalizeProofPurpose(value) {
  const raw = normalizeString(value) || "deposit";
  if (raw === "top_up" || raw === "additional") {
    return "balance";
  }
  if (raw === "deposit" || raw === "balance") {
    return raw;
  }
  throw new HttpsError("invalid-argument", "付款類型不正確");
}

const LEGACY_IMAGE_FIELDS = [
  "transferImageUrl",
  "transferImagePath",
  "settlementTopUpTransferImageUrl",
  "settlementTopUpTransferImagePath",
];

function buildPaymentProofRecord({
  proofId,
  imageUrl,
  storagePath,
  purpose,
  amount,
  last5,
  submittedBy,
  submittedAt,
}) {
  return {
    proofId,
    imageUrl,
    storagePath,
    purpose,
    amount,
    last5,
    submittedAt,
    submittedBy,
  };
}

function readProofPurpose(proof) {
  const data = proof && typeof proof === "object" ? proof : {};
  try {
    return normalizeProofPurpose(data.purpose);
  } catch (error) {
    return "deposit";
  }
}

function isUnconfirmedProof(proof) {
  const data = proof && typeof proof === "object" ? proof : {};
  return data.confirmedAt == null || data.confirmedAt === "";
}

/**
 * 只更新同 purpose、尚未確認的最新一筆 last5。
 * 沒有同用途照片時不改其他用途的 record。
 *
 * @param {Array} proofs
 * @param {string} purpose
 * @param {string} last5
 * @return {{proofs: Array, updated: boolean}}
 */
function applyLast5ToProofs(proofs, purpose, last5) {
  const list = Array.isArray(proofs) ? proofs.map((item) => {
    return item && typeof item === "object" ? {...item} : {};
  }) : [];
  let targetIndex = -1;
  for (let i = list.length - 1; i >= 0; i -= 1) {
    if (readProofPurpose(list[i]) !== purpose) {
      continue;
    }
    if (!isUnconfirmedProof(list[i])) {
      continue;
    }
    targetIndex = i;
    break;
  }
  if (targetIndex < 0) {
    return {proofs: Array.isArray(proofs) ? proofs : [], updated: false};
  }
  list[targetIndex] = {
    ...list[targetIndex],
    last5,
  };
  return {proofs: list, updated: true};
}

function last5LegacyMeta(purpose, last5, now) {
  if (purpose === "deposit") {
    return {
      transferLast5: last5,
      depositStatus: "pending_review",
      depositSubmittedAt: now,
    };
  }
  return {
    settlementTopUpTransferLast5: last5,
    settlementTopUpStatus: "pending_review",
    settlementTopUpSubmittedAt: now,
  };
}

function imageAppendBookingFields(purpose, hasLast5) {
  const keys = ["paymentProofs", "updatedAt"];
  if (purpose === "deposit") {
    keys.push("depositStatus", "depositSubmittedAt");
    if (hasLast5) {
      keys.push("transferLast5");
    }
  } else {
    keys.push("settlementTopUpStatus", "settlementTopUpSubmittedAt");
    if (hasLast5) {
      keys.push("settlementTopUpTransferLast5");
    }
  }
  return keys;
}

exports.normalizeProofPurpose = normalizeProofPurpose;
exports.buildPaymentProofRecord = buildPaymentProofRecord;
exports.applyLast5ToProofs = applyLast5ToProofs;
exports.LEGACY_IMAGE_FIELDS = LEGACY_IMAGE_FIELDS;
exports.last5LegacyMeta = last5LegacyMeta;
exports.imageAppendBookingFields = imageAppendBookingFields;

exports.appendBookingPaymentProof = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入");
      }
      const uid = request.auth.uid;
      const data = request.data || {};
      const bookingId = normalizeString(data.bookingId);
      const imageUrl = normalizeString(data.imageUrl);
      const storagePath = normalizeString(data.storagePath);
      let purpose;
      try {
        purpose = normalizeProofPurpose(data.purpose);
      } catch (error) {
        throw error;
      }
      const last5 = normalizeString(data.last5);
      const amount = toInt(data.amount, 0);
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單");
      }
      if (!imageUrl && !last5) {
        throw new HttpsError("invalid-argument", "缺少照片資料");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const snap = await bookingRef.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "找不到訂單");
      }
      const booking = snap.data() || {};
      const shopId = normalizeString(booking.shopId);
      const owner = normalizeString(booking.userId) === uid;
      const daycare = normalizeString(booking.bookingKind) === "daycare" ||
        normalizeString(booking.serviceType) === "daycare";
      const key = daycare ? "manage_daycare_bookings" : "manage_bookings";
      const staff = isRootAdmin(uid) ||
        await hasShopPermission(shopId, uid, key) ||
        await hasShopPermission(shopId, uid, "manage_bookings");
      if (!owner && !staff) {
        throw new HttpsError("permission-denied", "沒有上傳付款回傳照片的權限");
      }
      if (normalizeString(booking.status) === "cancelled") {
        throw new HttpsError("failed-precondition", "已取消的訂單無法上傳");
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      if (!imageUrl && last5) {
        const applied = applyLast5ToProofs(
            booking.paymentProofs,
            purpose,
            last5,
        );
        const meta = {
          updatedAt: now,
          ...last5LegacyMeta(purpose, last5, now),
        };
        if (applied.updated) {
          meta.paymentProofs = applied.proofs;
        }
        LEGACY_IMAGE_FIELDS.forEach((key) => {
          delete meta[key];
        });
        await bookingRef.update(meta);
        return {ok: true, purpose, last5, proofUpdated: applied.updated};
      }
      if (!imageUrl || !storagePath) {
        throw new HttpsError("invalid-argument", "缺少照片資料");
      }

      const proofId = normalizeString(data.proofId) ||
        `${purpose}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
      const submittedAt = admin.firestore.Timestamp.now();
      const record = buildPaymentProofRecord({
        proofId,
        imageUrl,
        storagePath,
        purpose,
        amount,
        last5,
        submittedAt,
        submittedBy: uid,
      });
      const update = {
        paymentProofs: admin.firestore.FieldValue.arrayUnion(record),
        updatedAt: now,
      };
      if (purpose === "deposit") {
        update.depositStatus = "pending_review";
        update.depositSubmittedAt = now;
        if (last5) {
          update.transferLast5 = last5;
        }
      }
      if (purpose === "balance") {
        update.settlementTopUpStatus = "pending_review";
        update.settlementTopUpSubmittedAt = now;
        if (last5) {
          update.settlementTopUpTransferLast5 = last5;
        }
      }
      LEGACY_IMAGE_FIELDS.forEach((key) => {
        delete update[key];
      });
      await bookingRef.update(update);
      return {ok: true, proofId, imageUrl, storagePath, purpose};
    },
);
