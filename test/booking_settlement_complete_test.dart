// 檔案名稱：test/booking_settlement_complete_test.dart
// 功能說明：安親結算後待補／待退不可當成訂單完成

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';

void main() {
  test('應收等於已收才完成', () {
    expect(
      BookingSettlementMath.isOrderComplete(<String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 1000,
        'paidAmount': 1000,
        'status': 'checked_in',
      }),
      isTrue,
    );
  });

  test('待補款不可 completed', () {
    expect(
      BookingSettlementMath.isOrderComplete(<String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 1200,
        'paidAmount': 1000,
        'status': 'completed',
      }),
      isFalse,
    );
    expect(
      BookingSettlementMath.isDaycareAwaitingClear(<String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 1200,
        'paidAmount': 1000,
      }),
      isTrue,
    );
  });

  test('待退款不可 completed', () {
    expect(
      BookingSettlementMath.isOrderComplete(<String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 800,
        'paidAmount': 1000,
        'status': 'completed',
      }),
      isFalse,
    );
  });
}
