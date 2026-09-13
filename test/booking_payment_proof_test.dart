// 檔案名稱：test/booking_payment_proof_test.dart
// 功能說明：付款回傳照片欄位 fallback

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/services/booking_payment_proof_function_service.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';

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
    expect(items.first.purposeLabel, '結算尾款');
    expect(items.last.purposeLabel, '訂金');
  });

  test('相同後五碼摘要只顯示一次，不同後五碼並列', () {
    expect(
      BookingPaymentProof.last5Summary(<String, dynamic>{
        'paymentProofs': <Map<String, dynamic>>[
          <String, dynamic>{
            'proofId': 'a',
            'imageUrl': 'https://a/1.jpg',
            'last5': '55555',
          },
          <String, dynamic>{
            'proofId': 'b',
            'imageUrl': 'https://a/2.jpg',
            'last5': '44444',
          },
          <String, dynamic>{
            'proofId': 'c',
            'imageUrl': 'https://a/3.jpg',
            'last5': '55555',
          },
        ],
      }),
      '55555、44444',
    );
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

  test('舊訂單 legacy 訂金圖與新上傳訂金圖都可顯示', () {
    final List<String> urls = BookingPaymentProof.urls(<String, dynamic>{
      'transferImageUrl': 'https://legacy/deposit.jpg',
      'transferImagePath': 'old/path.jpg',
      'paymentProofs': <Map<String, dynamic>>[
        <String, dynamic>{
          'proofId': 'p_new',
          'imageUrl': 'https://new/deposit.jpg',
          'storagePath': 'booking_images/b1/new.jpg',
          'purpose': 'deposit',
        },
      ],
    });
    expect(urls, <String>[
      'https://new/deposit.jpg',
      'https://legacy/deposit.jpg',
    ]);
    expect(
      BookingPaymentProof.hasImageForPurpose(
        <String, dynamic>{
          'transferImageUrl': 'https://legacy/deposit.jpg',
        },
        'deposit',
      ),
      isTrue,
    );
    expect(
      BookingPaymentProof.hasImageForPurpose(
        <String, dynamic>{
          'paymentProofs': <Map<String, dynamic>>[
            <String, dynamic>{
              'proofId': 'p_new',
              'imageUrl': 'https://new/deposit.jpg',
              'purpose': 'deposit',
            },
          ],
        },
        'deposit',
      ),
      isTrue,
    );
  });

  test('相同 imageUrl、不同 proofId 不可合併', () {
    final List<BookingPaymentProofRecord> items = BookingPaymentProof.records(
      <String, dynamic>{
        'paymentProofs': <Map<String, dynamic>>[
          <String, dynamic>{
            'proofId': 'p1',
            'imageUrl': 'https://same/img.jpg',
            'purpose': 'deposit',
          },
          <String, dynamic>{
            'proofId': 'p2',
            'imageUrl': 'https://same/img.jpg',
            'purpose': 'balance',
          },
        ],
      },
    );
    expect(items.length, 2);
    expect(items.map((BookingPaymentProofRecord e) => e.proofId).toList(),
        <String>['p1', 'p2']);
  });

  test('hasImageForPurpose 只看對應用途的圖片', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'settlementTopUpTransferImageUrl': 'https://legacy/balance.jpg',
      'paymentProofs': <Map<String, dynamic>>[
        <String, dynamic>{
          'proofId': 'b1',
          'imageUrl': 'https://new/balance.jpg',
          'purpose': 'balance',
        },
      ],
    };
    expect(BookingPaymentProof.hasImageForPurpose(data, 'deposit'), isFalse);
    expect(BookingPaymentProof.hasImageForPurpose(data, 'balance'), isTrue);
  });

  test('Function 寫入失敗與照片上傳失敗訊息', () {
    expect(
      BookingPaymentProofFunctionService.writeFailedMessage,
      '照片已上傳，但付款資料寫入失敗，請重新送出付款資料。',
    );
    expect(
      BookingPaymentProofFunctionService.storageFailedMessage,
      '照片上傳失敗，請重試。',
    );
    expect(
      BookingPaymentProofFunctionService.userMessage(Exception('x')),
      '照片上傳失敗，請重試。',
    );
  });

  test('舊訂單有 transferImageUrl 時變更付款方式後 URL 仍存在', () {
    final Map<String, dynamic> booking = <String, dynamic>{
      'transferImageUrl': 'https://legacy/deposit.jpg',
      'transferImagePath': 'old/path.jpg',
      'depositStatus': 'pending_review',
      'paymentMethod': PaymentMethodType.bankTransfer,
      'payAmountType': 'deposit',
    };
    final Map<String, dynamic> patch = BookingPaymentChoicePatch.depositFields(
      payAmountType: 'full',
      paymentMethod: PaymentMethodType.creditCard,
    );
    expect(patch.containsKey('transferImageUrl'), isFalse);
    expect(patch.containsKey('transferImagePath'), isFalse);
    expect(patch.containsKey('paymentProofs'), isFalse);
    final Map<String, dynamic> next = BookingPaymentChoicePatch.applyToBooking(
      booking: booking,
      patch: patch,
    );
    expect(next['transferImageUrl'], 'https://legacy/deposit.jpg');
    expect(next['transferImagePath'], 'old/path.jpg');
    expect(next['depositStatus'], 'unpaid');
    expect(next['paymentMethod'], PaymentMethodType.creditCard);
  });

  test('paymentProofs 在變更付款方式後仍完整存在', () {
    final List<Map<String, dynamic>> proofs = <Map<String, dynamic>>[
      <String, dynamic>{
        'proofId': 'p1',
        'imageUrl': 'https://a/1.jpg',
        'purpose': 'deposit',
      },
      <String, dynamic>{
        'proofId': 'p2',
        'imageUrl': 'https://a/2.jpg',
        'purpose': 'balance',
      },
    ];
    final Map<String, dynamic> next = BookingPaymentChoicePatch.applyToBooking(
      booking: <String, dynamic>{
        'paymentProofs': proofs,
        'transferImageUrl': 'https://legacy/deposit.jpg',
      },
      patch: BookingPaymentChoicePatch.depositFields(
        payAmountType: 'deposit',
        paymentMethod: PaymentMethodType.atm,
      ),
    );
    expect(next['paymentProofs'], proofs);
    expect(
      (next['paymentProofs'] as List<dynamic>).length,
      2,
    );
  });

  test('專案不再有會刪除付款證據 Storage 檔案的客戶端程式', () {
    final String page = File(
      'lib/features/booking/pages/booking_detail_page.dart',
    ).readAsStringSync();
    expect(page.contains('refFromURL'), isFalse);
    expect(page.contains("refFromURL(imageUrl).delete()"), isFalse);
    expect(page.contains('已刪除轉帳截圖'), isFalse);
    expect(page.contains('確定刪除'), isFalse);
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    for (final File file in dartFiles) {
      final String source = file.readAsStringSync();
      if (!source.contains('booking_images') &&
          !source.contains('transferImageUrl')) {
        continue;
      }
      expect(
        source.contains('refFromURL(imageUrl).delete()'),
        isFalse,
        reason: file.path,
      );
      expect(
        source.contains("refFromURL(imageUrl).delete()"),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('專案不再有變更付款方式時清空 transferImageUrl / transferImagePath 的寫入', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    final RegExp wipeUrl = RegExp(
      r"""['"]transferImageUrl['"]\s*:\s*['"]['"]""",
    );
    final RegExp wipePath = RegExp(
      r"""['"]transferImagePath['"]\s*:\s*['"]['"]""",
    );
    final RegExp deleteUrl = RegExp(
      r'''transferImageUrl['"]?\s*:\s*FieldValue\.delete''',
    );
    final RegExp deletePath = RegExp(
      r'''transferImagePath['"]?\s*:\s*FieldValue\.delete''',
    );
    for (final File file in dartFiles) {
      final String source = file.readAsStringSync();
      expect(wipeUrl.hasMatch(source), isFalse, reason: file.path);
      expect(wipePath.hasMatch(source), isFalse, reason: file.path);
      expect(deleteUrl.hasMatch(source), isFalse, reason: file.path);
      expect(deletePath.hasMatch(source), isFalse, reason: file.path);
    }
    for (final String key
        in BookingPaymentChoicePatch.preservedProofKeys) {
      expect(
        BookingPaymentChoicePatch.depositFields(
          payAmountType: 'deposit',
          paymentMethod: PaymentMethodType.creditCard,
        ).containsKey(key),
        isFalse,
      );
      expect(
        BookingPaymentChoicePatch.settlementTopUpFields(
          paymentMethod: PaymentMethodType.creditCard,
        ).containsKey(key),
        isFalse,
      );
    }
  });
}
