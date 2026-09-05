// 檔案名稱：functions/bookings/return_booking_inventory.js
// 功能說明：僅在 ba_{bookingId}_deduct / bs_{bookingId}_deduct 真實存在時返還。
// 🏨 取消住宿訂單時返還庫存
// 不依 booking snapshot 加庫存。同一 booking 返還幂等。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  bookingAddonDeductId,
  bookingAddonReturnId,
  bookingSupplyDeductId,
  bookingSupplyReturnId,
  prepareReturnFromDeduct,
  commitPreparedConsumption,
} = require("../inventory/inventory_consumption");

/**
 * @param {string} value
 * @return {string}
 */
function normalizeString(value) {
  return String(value || "").trim();
}

/**
 * @param {string} shopId
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function isShopMember(shopId, uid) {
  const snapshot = await admin.firestore()
      .collection("shop_members")
      .doc(`${shopId}_${uid}`)
      .get();
  return snapshot.exists;
}

exports.returnBookingInventory = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入會員帳號");
      }

      const requestData = request.data || {};
      const shopId = normalizeString(requestData.shopId);
      const bookingId = normalizeString(requestData.bookingId);
      const userId = request.auth.uid;

      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家 ID");
      }
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "缺少訂單 ID");
      }

      const firestore = admin.firestore();
      const bookingRef = firestore.collection("bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "找不到這筆訂單");
      }

      const booking = bookingSnap.data() || {};
      if (normalizeString(booking.shopId) !== shopId) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }

      const isOwner = normalizeString(booking.userId) === userId;
      const member = await isShopMember(shopId, userId);
      if (!isOwner && !member) {
        throw new HttpsError("permission-denied", "沒有權限操作此訂單");
      }

      if (normalizeString(booking.status) !== "cancelled" &&
          !booking.cancelledAt) {
        throw new HttpsError(
            "failed-precondition",
            "訂單尚未取消，無法返還庫存",
        );
      }

      try {
        await firestore.runTransaction(async (transaction) => {
          const addonPrepared = await prepareReturnFromDeduct(transaction, {
            shopId,
            deductId: bookingAddonDeductId(bookingId),
            returnId: bookingAddonReturnId(bookingId),
            sourceType: "return",
            sourceId: bookingId,
            movementType: "return",
            note: "取消預約返還加購庫存",
          });
          const supplyPrepared = await prepareReturnFromDeduct(transaction, {
            shopId,
            deductId: bookingSupplyDeductId(bookingId),
            returnId: bookingSupplyReturnId(bookingId),
            sourceType: "return",
            sourceId: bookingId,
            movementType: "return",
            note: "取消訂單返還住宿耗材",
          });
          commitPreparedConsumption(transaction, addonPrepared, userId);
          commitPreparedConsumption(transaction, supplyPrepared, userId);
        });
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        const message = error && error.message ?
          String(error.message) :
          "返還庫存失敗，請稍後再試";
        throw new HttpsError("internal", message);
      }

      return {ok: true};
    },
);
