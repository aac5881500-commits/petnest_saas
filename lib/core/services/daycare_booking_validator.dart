// lib/core/services/daycare_booking_validator.dart
// 🐾 臨托送出前驗證：時間、名額、寵物限制（後端仍會再驗一次）

import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareValidationResult {
  const DaycareValidationResult.ok() : error = null;
  const DaycareValidationResult.error(this.error);

  final String? error;
  bool get isOk => error == null;
}

class DaycareBookingValidator {
  DaycareBookingValidator._();

  static DaycareValidationResult validateSchedule({
    required DaycareSettingsModel settings,
    required DateTime startAt,
    required DateTime endAt,
    bool isAdmin = false,
    DateTime? now,
    DaycareDateOverrideModel? dateOverride,
  }) {
    if (!startAt.isBefore(endAt)) {
      return const DaycareValidationResult.error('送達時間不得晚於接回時間');
    }
    final int minutes = endAt.difference(startAt).inMinutes;
    if (minutes < settings.minDurationMinutes) {
      return const DaycareValidationResult.error('未達最短臨托時間');
    }
    if (minutes > settings.maxDurationMinutes) {
      return const DaycareValidationResult.error('已超過最長臨托時間');
    }
    if (settings.forbidOvernight &&
        !DaycareTimeHelper.sameCalendarDay(startAt, endAt)) {
      return const DaycareValidationResult.error('此店家不接受跨日臨托');
    }
    if (!DaycareDateAvailability.isDateOpen(
      settings: settings,
      date: startAt,
      override: dateOverride,
    )) {
      return const DaycareValidationResult.error('該日期不開放臨托');
    }
    final DaycareDayHours hours = DaycareDateAvailability.hours(
      settings: settings,
      override: dateOverride,
    );
    if (settings.blockOutsideHours) {
      final int startMin = startAt.hour * 60 + startAt.minute;
      final int endMin = endAt.hour * 60 + endAt.minute;
      if (startMin < DaycareTimeHelper.minutesOf(hours.earliestDropOff) ||
          endMin > DaycareTimeHelper.minutesOf(hours.latestPickUp)) {
        return const DaycareValidationResult.error('已超出臨托營業時間');
      }
      if (hours.latestDropoffTime.isNotEmpty &&
          startMin > DaycareTimeHelper.minutesOf(hours.latestDropoffTime)) {
        return const DaycareValidationResult.error('已超過當日最晚送達時間');
      }
    }
    if (!isAdmin) {
      final DateTime clock = now ?? DateTime.now();
      if (!settings.allowSameDay &&
          DaycareTimeHelper.sameCalendarDay(startAt, clock)) {
        return const DaycareValidationResult.error('不可預約當日臨托');
      }
      if (settings.minAdvanceHours > 0 &&
          startAt.difference(clock).inHours < settings.minAdvanceHours) {
        return const DaycareValidationResult.error('需提前預約');
      }
    }
    return const DaycareValidationResult.ok();
  }

  static DaycareValidationResult validatePets({
    required DaycareSettingsModel settings,
    required int petCount,
    required List<String> petTypes,
    required bool anyUnneutered,
    required bool missingVaccine,
    required bool blacklisted,
  }) {
    if (petCount < settings.minPets || petCount > settings.maxPets) {
      return const DaycareValidationResult.error('寵物數量不符合臨托限制');
    }
    if (settings.allowedPetTypes.isNotEmpty) {
      for (final String type in petTypes) {
        if (!settings.allowedPetTypes.contains(type)) {
          return const DaycareValidationResult.error('有寵物類型不在臨托允許範圍');
        }
      }
    }
    if (blacklisted) {
      return const DaycareValidationResult.error('此會員目前無法預約臨托');
    }
    return const DaycareValidationResult.ok();
  }

  static DaycareValidationResult validatePlan({
    required DaycarePlanModel plan,
    required DateTime startAt,
  }) {
    if (!plan.enabled) {
      return const DaycareValidationResult.error('臨托方案未啟用');
    }
    if (!plan.weekdays.contains(DaycareTimeHelper.weekdayTaiwan(startAt))) {
      return const DaycareValidationResult.error('此方案不適用該星期');
    }
    return const DaycareValidationResult.ok();
  }

  static DaycareValidationResult validateAllowedAddons({
    required DaycareSettingsModel settings,
    required List<String> addonIds,
  }) {
    for (final String id in addonIds) {
      if (!settings.allowsAddon(id)) {
        return const DaycareValidationResult.error('所選加購服務未開放臨托');
      }
    }
    return const DaycareValidationResult.ok();
  }
}

class DaycareStatusMachine {
  DaycareStatusMachine._();

  static const Map<String, List<String>> allowed = <String, List<String>>{
    'pending': <String>['confirmed', 'cancelled'],
    'confirmed': <String>['checked_in', 'cancelled'],
    'checked_in': <String>['completed', 'cancelled'],
    'completed': <String>[],
    'cancelled': <String>[],
  };

  static bool canTransit(String from, String to) {
    return (allowed[from] ?? const <String>[]).contains(to);
  }

  static bool canAssignRoom(String status) {
    return status == 'confirmed' || status == 'checked_in';
  }

  static bool canCheckIn({required String status, required String roomId}) {
    return status == 'confirmed' && roomId.trim().isNotEmpty;
  }

  static bool canComplete(String status) {
    return status == 'checked_in';
  }
}

class DaycareConversionHelper {
  DaycareConversionHelper._();

  static const String keepDaycare = 'keep_daycare';
  static const String creditAll = 'credit_all';
  static const String custom = 'custom';
  static const String cancelFee = 'cancel_daycare_fee';

  static int credit({
    required String policy,
    required int daycareTotal,
    int customAmount = 0,
  }) {
    if (policy == creditAll || policy == cancelFee) {
      return daycareTotal < 0 ? 0 : daycareTotal;
    }
    if (policy == custom) {
      if (customAmount < 0) {
        return 0;
      }
      return customAmount > daycareTotal ? daycareTotal : customAmount;
    }
    return 0;
  }
}

class ServiceScope {
  ServiceScope._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';
  static const String both = 'both';

  /// 舊資料沒有欄位時視為住宿，避免住宿優惠誤套到臨托。
  static bool applies(String? raw, String bookingKind) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) {
      return bookingKind == accommodation;
    }
    if (value == both) {
      return true;
    }
    return value == bookingKind;
  }
}
