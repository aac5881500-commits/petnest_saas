// 檔案名稱：lib/core/models/store_promotion_model.dart
// 功能說明：商城專用促銷活動
// 與住宿優惠 / 優惠券 / 特殊日期加價完全分開。

import 'package:cloud_firestore/cloud_firestore.dart';

class StoreBundleItem {
  const StoreBundleItem({required this.productId, this.quantity = 1});

  final String productId;
  final int quantity;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity < 1 ? 1 : quantity,
    };
  }

  factory StoreBundleItem.fromMap(Map<String, dynamic> data) {
    final int qty = data['quantity'] is int
        ? data['quantity'] as int
        : int.tryParse(data['quantity']?.toString() ?? '') ?? 1;
    return StoreBundleItem(
      productId: (data['productId'] ?? '').toString().trim(),
      quantity: qty < 1 ? 1 : qty,
    );
  }
}

class StorePromotionTypes {
  static const String bundle = 'bundle';
  static const String product = 'product';
  static const String category = 'category';
  static const String amount = 'amount';
  static const String quantity = 'quantity';
  static const String storewide = 'storewide';
  static const String flash = 'flash';

  static const List<String> selectable = <String>[
    bundle,
    quantity,
    category,
    amount,
  ];

  static String label(String type) {
    switch (type) {
      case bundle:
        return '套裝優惠';
      case product:
        return '多商品優惠（舊）';
      case category:
        return '分類優惠';
      case amount:
        return '滿額優惠';
      case quantity:
        return '多件優惠';
      case storewide:
        return '全館優惠（舊）';
      case flash:
        return '限時跨商品活動（舊）';
      default:
        return type;
    }
  }

  static String description(String type) {
    switch (type) {
      case bundle:
        return '多個指定商品組合成優惠價格\n例如：罐頭 + 零食 NT\$199';
      case quantity:
        return '指定商品任選達到件數享優惠\n例如：任選 3 件 9 折';
      case category:
        return '某個商品分類統一優惠\n例如：罐頭類全館 9 折';
      case amount:
        return '購物車金額達標享優惠\n例如：滿 NT\$1000 折 NT\$100';
      default:
        return '';
    }
  }

  static String normalize(dynamic value) {
    final String type = (value ?? category).toString().trim();
    if (type == bundle ||
        type == flash ||
        type == product ||
        type == category ||
        type == amount ||
        type == quantity ||
        type == storewide) {
      return type;
    }
    return category;
  }
}

class StoreDiscountMethods {
  static const String percent = 'percent';
  static const String amountOff = 'amountOff';
  static const String specialPrice = 'specialPrice';

  static const List<String> all = <String>[percent, amountOff, specialPrice];

  static String label(String method) {
    switch (method) {
      case percent:
        return '打折';
      case amountOff:
        return '固定減價';
      case specialPrice:
        return '特價';
      default:
        return method;
    }
  }
}

class StorePromotionModel {
  const StorePromotionModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.type,
    required this.discountMethod,
    required this.discountValue,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.productIds = const <String>[],
    this.bundleItems = const <StoreBundleItem>[],
    this.categoryId = '',
    this.minimumAmount = 0,
    this.minimumQuantity = 0,
    this.startAt,
    this.endAt,
    this.priority = 0,
    this.allowStack = false,
    this.archived = false,
    this.usedOrderCount = 0,
  });

  final String id;
  final String shopId;
  final String name;
  final String description;
  final String type;
  final String discountMethod;
  final num discountValue;
  final List<String> productIds;
  final List<StoreBundleItem> bundleItems;
  final String categoryId;
  final int minimumAmount;
  final int minimumQuantity;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool enabled;
  final bool archived;
  final bool allowStack;
  final int priority;
  final int usedOrderCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get activityId => id;

  bool get isItemLevel =>
      type == StorePromotionTypes.product ||
      type == StorePromotionTypes.category ||
      type == StorePromotionTypes.storewide ||
      type == StorePromotionTypes.flash;

  bool get isCartLevel =>
      type == StorePromotionTypes.amount ||
      type == StorePromotionTypes.quantity;

  bool get isBundle => type == StorePromotionTypes.bundle;

  bool get isMixMatch =>
      type == StorePromotionTypes.quantity && productIds.isNotEmpty;

  bool isActiveAt(DateTime now) {
    if (!enabled || archived) {
      return false;
    }
    if (startAt != null && now.isBefore(startAt!)) {
      return false;
    }
    if (endAt != null && now.isAfter(endAt!)) {
      return false;
    }
    return true;
  }

  String get statusKey {
    if (archived || !enabled) {
      return 'disabled';
    }
    final DateTime now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) {
      return 'upcoming';
    }
    if (endAt != null && now.isAfter(endAt!)) {
      return 'ended';
    }
    return 'active';
  }

  String get statusLabel {
    switch (statusKey) {
      case 'disabled':
        return '已停用';
      case 'upcoming':
        return '即將開始';
      case 'ended':
        return '已結束';
      default:
        return '活動中';
    }
  }

  String get offerLabel {
    if (discountMethod == StoreDiscountMethods.percent) {
      final num value = discountValue;
      if (value <= 10) {
        return '${value.toString().replaceAll(RegExp(r'\.0$'), '')} 折';
      }
      return '${value.round()} 折';
    }
    if (discountMethod == StoreDiscountMethods.amountOff) {
      return '減 NT\$${discountValue.round()}';
    }
    if (discountMethod == StoreDiscountMethods.specialPrice) {
      return '特價 NT\$${discountValue.round()}';
    }
    return StoreDiscountMethods.label(discountMethod);
  }

  String get offerDetail {
    if (type == StorePromotionTypes.amount) {
      return '滿 NT\$$minimumAmount $offerLabel';
    }
    if (type == StorePromotionTypes.quantity) {
      if (discountMethod == StoreDiscountMethods.specialPrice) {
        return '任選 $minimumQuantity 件 NT\$${discountValue.round()}';
      }
      return '任選 $minimumQuantity 件 $offerLabel';
    }
    if (type == StorePromotionTypes.bundle) {
      return '套裝價 NT\$${discountValue.round()}';
    }
    return offerLabel;
  }

  String contentsLabel(Map<String, String> productNames) {
    if (isBundle) {
      if (bundleItems.isEmpty) {
        return '尚未選擇商品';
      }
      return bundleItems
          .map((StoreBundleItem item) {
            final String name = productNames[item.productId] ?? '商品';
            return '$name×${item.quantity}';
          })
          .join(' + ');
    }
    if (isMixMatch) {
      return '指定 ${productIds.length} 款任選 $minimumQuantity 件';
    }
    return scopeLabel;
  }

  int bundleOriginalOf(Map<String, int> productPrices) {
    return bundleItems.fold<int>(0, (int sum, StoreBundleItem item) {
      return sum + (productPrices[item.productId] ?? 0) * item.quantity;
    });
  }

  String get bannerSubtitle {
    if (isBundle) {
      return '套裝$offerLabel　立即選購 →';
    }
    if (isMixMatch || type == StorePromotionTypes.quantity) {
      return '$offerDetail　立即選購 →';
    }
    if (type == StorePromotionTypes.category) {
      return '分類$offerLabel　立即選購 →';
    }
    if (type == StorePromotionTypes.amount) {
      return '$offerDetail　立即選購 →';
    }
    return offerDetail;
  }

  String get periodLabel {
    if (startAt == null && endAt == null) {
      return '不限期間';
    }
    return '${_short(startAt) ?? '即日起'} ～ ${_short(endAt) ?? '不限'}';
  }

  static String? _short(DateTime? value) {
    if (value == null) {
      return null;
    }
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String get scopeLabel {
    switch (type) {
      case StorePromotionTypes.product:
      case StorePromotionTypes.flash:
        if (categoryId.trim().isNotEmpty && productIds.isEmpty) {
          return '分類';
        }
        return productIds.isEmpty ? '指定商品' : '${productIds.length} 件商品';
      case StorePromotionTypes.category:
        return '分類';
      case StorePromotionTypes.bundle:
        return bundleItems.isEmpty
            ? '套裝'
            : bundleItems
                  .map((StoreBundleItem item) => '×${item.quantity}')
                  .join(' + ');
      case StorePromotionTypes.storewide:
        return '全館';
      case StorePromotionTypes.amount:
        return '滿 NT\$$minimumAmount';
      case StorePromotionTypes.quantity:
        return productIds.isEmpty
            ? '滿 $minimumQuantity 件'
            : '指定 ${productIds.length} 件商品任選 $minimumQuantity';
      default:
        return '';
    }
  }

  factory StorePromotionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final Object? rawIds = data['productIds'];
    final List<String> productIds = rawIds is List
        ? rawIds.map((Object? item) => item.toString().trim()).where((
            String id,
          ) {
            return id.isNotEmpty;
          }).toList()
        : <String>[];
    final Object? rawBundle = data['bundleItems'];
    final List<StoreBundleItem> bundleItems = rawBundle is List
        ? rawBundle
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> item) =>
                    StoreBundleItem.fromMap(Map<String, dynamic>.from(item)),
              )
              .where((StoreBundleItem item) => item.productId.isNotEmpty)
              .toList()
        : <StoreBundleItem>[];

    return StorePromotionModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      type: StorePromotionTypes.normalize(data['type']),
      discountMethod: (data['discountMethod'] ?? StoreDiscountMethods.percent)
          .toString(),
      discountValue: _numFromValue(data['discountValue']),
      productIds: productIds.isEmpty
          ? bundleItems.map((StoreBundleItem item) => item.productId).toList()
          : productIds,
      bundleItems: bundleItems,
      categoryId: (data['categoryId'] ?? '').toString(),
      minimumAmount: _intFromValue(data['minimumAmount']),
      minimumQuantity: _intFromValue(data['minimumQuantity']),
      startAt: _dateFromValue(data['startAt']),
      endAt: _dateFromValue(data['endAt']),
      enabled: data['enabled'] != false,
      archived: data['archived'] == true,
      allowStack: data['allowStack'] == true,
      priority: _intFromValue(data['priority']),
      usedOrderCount: _intFromValue(data['usedOrderCount']),
      createdAt: _dateFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'type': type,
      'discountMethod': discountMethod,
      'discountValue': discountValue,
      'productIds': productIds.isEmpty
          ? bundleItems.map((StoreBundleItem item) => item.productId).toList()
          : productIds,
      'bundleItems': bundleItems
          .map((StoreBundleItem item) => item.toMap())
          .toList(),
      'categoryId': categoryId.trim(),
      'minimumAmount': minimumAmount,
      'minimumQuantity': minimumQuantity,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'enabled': enabled,
      'archived': archived,
      'allowStack': allowStack,
      'priority': priority,
      'usedOrderCount': usedOrderCount,
    };
  }

  int get bundlePieceCount {
    return bundleItems.fold<int>(0, (int sum, StoreBundleItem item) {
      return sum + item.quantity;
    });
  }

  StorePromotionModel copyWith({
    String? id,
    String? name,
    bool? enabled,
    bool? archived,
    DateTime? startAt,
    DateTime? endAt,
    List<StoreBundleItem>? bundleItems,
    int? usedOrderCount,
  }) {
    return StorePromotionModel(
      id: id ?? this.id,
      shopId: shopId,
      name: name ?? this.name,
      description: description,
      type: type,
      discountMethod: discountMethod,
      discountValue: discountValue,
      productIds: productIds,
      bundleItems: bundleItems ?? this.bundleItems,
      categoryId: categoryId,
      minimumAmount: minimumAmount,
      minimumQuantity: minimumQuantity,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      enabled: enabled ?? this.enabled,
      archived: archived ?? this.archived,
      allowStack: allowStack,
      priority: priority,
      usedOrderCount: usedOrderCount ?? this.usedOrderCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static num _numFromValue(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
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

  static DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
