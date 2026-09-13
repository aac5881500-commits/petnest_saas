// 檔案名稱：test/daycare_room_type_option_test.dart
// 功能說明：安親房型選項以 room_types.capacity 為可訂上限

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';

void main() {
  test('房型容量 1 選 2 隻不可選', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'vip',
        enabled: true,
        maxPets: 3,
      ),
      name: 'VIP',
      petCount: 2,
      roomCapacity: 1,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, '此房型最多容納 1 隻寵物');
    expect(option.capacitySummary, '最多 1 隻');
  });

  test('安親 maxPets 不可大於房型實際容量', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'vip',
        enabled: true,
        maxPets: 3,
      ),
      name: 'VIP 尊爵房',
      petCount: 3,
      remainingRooms: 5,
      roomCapacity: 1,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, '此房型最多容納 1 隻寵物');
  });

  test('房型容量 3 選 2 隻可選', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'view',
        enabled: true,
        maxPets: 1,
      ),
      name: '陽光景觀房',
      petCount: 2,
      roomCapacity: 3,
    );
    expect(option.selectable, isTrue);
  });

  test('extraPetPrice 不會當成容量上限', () {
    final DaycareRoomTypeSetting setting = DaycareRoomTypeSetting.fromMap(
      const <String, dynamic>{
        'roomTypeId': 'std',
        'enabled': true,
        'maxPets': 5,
        'extraPetPrice': 100,
      },
    );
    expect(setting.extraPetPrice, 100);
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: setting,
      name: '舒適標準房',
      petCount: 2,
      roomCapacity: 5,
    );
    expect(option.selectable, isTrue);
  });

  test('petCount 等於房型容量可選，超過才不可選', () {
    const DaycareRoomTypeSetting setting = DaycareRoomTypeSetting(
      roomTypeId: 'vip',
      enabled: true,
      maxPets: 99,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: 'VIP尊爵房',
        petCount: 3,
        remainingRooms: 5,
        roomCapacity: 3,
      ).selectable,
      isTrue,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: 'VIP尊爵房',
        petCount: 4,
        remainingRooms: 5,
        roomCapacity: 3,
      ).selectable,
      isFalse,
    );
  });

  test('remainingRooms 5 可選、0 不可選', () {
    const DaycareRoomTypeSetting setting = DaycareRoomTypeSetting(
      roomTypeId: 'std',
      enabled: true,
      maxPets: 3,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: '舒適標準房',
        petCount: 3,
        remainingRooms: 5,
        roomCapacity: 3,
      ).selectable,
      isTrue,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: '舒適標準房',
        petCount: 3,
        remainingRooms: 0,
        roomCapacity: 3,
      ).selectable,
      isFalse,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: '舒適標準房',
        petCount: 3,
        remainingRooms: 0,
        roomCapacity: 3,
      ).blockedReason,
      DaycareOccupancyService.roomTypeSoldOut,
    );
  });

  test('VIP 與舒適兩個房型同時都可選', () {
    const DaycareRoomTypeSetting vip = DaycareRoomTypeSetting(
      roomTypeId: 'vip_id',
      enabled: true,
      maxPets: 3,
    );
    const DaycareRoomTypeSetting std = DaycareRoomTypeSetting(
      roomTypeId: 'std_id',
      enabled: true,
      maxPets: 3,
    );
    final DaycareRoomTypeOption vipOption = DaycareRoomTypeCatalog.evaluate(
      setting: vip,
      name: 'VIP尊爵房',
      petCount: 3,
      remainingRooms: 5,
      roomCapacity: 3,
    );
    final DaycareRoomTypeOption stdOption = DaycareRoomTypeCatalog.evaluate(
      setting: std,
      name: '舒適標準房',
      petCount: 3,
      remainingRooms: 9,
      roomCapacity: 3,
    );
    expect(vipOption.selectable, isTrue);
    expect(stdOption.selectable, isTrue);
  });

  test('roomTypeId 不一致顯示明確錯誤，不可沉默失敗', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'old-vip-name',
        enabled: true,
        maxPets: 3,
      ),
      name: 'VIP尊爵房',
      petCount: 3,
      remainingRooms: 5,
      typeExists: false,
      roomCapacity: 3,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, '找不到對應房型資料，請聯絡店家');
  });

  test('尚未選完整時間不顯示剩餘 0', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'vip',
        enabled: true,
      ),
      name: 'VIP',
      petCount: 1,
      timesComplete: false,
      roomCapacity: 1,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, DaycareOccupancyService.selectTimesFirst);
    expect(option.remainingRooms, isNull);
  });

  test('沒有實體房顯示聯絡店家', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'vip',
        enabled: true,
      ),
      name: 'VIP',
      petCount: 1,
      remainingRooms: 0,
      zeroReason: DaycareOccupancyService.noPhysicalRooms,
      roomCapacity: 1,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, DaycareOccupancyService.noPhysicalRooms);
  });

  test('客戶端不讀 daycare_room_type_holds，月曆與房型剩餘仍可算', () {
    const List<String> paths = <String>[
      'lib/features/shop/widgets/booking/front_calendar_helper.dart',
      'lib/core/services/daycare_calendar_helper.dart',
      'lib/core/services/daycare_room_type_option.dart',
      'lib/core/services/daycare_occupancy_service.dart',
      'lib/core/services/booking_service.dart',
    ];
    for (final String path in paths) {
      expect(
        File(path).readAsStringSync().contains('daycare_room_type_holds'),
        isFalse,
        reason: path,
      );
    }
    final DaycareRoomRemaining remaining =
        DaycareOccupancyService.remainingRoomsResultFromData(
          rooms: const <Map<String, dynamic>>[
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
          ],
          bookings: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'holdless',
              'status': 'pending',
              'bookingKind': 'daycare',
              'requestedRoomTypeId': 'vip',
              'roomId': '',
              'scheduledStartAt': DateTime(2026, 9, 13, 10),
              'scheduledEndAt': DateTime(2026, 9, 13, 18),
            },
          ],
          roomTypeId: 'vip',
          startAt: DateTime(2026, 9, 13, 10),
          endAt: DateTime(2026, 9, 13, 18),
        );
    expect(remaining.reservedCount, 1);
    expect(remaining.remaining, 1);
  });
}
