import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/navigation/shop_dashboard_module_access.dart';

void main() {
  const extra = [
    ShopModules.dogHotel,
    ShopModules.grooming,
    ShopModules.hospital,
  ];
  List<String> resolve(
    List<String> enabled, {
    String role = 'owner',
    Set<String> permissions = const {},
  }) => resolveShopDashboardModules(
    enabledModules: enabled,
    role: role,
    can: (key) => role == 'owner' || permissions.contains(key),
  );
  test('enabled service modules appear below cat hotel before reports', () {
    expect(
      resolve([
        ShopModules.basicInfo,
        ShopModules.catHotel,
        ...extra,
        ShopModules.reports,
      ]),
      [
        ShopModules.basicInfo,
        ShopModules.catHotel,
        ...extra,
        ShopModules.reports,
        ShopModules.inventory,
        ShopModules.store,
      ],
    );
  });
  for (final module in extra) {
    test('$module follows saved module switch for the owner', () {
      expect(resolve([ShopModules.catHotel, module]), contains(module));
      expect(resolve([ShopModules.catHotel]), isNot(contains(module)));
    });
    for (final permission in [
      ShopPermissionKeys.manageBookings,
      ShopPermissionKeys.manageBookingSettings,
    ]) {
      test('$module is visible to staff with $permission', () {
        expect(
          resolve([module], role: 'staff', permissions: {permission}),
          contains(module),
        );
        expect(
          resolve([], role: 'staff', permissions: {permission}),
          isNot(contains(module)),
        );
      });
    }
  }
  test('chat or inventory access does not grant access to service modules', () {
    final visible = resolve(
      extra,
      role: 'staff',
      permissions: {
        ShopPermissionKeys.manageChat,
        ShopPermissionKeys.viewInventory,
      },
    );
    for (final module in extra) {
      expect(visible, isNot(contains(module)));
    }
    expect(visible, contains(ShopModules.inventory));
  });
  test('switch changes are reflected on the next shop snapshot', () {
    expect(resolve(extra), containsAll(extra));
    expect(resolve([ShopModules.grooming]), contains(ShopModules.grooming));
    expect(
      resolve([ShopModules.grooming]),
      isNot(contains(ShopModules.dogHotel)),
    );
    expect(
      resolve([ShopModules.grooming]),
      isNot(contains(ShopModules.hospital)),
    );
  });
}
