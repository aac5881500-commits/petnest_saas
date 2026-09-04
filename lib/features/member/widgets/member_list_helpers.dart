// lib/features/member/widgets/member_list_helpers.dart
// 會員列表純函式：優惠券分類、點數流水篩選、訂單進行中判斷。

import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';

class MemberCouponGroups {
  const MemberCouponGroups({
    required this.available,
    required this.reserved,
    required this.used,
    required this.other,
  });

  final List<MemberCouponModel> available;
  final List<MemberCouponModel> reserved;
  final List<MemberCouponModel> used;
  final List<MemberCouponModel> other;

  static MemberCouponGroups fromList(List<MemberCouponModel> coupons) {
    final List<MemberCouponModel> available = <MemberCouponModel>[];
    final List<MemberCouponModel> reserved = <MemberCouponModel>[];
    final List<MemberCouponModel> used = <MemberCouponModel>[];
    final List<MemberCouponModel> other = <MemberCouponModel>[];
    for (final MemberCouponModel coupon in coupons) {
      if (coupon.canUseNow) {
        available.add(coupon);
      } else if (coupon.status == MemberCouponStatus.reserved) {
        reserved.add(coupon);
      } else if (coupon.status == MemberCouponStatus.used ||
          coupon.isUsageLimitReached) {
        used.add(coupon);
      } else {
        other.add(coupon);
      }
    }
    return MemberCouponGroups(
      available: available,
      reserved: reserved,
      used: used,
      other: other,
    );
  }
}

class MemberPointLogFilter {
  MemberPointLogFilter._();

  static const String all = 'all';
  static const String earned = 'earned';
  static const String used = 'used';
  static const String expired = 'expired';

  static List<MemberPointLogModel> apply({
    required List<MemberPointLogModel> logs,
    required String filter,
  }) {
    switch (filter) {
      case earned:
        return logs
            .where(
              (MemberPointLogModel log) =>
                  log.points > 0 && log.type != MemberPointLogType.expired,
            )
            .toList();
      case used:
        return logs
            .where(
              (MemberPointLogModel log) =>
                  log.points < 0 && log.type != MemberPointLogType.expired,
            )
            .toList();
      case expired:
        return logs
            .where(
              (MemberPointLogModel log) =>
                  log.type == MemberPointLogType.expired,
            )
            .toList();
      default:
        return logs;
    }
  }

  static ({int points, DateTime date})? nearestExpiry(
    List<MemberPointLogModel> logs, {
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    DateTime? nearest;
    int points = 0;
    for (final MemberPointLogModel log in logs) {
      final DateTime? expireAt = log.expireAt;
      if (expireAt == null || !expireAt.isAfter(current) || log.points <= 0) {
        continue;
      }
      if (nearest == null || expireAt.isBefore(nearest)) {
        nearest = expireAt;
        points = log.points;
      } else if (expireAt.year == nearest.year &&
          expireAt.month == nearest.month &&
          expireAt.day == nearest.day) {
        points += log.points;
      }
    }
    if (nearest == null) {
      return null;
    }
    return (points: points, date: nearest);
  }
}

class MemberBookingFilters {
  MemberBookingFilters._();

  static const String all = 'all';
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static bool matches(String filter, String status) {
    switch (filter) {
      case completed:
        return status == 'completed';
      case cancelled:
        return status == 'cancelled';
      case active:
        return status != 'completed' && status != 'cancelled';
      default:
        return true;
    }
  }

  static bool isActiveStatus(String status) {
    return matches(active, status);
  }
}
