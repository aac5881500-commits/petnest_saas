// lib/core/services/daycare_calendar_helper.dart
// 🐾 前台／後台臨托月曆：套用星期規則、單日例外與當日名額

import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

class DaycareCalendarHelper {
  DaycareCalendarHelper._();

  static Future<FrontCalendarPayload> buildPayload({
    required String shopId,
    required Map<String, dynamic> shop,
    required DaycareSettingsModel settings,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final DateTime start = DateTime(
      firstDate.year,
      firstDate.month,
      firstDate.day,
    );
    final DateTime end = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final Map<String, DaycareDateOverrideModel> overrides =
        await DaycareDateOverrideService.instance.loadRange(
          shopId: shopId,
          start: start,
          end: end,
        );
    final Map<String, int> usedPets = await DaycareOccupancyService.instance
        .usedPetsByDate(shopId: shopId, start: start, end: end);

    final Set<int> closedWeekdays = <int>{
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    }.difference(settings.weekdays.toSet());
    final Set<String> extraClosed = <String>{};
    final Set<String> extraOpen = <String>{};
    final Set<String> specialOpen = <String>{};
    final Set<String> extraFull = <String>{};
    final Map<String, int> remainingPetsMap = <String, int>{};

    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      final String key = ShopService.instance.formatDateKey(cursor);
      final DaycareDateOverrideModel? override =
          overrides[DaycareTimeHelper.overrideDocId(cursor)] ?? overrides[key];
      final bool open = DaycareDateAvailability.isDateOpen(
        settings: settings,
        date: cursor,
        override: override,
      );
      if (override != null && override.isOpen) {
        extraOpen.add(key);
        specialOpen.add(key);
      } else if (override != null && !override.isOpen) {
        extraClosed.add(key);
      }
      if (open) {
        final int maxPets = DaycareDateAvailability.dailyMaxPets(
          settings: settings,
          override: override,
        );
        final int used = usedPets[key] ?? 0;
        final int left = (maxPets - used).clamp(0, maxPets);
        remainingPetsMap[key] = left;
        if (left <= 0) {
          extraFull.add(key);
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return FrontCalendarHelper.buildPayload(
      shopId: shopId,
      shop: shop,
      firstDate: start,
      lastDate: end,
      extraClosedWeekdays: closedWeekdays,
      extraClosedReason: '未開放臨托',
      extraClosedDateKeys: extraClosed,
      extraOpenDateKeys: extraOpen,
      extraFullDateKeys: extraFull,
      specialOpenDateKeys: specialOpen,
      remainingPetsMap: remainingPetsMap,
      markFullRoomsUnbookable: false,
    );
  }
}
