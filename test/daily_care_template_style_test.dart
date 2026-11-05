import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/daily_care_upgrade_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_service_template_editor.dart';

void main() {
  const paid = DailyCareSettingModel(
    enabled: true,
    stayReportMode: DailyCareReportMode.paidAddon,
    stayPaidPlan: DailyCarePaidPlan(
      price: 300,
      reports: 3,
      sessionLabels: ['早安', '午間', '晚安'],
    ),
  );
  for (final style in ['editorial', 'cream']) {
    testWidgets(
      '$style paid report uses suite colors and still selects and clears',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingAppearanceScope(
                appearance: BookingPageAppearance(
                  style: style,
                  suiteColorMode: 'frontend',
                ),
                frontendTheme: HomeThemeModel.modernDefault.copyWith(
                  primaryColorValue: 0xFF6554A5,
                  textColorValue: 0xFF493853,
                ),
                child: StatefulBuilder(
                  builder: (context, change) => SingleChildScrollView(
                    child: DailyCareUpgradeCard(
                      setting: paid,
                      isDaycare: false,
                      shopDaycareOn: true,
                      offerId: 'room',
                      offerName: '標準房',
                      nights: 4,
                      startDate: DateTime(2026, 11, 5),
                      endDate: DateTime(2026, 11, 9),
                      selectedPlanId: selected,
                      onChanged: (v) => change(() => selected = v),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('daily-care-upgrade-$style')),
          findsOneWidget,
        );
        final plan = find.widgetWithText(RadioListTile<String?>, '寵物寫真與照護回報');
        await tester.ensureVisible(plan);
        await tester.tap(plan);
        await tester.pumpAndSettle();
        expect(selected, DailyCareReportMode.stayPaidId);
        expect(
          Theme.of(tester.element(plan)).colorScheme.primary,
          const Color(0xFF6554A5),
        );
        expect(find.textContaining('服務日期 2026/11/05'), findsOneWidget);
        final none = find.text('不加購');
        await tester.ensureVisible(none);
        await tester.tap(none);
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$style included and paid report fit 320px at 200 percent text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final setting in [
          paid,
          const DailyCareSettingModel(enabled: true),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 740),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: BookingAppearanceScope(
                    appearance: BookingPageAppearance(style: style),
                    child: SingleChildScrollView(
                      child: DailyCareUpgradeCard(
                        setting: setting,
                        isDaycare: false,
                        shopDaycareOn: true,
                        offerId: 'room',
                        offerName: '標準房',
                        nights: 4,
                        startDate: DateTime(2026, 11, 5),
                        endDate: DateTime(2026, 11, 9),
                        selectedPlanId: null,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('daily-care-upgrade-$style')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      '$style preview includes optional report and updates estimate',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingServicePreview(
                  appearance: BookingPageAppearance(
                    style: style,
                    serviceStyle: style,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 1800'), findsOneWidget);
        final plan = find.widgetWithText(RadioListTile<String?>, '寵物寫真與照護回報');
        await tester.ensureVisible(plan);
        await tester.tap(plan);
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 2700'), findsOneWidget);
        await tester.ensureVisible(find.text('不加購'));
        await tester.tap(find.text('不加購'));
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 1800'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
