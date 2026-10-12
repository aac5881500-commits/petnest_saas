// 檔案名稱：lib/core/services/shop_plan_access.dart
// 功能說明：依下一期生效日決定目前真正使用的方案與模組

import 'package:petnest_saas/core/constants/shop_modules.dart';

class ShopPlanAccess {
  static String taipeiToday([DateTime? now]) {
    final DateTime taipei = (now ?? DateTime.now())
        .toUtc()
        .add(const Duration(hours: 8));
    final String month = taipei.month.toString().padLeft(2, '0');
    final String day = taipei.day.toString().padLeft(2, '0');
    return '${taipei.year}-$month-$day';
  }

  static String effectivePlan(
    Map<String, dynamic>? shop, {
    String? today,
  }) {
    return _resolve(shop, today ?? taipeiToday()).effectivePlan;
  }

  static bool scheduleApplied(
    Map<String, dynamic>? shop, {
    String? today,
  }) {
    return _resolve(shop, today ?? taipeiToday()).applied;
  }

  static String pendingNextPlan(Map<String, dynamic>? shop, {String? today}) {
    return _resolve(shop, today ?? taipeiToday()).nextPlan;
  }

  static String pendingNextStarts(
    Map<String, dynamic>? shop, {
    String? today,
  }) {
    return _resolve(shop, today ?? taipeiToday()).nextStarts;
  }

  static List<String> modulesFor(Map<String, dynamic>? shop, String plan) {
    final String locked =
        shop?['lockedModule']?.toString().trim().isNotEmpty == true
        ? shop!['lockedModule'].toString()
        : shop?['businessType']?.toString() ?? ShopModules.catHotel;
    final List<String> base = plan == 'pro'
        ? ShopModules.proEnabledModules()
        : ShopModules.lockedPlanModules(locked);
    final List<dynamic> existing = shop?['enabledModules'] is List
        ? shop!['enabledModules'] as List<dynamic>
        : const <dynamic>[];
    for (final dynamic item in existing) {
      final String name = item.toString();
      if ((name == ShopModules.daycare || name == ShopModules.inventory) &&
          !base.contains(name)) {
        base.add(name);
      }
    }
    return base;
  }

  static _PlanSchedule _resolve(Map<String, dynamic>? shop, String today) {
    final String current = shop?['plan']?.toString() ?? '';
    final List<_QueuedPlan> queued = <_QueuedPlan>[];
    final String nextPlan = shop?['nextPlan']?.toString() ?? '';
    final String nextStarts = shop?['nextPlanStarts']?.toString() ?? '';
    final String followingPlan = shop?['followingPlan']?.toString() ?? '';
    final String followingStarts =
        shop?['followingPlanStarts']?.toString() ?? '';
    if (nextPlan.isNotEmpty && nextStarts.isNotEmpty) {
      queued.add(_QueuedPlan(nextPlan, nextStarts));
    }
    if (followingPlan.isNotEmpty && followingStarts.isNotEmpty) {
      queued.add(_QueuedPlan(followingPlan, followingStarts));
    }
    queued.sort((left, right) => left.starts.compareTo(right.starts));
    String plan = current;
    final List<_QueuedPlan> future = <_QueuedPlan>[];
    for (final _QueuedPlan item in queued) {
      if (item.starts.compareTo(today) <= 0) {
        plan = item.plan;
      } else {
        future.add(item);
      }
    }
    return _PlanSchedule(
      effectivePlan: plan.isEmpty ? 'free' : plan,
      applied: plan != current,
      nextPlan: future.isEmpty ? '' : future.first.plan,
      nextStarts: future.isEmpty ? '' : future.first.starts,
    );
  }
}

class _QueuedPlan {
  const _QueuedPlan(this.plan, this.starts);

  final String plan;
  final String starts;
}

class _PlanSchedule {
  const _PlanSchedule({
    required this.effectivePlan,
    required this.applied,
    required this.nextPlan,
    required this.nextStarts,
  });

  final String effectivePlan;
  final bool applied;
  final String nextPlan;
  final String nextStarts;
}
