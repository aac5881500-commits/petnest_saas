// 檔案名稱：lib/core/models/shop_task_item.dart
// 功能說明：後台共用待辦中心
// 依現有業務資料即時計算，不是通知歷史。
// 已接入每日照護、訂單與攝影機分享申請。

import 'camera_access_policy.dart';
import 'camera_brand.dart';

enum ShopTaskType {
  dailyCare,
  booking,
  cameraShare,
  payment,
  storeOrder,
  pickup,
  member,
  system,
}

class ShopTaskItem {
  const ShopTaskItem({
    required this.id,
    required this.type,
    required this.shopId,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.targetType,
    required this.targetId,
    this.createdAt,
    this.priority = 10,
    this.iconKey = '',
    this.metadata = const <String, dynamic>{},
    this.canOpen = true,
  });

  final String id;
  final ShopTaskType type;
  final String shopId;
  final String title;
  final String subtitle;
  final String statusLabel;
  final DateTime? createdAt;
  final int priority;
  final String iconKey;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> metadata;
  final bool canOpen;

  String get groupLabel {
    switch (type) {
      case ShopTaskType.dailyCare:
        return '每日照護';
      case ShopTaskType.booking:
        return '訂單';
      case ShopTaskType.cameraShare:
        return '攝影機分享';
      case ShopTaskType.payment:
        return '付款';
      case ShopTaskType.storeOrder:
        return '商城訂單';
      case ShopTaskType.pickup:
        return '取貨';
      case ShopTaskType.member:
        return '會員';
      case ShopTaskType.system:
        return '系統';
    }
  }
}

class ShopRoomCareProgress {
  const ShopRoomCareProgress({
    required this.roomId,
    required this.bookingId,
    required this.filled,
    required this.total,
  });

  final String roomId;
  final String bookingId;
  final int filled;
  final int total;

  int get pending => total > filled ? total - filled : 0;

  bool get isComplete => total > 0 && pending == 0;
}

class ShopTaskCenterSnapshot {
  const ShopTaskCenterSnapshot({
    this.items = const <ShopTaskItem>[],
    this.roomCareProgress = const <String, ShopRoomCareProgress>{},
    this.checkedInRoomCount = 0,
    this.hasError = false,
    this.errorMessage = '',
    this.bookingEnabled = false,
    this.bookingLoading = false,
    this.bookingErrorCode = '',
    this.bookingErrorSource = '',
    this.careEnabled = false,
    this.careLoading = false,
    this.careErrorCode = '',
    this.careErrorSource = '',
    this.cameraEnabled = false,
    this.cameraLoading = false,
    this.cameraErrorCode = '',
    this.cameraErrorSource = '',
  });

  final List<ShopTaskItem> items;
  final Map<String, ShopRoomCareProgress> roomCareProgress;
  final int checkedInRoomCount;
  final bool hasError;
  final String errorMessage;
  final bool bookingEnabled;
  final bool bookingLoading;
  final String bookingErrorCode;
  final String bookingErrorSource;
  final bool careEnabled;
  final bool careLoading;
  final String careErrorCode;
  final String careErrorSource;
  final bool cameraEnabled;
  final bool cameraLoading;
  final String cameraErrorCode;
  final String cameraErrorSource;

  bool get hasLaneLoading {
    return (bookingEnabled && bookingLoading) ||
        (careEnabled && careLoading) ||
        (cameraEnabled && cameraLoading);
  }

  bool get hasLaneError {
    return bookingErrorCode.isNotEmpty ||
        careErrorCode.isNotEmpty ||
        cameraErrorCode.isNotEmpty;
  }

  /// 已訂閱的分類都讀完、都沒有錯誤，而且沒有待辦，才算全部完成。
  bool get isAllClear {
    final bool anyLane = bookingEnabled || careEnabled || cameraEnabled;
    return anyLane && !hasLaneLoading && !hasLaneError && items.isEmpty;
  }

  int get totalCount => items.length;

  int get dailyCareCount => items
      .where((ShopTaskItem item) => item.type == ShopTaskType.dailyCare)
      .length;

  int get bookingCount => items
      .where((ShopTaskItem item) => item.type == ShopTaskType.booking)
      .length;

  List<ShopTaskItem> ofType(ShopTaskType type) {
    return items.where((ShopTaskItem item) => item.type == type).toList();
  }

  static const ShopTaskCenterSnapshot loading = ShopTaskCenterSnapshot();

  static const ShopTaskCenterSnapshot error = ShopTaskCenterSnapshot(
    hasError: true,
    errorMessage: '目前無法取得待辦事項，請稍後再試。',
  );
}

/// 店主需要立即處理的分享申請。補資料、已邀請與已結束不計入。
bool cameraRequestCountsAsOwnerTask(String status) {
  return status == cameraRequestPending ||
      status == cameraRequestRevocationPending;
}

String cameraOwnerTaskAction(String status) {
  if (status == cameraRequestPending) {
    return '待邀請';
  }
  if (status == cameraRequestRevocationPending) {
    return '待取消分享';
  }
  return '';
}

/// 由申請文件算出待辦。分享帳號只留在有權限的申請詳情，不放進待辦。
List<ShopTaskItem> cameraOwnerTasks({
  required String shopId,
  required List<Map<String, dynamic>> requests,
}) {
  final List<ShopTaskItem> items = <ShopTaskItem>[];
  for (final Map<String, dynamic> request in requests) {
    final String status = (request['status'] ?? '').toString();
    if (!cameraRequestCountsAsOwnerTask(status)) {
      continue;
    }
    final String requestId = (request['requestId'] ?? request['id'] ?? '')
        .toString()
        .trim();
    if (requestId.isEmpty) {
      continue;
    }
    final String roomName = (request['roomName'] ?? '').toString().trim();
    final String customerName = (request['customerName'] ?? '')
        .toString()
        .trim();
    final String provider = (request['provider'] ?? '').toString().trim();
    final String brand = cameraBrandLabel(provider);
    final String action = cameraOwnerTaskAction(status);
    final DateTime? createdAt = readShopTaskDate(request['createdAt']);
    items.add(
      ShopTaskItem(
        id: 'camera_$requestId',
        type: ShopTaskType.cameraShare,
        shopId: shopId,
        title: roomName.isEmpty ? '攝影機分享' : roomName,
        subtitle: <String>[
          if (customerName.isNotEmpty) customerName,
          if (brand.isNotEmpty) brand,
          if (action.isNotEmpty) action,
          if (createdAt != null) formatShopTaskTime(createdAt),
        ].join(' · '),
        statusLabel: action,
        createdAt: createdAt,
        priority: 15,
        iconKey: 'camera',
        targetType: 'cameraAccessRequest',
        targetId: requestId,
        metadata: <String, dynamic>{
          'requestId': requestId,
          'status': status,
          'roomName': roomName,
          'customerName': customerName,
          'provider': provider,
          'action': action,
        },
      ),
    );
  }
  return items;
}

DateTime? readShopTaskDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value == null) {
    return null;
  }
  try {
    final Object? date = (value as dynamic).toDate();
    if (date is DateTime) {
      return date;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String formatShopTaskTime(DateTime value) {
  final String month = value.month.toString();
  final String day = value.day.toString();
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String shopTaskLaneErrorMessage({
  required String laneLabel,
  required String code,
}) {
  switch (code) {
    case 'permission-denied':
      return '$laneLabel沒有讀取權限。';
    case 'failed-precondition':
      return '$laneLabel查詢尚未就緒，可能缺少索引。';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return '$laneLabel網路讀取失敗，請再試一次。';
    default:
      return '$laneLabel讀取失敗（$code）。';
  }
}
