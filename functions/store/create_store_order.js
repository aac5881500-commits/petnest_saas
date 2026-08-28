// functions/store/create_store_order.js
// 🛒 建立商城訂單並保留庫存
// 功能：後端依商品現價計算金額，原子保留多品項庫存，不信任前端金額。

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

const {
  applyReservation,
  mergeInventoryLines,
} = require("./store_inventory");

const RESERVATION_MINUTES = 20;

/**
 * @param {string} value
 * @return {string}
 */
function normalizeString(value) {
  return String(value || "").trim();
}

/**
 * @param {Object} shopData
 * @return {string}
 */
function shopAddressOf(shopData) {
  return [
    shopData.city,
    shopData.district,
    shopData.address,
  ].map((value) => normalizeString(value)).filter(Boolean).join("");
}

exports.createStoreOrder = onCall(
    {region: "asia-east1"},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "請先登入會員。");
      }

      const requestData = request.data || {};
      const shopId = normalizeString(requestData.shopId);
      const fulfillmentType = normalizeString(requestData.fulfillmentType) ||
        "pickup";
      const userId = request.auth.uid;
      const requestedItems = Array.isArray(requestData.items) ?
        requestData.items :
        [];

      if (!shopId) {
        throw new HttpsError("invalid-argument", "缺少店家編號。");
      }

      if (fulfillmentType !== "pickup") {
        throw new HttpsError(
            "failed-precondition",
            "商城第一版僅支援店內自取。",
        );
      }

      if (requestedItems.length === 0) {
        throw new HttpsError("invalid-argument", "請選擇要購買的商品。");
      }

      const firestore = admin.firestore();
      const shopSnapshot = await firestore
          .collection("shops")
          .doc(shopId)
          .get();
      if (!shopSnapshot.exists) {
        throw new HttpsError("not-found", "找不到店家。");
      }

      const shopData = shopSnapshot.data() || {};
      const enabledModules = Array.isArray(shopData.enabledModules) ?
        shopData.enabledModules.map((item) => String(item)) :
        [];
      if (!enabledModules.includes("store")) {
        throw new HttpsError("failed-precondition", "此店家尚未開放賣場。");
      }

      const settingsSnapshot = await firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_settings")
          .doc("main")
          .get();
      const settings = settingsSnapshot.data() || {};
      if (settings.storefrontEnabled === false) {
        throw new HttpsError("failed-precondition", "賣場目前未開放下單。");
      }

      const userSnapshot = await firestore
          .collection("users")
          .doc(userId)
          .get();
      const profileSnapshot = await firestore
          .collection("user_profiles")
          .doc(userId)
          .get();
      const userData = userSnapshot.data() || {};
      const profileData = profileSnapshot.data() || {};
      const customerName = normalizeString(requestData.customerName) ||
        normalizeString(profileData.name) ||
        normalizeString(userData.displayName) ||
        "會員";
      const customerPhone = normalizeString(requestData.customerPhone) ||
        normalizeString(profileData.phone) ||
        "";

      const productSnaps = [];
      for (const raw of requestedItems) {
        const productId = normalizeString(raw.productId);
        const quantity = Number(raw.quantity);
        if (!productId || !Number.isInteger(quantity) || quantity <= 0) {
          throw new HttpsError("invalid-argument", "商品數量不正確。");
        }

        const productSnapshot = await firestore
            .collection("shops")
            .doc(shopId)
            .collection("store_products")
            .doc(productId)
            .get();
        if (!productSnapshot.exists) {
          throw new HttpsError("not-found", "找不到商品。");
        }
        productSnaps.push({
          productId,
          quantity,
          product: productSnapshot.data() || {},
        });
      }

      const orderItems = [];
      const reservationLines = [];
      let subtotal = 0;

      for (const entry of productSnaps) {
        const product = entry.product;
        if (product.enabled === false) {
          throw new HttpsError(
              "failed-precondition",
              `「${product.name || "商品"}」已停售`,
          );
        }

        const unitPrice = Number(product.price || 0);
        if (!Number.isInteger(unitPrice) || unitPrice < 0) {
          throw new HttpsError("failed-precondition", "商品價格不正確。");
        }

        const lineSubtotal = unitPrice * entry.quantity;
        subtotal += lineSubtotal;

        const useInventory = product.useInventory === true;
        const inventoryItemId = normalizeString(product.inventoryItemId);
        const inventoryQuantityPerSale = Number(
            product.inventoryQuantityPerSale || 1,
        );

        if (useInventory) {
          if (!inventoryItemId || inventoryQuantityPerSale <= 0) {
            throw new HttpsError(
                "failed-precondition",
                `「${product.name || "商品"}」庫存設定不完整`,
            );
          }
          reservationLines.push({
            inventoryItemId,
            quantity: inventoryQuantityPerSale * entry.quantity,
          });
        }

        orderItems.push({
          productId: entry.productId,
          productName: normalizeString(product.name),
          imageUrl: normalizeString(product.imageUrl),
          unitPrice,
          quantity: entry.quantity,
          subtotal: lineSubtotal,
          useInventory,
          inventoryItemId,
          inventoryItemName: normalizeString(product.inventoryItemNameSnapshot),
          inventoryUnit: normalizeString(product.inventoryUnitSnapshot),
          inventoryQuantityPerSale: useInventory ? inventoryQuantityPerSale : 0,
        });
      }

      mergeInventoryLines(reservationLines);

      const orderRef = firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_orders")
          .doc();
      const counterRef = firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_counters")
          .doc("orders");
      const expireAt = new Date(
          Date.now() + RESERVATION_MINUTES * 60 * 1000,
      );

      let result;
      try {
        result = await firestore.runTransaction(async (transaction) => {
          const counterSnapshot = await transaction.get(counterRef);
          const current = counterSnapshot.exists ?
            Number((counterSnapshot.data() || {}).current || 0) :
            0;
          const next = current + 1;
          const orderCode = `${shopId}-S${String(next).padStart(6, "0")}`;

          if (reservationLines.length > 0) {
            await applyReservation({
              transaction,
              shopId,
              orderId: orderRef.id,
              lines: reservationLines,
              expireAt,
              userId,
            });
          }

          transaction.set(counterRef, {
            current: next,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

          transaction.set(orderRef, {
            orderId: orderRef.id,
            orderCode,
            shopId,
            shopNameSnapshot: normalizeString(shopData.name),
            userId,
            items: orderItems,
            subtotal,
            shippingFee: 0,
            totalAmount: subtotal,
            fulfillmentType: "pickup",
            status: "pending_payment",
            paymentStatus: "unpaid",
            customerName,
            customerPhone,
            pickupNote: normalizeString(settings.pickupNote),
            shopAddressSnapshot: shopAddressOf(shopData),
            reservationExpireAt: admin.firestore.Timestamp.fromDate(expireAt),
            lastPaymentId: "",
            inventoryReturned: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          return {orderId: orderRef.id, orderCode};
        });
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        throw new HttpsError(
            "failed-precondition",
            error && error.message ? error.message : "無法建立商城訂單",
        );
      }

      return {
        orderId: result.orderId,
        orderCode: result.orderCode,
        shopId,
        totalAmount: subtotal,
        reservationExpireAt: expireAt.toISOString(),
      };
    },
);
