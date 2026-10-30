import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';

void main() {
  testWidgets(
    'owner menu is shared; navigation never mounts production editors',
    (tester) async {
      String? entry;
      await tester.pumpWidget(
        MaterialApp(
          home: ShopDashboardInspectionView(
            shopId: 's1',
            shop: const {'name': '測試店家', 'plan': 'pro'},
            onOpenEntry: (value) => entry = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('基本資訊'), findsWidgets);
      final basic = find.text('店家基本資料');
      await tester.ensureVisible(basic);
      await tester.tap(basic);
      expect(entry, 'ShopBasicInfoPage');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('貓咪旅店').first);
      await tester.pumpAndSettle();
      expect(find.text('訂單管理'), findsOneWidget);
      await tester.tap(find.text('訂單管理'));
      expect(entry, 'AdminBookingListPage');
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'shared owner readonly home fits $width without Firebase access',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: ShopDashboardInspectionView(
              shopId: 's1',
              shop: const {'name': '測試店家', 'plan': 'pro'},
              onOpenEntry: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('貓咪旅店').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'same member page uses inspection pages; no merge or production detail',
    (tester) async {
      Map<String, dynamic>? selected;
      final cursors = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AdminMemberListPage(
            shopId: 's1',
            inspectionShop: const {},
            inspectionLoadPage: (cursor) async {
              cursors.add(cursor);
              return {
                'records': [
                  {
                    'path': 'shops/s1/members/m1',
                    'data': {'name': '陳小姐', 'phone': '0912345678'},
                  },
                ],
                'next': null,
              };
            },
            onInspectionMember: (member) => selected = member,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cursors, [null]);
      expect(find.byTooltip('會員合併'), findsNothing);
      expect(find.text('陳小姐'), findsWidgets);
      await tester.tap(find.text('陳小姐').first);
      expect(selected?['path'], 'shops/s1/members/m1');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('封存會員'));
      await tester.pumpAndSettle();
      expect(find.text('已載入資料中沒有符合條件的會員'), findsOneWidget);
    },
  );
}
