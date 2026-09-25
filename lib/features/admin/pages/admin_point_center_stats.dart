// 檔案名稱：lib/features/admin/pages/admin_point_center_stats.dart
// 功能說明：點數兌換中心的 KPI、成效統計、篩選與顯示文案。
// 只讀既有資料，不改點數扣除、退點、庫存與核銷邏輯。

import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';

enum PointCenterSection { rewards, pending, history, analytics }

enum PointRewardTypeFilter { all, coupon, physical }

enum PointRewardStatusFilter { all, enabled, disabled, soldOut }

enum PointHistoryTimeFilter { days30, days90, all }

/// 兌換結果／交付狀態
enum PointDeliveryState {
  couponIssued,
  pendingPickup,
  pickedUp,
  cancelled,
  expired,
  unknown,
}

enum PointDeliveryFilter {
  all,
  couponIssued,
  pendingPickup,
  pickedUp,
  cancelled,
  expired,
}

const String pointMemberUnavailableLabel = '會員資料已不可用';

/// 頂部 4 張 KPI 卡的真實數字。
class PointCenterKpi {
  const PointCenterKpi({
    required this.enabledRewards,
    required this.monthExchangeCount,
    required this.pendingPickupCount,
    required this.monthPointsSpent,
  });

  final int enabledRewards;
  final int monthExchangeCount;
  final int pendingPickupCount;
  final int monthPointsSpent;
}

PointCenterKpi summarizePointCenterKpi({
  required List<PointRewardModel> rewards,
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRedemptionModel> redemptions,
  required DateTime now,
}) {
  var monthExchangeCount = 0;
  var monthPointsSpent = 0;
  for (final MemberPointLogModel log in exchangeLogs) {
    if (!_isSameMonth(log.createdAt, now)) {
      continue;
    }
    monthExchangeCount += 1;
    monthPointsSpent += log.points.abs();
  }
  return PointCenterKpi(
    enabledRewards: rewards
        .where((PointRewardModel item) => item.enabled)
        .length,
    monthExchangeCount: monthExchangeCount,
    pendingPickupCount: redemptions
        .where(
          (PointRedemptionModel item) =>
              item.status == PointRedemptionStatus.pendingPickup,
        )
        .length,
    monthPointsSpent: monthPointsSpent,
  );
}

/// 商品成效排行榜的一列。
class PointRewardRank {
  const PointRewardRank({
    required this.rewardId,
    required this.name,
    required this.exchangeCount,
    required this.pointsSpent,
    required this.totalExchangeLimit,
    required this.exchangedCount,
    required this.isPhysical,
    required this.pickedUpCount,
    required this.pendingCount,
    required this.cancelledCount,
  });

  final String rewardId;
  final String name;
  final int exchangeCount;
  final int pointsSpent;
  final int totalExchangeLimit;
  final int exchangedCount;
  final bool isPhysical;
  final int pickedUpCount;
  final int pendingCount;
  final int cancelledCount;

  bool get hasTotalLimit => totalExchangeLimit > 0;

  String get usageRateLabel {
    return formatPointRate(value: exchangedCount, total: totalExchangeLimit);
  }
}

class PointCenterAnalytics {
  const PointCenterAnalytics({
    required this.totalExchangeCount,
    required this.totalPointsSpent,
    required this.monthExchangeCount,
    required this.monthPickedUpCount,
    required this.pendingPickupCount,
    required this.pickedUpCount,
    required this.cancelledCount,
    required this.expiredCount,
    required this.topRewards,
  });

  final int totalExchangeCount;
  final int totalPointsSpent;
  final int monthExchangeCount;
  final int monthPickedUpCount;
  final int pendingPickupCount;
  final int pickedUpCount;
  final int cancelledCount;
  final int expiredCount;
  final List<PointRewardRank> topRewards;

  int get cancelledOrExpiredCount => cancelledCount + expiredCount;

  int get redemptionTotal =>
      pendingPickupCount + pickedUpCount + cancelledCount + expiredCount;

  bool get hasData => totalExchangeCount > 0 || redemptionTotal > 0;

  /// 分母為 0 時回 0，不做除法。
  double statusShare(int value) {
    if (redemptionTotal <= 0) {
      return 0;
    }
    return value / redemptionTotal;
  }
}

PointCenterAnalytics summarizePointCenterAnalytics({
  required List<PointRewardModel> rewards,
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRedemptionModel> redemptions,
  required DateTime now,
}) {
  var totalPointsSpent = 0;
  var monthExchangeCount = 0;
  for (final MemberPointLogModel log in exchangeLogs) {
    totalPointsSpent += log.points.abs();
    if (_isSameMonth(log.createdAt, now)) {
      monthExchangeCount += 1;
    }
  }

  var pendingPickupCount = 0;
  var pickedUpCount = 0;
  var cancelledCount = 0;
  var expiredCount = 0;
  var monthPickedUpCount = 0;
  for (final PointRedemptionModel item in redemptions) {
    switch (item.status) {
      case PointRedemptionStatus.pendingPickup:
        pendingPickupCount += 1;
        break;
      case PointRedemptionStatus.pickedUp:
        pickedUpCount += 1;
        final DateTime? pickedUpAt = item.pickedUpAt;
        if (pickedUpAt != null && _isSameMonth(pickedUpAt, now)) {
          monthPickedUpCount += 1;
        }
        break;
      case PointRedemptionStatus.cancelled:
        cancelledCount += 1;
        break;
      case PointRedemptionStatus.expired:
        expiredCount += 1;
        break;
    }
  }

  return PointCenterAnalytics(
    totalExchangeCount: exchangeLogs.length,
    totalPointsSpent: totalPointsSpent,
    monthExchangeCount: monthExchangeCount,
    monthPickedUpCount: monthPickedUpCount,
    pendingPickupCount: pendingPickupCount,
    pickedUpCount: pickedUpCount,
    cancelledCount: cancelledCount,
    expiredCount: expiredCount,
    topRewards: rankPointRewards(
      rewards: rewards,
      exchangeLogs: exchangeLogs,
      redemptions: redemptions,
    ),
  );
}

/// 依 rewardId 彙總成效，取前 5 名。
List<PointRewardRank> rankPointRewards({
  required List<PointRewardModel> rewards,
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRedemptionModel> redemptions,
  int limit = 5,
}) {
  final Map<String, PointRewardModel> rewardById = <String, PointRewardModel>{
    for (final PointRewardModel reward in rewards) reward.id: reward,
  };
  final Map<String, int> counts = <String, int>{};
  final Map<String, int> points = <String, int>{};
  final Map<String, String> names = <String, String>{};

  for (final MemberPointLogModel log in exchangeLogs) {
    final String key = log.rewardId.trim();
    if (key.isEmpty) {
      continue;
    }
    counts[key] = (counts[key] ?? 0) + 1;
    points[key] = (points[key] ?? 0) + log.points.abs();
    names.putIfAbsent(
      key,
      () => pointRewardNameOf(
        rewardId: key,
        reward: rewardById[key],
        reason: log.reason,
        redemptions: redemptions,
      ),
    );
  }

  final Map<String, int> pickedUp = <String, int>{};
  final Map<String, int> pending = <String, int>{};
  final Map<String, int> cancelled = <String, int>{};
  for (final PointRedemptionModel item in redemptions) {
    final String key = item.rewardId.trim();
    if (key.isEmpty) {
      continue;
    }
    switch (item.status) {
      case PointRedemptionStatus.pickedUp:
        pickedUp[key] = (pickedUp[key] ?? 0) + 1;
        break;
      case PointRedemptionStatus.pendingPickup:
        pending[key] = (pending[key] ?? 0) + 1;
        break;
      case PointRedemptionStatus.cancelled:
      case PointRedemptionStatus.expired:
        cancelled[key] = (cancelled[key] ?? 0) + 1;
        break;
    }
  }

  final List<PointRewardRank> ranks = counts.keys.map((String key) {
    final PointRewardModel? reward = rewardById[key];
    return PointRewardRank(
      rewardId: key,
      name: names[key] ?? '已刪除商品',
      exchangeCount: counts[key] ?? 0,
      pointsSpent: points[key] ?? 0,
      totalExchangeLimit: reward?.totalExchangeLimit ?? 0,
      exchangedCount: reward?.exchangedCount ?? counts[key] ?? 0,
      isPhysical: reward?.isPhysicalProduct ?? (pending[key] ?? 0) > 0,
      pickedUpCount: pickedUp[key] ?? 0,
      pendingCount: pending[key] ?? 0,
      cancelledCount: cancelled[key] ?? 0,
    );
  }).toList();

  ranks.sort((PointRewardRank a, PointRewardRank b) {
    final int byCount = b.exchangeCount.compareTo(a.exchangeCount);
    if (byCount != 0) {
      return byCount;
    }
    return b.pointsSpent.compareTo(a.pointsSpent);
  });

  return ranks.take(limit).toList();
}

/// 兌換紀錄的一列，先組好再篩選，避免每次 build 重查。
class PointExchangeRow {
  const PointExchangeRow({
    required this.log,
    required this.rewardId,
    required this.rewardName,
    required this.isPhysical,
    required this.delivery,
    required this.memberLabel,
    this.redemption,
  });

  final MemberPointLogModel log;
  final String rewardId;
  final String rewardName;
  final bool isPhysical;
  final PointDeliveryState delivery;
  final String memberLabel;
  final PointRedemptionModel? redemption;

  int get pointsSpent => log.points.abs();

  DateTime get createdAt => log.createdAt;
}

List<PointExchangeRow> buildPointExchangeRows({
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRewardModel> rewards,
  required List<PointRedemptionModel> redemptions,
  String Function(String userId)? memberLabelOf,
}) {
  final Map<String, PointRewardModel> rewardById = <String, PointRewardModel>{
    for (final PointRewardModel reward in rewards) reward.id: reward,
  };
  final Map<String, PointRedemptionModel> redemptionById =
      <String, PointRedemptionModel>{
        for (final PointRedemptionModel item in redemptions) item.id: item,
      };

  return exchangeLogs.map((MemberPointLogModel log) {
    final String rewardId = log.rewardId.trim();
    final PointRewardModel? reward = rewardById[rewardId];
    final PointRedemptionModel? redemption =
        redemptionById[log.redemptionId.trim()];
    final bool isPhysical =
        redemption != null || (reward?.isPhysicalProduct ?? false);
    return PointExchangeRow(
      log: log,
      rewardId: rewardId,
      rewardName: pointRewardNameOf(
        rewardId: rewardId,
        reward: reward,
        reason: log.reason,
        redemptions: redemptions,
        redemption: redemption,
      ),
      isPhysical: isPhysical,
      delivery: pointDeliveryStateOf(
        log: log,
        redemption: redemption,
        isPhysical: isPhysical,
      ),
      memberLabel: pointMemberLabelOf(
        redemption: redemption,
        userId: log.userId,
        lookup: memberLabelOf,
      ),
      redemption: redemption,
    );
  }).toList();
}

List<PointExchangeRow> filterPointExchangeRows({
  required List<PointExchangeRow> rows,
  required DateTime now,
  PointHistoryTimeFilter time = PointHistoryTimeFilter.days30,
  String rewardId = '',
  PointRewardTypeFilter type = PointRewardTypeFilter.all,
  PointDeliveryFilter delivery = PointDeliveryFilter.all,
  String keyword = '',
}) {
  final DateTime? start = switch (time) {
    PointHistoryTimeFilter.days30 => now.subtract(const Duration(days: 30)),
    PointHistoryTimeFilter.days90 => now.subtract(const Duration(days: 90)),
    PointHistoryTimeFilter.all => null,
  };
  final String query = keyword.trim().toLowerCase();

  return rows.where((PointExchangeRow row) {
    if (start != null && row.createdAt.isBefore(start)) {
      return false;
    }
    if (rewardId.trim().isNotEmpty && row.rewardId != rewardId.trim()) {
      return false;
    }
    if (type == PointRewardTypeFilter.coupon && row.isPhysical) {
      return false;
    }
    if (type == PointRewardTypeFilter.physical && !row.isPhysical) {
      return false;
    }
    if (!_matchesDelivery(row.delivery, delivery)) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return '${row.rewardName} ${row.memberLabel}'.toLowerCase().contains(query);
  }).toList();
}

List<PointRewardModel> filterPointRewards({
  required List<PointRewardModel> rewards,
  String keyword = '',
  PointRewardTypeFilter type = PointRewardTypeFilter.all,
  PointRewardStatusFilter status = PointRewardStatusFilter.all,
}) {
  final String query = keyword.trim().toLowerCase();
  return rewards.where((PointRewardModel reward) {
    if (type == PointRewardTypeFilter.coupon && !reward.isCouponReward) {
      return false;
    }
    if (type == PointRewardTypeFilter.physical && !reward.isPhysicalProduct) {
      return false;
    }
    switch (status) {
      case PointRewardStatusFilter.all:
        break;
      case PointRewardStatusFilter.enabled:
        if (!reward.enabled) {
          return false;
        }
        break;
      case PointRewardStatusFilter.disabled:
        if (reward.enabled) {
          return false;
        }
        break;
      case PointRewardStatusFilter.soldOut:
        if (!reward.isSoldOut) {
          return false;
        }
        break;
    }
    if (query.isEmpty) {
      return true;
    }
    return reward.name.toLowerCase().contains(query);
  }).toList();
}

bool _matchesDelivery(PointDeliveryState state, PointDeliveryFilter filter) {
  switch (filter) {
    case PointDeliveryFilter.all:
      return true;
    case PointDeliveryFilter.couponIssued:
      return state == PointDeliveryState.couponIssued;
    case PointDeliveryFilter.pendingPickup:
      return state == PointDeliveryState.pendingPickup;
    case PointDeliveryFilter.pickedUp:
      return state == PointDeliveryState.pickedUp;
    case PointDeliveryFilter.cancelled:
      return state == PointDeliveryState.cancelled;
    case PointDeliveryFilter.expired:
      return state == PointDeliveryState.expired;
  }
}

PointDeliveryState pointDeliveryStateOf({
  required MemberPointLogModel log,
  required bool isPhysical,
  PointRedemptionModel? redemption,
}) {
  if (redemption != null) {
    switch (redemption.status) {
      case PointRedemptionStatus.pendingPickup:
        return PointDeliveryState.pendingPickup;
      case PointRedemptionStatus.pickedUp:
        return PointDeliveryState.pickedUp;
      case PointRedemptionStatus.cancelled:
        return PointDeliveryState.cancelled;
      case PointRedemptionStatus.expired:
        return PointDeliveryState.expired;
    }
  }
  if (log.couponId.trim().isNotEmpty) {
    return PointDeliveryState.couponIssued;
  }
  if (!isPhysical) {
    return PointDeliveryState.couponIssued;
  }
  return PointDeliveryState.unknown;
}

String pointDeliveryLabel(PointDeliveryState state) {
  switch (state) {
    case PointDeliveryState.couponIssued:
      return '已發券';
    case PointDeliveryState.pendingPickup:
      return '待領取';
    case PointDeliveryState.pickedUp:
      return '已核銷';
    case PointDeliveryState.cancelled:
      return '已取消';
    case PointDeliveryState.expired:
      return '已過期';
    case PointDeliveryState.unknown:
      return '無交付紀錄';
  }
}

String pointRewardNameOf({
  required String rewardId,
  PointRewardModel? reward,
  String reason = '',
  List<PointRedemptionModel> redemptions = const <PointRedemptionModel>[],
  PointRedemptionModel? redemption,
}) {
  final String fromReward = (reward?.name ?? '').trim();
  if (fromReward.isNotEmpty) {
    return fromReward;
  }
  final String fromRedemption = (redemption?.rewardName ?? '').trim();
  if (fromRedemption.isNotEmpty) {
    return fromRedemption;
  }
  if (rewardId.trim().isNotEmpty) {
    for (final PointRedemptionModel item in redemptions) {
      if (item.rewardId.trim() == rewardId.trim() &&
          item.rewardName.trim().isNotEmpty) {
        return item.rewardName.trim();
      }
    }
  }
  final String fromReason = reason
      .trim()
      .replaceFirst('兌換「', '')
      .replaceFirst('」', '')
      .trim();
  if (fromReason.isNotEmpty) {
    return fromReason;
  }
  return '點數兌換商品';
}

/// 會員顯示名稱。優先使用兌換紀錄快照，絕不顯示 UID。
String pointMemberLabelOf({
  PointRedemptionModel? redemption,
  String userId = '',
  String Function(String userId)? lookup,
}) {
  final String name = (redemption?.memberName ?? '').trim();
  if (name.isNotEmpty) {
    return name;
  }
  final String phone = (redemption?.memberPhone ?? '').trim();
  if (phone.isNotEmpty) {
    return phone;
  }
  final String id = userId.trim();
  if (id.isEmpty || lookup == null) {
    return pointMemberUnavailableLabel;
  }
  final String resolved = lookup(id).trim();
  return resolved.isEmpty ? pointMemberUnavailableLabel : resolved;
}

String pointProfileLabel(Map<String, dynamic>? data) {
  if (data == null) {
    return pointMemberUnavailableLabel;
  }
  final String name = (data['displayName'] ?? data['name'] ?? '')
      .toString()
      .trim();
  if (name.isNotEmpty) {
    return name;
  }
  final String email = (data['email'] ?? '').toString().trim();
  if (email.isNotEmpty) {
    return email;
  }
  return pointMemberUnavailableLabel;
}

/// 已有會員兌換過的商品一律不能刪除，只能下架。
bool canDeletePointReward(PointRewardModel reward) {
  return reward.exchangedCount <= 0;
}

String pointRewardTypeLabel(PointRewardModel reward) {
  if (reward.isPhysicalProduct) {
    return '實體商品・店內領取';
  }
  if (reward.isCouponReward) {
    return '優惠券';
  }
  return '其他';
}

/// 已兌換／總上限，例如「4 / 不限」或「4 / 20」。
String pointExchangeLimitLabel(PointRewardModel reward) {
  final String total = reward.hasTotalExchangeLimit
      ? '${reward.totalExchangeLimit}'
      : '不限';
  return '${reward.exchangedCount} / $total';
}

/// 非中央庫存的實體商品剩餘量。不限時不可寫成沒有庫存。
String pointRewardStockLabel(PointRewardModel reward) {
  if (reward.usesCentralInventory) {
    return '連動庫存';
  }
  if (!reward.hasStockLimit) {
    return '不限兌換數量';
  }
  return '剩餘 ${reward.remainingStock ?? 0} 份';
}

String formatPointRate({required int value, required int total}) {
  if (total <= 0) {
    return '不限';
  }
  final double percent = value * 100 / total;
  final String text = percent == percent.roundToDouble()
      ? percent.toStringAsFixed(0)
      : percent.toStringAsFixed(1);
  return '$text%';
}

String formatPointDateTime(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}/$month/$day $hour:$minute';
}

String formatPointDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}

bool _isSameMonth(DateTime value, DateTime now) {
  return value.year == now.year && value.month == now.month;
}
