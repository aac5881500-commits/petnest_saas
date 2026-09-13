// 檔案名稱：test/booking_settlement_complete_test.dart
// 功能說明：安親結算後待補／待退不可當成訂單完成

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

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

  test('只付訂金不可當成已付清', () {
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'quotedTotalPrice': 1800,
        'totalPrice': 1800,
        'paidAmount': 500,
        'depositAmount': 500,
        'depositPaid': true,
        'depositStatus': 'confirmed',
        'status': 'confirmed',
      },
      docId: 'id',
    );
    expect(view.isPaidInFull, isFalse);
    expect(view.paymentStatusLabel, isNot('已付清'));
    expect(view.daycareDepositProgressLabel, '訂金已付 NT\$500');
  });

  test('結算待補款不可顯示已完成', () {
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 1800,
        'paidAmount': 500,
        'status': 'completed',
      },
      docId: 'id',
    );
    expect(view.statusTitle, isNot('已完成'));
    expect(view.paymentStatusLabel, isNot('已付清'));
    expect(view.isPaidInFull, isFalse);
  });
}
