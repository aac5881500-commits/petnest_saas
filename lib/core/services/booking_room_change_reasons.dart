// 檔案名稱：lib/core/services/booking_room_change_reasons.dart
// 功能說明：換房必填原因選項（住宿／安親共用）

class BookingRoomChangeReasons {
  BookingRoomChangeReasons._();

  static const String other = '其他';

  static const List<String> values = <String>[
    '清潔',
    '維修',
    '客戶需求',
    '店家調度',
    other,
  ];
}
