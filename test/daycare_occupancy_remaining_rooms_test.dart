// 檔案名稱：test/daycare_occupancy_remaining_rooms_test.dart
// 功能說明：安親剩餘房間與住宿占用、取消／結算後釋放、單間容量

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';

void main() {
  final DateTime start = DateTime(2026, 9, 12, 10);
  final DateTime end = DateTime(2026, 9, 12, 18);
  const List<Map<String, dynamic>> rooms = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'r1',
      'roomTypeId': 'vip',
      'capacity': 1,
      'status': 'active',
    },
    <String, dynamic>{
      'id': 'r2',
      'roomTypeId': 'vip',
      'capacity': 1,
      'status': 'active',
    },
  ];

  test('同時段住宿占用會扣剩餘房間', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms,
      bookings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'stay1',
          'status': 'checked_in',
          'bookingKind': 'stay',
          'roomId': 'r1',
          'startDate': DateTime(2026, 9, 11),
          'endDate': DateTime(2026, 9, 13),
        },
      ],
      roomTypeId: 'vip',
      startAt: start,
      endAt: end,
      petCount: 1,
      roomTypeCapacity: 1,
    );
    expect(remaining, 1);
  });

  test('取消與過期訂單不佔用', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms,
      bookings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'c1',
          'status': 'cancelled',
          'bookingKind': 'daycare',
          'roomId': 'r1',
          'scheduledStartAt': start,
          'scheduledEndAt': end,
        },
        <String, dynamic>{
          'id': 'e1',
          'status': 'pending',
          'bookingKind': 'daycare',
          'roomId': 'r2',
          'depositExpired': true,
          'scheduledStartAt': start,
          'scheduledEndAt': end,
        },
      ],
      roomTypeId: 'vip',
      startAt: start,
      endAt: end,
      petCount: 1,
      roomTypeCapacity: 1,
    );
    expect(remaining, 2);
  });

  test('安親結算後不繼續佔房', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms,
      bookings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'd1',
          'status': 'checked_in',
          'bookingKind': 'daycare',
          'roomId': 'r1',
          'settlementConfirmed': true,
          'scheduledStartAt': start,
          'scheduledEndAt': end,
        },
      ],
      roomTypeId: 'vip',
      startAt: start,
      endAt: end,
      petCount: 1,
      roomTypeCapacity: 1,
    );
    expect(remaining, 2);
  });

  test('寵物數超過單間容量時剩餘為 0', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms,
      bookings: const <Map<String, dynamic>>[],
      roomTypeId: 'vip',
      startAt: start,
      endAt: end,
      petCount: 3,
      roomTypeCapacity: 1,
    );
    expect(remaining, 0);
  });
}
