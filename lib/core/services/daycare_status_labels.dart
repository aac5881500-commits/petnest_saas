// 檔案名稱：lib/core/services/daycare_status_labels.dart
// 功能說明：安親訂單狀態中文顯示（資料庫原始值不改）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';

class DaycareStatusLabels {
  DaycareStatusLabels._();

  static bool isNoShow(Map<String, dynamic> data) {
    if (data['noShow'] == true) {
      return true;
    }
    final String status = (data['status'] ?? '').toString();
    if (status == 'no_show') {
      return true;
    }
    return (data['cancelReason'] ?? '').toString() == 'no_show';
  }

  static bool isHistory(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString();
    if (status == 'cancelled' || status == 'no_show' || isNoShow(data)) {
      return true;
    }
    if (status == 'completed') {
      if (BookingSettlementMath.isDaycare(data) &&
          BookingSettlementMath.isDaycareAwaitingClear(data)) {
        return false;
      }
      return true;
    }
    return false;
  }

  static bool isAwaitingRoom(Map<String, dynamic> data) {
    if (isHistory(data)) {
      return false;
    }
    final String status = (data['status'] ?? '').toString();
    if (status != 'confirmed' && status != 'checked_in') {
      return false;
    }
    final String assign = (data['assignStatus'] ?? '').toString();
    if (assign == 'assigned') {
      return false;
    }
    if (assign == 'unassigned') {
      return true;
    }
    return (data['roomId'] ?? '').toString().trim().isEmpty;
  }

  static bool isDepositReview(Map<String, dynamic> data) {
    if (isHistory(data)) {
      return false;
    }
    return (data['depositStatus'] ?? '').toString() == 'pending_review';
  }

  static String assignLabel(Map<String, dynamic> data) {
    if (isAwaitingRoom(data)) {
      return '待分房';
    }
    final String assign = (data['assignStatus'] ?? '').toString();
    if (assign == 'assigned') {
      return '已分房';
    }
    return '尚未分房';
  }

  static String primary(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString();
    switch (status) {
      case 'pending':
      case 'pending_confirmation':
      case 'unpaid':
        return '待確認';
      case 'confirmed':
        return isAwaitingRoom(data) ? '待分房' : '已確認';
      case 'assigned':
        return '已分房';
      case 'checked_in':
        return _settledPrimary(data, '安親中');
      case 'checked_out':
        return _settledPrimary(data, '已退房／待結清');
      case 'completed':
        return _settledPrimary(data, '已完成');
      case 'cancelled':
      case 'no_show':
        return '已取消';
      default:
        if (status.isEmpty) {
          return '待確認';
        }
        return assignLabel(data);
    }
  }

  static String _settledPrimary(Map<String, dynamic> data, String fallback) {
    if (!BookingSettlementMath.isSettlementConfirmed(data)) {
      return fallback;
    }
    if (BookingSettlementMath.isOrderComplete(data)) {
      return '已完成';
    }
    if (BookingSettlementMath.remainingDue(data: data) > 0) {
      return '待補款';
    }
    if (BookingSettlementMath.refundDue(data: data) > 0) {
      return '待退款';
    }
    return fallback;
  }

  static bool matchesFilter(Map<String, dynamic> data, String filter) {
    if (filter == 'all' || filter.isEmpty) {
      return true;
    }
    final String status = (data['status'] ?? '').toString();
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart.add(const Duration(days: 1));
    DateTime? asDate(dynamic raw) {
      if (raw is Timestamp) {
        return raw.toDate();
      }
      if (raw is DateTime) {
        return raw;
      }
      return null;
    }

    final DateTime? start =
        asDate(data['scheduledStartAt']) ?? asDate(data['startDate']);
    final DateTime? end =
        asDate(data['scheduledEndAt']) ?? asDate(data['endDate']);
    switch (filter) {
      case 'pending':
        return !isHistory(data) &&
            (status == 'pending' ||
                status == 'pending_confirmation' ||
                status == 'unpaid');
      case 'depositReview':
        return isDepositReview(data);
      case 'confirmed':
        return !isHistory(data) && status == 'confirmed';
      case 'awaitingRoom':
        return isAwaitingRoom(data);
      case 'checked_in':
        return !isHistory(data) &&
            (status == 'checked_in' ||
                status == 'checked_out' ||
                BookingSettlementMath.isAwaitingClear(data));
      case 'todayDropOff':
        return !isHistory(data) &&
            start != null &&
            !start.isBefore(todayStart) &&
            start.isBefore(todayEnd);
      case 'todayPickUp':
        return !isHistory(data) &&
            end != null &&
            !end.isBefore(todayStart) &&
            end.isBefore(todayEnd);
      case 'history':
        return isHistory(data);
      case 'completed':
      case 'cancelled':
      case 'no_show':
        return isHistory(data);
      default:
        return status == filter;
    }
  }

  static Map<String, int> counts(List<Map<String, dynamic>> docs) {
    final Map<String, int> result = <String, int>{
      'all': docs.length,
      'pending': 0,
      'depositReview': 0,
      'confirmed': 0,
      'awaitingRoom': 0,
      'checked_in': 0,
      'todayDropOff': 0,
      'todayPickUp': 0,
      'history': 0,
    };
    for (final Map<String, dynamic> data in docs) {
      if (matchesFilter(data, 'pending')) {
        result['pending'] = (result['pending'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'depositReview')) {
        result['depositReview'] = (result['depositReview'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'confirmed')) {
        result['confirmed'] = (result['confirmed'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'awaitingRoom')) {
        result['awaitingRoom'] = (result['awaitingRoom'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'checked_in')) {
        result['checked_in'] = (result['checked_in'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'todayDropOff')) {
        result['todayDropOff'] = (result['todayDropOff'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'todayPickUp')) {
        result['todayPickUp'] = (result['todayPickUp'] ?? 0) + 1;
      }
      if (matchesFilter(data, 'history')) {
        result['history'] = (result['history'] ?? 0) + 1;
      }
    }
    return result;
  }

  static String actionName(String raw) {
    switch (raw) {
      case 'deposit_confirmed':
        return '確認訂金';
      case 'daycare_created':
        return '建立安親訂單';
      case 'daycare_confirm':
        return '確認訂單';
      case 'daycare_start':
        return '開始安親';
      case 'daycare_settle':
        return '結算安親';
      case 'daycare_cancel':
        return '取消訂單';
      case 'daycare_noShow':
        return '舊版取消紀錄';
      case 'daycare_assign_room':
      case 'stay_assign_room':
      case 'room_assigned':
        return '分配房間';
      case 'daycare_change_room':
      case 'stay_change_room':
      case 'room_changed':
        return '更換房間';
      case 'settlement_applyAdjust':
        return '重新調整結算';
      case 'settlement_checkOutStay':
        return '住宿結算';
      case 'settlement_confirmCollect':
        return '確認收款';
      case 'settlement_confirmRefund':
        return '確認退款';
      case 'payment_choice_changed':
        return '變更付款方式';
      case 'daycare_extend':
        return '延長安親時間';
      case 'daycare_convert':
      case 'daycare_convert_to_accommodation':
        return '轉為住宿';
      default:
        return '';
    }
  }
}
