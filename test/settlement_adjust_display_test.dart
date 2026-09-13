// 檔案名稱：test/settlement_adjust_display_test.dart
// 功能說明：安親加收／減免正負轉換、原因顯示條件、房號自然排序。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';

void main() {
  test('加收與減免只接受正數並轉成 signed adjustment', () {
    expect(
      SettlementAdjustDisplay.signedAmount(surcharge: true, unsigned: 500),
      500,
    );
    expect(
      SettlementAdjustDisplay.signedAmount(surcharge: false, unsigned: 500),
      -500,
    );
    expect(
      DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.surcharge,
        unsignedAmount: 500,
      ).signed,
      500,
    );
    expect(
      DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.discount,
        unsignedAmount: 300,
      ).signed,
      -300,
    );
    expect(
      const DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.none,
        unsignedAmount: 80,
      ).signed,
      0,
    );
    expect(SettlementAdjustDisplay.signedLabel(500), '＋NT\$500');
    expect(SettlementAdjustDisplay.signedLabel(-300), '－NT\$300');
  });

  test('未調整或沒有原因不顯示空白欄', () {
    expect(
      SettlementAdjustDisplay.shouldShow(<String, dynamic>{
        'manualAdjust': 0,
        'manualAdjustmentReason': 'x',
      }),
      isFalse,
    );
    expect(
      SettlementAdjustDisplay.shouldShow(<String, dynamic>{
        'manualAdjust': 500,
        'manualAdjustmentReason': '',
      }),
      isFalse,
    );
    expect(
      SettlementAdjustDisplay.shouldShow(<String, dynamic>{
        'manualAdjust': 500,
        'manualAdjustmentReason': '晚接回加收貓砂',
      }),
      isTrue,
    );
    expect(
      SettlementAdjustDisplay.customerNoteOf(<String, dynamic>{
        'manualAdjust': 500,
        'manualAdjustmentReason': '測試',
      }),
      '店家調整說明：測試',
    );
    expect(
      SettlementAdjustDisplay.shopAmountLine(500),
      '手動加收：＋NT\$500',
    );
    expect(
      SettlementAdjustDisplay.shopAmountLine(-300),
      '手動減免：－NT\$300',
    );
    expect(
      SettlementAdjustDisplay.isReasonMissing(amount: 500, reason: '  測試  '),
      isFalse,
    );
    expect(
      SettlementAdjustDisplay.isReasonMissing(amount: 500, reason: '   '),
      isTrue,
    );
    expect(
      SettlementAdjustDisplay.isReasonMissing(amount: 0, reason: ''),
      isFalse,
    );
    expect(
      SettlementAdjustDisplay.reasonOf(<String, dynamic>{
        'settlement': <String, dynamic>{'manualAdjustmentReason': '巢狀原因'},
      }),
      '巢狀原因',
    );
  });

  test('安親房號自然排序 A1 A2 A10 B1', () {
    final List<String> rooms = <String>['B1', 'A10', 'A2', 'A1']
      ..sort((String a, String b) => compareRoomCodes(a, b, tieA: a, tieB: b));
    expect(rooms, <String>['A1', 'A2', 'A10', 'B1']);
  });

  test('手機完整交易只在第三方金流顯示', () {
    expect(
      ShopPaymentMethods.hasThirdPartyGatewayTransaction(<String, dynamic>{
        'paymentMethod': 'transfer',
      }),
      isFalse,
    );
    expect(
      ShopPaymentMethods.hasThirdPartyGatewayTransaction(<String, dynamic>{
        'paymentMethod': 'bank_transfer',
      }),
      isFalse,
    );
    expect(
      ShopPaymentMethods.hasThirdPartyGatewayTransaction(<String, dynamic>{
        'paymentMethod': 'credit_card',
      }),
      isTrue,
    );
    expect(
      ShopPaymentMethods.hasThirdPartyGatewayTransaction(<String, dynamic>{
        'paymentMethod': 'atm',
      }),
      isTrue,
    );
    expect(
      ShopPaymentMethods.hasThirdPartyGatewayTransaction(<String, dynamic>{
        'paymentMethod': 'cvs_code',
      }),
      isTrue,
    );
  });

  test('確認訂金按鈕條件：人工轉帳、未確認、已上傳照片', () {
    expect(
      BookingPaymentProof.canConfirmManualDeposit(<String, dynamic>{
        'paymentMethod': 'transfer',
        'depositAmount': 500,
        'depositPaid': false,
        'transferImageUrl': 'https://a/img.jpg',
      }),
      isTrue,
    );
    expect(
      BookingPaymentProof.canConfirmManualDeposit(<String, dynamic>{
        'paymentMethod': 'credit_card',
        'depositAmount': 500,
        'depositPaid': false,
        'transferImageUrl': 'https://a/img.jpg',
      }),
      isFalse,
    );
    expect(
      BookingPaymentProof.canConfirmManualDeposit(<String, dynamic>{
        'paymentMethod': 'transfer',
        'depositAmount': 500,
        'depositPaid': true,
        'transferImageUrl': 'https://a/img.jpg',
      }),
      isFalse,
    );
    expect(
      BookingPaymentProof.canConfirmManualDeposit(<String, dynamic>{
        'paymentMethod': 'transfer',
        'depositAmount': 500,
        'depositPaid': false,
      }),
      isFalse,
    );
  });

  test('可見收費列加總等於最終結算應付，原預估尾款不混入', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'bookingKind': 'daycare',
      'settlementConfirmed': true,
      'quotedTotalPrice': 700,
      'overtimeAmount': 300,
      'overtimeMinutes': 160,
      'overtimeUnits': 6,
      'manualAdjust': 1000,
      'manualAdjustmentReason': '加購清潔',
    };
    final List<BookingSettlementDisplayLine> lines =
        BookingFinalSettlementDisplay.daycareLines(data);
    expect(
      lines.any((BookingSettlementDisplayLine e) => e.label == '原預估尾款'),
      isFalse,
    );
    expect(
      lines.where((BookingSettlementDisplayLine e) => e.label == '晚接回超時計費').length,
      1,
    );
    expect(
      lines.any((BookingSettlementDisplayLine e) => e.label == '超時加收'),
      isFalse,
    );
    expect(
      lines.any((BookingSettlementDisplayLine e) => e.label == '接回逾時費'),
      isFalse,
    );
    final BookingSettlementDisplayLine late = lines.firstWhere(
      (BookingSettlementDisplayLine e) => e.label == '晚接回超時計費',
    );
    expect(late.amount, 300);
    expect(late.subtitle, contains('160 分鐘'));
    expect(
      BookingFinalSettlementDisplay.daycareLines(<String, dynamic>{
        'bookingKind': 'daycare',
        'settlementConfirmed': true,
        'quotedTotalPrice': 700,
        'overtimeAmount': 300,
        'extraCharges': <Map<String, dynamic>>[
          <String, dynamic>{'label': '接回逾時費', 'amount': 300},
        ],
      }).where((BookingSettlementDisplayLine e) => e.label == '晚接回超時計費').length,
      1,
    );
    final BookingSettlementDisplayLine manual = lines.firstWhere(
      (BookingSettlementDisplayLine e) => e.label == '手動加收',
    );
    expect(manual.amount, 1000);
    expect(manual.subtitle, contains('加購清潔'));
    expect(
      BookingFinalSettlementDisplay.chargeSum(lines),
      2000,
    );
    expect(
      lines.firstWhere((BookingSettlementDisplayLine e) => e.isTotal).amount,
      2000,
    );
    expect(
      lines.any(
        (BookingSettlementDisplayLine e) =>
            e.isReference && e.label.contains('預約時預估總額'),
      ),
      isTrue,
    );
  });

  test('未結算不把預估尾款當成最終收費', () {
    final List<BookingSettlementDisplayLine> lines =
        BookingFinalSettlementDisplay.daycareLines(<String, dynamic>{
          'bookingKind': 'daycare',
          'quotedTotalPrice': 700,
          'depositAmount': 500,
          'depositStatus': 'confirmed',
          'depositPaid': true,
          'daycarePricingSnapshot': <String, dynamic>{
            'baseAmount': 500,
            'includedMinutes': 120,
            'totalAmount': 700,
          },
        });
    expect(
      lines.any((BookingSettlementDisplayLine e) => e.label == '最終結算應付'),
      isFalse,
    );
    expect(
      lines.any(
        (BookingSettlementDisplayLine e) => e.label == '服務完成後依實際時間結算尾款',
      ),
      isTrue,
    );
  });
}
