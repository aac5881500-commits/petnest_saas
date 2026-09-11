// 檔案名稱：test/shop_owner_identity_test.dart
// 功能說明：店主文件 ID、多餘 owner 降級、debug 對照文字

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/shop_staff_identity_snapshot.dart';

void main() {
  test('規則路徑是 shop_members/{shopId}_{uid}', () {
    expect(
      ShopOwnerIdentity.memberDocId('SHOP0001', 'uid-a'),
      'SHOP0001_uid-a',
    );
  });

  test('轉移後只保留新店主為 owner', () {
    expect(
      ShopOwnerIdentity.extraOwnerDocIds(
        newOwnerUid: 'uid-new',
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'SHOP0001_uid-old',
            'uid': 'uid-old',
            'role': 'owner',
          },
          <String, dynamic>{
            'id': 'SHOP0001_uid-new',
            'uid': 'uid-new',
            'role': 'owner',
          },
          <String, dynamic>{
            'id': 'SHOP0001_staff',
            'uid': 'staff',
            'role': 'staff',
          },
        ],
      ),
      <String>['SHOP0001_uid-old'],
    );
  });

  test('同一 uid 的非正規文件視為重複', () {
    expect(
      ShopOwnerIdentity.duplicateMemberDocIds(
        shopId: 'SHOP0001',
        uid: 'uid-a',
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'random-id',
            'shopId': 'SHOP0001',
            'uid': 'uid-a',
          },
          <String, dynamic>{
            'id': 'SHOP0001_uid-a',
            'shopId': 'SHOP0001',
            'uid': 'uid-a',
          },
        ],
      ),
      <String>['random-id'],
    );
  });

  test('debug 文字含 UID、shopId、root、member、ownerUid', () {
    const ShopStaffIdentitySnapshot snapshot = ShopStaffIdentitySnapshot(
      currentUid: 'uid-now',
      shopId: 'SHOP0001',
      bookingShopId: 'SHOP0001',
      ownerUid: 'uid-sister',
      isRoot: false,
      canonicalMemberExists: false,
      canonicalMemberRole: '',
      fieldMemberDocIds: <String>['wrong-id'],
      settlementLocked: false,
      previousOwnerUid: 'uid-sister',
    );
    final String text = ShopOwnerIdentity.debugText(snapshot);
    expect(text, contains('currentUid=uid-now'));
    expect(text, contains('booking.shopId=SHOP0001'));
    expect(text, contains('isRoot=false'));
    expect(text, contains('isShopMembersMember=false'));
    expect(text, contains('equalsOwnerUid=false'));
    expect(text, contains('shops.ownerUid=uid-sister'));
    expect(snapshot.rulesWouldAllowShopStaffUpdate, isFalse);
  });
}
