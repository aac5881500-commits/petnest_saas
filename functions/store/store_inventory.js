// 檔案名稱：functions/store/store_inventory.js
// 功能說明：使用 reservedQuantity 做有期限保留，不在未付款時永久扣除 currentStock。
// 🛒 商城庫存保留 / 轉正式扣除 / 釋放 / 返還
// 正式扣庫存與返還寫入既有 inventory_consumptions + movements。
// 成本算法共用 functions/inventory/inventory_cost.js
// （money 2 位、weighted average 8 位、quantity 4 位）。
// 過期 held reservation 以 Transaction 內 idempotent lazy cleanup 釋放，
// 不改 currentStock、不加 movement。

const admin = require("firebase-admin");
const {
  roundQuantity,
  costAfterStockChange,
} = require("../inventory/inventory_cost");

const EXPIRED_QUERY_LIMIT = 25;
const LOW_STOCK_SELLABLE_THRESHOLD = 3;

/**
 * @param {Array<*>} values
 * @return {Array<string>}
 */
function uniqueStrings(values) {
  const result = [];
  const seen = new Set();
  (values || []).forEach((value) => {
    const id = String(value || "").trim();
    if (!id || seen.has(id)) {
      return;
    }
    seen.add(id);
    result.push(id);
  });
  return result;
}

/**
 * @param {Array<Object>} lines
 * @return {Array<string>}
 */
function inventoryIdsFromLines(lines) {
  return uniqueStrings((lines || []).map((line) => line.inventoryItemId));
}

/**
 * @param {Object|null} order
 * @return {Array<string>}
 */
function inventoryIdsFromOrder(order) {
  const items = order && Array.isArray(order.items) ? order.items : [];
  return uniqueStrings(items.map((item) => item.inventoryItemId));
}

/**
 * @param {*} value
 * @param {number} nowMs
 * @return {boolean}
 */
function isTimestampExpired(value, nowMs) {
  if (!value) {
    return false;
  }
  let ms = 0;
  if (typeof value.toMillis === "function") {
    ms = value.toMillis();
  } else if (typeof value.toDate === "function") {
    ms = value.toDate().getTime();
  } else if (value instanceof Date) {
    ms = value.getTime();
  } else {
    return false;
  }
  return ms <= nowMs;
}

/**
 * @param {Object} reservation
 * @param {Object|null} order
 * @param {number} nowMs
 * @return {boolean}
 */
function shouldExpireHeldReservation(reservation, order, nowMs) {
  const status = String((reservation && reservation.status) || "");
  if (status !== "held") {
    return false;
  }
  if (status === "converted" || status === "released" || status === "expired") {
    return false;
  }
  if (!isTimestampExpired(reservation.expireAt, nowMs)) {
    return false;
  }
  if (order) {
    const orderStatus = String(order.status || "");
    const paymentStatus = String(order.paymentStatus || "");
    if (paymentStatus === "paid") {
      return false;
    }
    if (["paid", "preparing", "ready_for_pickup", "completed"]
        .indexOf(orderStatus) >= 0) {
      return false;
    }
  }
  return true;
}

/**
 * @param {Object} reservation
 * @param {Array<string>} wantedItems
 * @param {Array<string>} extraIds
 * @param {string} reservationId
 * @return {boolean}
 */
function reservationIsRelated(
    reservation,
    wantedItems,
    extraIds,
    reservationId,
) {
  if (extraIds.indexOf(reservationId) >= 0) {
    return true;
  }
  if (wantedItems.length === 0) {
    return false;
  }
  const lines = Array.isArray(reservation.lines) ? reservation.lines : [];
  const ids = uniqueStrings(
      inventoryIdsFromLines(lines).concat(reservation.inventoryItemIds || []),
  );
  return ids.some((id) => wantedItems.indexOf(id) >= 0);
}

/**
 * 讀取與目前品項相關、已過期且仍 held 的 reservation。
 * 必須在 Transaction 任何 write 之前呼叫。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Array<Object>>}
 */
async function collectExpiredHeldReservations(transaction, {
  shopId,
  itemIds,
  extraReservationIds,
  excludeReservationIds,
}) {
  const firestore = admin.firestore();
  const nowMs = Date.now();
  const nowTs = admin.firestore.Timestamp.fromMillis(nowMs);
  const wantedItems = uniqueStrings(itemIds);
  const extraIds = uniqueStrings(extraReservationIds);
  const excludeIds = uniqueStrings(excludeReservationIds);
  const collected = new Map();

  const querySnapshot = await transaction.get(
      firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_reservations")
          .where("status", "==", "held")
          .where("expireAt", "<=", nowTs)
          .orderBy("expireAt", "asc")
          .limit(EXPIRED_QUERY_LIMIT),
  );

  querySnapshot.docs.forEach((doc) => {
    collected.set(doc.id, {
      reservationRef: doc.ref,
      reservation: doc.data() || {},
    });
  });

  for (const reservationId of extraIds) {
    if (collected.has(reservationId)) {
      continue;
    }
    const reservationRef = firestore
        .collection("shops")
        .doc(shopId)
        .collection("store_reservations")
        .doc(reservationId);
    const snapshot = await transaction.get(reservationRef);
    if (snapshot.exists) {
      collected.set(reservationId, {
        reservationRef: snapshot.ref,
        reservation: snapshot.data() || {},
      });
    }
  }

  const relevant = [];
  collected.forEach((entry, reservationId) => {
    if (excludeIds.indexOf(reservationId) >= 0) {
      return;
    }
    const reservation = entry.reservation;
    if (!reservationIsRelated(
        reservation,
        wantedItems,
        extraIds,
        reservationId,
    )) {
      return;
    }
    const lines = Array.isArray(reservation.lines) ? reservation.lines : [];
    relevant.push({
      reservationId,
      reservationRef: entry.reservationRef,
      reservation,
      lines,
      itemIds: uniqueStrings(
          inventoryIdsFromLines(lines)
              .concat(reservation.inventoryItemIds || []),
      ),
      orderRef: firestore
          .collection("shops")
          .doc(shopId)
          .collection("store_orders")
          .doc(reservationId),
    });
  });

  for (const entry of relevant) {
    entry.orderSnapshot = await transaction.get(entry.orderRef);
    entry.order = entry.orderSnapshot.exists ?
      (entry.orderSnapshot.data() || {}) :
      null;
  }

  return relevant.filter((entry) => {
    return shouldExpireHeldReservation(
        entry.reservation,
        entry.order,
        nowMs,
    );
  });
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {string} shopId
 * @param {Array<string>} itemIds
 * @return {Promise<Map<string, Object>>}
 */
async function loadItemStates(transaction, shopId, itemIds) {
  const firestore = admin.firestore();
  const states = new Map();
  const ids = uniqueStrings(itemIds);

  for (const itemId of ids) {
    const itemRef = firestore
        .collection("shops")
        .doc(shopId)
        .collection("inventory_items")
        .doc(itemId);
    const itemSnapshot = await transaction.get(itemRef);
    const data = itemSnapshot.exists ? (itemSnapshot.data() || {}) : {};
    states.set(itemId, {
      itemId,
      itemRef,
      exists: itemSnapshot.exists,
      data,
      currentStock: roundQuantity(data.currentStock || 0),
      reservedQuantity: roundQuantity(data.reservedQuantity || 0),
      dirtyReserved: false,
    });
  }

  return states;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {string} shopId
 * @param {Array<string>} itemIds
 * @return {Promise<Array<Object>>}
 */
async function loadStoreProductsForItems(transaction, shopId, itemIds) {
  const firestore = admin.firestore();
  const ids = uniqueStrings(itemIds);
  const products = [];
  const seen = new Set();

  for (let index = 0; index < ids.length; index += 10) {
    const chunk = ids.slice(index, index + 10);
    if (chunk.length === 0) {
      continue;
    }
    const snapshot = await transaction.get(
        firestore
            .collection("shops")
            .doc(shopId)
            .collection("store_products")
            .where("inventoryItemId", "in", chunk),
    );
    snapshot.docs.forEach((doc) => {
      if (seen.has(doc.id)) {
        return;
      }
      seen.add(doc.id);
      products.push({
        ref: doc.ref,
        data: doc.data() || {},
      });
    });
  }

  return products;
}

/**
 * 前台公開庫存欄位。不含成本、供應商、安全庫存數字。
 *
 * @param {Object} params
 * @return {Object}
 */
function buildPublicStockFields({
  useInventory,
  item,
  inventoryQuantityPerSale,
}) {
  if (!useInventory) {
    return {
      publicStockStatus: "unlimited",
      publicSellableQuantity: 0,
    };
  }

  if (!item || item.enabled === false) {
    return {
      publicStockStatus: "out_of_stock",
      publicSellableQuantity: 0,
    };
  }

  const perSale = Number(inventoryQuantityPerSale);
  const safePerSale = Number.isFinite(perSale) && perSale > 0 ? perSale : 1;
  const currentStock = roundQuantity(item.currentStock || 0);
  const reservedQuantity = roundQuantity(item.reservedQuantity || 0);
  const available = roundQuantity(currentStock - reservedQuantity);
  const sellable = Math.floor(available / safePerSale);

  if (sellable <= 0) {
    return {
      publicStockStatus: "out_of_stock",
      publicSellableQuantity: 0,
    };
  }

  const safetyStock = Number(item.safetyStock || 0);
  const lowBySafety = safetyStock > 0 && available <= safetyStock;
  const lowByUnits = sellable <= LOW_STOCK_SELLABLE_THRESHOLD;

  return {
    publicStockStatus: (lowBySafety || lowByUnits) ?
      "low_stock" :
      "in_stock",
    publicSellableQuantity: sellable,
  };
}

/**
 * @param {Object|undefined} state
 * @return {Object|null}
 */
function itemViewFromState(state) {
  if (!state || !state.exists) {
    return null;
  }
  return {
    enabled: state.data.enabled,
    currentStock: state.currentStock,
    reservedQuantity: state.reservedQuantity,
    safetyStock: state.data.safetyStock,
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Array<Object>} products
 * @param {Map<string, Object>} itemStates
 */
function writePublicStockForProducts(transaction, products, itemStates) {
  (products || []).forEach((product) => {
    const data = product.data || {};
    const useInventory = data.useInventory === true;
    const itemId = String(data.inventoryItemId || "").trim();
    const fields = buildPublicStockFields({
      useInventory,
      item: useInventory ? itemViewFromState(itemStates.get(itemId)) : null,
      inventoryQuantityPerSale: data.inventoryQuantityPerSale,
    });

    if (String(data.publicStockStatus || "") === fields.publicStockStatus &&
      Number(data.publicSellableQuantity || 0) ===
        fields.publicSellableQuantity) {
      return;
    }

    transaction.update(product.ref, {
      publicStockStatus: fields.publicStockStatus,
      publicSellableQuantity: fields.publicSellableQuantity,
      publicStockUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * @param {Object} params
 * @return {Array<string>}
 */
function writeExpiredReservations({
  transaction,
  userId,
  expired,
  itemStates,
}) {
  const cancelledOrderIds = [];

  (expired || []).forEach((entry) => {
    const status = String(
        (entry.reservation && entry.reservation.status) || "",
    );
    if (status !== "held") {
      return;
    }

    (entry.lines || []).forEach((line) => {
      const itemId = String(line.inventoryItemId || "").trim();
      const state = itemStates.get(itemId);
      if (!state || !state.exists) {
        return;
      }
      const qty = roundQuantity(line.quantity || 0);
      state.reservedQuantity = roundQuantity(
          Math.max(state.reservedQuantity - qty, 0),
      );
      state.dirtyReserved = true;
    });

    transaction.set(entry.reservationRef, {
      status: "expired",
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      expireReason: "timeout",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: userId || "system",
    }, {merge: true});

    const orderStatus = entry.order ? String(entry.order.status || "") : "";
    if (entry.orderSnapshot &&
      entry.orderSnapshot.exists &&
      orderStatus === "pending_payment") {
      transaction.set(entry.orderRef, {
        status: "cancelled",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: "庫存保留已過期，請重新下單",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: userId || "system",
      }, {merge: true});
      cancelledOrderIds.push(entry.reservationId);
    }
  });

  return cancelledOrderIds;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {string} userId
 * @param {Map<string, Object>} itemStates
 */
function flushReservedOnly(transaction, userId, itemStates) {
  itemStates.forEach((state) => {
    if (!state.exists || !state.dirtyReserved) {
      return;
    }
    transaction.update(state.itemRef, {
      reservedQuantity: state.reservedQuantity,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: userId || "system",
    });
    state.dirtyReserved = false;
  });
}

/**
 * 釋放與目前品項相關的過期 reservation，並同步商品公開庫存。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function expireRelatedHeldReservations(transaction, {
  shopId,
  itemIds,
  extraReservationIds,
  excludeReservationIds,
  userId,
}) {
  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds,
    extraReservationIds,
    excludeReservationIds,
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings((itemIds || []).concat(expiredItemIds));
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );
  const cancelledOrderIds = writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });
  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);

  return {
    expiredReservationIds: expired.map((entry) => entry.reservationId),
    cancelledOrderIds,
    itemStates,
    products,
  };
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Array<Object>>}
 */
async function applyReservation({
  transaction,
  shopId,
  orderId,
  lines,
  expireAt,
  userId,
}) {
  const firestore = admin.firestore();
  const merged = mergeInventoryLines(lines);
  const neededIds = inventoryIdsFromLines(merged);
  const reservationRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("store_reservations")
      .doc(orderId);

  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds: neededIds,
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings(neededIds.concat(expiredItemIds));

  const reservationSnapshot = await transaction.get(reservationRef);
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );

  writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });

  let savedLines = [];

  if (reservationSnapshot.exists) {
    savedLines = reservationSnapshot.data().lines || [];
  } else {
    for (const line of merged) {
      const state = itemStates.get(line.inventoryItemId);
      if (!state || !state.exists) {
        throw new Error(`找不到庫存品項：${line.inventoryItemId}`);
      }

      const item = state.data || {};
      if (item.enabled === false) {
        throw new Error(`「${item.name || "庫存品項"}」已停用`);
      }

      const needed = roundQuantity(line.quantity);
      if (needed <= 0) {
        continue;
      }

      const available = roundQuantity(
          state.currentStock - state.reservedQuantity,
      );
      if (available < needed) {
        throw new Error(
            `「${item.name || "庫存品項"}」可售庫存不足`,
        );
      }

      state.reservedQuantity = roundQuantity(
          state.reservedQuantity + needed,
      );
      state.dirtyReserved = true;

      savedLines.push({
        inventoryItemId: line.inventoryItemId,
        quantity: needed,
        itemName: item.name || "",
        unit: item.unit || "",
      });
    }

    transaction.set(reservationRef, {
      shopId,
      orderId,
      userId: userId || "",
      status: "held",
      lines: savedLines,
      inventoryItemIds: inventoryIdsFromLines(savedLines),
      expireAt: admin.firestore.Timestamp.fromDate(expireAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);

  return savedLines;
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<void>}
 */
async function releaseReservation({
  transaction,
  shopId,
  orderId,
  userId,
}) {
  const firestore = admin.firestore();
  const reservationRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("store_reservations")
      .doc(orderId);
  const reservationSnapshot = await transaction.get(reservationRef);
  const reservation = reservationSnapshot.exists ?
    (reservationSnapshot.data() || {}) :
    {};
  const lines = Array.isArray(reservation.lines) ? reservation.lines : [];
  const neededIds = inventoryIdsFromLines(lines);

  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds: neededIds,
    extraReservationIds: [orderId],
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings(neededIds.concat(expiredItemIds));
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );

  writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });

  const alreadyExpired = expired.some((entry) => {
    return entry.reservationId === orderId;
  });

  if (reservationSnapshot.exists &&
    reservation.status === "held" &&
    !alreadyExpired) {
    lines.forEach((line) => {
      const itemId = String(line.inventoryItemId || "").trim();
      const state = itemStates.get(itemId);
      if (!state || !state.exists) {
        return;
      }
      const qty = roundQuantity(line.quantity || 0);
      state.reservedQuantity = roundQuantity(
          Math.max(state.reservedQuantity - qty, 0),
      );
      state.dirtyReserved = true;
    });

    transaction.set(reservationRef, {
      status: "released",
      releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);
}

/**
 * 付款成功後：保留轉正式扣庫存
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<void>}
 */
async function convertReservationToDeduct({
  transaction,
  shopId,
  orderId,
  userId,
}) {
  const firestore = admin.firestore();
  const reservationRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("store_reservations")
      .doc(orderId);
  const consumptionId = `so_${orderId}_deduct`;
  const consumptionRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("inventory_consumptions")
      .doc(consumptionId);

  const consumptionSnapshot = await transaction.get(consumptionRef);
  if (consumptionSnapshot.exists) {
    return;
  }

  const reservationSnapshot = await transaction.get(reservationRef);
  const reservation = reservationSnapshot.exists ?
    (reservationSnapshot.data() || {}) :
    {};
  const lines = Array.isArray(reservation.lines) ? reservation.lines : [];

  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds: inventoryIdsFromLines(lines),
    excludeReservationIds: [orderId],
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings(
      inventoryIdsFromLines(lines).concat(expiredItemIds),
  );
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );

  writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });

  if (lines.length === 0) {
    if (reservationSnapshot.exists && reservation.status === "held") {
      transaction.set(reservationRef, {
        status: "converted",
        convertedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    flushReservedOnly(transaction, userId, itemStates);
    writePublicStockForProducts(transaction, products, itemStates);
    return;
  }

  if (reservation.status === "converted") {
    flushReservedOnly(transaction, userId, itemStates);
    writePublicStockForProducts(transaction, products, itemStates);
    return;
  }

  if (reservation.status !== "held") {
    throw new Error("庫存保留已釋放，無法完成扣庫存");
  }

  const consumptionLines = [];

  for (const line of lines) {
    const state = itemStates.get(line.inventoryItemId);
    if (!state || !state.exists) {
      throw new Error("付款後找不到對應庫存品項");
    }

    const item = state.data || {};
    const quantity = roundQuantity(line.quantity || 0);
    const currentStock = state.currentStock;
    const reservedQuantity = state.reservedQuantity;
    const stockAfter = roundQuantity(currentStock - quantity);

    if (stockAfter < 0) {
      throw new Error(
          `「${item.name || "庫存品項"}」庫存不足，無法完成付款扣庫存`,
      );
    }

    const nextReserved = roundQuantity(
        Math.max(reservedQuantity - quantity, 0),
    );
    const nextCost = costAfterStockChange({
      item: Object.assign({}, item, {currentStock}),
      stockAfter,
    });
    const movementId = `${consumptionId}_${line.inventoryItemId}`;
    const movementRef = state.itemRef.collection("movements").doc(movementId);

    state.currentStock = stockAfter;
    state.reservedQuantity = nextReserved;
    state.dirtyReserved = false;

    transaction.update(state.itemRef, {
      currentStock: stockAfter,
      reservedQuantity: nextReserved,
      estimatedStockCost: nextCost.estimatedStockCost,
      weightedAverageCost: nextCost.weightedAverageCost,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: userId || "system",
    });

    transaction.set(movementRef, {
      shopId,
      inventoryItemId: line.inventoryItemId,
      type: "futureStore",
      quantityChange: -quantity,
      stockBefore: currentStock,
      stockAfter,
      sourceType: "futureStore",
      sourceId: orderId,
      sourceSubId: "",
      unitCost: Number(item.weightedAverageCost || 0),
      reason: "商城銷售",
      note: "商城訂單付款扣庫存",
      createdBy: userId || "system",
      itemNameSnapshot: item.name || line.itemName || "",
      unitSnapshot: item.unit || line.unit || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    consumptionLines.push({
      inventoryItemId: line.inventoryItemId,
      quantity,
      movementId,
      stockBefore: currentStock,
      stockAfter,
      itemName: item.name || line.itemName || "",
      unit: item.unit || line.unit || "",
    });
  }

  transaction.set(consumptionRef, {
    shopId,
    sourceType: "futureStore",
    sourceId: orderId,
    operation: "deduct",
    status: "completed",
    lines: consumptionLines,
    createdBy: userId || "system",
    note: "商城訂單付款扣庫存",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (reservationSnapshot.exists) {
    transaction.set(reservationRef, {
      status: "converted",
      convertedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);
}

/**
 * 已扣庫存後取消：idempotent 返還
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<void>}
 */
async function returnStoreOrderStock({
  transaction,
  shopId,
  orderId,
  userId,
}) {
  const firestore = admin.firestore();
  const deductId = `so_${orderId}_deduct`;
  const returnId = `so_${orderId}_return`;
  const deductRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("inventory_consumptions")
      .doc(deductId);
  const returnRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("inventory_consumptions")
      .doc(returnId);

  const returnSnapshot = await transaction.get(returnRef);
  if (returnSnapshot.exists) {
    return;
  }

  const deductSnapshot = await transaction.get(deductRef);
  if (!deductSnapshot.exists) {
    return;
  }

  const deduct = deductSnapshot.data() || {};
  const lines = Array.isArray(deduct.lines) ? deduct.lines : [];
  const neededIds = inventoryIdsFromLines(lines);

  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds: neededIds,
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings(neededIds.concat(expiredItemIds));
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );

  writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });

  const consumptionLines = [];

  for (const line of lines) {
    const state = itemStates.get(line.inventoryItemId);
    if (!state || !state.exists) {
      continue;
    }

    const item = state.data || {};
    const quantity = roundQuantity(line.quantity || 0);
    const currentStock = state.currentStock;
    const stockAfter = roundQuantity(currentStock + quantity);
    const nextCost = costAfterStockChange({
      item: Object.assign({}, item, {currentStock}),
      stockAfter,
    });
    const movementId = `${returnId}_${line.inventoryItemId}`;
    const movementRef = state.itemRef.collection("movements").doc(movementId);
    const update = {
      currentStock: stockAfter,
      estimatedStockCost: nextCost.estimatedStockCost,
      weightedAverageCost: nextCost.weightedAverageCost,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: userId || "system",
    };
    if (state.dirtyReserved) {
      update.reservedQuantity = state.reservedQuantity;
      state.dirtyReserved = false;
    }

    state.currentStock = stockAfter;

    transaction.update(state.itemRef, update);

    transaction.set(movementRef, {
      shopId,
      inventoryItemId: line.inventoryItemId,
      type: "return",
      quantityChange: quantity,
      stockBefore: currentStock,
      stockAfter,
      sourceType: "futureStore",
      sourceId: orderId,
      sourceSubId: "",
      unitCost: Number(item.weightedAverageCost || 0),
      reason: "取消返還",
      note: "商城訂單取消返還庫存",
      createdBy: userId || "system",
      itemNameSnapshot: item.name || line.itemName || "",
      unitSnapshot: item.unit || line.unit || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    consumptionLines.push({
      inventoryItemId: line.inventoryItemId,
      quantity,
      movementId,
      stockBefore: currentStock,
      stockAfter,
      itemName: item.name || line.itemName || "",
      unit: item.unit || line.unit || "",
    });
  }

  transaction.set(returnRef, {
    shopId,
    sourceType: "futureStore",
    sourceId: orderId,
    operation: "return",
    status: "completed",
    lines: consumptionLines,
    createdBy: userId || "system",
    note: "商城訂單取消返還庫存",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);
}

/**
 * @param {Array<Object>} lines
 * @return {Array<Object>}
 */
function mergeInventoryLines(lines) {
  const map = new Map();
  for (const line of lines) {
    const inventoryItemId = String(line.inventoryItemId || "").trim();
    const quantity = roundQuantity(line.quantity || 0);
    if (!inventoryItemId || quantity <= 0) {
      continue;
    }
    const current = map.get(inventoryItemId) || {
      inventoryItemId,
      quantity: 0,
    };
    current.quantity = roundQuantity(current.quantity + quantity);
    map.set(inventoryItemId, current);
  }
  return Array.from(map.values());
}

/**
 * 開始付款前：釋放相關過期 reservation；若本單仍 held 則延長期限。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareReservationForPayment({
  transaction,
  shopId,
  orderId,
  expireAt,
  userId,
}) {
  const firestore = admin.firestore();
  const reservationRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("store_reservations")
      .doc(orderId);
  const orderRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("store_orders")
      .doc(orderId);

  const reservationSnapshot = await transaction.get(reservationRef);
  const orderSnapshot = await transaction.get(orderRef);
  const reservation = reservationSnapshot.exists ?
    (reservationSnapshot.data() || {}) :
    {};
  const order = orderSnapshot.exists ? (orderSnapshot.data() || {}) : {};
  const itemIds = uniqueStrings(
      inventoryIdsFromLines(reservation.lines)
          .concat(inventoryIdsFromOrder(order)),
  );

  const expired = await collectExpiredHeldReservations(transaction, {
    shopId,
    itemIds,
    extraReservationIds: [orderId],
  });
  const expiredItemIds = [];
  expired.forEach((entry) => {
    (entry.itemIds || []).forEach((itemId) => expiredItemIds.push(itemId));
  });
  const allItemIds = uniqueStrings(itemIds.concat(expiredItemIds));
  const itemStates = await loadItemStates(transaction, shopId, allItemIds);
  const products = await loadStoreProductsForItems(
      transaction,
      shopId,
      allItemIds,
  );

  const cancelledOrderIds = writeExpiredReservations({
    transaction,
    userId,
    expired,
    itemStates,
  });

  const thisExpired = expired.some((entry) => entry.reservationId === orderId);
  const orderStatus = String(order.status || "");
  const reservationStatus = String(reservation.status || "");
  const hasReservation = reservationSnapshot.exists;
  const stillHeld = !thisExpired &&
    orderStatus === "pending_payment" &&
    (!hasReservation || reservationStatus === "held");

  if (stillHeld && expireAt) {
    const expireTimestamp = admin.firestore.Timestamp.fromDate(expireAt);
    transaction.set(reservationRef, {
      expireAt: expireTimestamp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (orderSnapshot.exists) {
      transaction.set(orderRef, {
        reservationExpireAt: expireTimestamp,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  flushReservedOnly(transaction, userId, itemStates);
  writePublicStockForProducts(transaction, products, itemStates);

  return {
    held: stillHeld,
    thisExpired,
    cancelledOrderIds,
    orderStatus: thisExpired ? "cancelled" : orderStatus,
    reservationStatus: thisExpired ? "expired" : reservationStatus,
  };
}

/**
 * 建立綠界付款後延長庫存保留期限（ATM / 超商需較長時間）。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<void>}
 */
async function extendReservationExpire({
  transaction,
  shopId,
  orderId,
  expireAt,
  userId,
}) {
  await prepareReservationForPayment({
    transaction,
    shopId,
    orderId,
    expireAt,
    userId,
  });
}

module.exports = {
  roundQuantity,
  applyReservation,
  releaseReservation,
  convertReservationToDeduct,
  returnStoreOrderStock,
  mergeInventoryLines,
  extendReservationExpire,
  expireRelatedHeldReservations,
  prepareReservationForPayment,
  buildPublicStockFields,
};
