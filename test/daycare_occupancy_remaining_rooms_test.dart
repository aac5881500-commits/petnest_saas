// 檔案名稱：test/daycare_occupancy_remaining_rooms_test.dart
// 功能說明：安親剩餘房間與住宿占用、取消／結算後釋放、單間容量

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';

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

  test('沒有實體房間剩餘 0 並給出原因', () {
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: const <Map<String, dynamic>>[],
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'vip',
          startAt: start,
          endAt: end,
        );
    expect(result.remaining, 0);
    expect(result.zeroReason, DaycareOccupancyService.noPhysicalRooms);
  });

  test('未分房有效安親只靠 bookings 扣除，不需 holds', () {
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'u1',
              'status': 'pending',
              'bookingKind': 'daycare',
              'requestedRoomTypeId': 'vip',
              'roomId': '',
              'scheduledStartAt': start,
              'scheduledEndAt': end,
            },
            <String, dynamic>{
              'id': 'a1',
              'status': 'confirmed',
              'bookingKind': 'daycare',
              'requestedRoomTypeId': 'vip',
              'roomId': 'r1',
              'scheduledStartAt': start,
              'scheduledEndAt': end,
            },
          ],
          occupancies: <Map<String, dynamic>>[
            <String, dynamic>{
              'bookingId': 'a1',
              'roomId': 'r1',
              'status': 'active',
              'startAt': start,
              'endAt': end,
            },
          ],
          roomTypeId: 'vip',
          startAt: start,
          endAt: end,
        );
    expect(result.remaining, 0);
    expect(result.reservedCount, 1);
  });

  test('時段不重疊可共用同一間', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms.sublist(0, 1),
      bookings: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'd1',
          'status': 'confirmed',
          'bookingKind': 'daycare',
          'roomId': 'r1',
          'scheduledStartAt': start,
          'scheduledEndAt': end,
        },
      ],
      roomTypeId: 'vip',
      startAt: DateTime(2026, 9, 12, 19),
      endAt: DateTime(2026, 9, 12, 21),
    );
    expect(remaining, 1);
  });

  test('住宿日曆占用會扣實體房', () {
    final int remaining = DaycareOccupancyService.remainingRoomsFromData(
      rooms: rooms.sublist(0, 1),
      bookings: const <Map<String, dynamic>>[],
      calendarEntries: <Map<String, dynamic>>[
        <String, dynamic>{
          'roomId': 'r1',
          'date': '2026-09-12',
          'status': 'booked',
        },
      ],
      roomTypeId: 'vip',
      startAt: start,
      endAt: end,
    );
    expect(remaining, 0);
  });

  List<Map<String, dynamic>> _tenRooms({
    bool enabled = true,
    String status = 'available',
  }) {
    return List<Map<String, dynamic>>.generate(10, (int i) {
      return <String, dynamic>{
        'id': 'r$i',
        'roomTypeId': 'std',
        'capacity': 1,
        'enabled': enabled,
        'status': status,
      };
    });
  }

  int _vacantHousekeepingCount(List<Map<String, dynamic>> rooms) {
    return rooms.where((Map<String, dynamic> room) {
      return DaycareOccupancyService.housekeepingLabel(room: room) ==
          DaycareOccupancyService.vacantLabel;
    }).length;
  }

  test('房間 enabled:false 房務不算空房、安親不可賣', () {
    final List<Map<String, dynamic>> rooms = _tenRooms(enabled: false);
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
          petCount: 1,
          roomTypeCapacity: 1,
        );
    expect(_vacantHousekeepingCount(rooms), 0);
    expect(
      rooms.every(
        (Map<String, dynamic> room) =>
            DaycareOccupancyService.housekeepingLabel(room: room) ==
            DaycareOccupancyService.disabledLabel,
      ),
      isTrue,
    );
    expect(result.remaining, 0);
    expect(result.disabledCount, 10);
    expect(result.zeroReason, '此房型有 10 間實體房，但 10 間目前未啟用');
  });

  test('舊 rooms.status=cleaning 不當永久鎖房，今天 calendar cleaning 才不可賣', () {
    final List<Map<String, dynamic>> rooms = _tenRooms(status: 'cleaning');
    final DaycareRoomRemaining dirty =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
          petCount: 1,
          roomTypeCapacity: 1,
        );
    expect(dirty.remaining, 10);
    expect(
      DaycareOccupancyService.housekeepingLabel(room: rooms.first),
      DaycareOccupancyService.vacantLabel,
    );
    final DaycareRoomRemaining today =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          calendarEntries: _tenRooms()
              .map(
                (Map<String, dynamic> room) => <String, dynamic>{
                  'roomId': room['id'],
                  'date': '2026-09-12',
                  'status': 'cleaning',
                },
              )
              .toList(),
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
          petCount: 1,
          roomTypeCapacity: 1,
        );
    expect(today.remaining, 0);
    expect(today.cleaningCount, 10);
    expect(
      DaycareOccupancyService.housekeepingLabel(
        room: rooms.first,
        calendarStatus: 'cleaning',
      ),
      DaycareOccupancyService.cleaningLabel,
    );
  });

  test('明天可使用今天已寫入 cleaning 的房間', () {
    final List<Map<String, dynamic>> rooms = _tenRooms();
    final DaycareRoomRemaining tomorrow =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          calendarEntries: _tenRooms()
              .map(
                (Map<String, dynamic> room) => <String, dynamic>{
                  'roomId': room['id'],
                  'date': '2026-09-12',
                  'status': 'cleaning',
                },
              )
              .toList(),
          roomTypeId: 'std',
          startAt: DateTime(2026, 9, 13, 10),
          endAt: DateTime(2026, 9, 13, 18),
          petCount: 1,
          roomTypeCapacity: 1,
          dateKey: '2026-09-13',
        );
    expect(tomorrow.remaining, 10);
  });

  test('enabled:false、maintenance、blocked、unavailable 全部不可賣', () {
    for (final Map<String, dynamic> room in <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'a',
        'roomTypeId': 'std',
        'enabled': false,
        'permanentStatus': 'available',
        'capacity': 1,
      },
      <String, dynamic>{
        'id': 'b',
        'roomTypeId': 'std',
        'enabled': true,
        'permanentStatus': 'maintenance',
        'capacity': 1,
      },
      <String, dynamic>{
        'id': 'c',
        'roomTypeId': 'std',
        'enabled': true,
        'permanentStatus': 'blocked',
        'capacity': 1,
      },
      <String, dynamic>{
        'id': 'd',
        'roomTypeId': 'std',
        'enabled': true,
        'permanentStatus': 'unavailable',
        'capacity': 1,
      },
    ]) {
      expect(DaycareOccupancyService.isRoomDocumentUnsellable(room), isTrue);
      expect(
        DaycareOccupancyService.remainingRoomsFromData(
          rooms: <Map<String, dynamic>>[room],
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
        ),
        0,
      );
    }
  });

  test('住宿未分房與安親未分房保留互相扣除同一房型容量', () {
    final List<Map<String, dynamic>> rooms = _tenRooms().sublist(0, 1);
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'stay-u',
              'status': 'pending',
              'bookingKind': 'accommodation',
              'roomTypeId': 'std',
              'roomId': '',
              'startDate': DateTime(2026, 9, 12),
              'endDate': DateTime(2026, 9, 13),
            },
            <String, dynamic>{
              'id': 'day-u',
              'status': 'pending',
              'bookingKind': 'daycare',
              'requestedRoomTypeId': 'std',
              'roomId': '',
              'scheduledStartAt': start,
              'scheduledEndAt': end,
            },
          ],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
        );
    expect(result.remaining, 0);
    expect(result.reservedCount, 2);
  });

  test('同時兩張訂單時第二張看到已保留後剩餘為 0', () {
    final List<Map<String, dynamic>> rooms = _tenRooms().sublist(0, 1);
    final DaycareRoomRemaining first =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          holdEntries: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
        );
    expect(first.remaining, 1);
    final DaycareRoomRemaining second =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          holdEntries: <Map<String, dynamic>>[
            <String, dynamic>{
              'bookingId': 'winner',
              'startAt': start.toIso8601String(),
              'endAt': end.toIso8601String(),
            },
          ],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
        );
    expect(second.remaining, 0);
  });

  test('10 間啟用且狀態正常、日曆無占用時剩餘 10 間且可選', () {
    final List<Map<String, dynamic>> rooms = _tenRooms();
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: rooms,
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
          petCount: 1,
          roomTypeCapacity: 1,
        );
    expect(result.remaining, 10);
    expect(result.usableCount, 10);
    expect(result.zeroReason, '');
    expect(_vacantHousekeepingCount(rooms), 10);
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'std',
        enabled: true,
      ),
      name: '舒適標準房',
      petCount: 1,
      remainingRooms: result.remaining,
      zeroReason: result.zeroReason,
      roomCapacity: 1,
    );
    expect(option.selectable, isTrue);
  });

  test('房務空房數與安親剩餘房間同一組資料一致', () {
    final List<Map<String, dynamic>> mixed = <Map<String, dynamic>>[
      ..._tenRooms().take(4),
      ..._tenRooms(enabled: false).take(3).map((Map<String, dynamic> room) {
        return <String, dynamic>{...room, 'id': 'd${room['id']}'};
      }),
      ..._tenRooms().take(3).map((Map<String, dynamic> room) {
        return <String, dynamic>{
          ...room,
          'id': 'c${room['id']}',
          'permanentStatus': 'maintenance',
        };
      }),
    ];
    final DaycareRoomRemaining result =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: mixed,
          bookings: const <Map<String, dynamic>>[],
          roomTypeId: 'std',
          startAt: start,
          endAt: end,
          petCount: 1,
          roomTypeCapacity: 1,
        );
    expect(_vacantHousekeepingCount(mixed), result.remaining);
    expect(result.remaining, 4);
    expect(result.disabledCount, 3);
    expect(result.maintenanceCount, 3);
    expect(
      result.zeroReason,
      '',
    );
  });
}
