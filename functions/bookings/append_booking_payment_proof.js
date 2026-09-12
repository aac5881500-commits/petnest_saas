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

const PURPOSES = ["deposit", "balance", "top_up"];

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
      const purpose = normalizeString(data.purpose) || "deposit";
      const last5 = normalizeString(data.last5);
      const amount = toInt(data.amount, 0);
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單");
      }
      if (!imageUrl && !last5) {
        throw new HttpsError("invalid-argument", "缺少照片資料");
      }
      if (purpose && !PURPOSES.includes(purpose)) {
        throw new HttpsError("invalid-argument", "付款類型不正確");
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
        const proofs = Array.isArray(booking.paymentProofs) ?
          booking.paymentProofs.slice() : [];
        if (proofs.length > 0) {
          const last = {...(proofs[proofs.length - 1] || {})};
          last.last5 = last5;
          proofs[proofs.length - 1] = last;
        }
        const meta = {paymentProofs: proofs, updatedAt: now};
        if (purpose === "deposit") {
          meta.transferLast5 = last5;
          meta.depositStatus = "pending_review";
          meta.depositSubmittedAt = now;
        } else {
          meta.settlementTopUpTransferLast5 = last5;
          meta.settlementTopUpStatus = "pending_review";
          meta.settlementTopUpSubmittedAt = now;
        }
        await bookingRef.update(meta);
        return {ok: true, purpose, last5};
      }
      if (!imageUrl || !storagePath) {
        throw new HttpsError("invalid-argument", "缺少照片資料");
      }

      const proofId = normalizeString(data.proofId) ||
        `${purpose}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
      const submittedAt = admin.firestore.Timestamp.now();
      const record = {
        proofId,
        imageUrl,
        storagePath,
        purpose,
        amount,
        last5,
        submittedAt,
        submittedBy: uid,
      };
      const update = {
        paymentProofs: admin.firestore.FieldValue.arrayUnion(record),
        updatedAt: now,
      };
      if (purpose === "deposit") {
        update.transferImageUrl = imageUrl;
        update.transferImagePath = storagePath;
        if (last5) {
          update.transferLast5 = last5;
        }
      }
      if (purpose === "top_up" || purpose === "balance") {
        update.settlementTopUpTransferImageUrl = imageUrl;
        update.settlementTopUpTransferImagePath = storagePath;
        if (last5) {
          update.settlementTopUpTransferLast5 = last5;
        }
        update.settlementTopUpStatus = "pending_review";
        update.settlementTopUpSubmittedAt = now;
      }
      await bookingRef.update(update);
      return {ok: true, proofId, imageUrl, storagePath, purpose};
    },
);
