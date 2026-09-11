// 檔案名稱：test/shop_member_kind_test.dart
// 功能說明：會員管理同一套 source 判斷店家會員／手動會員

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/shop_member_kind.dart';

void main() {
  test('source=admin 為手動會員', () {
    expect(
      ShopMemberKind.isManualMember(<String, dynamic>{'source': 'admin'}),
      isTrue,
    );
    expect(
      ShopMemberKind.isShopMember(<String, dynamic>{'source': 'admin'}),
      isFalse,
    );
  });

  test('source=app 或缺欄為店家會員', () {
    expect(
      ShopMemberKind.isShopMember(<String, dynamic>{'source': 'app'}),
      isTrue,
    );
    expect(ShopMemberKind.isShopMember(<String, dynamic>{}), isTrue);
    expect(
      ShopMemberKind.isManualMember(<String, dynamic>{'name': '小明'}),
      isFalse,
    );
  });

  test('尚未寫入的快速建立會員視為手動會員', () {
    expect(
      ShopMemberKind.isManualMember(<String, dynamic>{
        'isTempAdminMember': true,
        'name': '訪客',
      }),
      isTrue,
    );
  });
}
