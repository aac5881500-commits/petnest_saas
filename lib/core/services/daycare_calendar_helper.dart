// 檔案名稱：lib/core/services/daycare_calendar_helper.dart
// 功能說明：前台／後台安親月曆：預設開放、關閉例外與當日名額

import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
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
    bool secureCustomer = false,
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
    final Map<String, DaycareAvailabilityDay> secureDays =
        <String, DaycareAvailabilityDay>{};
    final Map<String, int> usedPets;
    if (secureCustomer) {
      final List<DateTime> dates = <DateTime>[];
      DateTime cursorDay = start;
      while (!cursorDay.isAfter(end)) {
        dates.add(cursorDay);
        cursorDay = cursorDay.add(const Duration(days: 1));
      }
      final DaycareAvailabilitySnapshot snapshot =
          await DaycareOccupancyService.instance.customerAvailability(
            shopId: shopId,
            dates: dates,
          );
      for (final DaycareAvailabilityDay day in snapshot.days) {
        secureDays[day.date] = day;
      }
      usedPets = <String, int>{
        for (final DaycareAvailabilityDay day in snapshot.days)
          day.date: day.occupied,
      };
    } else {
      usedPets = await DaycareOccupancyService.instance.usedPetsByDate(
        shopId: shopId,
        start: start,
        end: end,
      );
    }

    final Set<String> extraClosed = <String>{};
    final Set<String> extraOpen = <String>{};
    final Set<String> extraFull = <String>{};
    final Map<String, int> remainingPetsMap = <String, int>{};
    final int dailyMax = DaycareDateAvailability.dailyMaxPets(
      settings: settings,
    );

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
      final int used = usedPets[key] ?? 0;
      final DaycareAvailabilityDay? secure = secureDays[key];
      if (secureCustomer && secure == null) {
        throw const DaycareAvailabilityException('暫時無法取得剩餘名額');
      }
      final int left = secure != null
          ? (secure.unlimited ? 999999 : (secure.remaining ?? 0))
          : (dailyMax <= 0 ? 999999 : (dailyMax - used).clamp(0, dailyMax));
      remainingPetsMap[key] = secure != null
          ? (secure.unlimited ? -1 : left)
          : (dailyMax <= 0 ? -1 : left);
      final bool available =
          await DaycareDateAvailability.isDaycareDateAvailable(
            shopId: shopId,
            date: cursor,
            shop: shop,
            settings: settings,
            override: override,
            remainingPets: left,
          );
      // 覆寫店家住宿 blockedDates，安親只認自己的關閉例外。
      extraOpen.add(key);
      final bool enabled = DaycareSettingsService.instance.isEnabledForShop(
        shop: shop,
        settings: settings,
      );
      if (!enabled || !open) {
        extraClosed.add(key);
        extraOpen.remove(key);
      } else if (!available) {
        extraFull.add(key);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return FrontCalendarHelper.buildPayload(
      shopId: shopId,
      shop: shop,
      firstDate: start,
      lastDate: end,
      extraClosedWeekdays: const <int>{},
      extraClosedReason: '店休',
      extraClosedDateKeys: extraClosed,
      extraOpenDateKeys: extraOpen,
      extraFullDateKeys: extraFull,
      specialOpenDateKeys: const <String>{},
      remainingPetsMap: remainingPetsMap,
      markFullRoomsUnbookable: false,
      skipRoomInventory: true,
    );
  }
}
