// 檔案名稱：lib/core/services/daycare_status_labels.dart
// 功能說明：安親訂單狀態中文顯示（資料庫原始值不改）

import 'package:cloud_firestore/cloud_firestore.dart';

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
    return status == 'completed' ||
        status == 'cancelled' ||
        status == 'no_show' ||
        isNoShow(data);
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
        return '安親中';
      case 'completed':
        return '已完成';
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
        return status == 'pending' ||
            status == 'pending_confirmation' ||
            status == 'unpaid';
      case 'depositReview':
        return isDepositReview(data);
      case 'confirmed':
        return status == 'confirmed';
      case 'awaitingRoom':
        return isAwaitingRoom(data);
      case 'checked_in':
        return status == 'checked_in';
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
        return '標記未到店';
      case 'daycare_assign_room':
        return '分配房間';
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
