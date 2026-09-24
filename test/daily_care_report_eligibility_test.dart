// 檔案名稱：test/daily_care_report_eligibility_test.dart
// 功能說明：殘缺訂單快照改用店家設定重算；付費未加購不可變成免費回報。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_paid_plan.dart';
import 'package:petnest_saas/core/models/daily_care_report_mode.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_entitlement_math.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';

void main() {
  const DailyCareSettingModel includedSetting = DailyCareSettingModel(
    enabled: true,
    sessionCount: 3,
    sessionLabels: <String>['早晨', '午後', '晚間'],
    stayReportMode: DailyCareReportMode.includedFixed,
  );

  const DailyCareSettingModel paidSetting = DailyCareSettingModel(
    enabled: true,
    sessionCount: 3,
    sessionLabels: <String>['早晨', '午後', '晚間'],
    stayReportMode: DailyCareReportMode.paidAddon,
    stayPaidPlan: DailyCarePaidPlan(
      name: '寵物寫真',
      price: 150,
      reports: 2,
      sessionLabels: <String>['上午照護', '下午照護'],
    ),
  );

  Map<String, dynamic> stayBooking({
    Map<String, dynamic>? entitlement,
    List<Map<String, dynamic>>? addons,
  }) {
    return <String, dynamic>{
      'status': 'checked_in',
      'startDate': DateTime(2026, 9, 23),
      'endDate': DateTime(2026, 9, 24),
      'roomTypeId': 'rt-1',
      'roomTypeName': '標準房',
      'nights': 1,
      if (entitlement != null) 'dailyCareEntitlement': entitlement,
      if (addons != null) 'addons': addons,
    };
  }

  test('固定提供殘缺快照改用店家設定，不信任 enabled=false', () {
    final DailyCareEntitlement result =
        DailyCareReportEligibility.resolvedEntitlement(
          booking: stayBooking(
            entitlement: <String, dynamic>{
              'enabled': false,
              'finalReports': 0,
              'sessionLabels': <String>[],
            },
          ),
          setting: includedSetting,
          daycare: false,
        );
    expect(result.enabled, isTrue);
    expect(result.finalReports, 3);
    expect(result.baseReports, 3);
    expect(result.sessionLabels, <String>['早晨', '午後', '晚間']);
    expect(result.serviceDates, <String>['2026/09/23']);
  });

  test('fallbackFromSetting 不回傳訂單殘缺 map', () {
    final DailyCareEntitlement result =
        DailyCareEntitlementMath.fallbackFromSetting(
          setting: includedSetting,
          isDaycare: false,
          booking: stayBooking(
            entitlement: <String, dynamic>{'enabled': false, 'finalReports': 0},
          ),
        );
    expect(result.finalReports, 3);
    expect(result.enabled, isTrue);
  });

  test('付費加購未購買不得 fallback 成免費回報', () {
    final DailyCareEntitlement result =
        DailyCareReportEligibility.resolvedEntitlement(
          booking: stayBooking(
            entitlement: <String, dynamic>{
              'enabled': false,
              'mode': DailyCareReportMode.paidAddon,
              'finalReports': 0,
              'sessionLabels': <String>[],
            },
          ),
          setting: paidSetting,
          daycare: false,
        );
    expect(result.finalReports, 0);
    expect(result.amount, 0);
    expect(DailyCareReportEligibility.isEntitled(result), isFalse);
  });

  test('完整快照優先於店家設定', () {
    final DailyCareEntitlement result =
        DailyCareReportEligibility.resolvedEntitlement(
          booking: stayBooking(
            entitlement: <String, dynamic>{
              'enabled': true,
              'mode': DailyCareReportMode.includedFixed,
              'finalReports': 1,
              'baseReports': 1,
              'sessionLabels': <String>['早晨'],
              'serviceDates': <String>['2026/09/23'],
            },
          ),
          setting: includedSetting,
          daycare: false,
        );
    expect(result.finalReports, 1);
    expect(result.sessionLabels, <String>['早晨']);
  });
}
