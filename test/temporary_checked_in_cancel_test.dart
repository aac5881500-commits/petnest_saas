import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_section.dart';

void main() {
  test(
    'temporary cancellation appears after check in but not after locking or checkout',
    () {
      bool cancel(String status, {bool locked = false}) =>
          stayBookingActionFlags(
            data: {'assignStatus': 'assigned', 'settlementLocked': locked},
            status: status,
            depositAmount: 0,
            depositPaid: true,
          ).cancel;
      expect(cancel('checked_in'), isTrue);
      expect(cancel('checked_in', locked: true), isFalse);
      expect(cancel('checked_out'), isFalse);
      expect(cancel('completed'), isFalse);
      expect(cancel('cancelled'), isFalse);
      expect(cancel('confirmed'), isTrue);
    },
  );
}
