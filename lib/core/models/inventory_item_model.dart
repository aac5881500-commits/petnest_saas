// 檔案名稱：lib/core/models/inventory_item_model.dart
// 功能說明：保存每個店家獨立的庫存品項主檔。數量使用 num，可支援 0.5 包貓砂這類小數耗材。
// 📦 中央庫存品項 Model
// currentStock 不可在一般編輯頁直接覆蓋，只能透過進貨、出庫、盤點與自動扣庫存異動。
// estimatedStockCost 是獨立累計的庫存總成本，不可用四捨五入後的 weightedAverageCost × 數量回推。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';

class InventoryItemModel {
  const InventoryItemModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.currentStock,
    required this.safetyStock,
    required this.allowDecimal,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.category = '',
    this.sku = '',
    this.barcode = '',
    this.unit = '個',
    this.lastPurchaseUnitCost = 0,
    this.weightedAverageCost = 0,
    this.estimatedStockCost = 0,
    this.nearestExpiryDate,
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.reservedQuantity = 0,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final String id;
  final String shopId;
  final String name;
  final String description;
  final String category;
  final String sku;
  final String barcode;
  final String unit;
  final num currentStock;
  final num safetyStock;
  final bool allowDecimal;
  final bool enabled;
  final num lastPurchaseUnitCost;
  final num weightedAverageCost;
  final num estimatedStockCost;
  final DateTime? nearestExpiryDate;
  final String imageUrl;
  final String imageStoragePath;
  final num reservedQuantity;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryStockStatus get stockStatus {
    if (!enabled) {
      return InventoryStockStatus.disabled;
    }

    if (currentStock <= 0) {
      return InventoryStockStatus.outOfStock;
    }

    if (safetyStock > 0 && currentStock <= safetyStock) {
      return InventoryStockStatus.low;
    }

    return InventoryStockStatus.normal;
  }

  bool get hasCoverImage => imageUrl.trim().isNotEmpty;

  num get availableStock {
    final num available = currentStock - reservedQuantity;
    return available < 0 ? 0 : available;
  }

  bool get isExpiringSoon {
    final DateTime? expiry = nearestExpiryDate;
    if (expiry == null || currentStock <= 0) {
      return false;
    }

    final DateTime limit = DateTime.now().add(
      const Duration(days: InventoryConstants.expiryWarningDays),
    );

    return !expiry.isAfter(limit);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'sku': sku.trim(),
      'barcode': barcode.trim(),
      'unit': unit.trim().isEmpty ? '個' : unit.trim(),
      'currentStock': currentStock,
      'safetyStock': safetyStock,
      'allowDecimal': allowDecimal,
      'enabled': enabled,
      'lastPurchaseUnitCost': lastPurchaseUnitCost,
      'weightedAverageCost': weightedAverageCost,
      'estimatedStockCost': estimatedStockCost,
      'nearestExpiryDate': nearestExpiryDate == null
          ? null
          : Timestamp.fromDate(nearestExpiryDate!),
      'imageUrl': imageUrl.trim(),
      'imageStoragePath': imageStoragePath.trim(),
      'reservedQuantity': reservedQuantity,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory InventoryItemModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return InventoryItemModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      sku: (data['sku'] ?? '').toString(),
      barcode: (data['barcode'] ?? '').toString(),
      unit: (data['unit'] ?? '個').toString().trim().isEmpty
          ? '個'
          : (data['unit'] ?? '個').toString(),
      currentStock: _numFromValue(data['currentStock']),
      safetyStock: _numFromValue(data['safetyStock']),
      allowDecimal: data['allowDecimal'] == true,
      enabled: data['enabled'] != false,
      lastPurchaseUnitCost: _numFromValue(data['lastPurchaseUnitCost']),
      weightedAverageCost: _numFromValue(data['weightedAverageCost']),
      estimatedStockCost: _numFromValue(data['estimatedStockCost']),
      nearestExpiryDate: _dateTimeFromValue(data['nearestExpiryDate']),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageStoragePath: (data['imageStoragePath'] ?? '').toString(),
      reservedQuantity: _numFromValue(data['reservedQuantity']),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  InventoryItemModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    String? category,
    String? sku,
    String? barcode,
    String? unit,
    num? currentStock,
    num? safetyStock,
    bool? allowDecimal,
    bool? enabled,
    num? lastPurchaseUnitCost,
    num? weightedAverageCost,
    num? estimatedStockCost,
    DateTime? nearestExpiryDate,
    bool clearNearestExpiryDate = false,
    String? imageUrl,
    String? imageStoragePath,
    num? reservedQuantity,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      safetyStock: safetyStock ?? this.safetyStock,
      allowDecimal: allowDecimal ?? this.allowDecimal,
      enabled: enabled ?? this.enabled,
      lastPurchaseUnitCost: lastPurchaseUnitCost ?? this.lastPurchaseUnitCost,
      weightedAverageCost: weightedAverageCost ?? this.weightedAverageCost,
      estimatedStockCost: estimatedStockCost ?? this.estimatedStockCost,
      nearestExpiryDate: clearNearestExpiryDate
          ? null
          : nearestExpiryDate ?? this.nearestExpiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

num _numFromValue(dynamic value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
