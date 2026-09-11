// 檔案名稱：test/daycare_addon_pet_guard_test.dart
// 功能說明：安親第 2 步已選服務未選寵物不可進入下一步。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daycare_addon_line.dart';
import 'package:petnest_saas/core/services/daycare_addon_pet_guard.dart';

void main() {
  test('未選加值服務可進入下一步', () {
    expect(
      DaycareAddonPetGuard.addonIdsMissingPets(
        selectedAddons: const <Map<String, dynamic>>[],
        addonPetIds: const <String, Set<String>>{},
      ),
      isEmpty,
    );
  });

  test('已選客製服務未選寵物不可進入下一步', () {
    final List<String> missing = DaycareAddonPetGuard.addonIdsMissingPets(
      selectedAddons: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'custom1',
          'groupKey': DaycareAddonLine.groupCustom,
        },
      ],
      addonPetIds: const <String, Set<String>>{},
    );
    expect(missing, <String>['custom1']);
    expect(DaycareAddonPetGuard.missingPetMessage, '請選擇要使用此服務的寵物');
  });

  test('已選服務並指定寵物可進入下一步', () {
    expect(
      DaycareAddonPetGuard.addonIdsMissingPets(
        selectedAddons: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'custom1',
            'groupKey': DaycareAddonLine.groupCustom,
            'selectedPetIds': <String>['p1'],
          },
        ],
        addonPetIds: const <String, Set<String>>{},
      ),
      isEmpty,
    );
  });
}
