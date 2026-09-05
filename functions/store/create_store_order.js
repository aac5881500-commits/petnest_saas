// 檔案名稱：functions/store/create_store_order.js
// 功能說明：後端依商品原價 + 有效促銷重算金額，原子保留多品項庫存，不信任前端金額。
// 🛒 建立商城訂單並保留庫存

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

const {
  applyReservation,
  mergeInventoryLines,
} = require("./store_inventory");
const {quoteBundle, quoteCart} = require("./store_pricing");

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
      const bundleRequests = [];
      for (const raw of requestedItems) {
        const bundlePromotionId = normalizeString(raw.bundlePromotionId);
        const quantity = Number(raw.quantity);
        if (!Number.isInteger(quantity) || quantity <= 0) {
          throw new HttpsError("invalid-argument", "商品數量不正確。");
        }
        if (bundlePromotionId) {
          bundleRequests.push({bundlePromotionId, quantity});
          continue;
        }
        const productId = normalizeString(raw.productId);
        if (!productId) {
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

      const promoSnapshot = await firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_promotions")
          .where("enabled", "==", true)
          .get();
      const promotions = promoSnapshot.docs.map((doc) => {
        return {id: doc.id, ...doc.data()};
      });
      const promoById = {};
      promotions.forEach((promo) => {
        promoById[promo.id] = promo;
      });

      const bundleProductsById = {};
      const bundleQuotes = [];
      for (const request of bundleRequests) {
        const promo = promoById[request.bundlePromotionId];
        if (!promo || String(promo.type || "") !== "bundle") {
          throw new HttpsError("failed-precondition", "套裝優惠不存在或已結束。");
        }
        const items = Array.isArray(promo.bundleItems) ? promo.bundleItems : [];
        if (items.length === 0) {
          throw new HttpsError("failed-precondition", "套裝內容不完整。");
        }
        for (const line of items) {
          const productId = normalizeString(line.productId);
          if (!productId) {
            throw new HttpsError("failed-precondition", "套裝內容不完整。");
          }
          if (!bundleProductsById[productId]) {
            const snap = await firestore
                .collection("shops")
                .doc(shopId)
                .collection("store_products")
                .doc(productId)
                .get();
            if (!snap.exists) {
              throw new HttpsError("not-found", "套裝商品找不到。");
            }
            bundleProductsById[productId] = snap.data() || {};
          }
          const product = bundleProductsById[productId];
          if (product.enabled === false) {
            throw new HttpsError(
                "failed-precondition",
                `「${product.name || "商品"}」已停售，套裝無法購買`,
            );
          }
        }
        bundleQuotes.push(quoteBundle({
          promotion: promo,
          sets: request.quantity,
          productsById: bundleProductsById,
        }));
      }

      const bundleQuantities = {};
      bundleRequests.forEach((item) => {
        bundleQuantities[item.bundlePromotionId] = item.quantity;
      });
      const pricedCart = quoteCart({
        entries: productSnaps,
        promotions,
        now: new Date(),
        bundleQuantities,
        extraProductsById: bundleProductsById,
      });

      const orderItems = [];
      const reservationLines = [];
      const appliedPromotionIds = new Set();

      for (let index = 0; index < productSnaps.length; index += 1) {
        const entry = productSnaps[index];
        const product = entry.product;
        const priced = pricedCart.lines[index];
        if (product.enabled === false) {
          throw new HttpsError(
              "failed-precondition",
              `「${product.name || "商品"}」已停售`,
          );
        }

        const originalUnitPrice = Number(product.price || 0);
        if (!Number.isInteger(originalUnitPrice) || originalUnitPrice < 0) {
          throw new HttpsError("failed-precondition", "商品價格不正確。");
        }

        const finalUnitPrice = priced.finalUnitPrice;
        const purchaseQuantity = Number(
            priced.purchaseQuantity || entry.quantity,
        );
        const freeQuantity = Number(priced.freeQuantity || 0);
        const fulfillmentQuantity = Number(
            priced.fulfillmentQuantity || (purchaseQuantity + freeQuantity),
        );
        const linePromo = priced.promotion;
        if (linePromo && linePromo.id) {
          appliedPromotionIds.add(linePromo.id);
        }

        const inventoryItemId = normalizeString(product.inventoryItemId);
        const inventoryQuantityPerSale = Number(
            product.inventoryQuantityPerSale || 1,
        );
        if (!inventoryItemId || inventoryQuantityPerSale <= 0) {
          throw new HttpsError(
              "failed-precondition",
              `「${product.name || "商品"}」尚未連結中央庫存，無法下單`,
          );
        }
        const useInventory = true;
        const inventoryDeductedQuantity =
          inventoryQuantityPerSale * fulfillmentQuantity;
        const itemPromotionType = normalizeString(priced.itemPromotionType);
        const buyQuantity = itemPromotionType === "buy_x_get_y" ?
          Math.max(1, Number(product.itemPromotionBuyQuantity || 1)) :
          0;
        const freeQuantityPerGroup = itemPromotionType === "buy_x_get_y" ?
          Math.max(1, Number(product.itemPromotionFreeQuantity || 1)) :
          0;

        reservationLines.push({
          inventoryItemId,
          quantity: inventoryDeductedQuantity,
        });

        orderItems.push({
          productId: entry.productId,
          productName: normalizeString(product.name),
          imageUrl: normalizeString(product.imageUrl),
          unitPrice: finalUnitPrice,
          originalUnitPrice,
          discountUnitAmount: originalUnitPrice - finalUnitPrice,
          finalUnitPrice,
          quantity: purchaseQuantity,
          purchaseQuantity,
          freeQuantity,
          fulfillmentQuantity,
          totalFulfillmentQuantity: fulfillmentQuantity,
          originalSubtotal: originalUnitPrice * purchaseQuantity,
          discountAmount: priced.originalSubtotal - priced.finalSubtotal,
          itemPromotionDiscount: Number(priced.itemPromotionDiscount || 0),
          finalSubtotal: priced.finalSubtotal,
          subtotal: priced.finalSubtotal,
          promotionId: linePromo ? normalizeString(linePromo.id) : "",
          promotionName: linePromo ? normalizeString(linePromo.name) : "",
          promotionType: linePromo ? normalizeString(linePromo.type) : "",
          itemPromotionType,
          itemPromotionName: normalizeString(priced.itemPromotionName),
          buyQuantity,
          freeQuantityPerGroup,
          inventoryDeductedQuantity,
          useInventory,
          inventoryItemId,
          inventoryItemName: normalizeString(product.inventoryItemNameSnapshot),
          inventoryUnit: normalizeString(product.inventoryUnitSnapshot),
          inventoryQuantityPerSale: useInventory ? inventoryQuantityPerSale : 0,
        });
      }

      const bundleSnapshots = [];
      for (const request of bundleRequests) {
        const promo = promoById[request.bundlePromotionId];
        const quoted = bundleQuotes.find((item) => {
          return item.promotion.id === request.bundlePromotionId;
        });
        appliedPromotionIds.add(promo.id);
        bundleSnapshots.push({
          bundlePromotionId: promo.id,
          bundlePromotionName: normalizeString(promo.name),
          bundleQuantity: request.quantity,
          bundleOriginalPrice: quoted ? quoted.originalTotal : 0,
          bundleFinalPrice: quoted ? quoted.finalTotal : 0,
        });
        const bundleLines = Array.isArray(promo.bundleItems) ?
          promo.bundleItems :
          [];
        for (const line of bundleLines) {
          const productId = normalizeString(line.productId);
          const product = bundleProductsById[productId] || {};
          const unitQty = Math.max(1, Number(line.quantity || 1));
          const fulfillmentQuantity = unitQty * request.quantity;
          const inventoryQuantityPerSale = Math.max(
              1,
              Number(product.inventoryQuantityPerSale || 1),
          );
          const inventoryItemId = normalizeString(product.inventoryItemId);
          if (!inventoryItemId || inventoryQuantityPerSale <= 0) {
            throw new HttpsError(
                "failed-precondition",
                `套裝品項「${product.name || "商品"}」尚未連結中央庫存，無法下單`,
            );
          }
          const useInventory = true;
          reservationLines.push({
            inventoryItemId,
            quantity: fulfillmentQuantity * inventoryQuantityPerSale,
          });
          const originalUnit = Math.max(0, Number(product.price || 0));
          orderItems.push({
            productId,
            productName: normalizeString(product.name),
            imageUrl: normalizeString(product.imageUrl),
            unitPrice: originalUnit,
            originalUnitPrice: originalUnit,
            discountUnitAmount: 0,
            finalUnitPrice: originalUnit,
            quantity: fulfillmentQuantity,
            purchaseQuantity: fulfillmentQuantity,
            freeQuantity: 0,
            fulfillmentQuantity,
            totalFulfillmentQuantity: fulfillmentQuantity,
            originalSubtotal: originalUnit * fulfillmentQuantity,
            discountAmount: 0,
            itemPromotionDiscount: 0,
            finalSubtotal: originalUnit * fulfillmentQuantity,
            subtotal: originalUnit * fulfillmentQuantity,
            promotionId: promo.id,
            promotionName: normalizeString(promo.name),
            promotionType: "bundle",
            itemPromotionType: "",
            itemPromotionName: "",
            buyQuantity: 0,
            freeQuantityPerGroup: 0,
            inventoryDeductedQuantity: useInventory ?
              fulfillmentQuantity * inventoryQuantityPerSale :
              0,
            useInventory,
            inventoryItemId,
            inventoryItemName: normalizeString(
                product.inventoryItemNameSnapshot,
            ),
            inventoryUnit: normalizeString(product.inventoryUnitSnapshot),
            inventoryQuantityPerSale: useInventory ?
              inventoryQuantityPerSale :
              0,
            bundlePromotionId: promo.id,
            bundlePromotionName: normalizeString(promo.name),
            bundleQuantity: request.quantity,
            bundleOriginalPrice: quoted ? quoted.originalTotal : 0,
            bundleFinalPrice: quoted ? quoted.finalTotal : 0,
          });
        }
      }

      if (pricedCart.quantityPromotion && pricedCart.quantityPromotion.id) {
        appliedPromotionIds.add(pricedCart.quantityPromotion.id);
      }
      if (pricedCart.amountPromotion && pricedCart.amountPromotion.id) {
        appliedPromotionIds.add(pricedCart.amountPromotion.id);
      }

      const subtotal = pricedCart.finalSubtotal;

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

          for (const promotionId of appliedPromotionIds) {
            transaction.update(
                firestore
                    .collection("shops")
                    .doc(shopId)
                    .collection("store_promotions")
                    .doc(promotionId),
                {
                  usedOrderCount: admin.firestore.FieldValue.increment(1),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                },
            );
          }

          transaction.set(orderRef, {
            orderId: orderRef.id,
            orderCode,
            shopId,
            shopNameSnapshot: normalizeString(shopData.name),
            userId,
            items: orderItems,
            bundles: bundleSnapshots,
            bundleDiscount: pricedCart.bundleDiscount || 0,
            originalSubtotal: pricedCart.originalSubtotal,
            promotionDiscount: pricedCart.promotionDiscount,
            itemPromotionDiscount: pricedCart.itemPromotionDiscount,
            campaignDiscount: pricedCart.campaignDiscount,
            quantityDiscount: pricedCart.quantityDiscount,
            amountDiscount: pricedCart.amountDiscount,
            finalSubtotal: pricedCart.finalSubtotal,
            subtotal,
            shippingFee: 0,
            totalAmount: subtotal,
            quantityPromotionId: pricedCart.quantityPromotion ?
              normalizeString(pricedCart.quantityPromotion.id) : "",
            quantityPromotionName: pricedCart.quantityPromotion ?
              normalizeString(pricedCart.quantityPromotion.name) : "",
            amountPromotionId: pricedCart.amountPromotion ?
              normalizeString(pricedCart.amountPromotion.id) : "",
            amountPromotionName: pricedCart.amountPromotion ?
              normalizeString(pricedCart.amountPromotion.name) : "",
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
