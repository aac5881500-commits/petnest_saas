// 檔案名稱：test/booking_current_room_test.dart
// 功能說明：目前房型／實體房間只讀訂單最新欄位

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';

void main() {
  test('已分房顯示最新房型與房號', () {
    final BookingCurrentRoom room = BookingCurrentRoom.fromBooking(
      <String, dynamic>{
        'roomTypeName': '舒適標準房',
        'roomId': 'rid-a5',
        'roomName': 'A5',
      },
    );
    expect(room.typeDisplay(), '舒適標準房');
    expect(
      room.physicalDisplay(BookingCurrentRoomAudience.staff),
      'A5',
    );
    expect(
      room.physicalDisplay(BookingCurrentRoomAudience.customer),
      'A5',
    );
  });

  test('換房後只顯示新房號，不讀操作紀錄', () {
    final BookingCurrentRoom room = BookingCurrentRoom.fromBooking(
      <String, dynamic>{
        'roomTypeName': '舒適標準房',
        'roomId': 'rid-a3',
        'roomName': 'A3',
        'lastAction': 'A5',
      },
    );
    expect(room.physicalRoomLabel, 'A3');
    expect(room.physicalRoomLabel.contains('A5'), isFalse);
  });

  test('尚未分房：店員與客戶提示不同', () {
    final BookingCurrentRoom room = BookingCurrentRoom.fromBooking(
      <String, dynamic>{
        'roomTypeName': '舒適標準房',
        'requestedRoomTypeName': '舒適標準房',
      },
    );
    expect(room.hasPhysicalRoom, isFalse);
    expect(
      room.physicalDisplay(BookingCurrentRoomAudience.staff),
      '尚未分配實體房間',
    );
    expect(
      room.physicalDisplay(BookingCurrentRoomAudience.customer),
      '房間將由店家安排',
    );
  });

  test('舊單只有 roomId 時不把 document id 當房號', () {
    final BookingCurrentRoom room = BookingCurrentRoom.fromBooking(
      <String, dynamic>{'roomId': 'T7D4M2h7qbCAWoz37pWD', 'shopId': 'shop1'},
    );
    expect(room.hasPhysicalRoom, isTrue);
    expect(room.physicalRoomLabel, isEmpty);
    expect(room.needsRoomNameLookup, isTrue);
    expect(room.physicalDisplay(BookingCurrentRoomAudience.staff).contains('T7D4'), isFalse);
  });
}
