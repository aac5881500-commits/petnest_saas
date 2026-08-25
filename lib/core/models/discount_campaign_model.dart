// lib/core/models/discount_campaign_model.dart
// 🏷️ 優惠活動資料模型
// 功能：定義店家建立自動折扣時可選擇的類型、條件、範圍與限制

import 'package:cloud_firestore/cloud_firestore.dart';

/// 優惠活動類型
enum DiscountCampaignType {
  longStay,
  newMember,
  googleReview,
  stayDate,
  roomType,
  minimumAmount,
  limitedTime,
}

/// 折扣計算方式
enum DiscountValueType { percent, fixedAmount }

/// 新會員優惠資格判斷方式
enum NewMemberEligibilityMode {
  /// 僅活動建立後才加入本店的會員可使用
  createdAfterCampaign,

  /// 只要會員在本店沒有過往有效訂單即可使用
  noPreviousBooking,
}

/// 折扣適用範圍
enum DiscountApplyTarget { room, roomAndPet, total }

/// 特定日期符合方式
enum DiscountDateMatchType {
  /// 訂單只要包含活動日期，就只折符合日期的房價
  matchingStayDates,

  /// 入住日必須落在活動日期範圍
  checkInDate,

  /// 整段住宿都必須落在活動日期範圍
  entireStay,
}

class DiscountCampaignModel {
  const DiscountCampaignModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.type,
    required this.valueType,
    required this.applyTarget,
    required this.discountValue,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.startAt,
    this.endAt,
    this.dateMatchType,
    this.minimumNights = 0,
    this.minimumAmount = 0,
    this.maximumDiscountAmount = 0,
    this.memberUsageLimit = 1,
    this.totalUsageLimit = 0,
    this.usedCount = 0,
    this.firstBookingOnly = false,
    this.newMemberEligibilityMode =
        NewMemberEligibilityMode.createdAfterCampaign,
    this.allowCouponTogether = false,
    this.roomTypeIds = const <String>[],
    this.newMemberDiscountNights = 0,
    this.limitStayDate = false,
    this.stayStartAt,
    this.stayEndAt,
    this.createdBy = '',
  });

  final String id;
  final String shopId;

  /// 活動名稱
  final String name;

  /// 活動說明
  final String description;

  /// 長住、新會員、Google 評論、日期、房型、滿額、限時活動
  final DiscountCampaignType type;

  /// 百分比或固定金額
  final DiscountValueType valueType;

  /// 房價、房價＋寵物、整張訂單
  final DiscountApplyTarget applyTarget;

  /// 百分比時，例如輸入 15，代表折抵原價的 15%，會員支付 85%
  /// 固定金額時，例如輸入 300，代表直接折抵 300 元
  final num discountValue;

  /// 是否啟用
  final bool enabled;

  /// 活動開始與結束時間
  final DateTime? startAt;
  final DateTime? endAt;

  /// 特定日期優惠的判斷方式
  final DiscountDateMatchType? dateMatchType;

  /// 最低入住晚數
  final int minimumNights;

  /// 最低消費金額
  final int minimumAmount;

  /// 百分比折扣的最高折抵金額
  /// 0 代表不限制
  final int maximumDiscountAmount;

  /// 每位會員最多使用幾次
  /// 0 代表不限制
  final int memberUsageLimit;

  /// 活動總使用次數
  /// 0 代表不限制
  final int totalUsageLimit;

  /// 已使用次數
  final int usedCount;

  /// 是否限首次預約
  final bool firstBookingOnly;

  /// 新會員優惠資格判斷方式
  final NewMemberEligibilityMode newMemberEligibilityMode;

  /// 是否允許與會員折價券同時使用
  final bool allowCouponTogether;

  /// 適用房型 ID
  /// 空陣列代表全部房型
  final List<String> roomTypeIds;

  /// 新會員可享有的總優惠晚數
  ///
  /// 例如設定 3：
  /// 第一次住宿使用 1 晚後，剩餘 2 晚；
  /// 第二次住宿可繼續使用剩餘額度。
  ///
  /// 0 代表尚未設定。
  final int newMemberDiscountNights;

  /// 指定房型優惠是否限制住宿日期
  final bool limitStayDate;

  /// 指定房型優惠適用的住宿開始日期
  ///
  /// 這組日期判斷的是住宿日期，
  /// 不可與 startAt、endAt 的下單活動期間混用。
  final DateTime? stayStartAt;

  /// 指定房型優惠適用的住宿結束日期
  final DateTime? stayEndAt;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPercent => valueType == DiscountValueType.percent;

  bool get isFixedAmount => valueType == DiscountValueType.fixedAmount;

  bool get hasDateRange => startAt != null || endAt != null;

  bool get hasRoomTypeLimit => roomTypeIds.isNotEmpty;

  bool get hasStayDateLimit {
    return limitStayDate && (stayStartAt != null || stayEndAt != null);
  }

  bool get hasNewMemberNightLimit => newMemberDiscountNights > 0;

  bool get hasTotalUsageLimit => totalUsageLimit > 0;

  bool get hasMaximumDiscount => maximumDiscountAmount > 0;

  bool get isUsageLimitReached {
    if (totalUsageLimit <= 0) {
      return false;
    }

    return usedCount >= totalUsageLimit;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'description': description.trim(),
      'type': type.name,
      'valueType': valueType.name,
      'applyTarget': applyTarget.name,
      'discountValue': discountValue,
      'enabled': enabled,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'dateMatchType': dateMatchType?.name,
      'minimumNights': minimumNights,
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'memberUsageLimit': memberUsageLimit,
      'totalUsageLimit': totalUsageLimit,
      'usedCount': usedCount,
      'firstBookingOnly': firstBookingOnly,
      'newMemberEligibilityMode': newMemberEligibilityMode.name,
      'allowCouponTogether': allowCouponTogether,
      'roomTypeIds': roomTypeIds,
      'newMemberDiscountNights': newMemberDiscountNights,
      'limitStayDate': limitStayDate,
      'stayStartAt': stayStartAt == null
          ? null
          : Timestamp.fromDate(stayStartAt!),
      'stayEndAt': stayEndAt == null ? null : Timestamp.fromDate(stayEndAt!),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory DiscountCampaignModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return DiscountCampaignModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      type: _campaignTypeFromString((data['type'] ?? '').toString()),
      valueType: _valueTypeFromString((data['valueType'] ?? '').toString()),
      applyTarget: _applyTargetFromString(
        (data['applyTarget'] ?? '').toString(),
      ),
      discountValue: data['discountValue'] is num
          ? data['discountValue'] as num
          : 0,
      enabled: data['enabled'] == true,
      startAt: _dateTimeFromValue(data['startAt']),
      endAt: _dateTimeFromValue(data['endAt']),
      dateMatchType: _dateMatchTypeFromString(
        data['dateMatchType']?.toString(),
      ),
      minimumNights: ((data['minimumNights'] ?? 0) as num).toInt(),
      minimumAmount: ((data['minimumAmount'] ?? 0) as num).toInt(),
      maximumDiscountAmount: ((data['maximumDiscountAmount'] ?? 0) as num)
          .toInt(),
      memberUsageLimit: ((data['memberUsageLimit'] ?? 1) as num).toInt(),
      totalUsageLimit: ((data['totalUsageLimit'] ?? 0) as num).toInt(),
      usedCount: ((data['usedCount'] ?? 0) as num).toInt(),
      firstBookingOnly: data['firstBookingOnly'] == true,
      newMemberEligibilityMode: _newMemberEligibilityModeFromString(
        (data['newMemberEligibilityMode'] ?? '').toString(),
      ),
      allowCouponTogether: data['allowCouponTogether'] == true,
      roomTypeIds: _stringListFromValue(data['roomTypeIds']),
      newMemberDiscountNights: ((data['newMemberDiscountNights'] ?? 0) as num)
          .toInt(),
      limitStayDate: data['limitStayDate'] == true,
      stayStartAt: _dateTimeFromValue(data['stayStartAt']),
      stayEndAt: _dateTimeFromValue(data['stayEndAt']),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  DiscountCampaignModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    DiscountCampaignType? type,
    DiscountValueType? valueType,
    DiscountApplyTarget? applyTarget,
    num? discountValue,
    bool? enabled,
    DateTime? startAt,
    DateTime? endAt,
    DiscountDateMatchType? dateMatchType,
    int? minimumNights,
    int? minimumAmount,
    int? maximumDiscountAmount,
    int? memberUsageLimit,
    int? totalUsageLimit,
    int? usedCount,
    bool? firstBookingOnly,
    NewMemberEligibilityMode? newMemberEligibilityMode,
    bool? allowCouponTogether,
    List<String>? roomTypeIds,
    int? newMemberDiscountNights,
    bool? limitStayDate,
    DateTime? stayStartAt,
    DateTime? stayEndAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiscountCampaignModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      valueType: valueType ?? this.valueType,
      applyTarget: applyTarget ?? this.applyTarget,
      discountValue: discountValue ?? this.discountValue,
      enabled: enabled ?? this.enabled,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      dateMatchType: dateMatchType ?? this.dateMatchType,
      minimumNights: minimumNights ?? this.minimumNights,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      memberUsageLimit: memberUsageLimit ?? this.memberUsageLimit,
      totalUsageLimit: totalUsageLimit ?? this.totalUsageLimit,
      usedCount: usedCount ?? this.usedCount,
      firstBookingOnly: firstBookingOnly ?? this.firstBookingOnly,
      newMemberEligibilityMode:
          newMemberEligibilityMode ?? this.newMemberEligibilityMode,
      allowCouponTogether: allowCouponTogether ?? this.allowCouponTogether,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      newMemberDiscountNights:
          newMemberDiscountNights ?? this.newMemberDiscountNights,
      limitStayDate: limitStayDate ?? this.limitStayDate,
      stayStartAt: stayStartAt ?? this.stayStartAt,
      stayEndAt: stayEndAt ?? this.stayEndAt,
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

  static List<String> _stringListFromValue(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map((dynamic item) => item.toString())
        .where((String item) => item.trim().isNotEmpty)
        .toList();
  }

  static DiscountCampaignType _campaignTypeFromString(String value) {
    return DiscountCampaignType.values.firstWhere(
      (DiscountCampaignType item) => item.name == value,
      orElse: () => DiscountCampaignType.limitedTime,
    );
  }

  static DiscountValueType _valueTypeFromString(String value) {
    return DiscountValueType.values.firstWhere(
      (DiscountValueType item) => item.name == value,
      orElse: () => DiscountValueType.percent,
    );
  }

  static DiscountApplyTarget _applyTargetFromString(String value) {
    return DiscountApplyTarget.values.firstWhere(
      (DiscountApplyTarget item) => item.name == value,
      orElse: () => DiscountApplyTarget.room,
    );
  }

  static DiscountDateMatchType? _dateMatchTypeFromString(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    for (final DiscountDateMatchType item in DiscountDateMatchType.values) {
      if (item.name == value) {
        return item;
      }
    }

    return null;
  }

  static NewMemberEligibilityMode _newMemberEligibilityModeFromString(
    String value,
  ) {
    return NewMemberEligibilityMode.values.firstWhere(
      (NewMemberEligibilityMode item) => item.name == value,
      orElse: () => NewMemberEligibilityMode.createdAfterCampaign,
    );
  }
}
