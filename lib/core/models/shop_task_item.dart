// 檔案名稱：lib/core/models/shop_task_item.dart
// 功能說明：後台共用待辦中心 V1
// 依現有業務資料即時計算，不是通知歷史。
// V1 正式接入 dailyCare / booking；其餘 type 僅預留擴充。

enum ShopTaskType {
  dailyCare,
  booking,
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
  });

  final List<ShopTaskItem> items;
  final Map<String, ShopRoomCareProgress> roomCareProgress;
  final int checkedInRoomCount;
  final bool hasError;
  final String errorMessage;

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
