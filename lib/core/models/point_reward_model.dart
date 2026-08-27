// lib/core/models/point_reward_model.dart
// 🎁 點數兌換商品資料模型
// 功能：記錄店家提供的優惠券、住宿券、實體商品或現場服務，
// 讓會員使用點數兌換，並依商品類型決定直接發券或由店員現場核銷。

import 'package:cloud_firestore/cloud_firestore.dart';

import 'member_coupon_model.dart';

/// 點數兌換完成後的交付方式
enum PointRewardFulfillmentType {
  /// 兌換後建立會員優惠券，可在預約流程使用
  coupon,

  /// 兌換後建立領取憑證，由會員到店領取實體商品
  physicalProduct,

  /// 兌換後建立使用憑證，由店員確認現場服務完成
  onsiteService,
}

class PointRewardModel {
  const PointRewardModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.pointsCost,
    required this.couponType,
    required this.applyTarget,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.fulfillmentType = PointRewardFulfillmentType.coupon,
    this.couponTemplateId = '',
    this.imageUrl = '',
    this.stockQuantity = 0,
    this.useCentralInventory = false,
    this.inventoryItemId = '',
    this.inventoryItemName = '',
    this.inventoryUnit = '',
    this.inventoryQuantityPerExchange = 1,
    this.fulfillmentNote = '',
    this.requiresStaffVerification = false,
    this.discountValue = 0,
    this.minimumAmount = 0,
    this.maximumDiscountAmount = 0,
    this.freeStayNights = 0,
    this.serviceId = '',
    this.serviceName = '',
    this.roomTypeIds = const <String>[],
    this.validDays = 30,
    this.usageLimit = 1,
    this.exchangeLimitPerMember = 0,
    this.totalExchangeLimit = 0,
    this.exchangedCount = 0,
    this.sortOrder = 0,
    this.createdBy = '',
  });

  final String id;

  /// 所屬店家
  final String shopId;

  /// 兌換商品名稱
  final String name;

  /// 兌換商品說明
  final String description;

  /// 兌換需要的點數
  final int pointsCost;

  /// 兌換完成後的交付方式
  final PointRewardFulfillmentType fulfillmentType;

  /// 優惠券型商品所連結的優惠券模板 ID
  ///
  /// 空字串代表目前仍使用 PointRewardModel 內舊有的優惠券欄位，
  /// 保留舊資料相容性。
  final String couponTemplateId;

  /// 商品或兌換項目的圖片網址
  final String imageUrl;

  /// 商品庫存或總供應數量
  ///
  /// 0 代表不限制。
  /// 舊實體商品若未綁中央庫存，繼續使用此欄位搭配 exchangedCount。
  final int stockQuantity;

  /// 是否改為使用店家中央庫存
  final bool useCentralInventory;

  /// 中央庫存品項 ID
  final String inventoryItemId;

  /// 中央庫存品項名稱快照
  final String inventoryItemName;

  /// 中央庫存單位快照
  final String inventoryUnit;

  /// 每次兌換扣除的中央庫存數量
  final num inventoryQuantityPerExchange;

  /// 領取或使用說明
  ///
  /// 例如：
  /// 到店時出示兌換碼，由店員確認後領取。
  final String fulfillmentNote;

  /// 是否必須由店員確認核銷
  final bool requiresStaffVerification;

  /// 兌換後產生的優惠券類型
  ///
  /// 實體商品與現場服務目前仍保留此欄位，
  /// 以維持既有資料和頁面相容。
  final MemberCouponType couponType;

  /// 優惠券適用範圍
  final MemberCouponApplyTarget applyTarget;

  /// 固定金額或百分比折扣數值
  final num discountValue;

  /// 最低消費金額
  /// 0 代表不限制
  final int minimumAmount;

  /// 百分比券最高折抵金額
  /// 0 代表不限制
  final int maximumDiscountAmount;

  /// 免費住宿晚數
  final int freeStayNights;

  /// 指定服務 ID
  final String serviceId;

  /// 指定服務名稱快照
  final String serviceName;

  /// 指定房型
  /// 空陣列代表不限房型
  final List<String> roomTypeIds;

  /// 兌換成功後的有效天數
  ///
  /// 優惠券型：
  /// 代表優惠券的有效天數。
  ///
  /// 實體商品或現場服務：
  /// 代表兌換憑證的有效天數。
  ///
  /// 0 代表永久有效。
  final int validDays;

  /// 每張優惠券可使用次數
  final int usageLimit;

  /// 每位會員最多可兌換次數
  /// 0 代表不限制
  final int exchangeLimitPerMember;

  /// 全店總兌換上限
  /// 0 代表不限制
  final int totalExchangeLimit;

  /// 目前已兌換次數
  final int exchangedCount;

  /// 是否開放會員兌換
  final bool enabled;

  /// 前台顯示順序
  final int sortOrder;

  /// 建立人員 UID
  final String createdBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCouponReward {
    return fulfillmentType == PointRewardFulfillmentType.coupon;
  }

  bool get isPhysicalProduct {
    return fulfillmentType == PointRewardFulfillmentType.physicalProduct;
  }

  bool get isOnsiteService {
    return fulfillmentType == PointRewardFulfillmentType.onsiteService;
  }

  bool get requiresRedemptionVoucher {
    return !isCouponReward;
  }

  bool get hasCouponTemplate {
    return couponTemplateId.trim().isNotEmpty;
  }

  bool get hasMemberExchangeLimit {
    return exchangeLimitPerMember > 0;
  }

  bool get hasTotalExchangeLimit {
    return totalExchangeLimit > 0;
  }

  bool get usesCentralInventory {
    return isPhysicalProduct &&
        useCentralInventory &&
        inventoryItemId.trim().isNotEmpty;
  }

  bool get hasStockLimit {
    if (usesCentralInventory) {
      return false;
    }

    return stockQuantity > 0;
  }

  bool get hasRoomTypeLimit {
    return roomTypeIds.isNotEmpty;
  }

  bool get hasValidDays {
    return validDays > 0;
  }

  int? get remainingStock {
    if (!hasStockLimit) {
      return null;
    }

    final int remaining = stockQuantity - exchangedCount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  bool get isSoldOut {
    final bool reachedExchangeLimit =
        totalExchangeLimit > 0 && exchangedCount >= totalExchangeLimit;

    final bool reachedStockLimit =
        stockQuantity > 0 && exchangedCount >= stockQuantity;

    return reachedExchangeLimit || reachedStockLimit;
  }

  bool get canExchange {
    return enabled && !isSoldOut && pointsCost > 0;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'description': description.trim(),
      'pointsCost': pointsCost,
      'fulfillmentType': fulfillmentType.name,
      'couponTemplateId': couponTemplateId.trim(),
      'imageUrl': imageUrl.trim(),
      'stockQuantity': stockQuantity,
      'useCentralInventory': useCentralInventory,
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemName': inventoryItemName.trim(),
      'inventoryUnit': inventoryUnit.trim(),
      'inventoryQuantityPerExchange': inventoryQuantityPerExchange,
      'fulfillmentNote': fulfillmentNote.trim(),
      'requiresStaffVerification': requiresStaffVerification,
      'couponType': couponType.name,
      'applyTarget': applyTarget.name,
      'discountValue': discountValue,
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'freeStayNights': freeStayNights,
      'serviceId': serviceId,
      'serviceName': serviceName.trim(),
      'roomTypeIds': roomTypeIds,
      'validDays': validDays,
      'usageLimit': usageLimit,
      'exchangeLimitPerMember': exchangeLimitPerMember,
      'totalExchangeLimit': totalExchangeLimit,
      'exchangedCount': exchangedCount,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PointRewardModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final PointRewardFulfillmentType fulfillmentType =
        _fulfillmentTypeFromString((data['fulfillmentType'] ?? '').toString());

    return PointRewardModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      pointsCost: _intFromValue(data['pointsCost']),
      fulfillmentType: fulfillmentType,
      couponTemplateId: (data['couponTemplateId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      stockQuantity: _intFromValue(data['stockQuantity']),
      useCentralInventory: data['useCentralInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      inventoryUnit: (data['inventoryUnit'] ?? '').toString(),
      inventoryQuantityPerExchange: data['inventoryQuantityPerExchange'] is num
          ? data['inventoryQuantityPerExchange'] as num
          : num.tryParse(
                  data['inventoryQuantityPerExchange']?.toString() ?? '',
                ) ??
                1,
      fulfillmentNote: (data['fulfillmentNote'] ?? '').toString(),
      requiresStaffVerification: data['requiresStaffVerification'] is bool
          ? data['requiresStaffVerification'] == true
          : fulfillmentType != PointRewardFulfillmentType.coupon,
      couponType: _couponTypeFromString((data['couponType'] ?? '').toString()),
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
      roomTypeIds: _stringListFromValue(data['roomTypeIds']),
      validDays: _intFromValue(data['validDays'], defaultValue: 30),
      usageLimit: _intFromValue(data['usageLimit'], defaultValue: 1),
      exchangeLimitPerMember: _intFromValue(data['exchangeLimitPerMember']),
      totalExchangeLimit: _intFromValue(data['totalExchangeLimit']),
      exchangedCount: _intFromValue(data['exchangedCount']),
      enabled: data['enabled'] == true,
      sortOrder: _intFromValue(data['sortOrder']),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  PointRewardModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? description,
    int? pointsCost,
    PointRewardFulfillmentType? fulfillmentType,
    String? couponTemplateId,
    String? imageUrl,
    int? stockQuantity,
    bool? useCentralInventory,
    String? inventoryItemId,
    String? inventoryItemName,
    String? inventoryUnit,
    num? inventoryQuantityPerExchange,
    String? fulfillmentNote,
    bool? requiresStaffVerification,
    MemberCouponType? couponType,
    MemberCouponApplyTarget? applyTarget,
    num? discountValue,
    int? minimumAmount,
    int? maximumDiscountAmount,
    int? freeStayNights,
    String? serviceId,
    String? serviceName,
    List<String>? roomTypeIds,
    int? validDays,
    int? usageLimit,
    int? exchangeLimitPerMember,
    int? totalExchangeLimit,
    int? exchangedCount,
    bool? enabled,
    int? sortOrder,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PointRewardModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      pointsCost: pointsCost ?? this.pointsCost,
      fulfillmentType: fulfillmentType ?? this.fulfillmentType,
      couponTemplateId: couponTemplateId ?? this.couponTemplateId,
      imageUrl: imageUrl ?? this.imageUrl,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      useCentralInventory: useCentralInventory ?? this.useCentralInventory,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      inventoryItemName: inventoryItemName ?? this.inventoryItemName,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryQuantityPerExchange:
          inventoryQuantityPerExchange ?? this.inventoryQuantityPerExchange,
      fulfillmentNote: fulfillmentNote ?? this.fulfillmentNote,
      requiresStaffVerification:
          requiresStaffVerification ?? this.requiresStaffVerification,
      couponType: couponType ?? this.couponType,
      applyTarget: applyTarget ?? this.applyTarget,
      discountValue: discountValue ?? this.discountValue,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      freeStayNights: freeStayNights ?? this.freeStayNights,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      roomTypeIds: roomTypeIds ?? this.roomTypeIds,
      validDays: validDays ?? this.validDays,
      usageLimit: usageLimit ?? this.usageLimit,
      exchangeLimitPerMember:
          exchangeLimitPerMember ?? this.exchangeLimitPerMember,
      totalExchangeLimit: totalExchangeLimit ?? this.totalExchangeLimit,
      exchangedCount: exchangedCount ?? this.exchangedCount,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

PointRewardFulfillmentType _fulfillmentTypeFromString(String value) {
  return PointRewardFulfillmentType.values.firstWhere(
    (PointRewardFulfillmentType item) => item.name == value,
    orElse: () => PointRewardFulfillmentType.coupon,
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
      .map((dynamic item) => item.toString())
      .where((String item) => item.trim().isNotEmpty)
      .toList();
}
