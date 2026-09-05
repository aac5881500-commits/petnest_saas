// 檔案名稱：functions/inventory/inventory_consumption.js
// 功能說明：對應 Dart InventoryStockService 的確定性 consumption
// 點數：pr_{id}_deduct / pr_{id}_return
// 住宿加購：ba_{id}_deduct / ba_{id}_return
// 住宿耗材返還：bs_{id}_deduct 存在才可 bs_{id}_return
// 商城正式扣庫存仍走 store_inventory.js（含 reservedQuantity）。

const admin = require("firebase-admin");
const {
  roundQuantity,
  costAfterStockChange,
} = require("./inventory_cost");

/**
 * @param {string} prefix
 * @param {string} sourceId
 * @param {string} operation
 * @return {string}
 */
function consumptionId(prefix, sourceId, operation) {
  return `${prefix}_${String(sourceId || "").trim()}_${operation}`;
}

/**
 * @param {string} redemptionId
 * @return {string}
 */
function redemptionDeductId(redemptionId) {
  return consumptionId("pr", redemptionId, "deduct");
}

/**
 * @param {string} redemptionId
 * @return {string}
 */
function redemptionReturnId(redemptionId) {
  return consumptionId("pr", redemptionId, "return");
}

/**
 * @param {string} bookingId
 * @return {string}
 */
function bookingAddonDeductId(bookingId) {
  return consumptionId("ba", bookingId, "deduct");
}

/**
 * @param {string} bookingId
 * @return {string}
 */
function bookingAddonReturnId(bookingId) {
  return consumptionId("ba", bookingId, "return");
}

/**
 * @param {string} bookingId
 * @return {string}
 */
function bookingSupplyDeductId(bookingId) {
  return consumptionId("bs", bookingId, "deduct");
}

/**
 * @param {string} bookingId
 * @return {string}
 */
function bookingSupplyReturnId(bookingId) {
  return consumptionId("bs", bookingId, "return");
}

/**
 * @param {string} consumptionIdValue
 * @param {string} inventoryItemId
 * @return {string}
 */
function movementDocId(consumptionIdValue, inventoryItemId) {
  return `${consumptionIdValue}_${inventoryItemId}`;
}

/**
 * 合併相同 inventoryItemId 的扣除量。
 *
 * @param {Array<Object>} lines
 * @return {Array<Object>}
 */
function mergeDeductLines(lines) {
  const merged = new Map();
  (lines || []).forEach((line) => {
    const itemId = String(
        (line && line.inventoryItemId) || "",
    ).trim();
    const quantity = roundQuantity((line && line.quantity) || 0);
    if (!itemId || quantity <= 0) {
      return;
    }
    const existing = merged.get(itemId);
    if (!existing) {
      merged.set(itemId, {
        inventoryItemId: itemId,
        quantity,
        reason: String((line && line.reason) || ""),
        note: String((line && line.note) || ""),
      });
      return;
    }
    existing.quantity = roundQuantity(existing.quantity + quantity);
  });
  return Array.from(merged.values()).filter((line) => {
    return line.quantity > 0;
  });
}

/**
 * 準備合併後扣庫存。必須在 Transaction 任何 write 之前呼叫。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareMergedDeduct(transaction, {
  shopId,
  consumptionId: consumptionDocId,
  sourceType,
  sourceId,
  movementType,
  note,
  lines,
}) {
  const firestore = admin.firestore();
  const consumptionRef = firestore
      .collection("shops")
      .doc(shopId)
      .collection("inventory_consumptions")
      .doc(consumptionDocId);

  const consumptionSnapshot = await transaction.get(consumptionRef);
  const merged = mergeDeductLines(lines);
  if (consumptionSnapshot.exists || merged.length === 0) {
    return {skip: true, consumptionRef, lines: []};
  }

  const preparedLines = [];
  for (const line of merged) {
    const itemRef = firestore
        .collection("shops")
        .doc(shopId)
        .collection("inventory_items")
        .doc(line.inventoryItemId);
    const itemSnapshot = await transaction.get(itemRef);
    if (!itemSnapshot.exists) {
      throw new Error("找不到對應庫存品項");
    }

    const item = itemSnapshot.data() || {};
    if (item.enabled === false) {
      throw new Error(`「${item.name || "庫存品項"}」已停用`);
    }

    const needed = line.quantity;
    if (item.allowDecimal === false && needed % 1 !== 0) {
      throw new Error(`「${item.name || "庫存品項"}」僅允許整數數量`);
    }

    const stockBefore = roundQuantity(item.currentStock || 0);
    const reservedQuantity = roundQuantity(item.reservedQuantity || 0);
    const stockAfter = roundQuantity(stockBefore - needed);
    if (stockAfter < 0) {
      throw new Error(
          `庫存不足，目前剩餘 ${stockBefore} ${item.unit || ""}`.trim(),
      );
    }
    if (stockAfter < reservedQuantity) {
      throw new Error(
          `「${item.name || "庫存品項"}」可售庫存不足，` +
          "部分數量已保留給商城訂單",
      );
    }

    preparedLines.push({
      itemId: line.inventoryItemId,
      itemRef,
      item,
      quantityChange: roundQuantity(-needed),
      quantity: needed,
      stockBefore,
      stockAfter,
      reason: line.reason,
      note: line.note,
    });
  }

  return {
    skip: false,
    consumptionRef,
    consumptionId: consumptionDocId,
    shopId,
    sourceId,
    operation: "deduct",
    sourceType,
    movementType,
    note: String(note || ""),
    lines: preparedLines,
  };
}

/**
 * 依既有 deduct consumption 準備返還。沒有 deduct 則 skip。
 * 必須在 Transaction 任何 write 之前呼叫。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function prepareReturnFromDeduct(transaction, {
  shopId,
  deductId,
  returnId,
  sourceType,
  sourceId,
  movementType,
  note,
}) {
  const firestore = admin.firestore();
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
    return {skip: true, consumptionRef: returnRef, lines: []};
  }

  const deductSnapshot = await transaction.get(deductRef);
  if (!deductSnapshot.exists) {
    return {skip: true, consumptionRef: returnRef, lines: []};
  }

  const deduct = deductSnapshot.data() || {};
  const deductLines = Array.isArray(deduct.lines) ? deduct.lines : [];
  const lines = [];

  for (const line of deductLines) {
    const itemId = String(line.inventoryItemId || "").trim();
    if (!itemId) {
      continue;
    }
    const needed = roundQuantity(line.quantity || 0);
    if (needed <= 0) {
      continue;
    }
    const itemRef = firestore
        .collection("shops")
        .doc(shopId)
        .collection("inventory_items")
        .doc(itemId);
    const itemSnapshot = await transaction.get(itemRef);
    if (!itemSnapshot.exists) {
      continue;
    }
    const item = itemSnapshot.data() || {};
    const stockBefore = roundQuantity(item.currentStock || 0);
    const stockAfter = roundQuantity(stockBefore + needed);
    lines.push({
      itemId,
      itemRef,
      item,
      quantityChange: needed,
      quantity: needed,
      stockBefore,
      stockAfter,
      reason: "取消返還",
      note: String(note || ""),
    });
  }

  return {
    skip: lines.length === 0,
    consumptionRef: returnRef,
    consumptionId: returnId,
    shopId,
    sourceId,
    operation: "return",
    sourceType,
    movementType,
    note: String(note || ""),
    lines,
  };
}

/**
 * 準備點數兌換扣庫存。必須在 Transaction 任何 write 之前呼叫。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function preparePointRedemptionDeduct(transaction, {
  shopId,
  redemptionId,
  inventoryItemId,
  quantity,
  itemName,
  note,
}) {
  const displayName = String(itemName || "").trim();
  const reason = displayName ? `點數兌換「${displayName}」` : "點數兌換";
  return prepareMergedDeduct(transaction, {
    shopId,
    consumptionId: redemptionDeductId(redemptionId),
    sourceType: "pointRedemption",
    sourceId: redemptionId,
    movementType: "pointRedemption",
    note: String(note || ""),
    lines: [{
      inventoryItemId,
      quantity,
      reason,
      note: String(note || ""),
    }],
  });
}

/**
 * 準備點數兌換取消返還。必須在 Transaction 任何 write 之前呼叫。
 *
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} params
 * @return {Promise<Object>}
 */
async function preparePointRedemptionReturn(transaction, {
  shopId,
  redemptionId,
}) {
  return prepareReturnFromDeduct(transaction, {
    shopId,
    deductId: redemptionDeductId(redemptionId),
    returnId: redemptionReturnId(redemptionId),
    sourceType: "return",
    sourceId: redemptionId,
    movementType: "return",
    note: "取消點數兌換返還庫存",
  });
}

/**
 * @param {FirebaseFirestore.Transaction} transaction
 * @param {Object} prepared
 * @param {string} userId
 */
function commitPreparedConsumption(transaction, prepared, userId) {
  if (!prepared || prepared.skip) {
    return;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const consumptionLines = [];

  prepared.lines.forEach((line) => {
    const nextCost = costAfterStockChange({
      item: line.item,
      stockAfter: line.stockAfter,
    });
    const movementId = movementDocId(
        prepared.consumptionId,
        line.itemId,
    );
    const movementRef = line.itemRef.collection("movements").doc(movementId);

    transaction.update(line.itemRef, {
      currentStock: line.stockAfter,
      estimatedStockCost: nextCost.estimatedStockCost,
      weightedAverageCost: nextCost.weightedAverageCost,
      updatedAt: now,
      updatedBy: userId || "system",
    });

    transaction.set(movementRef, {
      shopId: prepared.shopId,
      inventoryItemId: line.itemId,
      type: prepared.movementType,
      quantityChange: line.quantityChange,
      stockBefore: line.stockBefore,
      stockAfter: line.stockAfter,
      sourceType: prepared.sourceType,
      sourceId: prepared.sourceId,
      sourceSubId: "",
      unitCost: Number(line.item.weightedAverageCost || 0),
      reason: line.reason,
      note: line.note,
      createdBy: userId || "system",
      itemNameSnapshot: line.item.name || "",
      unitSnapshot: line.item.unit || "",
      createdAt: now,
    });

    consumptionLines.push({
      inventoryItemId: line.itemId,
      quantity: line.quantity,
      movementId,
      stockBefore: line.stockBefore,
      stockAfter: line.stockAfter,
      itemName: line.item.name || "",
      unit: line.item.unit || "",
    });
  });

  transaction.set(prepared.consumptionRef, {
    shopId: prepared.shopId,
    sourceType: prepared.sourceType,
    sourceId: prepared.sourceId,
    operation: prepared.operation,
    status: "completed",
    lines: consumptionLines,
    createdBy: userId || "system",
    note: prepared.note || "",
    createdAt: now,
  });
}

module.exports = {
  consumptionId,
  redemptionDeductId,
  redemptionReturnId,
  bookingAddonDeductId,
  bookingAddonReturnId,
  bookingSupplyDeductId,
  bookingSupplyReturnId,
  mergeDeductLines,
  prepareMergedDeduct,
  prepareReturnFromDeduct,
  preparePointRedemptionDeduct,
  preparePointRedemptionReturn,
  commitPreparedConsumption,
};
