// 檔案名稱：lib/core/presentation/room_status_presentation.dart
// 功能說明：房務狀態的中文標籤、顏色與圖示，全站共用。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';

class RoomStatusPresentation {
  const RoomStatusPresentation({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;

  static const Color availableColor = Color(0xFF2E7D32);
  static const Color stayColor = Color(0xFFE64A19);
  static const Color daycareColor = Color(0xFF5E35B1);
  static const Color checkedInColor = Color(0xFF1565C0);
  static const Color completedColor = Color(0xFF7E57C2);
  static const Color cleaningColor = Color(0xFFEF6C00);
  static const Color closedColor = Color(0xFF6D4C41);
  static const Color maintenanceColor = Color(0xFF424242);

  static RoomStatusPresentation of({
    required String roomStatus,
    Map<String, dynamic>? booking,
  }) {
    final String status = roomStatus.trim().toLowerCase();
    if (status == 'cleaning') {
      return _item(
        'cleaning',
        '清潔中',
        cleaningColor,
        Icons.cleaning_services_outlined,
      );
    }
    if (status == 'closed') {
      return _item('closed', '今日關閉', closedColor, Icons.event_busy);
    }
    if (status == 'blocked' ||
        status == 'maintenance' ||
        status == 'unavailable') {
      return _item(
        'maintenance',
        '維修中',
        maintenanceColor,
        Icons.build_outlined,
      );
    }
    if (booking == null || booking.isEmpty) {
      return _item(
        'available',
        '空房',
        availableColor,
        Icons.meeting_room_outlined,
      );
    }
    final String bookingStatus = (booking['status'] ?? '').toString();
    if (bookingStatus == 'completed') {
      return _item(
        'completed',
        '退房／完成',
        completedColor,
        Icons.check_circle_outline,
      );
    }
    if (bookingStatus == 'checked_in') {
      return _item('checked_in', '入住', checkedInColor, Icons.login);
    }
    if (BookingKind.isDaycare(booking)) {
      return _item('daycare', '安親', daycareColor, Icons.pets_outlined);
    }
    if (bookingStatus == 'pending' || bookingStatus == 'confirmed') {
      return _item('occupied', '住宿', stayColor, Icons.hotel_outlined);
    }
    return _item('occupied', '住宿', stayColor, Icons.hotel_outlined);
  }

  static RoomStatusPresentation calendarDot(String calendarStatus) {
    switch (calendarStatus) {
      case 'booked_daycare':
      case 'daycare':
        return _item('daycare', '安親', daycareColor, Icons.pets_outlined);
      case 'booked':
      case 'occupied_stay':
        return _item('occupied', '住宿', stayColor, Icons.hotel_outlined);
      case 'occupied':
      case 'checked_in':
        return _item('checked_in', '入住', checkedInColor, Icons.login);
      case 'occupied_daycare':
        return _item('daycare', '安親', daycareColor, Icons.pets_outlined);
      case 'completed':
        return _item(
          'completed',
          '退房／完成',
          completedColor,
          Icons.check_circle_outline,
        );
      case 'cleaning':
        return _item(
          'cleaning',
          '清潔中',
          cleaningColor,
          Icons.cleaning_services_outlined,
        );
      case 'closed':
        return _item('closed', '今日關閉', closedColor, Icons.event_busy);
      case 'blocked':
      case 'maintenance':
      case 'unavailable':
        return _item(
          'maintenance',
          '維修中',
          maintenanceColor,
          Icons.build_outlined,
        );
      default:
        return _item(
          'available',
          '空房',
          availableColor,
          Icons.meeting_room_outlined,
        );
    }
  }

  static List<RoomStatusPresentation> legendItems() {
    return <RoomStatusPresentation>[
      _item('available', '空房', availableColor, Icons.meeting_room_outlined),
      _item('occupied', '住宿', stayColor, Icons.hotel_outlined),
      _item('daycare', '安親', daycareColor, Icons.pets_outlined),
      _item('checked_in', '入住', checkedInColor, Icons.login),
      _item('completed', '退房／完成', completedColor, Icons.check_circle_outline),
      _item('cleaning', '清潔中', cleaningColor, Icons.cleaning_services_outlined),
      _item('closed', '今日關閉', closedColor, Icons.event_busy),
      _item('maintenance', '維修中', maintenanceColor, Icons.build_outlined),
    ];
  }

  static RoomStatusPresentation _item(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return RoomStatusPresentation(
      value: value,
      label: label,
      color: color,
      background: color.withValues(alpha: 0.12),
      border: color.withValues(alpha: 0.35),
      icon: icon,
    );
  }
}
