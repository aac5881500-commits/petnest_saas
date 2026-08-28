// functions/inventory/inventory_cost.js
// 📦 與 Dart InventoryConstants 等價的成本算法
// remainingStockCost / weightedAverageFromCost / round 精度必須與
// lib/core/constants/inventory_constants.dart 一致，
// 供商城、點數兌換、住宿加購 Functions 共用，避免各功能另寫一套算法。

/**
 * @param {number} value
 * @return {number}
 */
function roundQuantity(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    return 0;
  }
  return Number(numberValue.toFixed(4));
}

/**
 * @param {number} value
 * @return {number}
 */
function roundMoney(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) {
    return 0;
  }
  return Number(numberValue.toFixed(2));
}

/**
 * @param {number} value
 * @return {number}
 */
function roundUnitCost(value) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue) || numberValue === 0) {
    return 0;
  }
  return Number(numberValue.toFixed(8));
}

/**
 * 出庫／返還：依庫存比例調整獨立總成本。
 *
 * @param {Object} params
 * @return {number}
 */
function remainingStockCost({
  currentEstimatedCost,
  stockBefore,
  stockAfter,
  fallbackUnitCost,
}) {
  if (stockAfter <= 0) {
    return 0;
  }

  if (stockBefore > 0) {
    return roundMoney(
        Number(currentEstimatedCost || 0) * stockAfter / stockBefore,
    );
  }

  return roundMoney(stockAfter * Number(fallbackUnitCost || 0));
}

/**
 * 由獨立庫存總成本推導加權平均，不反過來用平均回推總成本。
 *
 * @param {Object} params
 * @return {number}
 */
function weightedAverageFromCost({
  estimatedStockCost,
  currentStock,
  fallbackUnitCost,
}) {
  if (currentStock <= 0) {
    return roundUnitCost(Number(fallbackUnitCost || 0));
  }

  return roundUnitCost(
      Number(estimatedStockCost || 0) / currentStock,
  );
}

/**
 * 對應 Dart InventoryStockService._costAfterStockChange。
 *
 * @param {Object} params
 * @return {{estimatedStockCost: number, weightedAverageCost: number}}
 */
function costAfterStockChange({item, stockAfter}) {
  const stockBefore = roundQuantity(item.currentStock || 0);
  const nextEstimatedCost = remainingStockCost({
    currentEstimatedCost: Number(item.estimatedStockCost || 0),
    stockBefore,
    stockAfter,
    fallbackUnitCost: Number(item.weightedAverageCost || 0),
  });

  return {
    estimatedStockCost: nextEstimatedCost,
    weightedAverageCost: weightedAverageFromCost({
      estimatedStockCost: nextEstimatedCost,
      currentStock: stockAfter,
      fallbackUnitCost: Number(item.weightedAverageCost || 0),
    }),
  };
}

module.exports = {
  roundQuantity,
  roundMoney,
  roundUnitCost,
  remainingStockCost,
  weightedAverageFromCost,
  costAfterStockChange,
};
