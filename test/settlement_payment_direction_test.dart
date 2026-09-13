// 檔案名稱：test/settlement_payment_direction_test.dart
// 功能說明：減免後依待補／待退顯示補款或退款

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';

void main() {
  test('原價 3200 已收 1600 減免 500 仍待補 1100', () {
    const Map<String, dynamic> booking = <String, dynamic>{
      'quotedTotalPrice': 3200,
      'paidAmount': 1600,
    };
    expect(
      BookingSettlementMath.expectedTotal(
        data: booking,
        manualAdjustOverride: -500,
      ),
      2700,
    );
    expect(
      BookingSettlementMath.remainingDue(
        data: booking,
        manualAdjustOverride: -500,
      ),
      1100,
    );
    expect(
      BookingSettlementMath.refundDue(
        data: booking,
        manualAdjustOverride: -500,
      ),
      0,
    );
    expect(SettlementAdjustDisplay.showTopUp(1100, 0), isTrue);
    expect(SettlementAdjustDisplay.showRefund(1100, 0), isFalse);
  });

  test('已收大於最終應收才顯示退款方式', () {
    expect(SettlementAdjustDisplay.showTopUp(0, 500), isFalse);
    expect(SettlementAdjustDisplay.showRefund(0, 500), isTrue);
    expect(SettlementAdjustDisplay.showTopUp(0, 0), isFalse);
    expect(SettlementAdjustDisplay.showRefund(0, 0), isFalse);
  });

  test('台灣 15:40 UTC 讀回仍是 15:40', () {
    final DateTime utc = DateTime.utc(2026, 9, 13, 7, 40);
    expect(DaycareTimeHelper.formatHm(utc), '15:40');
    expect(DaycareTimeHelper.callableInstant(utc).endsWith('Z'), isTrue);
    expect(DaycareTimeHelper.formatHm(utc).contains('23'), isFalse);
  });

  test('客戶變更付款改走 Cloud Function', () {
    final String src = File(
      'lib/features/booking/pages/booking_detail_page.dart',
    ).readAsStringSync();
    expect(src.contains('changeCustomerPaymentMethod'), isTrue);
    expect(src.contains('DaycareFunctionException'), isTrue);
  });
}
