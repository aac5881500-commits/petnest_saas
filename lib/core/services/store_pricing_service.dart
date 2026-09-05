// 檔案名稱：lib/core/services/store_pricing_service.dart
// 功能說明：商城共用計價引擎
// 單品優惠 + 跨商品活動同一套計算。不改 StoreProduct.price。
// 同一層級取最優惠，不疊成連乘。買 X 送 Y 的付款數量與出貨數量分開。

import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';

class StorePricedLine {
  StorePricedLine({
    required this.product,
    required this.quantity,
    required this.originalUnitPrice,
    required this.finalUnitPrice,
    this.promotion,
    this.freeQuantity = 0,
    int? fulfillmentQuantity,
    this.itemPromotionType = StoreItemPromotionTypes.none,
    this.itemPromotionName = '',
    this.itemPromotionDiscount = 0,
    this.campaignDiscount = 0,
    this.canStackFurther = true,
    this.appliedEndAt,
  }) : fulfillmentQuantity = fulfillmentQuantity ?? quantity + freeQuantity;

  final StoreProductModel product;
  final int quantity;
  final int originalUnitPrice;
  final int finalUnitPrice;
  final StorePromotionModel? promotion;
  final int freeQuantity;
  final int fulfillmentQuantity;
  final String itemPromotionType;
  final String itemPromotionName;
  final int itemPromotionDiscount;
  final int campaignDiscount;
  final bool canStackFurther;
  final DateTime? appliedEndAt;

  int get purchaseQuantity => quantity;
  int get originalSubtotal => originalUnitPrice * quantity;
  int get finalSubtotal => finalUnitPrice * quantity;
  int get discountAmount => originalSubtotal - finalSubtotal;
  bool get hasDiscount =>
      finalUnitPrice < originalUnitPrice || freeQuantity > 0;
  bool get hasOffer =>
      hasDiscount ||
      (itemPromotionType.isNotEmpty &&
          itemPromotionType != StoreItemPromotionTypes.none) ||
      promotion != null;

  bool get isBuyXGetYOffer =>
      itemPromotionType == StoreItemPromotionTypes.buyXGetY;

  /// 商品卡圖片角落不放買 X 送 Y，避免與文字區重複。
  bool get showsPromotionOnProductImage =>
      offerBadge.trim().isNotEmpty && !isBuyXGetYOffer;

  String get offerBadge {
    if (itemPromotionType == StoreItemPromotionTypes.buyXGetY) {
      final int buy = product.itemPromotionBuyQuantity < 1
          ? 1
          : product.itemPromotionBuyQuantity;
      final int free = product.itemPromotionFreeQuantity < 1
          ? 1
          : product.itemPromotionFreeQuantity;
      return '買$buy送$free';
    }
    if (itemPromotionType == StoreItemPromotionTypes.specialPrice) {
      return '特價';
    }
    if (itemPromotionType == StoreItemPromotionTypes.percent) {
      return StoreItemPromotionTypes.percentLabel(product.itemPromotionValue);
    }
    if (itemPromotionType == StoreItemPromotionTypes.amountOff) {
      return '減價';
    }
    if (promotion == null) {
      return '';
    }
    if (promotion!.discountMethod == StoreDiscountMethods.specialPrice) {
      return '特價';
    }
    if (promotion!.discountMethod == StoreDiscountMethods.percent) {
      return StoreItemPromotionTypes.percentLabel(promotion!.discountValue);
    }
    return '優惠';
  }

  String get offerName {
    if (itemPromotionName.trim().isNotEmpty) {
      return itemPromotionName;
    }
    return promotion?.offerLabel ?? '';
  }
}

class StoreBundleQuote {
  const StoreBundleQuote({
    required this.promotion,
    required this.sets,
    required this.originalTotal,
    required this.finalTotal,
    required this.soldOut,
    this.componentLabels = const <String>[],
  });

  final StorePromotionModel promotion;
  final int sets;
  final int originalTotal;
  final int finalTotal;
  final bool soldOut;
  final List<String> componentLabels;

  int get saved => originalTotal - finalTotal;
}

class StoreCartQuote {
  const StoreCartQuote({
    required this.lines,
    required this.originalSubtotal,
    required this.itemDiscount,
    required this.itemPromotionDiscount,
    required this.campaignDiscount,
    required this.quantityDiscount,
    required this.amountDiscount,
    required this.finalSubtotal,
    this.quantityPromotion,
    this.amountPromotion,
    this.bundleQuotes = const <StoreBundleQuote>[],
    this.bundleDiscount = 0,
    this.priceChanged = false,
  });

  final List<StorePricedLine> lines;
  final int originalSubtotal;
  final int itemDiscount;
  final int itemPromotionDiscount;
  final int campaignDiscount;
  final int quantityDiscount;
  final int amountDiscount;
  final int finalSubtotal;
  final StorePromotionModel? quantityPromotion;
  final StorePromotionModel? amountPromotion;
  final List<StoreBundleQuote> bundleQuotes;
  final int bundleDiscount;
  final bool priceChanged;

  int get promotionDiscount =>
      itemPromotionDiscount +
      campaignDiscount +
      quantityDiscount +
      amountDiscount +
      bundleDiscount;

  StorePricedLine? lineOf(String productId) {
    for (final StorePricedLine line in lines) {
      if (line.product.id == productId) {
        return line;
      }
    }
    return null;
  }
}

class StorePricingService {
  StorePricingService._();
  static final StorePricingService instance = StorePricingService._();

  StoreCartQuote quoteCart({
    required List<StoreProductModel> products,
    required Map<String, int> quantities,
    required List<StorePromotionModel> promotions,
    DateTime? now,
    int? previousFinalSubtotal,
    Map<String, int> bundleQuantities = const <String, int>{},
  }) {
    final DateTime at = now ?? DateTime.now();
    final List<StorePromotionModel> active = promotions
        .where((StorePromotionModel item) => item.isActiveAt(at))
        .toList();

    final List<StorePricedLine> lines = <StorePricedLine>[];
    for (final StoreProductModel product in products) {
      final int quantity = quantities[product.id] ?? 0;
      if (quantity <= 0) {
        continue;
      }
      lines.add(
        quoteProduct(
          product: product,
          quantity: quantity,
          promotions: active,
          now: at,
        ),
      );
    }

    final int originalSubtotal = lines.fold<int>(
      0,
      (int sum, StorePricedLine line) => sum + line.originalSubtotal,
    );
    final int itemPromotionDiscount = lines.fold<int>(
      0,
      (int sum, StorePricedLine line) => sum + line.itemPromotionDiscount,
    );
    final int campaignDiscount = lines.fold<int>(
      0,
      (int sum, StorePricedLine line) => sum + line.campaignDiscount,
    );

    final _MixMatchResult mix = _quoteMixMatch(
      lines: lines,
      promotions: active,
    );

    int stackableAmount = 0;
    int lockedAmount = 0;
    int stackableQty = 0;
    for (final StorePricedLine line in lines) {
      final bool mixLocked =
          mix.promotion != null &&
          !mix.promotion!.allowStack &&
          mix.productIds.contains(line.product.id);
      if (line.canStackFurther && !mixLocked) {
        stackableAmount += line.finalSubtotal;
        stackableQty += line.purchaseQuantity;
      } else {
        lockedAmount += line.finalSubtotal;
      }
    }
    if (mix.promotion != null && mix.promotion!.allowStack) {
      stackableAmount -= mix.discount;
      if (stackableAmount < 0) {
        stackableAmount = 0;
      }
    }

    final _CartLayerResult cartLayer = _quoteCartLayers(
      promotions: active.where((StorePromotionModel item) {
        return !item.isMixMatch;
      }).toList(),
      stackableAmount: stackableAmount,
      stackableQty: stackableQty,
    );

    final List<StoreBundleQuote> bundleQuotes = <StoreBundleQuote>[];
    int bundleOriginal = 0;
    int bundleFinal = 0;
    for (final StorePromotionModel promo in active) {
      final int sets = bundleQuantities[promo.id] ?? 0;
      if (!promo.isBundle || sets <= 0) {
        continue;
      }
      final StoreBundleQuote quoted = quoteBundle(
        promotion: promo,
        sets: sets,
        products: products,
        now: at,
      );
      bundleQuotes.add(quoted);
      bundleOriginal += quoted.originalTotal;
      bundleFinal += quoted.finalTotal;
    }

    final int productFinal =
        lockedAmount +
        cartLayer.finalStackable -
        (mix.promotion != null && !mix.promotion!.allowStack
            ? mix.discount
            : 0);
    final int finalSubtotal = productFinal + bundleFinal;

    return StoreCartQuote(
      lines: lines,
      originalSubtotal: originalSubtotal + bundleOriginal,
      itemDiscount: itemPromotionDiscount + campaignDiscount,
      itemPromotionDiscount: itemPromotionDiscount,
      campaignDiscount: campaignDiscount,
      quantityDiscount: cartLayer.quantityDiscount + mix.discount,
      amountDiscount: cartLayer.amountDiscount,
      finalSubtotal: finalSubtotal < 0 ? 0 : finalSubtotal,
      quantityPromotion: mix.promotion ?? cartLayer.quantityPromotion,
      amountPromotion: cartLayer.amountPromotion,
      bundleQuotes: bundleQuotes,
      bundleDiscount: bundleOriginal - bundleFinal,
      priceChanged:
          previousFinalSubtotal != null &&
          previousFinalSubtotal != finalSubtotal,
    );
  }

  StoreBundleQuote quoteBundle({
    required StorePromotionModel promotion,
    required int sets,
    required List<StoreProductModel> products,
    DateTime? now,
  }) {
    final DateTime at = now ?? DateTime.now();
    final Map<String, StoreProductModel> byId = <String, StoreProductModel>{
      for (final StoreProductModel item in products) item.id: item,
    };
    int original = 0;
    final List<String> labels = <String>[];
    for (final StoreBundleItem line in promotion.bundleItems) {
      final StoreProductModel? product = byId[line.productId];
      final int unit = product == null
          ? 0
          : (product.price < 0 ? 0 : product.price);
      original += unit * line.quantity * sets;
      labels.add('${product?.name ?? '商品'}×${line.quantity}');
    }
    final int bundlePrice = promotion.discountValue.round();
    int finalTotal = (bundlePrice < 0 ? 0 : bundlePrice) * sets;
    if (finalTotal > original) {
      finalTotal = original;
    }
    return StoreBundleQuote(
      promotion: promotion,
      sets: sets,
      originalTotal: original,
      finalTotal: finalTotal,
      soldOut: isBundleSoldOut(
        promotion: promotion,
        products: products,
        sets: sets,
        now: at,
      ),
      componentLabels: labels,
    );
  }

  int maxBundleSets({
    required StorePromotionModel promotion,
    required List<StoreProductModel> products,
  }) {
    if (promotion.bundleItems.isEmpty) {
      return 0;
    }
    final Map<String, StoreProductModel> byId = <String, StoreProductModel>{
      for (final StoreProductModel item in products) item.id: item,
    };
    int maxSets = 99;
    for (final StoreBundleItem line in promotion.bundleItems) {
      final StoreProductModel? product = byId[line.productId];
      if (product == null || !product.enabled || !product.hasInventoryLink) {
        return 0;
      }
      final int sellable = product.publicSellableQuantity < 0
          ? 0
          : product.publicSellableQuantity;
      final int perSet = line.quantity < 1 ? 1 : line.quantity;
      final int sets = sellable ~/ perSet;
      if (sets < maxSets) {
        maxSets = sets;
      }
    }
    return maxSets < 0 ? 0 : maxSets;
  }

  bool isBundleSoldOut({
    required StorePromotionModel promotion,
    required List<StoreProductModel> products,
    int sets = 1,
    DateTime? now,
  }) {
    return maxBundleSets(promotion: promotion, products: products) < sets;
  }

  StorePricedLine quoteProduct({
    required StoreProductModel product,
    int quantity = 1,
    required List<StorePromotionModel> promotions,
    DateTime? now,
  }) {
    final DateTime at = now ?? DateTime.now();
    final int purchase = quantity < 1 ? 1 : quantity;
    final int original = product.price < 0 ? 0 : product.price;
    final _LineChoice choice = _bestLineChoice(
      product: product,
      purchase: purchase,
      original: original,
      promotions: promotions,
      now: at,
    );

    return StorePricedLine(
      product: product,
      quantity: purchase,
      originalUnitPrice: original,
      finalUnitPrice: choice.paidUnit,
      promotion: choice.campaign,
      freeQuantity: choice.freeQuantity,
      fulfillmentQuantity: purchase + choice.freeQuantity,
      itemPromotionType: choice.itemPromotionType,
      itemPromotionName: choice.itemPromotionName,
      itemPromotionDiscount: choice.itemPromotionDiscount,
      campaignDiscount: choice.campaignDiscount,
      canStackFurther: choice.canStackFurther,
      appliedEndAt: choice.appliedEndAt,
    );
  }

  int applyDiscount({
    required int original,
    required String method,
    required num value,
  }) {
    int result = original;
    if (method == StoreDiscountMethods.percent ||
        method == StoreItemPromotionTypes.percent) {
      result = _roundMoney(original * (value / 10));
      if (value > 10) {
        result = _roundMoney(original * (value / 100));
      }
    } else if (method == StoreDiscountMethods.amountOff ||
        method == StoreItemPromotionTypes.amountOff) {
      result = original - value.round();
    } else if (method == StoreDiscountMethods.specialPrice ||
        method == StoreItemPromotionTypes.specialPrice) {
      result = value.round();
    }
    if (result < 0) {
      return 0;
    }
    return result;
  }

  int freeQuantityOf({
    required StoreProductModel product,
    required int purchaseQuantity,
    DateTime? now,
  }) {
    final DateTime at = now ?? DateTime.now();
    if (!product.isItemPromotionActiveAt(at) || !product.isBuyXGetY) {
      return 0;
    }
    final int buy = product.itemPromotionBuyQuantity < 1
        ? 1
        : product.itemPromotionBuyQuantity;
    final int free = product.itemPromotionFreeQuantity < 1
        ? 1
        : product.itemPromotionFreeQuantity;
    final int purchase = purchaseQuantity < 0 ? 0 : purchaseQuantity;
    return (purchase ~/ buy) * free;
  }

  int fulfillmentQuantityOf({
    required StoreProductModel product,
    required int purchaseQuantity,
    DateTime? now,
  }) {
    return purchaseQuantity +
        freeQuantityOf(
          product: product,
          purchaseQuantity: purchaseQuantity,
          now: now,
        );
  }

  int maxPurchaseForSellable({
    required StoreProductModel product,
    required int sellableUnits,
    DateTime? now,
  }) {
    if (sellableUnits <= 0) {
      return 0;
    }
    final DateTime at = now ?? DateTime.now();
    if (!product.isItemPromotionActiveAt(at) || !product.isBuyXGetY) {
      return sellableUnits;
    }
    int low = 0;
    int high = sellableUnits;
    int best = 0;
    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      final int fulfillment = fulfillmentQuantityOf(
        product: product,
        purchaseQuantity: mid,
        now: at,
      );
      if (fulfillment <= sellableUnits) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  String itemPromotionNameOf(StoreProductModel product, {DateTime? now}) {
    if (!product.isItemPromotionActiveAt(now ?? DateTime.now())) {
      return '';
    }
    return product.itemOfferLabel(now: now);
  }

  int applyItemUnitPrice({
    required StoreProductModel product,
    required int original,
    DateTime? now,
  }) {
    final DateTime at = now ?? DateTime.now();
    if (!product.isItemPromotionActiveAt(at)) {
      return original;
    }
    switch (product.itemPromotionType) {
      case StoreItemPromotionTypes.specialPrice:
        return applyDiscount(
          original: original,
          method: StoreDiscountMethods.specialPrice,
          value: product.itemPromotionValue,
        );
      case StoreItemPromotionTypes.percent:
        return applyDiscount(
          original: original,
          method: StoreDiscountMethods.percent,
          value: product.itemPromotionValue,
        );
      case StoreItemPromotionTypes.amountOff:
        return applyDiscount(
          original: original,
          method: StoreDiscountMethods.amountOff,
          value: product.itemPromotionValue,
        );
      default:
        return original;
    }
  }

  _LineChoice _bestLineChoice({
    required StoreProductModel product,
    required int purchase,
    required int original,
    required List<StorePromotionModel> promotions,
    required DateTime now,
  }) {
    final bool itemActive = product.isItemPromotionActiveAt(now);
    final int itemUnit = applyItemUnitPrice(
      product: product,
      original: original,
      now: now,
    );
    final int itemFree = freeQuantityOf(
      product: product,
      purchaseQuantity: purchase,
      now: now,
    );
    final String itemName = itemPromotionNameOf(product, now: now);
    final String itemType = itemActive
        ? product.itemPromotionType
        : StoreItemPromotionTypes.none;
    final DateTime? itemEnd = itemActive ? product.itemPromotionEndAt : null;
    final int itemDiscount = (original - itemUnit) * purchase;

    final List<_LineChoice> choices = <_LineChoice>[];
    if (itemActive) {
      choices.add(
        _LineChoice(
          paidUnit: itemUnit,
          freeQuantity: itemFree,
          itemPromotionType: itemType,
          itemPromotionName: itemName,
          itemPromotionDiscount: itemDiscount,
          campaignDiscount: 0,
          canStackFurther: product.itemPromotionAllowStack,
          appliedEndAt: itemEnd,
        ),
      );
    } else {
      choices.add(
        _LineChoice(
          paidUnit: original,
          freeQuantity: 0,
          itemPromotionType: StoreItemPromotionTypes.none,
          itemPromotionName: '',
          itemPromotionDiscount: 0,
          campaignDiscount: 0,
          canStackFurther: true,
          appliedEndAt: null,
        ),
      );
    }

    final List<StorePromotionModel> matching = promotions.where((
      StorePromotionModel promotion,
    ) {
      return promotion.isActiveAt(now) &&
          promotion.isItemLevel &&
          _matchesProduct(promotion, product);
    }).toList();

    final bool lockItemBogo =
        itemActive &&
        !product.itemPromotionAllowStack &&
        product.itemPromotionType == StoreItemPromotionTypes.buyXGetY;

    for (final StorePromotionModel campaign in matching) {
      if (lockItemBogo) {
        continue;
      }
      final int campaignUnit = applyDiscount(
        original: original,
        method: campaign.discountMethod,
        value: campaign.discountValue,
      );
      choices.add(
        _LineChoice(
          paidUnit: campaignUnit,
          freeQuantity: 0,
          itemPromotionType: StoreItemPromotionTypes.none,
          itemPromotionName: '',
          itemPromotionDiscount: 0,
          campaignDiscount: (original - campaignUnit) * purchase,
          canStackFurther: campaign.allowStack,
          campaign: campaign,
          appliedEndAt: campaign.endAt,
        ),
      );

      if (itemActive &&
          product.itemPromotionAllowStack &&
          campaign.allowStack) {
        final int stackedUnit = applyDiscount(
          original: itemUnit,
          method: campaign.discountMethod,
          value: campaign.discountValue,
        );
        choices.add(
          _LineChoice(
            paidUnit: stackedUnit,
            freeQuantity: itemFree,
            itemPromotionType: itemType,
            itemPromotionName: itemName,
            itemPromotionDiscount: itemDiscount,
            campaignDiscount: (itemUnit - stackedUnit) * purchase,
            canStackFurther: true,
            campaign: campaign,
            appliedEndAt: _earlierEnd(itemEnd, campaign.endAt),
          ),
        );
      }
    }

    _LineChoice best = choices.first;
    for (final _LineChoice choice in choices.skip(1)) {
      if (_isBetterChoice(choice, best, purchase: purchase)) {
        best = choice;
      }
    }
    return best;
  }

  bool _isBetterChoice(
    _LineChoice candidate,
    _LineChoice current, {
    required int purchase,
  }) {
    final int candidatePaid = candidate.paidUnit * purchase;
    final int currentPaid = current.paidUnit * purchase;
    if (candidatePaid != currentPaid) {
      return candidatePaid < currentPaid;
    }
    if (candidate.freeQuantity != current.freeQuantity) {
      return candidate.freeQuantity > current.freeQuantity;
    }
    return false;
  }

  DateTime? _earlierEnd(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isBefore(b) ? a : b;
  }

  bool _matchesProduct(
    StorePromotionModel promotion,
    StoreProductModel product,
  ) {
    if (promotion.type == StorePromotionTypes.storewide) {
      return true;
    }
    if (promotion.type == StorePromotionTypes.product) {
      return promotion.productIds.contains(product.id);
    }
    if (promotion.type == StorePromotionTypes.category) {
      return promotion.categoryId.trim().isNotEmpty &&
          promotion.categoryId == product.categoryId;
    }
    if (promotion.type == StorePromotionTypes.flash) {
      if (promotion.productIds.contains(product.id)) {
        return true;
      }
      if (promotion.categoryId.trim().isNotEmpty &&
          promotion.categoryId == product.categoryId) {
        return true;
      }
      return promotion.productIds.isEmpty &&
          promotion.categoryId.trim().isEmpty;
    }
    return false;
  }

  _MixMatchResult _quoteMixMatch({
    required List<StorePricedLine> lines,
    required List<StorePromotionModel> promotions,
  }) {
    _MixMatchResult best = const _MixMatchResult();
    for (final StorePromotionModel promo in promotions) {
      if (!promo.isMixMatch || promo.minimumQuantity <= 0) {
        continue;
      }
      final List<StorePricedLine> eligible = lines.where((
        StorePricedLine line,
      ) {
        return line.canStackFurther &&
            promo.productIds.contains(line.product.id);
      }).toList();
      final int qty = eligible.fold<int>(
        0,
        (int sum, StorePricedLine line) => sum + line.purchaseQuantity,
      );
      if (qty < promo.minimumQuantity) {
        continue;
      }
      final int eligibleAmount = eligible.fold<int>(
        0,
        (int sum, StorePricedLine line) => sum + line.finalSubtotal,
      );
      int discounted = eligibleAmount;
      if (promo.discountMethod == StoreDiscountMethods.specialPrice) {
        final int groups = qty ~/ promo.minimumQuantity;
        final int covered = groups * promo.minimumQuantity;
        final List<int> units = <int>[];
        for (final StorePricedLine line in eligible) {
          for (int i = 0; i < line.purchaseQuantity; i++) {
            units.add(line.finalUnitPrice);
          }
        }
        units.sort((int a, int b) => b.compareTo(a));
        int coveredSum = 0;
        int restSum = 0;
        for (int i = 0; i < units.length; i++) {
          if (i < covered) {
            coveredSum += units[i];
          } else {
            restSum += units[i];
          }
        }
        discounted = (groups * promo.discountValue.round()) + restSum;
        if (discounted > coveredSum + restSum) {
          discounted = coveredSum + restSum;
        }
      } else {
        discounted = applyDiscount(
          original: eligibleAmount,
          method: promo.discountMethod == StoreDiscountMethods.specialPrice
              ? StoreDiscountMethods.amountOff
              : promo.discountMethod,
          value: promo.discountValue,
        );
      }
      final int saving = eligibleAmount - discounted;
      if (saving > best.discount) {
        best = _MixMatchResult(
          discount: saving < 0 ? 0 : saving,
          promotion: promo,
          productIds: promo.productIds.toSet(),
        );
      }
    }
    return best;
  }

  _CartLayerResult _quoteCartLayers({
    required List<StorePromotionModel> promotions,
    required int stackableAmount,
    required int stackableQty,
  }) {
    if (stackableAmount <= 0) {
      return const _CartLayerResult();
    }

    final List<StorePromotionModel> qtyPromos = promotions.where((
      StorePromotionModel item,
    ) {
      return item.type == StorePromotionTypes.quantity &&
          item.minimumQuantity > 0 &&
          stackableQty >= item.minimumQuantity;
    }).toList();
    final List<StorePromotionModel> amountPromos = promotions.where((
      StorePromotionModel item,
    ) {
      return item.type == StorePromotionTypes.amount && item.minimumAmount > 0;
    }).toList();

    final _CartDiscount? qtyOnly = _bestCartDiscount(
      promotions: qtyPromos,
      currentSubtotal: stackableAmount,
    );
    final List<StorePromotionModel> amountOnBase = amountPromos
        .where(
          (StorePromotionModel item) => stackableAmount >= item.minimumAmount,
        )
        .toList();
    final _CartDiscount? amountOnly = _bestCartDiscount(
      promotions: amountOnBase,
      currentSubtotal: stackableAmount,
    );

    _CartDiscount? stackedAmount;
    if (qtyOnly != null && qtyOnly.promotion.allowStack) {
      final List<StorePromotionModel> amountAfterQty = amountPromos.where((
        StorePromotionModel item,
      ) {
        return item.allowStack && qtyOnly.finalAmount >= item.minimumAmount;
      }).toList();
      stackedAmount = _bestCartDiscount(
        promotions: amountAfterQty,
        currentSubtotal: qtyOnly.finalAmount,
      );
    }

    int bestAmount = stackableAmount;
    StorePromotionModel? qtyPromo;
    StorePromotionModel? amountPromo;
    int qtyDiscount = 0;
    int amountDiscount = 0;

    void consider({
      required int finalAmount,
      StorePromotionModel? quantity,
      StorePromotionModel? amount,
      required int nextQtyDiscount,
      required int nextAmountDiscount,
    }) {
      if (finalAmount < bestAmount) {
        bestAmount = finalAmount;
        qtyPromo = quantity;
        amountPromo = amount;
        qtyDiscount = nextQtyDiscount;
        amountDiscount = nextAmountDiscount;
      }
    }

    if (qtyOnly != null) {
      consider(
        finalAmount: qtyOnly.finalAmount,
        quantity: qtyOnly.promotion,
        amount: null,
        nextQtyDiscount: stackableAmount - qtyOnly.finalAmount,
        nextAmountDiscount: 0,
      );
    }
    if (amountOnly != null) {
      consider(
        finalAmount: amountOnly.finalAmount,
        quantity: null,
        amount: amountOnly.promotion,
        nextQtyDiscount: 0,
        nextAmountDiscount: stackableAmount - amountOnly.finalAmount,
      );
    }
    if (qtyOnly != null && stackedAmount != null) {
      consider(
        finalAmount: stackedAmount.finalAmount,
        quantity: qtyOnly.promotion,
        amount: stackedAmount.promotion,
        nextQtyDiscount: stackableAmount - qtyOnly.finalAmount,
        nextAmountDiscount: qtyOnly.finalAmount - stackedAmount.finalAmount,
      );
    }

    return _CartLayerResult(
      finalStackable: bestAmount,
      quantityDiscount: qtyDiscount,
      amountDiscount: amountDiscount,
      quantityPromotion: qtyPromo,
      amountPromotion: amountPromo,
    );
  }

  _CartDiscount? _bestCartDiscount({
    required List<StorePromotionModel> promotions,
    required int currentSubtotal,
  }) {
    _CartDiscount? best;
    for (final StorePromotionModel promotion in promotions) {
      final int priced = applyDiscount(
        original: currentSubtotal,
        method: promotion.discountMethod == StoreDiscountMethods.specialPrice
            ? StoreDiscountMethods.amountOff
            : promotion.discountMethod,
        value: promotion.discountValue,
      );
      if (best == null || priced < best.finalAmount) {
        best = _CartDiscount(promotion: promotion, finalAmount: priced);
      }
    }
    return best;
  }

  int _roundMoney(num value) {
    return value.round();
  }
}

class _LineChoice {
  const _LineChoice({
    required this.paidUnit,
    required this.freeQuantity,
    required this.itemPromotionType,
    required this.itemPromotionName,
    required this.itemPromotionDiscount,
    required this.campaignDiscount,
    required this.canStackFurther,
    this.campaign,
    this.appliedEndAt,
  });

  final int paidUnit;
  final int freeQuantity;
  final String itemPromotionType;
  final String itemPromotionName;
  final int itemPromotionDiscount;
  final int campaignDiscount;
  final bool canStackFurther;
  final StorePromotionModel? campaign;
  final DateTime? appliedEndAt;
}

class _MixMatchResult {
  const _MixMatchResult({
    this.discount = 0,
    this.promotion,
    this.productIds = const <String>{},
  });

  final int discount;
  final StorePromotionModel? promotion;
  final Set<String> productIds;
}

class _CartDiscount {
  const _CartDiscount({required this.promotion, required this.finalAmount});

  final StorePromotionModel promotion;
  final int finalAmount;
}

class _CartLayerResult {
  const _CartLayerResult({
    this.finalStackable = 0,
    this.quantityDiscount = 0,
    this.amountDiscount = 0,
    this.quantityPromotion,
    this.amountPromotion,
  });

  final int finalStackable;
  final int quantityDiscount;
  final int amountDiscount;
  final StorePromotionModel? quantityPromotion;
  final StorePromotionModel? amountPromotion;
}
