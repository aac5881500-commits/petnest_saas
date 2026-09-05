// 檔案名稱：lib/core/models/coupon_template_model.dart
// 功能說明：記錄店家建立的優惠券母版，供手動發券、點數兌換與自動贈券共用。
// 🎟️ 優惠券模板資料模型

import 'package:cloud_firestore/cloud_firestore.dart';

import 'member_coupon_model.dart';

/// 免費服務券綁定的服務種類
enum CouponServiceCategory {
  /// 整張訂單只計算一次的加值服務
  value,

  /// 每隻寵物各自計算一次的客製服務
  custom,
}

class CouponTemplateModel {
  const CouponTemplateModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.type,
    required this.applyTarget,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.discountValue = 0,
    this.minimumAmount = 0,
    this.maximumDiscountAmount = 0,
    this.freeStayNights = 0,
    this.serviceId = '',
    this.serviceName = '',
    this.serviceCategory = CouponServiceCategory.value,
    this.roomTypeIds = const <String>[],
    this.validDays = 30,
    this.usageLimit = 1,
    this.sortOrder = 0,
    this.createdBy = '',
    this.updatedBy = '',
  });

  final String id;

  /// 所屬店家
  final String shopId;

  /// 優惠券模板名稱
  final String name;

  /// 優惠券說明
  final String description;

  /// 固定金額、百分比、免費住宿或免費服務
  final MemberCouponType type;

  /// 優惠券可折抵的範圍
  final MemberCouponApplyTarget applyTarget;

  /// 固定金額或百分比數值
  ///
  /// fixedAmount：
  /// 例如 300，代表折抵 300 元。
  ///
  /// percent：
  /// 例如 10，代表折抵 10%，會員支付 90%。
  final num discountValue;

  /// 最低消費金額
  ///
  /// 0 代表不限制。
  final int minimumAmount;

  /// 百分比券最高折抵金額
  ///
  /// 0 代表不限制。
  final int maximumDiscountAmount;

  /// 免費住宿晚數
  final int freeStayNights;

  /// 免費服務券指定的服務 ID
  final String serviceId;

  /// 免費服務名稱快照
  final String serviceName;

  /// 免費服務的服務類別
  ///
  /// value：整張訂單免費一次。
  /// custom：每隻寵物免費一次。
  final CouponServiceCategory serviceCategory;

  /// 指定房型 ID
  ///
  /// 空陣列代表不限房型。
  final List<String> roomTypeIds;

  /// 發放後有效天數
  ///
  /// 0 代表永久有效。
  final int validDays;

  /// 每張優惠券可使用次數
  final int usageLimit;

  /// 是否開放使用此模板
  final bool enabled;

  /// 後台顯示排序
  final int sortOrder;

  /// 建立人員 UID
  final String createdBy;

  /// 最後修改人員 UID
  final String updatedBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFixedAmount => type == MemberCouponType.fixedAmount;

  bool get isPercent => type == MemberCouponType.percent;

  bool get isFreeStay => type == MemberCouponType.freeStay;

  bool get isFreeService => type == MemberCouponType.freeService;

  bool get hasMinimumAmount => minimumAmount > 0;

  bool get hasMaximumDiscount => maximumDiscountAmount > 0;

  bool get hasRoomTypeLimit => roomTypeIds.isNotEmpty;

  bool get hasValidDays => validDays > 0;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'description': description.trim(),
      'type': type.name,
      'applyTarget': applyTarget.name,
      'discountValue': discountValue,
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'freeStayNights': freeStayNights,
      'serviceId': serviceId,
      'serviceName': serviceName.trim(),
      'serviceCategory': serviceCategory.name,
      'roomTypeIds': roomTypeIds,
      'validDays': validDays,
      'usageLimit': usageLimit,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CouponTemplateModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return CouponTemplateModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      type: _couponTypeFromString((data['type'] ?? '').toString()),
      applyTarget: _applyTargetFromString(
        (data['applyTarget'] ?? '').toString(),
      ),
      discountValue: data['discountValue'] is num
          ? data['discountValue'] as num
          : 0,
      minimumAmount: _intFromValue(data['minimumAmount']),
      maximumDiscountAmount: _intFromValue(data['maximumDiscountAmount']),
      freeStayNights: _intFromValue(data['freeStayNights']),
      serviceId: (data['serviceId'] ?? '').toString(),
      serviceName: (data['serviceName'] ?? '').toString(),
      serviceCategory: _serviceCategoryFromString(
        (data['serviceCategory'] ?? '').toString(),
      ),
      roomTypeIds: _stringListFromValue(data['roomTypeIds']),
      validDays: _intFromValue(data['validDays'], defaultValue: 30),
      usageLimit: _intFromValue(data['usageLimit'], defaultValue: 1),
      enabled: data['enabled'] != false,
      sortOrder: _intFromValue(data['sortOrder']),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  CouponTemplateModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    MemberCouponType? type,
    MemberCouponApplyTarget? applyTarget,
    num? discountValue,
    int? minimumAmount,
    int? maximumDiscountAmount,
    int? freeStayNights,
    String? serviceId,
    String? serviceName,
    CouponServiceCategory? serviceCategory,
    List<String>? roomTypeIds,
    int? validDays,
    int? usageLimit,
    bool? enabled,
    int? sortOrder,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CouponTemplateModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      applyTarget: applyTarget ?? this.applyTarget,
      discountValue: discountValue ?? this.discountValue,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      freeStayNights: freeStayNights ?? this.freeStayNights,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      validDays: validDays ?? this.validDays,
      usageLimit: usageLimit ?? this.usageLimit,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

CouponServiceCategory _serviceCategoryFromString(String value) {
  return CouponServiceCategory.values.firstWhere(
    (CouponServiceCategory item) => item.name == value,
    orElse: () => CouponServiceCategory.value,
  );
}

MemberCouponType _couponTypeFromString(String value) {
  return MemberCouponType.values.firstWhere(
    (MemberCouponType item) => item.name == value,
    orElse: () => MemberCouponType.fixedAmount,
  );
}

MemberCouponApplyTarget _applyTargetFromString(String value) {
  return MemberCouponApplyTarget.values.firstWhere(
    (MemberCouponApplyTarget item) => item.name == value,
    orElse: () => MemberCouponApplyTarget.total,
  );
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

int _intFromValue(dynamic value, {int defaultValue = 0}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? defaultValue;
}

List<String> _stringListFromValue(dynamic value) {
  if (value is! List) {
    return <String>[];
  }

  return value
      .map((dynamic item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .toSet()
      .toList();
}
