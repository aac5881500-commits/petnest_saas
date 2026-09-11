// 檔案名稱：test/member_search_fields_test.dart
// 功能說明：會員姓名前綴與電話後段搜尋欄位

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/member_search_fields.dart';

void main() {
  test('姓名前綴長度可控', () {
    final List<String> prefixes = MemberSearchFields.namePrefixes('王小明');
    expect(prefixes.first, '王');
    expect(prefixes.contains('王小明'), isTrue);
    expect(prefixes.length, 3);
  });

  test('電話後四碼五碼', () {
    final Map<String, dynamic> fields = MemberSearchFields.fromMember(
      name: '王小明',
      phone: '0912345678',
      email: 'A@B.COM',
    );
    expect(fields['phoneLast4'], '5678');
    expect(fields['phoneLast5'], '45678');
    expect(fields['emailNormalized'], 'a@b.com');
  });
}
