// test/daycare_legacy_parse_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';

void main() {
  test('舊方案 requiresRoomType 仍可讀取，但新 toMap 不再寫入', () {
    final DaycarePlanModel plan = DaycarePlanModel.fromMap(
      const <String, dynamic>{
        'id': 'old',
        'name': '舊方案',
        'requiresRoomType': true,
      },
    );
    expect(plan.requiresRoomType, isTrue);
    expect(plan.toMap().containsKey('requiresRoomType'), isFalse);
  });

  test('舊臨托點數、黑名單、疫苗欄位可讀取，新 toMap 不再寫入', () {
    final DaycareSettingsModel settings =
        DaycareSettingsModel.fromMap(const <String, dynamic>{
          'enabled': true,
          'blockBlacklisted': false,
          'requireVaccine': true,
          'allowUnneutered': false,
          'pointsEarnEnabled': true,
          'pointsSpendEnabled': true,
          'termsEnabled': true,
          'termsTitle': '舊臨托條款',
          'termsContent': '舊內容',
        });
    expect(settings.blockBlacklisted, isFalse);
    expect(settings.requireVaccine, isTrue);
    expect(settings.pointsEarnEnabled, isTrue);
    final Map<String, dynamic> map = settings.toMap();
    expect(map.containsKey('blockBlacklisted'), isFalse);
    expect(map.containsKey('requireVaccine'), isFalse);
    expect(map.containsKey('pointsEarnEnabled'), isFalse);
    expect(map.containsKey('termsTitle'), isFalse);
  });

  test('舊人工確認與房型開關可讀取，新 toMap 不再寫入', () {
    final DaycareSettingsModel settings = DaycareSettingsModel.fromMap(
      const <String, dynamic>{
        'requiresManualConfirm': false,
        'requireRoomType': false,
        'allowedAddonIds': <String>['a1'],
      },
    );
    expect(settings.requiresManualConfirm, isFalse);
    expect(settings.requireRoomType, isFalse);
    expect(settings.allowedAddonIds, <String>['a1']);
    final Map<String, dynamic> map = settings.toMap();
    expect(map.containsKey('requiresManualConfirm'), isFalse);
    expect(map.containsKey('requireRoomType'), isFalse);
    expect(map['allowedAddonIds'], <String>['a1']);
  });

  test('舊上午方案仍可解析顯示，但不可再選用', () {
    final DaycarePlanModel plan = DaycarePlanModel.fromMap(
      const <String, dynamic>{'id': 'am', 'name': '上午', 'type': 'morning'},
    );
    expect(plan.type, DaycarePlanTypes.morning);
    expect(DaycarePlanTypes.isSelectable(plan.type), isFalse);
    expect(DaycarePlanTypes.label(plan.type), '上午方案');
  });
}
