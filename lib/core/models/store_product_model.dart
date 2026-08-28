// lib/core/models/store_product_model.dart
// 🛒 商城商品 Model
// 功能：店家賣場商品主檔。可選擇不管理庫存，或綁定一個中央庫存品項。

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

  bool get hasCoverImage => imageUrl.trim().isNotEmpty;

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
      inventoryItemNameSnapshot:
          (data['inventoryItemNameSnapshot'] ?? '').toString(),
      inventoryUnitSnapshot: (data['inventoryUnitSnapshot'] ?? '').toString(),
      inventoryQuantityPerSale: _numFromValue(data['inventoryQuantityPerSale']),
      publicStockStatus: _stockStatusFromValue(data['publicStockStatus']),
      publicSellableQuantity: _intFromValue(data['publicSellableQuantity']),
      sortOrder: _intFromValue(data['sortOrder']),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
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
