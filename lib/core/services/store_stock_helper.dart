// lib/core/services/store_stock_helper.dart
// 🛒 商城前台庫存呈現
// 功能：只使用 StoreProduct 上的公開庫存狀態，不讀 inventory_items。

import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';

class StoreStockHelper {
  StoreStockHelper._();

  static bool isOutOfStock(StoreProductModel product) {
    if (!product.hasInventoryLink) {
      return true;
    }
    if (product.publicStockStatus == StoreConstants.stockUnlimited) {
      return product.publicSellableQuantity <= 0;
    }
    return product.publicStockStatus == StoreConstants.stockOutOfStock ||
        product.publicSellableQuantity <= 0;
  }

  static int maxPurchaseQuantity(StoreProductModel product) {
    if (!product.hasInventoryLink) {
      return 0;
    }
    if (product.publicStockStatus == StoreConstants.stockUnlimited &&
        product.publicSellableQuantity <= 0) {
      return 0;
    }
    final int quantity = product.publicSellableQuantity;
    final int sellable = quantity < 0 ? 0 : quantity;
    return StorePricingService.instance.maxPurchaseForSellable(
      product: product,
      sellableUnits: sellable,
    );
  }

  static String adminStatusLabel(StoreProductModel product) {
    if (!product.hasInventoryLink) {
      return '未連結庫存';
    }
    if (isOutOfStock(product)) {
      return '售罄';
    }
    if (product.publicStockStatus == StoreConstants.stockLow) {
      return '低庫存';
    }
    return '正常';
  }

  static String statusLabel(StoreProductModel product) {
    return storefrontStatusLabel(product);
  }

  /// 前台庫存文案。showStockToCustomer = false 時不公開實際件數。
  static String storefrontStatusLabel(
    StoreProductModel product, {
    bool showStockToCustomer = true,
    bool unpublished = false,
  }) {
    if (unpublished || !product.enabled) {
      return '未上架';
    }
    if (!product.hasInventoryLink || isOutOfStock(product)) {
      return '售罄';
    }
    if (product.publicStockStatus == StoreConstants.stockLow) {
      if (showStockToCustomer && product.publicSellableQuantity > 0) {
        return '僅剩 ${product.publicSellableQuantity} 件';
      }
      return '即將售罄';
    }
    return '庫存充足';
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

    final num perSale = inventoryQuantityPerSale <= 0
        ? 1
        : inventoryQuantityPerSale;
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
    final bool lowByUnits =
        sellable <= StoreConstants.lowStockSellableThreshold;
    return <String, dynamic>{
      'publicStockStatus': (lowBySafety || lowByUnits)
          ? StoreConstants.stockLow
          : StoreConstants.stockInStock,
      'publicSellableQuantity': sellable,
    };
  }
}
