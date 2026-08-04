// lib/core/models/point_exchange_model.dart
// 🪙 點數兌換商品 Model
// 功能：店主設定會員可使用點數兌換的商品

import 'package:cloud_firestore/cloud_firestore.dart';

class PointExchangeModel {
  const PointExchangeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.couponId,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// 顯示名稱
  final String title;

  /// 說明
  final String description;

  /// 需要點數
  final int pointsRequired;

  /// 對應優惠券
  final String couponId;

  /// 是否啟用
  final bool enabled;

  /// 排序
  final int sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory PointExchangeModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return PointExchangeModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      pointsRequired: (data['pointsRequired'] ?? 0) as int,
      couponId: data['couponId'] ?? '',
      enabled: data['enabled'] ?? true,
      sortOrder: (data['sortOrder'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'pointsRequired': pointsRequired,
      'couponId': couponId,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
