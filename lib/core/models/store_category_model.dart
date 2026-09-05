// 檔案名稱：lib/core/models/store_category_model.dart
// 功能說明：商城分類 Model

import 'package:cloud_firestore/cloud_firestore.dart';

class StoreCategoryModel {
  const StoreCategoryModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String shopId;
  final String name;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StoreCategoryModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return StoreCategoryModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      enabled: data['enabled'] != false,
      sortOrder: data['sortOrder'] is int
          ? data['sortOrder'] as int
          : int.tryParse(data['sortOrder']?.toString() ?? '') ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
