import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/features/platform/models/platform_member_shop_identity.dart';

void main() {
  const String claireUid = '7PWzA7ybQy0T9902bKng5czqtWG2';

  test('owner identity comes from shops.ownerUid and keeps a second workplace', () {
    final PlatformMemberShopIdentity identity = assemblePlatformMemberShopIdentity(
      uid: claireUid,
      shops: const <PlatformShopRecord>[
        PlatformShopRecord(
          shopId: 'SHOP0002',
          name: 'Claire 的店',
          ownerUid: claireUid,
          plan: 'pro',
          status: 'active',
        ),
      ],
      members: const <PlatformShopMemberRecord>[
        PlatformShopMemberRecord(
          shopId: 'SHOP0002',
          uid: claireUid,
          role: 'owner',
        ),
        PlatformShopMemberRecord(
          shopId: 'SHOP0008',
          uid: claireUid,
          role: 'staff',
        ),
      ],
      shopNamesById: const <String, String>{'SHOP0008': '別間店'},
    );

    expect(identity.owned.map((PlatformOwnedShopView shop) => shop.shopId), [
      'SHOP0002',
    ]);
    expect(identity.owned.single.planLabel, '專業版');
    expect(identity.owned.single.statusLabel, '正常');
    expect(identity.workplaces.map((PlatformWorkplaceView shop) => shop.shopId), [
      'SHOP0008',
    ]);
    expect(identity.workplaces.single.roleLabel, '員工');
    expect(identity.ownedCount, 1);
    expect(identity.workplaceCount, 1);
  });

  test('users.role is not treated as a shop owner or staff role', () {
    expect(
      platformAccountRoleLabel(
        uid: claireUid,
        user: const <String, dynamic>{'role': 'owner'},
      ),
      '一般帳號',
    );
    expect(
      platformAccountRoleLabel(
        uid: claireUid,
        user: const <String, dynamic>{'role': 'user'},
      ),
      '一般帳號',
    );
    expect(
      platformAccountRoleLabel(
        uid: claireUid,
        user: const <String, dynamic>{'platformRole': 'platform_staff'},
      ),
      '平台員工',
    );
    expect(
      platformAccountRoleLabel(
        uid: PlatformRootAdmin.uid,
        user: const <String, dynamic>{'role': 'user'},
      ),
      '平台管理員',
    );
  });

  test('manager role is labeled in Chinese and missing dates stay displayable', () {
    expect(platformShopRoleLabel('manager'), '管理員');
    expect(platformShopRoleLabel('owner'), '店主');
    expect(platformAccountStatusLabel(''), '正常');
  });
}
