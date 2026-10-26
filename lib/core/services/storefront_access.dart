// 商城資格由目前付費方案決定，不受 enabledModules 影響。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_plan_access.dart';

class StorefrontAccess {
  StorefrontAccess._();

  static bool hasEntitlement(Map<String, dynamic>? shop, {DateTime? now}) {
    if (shop == null || shop['deletionState'] == 'deleting') return false;
    final instant = now ?? DateTime.now();
    final today = ShopPlanAccess.taipeiToday(instant);
    final plan = ShopPlanAccess.effectivePlan(shop, today: today);
    if (plan != 'basic' && plan != 'pro') return false;
    final date = shop['paidUntilDate'];
    if (date is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      return date.compareTo(today) >= 0;
    }
    final until = shop['paidUntil'];
    final end = until is Timestamp
        ? until.toDate()
        : until is DateTime
        ? until
        : null;
    return end != null && end.isAfter(instant);
  }

  // 相容既有入口；此名稱不再表示可勾選的商城模組。
  static bool isModuleEnabled(Map<String, dynamic>? shop) =>
      hasEntitlement(shop);

  static String businessStatus(Map<String, dynamic>? settings) {
    final explicit = settings?['businessStatus'];
    if (explicit == 'preparing' || explicit == 'open' || explicit == 'paused') {
      return explicit as String;
    }
    // 未設定的新商城先準備；已有商城沿用原本接單狀態。
    if (settings == null ||
        (!settings.containsKey('storefrontEnabled') &&
            !settings.containsKey('acceptNewOrders'))) {
      return 'preparing';
    }
    if (settings['storefrontEnabled'] == false) return 'preparing';
    return settings['acceptNewOrders'] == false ? 'paused' : 'open';
  }

  static bool isStorefrontEnabled(Map<String, dynamic>? settings) =>
      settings != null &&
      settings['storefrontEnabled'] != false &&
      businessStatus(settings) != 'preparing';

  static bool isStorefrontOpen({
    required Map<String, dynamic>? shop,
    Map<String, dynamic>? settings,
    DateTime? now,
  }) => hasEntitlement(shop, now: now) && isStorefrontEnabled(settings);

  static bool canAcceptOrders({
    required Map<String, dynamic>? shop,
    Map<String, dynamic>? settings,
    DateTime? now,
  }) =>
      isStorefrontOpen(shop: shop, settings: settings, now: now) &&
      businessStatus(settings) == 'open' &&
      settings?['acceptNewOrders'] != false;
}
