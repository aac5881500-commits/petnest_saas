// 檔案名稱：lib/core/services/daily_care_daycare_access.dart
// 功能說明：安親是否可填／可看既有每日照護紀錄（同一套系統，不另建 collection）

import '../models/booking_kind.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_setting_model.dart';

class DailyCareDaycareAccess {
  DailyCareDaycareAccess._();

  static DateTime? serviceCalendarDate(Map<String, dynamic> booking) {
    final Object? start = booking['scheduledStartAt'] ?? booking['startDate'];
    DateTime? instant;
    if (start is DateTime) {
      instant = start;
    } else {
      try {
        instant = (start as dynamic).toDate() as DateTime?;
      } catch (_) {}
    }
    final String key = (booking['serviceDate'] ?? '').toString().trim();
    if (key.isNotEmpty) {
      final String normalized = key.contains('/')
          ? key
          : key.replaceAll('-', '/');
      final DateTime? parsed = DailyCareDateHelper.parseDateKey(normalized);
      if (parsed != null) {
        return DailyCareDateHelper.dateOnly(parsed);
      }
    }
    if (instant != null) {
      return DailyCareDateHelper.calendarDateInTaipei(instant);
    }
    return null;
  }

  static String _status(Map<String, dynamic> booking) {
    return (booking['status'] ?? '').toString().trim();
  }

  /// 已報到／入住或服務已結束（退房後仍可依期限看照片與下載）。
  static bool hasStartedCare(Map<String, dynamic> booking) {
    final String status = _status(booking);
    return status == 'checked_in' ||
        status == 'completed' ||
        status == 'checked_out';
  }

  static bool canOperate({
    required DailyCareSettingModel setting,
    required Map<String, dynamic> booking,
    DateTime? now,
  }) {
    if (!setting.daycareEnabled) {
      return false;
    }
    if (!BookingKind.isDaycare(booking)) {
      return false;
    }
    if (_status(booking) != 'checked_in') {
      return false;
    }
    if (serviceCalendarDate(booking) == null) {
      return false;
    }
    return true;
  }

  static bool canCustomerView({
    required DailyCareSettingModel setting,
    required Map<String, dynamic> booking,
    DateTime? now,
  }) {
    if (!setting.daycareEnabled) {
      return false;
    }
    if (!BookingKind.isDaycare(booking)) {
      return false;
    }
    return hasStartedCare(booking);
  }
}
