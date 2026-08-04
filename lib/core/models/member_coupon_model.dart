// lib/core/models/member_coupon_model.dart
// 🎟️ 會員優惠券資料模型
// 功能：記錄會員實際持有的折價券、折扣券、住宿券或服務券

import 'package:cloud_firestore/cloud_firestore.dart';
import 'coupon_template_model.dart';

/// 優惠券類型
enum MemberCouponType {
  /// 固定金額折價券，例如折抵 300 元
  fixedAmount,

  /// 百分比折扣券，例如 9 折
  percent,

  /// 免費住宿券，例如免費住宿 1 晚
  freeStay,

  /// 免費服務券，例如免費餵藥一次
  freeService,
}

/// 優惠券適用範圍
enum MemberCouponApplyTarget {
  /// 僅限房價
  room,

  /// 房價與寵物費
  roomAndPet,

  /// 整張訂單
  total,

  /// 指定加購服務
  service,
}

/// 優惠券取得來源
enum MemberCouponSource {
  /// 店家從會員管理手動發放
  manual,

  /// 會員使用點數兌換
  pointsExchange,
}

/// 優惠券狀態
enum MemberCouponStatus {
  available,

  /// 已套用到尚未完成的訂單，暫時不能再次使用
  reserved,

  used,
  expired,
  revoked,
}

class MemberCouponModel {
  const MemberCouponModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.name,
    required this.type,
    required this.applyTarget,
    required this.source,
    required this.status,
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
    this.startAt,
    this.expireAt,
    this.usageLimit = 1,
    this.usedCount = 0,
    this.issuedBy = '',
    this.issuedReason = '',
    this.pointsCost = 0,
    this.pointRewardId = '',
    this.usedBookingId = '',
    this.usedAt,
    this.revokedBy = '',
    this.revokedReason = '',
    this.revokedAt,
  });

  final String id;

  /// 所屬店家
  final String shopId;

  /// 持有優惠券的會員 UID
  final String userId;

  /// 優惠券名稱
  final String name;

  /// 優惠券說明
  final String description;

  /// 固定金額、百分比、住宿券或服務券
  final MemberCouponType type;

  /// 適用範圍
  final MemberCouponApplyTarget applyTarget;

  /// 取得來源：手動發放或點數兌換
  final MemberCouponSource source;

  /// 優惠券狀態
  final MemberCouponStatus status;

  /// 折扣數值
  ///
  /// fixedAmount：
  /// 例如 300，代表折抵 300 元。
  ///
  /// percent：
  /// 例如 10，代表折抵 10%，會員支付 90%。
  final num discountValue;

  /// 最低消費金額
  /// 0 代表不限制
  final int minimumAmount;

  /// 百分比優惠券最高折抵金額
  /// 0 代表不限制
  final int maximumDiscountAmount;

  /// 免費住宿晚數
  ///
  /// 住宿券使用，例如 1 代表免費住宿一晚。
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
  /// 空陣列代表所有房型皆可使用
  final List<String> roomTypeIds;

  /// 可開始使用時間
  final DateTime? startAt;

  /// 使用期限
  /// null 代表永久有效
  final DateTime? expireAt;

  /// 可使用次數
  final int usageLimit;

  /// 已使用次數
  final int usedCount;

  /// 發放人員 UID
  final String issuedBy;

  /// 店家發券原因，例如客訴補償、熟客贈送
  final String issuedReason;

  /// 點數兌換花費
  /// 手動發放時為 0
  final int pointsCost;

  /// 對應的點數兌換商品 ID
  /// 手動發放時為空字串
  final String pointRewardId;

  /// 使用此券的訂單 ID
  ///
  /// 目前先支援單次券；未使用時為空字串。
  final String usedBookingId;

  /// 實際使用時間
  final DateTime? usedAt;

  /// 撤銷人員 UID
  final String revokedBy;

  /// 撤銷原因
  final String revokedReason;

  /// 撤銷時間
  final DateTime? revokedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAvailable => status == MemberCouponStatus.available;

  bool get isUsed => status == MemberCouponStatus.used;

  bool get isRevoked => status == MemberCouponStatus.revoked;

  bool get isFixedAmount => type == MemberCouponType.fixedAmount;

  bool get isPercent => type == MemberCouponType.percent;

  bool get isFreeStay => type == MemberCouponType.freeStay;

  bool get isFreeService => type == MemberCouponType.freeService;

  bool get isManual => source == MemberCouponSource.manual;

  bool get isPointsExchange {
    return source == MemberCouponSource.pointsExchange;
  }

  bool get hasMinimumAmount => minimumAmount > 0;

  bool get hasMaximumDiscount => maximumDiscountAmount > 0;

  bool get hasRoomTypeLimit => roomTypeIds.isNotEmpty;

  bool get hasExpireDate => expireAt != null;

  bool get hasUsageLimit => usageLimit > 0;

  bool get isUsageLimitReached {
    if (usageLimit <= 0) {
      return false;
    }

    return usedCount >= usageLimit;
  }

  /// 根據時間與狀態判斷是否已失效
  ///
  /// Firestore 內的 status 可能尚未更新為 expired，
  /// 因此前台顯示時仍需即時計算期限。
  bool get isExpired {
    if (status == MemberCouponStatus.expired) {
      return true;
    }

    final DateTime? end = expireAt;
    if (end == null) {
      return false;
    }

    return DateTime.now().isAfter(end);
  }

  /// 是否尚未到可使用日期
  bool get isNotStarted {
    final DateTime? start = startAt;
    if (start == null) {
      return false;
    }

    return DateTime.now().isBefore(start);
  }

  /// 目前是否可以嘗試使用
  ///
  /// 實際套用訂單時，仍需檢查最低消費、房型及搭配規則。
  bool get canUseNow {
    return isAvailable && !isExpired && !isNotStarted && !isUsageLimitReached;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'userId': userId,
      'name': name.trim(),
      'description': description.trim(),
      'type': type.name,
      'applyTarget': applyTarget.name,
      'source': source.name,
      'status': status.name,
      'discountValue': discountValue,
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'freeStayNights': freeStayNights,
      'serviceId': serviceId,
      'serviceName': serviceName.trim(),
      'serviceCategory': serviceCategory.name,
      'roomTypeIds': roomTypeIds,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
      'expireAt': expireAt == null ? null : Timestamp.fromDate(expireAt!),
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'issuedBy': issuedBy,
      'issuedReason': issuedReason.trim(),
      'pointsCost': pointsCost,
      'pointRewardId': pointRewardId,
      'usedBookingId': usedBookingId,
      'usedAt': usedAt == null ? null : Timestamp.fromDate(usedAt!),
      'revokedBy': revokedBy,
      'revokedReason': revokedReason.trim(),
      'revokedAt': revokedAt == null ? null : Timestamp.fromDate(revokedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MemberCouponModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return MemberCouponModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      type: _couponTypeFromString((data['type'] ?? '').toString()),
      applyTarget: _applyTargetFromString(
        (data['applyTarget'] ?? '').toString(),
      ),
      source: _sourceFromString((data['source'] ?? '').toString()),
      status: _statusFromString((data['status'] ?? '').toString()),
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
      startAt: _dateTimeFromValue(data['startAt']),
      expireAt: _dateTimeFromValue(data['expireAt']),
      usageLimit: _intFromValue(data['usageLimit'], defaultValue: 1),
      usedCount: _intFromValue(data['usedCount']),
      issuedBy: (data['issuedBy'] ?? '').toString(),
      issuedReason: (data['issuedReason'] ?? '').toString(),
      pointsCost: _intFromValue(data['pointsCost']),
      pointRewardId: (data['pointRewardId'] ?? '').toString(),
      usedBookingId: (data['usedBookingId'] ?? '').toString(),
      usedAt: _dateTimeFromValue(data['usedAt']),
      revokedBy: (data['revokedBy'] ?? '').toString(),
      revokedReason: (data['revokedReason'] ?? '').toString(),
      revokedAt: _dateTimeFromValue(data['revokedAt']),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  MemberCouponModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? name,
    String? description,
    MemberCouponType? type,
    MemberCouponApplyTarget? applyTarget,
    MemberCouponSource? source,
    MemberCouponStatus? status,
    num? discountValue,
    int? minimumAmount,
    int? maximumDiscountAmount,
    int? freeStayNights,
    String? serviceId,
    String? serviceName,
    CouponServiceCategory? serviceCategory,
    List<String>? roomTypeIds,
    DateTime? startAt,
    bool clearStartAt = false,
    DateTime? expireAt,
    bool clearExpireAt = false,
    int? usageLimit,
    int? usedCount,
    String? issuedBy,
    String? issuedReason,
    int? pointsCost,
    String? pointRewardId,
    String? usedBookingId,
    DateTime? usedAt,
    bool clearUsedAt = false,
    String? revokedBy,
    String? revokedReason,
    DateTime? revokedAt,
    bool clearRevokedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MemberCouponModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      applyTarget: applyTarget ?? this.applyTarget,
      source: source ?? this.source,
      status: status ?? this.status,
      discountValue: discountValue ?? this.discountValue,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      freeStayNights: freeStayNights ?? this.freeStayNights,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      startAt: clearStartAt ? null : startAt ?? this.startAt,
      expireAt: clearExpireAt ? null : expireAt ?? this.expireAt,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      issuedBy: issuedBy ?? this.issuedBy,
      issuedReason: issuedReason ?? this.issuedReason,
      pointsCost: pointsCost ?? this.pointsCost,
      pointRewardId: pointRewardId ?? this.pointRewardId,
      usedBookingId: usedBookingId ?? this.usedBookingId,
      usedAt: clearUsedAt ? null : usedAt ?? this.usedAt,
      revokedBy: revokedBy ?? this.revokedBy,
      revokedReason: revokedReason ?? this.revokedReason,
      revokedAt: clearRevokedAt ? null : revokedAt ?? this.revokedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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

MemberCouponSource _sourceFromString(String value) {
  return MemberCouponSource.values.firstWhere(
    (MemberCouponSource item) => item.name == value,
    orElse: () => MemberCouponSource.manual,
  );
}

MemberCouponStatus _statusFromString(String value) {
  return MemberCouponStatus.values.firstWhere(
    (MemberCouponStatus item) => item.name == value,
    orElse: () => MemberCouponStatus.available,
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
      .map((dynamic item) => item.toString())
      .where((String item) => item.trim().isNotEmpty)
      .toList();
}

CouponServiceCategory _serviceCategoryFromString(String value) {
  return CouponServiceCategory.values.firstWhere(
    (CouponServiceCategory item) => item.name == value,
    orElse: () => CouponServiceCategory.value,
  );
}
