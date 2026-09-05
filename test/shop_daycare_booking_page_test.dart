// 檔案名稱：test/shop_daycare_booking_page_test.dart
// 功能說明：安親預約第一步整頁 Widget 測試（未登入／已登入有寵物）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_booking_page.dart';

void _expectStepOneChrome(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.text('安親預約'), findsWidgets);
  expect(find.text('日期與寵物'), findsOneWidget);
  expect(find.text('方案與服務'), findsOneWidget);
  expect(find.text('費用與確認'), findsOneWidget);
  expect(find.text('尚未選擇日期'), findsOneWidget);
  expect(find.text('選擇日期'), findsOneWidget);
  expect(find.text('送達時間'), findsOneWidget);
  expect(find.text('接回時間'), findsOneWidget);
  expect(find.textContaining('選擇安親寵物'), findsOneWidget);
  expect(
    tester.getSize(find.byType(SingleChildScrollView)).height,
    greaterThan(80),
  );
}

Future<void> _pumpDaycarePage(
  WidgetTester tester, {
  required bool loggedIn,
  Stream<List<Map<String, dynamic>>>? petsStream,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ShopDaycareBookingPage(
        shopId: 'shop-test',
        settings: const DaycareSettingsModel(
          enabled: true,
          serviceName: '安親預約',
        ),
        shop: const <String, dynamic>{'name': '測試店家'},
        skipRemoteLoads: true,
        debugLoggedIn: loggedIn,
        debugPetsStream:
            petsStream ??
            Stream<List<Map<String, dynamic>>>.value(
              const <Map<String, dynamic>>[],
            ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('未登入時安親第一步仍顯示日期、時間與寵物區', (WidgetTester tester) async {
    await _pumpDaycarePage(tester, loggedIn: false);
    _expectStepOneChrome(tester);
    expect(find.textContaining('目前尚未登入'), findsOneWidget);
  });

  testWidgets('已登入且寵物 Stream 有資料時整頁不崩潰', (WidgetTester tester) async {
    await _pumpDaycarePage(
      tester,
      loggedIn: true,
      petsStream: Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[
          <String, dynamic>{'petId': 'p1', 'name': '小白', 'type': 'cat'},
        ],
      ),
    );
    _expectStepOneChrome(tester);
    expect(find.text('小白'), findsOneWidget);
  });

  testWidgets('第三步顯示優惠券與費用並直接開啟填寫資料', (WidgetTester tester) async {
    const DaycarePlanModel plan = DaycarePlanModel(
      id: 'hourly',
      name: '每小時計費',
      includedMinutes: 120,
      basePrice: 200,
      extraBillingMinutes: 30,
      extraBillingPrice: 100,
      extraPetPrice: 100,
      maxBaseCharge: 1000,
      enabled: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDaycareBookingPage(
          shopId: 'shop-test',
          settings: const DaycareSettingsModel(
            enabled: true,
            serviceName: '安親預約',
            allowCoupon: true,
            depositType: DaycareDepositTypes.fixed,
            depositValue: 1000,
            plans: <DaycarePlanModel>[plan],
          ),
          shop: const <String, dynamic>{'name': '測試店家'},
          skipRemoteLoads: true,
          debugLoggedIn: true,
          debugInitialStep: 3,
          debugDate: DateTime(2026, 9, 5),
          debugDropOff: '09:00',
          debugPickUp: '17:00',
          debugSelectedPetIds: <String>['p1'],
          debugPlan: plan,
          debugPetsStream: Stream<List<Map<String, dynamic>>>.value(
            const <Map<String, dynamic>>[
              <String, dynamic>{'petId': 'p1', 'name': '小白', 'type': 'cat'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.text('使用優惠券'), findsOneWidget);
    expect(find.text('費用明細'), findsOneWidget);
    expect(find.text('預約摘要'), findsOneWidget);
    expect(find.text('當次最高計費　NT\$1000'), findsNothing);
    expect(find.textContaining('預計訂金'), findsOneWidget);
    expect(find.text('下一步：填寫資料'), findsOneWidget);
    expect(find.text('預約確認'), findsNothing);
    await tester.ensureVisible(find.text('下一步：填寫資料'));
    await tester.tap(find.text('下一步：填寫資料'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(BookingFormPage), findsOneWidget);
    expect(find.text('填寫預約資料'), findsOneWidget);
  });
}
