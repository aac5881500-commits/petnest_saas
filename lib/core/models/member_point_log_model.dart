// lib/core/models/member_point_log_model.dart
// 🪙 會員點數流水模型
// 功能：記錄會員每一次點數增加、扣除、兌換、退回與過期紀錄

import 'package:cloud_firestore/cloud_firestore.dart';

class MemberPointLogModel {
  const MemberPointLogModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.type,
    required this.points,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reason,
    required this.operatorUid,
    required this.createdAt,
    this.sourceId = '',
    this.bookingId = '',
    this.rewardId = '',
    this.couponId = '',
    this.redemptionId = '',
    this.expireAt,
    this.note = '',
  });

  /// 流水紀錄 ID
  final String id;

  /// 所屬店家 ID
  final String shopId;

  /// 會員 UID
  final String userId;

  /// 點數異動類型
  final MemberPointLogType type;

  /// 點數異動數量
  ///
  /// 增加點數使用正數，例如 10。
  /// 扣除點數使用負數，例如 -10。
  final int points;

  /// 異動前點數
  final int balanceBefore;

  /// 異動後點數
  final int balanceAfter;

  /// 異動原因
  final String reason;

  /// 操作者 UID
  ///
  /// 店家手動調整時為店家人員 UID。
  /// 系統自動發點時可為空字串或 system。
  final String operatorUid;

  /// 來源資料 ID
  ///
  /// 可記錄訂單、兌換、補償等來源 ID。
  final String sourceId;

  /// 關聯訂單 ID
  final String bookingId;

  /// 關聯點數兌換商品 ID
  final String rewardId;

  /// 關聯優惠券 ID
  ///
  /// 兌換優惠券商品時使用。
  final String couponId;

  /// 關聯實體商品兌換紀錄 ID
  ///
  /// 兌換實體商品時，對應：
  /// shops/{shopId}/point_redemptions/{redemptionId}
  final String redemptionId;

  /// 此筆獲得點數的到期時間
  /// 只有獲得點數時可能會有值。
  final DateTime? expireAt;

  /// 額外備註
  final String note;

  final DateTime createdAt;

  /// 是否為增加點數
  bool get isIncrease => points > 0;

  /// 是否為扣除點數
  bool get isDecrease => points < 0;

  /// 顯示用絕對點數
  int get absolutePoints => points.abs();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'userId': userId,
      'type': type.value,
      'points': points,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'reason': reason.trim(),
      'operatorUid': operatorUid,
      'sourceId': sourceId,
      'bookingId': bookingId,
      'rewardId': rewardId,
      'couponId': couponId,
      'redemptionId': redemptionId,
      'expireAt': expireAt == null ? null : Timestamp.fromDate(expireAt!),
      'note': note.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MemberPointLogModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return MemberPointLogModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      type: MemberPointLogType.fromValue((data['type'] ?? '').toString()),
      points: _intFromValue(data['points']),
      balanceBefore: _intFromValue(data['balanceBefore']),
      balanceAfter: _intFromValue(data['balanceAfter']),
      reason: (data['reason'] ?? '').toString(),
      operatorUid: (data['operatorUid'] ?? '').toString(),
      sourceId: (data['sourceId'] ?? '').toString(),
      bookingId: (data['bookingId'] ?? '').toString(),
      rewardId: (data['rewardId'] ?? '').toString(),
      couponId: (data['couponId'] ?? '').toString(),
      redemptionId: (data['redemptionId'] ?? '').toString(),
      expireAt: _dateTimeFromValue(data['expireAt']),
      note: (data['note'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
    );
  }

  MemberPointLogModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    MemberPointLogType? type,
    int? points,
    int? balanceBefore,
    int? balanceAfter,
    String? reason,
    String? operatorUid,
    String? sourceId,
    String? bookingId,
    String? rewardId,
    String? couponId,
    String? redemptionId,
    DateTime? expireAt,
    String? note,
    DateTime? createdAt,
    bool clearExpireAt = false,
  }) {
    return MemberPointLogModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      points: points ?? this.points,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      reason: reason ?? this.reason,
      operatorUid: operatorUid ?? this.operatorUid,
      sourceId: sourceId ?? this.sourceId,
      bookingId: bookingId ?? this.bookingId,
      rewardId: rewardId ?? this.rewardId,
      couponId: couponId ?? this.couponId,
      redemptionId: redemptionId ?? this.redemptionId,
      expireAt: clearExpireAt ? null : expireAt ?? this.expireAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum MemberPointLogType {
  bookingEarned('bookingEarned'),
  manualAdded('manualAdded'),
  manualDeducted('manualDeducted'),
  rewardExchange('rewardExchange'),
  refunded('refunded'),
  expired('expired'),
  cancelled('cancelled');

  const MemberPointLogType(this.value);

  final String value;

  /// 前台與後台顯示使用的中文名稱
  String get label {
    switch (this) {
      case MemberPointLogType.bookingEarned:
        return '完成住宿獲得點數';

      case MemberPointLogType.manualAdded:
        return '店家手動增加';

      case MemberPointLogType.manualDeducted:
        return '店家手動扣除';

      case MemberPointLogType.rewardExchange:
        return '兌換優惠';

      case MemberPointLogType.refunded:
        return '點數退回';

      case MemberPointLogType.expired:
        return '點數到期';

      case MemberPointLogType.cancelled:
        return '點數取消';
    }
  }

  static MemberPointLogType fromValue(String value) {
    for (final MemberPointLogType type in values) {
      if (type.value == value) {
        return type;
      }
    }

    return MemberPointLogType.manualAdded;
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
