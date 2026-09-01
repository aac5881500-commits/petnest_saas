// test/daycare_date_override_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

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

  test('沒有例外設定時依可預約星期', () {
    final DateTime monday = DateTime(2026, 9, 7, 10);
    final DateTime sunday = DateTime(2026, 9, 6, 10);
    expect(
      DaycareDateAvailability.isDateOpen(settings: weekdayOnly, date: monday),
      isTrue,
    );
    expect(
      DaycareDateAvailability.isDateOpen(settings: weekdayOnly, date: sunday),
      isFalse,
    );
  });

  test('特別關閉覆寫原本開放的星期', () {
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

  test('特別開放覆寫原本不開放的星期', () {
    final DateTime sunday = DateTime(2026, 9, 6, 10);
    const DaycareDateOverrideModel opened = DaycareDateOverrideModel(
      id: '20260906',
      date: '2026-09-06',
      isOpen: true,
      openTime: '10:00',
      closeTime: '16:00',
    );
    expect(
      DaycareDateAvailability.isDateOpen(
        settings: weekdayOnly,
        date: sunday,
        override: opened,
      ),
      isTrue,
    );
    expect(
      DaycareBookingValidator.validateSchedule(
        settings: weekdayOnly,
        startAt: sunday,
        endAt: DateTime(2026, 9, 6, 12),
        isAdmin: true,
        dateOverride: opened,
      ).isOk,
      isTrue,
    );
  });

  test('當日 maxPets 留空沿用平日設定', () {
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
      3,
    );
  });

  test('override 文件 ID 為 yyyyMMdd', () {
    expect(DaycareTimeHelper.overrideDocId(DateTime(2026, 9, 1)), '20260901');
  });
}
