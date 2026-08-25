// lib/core/models/special_date_surcharge_model.dart
// 📅 特殊日期加價資料模型
// 功能：定義店家在春節、連假、跨年等指定住宿日期的每晚固定加價設定。

import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialDateSurchargeModel {
  const SpecialDateSurchargeModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.amountPerNight,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.createdBy = '',
    this.allowCampaignDiscount = true,
    this.allowCoupon = true,
    this.roomTypeIds = const <String>[],
  });

  final String id;
  final String shopId;

  /// 例如：春節加價、跨年加價
  final String name;

  /// 店主自行填寫的補充說明
  final String description;

  /// 加價適用的住宿開始日
  final DateTime startDate;

  /// 加價適用的住宿結束日
  ///
  /// 此日期代表「最後一個會被加價的住宿夜」。
  final DateTime endDate;

  /// 每一晚固定增加的金額
  ///
  /// 例如 500：
  /// 符合日期的每一住宿晚增加 NT$500。
  final int amountPerNight;

  /// 是否啟用
  final bool enabled;

  /// 是否允許同時套用其他自動優惠活動 Campaign
  final bool allowCampaignDiscount;

  /// 是否允許使用優惠券
  final bool allowCoupon;

  /// 指定適用房型 ID。
  /// 空陣列代表所有房型都適用。
  final List<String> roomTypeIds;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 指定住宿日期是否落在加價範圍內
  bool appliesToDate(DateTime date) {
    final DateTime target = DateTime(date.year, date.month, date.day);

    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);

    return !target.isBefore(start) && !target.isAfter(end);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'amountPerNight': amountPerNight,
      'enabled': enabled,
      'allowCampaignDiscount': allowCampaignDiscount,
      'allowCoupon': allowCoupon,
      'roomTypeIds': roomTypeIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SpecialDateSurchargeModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return SpecialDateSurchargeModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      startDate:
          _dateTimeFromValue(data['startDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endDate:
          _dateTimeFromValue(data['endDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      amountPerNight: _intFromValue(data['amountPerNight']),
      enabled: data['enabled'] == true,
      allowCampaignDiscount: data['allowCampaignDiscount'] is bool
          ? data['allowCampaignDiscount'] as bool
          : true,
      allowCoupon: data['allowCoupon'] is bool
          ? data['allowCoupon'] as bool
          : true,
      roomTypeIds: data['roomTypeIds'] is List
          ? List<String>.from(
              (data['roomTypeIds'] as List).map(
                (dynamic item) => item.toString(),
              ),
            )
          : const <String>[],
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt:
          _dateTimeFromValue(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _dateTimeFromValue(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  SpecialDateSurchargeModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? amountPerNight,
    bool? enabled,
    bool? allowCampaignDiscount,
    bool? allowCoupon,
    List<String>? roomTypeIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpecialDateSurchargeModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      amountPerNight: amountPerNight ?? this.amountPerNight,
      enabled: enabled ?? this.enabled,
      allowCampaignDiscount:
          allowCampaignDiscount ?? this.allowCampaignDiscount,
      allowCoupon: allowCoupon ?? this.allowCoupon,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
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

  static int _intFromValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
