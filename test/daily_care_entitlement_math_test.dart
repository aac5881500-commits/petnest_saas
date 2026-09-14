// 檔案名稱：test/daily_care_entitlement_math_test.dart
// 功能說明：照護權益、服務日期計費與每場照片規則。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_offer_quota.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';

void main() {
  const DailyCareSettingModel setting = DailyCareSettingModel(
    enabled: true,
    sessionCount: 1,
    sessionLabels: <String>['早晨', '午後', '晚間'],
    stayPaidPlan: DailyCarePaidPlan(
      name: '寵物寫真',
      price: 150,
      reports: 2,
      chargeUnit: DailyCareReportMode.chargePerServiceDay,
      sessionLabels: <String>['上午照護', '下午照護'],
    ),
  );

  test('固定提供不購買，每天場次由設定決定', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting,
      isDaycare: false,
      shopDaycareOn: true,
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
    );
    expect(result.finalReports, 1);
    expect(result.finalPhotos, 3);
    expect(result.amount, 0);
    expect(result.serviceDates, <String>['2026/09/10', '2026/09/11']);
  });

  test('付費每日計費依服務日期，不住晚數', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(stayReportMode: DailyCareReportMode.paidAddon),
      isDaycare: false,
      shopDaycareOn: true,
      purchaseAddon: true,
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 12),
    );
    expect(result.finalReports, 2);
    expect(result.finalPhotos, 6);
    expect(result.quantity, 2);
    expect(result.amount, 300);
    expect(result.chargeUnit, DailyCareReportMode.chargePerServiceDay);
  });

  test('整筆住宿收費一次，服務日期仍每天提供', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(
        stayReportMode: DailyCareReportMode.paidAddon,
        stayPaidPlan: const DailyCarePaidPlan(
          name: '寵物寫真',
          price: 400,
          reports: 1,
          chargeUnit: DailyCareReportMode.chargeOncePerStay,
        ),
      ),
      isDaycare: false,
      shopDaycareOn: true,
      purchaseAddon: true,
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 13),
    );
    expect(result.quantity, 1);
    expect(result.amount, 400);
    expect(result.serviceDates.length, 3);
    expect(result.finalReports, 1);
  });

  test('安親按筆計費', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(
        daycareEnabled: true,
        daycareSessionCount: 2,
        daycarePaidPlan: const DailyCarePaidPlan(
          name: '安親回報',
          price: 80,
          reports: 2,
          chargeUnit: DailyCareReportMode.chargePerVisit,
        ),
        daycareReportMode: DailyCareReportMode.paidAddon,
      ),
      isDaycare: true,
      shopDaycareOn: true,
      purchaseAddon: true,
      startDate: DateTime(2026, 9, 10),
    );
    expect(result.quantity, 1);
    expect(result.amount, 80);
    expect(result.chargeUnit, DailyCareReportMode.chargePerVisit);
    expect(result.finalReports, 2);
  });

  test('舊設定預設固定模式', () {
    const DailyCareSettingModel old = DailyCareSettingModel(enabled: true);
    expect(old.stayReportMode, DailyCareReportMode.includedFixed);
    final result = DailyCareEntitlementMath.resolve(
      setting: old,
      isDaycare: false,
      shopDaycareOn: false,
    );
    expect(result.baseReports, 2);
  });

  test('依房型 VIP 只看場次，未設定會拋錯', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(
        stayReportMode: DailyCareReportMode.includedByOffer,
        stayOfferQuotas: const <String, DailyCareOfferQuota>{
          'vip': DailyCareOfferQuota(
            reports: 2,
            sessionLabels: <String>['上午照護', '下午照護'],
          ),
        },
      ),
      isDaycare: false,
      shopDaycareOn: true,
      offerId: 'vip',
    );
    expect(result.baseReports, 2);
    expect(result.sessionLabels.length, 2);

    expect(
      () => DailyCareEntitlementMath.resolve(
        setting: setting.copyWith(
          stayReportMode: DailyCareReportMode.includedByOffer,
        ),
        isDaycare: false,
        shopDaycareOn: true,
        offerId: 'normal',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('付費未購買不含顧客回報', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(stayReportMode: DailyCareReportMode.paidAddon),
      isDaycare: false,
      shopDaycareOn: true,
    );
    expect(result.finalReports, 0);
    expect(result.amount, 0);
  });

  test('住宿 9/16～9/18 固定兩天回報，忽略舊開關', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(),
      isDaycare: false,
      shopDaycareOn: true,
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 18),
    );
    expect(result.serviceDates, <String>['2026/09/16', '2026/09/17']);
  });

  test('同日入住退房為 0 天每日照護回報', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting,
      isDaycare: false,
      shopDaycareOn: true,
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 16),
    );
    expect(result.serviceDates, isEmpty);
  });

  test('安親只使用服務當日', () {
    final result = DailyCareEntitlementMath.resolve(
      setting: setting.copyWith(daycareEnabled: true, daycareSessionCount: 1),
      isDaycare: true,
      shopDaycareOn: true,
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 9, 18),
    );
    expect(result.serviceDates, <String>['2026/09/16']);
  });
}
