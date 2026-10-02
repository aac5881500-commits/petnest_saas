import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/platform_member_reconciliation_service.dart';

void main() {
  const String shop0002Owner = '7PWzA7ybQy0T9902bKng5czqtWG2';

  Map<String, List<MissingOwnerShop>> shop0002() {
    return <String, List<MissingOwnerShop>>{
      shop0002Owner: <MissingOwnerShop>[
        const MissingOwnerShop(shopId: 'SHOP0002', shopName: '測試店'),
      ],
    };
  }

  test('SHOP0002 is missing when users doc does not exist', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: shop0002(),
          usersById: <String, Map<String, dynamic>?>{shop0002Owner: null},
        );

    expect(scan.isClear, isFalse);
    expect(scan.missing, hasLength(1));
    expect(scan.incomplete, isEmpty);
    expect(scan.missing.single.ownerUid, shop0002Owner);
    expect(scan.missing.single.documentMissing, isTrue);
    expect(scan.missing.single.shops.single.shopId, 'SHOP0002');
  });

  test('SHOP0002 existing without createdAt is incomplete, not all clear', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: shop0002(),
          usersById: <String, Map<String, dynamic>?>{
            shop0002Owner: <String, dynamic>{'email': 'owner@example.com'},
          },
        );

    expect(scan.isClear, isFalse);
    expect(scan.missing, isEmpty);
    expect(scan.incomplete, hasLength(1));
    expect(scan.incomplete.single.ownerUid, shop0002Owner);
    expect(
      scan.incomplete.single.missingFields,
      containsAll(<String>[
        'uid',
        'createdAt',
        'updatedAt',
        'platformStatus',
        'status',
        'displayName',
      ]),
    );
  });

  test('complete users document is not reported', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: shop0002(),
          usersById: <String, Map<String, dynamic>?>{
            shop0002Owner: <String, dynamic>{
              'uid': shop0002Owner,
              'createdAt': DateTime(2024),
              'updatedAt': DateTime(2024, 2),
              'platformStatus': 'active',
              'status': 'active',
              'displayName': '王小明',
              'email': 'owner@example.com',
            },
          },
        );

    expect(scan.isClear, isTrue);
  });

  test('missing email still keeps a missing owner', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: shop0002(),
          usersById: <String, Map<String, dynamic>?>{shop0002Owner: null},
        );

    expect(scan.missing.single.email, isEmpty);
    expect(scan.missing.single.displayName, '店主');
  });

  test('same ownerUid across shops is one issue', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: <String, List<MissingOwnerShop>>{
            shop0002Owner: <MissingOwnerShop>[
              const MissingOwnerShop(shopId: 'SHOP0002', shopName: '甲店'),
              const MissingOwnerShop(shopId: 'SHOP0009', shopName: '乙店'),
            ],
          },
          usersById: <String, Map<String, dynamic>?>{shop0002Owner: null},
          emails: <String, String>{shop0002Owner: 'owner@example.com'},
          displayNames: <String, String>{shop0002Owner: '王小明'},
        );

    expect(scan.missing, hasLength(1));
    expect(
      scan.missing.single.shops.map((MissingOwnerShop shop) => shop.shopId),
      <String>['SHOP0002', 'SHOP0009'],
    );
  });

  test('blank ownerUid is ignored', () {
    final OwnerPlatformMemberScan scan =
        PlatformMemberReconciliationService.assembleOwnerPlatformMemberScan(
          shopsByOwnerUid: <String, List<MissingOwnerShop>>{
            '': <MissingOwnerShop>[
              const MissingOwnerShop(shopId: 'SHOP0001', shopName: '無主店'),
            ],
          },
          usersById: <String, Map<String, dynamic>?>{},
        );

    expect(scan.isClear, isTrue);
  });
}
