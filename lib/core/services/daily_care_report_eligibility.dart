// 檔案名稱：lib/core/services/daily_care_report_eligibility.dart
// 功能說明：住宿／安親訂單每日照護回報資格與場次解析共用邏輯。

import '../models/booking_kind.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_entitlement.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_report_center_item.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import 'daily_care_daycare_access.dart';
import 'daily_care_record_service.dart';

class DailyCareReportEligibility {
  DailyCareReportEligibility._();

  static DailyCareEntitlement entitlementOf(Map<String, dynamic> booking) {
    final Object? raw = booking['dailyCareEntitlement'];
    if (raw is! Map) {
      return const DailyCareEntitlement();
    }
    try {
      return DailyCareEntitlement.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const DailyCareEntitlement();
    }
  }

  static bool isEntitled(DailyCareEntitlement entitlement) {
    return entitlement.enabled && entitlement.finalReports >= 1;
  }

  static bool stayQualifiesToday({
    required Map<String, dynamic> booking,
    required DateTime today,
    DailyCareEntitlement? entitlement,
  }) {
    if (BookingKind.isDaycare(booking)) {
      return false;
    }
    if ((booking['status'] ?? '').toString().trim() != 'checked_in') {
      return false;
    }
    final DailyCareEntitlement rights = entitlement ?? entitlementOf(booking);
    if (!isEntitled(rights)) {
      return false;
    }
    return _isTodayCovered(
      booking: booking,
      entitlement: rights,
      today: today,
      daycare: false,
    );
  }

  static bool daycareQualifiesToday({
    required DailyCareSettingModel setting,
    required Map<String, dynamic> booking,
    required DateTime today,
    DailyCareEntitlement? entitlement,
  }) {
    final DailyCareEntitlement rights = entitlement ?? entitlementOf(booking);
    if (!isEntitled(rights)) {
      return false;
    }
    if (!DailyCareDaycareAccess.canOperate(
      setting: setting,
      booking: booking,
    )) {
      return false;
    }
    return _isTodayCovered(
      booking: booking,
      entitlement: rights,
      today: today,
      daycare: true,
    );
  }

  static String sessionName({
    required DailyCareEntitlement entitlement,
    required DailyCareSettingModel setting,
    required int sessionIndex,
  }) {
    if (sessionIndex >= 0 && sessionIndex < entitlement.sessionLabels.length) {
      final String label = entitlement.sessionLabels[sessionIndex].trim();
      if (label.isNotEmpty) {
        return label;
      }
    }
    return setting.sessionLabelAt(sessionIndex);
  }

  static List<String> petIdsOf(Map<String, dynamic> booking) {
    final Object? raw = booking['petIds'];
    if (raw is Iterable) {
      return raw
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final Object? pets = booking['pets'];
    if (pets is! Iterable) {
      return const <String>[];
    }
    return pets
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              (item['petId'] ?? item['id'] ?? '').toString().trim(),
        )
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  static String customerNameOf(Map<String, dynamic> booking) {
    for (final String key in <String>[
      'customerName',
      'userName',
      'memberName',
      'ownerName',
    ]) {
      final String value = (booking[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String bookingIdOf(Map<String, dynamic> booking) {
    final String id = (booking['bookingId'] ?? booking['id'] ?? '')
        .toString()
        .trim();
    return id;
  }

  static List<DailyCareReportCenterItem> expandBooking({
    required String shopId,
    required Map<String, dynamic> booking,
    required DailyCareSettingModel setting,
    required DateTime today,
    required bool canOperate,
    required bool daycare,
    Set<String> completedIds = const <String>{},
    Map<String, DateTime?> updatedAtById = const <String, DateTime?>{},
  }) {
    final DailyCareEntitlement entitlement = entitlementOf(booking);
    final bool qualifies = daycare
        ? daycareQualifiesToday(
            setting: setting,
            booking: booking,
            today: today,
            entitlement: entitlement,
          )
        : stayQualifiesToday(
            booking: booking,
            today: today,
            entitlement: entitlement,
          );
    if (!qualifies) {
      return const <DailyCareReportCenterItem>[];
    }
    final String bookingId = bookingIdOf(booking);
    if (bookingId.isEmpty) {
      return const <DailyCareReportCenterItem>[];
    }
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    final List<String> petIds = petIdsOf(booking);
    final List<String> petNames = stay.pets
        .map((DailyCareStayPet pet) => pet.name.trim())
        .where((String name) => name.isNotEmpty)
        .toList();
    final String petPhotoUrl = stay.pets
        .map((DailyCareStayPet pet) => pet.photoUrl.trim())
        .firstWhere((String url) => url.isNotEmpty, orElse: () => '');
    final String roomName = daycare ? '' : stay.roomName.trim();
    final String roomId = daycare
        ? ''
        : (booking['roomId'] ?? '').toString().trim();
    final String bookingCode = (booking['bookingCode'] ?? '').toString().trim();
    final String roomTypeName = roomTypeNameOf(booking);
    int? stayDayIndex;
    int? stayDayTotal;
    if (!daycare) {
      final List<String> careKeys = stay.careDateKeys();
      stayDayTotal = careKeys.isEmpty ? null : careKeys.length;
      final int idx = careKeys.indexOf(DailyCareDateHelper.dateKey(today));
      stayDayIndex = idx >= 0 ? idx + 1 : null;
    }
    final DateTime? daycareStart = daycare
        ? (_readInstant(booking['actualStartAt']) ??
              _readInstant(booking['scheduledStartAt']))
        : null;
    final DateTime? daycareEnd = daycare
        ? (_readInstant(booking['actualEndAt']) ??
              _readInstant(booking['scheduledEndAt']))
        : null;
    final String daycareTimeLabel = daycare
        ? _daycareTimeLabel(start: daycareStart, end: daycareEnd)
        : '';
    final int sessions = entitlement.finalReports;
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[];
    for (int index = 0; index < sessions; index++) {
      final String recordId = DailyCareRecordService.recordId(
        bookingId: bookingId,
        recordDate: today,
        sessionIndex: index,
      );
      items.add(
        DailyCareReportCenterItem(
          id: recordId,
          shopId: shopId,
          bookingId: bookingId,
          sourceCollection: 'bookings',
          serviceType: daycare
              ? DailyCareServiceTypes.daycare
              : DailyCareServiceTypes.accommodation,
          roomId: roomId,
          roomName: roomName,
          roomTypeName: roomTypeName,
          bookingCode: bookingCode,
          customerName: customerNameOf(booking),
          petIds: petIds,
          petNames: petNames,
          petPhotoUrl: petPhotoUrl,
          checkInDate: daycare ? null : stay.startDate,
          checkOutDate: daycare ? null : stay.endDate,
          stayDayIndex: stayDayIndex,
          stayDayTotal: stayDayTotal,
          daycareStartAt: daycareStart,
          daycareEndAt: daycareEnd,
          daycareTimeLabel: daycareTimeLabel,
          recordDate: today,
          sessionIndex: index,
          sessionName: sessionName(
            entitlement: entitlement,
            setting: setting,
            sessionIndex: index,
          ),
          isCompleted: completedIds.contains(recordId),
          updatedAt: updatedAtById[recordId],
          entitlement: entitlement,
          canOperate: canOperate,
        ),
      );
    }
    return items;
  }

  static String roomTypeNameOf(Map<String, dynamic> booking) {
    for (final String key in <String>[
      'roomTypeName',
      'roomTypeNameSnapshot',
      'typeName',
    ]) {
      final String value = (booking[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    final Object? raw = booking['roomType'];
    if (raw is Map) {
      final String name = (raw['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return '';
  }

  static DateTime? _readInstant(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    try {
      return (raw as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  static String _clock(DateTime value) {
    final DateTime taipei = value.toUtc().add(const Duration(hours: 8));
    return '${taipei.hour.toString().padLeft(2, '0')}:'
        '${taipei.minute.toString().padLeft(2, '0')}';
  }

  static String _daycareTimeLabel({DateTime? start, DateTime? end}) {
    if (start != null && end != null) {
      return '${_clock(start)} ～ ${_clock(end)}';
    }
    if (start != null) {
      return '送達 ${_clock(start)}';
    }
    if (end != null) {
      return '接回 ${_clock(end)}';
    }
    return '';
  }

  static bool _isTodayCovered({
    required Map<String, dynamic> booking,
    required DailyCareEntitlement entitlement,
    required DateTime today,
    required bool daycare,
  }) {
    if (entitlement.serviceDates.isNotEmpty) {
      return containsServiceDate(entitlement.serviceDates, today);
    }
    if (daycare) {
      final DateTime? serviceDate = DailyCareDaycareAccess.serviceCalendarDate(
        booking,
      );
      if (serviceDate == null) {
        return false;
      }
      return DailyCareDateHelper.dateKey(serviceDate) ==
          DailyCareDateHelper.dateKey(today);
    }
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    return DailyCareDateHelper.isCareDate(
      date: today,
      checkIn: stay.startDate,
      checkOut: stay.endDate,
    );
  }

  /// 整筆住宿應填場次數：照護日期 × 每日場次（`finalReports`）。
  static int stayScheduledSessionTotal(
    Map<String, dynamic> booking, {
    DailyCareSettingModel? setting,
  }) {
    final DailyCareEntitlement entitlement = entitlementOf(booking);
    int perDay = entitlement.finalReports;
    if (perDay < 1) {
      perDay = setting?.sessionCount ?? 0;
    }
    if (perDay < 1) {
      perDay = entitlement.sessionLabels.length;
    }
    if (perDay < 1) {
      return 0;
    }
    final List<DateTime> dates = stayCareDates(booking);
    final int days = dates.isEmpty ? 0 : dates.length;
    return days * perDay;
  }

  static int staySessionPerDay(
    Map<String, dynamic> booking, {
    DailyCareSettingModel? setting,
  }) {
    final DailyCareEntitlement entitlement = entitlementOf(booking);
    if (entitlement.finalReports >= 1) {
      return entitlement.finalReports;
    }
    if (setting != null && setting.sessionCount >= 1) {
      return setting.sessionCount;
    }
    return entitlement.sessionLabels.length;
  }

  static List<DateTime> stayCareDates(Map<String, dynamic> booking) {
    final DailyCareEntitlement entitlement = entitlementOf(booking);
    if (entitlement.serviceDates.isNotEmpty) {
      final List<DateTime> parsed = <DateTime>[];
      for (final String raw in entitlement.serviceDates) {
        final DateTime? date = DailyCareDateHelper.parseDateKey(
          raw.replaceAll('-', '/'),
        );
        if (date != null) {
          parsed.add(date);
        }
      }
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    return stay
        .careDateKeys()
        .map(DailyCareDateHelper.parseDateKey)
        .whereType<DateTime>()
        .toList();
  }

  static int completedSessionCount(List<DailyCareRecordModel> records) {
    final Set<String> keys = <String>{};
    for (final DailyCareRecordModel record in records) {
      keys.add(
        '${DailyCareDateHelper.dateKey(record.recordDate)}#${record.sessionIndex}',
      );
    }
    return keys.length;
  }

  /// 本日可填場次數範圍內，第一個尚未有紀錄的 sessionIndex；全完成則回 0。
  static int firstIncompleteSessionIndex({
    required int sessionCount,
    required Iterable<int> completedIndexes,
  }) {
    final int count = sessionCount < 1 ? 1 : sessionCount;
    final Set<int> done = completedIndexes.toSet();
    for (int index = 0; index < count; index++) {
      if (!done.contains(index)) {
        return index;
      }
    }
    return 0;
  }

  /// 優先今天（若為照護日），否則用既有 currentCareDate。
  static DateTime stayFillDate(Map<String, dynamic> booking) {
    final DateTime today = DailyCareDateHelper.todayInTaipei();
    final String todayKey = DailyCareDateHelper.dateKey(today);
    for (final DateTime date in stayCareDates(booking)) {
      if (DailyCareDateHelper.dateKey(date) == todayKey) {
        return DailyCareDateHelper.dateOnly(date);
      }
    }
    return DailyCareStayInfo.fromBookingMap(
      booking,
    ).currentCareDate(now: today);
  }

  static bool containsServiceDate(List<String> dates, DateTime today) {
    final String slash = DailyCareDateHelper.dateKey(today);
    final String dash = slash.replaceAll('/', '-');
    final String compact = DailyCareDateHelper.recordIdDateKey(today);
    for (final String raw in dates) {
      final String value = raw.trim();
      if (value.isEmpty) {
        continue;
      }
      if (value == slash || value == dash || value == compact) {
        return true;
      }
      final String asSlash = value.replaceAll('-', '/');
      if (asSlash == slash) {
        return true;
      }
    }
    return false;
  }
}
