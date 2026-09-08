// 檔案名稱：test/daycare_room_type_option_test.dart
// 功能說明：安親房型選項的單元測試（maxPets=1 選 2 隻不可選）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_room_type_option.dart';

void main() {
  test('maxPets=1 選 2 隻不可選', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'vip',
        enabled: true,
        maxPets: 1,
      ),
      name: 'VIP',
      petCount: 2,
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, '寵物數量超過容量');
  });

  test('maxPets=3 選 2 隻可選', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'view',
        enabled: true,
        maxPets: 3,
      ),
      name: '陽光景觀房',
      petCount: 2,
    );
    expect(option.selectable, isTrue);
  });

  test('maxPets=5 選 2 隻可選', () {
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: const DaycareRoomTypeSetting(
        roomTypeId: 'std',
        enabled: true,
        maxPets: 5,
      ),
      name: '舒適標準房',
      petCount: 2,
    );
    expect(option.selectable, isTrue);
  });

  test("maxPets='5' 選 2 隻可選", () {
    final DaycareRoomTypeSetting setting = DaycareRoomTypeSetting.fromMap(
      const <String, dynamic>{
        'roomTypeId': 'std',
        'enabled': true,
        'maxPets': '5',
      },
    );
    expect(setting.maxPets, 5);
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: setting,
      name: '舒適標準房',
      petCount: 2,
    );
    expect(option.selectable, isTrue);
  });

  test('extraPetPrice 不會當成 maxPets', () {
    final DaycareRoomTypeSetting setting = DaycareRoomTypeSetting.fromMap(
      const <String, dynamic>{
        'roomTypeId': 'std',
        'enabled': true,
        'maxPets': 5,
        'extraPetPrice': 100,
      },
    );
    expect(setting.maxPets, 5);
    expect(setting.extraPetPrice, 100);
    final DaycareRoomTypeOption option = DaycareRoomTypeCatalog.evaluate(
      setting: setting,
      name: '舒適標準房',
      petCount: 2,
    );
    expect(option.selectable, isTrue);
  });

  test('petCount 等於 maxPets 可選，超過才不可選', () {
    final DaycareRoomTypeSetting setting = const DaycareRoomTypeSetting(
      roomTypeId: 'vip',
      enabled: true,
      maxPets: 3,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: 'VIP尊爵房',
        petCount: 3,
        remainingRooms: 5,
      ).selectable,
      isTrue,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: 'VIP尊爵房',
        petCount: 4,
        remainingRooms: 5,
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
      ).selectable,
      isTrue,
    );
    expect(
      DaycareRoomTypeCatalog.evaluate(
        setting: setting,
        name: '舒適標準房',
        petCount: 3,
        remainingRooms: 0,
      ).selectable,
      isFalse,
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
    );
    final DaycareRoomTypeOption stdOption = DaycareRoomTypeCatalog.evaluate(
      setting: std,
      name: '舒適標準房',
      petCount: 3,
      remainingRooms: 9,
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
    );
    expect(option.selectable, isFalse);
    expect(option.blockedReason, '找不到對應房型資料，請聯絡店家');
  });

  test('選 VIP 後重新整理選項仍可用同一 roomTypeId 對應', () {
    const String selected = 'vip_id';
    final List<DaycareRoomTypeOption> options = <DaycareRoomTypeOption>[
      DaycareRoomTypeCatalog.evaluate(
        setting: const DaycareRoomTypeSetting(
          roomTypeId: 'vip_id',
          enabled: true,
          maxPets: 3,
        ),
        name: 'VIP尊爵房',
        petCount: 3,
        remainingRooms: 5,
      ),
      DaycareRoomTypeCatalog.evaluate(
        setting: const DaycareRoomTypeSetting(
          roomTypeId: 'std_id',
          enabled: true,
          maxPets: 3,
        ),
        name: '舒適標準房',
        petCount: 3,
        remainingRooms: 9,
      ),
    ];
    expect(
      options.any(
        (DaycareRoomTypeOption e) => e.selectable && e.roomTypeId == selected,
      ),
      isTrue,
    );
  });

  test('不會把住宿 capacity 或缺欄位預設成全房型都只能 1 隻', () {
    final DaycareRoomTypeSetting missing = DaycareRoomTypeSetting.fromMap(
      const <String, dynamic>{'roomTypeId': 'a', 'enabled': true},
    );
    expect(missing.maxPets, 1);
    final DaycareRoomTypeSetting fromDouble = DaycareRoomTypeSetting.fromMap(
      const <String, dynamic>{
        'roomTypeId': 'b',
        'enabled': true,
        'maxPets': 5.0,
      },
    );
    expect(fromDouble.maxPets, 5);
  });
}
