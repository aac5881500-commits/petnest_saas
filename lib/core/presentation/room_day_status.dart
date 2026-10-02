// 檔案名稱：lib/core/presentation/room_day_status.dart
// 功能說明：單一房間單一日期的顯示狀態與可否操作，桌機房務總覽左右兩側共用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';

/// 過去且沒有有效訂單的日期，一律以灰色歷史日期呈現。
const Color roomDayHistoryColor = Color(0xFFBDBDBD);

const String roomDayHistoryLabel = '歷史日期';

const List<String> _activeBookingStatuses = <String>[
  'pending',
  'confirmed',
  'checked_in',
  'checked_out',
  'completed',
];

DateTime roomDayOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// 已取消、無效、草稿等不算有效訂單。
bool isActiveRoomDayBooking(Map<String, dynamic>? booking) {
  if (booking == null) {
    return false;
  }
  return _activeBookingStatuses.contains((booking['status'] ?? '').toString());
}

bool roomDayBookingCovers({
  required Map<String, dynamic> booking,
  required DateTime date,
}) {
  final DateTime day = roomDayOnly(date);
  if (BookingKind.isDaycare(booking)) {
    final DateTime? service = DailyCareDaycareAccess.serviceCalendarDate(
      booking,
    );
    if (service == null) {
      return false;
    }
    return day.year == service.year &&
        day.month == service.month &&
        day.day == service.day;
  }
  final DateTime? start = _asTaipeiDate(booking['startDate']);
  final DateTime? end = _asTaipeiDate(booking['endDate']);
  if (start == null || end == null) {
    return false;
  }
  return !day.isBefore(start) && day.isBefore(end);
}

/// 安親有效占房：active、同一房、同一 booking、serviceDate 對到該日。
bool daycareOccupancyCoversRoomDay({
  required Map<String, dynamic> occupancy,
  required String roomId,
  required String bookingId,
  required DateTime day,
}) {
  if ((occupancy['status'] ?? '').toString() != 'active') {
    return false;
  }
  if (roomId.isEmpty || (occupancy['roomId'] ?? '').toString() != roomId) {
    return false;
  }
  if (bookingId.isEmpty ||
      (occupancy['bookingId'] ?? '').toString() != bookingId) {
    return false;
  }
  final DateTime wanted = roomDayOnly(day);
  final String raw = (occupancy['serviceDate'] ?? '').toString().trim();
  if (raw.isNotEmpty) {
    final String normalized = raw.contains('/')
        ? raw
        : raw.replaceAll('-', '/');
    final DateTime? parsed = DailyCareDateHelper.parseDateKey(normalized);
    if (parsed == null) {
      return false;
    }
    final DateTime service = DailyCareDateHelper.dateOnly(parsed);
    return service.year == wanted.year &&
        service.month == wanted.month &&
        service.day == wanted.day;
  }
  final DateTime? start = _asTaipeiDate(occupancy['startAt']);
  if (start == null) {
    return false;
  }
  return start.year == wanted.year &&
      start.month == wanted.month &&
      start.day == wanted.day;
}

/// 安親服務時段，台灣時間。缺資料時不顯示。
String daycareServiceTimeLabel(Map<String, dynamic> booking) {
  final String start = _taipeiClock(booking['scheduledStartAt']);
  final String end = _taipeiClock(booking['scheduledEndAt']);
  if (start.isEmpty || end.isEmpty) {
    return '';
  }
  return '$start～$end';
}

bool roomBookingVisibleInMonth({
  required Map<String, dynamic> booking,
  required DateTime monthStart,
  required DateTime nextMonthStart,
}) {
  if (BookingKind.isDaycare(booking)) {
    final DateTime? service = DailyCareDaycareAccess.serviceCalendarDate(
      booking,
    );
    if (service == null) {
      return false;
    }
    return !service.isBefore(monthStart) && service.isBefore(nextMonthStart);
  }
  final DateTime? start = _asDate(booking['startDate']);
  final DateTime? end = _asDate(booking['endDate']);
  if (start == null || end == null) {
    return false;
  }
  return start.isBefore(nextMonthStart) && end.isAfter(monthStart);
}

/// 同一天有多筆有效訂單時的取用順序，讓左右兩側取到同一筆。
int roomDayBookingPriority(Map<String, dynamic> booking) {
  switch ((booking['status'] ?? '').toString()) {
    case 'checked_in':
      return 3;
    case 'confirmed':
      return 2;
    case 'pending':
      return 1;
    case 'completed':
    case 'checked_out':
      return 0;
    default:
      return -1;
  }
}

class RoomDayStatus {
  const RoomDayStatus({
    required this.presentation,
    required this.isPast,
    required this.hasActiveBooking,
  });

  final RoomStatusPresentation presentation;
  final bool isPast;
  final bool hasActiveBooking;

  /// 過去而且沒有有效訂單，就只是歷史日期，不再用營運色強調。
  bool get isHistory => isPast && !hasActiveBooking;

  /// 過去日期一律唯讀，有訂單也不開放變更房間狀態。
  bool get canEditStatus => !isPast;

  Color get color => isHistory ? roomDayHistoryColor : presentation.color;

  String get label => isHistory ? roomDayHistoryLabel : presentation.label;
}

/// 房間 + 日期 → 顯示狀態。左側 7 天點與右側月曆都用這一支。
RoomDayStatus resolveRoomDayStatus({
  required DateTime date,
  required DateTime today,
  Map<String, dynamic> room = const <String, dynamic>{},
  String calendarStatus = '',
  Map<String, dynamic>? booking,
}) {
  final Map<String, dynamic>? activeBooking = isActiveRoomDayBooking(booking)
      ? booking
      : null;
  return RoomDayStatus(
    presentation: roomDayPresentation(
      room: room,
      calendarStatus: calendarStatus,
      booking: activeBooking,
    ),
    isPast: roomDayOnly(date).isBefore(roomDayOnly(today)),
    hasActiveBooking: activeBooking != null,
  );
}

/// 房務總覽所有日期燈共用的優先順序。
/// 維修／不可用、今日關閉、清潔中、入住中、住宿（含已退房）、安親、其餘。
RoomStatusPresentation roomDayPresentation({
  required Map<String, dynamic> room,
  required String calendarStatus,
  Map<String, dynamic>? booking,
}) {
  if (!DaycareOccupancyService.isRoomEnabled(room)) {
    return RoomStatusPresentation.disabled();
  }
  if (DaycareOccupancyService.isPermanentStatusUnsellable(
    DaycareOccupancyService.permanentStatusOf(room),
  )) {
    return RoomStatusPresentation.maintenance();
  }
  final String calendar = calendarStatus.trim().toLowerCase();
  if (calendar == 'disabled' || calendar == 'inactive') {
    return RoomStatusPresentation.disabled();
  }
  if (calendar == 'blocked' ||
      calendar == 'maintenance' ||
      calendar == 'unavailable') {
    return RoomStatusPresentation.maintenance();
  }
  if (calendar == 'closed') {
    return RoomStatusPresentation.closed();
  }
  if (calendar == 'cleaning') {
    return RoomStatusPresentation.cleaning();
  }
  if (calendar == 'checkout_cleaning') {
    return RoomStatusPresentation.checkoutHold();
  }
  final String bookingStatus = (booking?['status'] ?? '').toString();
  final bool stay = booking != null && !BookingKind.isDaycare(booking);
  final bool daycare = booking != null && BookingKind.isDaycare(booking);
  if (stay && bookingStatus == 'checked_in') {
    return RoomStatusPresentation.stayCheckedIn();
  }
  if (stay) {
    return RoomStatusPresentation.stayBooked();
  }
  if (daycare && bookingStatus == 'checked_in') {
    return RoomStatusPresentation.daycareCheckedIn();
  }
  if (daycare) {
    return RoomStatusPresentation.daycareBooked();
  }
  if (calendar == 'completed') {
    return RoomStatusPresentation.completed();
  }
  if (calendar == 'checked_in' || calendar == 'occupied') {
    return RoomStatusPresentation.stayCheckedIn();
  }
  if (calendar == 'booked' || calendar == 'occupied_stay') {
    return RoomStatusPresentation.stayBooked();
  }
  if (calendar == 'booked_daycare' ||
      calendar == 'daycare' ||
      calendar == 'occupied_daycare') {
    return calendar == 'occupied_daycare'
        ? RoomStatusPresentation.daycareCheckedIn()
        : RoomStatusPresentation.daycareBooked();
  }
  return RoomStatusPresentation.available();
}

DateTime? _asDate(Object? raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  return null;
}

DateTime? _asTaipeiDate(Object? raw) {
  final DateTime? date = _asDate(raw);
  if (date == null) {
    return null;
  }
  return DailyCareDateHelper.calendarDateInTaipei(date);
}

String _taipeiClock(Object? raw) {
  final DateTime? instant = _asDate(raw);
  if (instant == null) {
    return '';
  }
  final DateTime taipei = instant.toUtc().add(const Duration(hours: 8));
  final String hour = taipei.hour.toString().padLeft(2, '0');
  final String minute = taipei.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
