// 檔案名稱：lib/core/services/daycare_enabled.dart
// 功能說明：安親總開關唯一判斷：shops.daycareEnabled；舊資料才回退 daycare_settings.enabled

import 'package:petnest_saas/core/models/daycare_settings_model.dart';

class DaycareEnabled {
  DaycareEnabled._();

  static const String closedMessage = '店家目前未開放安親服務';

  static bool isOn({
    Map<String, dynamic>? shop,
    DaycareSettingsModel? settings,
    bool? settingsEnabled,
  }) {
    final dynamic shopFlag = shop == null ? null : shop['daycareEnabled'];
    if (_hasExplicit(shopFlag)) {
      return DaycareBool.parse(shopFlag);
    }
    if (settings != null) {
      return DaycareBool.parse(settings.enabled);
    }
    return DaycareBool.parse(settingsEnabled);
  }

  static bool _hasExplicit(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String && value.trim().isEmpty) {
      return false;
    }
    return true;
  }
}
