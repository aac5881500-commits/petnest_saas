// 檔案名稱：lib/features/shop/widgets/booking/front_calendar_payload.dart
// 功能說明：前台預約月曆資料：關閉日、滿房日、價格與剩餘房數

class FrontCalendarPayload {
  const FrontCalendarPayload({
    required this.blockedDateKeys,
    required this.blockedDateReasons,
    required this.unbookableDateKeys,
    required this.priceMap,
    required this.remainingRoomsMap,
    this.specialOpenDateKeys = const <String>{},
  });

  final Set<String> blockedDateKeys;
  final Map<String, String> blockedDateReasons;
  final Set<String> unbookableDateKeys;
  final Map<String, int> priceMap;
  final Map<String, int> remainingRoomsMap;
  final Set<String> specialOpenDateKeys;
}
