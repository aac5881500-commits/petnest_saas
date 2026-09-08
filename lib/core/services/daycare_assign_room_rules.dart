// 檔案名稱：lib/core/services/daycare_assign_room_rules.dart
// 功能說明：安親分房限制：房型計費不可改房型；獨立方案可選房型但不可改價

import 'package:petnest_saas/core/models/daycare_settings_model.dart';

class DaycareAssignRoomRules {
  DaycareAssignRoomRules._();

  static String requestedRoomTypeId(Map<String, dynamic> booking) {
    final String requested =
        (booking['requestedRoomTypeId'] ??
                booking['requested_room_type_id'] ??
                '')
            .toString()
            .trim();
    if (requested.isNotEmpty) {
      return requested;
    }
    if (isRoomBased(booking) &&
        (booking['assignStatus'] ?? 'unassigned').toString() != 'assigned' &&
        (booking['roomId'] ?? '').toString().trim().isEmpty) {
      return (booking['roomTypeId'] ?? '').toString().trim();
    }
    return '';
  }

  static bool isRoomBased(Map<String, dynamic> booking) {
    return DaycarePricingModes.isRoomBased(
      (booking['pricingMode'] ?? '').toString(),
    );
  }

  static bool lockRoomType(Map<String, dynamic> booking) {
    return isRoomBased(booking) && requestedRoomTypeId(booking).isNotEmpty;
  }

  static bool allowsAssignedRoomType({
    required Map<String, dynamic> booking,
    required String assignedRoomTypeId,
  }) {
    final String assigned = assignedRoomTypeId.trim();
    if (assigned.isEmpty) {
      return false;
    }
    if (!isRoomBased(booking)) {
      return true;
    }
    return assigned == requestedRoomTypeId(booking);
  }
}
