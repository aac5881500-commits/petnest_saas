// 檔案名稱：lib/core/models/point_redemption_model.dart
// 功能說明：記錄會員使用點數兌換實體商品後的領取憑證
// 🎁 點數實體商品兌換紀錄 Model
// 商品快照、領取狀態、店員核銷、取消與退點資料。

import 'package:cloud_firestore/cloud_firestore.dart';

/// 實體商品兌換狀態
enum PointRedemptionStatus {
  /// 已兌換，等待會員到店領取
  pendingPickup,

  /// 店員已完成商品交付
  pickedUp,

  /// 店家或會員取消兌換
  cancelled,

  /// 超過領取期限
  expired,
}

/// 點數實體商品兌換紀錄
class PointRedemptionModel {
  const PointRedemptionModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.rewardId,
    required this.rewardName,
    required this.pointsCost,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.pickupCode,
    required this.createdAt,
    required this.updatedAt,
    this.rewardDescription = '',
    this.rewardImageUrl = '',
    this.fulfillmentNote = '',
    this.expireAt,
    this.pickedUpAt,
    this.pickedUpBy = '',
    this.cancelledAt,
    this.cancelledBy = '',
    this.cancelReason = '',
    this.pointsRefunded = false,
    this.pointsRefundedAt,
    this.pointsRefundedBy = '',
    this.useCentralInventory = false,
    this.inventoryItemId = '',
    this.inventoryItemName = '',
    this.inventoryUnit = '',
    this.inventoryQuantity = 0,
    this.inventoryDeducted = false,
    this.inventoryReturned = false,
    this.memberName = '',
    this.memberPhone = '',
    this.note = '',
  });

  /// 兌換紀錄 ID
  final String id;

  /// 所屬店家 ID
  final String shopId;

  /// 兌換會員 UID
  final String userId;

  /// 原始點數商城商品 ID
  final String rewardId;

  /// 商品名稱快照
  ///
  /// 即使店家日後修改或刪除商品，
  /// 兌換紀錄仍保留當時的商品名稱。
  final String rewardName;

  /// 商品說明快照
  final String rewardDescription;

  /// 商品圖片快照
  final String rewardImageUrl;

  /// 領取說明快照
  final String fulfillmentNote;

  /// 本次扣除點數
  final int pointsCost;

  /// 扣點前餘額
  final int balanceBefore;

  /// 扣點後餘額
  final int balanceAfter;

  /// 目前領取狀態
  final PointRedemptionStatus status;

  /// 到店領取碼
  ///
  /// 會員到店後出示給店員核銷。
  final String pickupCode;

  /// 領取期限
  ///
  /// null 代表永久有效。
  final DateTime? expireAt;

  /// 實際領取時間
  final DateTime? pickedUpAt;

  /// 完成交付的店員 UID
  final String pickedUpBy;

  /// 取消時間
  final DateTime? cancelledAt;

  /// 執行取消的人員 UID
  final String cancelledBy;

  /// 取消原因
  final String cancelReason;

  /// 取消後是否已退回點數
  final bool pointsRefunded;

  /// 點數退回時間
  final DateTime? pointsRefundedAt;

  /// 執行退點的人員 UID
  final String pointsRefundedBy;

  /// 此次兌換是否使用中央庫存
  final bool useCentralInventory;

  final String inventoryItemId;
  final String inventoryItemName;
  final String inventoryUnit;
  final num inventoryQuantity;
  final bool inventoryDeducted;
  final bool inventoryReturned;

  /// 會員名稱快照
  final String memberName;

  /// 會員電話快照
  final String memberPhone;

  /// 店員內部備註
  final String note;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPendingPickup {
    return status == PointRedemptionStatus.pendingPickup;
  }

  bool get isPickedUp {
    return status == PointRedemptionStatus.pickedUp;
  }

  bool get isCancelled {
    return status == PointRedemptionStatus.cancelled;
  }

  bool get isExpired {
    return status == PointRedemptionStatus.expired;
  }

  /// 是否仍可由店員進行核銷
  bool get canPickup {
    if (!isPendingPickup) {
      return false;
    }

    if (expireAt == null) {
      return true;
    }

    return DateTime.now().isBefore(expireAt!);
  }

  /// 是否已經超過領取期限
  bool get hasExpired {
    if (expireAt == null) {
      return false;
    }

    return DateTime.now().isAfter(expireAt!);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'userId': userId,
      'rewardId': rewardId,
      'rewardName': rewardName.trim(),
      'rewardDescription': rewardDescription.trim(),
      'rewardImageUrl': rewardImageUrl.trim(),
      'fulfillmentNote': fulfillmentNote.trim(),
      'pointsCost': pointsCost,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'status': status.name,
      'pickupCode': pickupCode.trim(),
      'expireAt': expireAt == null ? null : Timestamp.fromDate(expireAt!),
      'pickedUpAt': pickedUpAt == null ? null : Timestamp.fromDate(pickedUpAt!),
      'pickedUpBy': pickedUpBy.trim(),
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'cancelledBy': cancelledBy.trim(),
      'cancelReason': cancelReason.trim(),
      'pointsRefunded': pointsRefunded,
      'pointsRefundedAt': pointsRefundedAt == null
          ? null
          : Timestamp.fromDate(pointsRefundedAt!),
      'pointsRefundedBy': pointsRefundedBy.trim(),
      'useCentralInventory': useCentralInventory,
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemName': inventoryItemName.trim(),
      'inventoryUnit': inventoryUnit.trim(),
      'inventoryQuantity': inventoryQuantity,
      'inventoryDeducted': inventoryDeducted,
      'inventoryReturned': inventoryReturned,
      'memberName': memberName.trim(),
      'memberPhone': memberPhone.trim(),
      'note': note.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PointRedemptionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return PointRedemptionModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      rewardId: (data['rewardId'] ?? '').toString(),
      rewardName: (data['rewardName'] ?? '').toString(),
      rewardDescription: (data['rewardDescription'] ?? '').toString(),
      rewardImageUrl: (data['rewardImageUrl'] ?? '').toString(),
      fulfillmentNote: (data['fulfillmentNote'] ?? '').toString(),
      pointsCost: _intFromValue(data['pointsCost']),
      balanceBefore: _intFromValue(data['balanceBefore']),
      balanceAfter: _intFromValue(data['balanceAfter']),
      status: _statusFromString((data['status'] ?? '').toString()),
      pickupCode: (data['pickupCode'] ?? '').toString(),
      expireAt: _dateTimeFromValue(data['expireAt']),
      pickedUpAt: _dateTimeFromValue(data['pickedUpAt']),
      pickedUpBy: (data['pickedUpBy'] ?? '').toString(),
      cancelledAt: _dateTimeFromValue(data['cancelledAt']),
      cancelledBy: (data['cancelledBy'] ?? '').toString(),
      cancelReason: (data['cancelReason'] ?? '').toString(),
      pointsRefunded: data['pointsRefunded'] == true,
      pointsRefundedAt: _dateTimeFromValue(data['pointsRefundedAt']),
      pointsRefundedBy: (data['pointsRefundedBy'] ?? '').toString(),
      useCentralInventory: data['useCentralInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      inventoryUnit: (data['inventoryUnit'] ?? '').toString(),
      inventoryQuantity: data['inventoryQuantity'] is num
          ? data['inventoryQuantity'] as num
          : num.tryParse(data['inventoryQuantity']?.toString() ?? '') ?? 0,
      inventoryDeducted: data['inventoryDeducted'] == true,
      inventoryReturned: data['inventoryReturned'] == true,
      memberName: (data['memberName'] ?? '').toString(),
      memberPhone: (data['memberPhone'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  PointRedemptionModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? rewardId,
    String? rewardName,
    String? rewardDescription,
    String? rewardImageUrl,
    String? fulfillmentNote,
    int? pointsCost,
    int? balanceBefore,
    int? balanceAfter,
    PointRedemptionStatus? status,
    String? pickupCode,
    DateTime? expireAt,
    bool clearExpireAt = false,
    DateTime? pickedUpAt,
    bool clearPickedUpAt = false,
    String? pickedUpBy,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
    String? cancelledBy,
    String? cancelReason,
    bool? pointsRefunded,
    DateTime? pointsRefundedAt,
    bool clearPointsRefundedAt = false,
    String? pointsRefundedBy,
    bool? useCentralInventory,
    String? inventoryItemId,
    String? inventoryItemName,
    String? inventoryUnit,
    num? inventoryQuantity,
    bool? inventoryDeducted,
    bool? inventoryReturned,
    String? memberName,
    String? memberPhone,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PointRedemptionModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      rewardId: rewardId ?? this.rewardId,
      rewardName: rewardName ?? this.rewardName,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      rewardImageUrl: rewardImageUrl ?? this.rewardImageUrl,
      fulfillmentNote: fulfillmentNote ?? this.fulfillmentNote,
      pointsCost: pointsCost ?? this.pointsCost,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      status: status ?? this.status,
      pickupCode: pickupCode ?? this.pickupCode,
      expireAt: clearExpireAt ? null : expireAt ?? this.expireAt,
      pickedUpAt: clearPickedUpAt ? null : pickedUpAt ?? this.pickedUpAt,
      pickedUpBy: pickedUpBy ?? this.pickedUpBy,
      cancelledAt: clearCancelledAt ? null : cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      pointsRefunded: pointsRefunded ?? this.pointsRefunded,
      pointsRefundedAt: clearPointsRefundedAt
          ? null
          : pointsRefundedAt ?? this.pointsRefundedAt,
      pointsRefundedBy: pointsRefundedBy ?? this.pointsRefundedBy,
      useCentralInventory: useCentralInventory ?? this.useCentralInventory,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      inventoryItemName: inventoryItemName ?? this.inventoryItemName,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryQuantity: inventoryQuantity ?? this.inventoryQuantity,
      inventoryDeducted: inventoryDeducted ?? this.inventoryDeducted,
      inventoryReturned: inventoryReturned ?? this.inventoryReturned,
      memberName: memberName ?? this.memberName,
      memberPhone: memberPhone ?? this.memberPhone,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

PointRedemptionStatus _statusFromString(String value) {
  return PointRedemptionStatus.values.firstWhere(
    (PointRedemptionStatus status) => status.name == value,
    orElse: () => PointRedemptionStatus.pendingPickup,
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

int _intFromValue(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
