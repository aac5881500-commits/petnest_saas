// lib/core/models/member_point_model.dart
// 🪙 會員點數資料模型
// 功能：記錄會員在指定店家的目前點數、累積獲得、使用與過期點數

import 'package:cloud_firestore/cloud_firestore.dart';

class MemberPointModel {
  const MemberPointModel({
    required this.shopId,
    required this.userId,
    required this.currentPoints,
    required this.totalEarnedPoints,
    required this.totalUsedPoints,
    required this.totalExpiredPoints,
    required this.createdAt,
    required this.updatedAt,
    this.lastEarnedAt,
    this.lastUsedAt,
    this.lastExpiredAt,
  });

  /// 所屬店家 ID
  final String shopId;

  /// 會員 UID
  final String userId;

  /// 目前可使用點數
  final int currentPoints;

  /// 歷史累積獲得點數
  final int totalEarnedPoints;

  /// 歷史累積使用點數
  final int totalUsedPoints;

  /// 歷史累積過期點數
  final int totalExpiredPoints;

  /// 最近一次獲得點數時間
  final DateTime? lastEarnedAt;

  /// 最近一次使用點數時間
  final DateTime? lastUsedAt;

  /// 最近一次點數過期時間
  final DateTime? lastExpiredAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否還有可使用點數
  bool get hasPoints => currentPoints > 0;

  /// 是否足夠兌換指定點數商品
  bool hasEnoughPoints(int requiredPoints) {
    if (requiredPoints <= 0) {
      return true;
    }

    return currentPoints >= requiredPoints;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'userId': userId,
      'currentPoints': currentPoints,
      'totalEarnedPoints': totalEarnedPoints,
      'totalUsedPoints': totalUsedPoints,
      'totalExpiredPoints': totalExpiredPoints,
      'lastEarnedAt': lastEarnedAt == null
          ? null
          : Timestamp.fromDate(lastEarnedAt!),
      'lastUsedAt': lastUsedAt == null ? null : Timestamp.fromDate(lastUsedAt!),
      'lastExpiredAt': lastExpiredAt == null
          ? null
          : Timestamp.fromDate(lastExpiredAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MemberPointModel.fromMap({
    required String shopId,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return MemberPointModel(
      shopId: (data['shopId'] ?? shopId).toString(),
      userId: (data['userId'] ?? userId).toString(),
      currentPoints: _intFromValue(data['currentPoints']),
      totalEarnedPoints: _intFromValue(data['totalEarnedPoints']),
      totalUsedPoints: _intFromValue(data['totalUsedPoints']),
      totalExpiredPoints: _intFromValue(data['totalExpiredPoints']),
      lastEarnedAt: _dateTimeFromValue(data['lastEarnedAt']),
      lastUsedAt: _dateTimeFromValue(data['lastUsedAt']),
      lastExpiredAt: _dateTimeFromValue(data['lastExpiredAt']),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  factory MemberPointModel.empty({
    required String shopId,
    required String userId,
  }) {
    final DateTime now = DateTime.now();

    return MemberPointModel(
      shopId: shopId,
      userId: userId,
      currentPoints: 0,
      totalEarnedPoints: 0,
      totalUsedPoints: 0,
      totalExpiredPoints: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  MemberPointModel copyWith({
    String? shopId,
    String? userId,
    int? currentPoints,
    int? totalEarnedPoints,
    int? totalUsedPoints,
    int? totalExpiredPoints,
    DateTime? lastEarnedAt,
    DateTime? lastUsedAt,
    DateTime? lastExpiredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLastEarnedAt = false,
    bool clearLastUsedAt = false,
    bool clearLastExpiredAt = false,
  }) {
    return MemberPointModel(
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      currentPoints: currentPoints ?? this.currentPoints,
      totalEarnedPoints: totalEarnedPoints ?? this.totalEarnedPoints,
      totalUsedPoints: totalUsedPoints ?? this.totalUsedPoints,
      totalExpiredPoints: totalExpiredPoints ?? this.totalExpiredPoints,
      lastEarnedAt: clearLastEarnedAt
          ? null
          : lastEarnedAt ?? this.lastEarnedAt,
      lastUsedAt: clearLastUsedAt ? null : lastUsedAt ?? this.lastUsedAt,
      lastExpiredAt: clearLastExpiredAt
          ? null
          : lastExpiredAt ?? this.lastExpiredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

int _intFromValue(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
