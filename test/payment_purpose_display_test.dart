// 檔案名稱：test/payment_purpose_display_test.dart
// 功能說明：付款用途顯示兼容訂金／全額／結算尾款與失效狀態

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

void main() {
  test('amountType deposit 即使 purpose 寫錯也顯示訂金', () {
    expect(
      PaymentPurpose.displayLabel('full', amountType: 'deposit'),
      '訂金',
    );
    expect(PaymentPurpose.displayLabel('deposit'), '訂金');
  });

  test('一次付清才顯示全額付款', () {
    expect(PaymentPurpose.displayLabel('full'), '全額付款');
  });

  test('結算尾款包含 balance 與舊 additional', () {
    expect(PaymentPurpose.displayLabel('balance'), '結算尾款');
    expect(PaymentPurpose.displayLabel('additional'), '結算尾款');
  });

  test('失效狀態顯示結算金額已更新', () {
    expect(
      BookingDetailViewData.paymentRecordStatusLabel(
        PaymentTransactionStatus.superseded,
      ),
      '已失效（結算金額已更新）',
    );
  });
}
