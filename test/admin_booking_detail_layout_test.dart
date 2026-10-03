// 檔案名稱：test/admin_booking_detail_layout_test.dart
// 功能說明：店主訂單詳細響應式斷點與四種寬度不 overflow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/core/navigation/shop_operations_workbench.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_header_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_card.dart';

void main() {
  test('斷點：1024 桌面、600 平板、599 手機、840 起雙欄', () {
    expect(
      AdminBookingDetailMetrics.modeFor(1440),
      AdminBookingDetailMode.desktop,
    );
    expect(
      AdminBookingDetailMetrics.modeFor(1024),
      AdminBookingDetailMode.desktop,
    );
    expect(
      AdminBookingDetailMetrics.modeFor(1023),
      AdminBookingDetailMode.tablet,
    );
    expect(
      AdminBookingDetailMetrics.modeFor(600),
      AdminBookingDetailMode.tablet,
    );
    expect(
      AdminBookingDetailMetrics.modeFor(599),
      AdminBookingDetailMode.phone,
    );
    expect(AdminBookingDetailMetrics.useTwoColumns(840), isTrue);
    expect(AdminBookingDetailMetrics.useTwoColumns(839), isFalse);
  });

  testWidgets('1440/1024/768/390 版型不 overflow', (WidgetTester tester) async {
    Future<void> pumpWidth(double width) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ShopFrontendThemeInherited(
          theme: ShopFrontendTheme.fallback,
          child: MaterialApp(
            home: AdminBookingDetailScaffold(
              title: '訂單詳細',
              bookingCode: 'SHOP0001-B000105',
              overview: const AdminBookingHeaderCard(
                data: <String, dynamic>{
                  'bookingKind': 'accommodation',
                  'status': 'pending',
                  'customerName': '林小華',
                  'bookingCode': 'SHOP0001-B000105',
                  'roomTypeName': '標準房',
                  'nights': 2,
                },
                bookingId: 'b1',
              ),
              actions: const AdminBookingDetailCard(
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    FilledButton(onPressed: null, child: Text('確認訂金')),
                    OutlinedButton(onPressed: null, child: Text('取消訂單')),
                  ],
                ),
              ),
              left: const <Widget>[
                AdminBookingDetailSection(
                  title: '顧客資訊',
                  child: AdminBookingCustomerSection(
                    data: <String, dynamic>{
                      'customerName': '林小華',
                      'customerPhone': '0911111111',
                      'address': '台北市測試路一段超長地址用來確認可以換行不會爆版',
                    },
                    emergency: <String, dynamic>{'name': '緊急', 'phone': '0922'},
                  ),
                ),
                AdminBookingPetCard(
                  compact: true,
                  pet: <String, dynamic>{
                    'name': '咪',
                    'breed': '英短',
                    'gender': '母',
                  },
                ),
              ],
              right: const <Widget>[
                AdminBookingDetailCard(child: Text('付款摘要 NT\$ 3200')),
                AdminBookingDetailCard(child: Text('操作紀錄')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('訂單詳細'), findsWidgets);
      if (width >= 1024) {
        expect(find.byType(Scrollbar), findsNWidgets(2));
      }
      expect(find.textContaining('SHOP0001-B000105'), findsWidgets);
      expect(find.text('目前安排'), findsOneWidget);
      expect(find.text('尚未安排房間'), findsOneWidget);
      expect(find.textContaining('點擊查看'), findsNothing);
      expect(find.text('寵物照護資料提醒'), findsNothing);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWidth(1440);
    await pumpWidth(1024);
    await pumpWidth(768);
    await pumpWidth(390);
  });

  testWidgets('手機訂單進度在獨立分頁，主要操作固定在底部', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'SHOP0001-B000197',
            operationsShopId: 'shop-1',
            splitPhoneActions: true,
            overview: const Text('訂單摘要'),
            left: const <Widget>[Text('顧客資訊')],
            right: const <Widget>[Text('付款')],
            phoneInlineActions: const Text('取消訂單'),
            phoneStickyActions: const Text('辦理退房／結算'),
            progress: const Text('完整時間軸'),
            actions: const Text('不應出現在手機'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('訂單'), findsOneWidget);
    expect(find.text('進度'), findsOneWidget);
    expect(find.text('完整時間軸'), findsNothing);
    expect(find.text('辦理退房／結算'), findsOneWidget);
    expect(find.text('不應出現在手機'), findsNothing);
    expect(find.text('顧客資訊'), findsOneWidget);
    await tester.tap(find.text('進度'));
    await tester.pump();
    expect(find.text('完整時間軸'), findsOneWidget);
    expect(find.text('顧客資訊'), findsNothing);
  });

  testWidgets('桌機保留右側訂單進度', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ShopFrontendThemeInherited(
        theme: ShopFrontendTheme.fallback,
        child: MaterialApp(
          home: AdminBookingDetailScaffold(
            title: '訂單詳細',
            bookingCode: 'B1',
            operationsShopId: 'shop-1',
            overview: const Text('訂單摘要'),
            actions: const Text('辦理退房／結算'),
            phoneStickyActions: const Text('手機底部'),
            left: const <Widget>[Text('顧客資訊')],
            right: const <Widget>[Text('付款')],
            progress: const Text('完整時間軸'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('營運工作台'), findsOneWidget);
    expect(find.text('完整時間軸'), findsOneWidget);
    expect(find.text('辦理退房／結算'), findsOneWidget);
    expect(find.text('手機底部'), findsNothing);
    expect(find.text('進度'), findsNothing);
  });

  testWidgets('營運工作台已在堆疊時 pop 回去，不另開一頁', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: shopOperationsWorkbenchRouteName,
                    ),
                    builder: (_) => const Scaffold(body: Text('原工作台')),
                  ),
                );
              },
              child: const Text('先開工作台'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('先開工作台'));
    await tester.pumpAndSettle();
    final BuildContext workbench = tester.element(
      find.text('原工作台', skipOffstage: false),
    );
    Navigator.of(workbench).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: TextButton(
            onPressed: () =>
                openShopOperationsWorkbench(workbench, shopId: 'shop-1'),
            child: const Text('回工作台'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('回工作台'));
    await tester.pumpAndSettle();
    expect(find.text('原工作台'), findsOneWidget);
    expect(find.text('回工作台'), findsNothing);
  });
}
