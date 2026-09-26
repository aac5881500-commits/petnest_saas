// 檔案名稱：lib/features/admin/pages/admin_point_center_stats.dart
// 功能說明：點數兌換中心的 KPI、成效統計、篩選與顯示文案。
// 只讀既有資料，不改點數扣除、退點、庫存與核銷邏輯。

import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';

enum PointCenterSection { rewards, pending, history, analytics, ledger }

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

/// 點數流水的類型篩選。all 表示不限類型。
enum PointLedgerTypeFilter {
  all,
  bookingEarned,
  bookingSpent,
  bookingAdjusted,
  manualAdded,
  manualDeducted,
  rewardExchange,
  refunded,
  expired,
  cancelled,
}

enum PointLedgerDirectionFilter { all, increase, decrease }

const String pointMemberUnavailableLabel = '會員資料已不可用';

/// 頂部 4 張 KPI 卡的真實數字。
class PointCenterKpi {
  const PointCenterKpi({
    required this.enabledRewards,
    required this.monthExchangeCount,
    required this.pendingPickupCount,
    required this.monthPointsSpent,
    required this.monthCouponIssued,
    required this.monthPickedUp,
  });

  final int enabledRewards;
  final int monthExchangeCount;
  final int pendingPickupCount;
  final int monthPointsSpent;

  /// 本月數位券兌換且已寫入 couponId。
  final int monthCouponIssued;

  /// 本月實體商品完成交付核銷。
  final int monthPickedUp;
}

PointCenterKpi summarizePointCenterKpi({
  required List<PointRewardModel> rewards,
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRedemptionModel> redemptions,
  required DateTime now,
}) {
  var monthExchangeCount = 0;
  var monthPointsSpent = 0;
  var monthCouponIssued = 0;
  for (final MemberPointLogModel log in exchangeLogs) {
    if (log.type != MemberPointLogType.rewardExchange) {
      continue;
    }
    if (!_isSameMonth(log.createdAt, now)) {
      continue;
    }
    monthExchangeCount += 1;
    monthPointsSpent += log.points.abs();
    if (log.couponId.trim().isNotEmpty) {
      monthCouponIssued += 1;
    }
  }
  var monthPickedUp = 0;
  var pendingPickupCount = 0;
  for (final PointRedemptionModel item in redemptions) {
    if (item.status == PointRedemptionStatus.pendingPickup) {
      pendingPickupCount += 1;
    }
    final DateTime? pickedUpAt = item.pickedUpAt;
    if (item.status == PointRedemptionStatus.pickedUp &&
        pickedUpAt != null &&
        _isSameMonth(pickedUpAt, now)) {
      monthPickedUp += 1;
    }
  }
  return PointCenterKpi(
    enabledRewards: rewards
        .where((PointRewardModel item) => item.enabled)
        .length,
    monthExchangeCount: monthExchangeCount,
    pendingPickupCount: pendingPickupCount,
    monthPointsSpent: monthPointsSpent,
    monthCouponIssued: monthCouponIssued,
    monthPickedUp: monthPickedUp,
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
    required this.issuedCount,
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

  /// 數位券已寫入 couponId 的筆數。
  final int issuedCount;

  String get channelLabel => isPhysical ? '店內自取' : '數位券';

  String get resultLabel {
    if (isPhysical) {
      return '已兌換 $exchangeCount・待核銷 $pendingCount・'
          '已核銷 $pickedUpCount・取消 $cancelledCount';
    }
    return '已兌換 $exchangeCount・已發券 $issuedCount';
  }

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
    required this.monthCouponIssuedCount,
    required this.couponIssuedCount,
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
  final int monthCouponIssuedCount;

  /// 全部數位券兌換且 couponId 不為空。
  final int couponIssuedCount;
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
  var totalExchangeCount = 0;
  var totalPointsSpent = 0;
  var monthExchangeCount = 0;
  var monthCouponIssuedCount = 0;
  var couponIssuedCount = 0;
  for (final MemberPointLogModel log in exchangeLogs) {
    if (log.type != MemberPointLogType.rewardExchange) {
      continue;
    }
    totalExchangeCount += 1;
    totalPointsSpent += log.points.abs();
    final bool issued = log.couponId.trim().isNotEmpty;
    if (issued) {
      couponIssuedCount += 1;
    }
    if (_isSameMonth(log.createdAt, now)) {
      monthExchangeCount += 1;
      if (issued) {
        monthCouponIssuedCount += 1;
      }
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
    totalExchangeCount: totalExchangeCount,
    totalPointsSpent: totalPointsSpent,
    monthExchangeCount: monthExchangeCount,
    monthPickedUpCount: monthPickedUpCount,
    monthCouponIssuedCount: monthCouponIssuedCount,
    couponIssuedCount: couponIssuedCount,
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

  final Map<String, int> issued = <String, int>{};
  for (final MemberPointLogModel log in exchangeLogs) {
    if (log.couponId.trim().isEmpty) {
      continue;
    }
    final String key = log.rewardId.trim();
    if (key.isEmpty) {
      continue;
    }
    issued[key] = (issued[key] ?? 0) + 1;
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
      isPhysical:
          !(reward?.isCouponReward ?? false) &&
          ((reward?.isPhysicalProduct ?? false) || (pending[key] ?? 0) > 0),
      pickedUpCount: pickedUp[key] ?? 0,
      pendingCount: pending[key] ?? 0,
      cancelledCount: cancelled[key] ?? 0,
      issuedCount: issued[key] ?? 0,
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
    this.couponName = '',
    this.redemption,
  });

  final MemberPointLogModel log;
  final String rewardId;
  final String rewardName;
  final bool isPhysical;
  final PointDeliveryState delivery;
  final String memberLabel;

  /// 數位券對應的優惠券名稱。實體商品為空。
  final String couponName;
  final PointRedemptionModel? redemption;

  int get pointsSpent => log.points.abs();

  DateTime get createdAt => log.createdAt;
}

List<PointExchangeRow> buildPointExchangeRows({
  required List<MemberPointLogModel> exchangeLogs,
  required List<PointRewardModel> rewards,
  required List<PointRedemptionModel> redemptions,
  String Function(String userId)? memberLabelOf,
  Map<String, String> templateNames = const <String, String>{},
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
    final bool isPhysical = _rowIsPhysical(
      reward: reward,
      redemption: redemption,
    );
    final String templateId = (reward?.couponTemplateId ?? '').trim();
    final String templateName = (templateNames[templateId] ?? '').trim();
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
      couponName: isPhysical
          ? ''
          : (templateName.isNotEmpty
                ? templateName
                : (reward?.name ?? '').trim()),
      redemption: isPhysical ? redemption : null,
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

bool _rowIsPhysical({
  required PointRewardModel? reward,
  required PointRedemptionModel? redemption,
}) {
  if (reward?.isCouponReward ?? false) {
    return false;
  }
  if (redemption != null) {
    return true;
  }
  return reward?.isPhysicalProduct ?? false;
}

/// 兌換紀錄結果文案。數位券固定為已發送，不出現領取碼。
String pointExchangeResultLabel(PointExchangeRow row) {
  if (!row.isPhysical || row.delivery == PointDeliveryState.couponIssued) {
    return '數位優惠券・已發送';
  }
  return pointDeliveryLabel(row.delivery);
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

/// 店主點數流水的本月總覽。退點不計入發放。
class PointLedgerKpi {
  const PointLedgerKpi({
    required this.monthGranted,
    required this.monthMemberSpent,
    required this.monthExchangeSpent,
    required this.manualIncrease,
    required this.manualDecrease,
  });

  final int monthGranted;
  final int monthMemberSpent;
  final int monthExchangeSpent;
  final int manualIncrease;
  final int manualDecrease;

  String get manualAdjustLabel => '+$manualIncrease／-$manualDecrease';
}

PointLedgerKpi summarizePointLedger({
  required List<MemberPointLogModel> logs,
  required DateTime now,
}) {
  var granted = 0;
  var memberSpent = 0;
  var exchangeSpent = 0;
  var manualIncrease = 0;
  var manualDecrease = 0;
  for (final MemberPointLogModel log in logs) {
    if (!_isSameMonth(log.createdAt, now)) {
      continue;
    }
    switch (log.type) {
      case MemberPointLogType.bookingEarned:
        if (log.points > 0) {
          granted += log.points;
        }
        break;
      case MemberPointLogType.manualAdded:
        if (log.points > 0) {
          granted += log.points;
          manualIncrease += log.points;
        } else if (log.points < 0) {
          manualDecrease += log.points.abs();
        }
        break;
      case MemberPointLogType.bookingAdjusted:
        if (log.points > 0) {
          granted += log.points;
          manualIncrease += log.points;
        } else if (log.points < 0) {
          manualDecrease += log.points.abs();
        }
        break;
      case MemberPointLogType.manualDeducted:
        if (log.points < 0) {
          manualDecrease += log.points.abs();
        } else if (log.points > 0) {
          manualIncrease += log.points;
        }
        break;
      case MemberPointLogType.bookingSpent:
        memberSpent += log.points.abs();
        break;
      case MemberPointLogType.rewardExchange:
        exchangeSpent += log.points.abs();
        break;
      case MemberPointLogType.refunded:
      case MemberPointLogType.expired:
      case MemberPointLogType.cancelled:
        break;
    }
  }
  return PointLedgerKpi(
    monthGranted: granted,
    monthMemberSpent: memberSpent,
    monthExchangeSpent: exchangeSpent,
    manualIncrease: manualIncrease,
    manualDecrease: manualDecrease,
  );
}

class PointLedgerRow {
  const PointLedgerRow({
    required this.log,
    required this.memberLabel,
    required this.operatorLabel,
    required this.rewardName,
  });

  final MemberPointLogModel log;
  final String memberLabel;
  final String operatorLabel;
  final String rewardName;

  bool get opensBooking {
    if (log.bookingId.trim().isEmpty) {
      return false;
    }
    return log.type == MemberPointLogType.bookingEarned ||
        log.type == MemberPointLogType.bookingSpent ||
        log.type == MemberPointLogType.bookingAdjusted;
  }

  bool get opensExchange => log.type == MemberPointLogType.rewardExchange;

  String get relationText {
    switch (log.type) {
      case MemberPointLogType.bookingEarned:
      case MemberPointLogType.bookingSpent:
      case MemberPointLogType.bookingAdjusted:
        return opensBooking ? '查看訂單' : log.reason.trim();
      case MemberPointLogType.rewardExchange:
        return rewardName.trim().isEmpty ? '查看兌換紀錄' : rewardName.trim();
      case MemberPointLogType.manualAdded:
      case MemberPointLogType.manualDeducted:
        final String reason = log.reason.trim();
        if (reason.isEmpty) {
          return '操作者 $operatorLabel';
        }
        return '操作者 $operatorLabel・$reason';
      case MemberPointLogType.refunded:
      case MemberPointLogType.cancelled:
      case MemberPointLogType.expired:
        final String reason = log.reason.trim();
        return reason.isEmpty ? pointLedgerTypeLabel(log.type) : reason;
    }
  }
}

List<PointLedgerRow> buildPointLedgerRows({
  required List<MemberPointLogModel> logs,
  required List<PointRewardModel> rewards,
  required List<PointRedemptionModel> redemptions,
  String Function(String userId)? memberLabelOf,
  String Function(String operatorUid)? operatorLabelOf,
}) {
  final Map<String, PointRewardModel> rewardById = <String, PointRewardModel>{
    for (final PointRewardModel reward in rewards) reward.id: reward,
  };
  return logs.map((MemberPointLogModel log) {
    final PointRedemptionModel? redemption = _redemptionOf(log, redemptions);
    return PointLedgerRow(
      log: log,
      memberLabel: pointMemberLabelOf(
        redemption: redemption,
        userId: log.userId,
        lookup: memberLabelOf,
      ),
      operatorLabel: pointOperatorLabel(
        operatorUid: log.operatorUid,
        email: operatorLabelOf?.call(log.operatorUid) ?? '',
      ),
      rewardName: pointRewardNameOf(
        rewardId: log.rewardId,
        reward: rewardById[log.rewardId.trim()],
        reason: log.reason,
        redemptions: redemptions,
        redemption: redemption,
      ),
    );
  }).toList();
}

List<PointLedgerRow> filterPointLedgerRows({
  required List<PointLedgerRow> rows,
  required DateTime now,
  PointHistoryTimeFilter time = PointHistoryTimeFilter.days30,
  PointLedgerTypeFilter type = PointLedgerTypeFilter.all,
  PointLedgerDirectionFilter direction = PointLedgerDirectionFilter.all,
  String keyword = '',
}) {
  final DateTime? start = switch (time) {
    PointHistoryTimeFilter.days30 => now.subtract(const Duration(days: 30)),
    PointHistoryTimeFilter.days90 => now.subtract(const Duration(days: 90)),
    PointHistoryTimeFilter.all => null,
  };
  final String query = keyword.trim().toLowerCase();
  return rows.where((PointLedgerRow row) {
    if (start != null && row.log.createdAt.isBefore(start)) {
      return false;
    }
    if (type != PointLedgerTypeFilter.all &&
        row.log.type != _ledgerTypeOf(type)) {
      return false;
    }
    if (direction == PointLedgerDirectionFilter.increase &&
        row.log.points <= 0) {
      return false;
    }
    if (direction == PointLedgerDirectionFilter.decrease &&
        row.log.points >= 0) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    final String haystack =
        '${row.memberLabel} ${row.rewardName} ${row.operatorLabel} '
                '${row.log.reason} ${pointLedgerTypeLabel(row.log.type)}'
            .toLowerCase();
    return haystack.contains(query);
  }).toList();
}

String pointLedgerTypeLabel(MemberPointLogType type) {
  switch (type) {
    case MemberPointLogType.bookingEarned:
      return '完成訂單獲得';
    case MemberPointLogType.bookingSpent:
      return '訂單折抵';
    case MemberPointLogType.bookingAdjusted:
      return '訂單調整';
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

String pointLedgerTypeFilterLabel(PointLedgerTypeFilter filter) {
  if (filter == PointLedgerTypeFilter.all) {
    return '全部類型';
  }
  return pointLedgerTypeLabel(_ledgerTypeOf(filter));
}

/// 操作者只顯示 email。系統自動異動顯示「系統」，找不到時不露出 UID。
String pointOperatorLabel({required String operatorUid, String email = ''}) {
  final String id = operatorUid.trim();
  if (id.isEmpty || id == 'system') {
    return '系統';
  }
  final String mail = email.trim();
  if (mail.isEmpty || mail == id) {
    return '操作者資料已不可用';
  }
  return mail;
}

String pointLedgerPointsText(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}

MemberPointLogType _ledgerTypeOf(PointLedgerTypeFilter filter) {
  switch (filter) {
    case PointLedgerTypeFilter.all:
    case PointLedgerTypeFilter.bookingEarned:
      return MemberPointLogType.bookingEarned;
    case PointLedgerTypeFilter.bookingSpent:
      return MemberPointLogType.bookingSpent;
    case PointLedgerTypeFilter.bookingAdjusted:
      return MemberPointLogType.bookingAdjusted;
    case PointLedgerTypeFilter.manualAdded:
      return MemberPointLogType.manualAdded;
    case PointLedgerTypeFilter.manualDeducted:
      return MemberPointLogType.manualDeducted;
    case PointLedgerTypeFilter.rewardExchange:
      return MemberPointLogType.rewardExchange;
    case PointLedgerTypeFilter.refunded:
      return MemberPointLogType.refunded;
    case PointLedgerTypeFilter.expired:
      return MemberPointLogType.expired;
    case PointLedgerTypeFilter.cancelled:
      return MemberPointLogType.cancelled;
  }
}

PointRedemptionModel? _redemptionOf(
  MemberPointLogModel log,
  List<PointRedemptionModel> redemptions,
) {
  final String id = log.redemptionId.trim();
  if (id.isEmpty) {
    return null;
  }
  for (final PointRedemptionModel item in redemptions) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}
