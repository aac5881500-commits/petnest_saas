// 檔案名稱：test/booking_payment_labels_test.dart
// 功能說明：結算卡／操作紀錄共用付款中文，不露出代碼

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_payment_labels.dart';

void main() {
  test('付款方式中文化', () {
    expect(BookingPaymentLabels.method('cash'), '店內付款');
    expect(BookingPaymentLabels.method('onsite'), '店內付款');
    expect(BookingPaymentLabels.method('store_payment'), '店內付款');
    expect(BookingPaymentLabels.method('transfer'), '銀行轉帳');
    expect(BookingPaymentLabels.method('bank_transfer'), '銀行轉帳');
    expect(BookingPaymentLabels.method('credit_card'), '信用卡');
    expect(BookingPaymentLabels.method('atm'), 'ATM 虛擬帳號');
    expect(BookingPaymentLabels.method('cvs'), '超商代碼繳費');
    expect(BookingPaymentLabels.method('cvs_code'), '超商代碼繳費');
    expect(BookingPaymentLabels.method('unknown_code'), '其他付款方式');
  });

  test('付款狀態中文化', () {
    expect(BookingPaymentLabels.status('unpaid'), '尚未付款');
    expect(BookingPaymentLabels.status('partial'), '已付部分款項');
    expect(BookingPaymentLabels.status('paid'), '已付清');
    expect(BookingPaymentLabels.status('awaiting_supplement'), '待補款');
    expect(BookingPaymentLabels.status('awaiting_refund'), '待退款');
    expect(BookingPaymentLabels.status('awaiting_proof'), '等待客戶上傳轉帳證明');
    expect(BookingPaymentLabels.status('pending_verification'), '待店家核對');
    expect(BookingPaymentLabels.status('staff_verified_no_image'), '店員現場已核對入帳');
    expect(BookingPaymentLabels.status('selected'), '已選擇付款方式');
    expect(BookingPaymentLabels.status('已選擇方式'), '已選擇付款方式');
    expect(BookingPaymentLabels.status('weird_en'), '付款狀態待確認');
  });
}
