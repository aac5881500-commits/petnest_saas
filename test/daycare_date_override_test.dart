// 檔案名稱：test/daycare_date_override_test.dart
// 功能說明：安親日期覆寫的單元測試（沒有例外設定時所有日期預設可預約，不再依星期關閉）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';

void main() {
  const DaycareSettingsModel weekdayOnly = DaycareSettingsModel(
    weekdays: <int>[1, 2, 3, 4, 5],
    earliestDropOff: '09:00',
    latestPickUp: '18:00',
    minDurationMinutes: 60,
    maxDurationMinutes: 480,
    allowSameDay: true,
    minAdvanceHours: 0,
  );

  test('沒有例外設定時所有日期預設可預約，不再依星期關閉', () {
    final DateTime monday = DateTime(2026, 9, 7, 10);
    final DateTime sunday = DateTime(2026, 9, 6, 10);
    expect(
      DaycareDateAvailability.isDateOpen(settings: weekdayOnly, date: monday),
      isTrue,
    );
    expect(
      DaycareDateAvailability.isDateOpen(settings: weekdayOnly, date: sunday),
      isTrue,
    );
  });

  test('明確關閉覆寫預設開放', () {
    final DateTime monday = DateTime(2026, 9, 7, 10);
    const DaycareDateOverrideModel closed = DaycareDateOverrideModel(
      id: '20260907',
      date: '2026-09-07',
      isOpen: false,
    );
    expect(
      DaycareDateAvailability.isDateOpen(
        settings: weekdayOnly,
        date: monday,
        override: closed,
      ),
      isFalse,
    );
    expect(
      DaycareBookingValidator.validateSchedule(
        settings: weekdayOnly,
        startAt: monday,
        endAt: DateTime(2026, 9, 7, 12),
        isAdmin: true,
        dateOverride: closed,
      ).isOk,
      isFalse,
    );
  });

  test('舊的特別開放文件視為可預約', () {
    final DateTime sunday = DateTime(2026, 9, 6, 10);
    const DaycareDateOverrideModel opened = DaycareDateOverrideModel(
      id: '20260906',
      date: '2026-09-06',
      isOpen: true,
    );
    expect(
      DaycareDateAvailability.isDateOpen(
        settings: weekdayOnly,
        date: sunday,
        override: opened,
      ),
      isTrue,
    );
  });

  test('每日接待量不再被單日 maxPets 覆寫', () {
    expect(
      DaycareDateAvailability.dailyMaxPets(settings: weekdayOnly),
      weekdayOnly.dailyMaxPets,
    );
    expect(
      DaycareDateAvailability.dailyMaxPets(
        settings: weekdayOnly,
        override: const DaycareDateOverrideModel(
          id: '20260907',
          date: '2026-09-07',
          isOpen: true,
          maxPets: 3,
        ),
      ),
      weekdayOnly.dailyMaxPets,
    );
  });

  test('沒有 isOpen 欄位的舊例外視為可預約，closed 仍關閉', () {
    final DaycareDateOverrideModel missing = DaycareDateOverrideModel.fromMap(
      const <String, dynamic>{'date': '2026-09-07'},
      id: '20260907',
    );
    expect(missing.isOpen, isTrue);
    final DaycareDateOverrideModel closed = DaycareDateOverrideModel.fromMap(
      const <String, dynamic>{'date': '2026-09-07', 'closed': true},
      id: '20260907',
    );
    expect(closed.isOpen, isFalse);
    final DaycareDateOverrideModel flag = DaycareDateOverrideModel.fromMap(
      const <String, dynamic>{'date': '2026-09-07', 'isOpen': '0'},
      id: '20260907',
    );
    expect(flag.isOpen, isFalse);
  });

  test('每日上限 0 代表不限制', () {
    expect(
      DaycareDateAvailability.dailyMaxPets(
        settings: const DaycareSettingsModel(dailyMaxPets: 0),
      ),
      0,
    );
  });
}
