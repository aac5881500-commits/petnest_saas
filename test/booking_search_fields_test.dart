// 檔案名稱：test/booking_search_fields_test.dart
// 功能說明：訂單搜尋正規化欄位

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_search_fields.dart';

void main() {
  test('電話後四碼與五碼', () {
    final Map<String, dynamic> fields = BookingSearchFields.fromBooking(
      <String, dynamic>{
        'customerName': '王小明',
        'customerPhone': '0912-345-678',
        'bookingCode': 'SHOP0001-B000009',
        'pets': <Map<String, String>>[
          <String, String>{'name': '奶茶'},
        ],
      },
    );
    expect(fields['customerPhoneLast4'], '5678');
    expect(fields['customerPhoneLast5'], '45678');
    expect(fields['customerNameNormalized'], '王小明');
    expect(fields['petNamesNormalized'], <String>['奶茶']);
    expect(fields['bookingCodeNormalized'], 'shop0001-b000009');
  });
}
