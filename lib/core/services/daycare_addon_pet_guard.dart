// 檔案名稱：lib/core/services/daycare_addon_pet_guard.dart
// 功能說明：安親第 2 步：已選客製／每日分時段服務時必須指定寵物。

import 'package:petnest_saas/core/services/daycare_addon_line.dart';

class DaycareAddonPetGuard {
  DaycareAddonPetGuard._();

  static const String missingPetMessage = '請選擇要使用此服務的寵物';

  static bool requiresPet(Map<String, dynamic> addon) {
    final String group = DaycareAddonLine.groupKeyOf(addon);
    return group == DaycareAddonLine.groupCustom ||
        group == DaycareAddonLine.groupDailyTimed;
  }

  static List<String> addonIdsMissingPets({
    required Iterable<Map<String, dynamic>> selectedAddons,
    required Map<String, Set<String>> addonPetIds,
  }) {
    final List<String> missing = <String>[];
    for (final Map<String, dynamic> addon in selectedAddons) {
      if (!requiresPet(addon)) {
        continue;
      }
      final String id = (addon['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        continue;
      }
      final List<String> fromAddon = DaycareAddonLine.uniqueIds(
        addon['selectedPetIds'] as Iterable<dynamic>?,
      );
      final Set<String> pets = <String>{
        ...fromAddon,
        ...(addonPetIds[id] ?? <String>{}),
      };
      if (pets.isEmpty) {
        missing.add(id);
      }
    }
    return missing;
  }
}
