// 檔案名稱：test/daily_care_date_helper_test.dart
// 功能說明：住宿晚數照護日、安親當日、同日 0 天

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';

void main() {
  test('9/16 入住 9/18 退房為兩天', () {
    final List<DateTime> dates = DailyCareDateHelper.careDates(
      checkIn: DateTime(2026, 9, 16),
      checkOut: DateTime(2026, 9, 18),
    );
    expect(dates.map(DailyCareDateHelper.dateKey).toList(), <String>[
      '2026/09/16',
      '2026/09/17',
    ]);
  });

  test('recordIdDateKey 使用台北日曆日', () {
    expect(
      DailyCareDateHelper.recordIdDateKey(DateTime.utc(2026, 9, 19, 16)),
      '20260920',
    );
    expect(DailyCareDateHelper.displayDateKey('20260920'), '2026/09/20');
  });

  test('taipeiTodayUtcRange 是台灣日 00:00 到隔日 00:00', () {
    final DateTime now = DateTime.utc(2026, 9, 21, 16, 5);
    final ({DateTime startUtc, DateTime endUtc}) range =
        DailyCareDateHelper.taipeiTodayUtcRange(now);
    expect(range.startUtc, DateTime.utc(2026, 9, 21, 16));
    expect(range.endUtc, DateTime.utc(2026, 9, 22, 16));
  });

  test('同日入住退房為 0 天', () {
    expect(
      DailyCareDateHelper.careDates(
        checkIn: DateTime(2026, 9, 16),
        checkOut: DateTime(2026, 9, 16),
      ),
      isEmpty,
    );
  });

  test('安親只取服務當日', () {
    expect(
      DailyCareDateHelper.daycareCareDates(
        serviceDate: DateTime(2026, 9, 16, 10, 30),
      ).map(DailyCareDateHelper.dateKey),
      <String>['2026/09/16'],
    );
  });
}
