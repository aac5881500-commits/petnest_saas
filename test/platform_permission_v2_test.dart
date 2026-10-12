import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/core/services/platform_permission_catalog.dart';
import 'package:petnest_saas/features/platform/widgets/platform_permission_editor.dart';

void main() {
  test('既有權限鍵仍在，最高管理員專屬權限不能當一般授權', () {
    expect(
      PlatformPermissionKeys.assignableValues,
      contains(PlatformPermissionKeys.manageSales),
    );
    expect(
      PlatformPermissionKeys.assignableValues,
      contains(PlatformPermissionKeys.viewOwnSales),
    );
    expect(
      PlatformPermissionCatalog.isSuperOnly(
        PlatformPermissionKeys.managePaymentSettings,
      ),
      isTrue,
    );
    expect(
      PlatformPermissionCatalog.isSuperOnly(PlatformPermissionKeys.viewShops),
      isFalse,
    );
    expect(PlatformAdminRoles.label('platform_admin'), '平台管理員');
    expect(PlatformAdminRoles.label('developer_admin'), '開發管理員');
    expect(PlatformAdminRoles.assignableRoles, isNot(contains('super_admin')));
  });

  test('異動摘要使用中文，不輸出原始權限鍵', () {
    final String headline = PlatformPermissionCatalog.changeHeadline(
      operatorRole: PlatformAdminRoles.platformAdmin,
      addedCount: 3,
      removedCount: 1,
      enabledChanged: false,
      nextEnabled: true,
    );
    final String detail = PlatformPermissionCatalog.changeDetail(
      addedCount: 3,
      removedCount: 1,
      enabledChanged: false,
      nextEnabled: true,
      roleChanged: false,
    );
    expect(headline, '平台管理員修改員工權限');
    expect(detail, '新增 3 項、移除 1 項');
    expect(detail.contains('view_shops'), isFalse);
  });

  test('查看店家與查看自己的業務客戶是不同權限', () {
    expect(
      PlatformPermissionKeys.viewShops,
      isNot(PlatformPermissionKeys.viewOwnSales),
    );
    expect(
      PlatformPermissionCatalog.explain(PlatformPermissionKeys.viewOwnSales),
      contains('自己'),
    );
  });

  testWidgets('權限編輯在手機與桌機寬度不溢出', (WidgetTester tester) async {
    Future<void> pump(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformPermissionEditor(
                key: ValueKey<Size>(size),
                selected: <String>{PlatformPermissionKeys.viewShops},
                onChanged: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('僅最高管理員', skipOffstage: false), findsWidgets);
      expect(_switchEnabled('查看所有店家'), isTrue);
      expect(_switchEnabled('修改金流設定'), isFalse);
      await tester.enterText(find.byType(TextField), '金流');
      await tester.pumpAndSettle();
      expect(_hasText('查看所有店家'), isFalse);
      final Finder vertical = find.byWidgetPredicate(
        (Widget widget) => widget is Scrollable && widget.axis == Axis.vertical,
      );
      await tester.drag(vertical, const Offset(0, -800));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pump(const Size(390, 844));
    await pump(const Size(1280, 800));
    await tester.binding.setSurfaceSize(null);
  });
}

bool _hasText(String value) {
  for (final Element element in find.byType(Text, skipOffstage: false).evaluate()) {
    if ((element.widget as Text).data == value) return true;
  }
  return false;
}

bool _switchEnabled(String label) {
  for (final Element element in find.byType(Text, skipOffstage: false).evaluate()) {
    final Text text = element.widget as Text;
    if (text.data != label) continue;
    SwitchListTile? tile;
    element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget is SwitchListTile) {
        tile = ancestor.widget as SwitchListTile;
        return false;
      }
      return true;
    });
    return tile?.onChanged != null;
  }
  return false;
}
