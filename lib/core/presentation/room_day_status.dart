// 檔案名稱：lib/core/presentation/room_day_status.dart
// 功能說明：單一房間單一日期的顯示狀態與可否操作，桌機房務總覽左右兩側共用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';

/// 過去且沒有有效訂單的日期，一律以灰色歷史日期呈現。
const Color roomDayHistoryColor = Color(0xFFBDBDBD);

const String roomDayHistoryLabel = '歷史日期';

const List<String> _activeBookingStatuses = <String>[
  'pending',
  'confirmed',
  'checked_in',
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
  final DateTime? start = _asDate(booking['startDate']);
  final DateTime? end = _asDate(booking['endDate']);
  if (start == null || end == null) {
    return false;
  }
  final DateTime day = roomDayOnly(date);
  return !day.isBefore(roomDayOnly(start)) && day.isBefore(roomDayOnly(end));
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
  final String label = DaycareOccupancyService.housekeepingLabel(
    room: room,
    calendarStatus: calendarStatus,
    stayBooking: activeBooking,
  );
  return RoomDayStatus(
    presentation: RoomStatusPresentation.fromHousekeepingLabel(
      label,
      booking: activeBooking,
    ),
    isPast: roomDayOnly(date).isBefore(roomDayOnly(today)),
    hasActiveBooking: activeBooking != null,
  );
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
