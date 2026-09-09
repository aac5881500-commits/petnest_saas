// 檔案名稱：test/daycare_enabled_test.dart
// 功能說明：安親總開關以 shops.daycareEnabled 為準

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';

void main() {
  test('shop 明確關閉時即使 settings.enabled 仍為開也視為關閉', () {
    expect(
      DaycareEnabled.isOn(
        shop: <String, dynamic>{'daycareEnabled': false},
        settings: const DaycareSettingsModel(enabled: true),
      ),
      isFalse,
    );
  });

  test('舊資料沒有 shop 欄位時才回退 settings.enabled', () {
    expect(
      DaycareEnabled.isOn(
        shop: <String, dynamic>{},
        settings: const DaycareSettingsModel(enabled: true),
      ),
      isTrue,
    );
  });
}
