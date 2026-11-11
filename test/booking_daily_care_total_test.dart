import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_helper.dart';

void main() {
  const setting = DailyCareSettingModel(
    enabled: true,
    stayReportMode: DailyCareReportMode.paidAddon,
    stayPaidPlan: DailyCarePaidPlan(
      name: '寵物寫真與照護回報',
      price: 300,
      reports: 3,
      chargeUnit: DailyCareReportMode.chargePerServiceDay,
    ),
  );
  const services = <Map<String, dynamic>>[
    {'name': '迎賓點心', 'price': 100},
    {'name': '專屬照護安排', 'price': 400},
  ];
  for (final purchase in [false, true]) {
    final care = DailyCareEntitlementMath.resolve(
      setting: setting,
      isDaycare: false,
      shopDaycareOn: true,
      purchaseAddon: purchase,
      startDate: DateTime(2026, 11, 5),
      endDate: DateTime(2026, 11, 7),
    );
    test('two-day care purchase=$purchase totals and submit addon agree', () {
      final parts = BookingSummaryHelper.calculatePriceParts(
        selectedRoomType: {'price': 600},
        nights: 2,
        selectedPetIds: ['a', 'b'],
        selectedTimeAddon: null,
        selectedValueServices: services,
        selectedCustomServices: {},
        addonData: null,
        dailyCareAmount: care.amount,
      );
      expect(parts['subtotal'], purchase ? 2300 : 1700);
      expect(parts['addonTotal'], purchase ? 1100 : 500);
      expect(care.toAddonLine()?['amount'], purchase ? 600 : null);
    });
    for (final style in ['warm', 'cream', 'editorial']) {
      testWidgets(
        'confirmation $style purchase=$purchase shows full stay care price',
        (tester) async {
          final summary = BookingSummaryHelper.buildSummary(
            startDateText: '2026-11-05',
            endDateText: '2026-11-07',
            nights: 2,
            selectedPetIds: ['a', 'b'],
            pets: [
              {'id': 'a', 'name': '測試'},
              {'id': 'b', 'name': '喵喵'},
            ],
            selectedRoomType: {'name': '標準房', 'price': 600},
            totalPrice: purchase ? 2300 : 1700,
            dailyCare: care,
            selectedTimeAddon: null,
            selectedValueServices: services,
            selectedCustomServices: {},
            selectedDailyTimedServices: {},
            addonData: null,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: BookingAppearanceScope(
                  appearance: BookingPageAppearance(style: style),
                  child: SingleChildScrollView(child: summary),
                ),
              ),
            ),
          );
          final card = tester.widget<BookingSummaryCard>(
            find.byType(BookingSummaryCard),
          );
          expect(card.addonAmount, purchase ? 1100 : 500);
          expect(
            card.valueServices.where((s) => s['name'] == '寵物寫真與照護回報').length,
            purchase ? 1 : 0,
          );
          expect(
            find.text('寵物寫真與照護回報'),
            purchase ? findsOneWidget : findsNothing,
          );
          if (purchase) {
            expect(card.valueServices.last['price'], 600);
            expect(find.textContaining('600'), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
