// 檔案名稱：lib/features/auth/widgets/my_shop_open_status_helper.dart
// 功能說明：依照 isOpen、openTime、closeTime 判斷目前是否營業中
// 🕒 我的店家營業狀態判斷工具

bool isShopOpenNow({
  required bool isOpen,
  required String openTime,
  required String closeTime,
}) {
  if (!isOpen) return false;

  if (openTime.isEmpty || closeTime.isEmpty) {
    return isOpen;
  }

  final now = DateTime.now();

  final open = _parseTimeToday(openTime);
  final close = _parseTimeToday(closeTime);

  if (open == null || close == null) {
    return isOpen;
  }

  /// 一般情況：10:00 - 20:00
  if (close.isAfter(open)) {
    return now.isAfter(open) && now.isBefore(close);
  }

  /// 跨日情況：20:00 - 02:00
  return now.isAfter(open) || now.isBefore(close);
}

DateTime? _parseTimeToday(String value) {
  final parts = value.split(':');

  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null || minute == null) return null;

  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day, hour, minute);
}
