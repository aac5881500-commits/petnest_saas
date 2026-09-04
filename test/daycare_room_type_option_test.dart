// test/daycare_room_type_option_test.dart
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
