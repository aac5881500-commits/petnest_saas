// functions/store/sync_store_product_public_stock.js
// 🛒 庫存主檔異動後，同步商城商品公開庫存狀態（不含成本）。
// 同時對相關品項做 lazy expiration，避免進貨後仍被過期 reservation 鎖住。

const admin = require("firebase-admin");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {
  expireRelatedHeldReservations,
} = require("./store_inventory");

exports.syncStoreProductPublicStock = onDocumentWritten(
    {
      region: "asia-east1",
      document: "shops/{shopId}/inventory_items/{itemId}",
    },
    async (event) => {
      const shopId = String((event.params && event.params.shopId) || "").trim();
      const itemId = String((event.params && event.params.itemId) || "").trim();
      if (!shopId || !itemId) {
        return;
      }

      const after = event.data && event.data.after;
      if (!after || !after.exists) {
        return;
      }

      await admin.firestore().runTransaction(async (transaction) => {
        await expireRelatedHeldReservations(transaction, {
          shopId,
          itemIds: [itemId],
          userId: "system",
        });
      });
    },
);
