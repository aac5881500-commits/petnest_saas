// lib/core/services/shop_plan_service.dart
// 💳 店家方案規則服務
// 功能：集中判斷免費版 / 999 方案可用功能與限制

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_plan_keys.dart';

class ShopPlanService {
  static String planOf(Map<String, dynamic>? shop) {
    return (shop?['plan'] ?? ShopPlanKeys.free).toString();
  }

  static bool isFree(Map<String, dynamic>? shop) {
    return planOf(shop) == ShopPlanKeys.free;
  }

  static bool isPro999(Map<String, dynamic>? shop) {
    return planOf(shop) == ShopPlanKeys.pro999;
  }

  static bool isPaidActive(Map<String, dynamic>? shop) {
    final plan = planOf(shop);
    final paidUntil = shop?['paidUntil'];

    if (plan == ShopPlanKeys.free) return false;
    if (plan != 'basic' && plan != 'pro999') return false;
    if (paidUntil is! Timestamp) return false;

    return paidUntil.toDate().isAfter(DateTime.now());
  }

  // 免費版仍可用
  static bool canUseMemberManage(Map<String, dynamic>? shop) => true;
  static bool canUsePlatformNotification(Map<String, dynamic>? shop) => true;
  static bool canUseContactPlatform(Map<String, dynamic>? shop) => true;
  static bool canUseManualBooking(Map<String, dynamic>? shop) => true;
  static bool canUseRoomDashboard(Map<String, dynamic>? shop) => true;
  static bool canUseBookingSettings(Map<String, dynamic>? shop) => true;
  static bool canUseRoomTypes(Map<String, dynamic>? shop) => true;
  static bool canUseRooms(Map<String, dynamic>? shop) => true;
  static bool canUseAddons(Map<String, dynamic>? shop) => true;
  static bool canViewPolicyLogs(Map<String, dynamic>? shop) => true;

  // 前台內容
  static bool canUseBusinessInfo(Map<String, dynamic>? shop) =>
      isPaidActive(shop);

  static bool canUseShopBanner(Map<String, dynamic>? shop) =>
      isPaidActive(shop);

  static bool canUseEnvironment(Map<String, dynamic>? shop) =>
      isPaidActive(shop);

  static bool canUseAboutUs(Map<String, dynamic>? shop) => isPaidActive(shop);

  // 999 才開
  static bool canUsePublicPage(Map<String, dynamic>? shop) =>
      isPaidActive(shop);
  static bool canUseOnlineBooking(Map<String, dynamic>? shop) =>
      isPaidActive(shop);
  static bool canUseAnnouncement(Map<String, dynamic>? shop) =>
      isPaidActive(shop);
  static bool canUseFaq(Map<String, dynamic>? shop) => isPaidActive(shop);
  static bool canUseDepositSettings(Map<String, dynamic>? shop) =>
      isPaidActive(shop);
  static bool canUsePolicySettings(Map<String, dynamic>? shop) =>
      isPaidActive(shop);

  // 免費版限制
  static int manualBookingDailyLimit(Map<String, dynamic>? shop) {
    return isPaidActive(shop) ? 999999 : 10;
  }

  static int roomTypeLimit(Map<String, dynamic>? shop) {
    return isPaidActive(shop) ? 999999 : 3;
  }

  static int roomLimit(Map<String, dynamic>? shop) {
    return isPaidActive(shop) ? 999999 : 10;
  }

  static int bookingOpenDaysLimit(Map<String, dynamic>? shop) {
    return isPaidActive(shop) ? 365 : 30;
  }
}
