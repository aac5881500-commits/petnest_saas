// lib/core/services/daycare_date_availability.dart
// 🐾 臨托可預約日期判斷：與 Cloud Function 同一套順序

import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareDayHours {
  const DaycareDayHours({
    required this.openTime,
    required this.closeTime,
    required this.earliestDropOff,
    required this.latestPickUp,
    this.latestDropoffTime = '',
  });

  final String openTime;
  final String closeTime;
  final String earliestDropOff;
  final String latestPickUp;

  /// 當日最晚可送達；空白表示不另限
  final String latestDropoffTime;
}

class DaycareDateAvailability {
  DaycareDateAvailability._();

  /// 1. 特別關閉 → 不可預約
  /// 2. 特別開放 → 可預約（覆寫星期）
  /// 3. 沒有例外 → 依可預約星期
  static bool isDateOpen({
    required DaycareSettingsModel settings,
    required DateTime date,
    DaycareDateOverrideModel? override,
  }) {
    if (override != null) {
      return override.isOpen;
    }
    return settings.weekdays.contains(DaycareTimeHelper.weekdayTaiwan(date));
  }

  static int dailyMaxPets({
    required DaycareSettingsModel settings,
    DaycareDateOverrideModel? override,
  }) {
    if (override != null && override.maxPets > 0) {
      return override.maxPets;
    }
    return settings.dailyMaxPets;
  }

  static DaycareDayHours hours({
    required DaycareSettingsModel settings,
    DaycareDateOverrideModel? override,
  }) {
    final String openTime = _orDefault(override?.openTime, settings.openTime);
    final String closeTime = _orDefault(
      override?.closeTime,
      settings.closeTime,
    );
    return DaycareDayHours(
      openTime: openTime,
      closeTime: closeTime,
      earliestDropOff: _orDefault(override?.openTime, settings.earliestDropOff),
      latestPickUp: _orDefault(
        _firstNonEmpty(override?.latestPickupTime, override?.closeTime),
        settings.latestPickUp,
      ),
      latestDropoffTime: (override?.latestDropoffTime ?? '').trim(),
    );
  }

  static String _firstNonEmpty(String? a, String? b) {
    final String first = (a ?? '').trim();
    if (first.isNotEmpty) {
      return first;
    }
    return (b ?? '').trim();
  }

  static String _orDefault(String? value, String fallback) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }
}
