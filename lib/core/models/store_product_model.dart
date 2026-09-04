// lib/core/models/store_product_model.dart
// 🛒 商城商品 Model
// 功能：店家賣場呈現主檔。新商品必須綁定一個中央庫存品項；舊的未連庫存資料仍可解析。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

class StoreProductModel {
  const StoreProductModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    required this.enabled,
    required this.featured,
    required this.useInventory,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.categoryId = '',
    this.categoryNameSnapshot = '',
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.inventoryItemId = '',
    this.inventoryItemNameSnapshot = '',
    this.inventoryUnitSnapshot = '',
    this.inventoryQuantityPerSale = 1,
    this.publicStockStatus = StoreConstants.stockUnlimited,
    this.publicSellableQuantity = 0,
    this.createdBy = '',
    this.updatedBy = '',
    this.itemPromotionEnabled = false,
    this.itemPromotionType = StoreItemPromotionTypes.none,
    this.itemPromotionValue = 0,
    this.itemPromotionBuyQuantity = 1,
    this.itemPromotionFreeQuantity = 1,
    this.itemPromotionAllowStack = false,
    this.itemPromotionStartAt,
    this.itemPromotionEndAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String description;
  final String categoryId;
  final String categoryNameSnapshot;
  final String imageUrl;
  final String imageStoragePath;
  final int price;
  final bool enabled;
  final bool featured;
  final bool useInventory;
  final String inventoryItemId;
  final String inventoryItemNameSnapshot;
  final String inventoryUnitSnapshot;
  final num inventoryQuantityPerSale;
  final String publicStockStatus;
  final int publicSellableQuantity;
  final int sortOrder;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool itemPromotionEnabled;
  final String itemPromotionType;
  final num itemPromotionValue;
  final int itemPromotionBuyQuantity;
  final int itemPromotionFreeQuantity;
  final bool itemPromotionAllowStack;
  final DateTime? itemPromotionStartAt;
  final DateTime? itemPromotionEndAt;

  bool get hasCoverImage => imageUrl.trim().isNotEmpty;

  /// 是否已綁定中央庫存。舊資料可能為空，前台不可販售。
  bool get hasInventoryLink => inventoryItemId.trim().isNotEmpty;

  bool isItemPromotionActiveAt(DateTime now) {
    if (!itemPromotionEnabled) {
      return false;
    }
    if (itemPromotionType == StoreItemPromotionTypes.none) {
      return false;
    }
    if (itemPromotionStartAt != null && now.isBefore(itemPromotionStartAt!)) {
      return false;
    }
    if (itemPromotionEndAt != null && now.isAfter(itemPromotionEndAt!)) {
      return false;
    }
    return true;
  }

  bool get isBuyXGetY => itemPromotionType == StoreItemPromotionTypes.buyXGetY;

  String itemOfferLabel({DateTime? now}) {
    if (!isItemPromotionActiveAt(now ?? DateTime.now()) &&
        !itemPromotionEnabled) {
      return '';
    }
    switch (itemPromotionType) {
      case StoreItemPromotionTypes.specialPrice:
        return '特價 NT\$${itemPromotionValue.round()}';
      case StoreItemPromotionTypes.percent:
        return StoreItemPromotionTypes.percentLabel(itemPromotionValue);
      case StoreItemPromotionTypes.amountOff:
        return '每件折 NT\$${itemPromotionValue.round()}';
      case StoreItemPromotionTypes.buyXGetY:
        return '買$itemPromotionBuyQuantity送$itemPromotionFreeQuantity';
      default:
        return '';
    }
  }

  String itemOfferBadge({DateTime? now}) {
    if (!isItemPromotionActiveAt(now ?? DateTime.now()) &&
        !itemPromotionEnabled) {
      return '';
    }
    switch (itemPromotionType) {
      case StoreItemPromotionTypes.specialPrice:
        return '特價';
      case StoreItemPromotionTypes.percent:
        return StoreItemPromotionTypes.percentLabel(itemPromotionValue);
      case StoreItemPromotionTypes.amountOff:
        return '減價';
      case StoreItemPromotionTypes.buyXGetY:
        return '買$itemPromotionBuyQuantity送$itemPromotionFreeQuantity';
      default:
        return '';
    }
  }

  factory StoreProductModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return StoreProductModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? '').toString(),
      categoryNameSnapshot: (data['categoryNameSnapshot'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageStoragePath: (data['imageStoragePath'] ?? '').toString(),
      price: _intFromValue(data['price']),
      enabled: data['enabled'] != false,
      featured: data['featured'] == true,
      useInventory: data['useInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemNameSnapshot: (data['inventoryItemNameSnapshot'] ?? '')
          .toString(),
      inventoryUnitSnapshot: (data['inventoryUnitSnapshot'] ?? '').toString(),
      inventoryQuantityPerSale: _numFromValue(data['inventoryQuantityPerSale']),
      publicStockStatus: _stockStatusFromValue(data['publicStockStatus']),
      publicSellableQuantity: _intFromValue(data['publicSellableQuantity']),
      sortOrder: _intFromValue(data['sortOrder']),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
      itemPromotionEnabled: data['itemPromotionEnabled'] == true,
      itemPromotionType: StoreItemPromotionTypes.normalize(
        data['itemPromotionType'],
      ),
      itemPromotionValue: _optionalNumFromValue(data['itemPromotionValue']),
      itemPromotionBuyQuantity: _intFromValue(
        data['itemPromotionBuyQuantity'],
      ).clamp(1, 99),
      itemPromotionFreeQuantity: _intFromValue(
        data['itemPromotionFreeQuantity'],
      ).clamp(1, 99),
      itemPromotionAllowStack: data['itemPromotionAllowStack'] == true,
      itemPromotionStartAt: _dateTimeFromValue(data['itemPromotionStartAt']),
      itemPromotionEndAt: _dateTimeFromValue(data['itemPromotionEndAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'description': description.trim(),
      'categoryId': categoryId.trim(),
      'categoryNameSnapshot': categoryNameSnapshot.trim(),
      'imageUrl': imageUrl.trim(),
      'imageStoragePath': imageStoragePath.trim(),
      'price': price,
      'enabled': enabled,
      'featured': featured,
      'useInventory': useInventory,
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemNameSnapshot': inventoryItemNameSnapshot.trim(),
      'inventoryUnitSnapshot': inventoryUnitSnapshot.trim(),
      'inventoryQuantityPerSale': inventoryQuantityPerSale <= 0
          ? 1
          : inventoryQuantityPerSale,
      'publicStockStatus': publicStockStatus,
      'publicSellableQuantity': publicSellableQuantity < 0
          ? 0
          : publicSellableQuantity,
      'sortOrder': sortOrder,
      'itemPromotionEnabled': itemPromotionEnabled,
      'itemPromotionType': itemPromotionType,
      'itemPromotionValue': itemPromotionValue,
      'itemPromotionBuyQuantity': itemPromotionBuyQuantity < 1
          ? 1
          : itemPromotionBuyQuantity,
      'itemPromotionFreeQuantity': itemPromotionFreeQuantity < 1
          ? 1
          : itemPromotionFreeQuantity,
      'itemPromotionAllowStack': itemPromotionAllowStack,
      'itemPromotionStartAt': itemPromotionStartAt == null
          ? null
          : Timestamp.fromDate(itemPromotionStartAt!),
      'itemPromotionEndAt': itemPromotionEndAt == null
          ? null
          : Timestamp.fromDate(itemPromotionEndAt!),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static String _stockStatusFromValue(dynamic value) {
    final String status = (value ?? '').toString().trim();
    if (status == StoreConstants.stockInStock ||
        status == StoreConstants.stockLow ||
        status == StoreConstants.stockOutOfStock ||
        status == StoreConstants.stockUnlimited) {
      return status;
    }
    return StoreConstants.stockUnlimited;
  }

  static int _intFromValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static num _numFromValue(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 1;
  }

  static num _optionalNumFromValue(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class StoreItemPromotionTypes {
  static const String none = 'none';
  static const String specialPrice = 'special_price';
  static const String percent = 'percent';
  static const String amountOff = 'amount_off';
  static const String buyXGetY = 'buy_x_get_y';
  static const String nthDiscount = 'nth_discount';

  static const List<String> v1 = <String>[
    none,
    specialPrice,
    percent,
    amountOff,
    buyXGetY,
  ];

  static const List<String> selectable = <String>[
    specialPrice,
    percent,
    buyXGetY,
  ];

  static String label(String type) {
    switch (type) {
      case specialPrice:
        return '特價';
      case percent:
        return '打折';
      case amountOff:
        return '固定減價';
      case buyXGetY:
        return '買X送Y';
      case nthDiscount:
        return '第N件折扣';
      default:
        return '無優惠';
    }
  }

  static String percentLabel(num value) {
    if (value <= 10) {
      return '${value.toString().replaceAll(RegExp(r'\.0$'), '')}折';
    }
    return '${value.round()}折';
  }

  static String normalize(dynamic value) {
    final String type = (value ?? none).toString().trim();
    if (v1.contains(type) || type == nthDiscount) {
      return type;
    }
    return none;
  }
}
