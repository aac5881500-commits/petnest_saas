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
    final String roomName = daycare ? '' : stay.roomName.trim();
    final String roomId = daycare
        ? ''
        : (booking['roomId'] ?? '').toString().trim();
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
          customerName: customerNameOf(booking),
          petIds: petIds,
          petNames: petNames,
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
