import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/features/platform/pages/platform_admin_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _Preview())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop 1440 uses 3 columns and keeps every entry', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1440, 2400));

    expect(tester.takeException(), isNull);
    expect(find.text('前往'), findsNWidgets(13));
    expect(find.text('管理店家、收費、平台帳號與營運案件'), findsOneWidget);
    expect(find.text('店家狀態、申請與客服案件'), findsOneWidget);
    expect(find.text('平台操作紀錄'), findsOneWidget);
    expect(find.text('外觀圖庫'), findsOneWidget);
    expect(find.text('評價管理'), findsOneWidget);
    expect(find.text('平台條款管理'), findsOneWidget);

    final request = tester.getTopLeft(find.text('店家申請中心'));
    final contact = tester.getTopLeft(find.text('聯絡平台案件'));
    expect((request.dy - contact.dy).abs(), lessThan(2));
    expect(contact.dx, greaterThan(request.dx + 80));

    final header = tester.getTopLeft(find.text('管理店家、收費、平台帳號與營運案件'));
    expect(header.dx, greaterThan(28));
    expect(header.dx, lessThan(48));
  });

  testWidgets('desktop 1600 stays centered inside the max width', (
    tester,
  ) async {
    await pumpDashboard(tester, const Size(1600, 2400));

    expect(tester.takeException(), isNull);
    final header = tester.getTopLeft(find.text('管理店家、收費、平台帳號與營運案件'));
    expect(header.dx, greaterThan(70));
  });

  testWidgets('desktop 1024 and 1199 use 2 columns without overflow', (
    tester,
  ) async {
    for (final width in [900.0, 1024.0, 1199.0]) {
      await pumpDashboard(tester, Size(width, 2400));
      expect(tester.takeException(), isNull);
      expect(find.text('前往'), findsNWidgets(13));

      final request = tester.getTopLeft(find.text('店家申請中心'));
      final contact = tester.getTopLeft(find.text('聯絡平台案件'));
      expect(contact.dy, greaterThan(request.dy + 80));
    }
  });

  testWidgets('desktop 1200 switches to 3 columns', (tester) async {
    await pumpDashboard(tester, const Size(1200, 2400));
    expect(tester.takeException(), isNull);

    final request = tester.getTopLeft(find.text('店家申請中心'));
    final contact = tester.getTopLeft(find.text('聯絡平台案件'));
    expect((request.dy - contact.dy).abs(), lessThan(2));
  });

  testWidgets('mobile 390 and 768 use a single column without 前往', (
    tester,
  ) async {
    for (final width in [390.0, 768.0, 899.0]) {
      await pumpDashboard(tester, Size(width, 2400));
      expect(tester.takeException(), isNull);
      expect(find.text('前往'), findsNothing);
      expect(find.text('管理店家、收費、平台帳號與營運案件'), findsNothing);
      expect(find.text('店家狀態、申請與客服案件'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(13));

      final request = tester.getTopLeft(find.text('店家申請中心'));
      final contact = tester.getTopLeft(find.text('聯絡平台案件'));
      expect(contact.dy, greaterThan(request.dy + 40));
      expect((contact.dx - request.dx).abs(), lessThan(4));
    }
  });

  test('hidden permissions omit entries and empty sections', () {
    bool allow(String permission, Set<String> granted) =>
        granted.contains(permission);

    final none = debugPlatformAdminCatalog(
      hasPermission: (_) => false,
      hasAnyPermission: (_) => false,
    );
    expect(none, isEmpty);

    final activationOnly = debugPlatformAdminCatalog(
      hasPermission: (permission) =>
          allow(permission, {PlatformPermissionKeys.manageActivationCodes}),
      hasAnyPermission: (permissions) => permissions.any(
        (permission) =>
            allow(permission, {PlatformPermissionKeys.manageActivationCodes}),
      ),
    );
    expect(activationOnly, hasLength(1));
    expect(activationOnly.single.title, '方案與收費');
    expect(activationOnly.single.entries, ['激活碼管理']);

    final subscriptionOnly = debugPlatformAdminCatalog(
      hasPermission: (permission) =>
          allow(permission, {PlatformPermissionKeys.manageShopSubscriptions}),
      hasAnyPermission: (permissions) => permissions.any(
        (permission) =>
            allow(permission, {PlatformPermissionKeys.manageShopSubscriptions}),
      ),
    );
    expect(subscriptionOnly.map((section) => section.title), ['店家管理', '方案與收費']);
    expect(subscriptionOnly[0].entries, ['店家管理']);
    expect(subscriptionOnly[1].entries, ['方案 / 付款管理']);

    final adminsOnly = debugPlatformAdminCatalog(
      hasPermission: (permission) =>
          allow(permission, {PlatformPermissionKeys.managePlatformAdmins}),
      hasAnyPermission: (permissions) => permissions.any(
        (permission) =>
            allow(permission, {PlatformPermissionKeys.managePlatformAdmins}),
      ),
    );
    expect(adminsOnly.single.title, '平台設定');
    expect(adminsOnly.single.entries, ['平台人員與權限']);

    final all = debugPlatformAdminCatalog(
      hasPermission: (_) => true,
      hasAnyPermission: (_) => true,
    );
    expect(all.map((section) => section.title), [
      '店家管理',
      '方案與收費',
      '會員管理',
      '平台設定',
    ]);
    expect(all.expand((section) => section.entries), [
      '店家管理',
      '店家申請中心',
      '聯絡平台案件',
      '綠界金流審核中心',
      '方案 / 付款管理',
      '激活碼管理',
      '平台會員管理',
      '帳號刪除申請',
      '平台人員與權限',
      '外觀圖庫',
      '評價管理',
      '平台條款管理',
      '平台操作紀錄',
    ]);
  });
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    return debugPlatformAdminDashboardPreview();
  }
}
