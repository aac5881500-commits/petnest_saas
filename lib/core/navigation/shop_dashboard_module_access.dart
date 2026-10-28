import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';

/// Shared by the desktop sidebar and the mobile tabs.
/// Enabling a module exposes its entry only to authorized shop staff.
List<String> resolveShopDashboardModules({
  required List<String> enabledModules,
  required String? role,
  required bool Function(String) can,
}) {
  final result = <String>[];

  final canSeeBasicInfo =
      can(ShopPermissionKeys.editBasicInfo) ||
      can(ShopPermissionKeys.editBusinessInfo) ||
      can(ShopPermissionKeys.editMedia) ||
      can(ShopPermissionKeys.manageFrontendContent) ||
      can(ShopPermissionKeys.manageReviews);
  final canSeeCatHotel =
      can(ShopPermissionKeys.manageBookings) ||
      can(ShopPermissionKeys.manageBookingSettings) ||
      can(ShopPermissionKeys.manageRoomDashboard) ||
      can(ShopPermissionKeys.manageRoomTypes) ||
      can(ShopPermissionKeys.manageRooms) ||
      can(ShopPermissionKeys.managePaymentSettings) ||
      can(ShopPermissionKeys.manageAddons) ||
      can(ShopPermissionKeys.manageDevices) ||
      can(ShopPermissionKeys.managePolicy) ||
      can(ShopPermissionKeys.manageChat);
  final canSeeReports =
      role == ShopRoles.owner ||
      can(ShopPermissionKeys.viewReports) ||
      can(ShopPermissionKeys.viewActionLogs);
  final canSeeInventory =
      role == ShopRoles.owner ||
      can(ShopPermissionKeys.viewInventory) ||
      can(ShopPermissionKeys.manageInventory) ||
      can(ShopPermissionKeys.receiveInventory) ||
      can(ShopPermissionKeys.adjustInventory);
  final canSeeStore =
      role == ShopRoles.owner ||
      can(ShopPermissionKeys.viewStoreOrders) ||
      can(ShopPermissionKeys.manageStoreProducts) ||
      can(ShopPermissionKeys.manageStoreOrders) ||
      can(ShopPermissionKeys.manageStoreSettings);

  if (enabledModules.contains(ShopModules.basicInfo) &&
      (canSeeBasicInfo || role == ShopRoles.staff)) {
    result.add(ShopModules.basicInfo);
  }

  if (enabledModules.contains(ShopModules.catHotel) && canSeeCatHotel) {
    result.add(ShopModules.catHotel);
  }

  final canSeeServiceModules =
      role == ShopRoles.owner ||
      can(ShopPermissionKeys.manageBookings) ||
      can(ShopPermissionKeys.manageBookingSettings);
  for (final module in [
    ShopModules.dogHotel,
    ShopModules.grooming,
    ShopModules.hospital,
  ]) {
    if (enabledModules.contains(module) && canSeeServiceModules) {
      result.add(module);
    }
  }

  if (role == ShopRoles.owner ||
      (enabledModules.contains(ShopModules.reports) && canSeeReports)) {
    result.add(ShopModules.reports);
  }

  if (canSeeInventory) {
    result.add(ShopModules.inventory);
  }

  if (canSeeStore) {
    result.add(ShopModules.store);
  }
  return result;
}
