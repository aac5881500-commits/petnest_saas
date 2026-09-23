// 檔案名稱：lib/core/presentation/room_status_presentation.dart
// 功能說明：房務狀態的中文標籤、顏色與圖示，全站共用。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';

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
  static const Color disabledColor = Color(0xFF607D8B);

  static RoomStatusPresentation available() {
    return _item(
      'available',
      '空房',
      availableColor,
      Icons.meeting_room_outlined,
    );
  }

  static RoomStatusPresentation stayBooked() {
    return _item('occupied', '住宿・已訂', stayColor, Icons.hotel_outlined);
  }

  static RoomStatusPresentation daycareBooked() {
    return _item('daycare', '安親・已訂', daycareColor, Icons.pets_outlined);
  }

  static RoomStatusPresentation stayCheckedIn() {
    return _item('checked_in', '入住中', checkedInColor, Icons.login);
  }

  static RoomStatusPresentation daycareCheckedIn() {
    return _item(
      'daycare_checked_in',
      '安親中',
      daycareColor,
      Icons.pets_outlined,
    );
  }

  static RoomStatusPresentation completed() {
    return _item(
      'completed',
      '退房／完成',
      completedColor,
      Icons.check_circle_outline,
    );
  }

  static RoomStatusPresentation cleaning() {
    return _item(
      'cleaning',
      '清潔中',
      cleaningColor,
      Icons.cleaning_services_outlined,
    );
  }

  static RoomStatusPresentation closed() {
    return _item('closed', '今日關閉', closedColor, Icons.event_busy);
  }

  static RoomStatusPresentation maintenance() {
    return _item('maintenance', '維修中', maintenanceColor, Icons.build_outlined);
  }

  static RoomStatusPresentation disabled() {
    return _item(
      'disabled',
      '未啟用',
      disabledColor,
      Icons.power_settings_new_outlined,
    );
  }

  static RoomStatusPresentation of({
    required String roomStatus,
    Map<String, dynamic>? booking,
  }) {
    final String status = roomStatus.trim().toLowerCase();
    if (status == 'cleaning') {
      return cleaning();
    }
    if (status == 'closed') {
      return closed();
    }
    if (status == 'blocked' ||
        status == 'maintenance' ||
        status == 'unavailable') {
      return maintenance();
    }
    if (status == 'disabled' || status == 'inactive') {
      return disabled();
    }
    if (booking == null || booking.isEmpty) {
      return available();
    }
    final String bookingStatus = (booking['status'] ?? '').toString();
    if (bookingStatus == 'completed') {
      return completed();
    }
    final bool daycare = BookingKind.isDaycare(booking);
    if (bookingStatus == 'checked_in') {
      return daycare ? daycareCheckedIn() : stayCheckedIn();
    }
    if (daycare) {
      return daycareBooked();
    }
    return stayBooked();
  }

  /// 房務首頁：DaycareOccupancyService.housekeepingLabel 的中文狀態。
  static RoomStatusPresentation fromHousekeepingLabel(
    String label, {
    Map<String, dynamic>? booking,
  }) {
    switch (label.trim()) {
      case DaycareOccupancyService.disabledLabel:
        return disabled();
      case DaycareOccupancyService.cleaningLabel:
        return cleaning();
      case DaycareOccupancyService.maintenanceLabel:
        return maintenance();
      case DaycareOccupancyService.closedLabel:
        return closed();
      case DaycareOccupancyService.vacantLabel:
        return available();
      case '已完成':
        return completed();
      case '已訂':
        return BookingKind.isDaycare(booking) ? daycareBooked() : stayBooked();
      case '入住中':
        return BookingKind.isDaycare(booking)
            ? daycareCheckedIn()
            : stayCheckedIn();
      default:
        return available();
    }
  }

  static bool isInUseLabel(String label) {
    return label.trim() == '已訂' || label.trim() == '入住中';
  }

  static RoomStatusPresentation calendarDot(String calendarStatus) {
    switch (calendarStatus) {
      case 'booked_daycare':
      case 'daycare':
        return daycareBooked();
      case 'booked':
      case 'occupied_stay':
        return stayBooked();
      case 'occupied':
      case 'checked_in':
        return stayCheckedIn();
      case 'occupied_daycare':
        return daycareCheckedIn();
      case 'completed':
        return completed();
      case 'cleaning':
        return cleaning();
      case 'closed':
        return closed();
      case 'blocked':
      case 'maintenance':
      case 'unavailable':
        return maintenance();
      case 'disabled':
      case 'inactive':
        return disabled();
      default:
        return available();
    }
  }

  static List<RoomStatusPresentation> legendItems() {
    return <RoomStatusPresentation>[
      available(),
      _item('occupied', '住宿', stayColor, Icons.hotel_outlined),
      _item('daycare', '安親', daycareColor, Icons.pets_outlined),
      stayCheckedIn(),
      completed(),
      cleaning(),
      closed(),
      maintenance(),
      disabled(),
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
