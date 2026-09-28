// 檔案名稱：test/daily_care_stay_report_dates_test.dart
// 功能說明：住宿回報日只跟入住／退房；安親仍是服務當日。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/services/daily_care_report_eligibility.dart';

void main() {
  test('住宿 9/28～9/30 只回報 9/28、9/29', () {
    final List<String> keys = DailyCareDateHelper.careDateKeys(
      checkIn: DateTime.utc(2026, 9, 27, 16),
      checkOut: DateTime.utc(2026, 9, 29, 16),
    );
    expect(keys, <String>['2026/09/28', '2026/09/29']);
  });

  test('serviceDates 早一天時住宿仍以入住退房為準', () {
    final Map<String, dynamic> booking = <String, dynamic>{
      'bookingKind': 'accommodation',
      'startDate': DateTime(2026, 9, 28),
      'endDate': DateTime(2026, 9, 30),
      'dailyCareEntitlement': <String, dynamic>{
        'enabled': true,
        'service': 'accommodation',
        'mode': 'included_fixed',
        'finalReports': 1,
        'sessionLabels': <String>['第 1 場'],
        'serviceDates': <String>['2026/09/27', '2026/09/28'],
      },
    };
    final List<String> keys = DailyCareReportEligibility.stayCareDates(
      booking,
    ).map(DailyCareDateHelper.dateKey).toList();
    expect(keys, <String>['2026/09/28', '2026/09/29']);
    expect(
      DailyCareReportEligibility.stayServiceDatesNeedRepair(
        isDaycare: false,
        checkIn: DateTime(2026, 9, 28),
        checkOut: DateTime(2026, 9, 30),
        serviceDates: const <String>['2026/09/27', '2026/09/28'],
      ),
      isTrue,
    );
    expect(
      DailyCareReportEligibility.stayServiceDatesNeedRepair(
        isDaycare: false,
        checkIn: DateTime(2026, 9, 28),
        checkOut: DateTime(2026, 9, 30),
        serviceDates: const <String>['2026/09/28', '2026/09/29'],
      ),
      isFalse,
    );
  });

  test('安親仍只取服務當日', () {
    final Map<String, dynamic> booking = <String, dynamic>{
      'bookingKind': 'daycare',
      'serviceDate': '2026/09/28',
      'startDate': DateTime(2026, 9, 28),
      'endDate': DateTime(2026, 9, 30),
      'dailyCareEntitlement': <String, dynamic>{
        'serviceDates': <String>['2026/09/27'],
      },
    };
    expect(
      DailyCareReportEligibility.daycareCareDates(
        booking,
      ).map(DailyCareDateHelper.dateKey).toList(),
      <String>['2026/09/28'],
    );
    expect(
      DailyCareDateHelper.daycareCareDates(
        serviceDate: DateTime(2026, 9, 28, 9),
      ).map(DailyCareDateHelper.dateKey),
      <String>['2026/09/28'],
    );
    expect(
      DailyCareReportEligibility.stayServiceDatesNeedRepair(
        isDaycare: true,
        checkIn: DateTime(2026, 9, 28),
        checkOut: DateTime(2026, 9, 30),
        serviceDates: const <String>['2026/09/27'],
      ),
      isFalse,
    );
  });
}
