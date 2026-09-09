import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daycare_assign_room_rules.dart';

void main() {
  test('房型計費不可跨房型', () {
    final Map<String, dynamic> booking = <String, dynamic>{
      'pricingMode': 'room_based',
      'requestedRoomTypeId': 'deluxe',
    };
    expect(
      DaycareAssignRoomRules.allowsAssignedRoomType(
        booking: booking,
        assignedRoomTypeId: 'standard',
      ),
      isFalse,
    );
    expect(
      DaycareAssignRoomRules.allowsAssignedRoomType(
        booking: booking,
        assignedRoomTypeId: 'deluxe',
      ),
      isTrue,
    );
  });

  test('獨立方案可選任意房型', () {
    final Map<String, dynamic> booking = <String, dynamic>{
      'pricingMode': 'time_based',
      'requestedRoomTypeId': '',
    };
    expect(
      DaycareAssignRoomRules.allowsAssignedRoomType(
        booking: booking,
        assignedRoomTypeId: 'any',
      ),
      isTrue,
    );
  });
}
