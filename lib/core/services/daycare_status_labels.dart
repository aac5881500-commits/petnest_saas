// 檔案名稱：lib/core/services/daycare_status_labels.dart
// 功能說明：安親訂單狀態中文顯示（資料庫原始值不改）

class DaycareStatusLabels {
  DaycareStatusLabels._();

  static const List<Map<String, String>> listFilters = <Map<String, String>>[
    <String, String>{'id': 'all', 'label': '全部'},
    <String, String>{'id': 'pending', 'label': '待確認'},
    <String, String>{'id': 'confirmed', 'label': '已確認'},
    <String, String>{'id': 'assigned', 'label': '已分房'},
    <String, String>{'id': 'unassigned', 'label': '尚未分房'},
    <String, String>{'id': 'checked_in', 'label': '安親中'},
    <String, String>{'id': 'completed', 'label': '已完成'},
    <String, String>{'id': 'cancelled', 'label': '已取消'},
    <String, String>{'id': 'no_show', 'label': '未到店'},
  ];

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

  static String assignLabel(Map<String, dynamic> data) {
    final String assign = (data['assignStatus'] ?? '').toString();
    if (assign == 'assigned') {
      return '已分房';
    }
    return '尚未分房';
  }

  static String primary(Map<String, dynamic> data) {
    if (isNoShow(data)) {
      return '未到店';
    }
    final String status = (data['status'] ?? '').toString();
    switch (status) {
      case 'pending':
      case 'pending_confirmation':
      case 'unpaid':
        return '待確認';
      case 'confirmed':
        return '已確認';
      case 'assigned':
        return '已分房';
      case 'checked_in':
        return '安親中';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'no_show':
        return '未到店';
      case 'unassigned':
        return '尚未分房';
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
    final String assign = (data['assignStatus'] ?? 'unassigned').toString();
    switch (filter) {
      case 'pending':
        return status == 'pending' ||
            status == 'pending_confirmation' ||
            status == 'unpaid';
      case 'confirmed':
        return status == 'confirmed';
      case 'assigned':
        return assign == 'assigned';
      case 'unassigned':
        return assign != 'assigned';
      case 'checked_in':
        return status == 'checked_in';
      case 'completed':
        return status == 'completed';
      case 'cancelled':
        return status == 'cancelled' && !isNoShow(data);
      case 'no_show':
        return isNoShow(data);
      default:
        return status == filter;
    }
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
