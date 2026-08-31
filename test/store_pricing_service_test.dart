import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';

void main() {
  final StorePricingService pricing = StorePricingService.instance;
  final DateTime now = DateTime(2026, 8, 30, 12);

  StoreProductModel product({
    String id = 'can',
    int price = 999,
    bool itemEnabled = false,
    String itemType = StoreItemPromotionTypes.none,
    num itemValue = 0,
    int buy = 1,
    int free = 1,
    bool allowStack = false,
    DateTime? start,
    DateTime? end,
    String categoryId = 'cat-can',
  }) {
    return StoreProductModel(
      id: id,
      shopId: 'shop',
      name: '測試罐頭',
      price: price,
      enabled: true,
      featured: false,
      useInventory: false,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
      itemPromotionEnabled: itemEnabled,
      itemPromotionType: itemType,
      itemPromotionValue: itemValue,
      itemPromotionBuyQuantity: buy,
      itemPromotionFreeQuantity: free,
      itemPromotionAllowStack: allowStack,
      itemPromotionStartAt: start,
      itemPromotionEndAt: end,
    );
  }

  StorePromotionModel campaign({
    required String type,
    String id = 'promo',
    String method = StoreDiscountMethods.percent,
    num value = 9,
    String categoryId = '',
    List<String> productIds = const <String>[],
    int minimumAmount = 0,
    int minimumQuantity = 0,
    bool allowStack = false,
    DateTime? start,
    DateTime? end,
  }) {
    return StorePromotionModel(
      id: id,
      shopId: 'shop',
      name: id,
      type: type,
      discountMethod: method,
      discountValue: value,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
      productIds: productIds,
      minimumAmount: minimumAmount,
      minimumQuantity: minimumQuantity,
      allowStack: allowStack,
      startAt: start,
      endAt: end,
    );
  }

  test('A 無優惠 → 原價', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(),
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.finalUnitPrice, 999);
    expect(line.freeQuantity, 0);
    expect(line.fulfillmentQuantity, 1);
  });

  test('B 特價 999 → 799', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.specialPrice,
        itemValue: 799,
      ),
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.finalUnitPrice, 799);
    expect(line.itemPromotionDiscount, 200);
    expect(line.offerBadge, '特價');
  });

  test('C 8 折 999 → 799', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.percent,
        itemValue: 8,
      ),
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.finalUnitPrice, 799);
  });

  test('D 固定減 100 → 899', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.amountOff,
        itemValue: 100,
      ),
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.finalUnitPrice, 899);
  });

  test('E 買 1 送 1：購買 1 → 付款 1、出貨 2', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.buyXGetY,
        buy: 1,
        free: 1,
      ),
      quantity: 1,
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.purchaseQuantity, 1);
    expect(line.freeQuantity, 1);
    expect(line.fulfillmentQuantity, 2);
    expect(line.finalSubtotal, 999);
    expect(line.finalUnitPrice, 999);
  });

  test('買 2 送 1：購買 1 / 2 / 3 / 4 出貨正確', () {
    final StoreProductModel canned = product(
      itemEnabled: true,
      itemType: StoreItemPromotionTypes.buyXGetY,
      buy: 2,
      free: 1,
    );
    StorePricedLine lineOf(int qty) {
      return pricing.quoteProduct(
        product: canned,
        quantity: qty,
        promotions: const <StorePromotionModel>[],
        now: now,
      );
    }

    expect(lineOf(1).freeQuantity, 0);
    expect(lineOf(1).fulfillmentQuantity, 1);
    expect(lineOf(2).freeQuantity, 1);
    expect(lineOf(2).fulfillmentQuantity, 3);
    expect(lineOf(2).finalSubtotal, 999 * 2);
    expect(lineOf(3).freeQuantity, 1);
    expect(lineOf(3).fulfillmentQuantity, 4);
    expect(lineOf(4).freeQuantity, 2);
    expect(lineOf(4).fulfillmentQuantity, 6);
  });

  test('F 買 2 送 1：購買 4 → 贈送 2、出貨 6', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.buyXGetY,
        buy: 2,
        free: 1,
      ),
      quantity: 4,
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.freeQuantity, 2);
    expect(line.fulfillmentQuantity, 6);
    expect(line.finalSubtotal, 999 * 4);
  });

  test('G 買一送一不可疊 → 不吃分類折扣', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.buyXGetY,
        allowStack: false,
      ),
      quantity: 1,
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.category,
          categoryId: 'cat-can',
          value: 9,
        ),
      ],
      now: now,
    );
    expect(line.finalUnitPrice, 999);
    expect(line.freeQuantity, 1);
    expect(line.campaignDiscount, 0);
    expect(line.canStackFurther, isFalse);
  });

  test('H 單品可疊 + 分類 9 折', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.percent,
        itemValue: 8,
        allowStack: true,
      ),
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.category,
          categoryId: 'cat-can',
          value: 9,
          allowStack: true,
        ),
      ],
      now: now,
    );
    expect(line.finalUnitPrice, pricing.applyDiscount(
      original: 799,
      method: StoreDiscountMethods.percent,
      value: 9,
    ));
    expect(line.itemPromotionDiscount, 200);
    expect(line.campaignDiscount, greaterThan(0));
  });

  test('最優惠：8折 / 9折 / 85折 不可疊只取一個', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.percent,
        itemValue: 8,
      ),
      promotions: <StorePromotionModel>[
        campaign(
          id: 'cat9',
          type: StorePromotionTypes.category,
          categoryId: 'cat-can',
          value: 9,
        ),
        campaign(
          id: 'multi85',
          type: StorePromotionTypes.product,
          productIds: <String>['can'],
          value: 85,
        ),
      ],
      now: now,
    );
    expect(line.finalUnitPrice, 799);
    expect(line.itemPromotionType, StoreItemPromotionTypes.percent);
  });

  test('I 分類折扣', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(),
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.category,
          categoryId: 'cat-can',
          value: 9,
        ),
      ],
      now: now,
    );
    expect(line.finalUnitPrice, 899);
  });

  test('J 滿件不計算贈品', () {
    final StoreCartQuote quote = pricing.quoteCart(
      products: <StoreProductModel>[
        product(
          itemEnabled: true,
          itemType: StoreItemPromotionTypes.buyXGetY,
          buy: 2,
          free: 2,
          allowStack: true,
        ),
      ],
      quantities: <String, int>{'can': 2},
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.quantity,
          method: StoreDiscountMethods.percent,
          value: 95,
          minimumQuantity: 5,
          allowStack: true,
        ),
      ],
      now: now,
    );
    expect(quote.lines.first.purchaseQuantity, 2);
    expect(quote.lines.first.freeQuantity, 2);
    expect(quote.quantityDiscount, 0);
  });

  test('K 滿額依前面優惠後金額', () {
    final StoreCartQuote quote = pricing.quoteCart(
      products: <StoreProductModel>[
        product(
          itemEnabled: true,
          itemType: StoreItemPromotionTypes.specialPrice,
          itemValue: 799,
          allowStack: true,
        ),
      ],
      quantities: <String, int>{'can': 2},
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.amount,
          method: StoreDiscountMethods.amountOff,
          value: 100,
          minimumAmount: 1500,
          allowStack: true,
        ),
      ],
      now: now,
    );
    expect(quote.originalSubtotal, 1998);
    expect(quote.itemPromotionDiscount, 400);
    expect(quote.amountDiscount, 100);
    expect(quote.finalSubtotal, 1498);
  });

  test('L 活動到期恢復原價', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.specialPrice,
        itemValue: 799,
        end: DateTime(2026, 8, 1),
      ),
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.finalUnitPrice, 999);
    expect(line.itemPromotionType, StoreItemPromotionTypes.none);
  });

  test('N 出貨數量供庫存：買1送1 購買1 → fulfillment 2', () {
    expect(
      pricing.fulfillmentQuantityOf(
        product: product(
          itemEnabled: true,
          itemType: StoreItemPromotionTypes.buyXGetY,
        ),
        purchaseQuantity: 1,
        now: now,
      ),
      2,
    );
  });

  StoreProductModel stocked({
    required String id,
    required int price,
    required int sellable,
    String name = '商品',
    String inventoryItemId = 'inv',
  }) {
    return StoreProductModel(
      id: id,
      shopId: 'shop',
      name: name,
      price: price,
      enabled: true,
      featured: false,
      useInventory: true,
      inventoryItemId: inventoryItemId,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      publicSellableQuantity: sellable,
      publicStockStatus: sellable <= 0
          ? 'out_of_stock'
          : (sellable <= 3 ? 'low_stock' : 'in_stock'),
    );
  }

  StorePromotionModel bundleOf({
    required List<StoreBundleItem> items,
    int price = 299,
  }) {
    return StorePromotionModel(
      id: 'bundle',
      shopId: 'shop',
      name: '貓咪迎新組',
      type: StorePromotionTypes.bundle,
      discountMethod: StoreDiscountMethods.specialPrice,
      discountValue: price,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      bundleItems: items,
    );
  }

  test('套裝 A×2 + B×1 庫存充足可買', () {
    final List<StoreProductModel> products = <StoreProductModel>[
      stocked(id: 'a', price: 100, sellable: 10, name: '罐頭'),
      stocked(id: 'b', price: 80, sellable: 10, name: '零食'),
    ];
    final StorePromotionModel promo = bundleOf(
      items: const <StoreBundleItem>[
        StoreBundleItem(productId: 'a', quantity: 2),
        StoreBundleItem(productId: 'b', quantity: 1),
      ],
      price: 199,
    );
    expect(
      pricing.isBundleSoldOut(promotion: promo, products: products),
      isFalse,
    );
    final StoreCartQuote quote = pricing.quoteCart(
      products: products,
      quantities: const <String, int>{},
      promotions: <StorePromotionModel>[promo],
      bundleQuantities: const <String, int>{'bundle': 1},
      now: now,
    );
    expect(quote.originalSubtotal, 280);
    expect(quote.finalSubtotal, 199);
    expect(quote.bundleDiscount, 81);
  });

  test('套裝任一成分不足 → 整組售罄', () {
    final StorePromotionModel promo = bundleOf(
      items: const <StoreBundleItem>[
        StoreBundleItem(productId: 'a', quantity: 2),
        StoreBundleItem(productId: 'b', quantity: 1),
      ],
    );
    expect(
      pricing.isBundleSoldOut(
        promotion: promo,
        products: <StoreProductModel>[
          stocked(id: 'a', price: 100, sellable: 1),
          stocked(id: 'b', price: 80, sellable: 10),
        ],
      ),
      isTrue,
    );
  });

  test('套裝 2 組原價與售價 ×2', () {
    final StoreCartQuote quote = pricing.quoteCart(
      products: <StoreProductModel>[
        stocked(id: 'a', price: 100, sellable: 10),
        stocked(id: 'b', price: 80, sellable: 10),
      ],
      quantities: const <String, int>{},
      promotions: <StorePromotionModel>[
        bundleOf(
          items: const <StoreBundleItem>[
            StoreBundleItem(productId: 'a', quantity: 2),
            StoreBundleItem(productId: 'b', quantity: 1),
          ],
          price: 199,
        ),
      ],
      bundleQuantities: const <String, int>{'bundle': 2},
      now: now,
    );
    expect(quote.originalSubtotal, 560);
    expect(quote.finalSubtotal, 398);
  });

  test('多件任選 3 件 9 折', () {
    final StoreCartQuote quote = pricing.quoteCart(
      products: <StoreProductModel>[
        product(id: 'a', price: 100),
        product(id: 'b', price: 100),
        product(id: 'c', price: 100),
      ],
      quantities: const <String, int>{'a': 1, 'b': 1, 'c': 1},
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.quantity,
          method: StoreDiscountMethods.percent,
          value: 9,
          minimumQuantity: 3,
          productIds: const <String>['a', 'b', 'c'],
        ),
      ],
      now: now,
    );
    expect(quote.quantityDiscount, 30);
    expect(quote.finalSubtotal, 270);
  });

  test('多件任選 3 件 NT\$199', () {
    final StoreCartQuote quote = pricing.quoteCart(
      products: <StoreProductModel>[
        product(id: 'a', price: 100),
        product(id: 'b', price: 100),
        product(id: 'c', price: 100),
      ],
      quantities: const <String, int>{'a': 1, 'b': 1, 'c': 1},
      promotions: <StorePromotionModel>[
        campaign(
          type: StorePromotionTypes.quantity,
          method: StoreDiscountMethods.specialPrice,
          value: 199,
          minimumQuantity: 3,
          productIds: const <String>['a', 'b', 'c'],
        ),
      ],
      now: now,
    );
    expect(quote.finalSubtotal, 199);
    expect(quote.quantityDiscount, 101);
  });

  test('買2送1 庫存5 → 最多可購3（fulfillment 4）', () {
    expect(
      pricing.maxPurchaseForSellable(
        product: product(
          itemEnabled: true,
          itemType: StoreItemPromotionTypes.buyXGetY,
          buy: 2,
          free: 1,
        ),
        sellableUnits: 5,
        now: now,
      ),
      3,
    );
  });

  test('買2送1 購買2 → fulfillment 3；購買4 → fulfillment 6', () {
    final StoreProductModel canned = product(
      itemEnabled: true,
      itemType: StoreItemPromotionTypes.buyXGetY,
      buy: 2,
      free: 1,
    );
    expect(
      pricing.fulfillmentQuantityOf(
        product: canned,
        purchaseQuantity: 2,
        now: now,
      ),
      3,
    );
    expect(
      pricing.fulfillmentQuantityOf(
        product: canned,
        purchaseQuantity: 4,
        now: now,
      ),
      6,
    );
  });

  test('套裝成分未連庫存 → 整組不可買', () {
    expect(
      pricing.maxBundleSets(
        promotion: bundleOf(
          items: const <StoreBundleItem>[
            StoreBundleItem(productId: 'a', quantity: 2),
            StoreBundleItem(productId: 'b', quantity: 1),
          ],
        ),
        products: <StoreProductModel>[
          stocked(id: 'a', price: 100, sellable: 10, inventoryItemId: ''),
          stocked(id: 'b', price: 80, sellable: 10),
        ],
      ),
      0,
    );
  });

  test('買X送Y Badge 不放商品卡圖片角落', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.buyXGetY,
        buy: 2,
        free: 1,
      ),
      quantity: 1,
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.isBuyXGetYOffer, isTrue);
    expect(line.offerBadge, '買2送1');
    expect(line.showsPromotionOnProductImage, isFalse);
  });

  test('特價 Badge 可留在商品卡圖片角落', () {
    final StorePricedLine line = pricing.quoteProduct(
      product: product(
        itemEnabled: true,
        itemType: StoreItemPromotionTypes.specialPrice,
        itemValue: 888,
      ),
      quantity: 1,
      promotions: const <StorePromotionModel>[],
      now: now,
    );
    expect(line.offerBadge, '特價');
    expect(line.showsPromotionOnProductImage, isTrue);
  });
}
