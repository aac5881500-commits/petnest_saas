// 檔案名稱：test/booking_settlement_complete_test.dart
// 功能說明：安親結算後待補／待退不可當成訂單完成

import 'dart:io';

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
    expect(view.depositRequirementComplete, isTrue);
    expect(view.paymentProgressSubtitle, '訂金已付，結算尾款待服務結束');
  });

  test('信用卡訂金成功上方付款卡不可已付清', () {
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'paymentMethod': 'credit_card',
        'quotedTotalPrice': 700,
        'totalPrice': 700,
        'paidAmount': 500,
        'depositAmount': 500,
        'depositPaid': true,
        'depositStatus': 'confirmed',
        'status': 'confirmed',
      },
      docId: 'id',
    );
    expect(view.isPaidInFull, isFalse);
    expect(view.paymentProgressSubtitle, isNot('已付清'));
    expect(view.paymentProgressSubtitle, contains('訂金已付'));
    expect(view.depositRequirementComplete, isTrue);
  });

  test('真正結清才顯示已付清', () {
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 700,
        'paidAmount': 700,
        'refundAmount': 0,
        'status': 'completed',
      },
      docId: 'id',
    );
    expect(view.isPaidInFull, isTrue);
    expect(view.paymentProgressSubtitle, '已付清');
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

  test('住宿退房待補款不可 completed 也不可已付清', () {
    expect(
      BookingSettlementMath.isOrderComplete(<String, dynamic>{
        'bookingKind': 'accommodation',
        'settlementConfirmed': true,
        'quotedTotalPrice': 3000,
        'paidAmount': 1000,
        'status': 'checked_out',
      }),
      isFalse,
    );
    expect(
      BookingSettlementMath.isStayAwaitingClear(<String, dynamic>{
        'bookingKind': 'accommodation',
        'settlementConfirmed': true,
        'quotedTotalPrice': 3000,
        'paidAmount': 1000,
        'status': 'checked_out',
      }),
      isTrue,
    );
    final BookingDetailViewData view = BookingDetailViewData.fromBooking(
      data: <String, dynamic>{
        'bookingKind': 'accommodation',
        'settlementConfirmed': true,
        'quotedTotalPrice': 3000,
        'totalPrice': 3000,
        'paidAmount': 1000,
        'manualAdjust': 200,
        'manualAdjustmentReason': '加收清潔',
        'status': 'checked_out',
      },
      docId: 'stay-1',
    );
    expect(view.statusTitle, '待支付結算尾款');
    expect(view.paymentStatusLabel, '待支付結算尾款');
    expect(view.isPaidInFull, isFalse);
    expect(
      view.feeLines.any((BookingDetailFeeLine e) => e.label == '手動加收'),
      isTrue,
    );
  });

  test('住宿前端退房不可再直接寫 completed', () {
    final String src = File(
      'lib/features/admin/pages/admin_booking_detail_page.dart',
    ).readAsStringSync();
    expect(src.contains("'status': 'completed'"), isFalse);
    expect(src.contains('額外清潔費'), isFalse);
    expect(src.contains('退房 - 額外收費'), isFalse);
    expect(src.contains("action: 'checkOutStay'"), isTrue);
    expect(
      File(
        'lib/features/admin/widgets/admin_booking_action_section.dart',
      ).readAsStringSync().contains('辦理退房／結算'),
      isTrue,
    );
  });
}
