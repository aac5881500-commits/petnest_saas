import 'package:petnest_saas/core/models/room_status_palette.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';
import 'package:petnest_saas/features/room/widgets/workbench_booking_task.dart';

String opsDateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String opsShortDate(DateTime day) =>
    '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}';
String opsPets(Map<String, dynamic>? booking) {
  final raw = booking?['petNames'] ?? booking?['petName'] ?? booking?['pets'];
  if (raw is List) {
    return raw
        .map(
          (pet) => pet is Map ? (pet['name'] ?? '').toString() : pet.toString(),
        )
        .where((name) => name.trim().isNotEmpty)
        .join('、');
  }
  return raw is String ? raw : '';
}

String opsClock(Object? raw) {
  final instant = raw is Timestamp
      ? raw.toDate()
      : raw is DateTime
      ? raw
      : null;
  if (instant == null) return '—';
  final date = instant.toUtc().add(const Duration(hours: 8));
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

DateTime? workbenchBookingStart(Map<String, dynamic> data) =>
    workbenchBookingTaskDate(data, departure: false);
DateTime? workbenchBookingEnd(Map<String, dynamic> data) =>
    workbenchBookingTaskDate(data, departure: true);
String opsOrderRange(Map<String, dynamic> data) {
  final start = workbenchBookingStart(data), end = workbenchBookingEnd(data);
  if (BookingKind.isDaycare(data)) {
    return '${start == null ? '安親' : opsShortDate(start)} ${daycareServiceTimeLabel(data)}'
        .trim();
  }
  if (start == null || end == null) return '日期請見訂單';
  return '${opsShortDate(start)}－${opsShortDate(end)}（${end.difference(start).inDays} 晚）';
}

class OperationsRoom {
  const OperationsRoom(this.data);
  final Map<String, dynamic> data;
  String get id => (data['id'] ?? '').toString();
  String get name => (data['name'] ?? '未命名房間').toString();
  String get type => (data['roomTypeName'] ?? '未分類').toString();
}

class OperationsDay {
  const OperationsDay(this.status, this.orders);
  final RoomDayStatus status;
  final List<RoomDayBookingChoice> orders;
  RoomDayBookingChoice? get preferred => preferredRoomDayBooking(orders);
  String get pets => opsPets(preferred?.data);
  bool get hasBooking => orders.isNotEmpty;
  // Never draw a booking over maintenance, cleaning, closed or disabled cells.
  String get spanId =>
      orders.length == 1 &&
          const [
            'occupied',
            'checked_in',
            'daycare',
            'daycare_checked_in',
          ].contains(status.presentation.value)
      ? preferred!.id
      : '';
}

enum OperationsTaskGroup { arrivals, housekeeping, care }

enum OperationsTaskState { pending, active, completed }

class OperationsTask {
  const OperationsTask({
    required this.id,
    required this.group,
    required this.state,
    required this.title,
    required this.subtitle,
    required this.action,
    this.roomId = '',
    this.roomName = '',
    this.pets = '',
    this.time = '—',
    this.booking,
    this.care,
    this.order = 0,
  });
  final String id, roomId, roomName, pets, title, subtitle, action, time;
  final int order;
  final OperationsTaskGroup group;
  final OperationsTaskState state;
  final RoomDayBookingChoice? booking;
  final DailyCareReportCenterItem? care;
}

/// Read-only adapter shared by the production widget and its visual captures.
/// It always uses the existing room-day, entitlement and occupancy projections.
class OperationsWorkbenchData {
  const OperationsWorkbenchData({
    required this.rooms,
    required this.bookings,
    required this.calendar,
    required this.occupancies,
    required this.report,
    required this.date,
    required this.today,
    this.palette = RoomStatusPalette.defaults,
  });
  final List<OperationsRoom> rooms;
  final List<RoomDayBookingChoice> bookings;
  final Map<String, String> calendar;
  final List<Map<String, dynamic>> occupancies;
  final DailyCareReportCenterSnapshot? report;
  final DateTime date, today;
  final RoomStatusPalette palette;
  OperationsDay day(OperationsRoom room, DateTime date) {
    final orders = activeBookingsOnRoomDay(
      bookings: bookings,
      roomId: room.id,
      day: date,
      occupancies: occupancies,
    );
    return OperationsDay(
      resolveRoomDayStatus(
        palette: palette,
        date: date,
        today: today,
        room: room.data,
        calendarStatus: calendar['${room.id}|${opsDateKey(date)}'] ?? '',
        booking: preferredRoomDayBooking(orders)?.data,
      ),
      orders,
    );
  }

  bool get isToday => DateUtils.isSameDay(date, today);
  List<DailyCareReportCenterItem> get careItems =>
      report?.items
          .where((item) => DateUtils.isSameDay(item.recordDate, date))
          .toList() ??
      [];
  List<OperationsTask> get tasks {
    final items = <OperationsTask>[];
    for (final booking in bookings) {
      final data = booking.data;
      final status = data['status'];
      if (!isActiveRoomDayBooking(data)) continue;
      final roomId = (data['roomId'] ?? '').toString();
      final matches = rooms.where((room) => room.id == roomId);
      final roomName = matches.isEmpty
          ? (data['roomName'] ?? '待分房').toString()
          : matches.first.name;
      final daycare = BookingKind.isDaycare(data);
      for (final departure in [false, true]) {
        if (!DateUtils.isSameDay(
          workbenchBookingTaskDate(data, departure: departure),
          date,
        )) {
          continue;
        }
        final state = departure
            ? (const ['checked_out', 'completed'].contains(status)
                  ? OperationsTaskState.completed
                  : status == 'checked_in'
                  ? OperationsTaskState.pending
                  : null)
            : (const ['pending', 'confirmed'].contains(status)
                  ? OperationsTaskState.pending
                  : status == 'checked_in'
                  ? OperationsTaskState.active
                  : OperationsTaskState.completed);
        if (state == null) continue;
        final label = departure
            ? (daycare ? '預計接回' : '預計離店')
            : (daycare ? '預計送達' : '預計抵達');
        final time = daycare
            ? opsClock(data[departure ? 'scheduledEndAt' : 'scheduledStartAt'])
            : '—';
        items.add(
          OperationsTask(
            id: '${booking.id}:${departure ? 'end' : 'start'}',
            group: OperationsTaskGroup.arrivals,
            state: state,
            roomId: roomId,
            roomName: roomName,
            pets: opsPets(data),
            title: label,
            subtitle: departure ? '核對服務與帳務，依訂單流程辦理離店' : '查看訂單與入住準備，確認房間安排',
            action: '查看訂單',
            time: time,
            booking: booking,
            order: departure ? 1 : 0,
          ),
        );
      }
    }
    for (final room in rooms) {
      final facts = day(room, date);
      if (RoomStatusPresentation.countsAsHousekeepingTodo(
        facts.status.presentation,
      )) {
        items.add(
          OperationsTask(
            id: 'room:${room.id}',
            group: OperationsTaskGroup.housekeeping,
            state: facts.status.presentation.value == 'cleaning'
                ? OperationsTaskState.active
                : OperationsTaskState.pending,
            title: facts.status.presentation.label,
            subtitle: room.type,
            roomId: room.id,
            roomName: room.name,
            action: '查看房務',
          ),
        );
      }
    }
    for (final item in careItems) {
      if (item.isHistoryIncomplete) continue;
      items.add(
        OperationsTask(
          id: 'care:${item.id}',
          group: OperationsTaskGroup.care,
          state: item.isCompleted
              ? OperationsTaskState.completed
              : OperationsTaskState.pending,
          title: item.sessionName,
          subtitle: item.isCompleted ? '本場照護回報已完成' : '記錄飲食、排泄、精神與照片',
          action: item.canFill ? '填寫回報' : '查看回報',
          roomId: item.roomId,
          roomName: item.roomName.isEmpty ? item.typeLabel : item.roomName,
          pets: item.petNames.join('、'),
          care: item,
          order: item.sessionIndex,
        ),
      );
    }
    items.sort((a, b) {
      final group = a.group.index.compareTo(b.group.index);
      if (group != 0) return group;
      final time = a.time.compareTo(b.time);
      return time != 0 ? time : a.order.compareTo(b.order);
    });
    return items;
  }
}
