// 檔案名稱：test/booking_payment_proof_test.dart
// 功能說明：付款回傳照片欄位 fallback

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';

void main() {
  test('相容 transferImageUrl 與舊欄位', () {
    expect(
      BookingPaymentProof.urls(<String, dynamic>{
        'transferImageUrl': 'https://a/img.jpg',
        'paymentProofUrl': 'https://a/img.jpg',
        'depositImageUrl': 'https://b/old.jpg',
      }),
      <String>['https://a/img.jpg', 'https://b/old.jpg'],
    );
    expect(BookingPaymentProof.urls(<String, dynamic>{}), isEmpty);
  });

  test('paymentProofs 與 legacy 單張並存且不覆蓋', () {
    final List<BookingPaymentProofRecord> items = BookingPaymentProof.records(
      <String, dynamic>{
        'transferImageUrl': 'https://a/old.jpg',
        'transferLast5': '11111',
        'depositAmount': 500,
        'paymentProofs': <Map<String, dynamic>>[
          <String, dynamic>{
            'proofId': 'p2',
            'imageUrl': 'https://b/new.jpg',
            'purpose': 'top_up',
            'amount': 300,
            'last5': '22222',
          },
        ],
      },
    );
    expect(items.map((BookingPaymentProofRecord e) => e.imageUrl).toList(),
        <String>['https://b/new.jpg', 'https://a/old.jpg']);
    expect(items.first.purposeLabel, '補款');
    expect(items.last.purposeLabel, '訂金');
  });

  test('只有銀行轉帳才顯示付款回傳照片按鈕', () {
    expect(
      BookingPaymentProof.shouldShow(<String, dynamic>{
        'paymentMethod': 'transfer',
      }),
      isTrue,
    );
    expect(
      BookingPaymentProof.shouldShow(<String, dynamic>{
        'paymentMethod': 'credit_card',
      }),
      isFalse,
    );
    expect(
      BookingPaymentProof.shouldShow(<String, dynamic>{'paymentMethod': 'atm'}),
      isFalse,
    );
    expect(
      BookingPaymentProof.shouldShow(<String, dynamic>{'paymentMethod': ''}),
      isFalse,
    );
  });
}
