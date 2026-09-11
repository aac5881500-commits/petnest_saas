// 檔案名稱：test/booking_settlement_math_test.dart
// 功能說明：待補／待退計算例子

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';

void main() {
  test('已收 1600，應收 1800 → 待補 200', () {
    expect(
      BookingSettlementMath.balanceDelta(
        data: <String, dynamic>{
          'totalPrice': 1800,
          'quotedTotalPrice': 1800,
          'paidAmount': 1600,
        },
      ),
      200,
    );
  });

  test('已收 1600，應收 1400 → 待退 200', () {
    expect(
      BookingSettlementMath.balanceDelta(
        data: <String, dynamic>{
          'totalPrice': 1400,
          'quotedTotalPrice': 1400,
          'paidAmount': 1600,
        },
      ),
      -200,
    );
  });

  test('已收 800，應收由 1600 降成 1400 → 待補 600', () {
    expect(
      BookingSettlementMath.balanceDelta(
        data: <String, dynamic>{
          'totalPrice': 1400,
          'quotedTotalPrice': 1400,
          'paidAmount': 800,
        },
      ),
      600,
    );
  });

  test('已收 1600、已退 200，應收 1500 → 待補 100', () {
    expect(
      BookingSettlementMath.balanceDelta(
        data: <String, dynamic>{
          'totalPrice': 1500,
          'quotedTotalPrice': 1500,
          'paidAmount': 1600,
          'refundAmount': 200,
        },
      ),
      100,
    );
  });

  test('已收 500 應收降為 1000 → 待補 500 不退', () {
    expect(
      BookingSettlementMath.balanceDelta(
        data: <String, dynamic>{
          'totalPrice': 1000,
          'quotedTotalPrice': 1000,
          'paidAmount': 500,
        },
      ),
      500,
    );
  });

  test('paidAmount 為 0 時改讀 paymentPaidAmount，不把預計訂金當實收', () {
    expect(
      BookingSettlementMath.paidAmount(<String, dynamic>{
        'paidAmount': 0,
        'paymentPaidAmount': 500,
        'depositAmount': 800,
      }),
      500,
    );
    expect(
      BookingSettlementMath.paidAmount(<String, dynamic>{
        'paidAmount': 0,
        'depositAmount': 800,
      }),
      0,
    );
    expect(
      BookingSettlementMath.paidAmount(<String, dynamic>{
        'paidAmount': 0,
        'depositAmount': 800,
        'depositStatus': 'confirmed',
      }),
      800,
    );
  });
}
