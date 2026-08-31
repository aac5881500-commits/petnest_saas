import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/store_stock_helper.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_availability_view.dart';

void main() {
  final DateTime now = DateTime(2026, 8, 30);

  StoreProductModel item({
    required String status,
    int sellable = 0,
    bool enabled = true,
    bool useInventory = true,
    String inventoryItemId = 'inv-1',
    String itemType = StoreItemPromotionTypes.none,
    int buy = 1,
    int free = 1,
    bool itemEnabled = false,
  }) {
    return StoreProductModel(
      id: 'p',
      shopId: 'shop',
      name: '測試',
      price: 100,
      enabled: enabled,
      featured: false,
      useInventory: useInventory,
      inventoryItemId: inventoryItemId,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      publicStockStatus: status,
      publicSellableQuantity: sellable,
      itemPromotionEnabled: itemEnabled,
      itemPromotionType: itemType,
      itemPromotionBuyQuantity: buy,
      itemPromotionFreeQuantity: free,
    );
  }

  test('售罄標籤', () {
    final StoreProductModel product = item(
      status: StoreConstants.stockOutOfStock,
      sellable: 0,
    );
    expect(StoreStockHelper.isOutOfStock(product), isTrue);
    expect(StoreAvailabilityView.label(product: product), '售罄');
  });

  test('低庫存顯示件數 ON', () {
    expect(
      StoreAvailabilityView.label(
        product: item(status: StoreConstants.stockLow, sellable: 3),
        showStockToCustomer: true,
      ),
      '僅剩 3 件',
    );
  });

  test('低庫存顯示件數 OFF', () {
    expect(
      StoreAvailabilityView.label(
        product: item(status: StoreConstants.stockLow, sellable: 3),
        showStockToCustomer: false,
      ),
      '即將售罄',
    );
  });

  test('未上架', () {
    expect(
      StoreAvailabilityView.label(
        product: item(status: StoreConstants.stockInStock, sellable: 8),
        unpublished: true,
      ),
      '未上架',
    );
  });

  test('舊商品未連庫存 → 前台不可販售', () {
    final StoreProductModel product = item(
      status: StoreConstants.stockUnlimited,
      sellable: 0,
      useInventory: false,
      inventoryItemId: '',
    );
    expect(product.hasInventoryLink, isFalse);
    expect(StoreStockHelper.isOutOfStock(product), isTrue);
    expect(StoreStockHelper.maxPurchaseQuantity(product), 0);
    expect(StoreStockHelper.adminStatusLabel(product), '未連結庫存');
    expect(StoreAvailabilityView.label(product: product), '售罄');
  });

  test('買2送1 可售5件 → 最多購買3件', () {
    final StoreProductModel product = item(
      status: StoreConstants.stockInStock,
      sellable: 5,
      itemEnabled: true,
      itemType: StoreItemPromotionTypes.buyXGetY,
      buy: 2,
      free: 1,
    );
    expect(StoreStockHelper.maxPurchaseQuantity(product), 3);
  });
}
