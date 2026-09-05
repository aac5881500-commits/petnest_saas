// 檔案名稱：lib/core/services/daycare_date_availability.dart
// 功能說明：安親可預約日期：預設開放，僅明確關閉／店休例外不可預約

import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class DaycareDayHours {
  const DaycareDayHours({
    required this.openTime,
    required this.closeTime,
    required this.earliestDropOff,
    required this.latestPickUp,
    this.latestDropoffTime = '',
  });

  final String openTime;
  final String closeTime;
  final String earliestDropOff;
  final String latestPickUp;

  /// 當日最晚可送達；空白表示不另限
  final String latestDropoffTime;
}

class DaycareDateAvailability {
  DaycareDateAvailability._();

  /// 沒有例外文件 → 可預約。只有明確關閉才不可預約。
  /// 舊的 specialOpen／星期規則仍可讀取，但不再用來關閉日期。
  static bool isDateOpen({
    required DaycareSettingsModel settings,
    required DateTime date,
    DaycareDateOverrideModel? override,
  }) {
    if (override == null) {
      return true;
    }
    return override.isOpen;
  }

  /// 安親前台／後台共用日期判斷。
  static Future<bool> isDaycareDateAvailable({
    required String shopId,
    required DateTime date,
    Map<String, dynamic>? shop,
    DaycareSettingsModel? settings,
    DaycareDateOverrideModel? override,
    int? remainingPets,
  }) async {
    final Map<String, dynamic> liveShop =
        shop ??
        (await ShopService.instance.getShop(shopId)) ??
        const <String, dynamic>{};
    final DaycareSettingsModel liveSettings =
        settings ?? await DaycareSettingsService.instance.get(shopId);
    if (!DaycareSettingsService.instance.isEnabledForShop(
      shop: liveShop,
      settings: liveSettings,
    )) {
      return false;
    }
    DaycareDateOverrideModel? liveOverride = override;
    liveOverride ??= await DaycareDateOverrideService.instance.get(
      shopId: shopId,
      date: date,
    );
    if (!isDateOpen(
      settings: liveSettings,
      date: date,
      override: liveOverride,
    )) {
      return false;
    }
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (day.isBefore(today)) {
      return false;
    }
    final int maxDays = _toInt(liveShop['maxAdvanceBookingDays'], 30);
    if (maxDays > 0 && day.isAfter(today.add(Duration(days: maxDays)))) {
      return false;
    }
    final int dailyMax = dailyMaxPets(settings: liveSettings);
    if (dailyMax <= 0) {
      return true;
    }
    int left = remainingPets ?? -1;
    if (left < 0) {
      left = await DaycareOccupancyService.instance.remainingPets(
        shopId: shopId,
        serviceDate: day,
        dailyMaxPets: dailyMax,
      );
    }
    return left > 0;
  }

  static int dailyMaxPets({
    required DaycareSettingsModel settings,
    DaycareDateOverrideModel? override,
  }) {
    // 單日 maxPets 舊欄位不再覆寫全店每日接待量。
    return settings.dailyMaxPets;
  }

  static DaycareDayHours hours({
    required DaycareSettingsModel settings,
    DaycareDateOverrideModel? override,
  }) {
    return DaycareDayHours(
      openTime: settings.openTime,
      closeTime: settings.closeTime,
      earliestDropOff: settings.earliestDropOff,
      latestPickUp: settings.latestPickUp,
      latestDropoffTime: '',
    );
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
