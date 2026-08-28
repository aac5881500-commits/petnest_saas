// lib/core/services/store_stock_helper.dart
// 🛒 商城前台庫存呈現
// 功能：只使用 StoreProduct 上的公開庫存狀態，不讀 inventory_items。

import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';

class StoreStockHelper {
  StoreStockHelper._();

  static bool isOutOfStock(StoreProductModel product) {
    if (!product.useInventory) {
      return false;
    }
    if (product.publicStockStatus == StoreConstants.stockUnlimited) {
      return false;
    }
    return product.publicStockStatus == StoreConstants.stockOutOfStock ||
        product.publicSellableQuantity <= 0;
  }

  static int maxPurchaseQuantity(StoreProductModel product) {
    if (!product.useInventory) {
      return 99;
    }
    if (product.publicStockStatus == StoreConstants.stockUnlimited) {
      return 99;
    }
    final int quantity = product.publicSellableQuantity;
    return quantity < 0 ? 0 : quantity;
  }

  static String statusLabel(StoreProductModel product) {
    if (!product.useInventory) {
      return '';
    }
    switch (product.publicStockStatus) {
      case StoreConstants.stockOutOfStock:
        return '缺貨';
      case StoreConstants.stockLow:
        return '低庫存';
      case StoreConstants.stockInStock:
      case StoreConstants.stockUnlimited:
        return '正常';
      default:
        return '正常';
    }
  }

  /// 店家後台寫入商品時計算公開庫存欄位。不得包含成本。
  static Map<String, dynamic> publicStockFields({
    required bool useInventory,
    InventoryItemModel? item,
    num inventoryQuantityPerSale = 1,
  }) {
    if (!useInventory) {
      return <String, dynamic>{
        'publicStockStatus': StoreConstants.stockUnlimited,
        'publicSellableQuantity': 0,
      };
    }

    if (item == null || !item.enabled) {
      return <String, dynamic>{
        'publicStockStatus': StoreConstants.stockOutOfStock,
        'publicSellableQuantity': 0,
      };
    }

    final num perSale =
        inventoryQuantityPerSale <= 0 ? 1 : inventoryQuantityPerSale;
    final num available = item.availableStock;
    final int sellable = (available / perSale).floor();
    if (sellable <= 0) {
      return <String, dynamic>{
        'publicStockStatus': StoreConstants.stockOutOfStock,
        'publicSellableQuantity': 0,
      };
    }

    final bool lowBySafety =
        item.safetyStock > 0 && available <= item.safetyStock;
    final bool lowByUnits = sellable <= StoreConstants.lowStockSellableThreshold;
    return <String, dynamic>{
      'publicStockStatus': (lowBySafety || lowByUnits)
          ? StoreConstants.stockLow
          : StoreConstants.stockInStock,
      'publicSellableQuantity': sellable,
    };
  }
}
