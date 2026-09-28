// 檔案名稱：test/daily_care_upgrade_card_test.dart
// 功能說明：付費照護卡在未完成服務選擇時仍顯示，完成後顯示價格。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_booking_page.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daily_care_upgrade_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const DailyCareSettingModel paidDaycare = DailyCareSettingModel(
    daycareEnabled: true,
    daycareReportMode: DailyCareReportMode.paidAddon,
    daycarePaidPlan: DailyCarePaidPlan(
      name: '安親寫真',
      price: 150,
      reports: 1,
      chargeUnit: DailyCareReportMode.chargePerVisit,
      sessionLabels: <String>['安親回報'],
    ),
  );

  testWidgets('未選日期仍顯示不加購與付費方案', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyCareUpgradeCard(
            setting: paidDaycare,
            isDaycare: true,
            shopDaycareOn: true,
            offerId: '',
            offerName: '',
            nights: 1,
            selectedPlanId: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('請先完成服務選擇以計算價格'), findsWidgets);
    expect(find.text('不加購'), findsOneWidget);
    expect(find.text('安親寫真'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('安親費用摘要會加上已選照護加購，取消後移除', (WidgetTester tester) async {
    const DaycarePlanModel plan = DaycarePlanModel(
      id: 'plan-1',
      name: '半日安親',
      basePrice: 400,
      includedMinutes: 240,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDaycareBookingPage(
          shopId: 'shop-test',
          settings: DaycareSettingsModel(
            enabled: true,
            pricingMode: DaycarePricingModes.independentPlan,
            plans: <DaycarePlanModel>[plan],
          ),
          shop: const <String, dynamic>{'name': '測試店家'},
          skipRemoteLoads: true,
          debugLoggedIn: true,
          debugPetsStream: Stream<List<Map<String, dynamic>>>.value(
            const <Map<String, dynamic>>[],
          ),
          debugInitialStep: 2,
          debugDate: DateTime(2026, 9, 28),
          debugDropOff: '09:00',
          debugPickUp: '12:00',
          debugSelectedPetIds: const <String>['pet-1'],
          debugPlan: plan,
          debugDailyCareSetting: paidDaycare,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('不加購'), findsOneWidget);
    expect(find.text('安親寫真'), findsOneWidget);
    expect(
      find.textContaining('小計 ${ShopReportFormat.money(150)}'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('安親寫真'));
    await tester.tap(find.text('安親寫真'));
    await tester.pumpAndSettle();
    final RadioListTile<String?> paidTile = tester
        .widget<RadioListTile<String?>>(
          find.widgetWithText(RadioListTile<String?>, '安親寫真'),
        );
    expect(paidTile.groupValue, 'daycare_paid');

    await tester.ensureVisible(find.text('不加購'));
    await tester.tap(find.text('不加購'));
    await tester.pumpAndSettle();
    final RadioListTile<String?> cleared = tester
        .widget<RadioListTile<String?>>(
          find.widgetWithText(RadioListTile<String?>, '不加購'),
        );
    expect(cleared.groupValue, isNull);
    expect(find.text('安親寫真'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
