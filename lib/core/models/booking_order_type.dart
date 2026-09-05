// 檔案名稱：lib/core/models/booking_order_type.dart
// 功能說明：後台訂單類型：住宿／依房型安親／獨立時計安親；無法判斷時為 unknown。

import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingOrderType {
  BookingOrderType._();

  static const String accommodation = 'accommodation';
  static const String daycareRoomType = 'daycare_room_type';
  static const String daycareIndependentPlan = 'daycare_independent_plan';
  static const String unknown = 'unknown';

  static String resolve(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return unknown;
    }
    final String kind = BookingKind.resolve(data);
    if (kind == BookingKind.accommodation) {
      return accommodation;
    }
    if (kind != BookingKind.daycare) {
      return unknown;
    }
    final String requestedRoomTypeId = SafeParse.parseString(
      data['requestedRoomTypeId'],
    );
    final String planId = SafeParse.parseString(data['daycarePlanId']);
    final String rawMode = SafeParse.parseString(data['pricingMode']);
    if (DaycarePricingModes.isRoomBased(rawMode) ||
        requestedRoomTypeId.isNotEmpty) {
      return daycareRoomType;
    }
    if (rawMode == DaycarePricingModes.independentPlan ||
        rawMode == DaycarePricingModes.timeBased ||
        planId.isNotEmpty) {
      return daycareIndependentPlan;
    }
    return unknown;
  }

  static String label(String type) {
    switch (type) {
      case daycareRoomType:
        return '依房型安親';
      case daycareIndependentPlan:
        return '獨立時計安親';
      case accommodation:
        return '住宿';
      default:
        return '未知訂單類型';
    }
  }
}
