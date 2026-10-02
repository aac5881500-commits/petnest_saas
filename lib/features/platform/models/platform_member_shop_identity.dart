// 平台會員的店家身分只在查看時組裝。
// 店主來自 shops.ownerUid，店家角色來自 shop_members.role，不讀 users.role。

import 'package:petnest_saas/core/constants/platform_root_admin.dart';

class PlatformShopRecord {
  const PlatformShopRecord({
    required this.shopId,
    required this.name,
    required this.ownerUid,
    required this.plan,
    required this.status,
  });

  final String shopId;
  final String name;
  final String ownerUid;
  final String plan;
  final String status;
}

class PlatformShopMemberRecord {
  const PlatformShopMemberRecord({
    required this.shopId,
    required this.uid,
    required this.role,
  });

  final String shopId;
  final String uid;
  final String role;
}

class PlatformOwnedShopView {
  const PlatformOwnedShopView({
    required this.shopId,
    required this.name,
    required this.planLabel,
    required this.statusLabel,
  });

  final String shopId;
  final String name;
  final String planLabel;
  final String statusLabel;
}

class PlatformWorkplaceView {
  const PlatformWorkplaceView({
    required this.shopId,
    required this.name,
    required this.roleLabel,
  });

  final String shopId;
  final String name;
  final String roleLabel;
}

class PlatformMemberShopIdentity {
  const PlatformMemberShopIdentity({
    required this.owned,
    required this.workplaces,
    this.unavailable = false,
  });

  final List<PlatformOwnedShopView> owned;
  final List<PlatformWorkplaceView> workplaces;
  final bool unavailable;

  static const PlatformMemberShopIdentity unavailableIdentity =
      PlatformMemberShopIdentity(owned: [], workplaces: [], unavailable: true);

  int get ownedCount => owned.length;

  int get workplaceCount => workplaces.length;
}

String platformShopPlanLabel(String plan) {
  switch (plan.trim()) {
    case 'free':
      return '免費版';
    case 'basic':
      return '基本版';
    case 'pro':
      return '專業版';
    case 'premium':
      return '旗艦版';
    case '':
      return '未設定';
    default:
      return plan.trim();
  }
}

String platformShopStatusLabel(String status) {
  switch (status.trim()) {
    case 'active':
      return '正常';
    case 'suspended':
      return '停權';
    case 'pending':
      return '待審核';
    case '':
      return '未設定';
    default:
      return status.trim();
  }
}

String platformShopRoleLabel(String role) {
  switch (role.trim()) {
    case 'owner':
      return '店主';
    case 'manager':
      return '管理員';
    case 'staff':
      return '員工';
    case '':
      return '員工';
    default:
      return role.trim();
  }
}

/// 平台帳號角色只看平台欄位。users.role 為 user、owner、staff 時仍是一般帳號。
String platformAccountRoleLabel({
  required String uid,
  required Map<String, dynamic> user,
}) {
  if (PlatformRootAdmin.isRoot(uid)) return '平台管理員';
  final String explicit = _firstText(user, const <String>[
    'platformRole',
    'platformAdminRole',
  ]);
  final String role = explicit.isNotEmpty
      ? explicit
      : _firstText(user, const <String>['role']);
  switch (role) {
    case 'platform_staff':
      return '平台員工';
    case 'super_admin':
    case 'developer_admin':
    case 'platform_admin':
      return '平台管理員';
    default:
      return '一般帳號';
  }
}

String platformAccountStatusLabel(String status) {
  switch (status.trim()) {
    case 'blocked':
      return '封鎖';
    case 'restricted':
      return '限制';
    case 'active':
    case '':
      return '正常';
    default:
      return '正常';
  }
}

PlatformMemberShopIdentity assemblePlatformMemberShopIdentity({
  required String uid,
  required List<PlatformShopRecord> shops,
  required List<PlatformShopMemberRecord> members,
  Map<String, String> shopNamesById = const <String, String>{},
}) {
  final String target = uid.trim();
  if (target.isEmpty) {
    return const PlatformMemberShopIdentity(owned: [], workplaces: []);
  }

  final List<PlatformOwnedShopView> owned = <PlatformOwnedShopView>[];
  final Set<String> ownedIds = <String>{};
  for (final PlatformShopRecord shop in shops) {
    if (shop.ownerUid.trim() != target || shop.shopId.trim().isEmpty) continue;
    if (!ownedIds.add(shop.shopId)) continue;
    final String name = shop.name.trim().isEmpty ? '未命名店家' : shop.name.trim();
    owned.add(
      PlatformOwnedShopView(
        shopId: shop.shopId,
        name: name,
        planLabel: platformShopPlanLabel(shop.plan),
        statusLabel: platformShopStatusLabel(shop.status),
      ),
    );
  }

  final List<PlatformWorkplaceView> workplaces = <PlatformWorkplaceView>[];
  final Set<String> workplaceIds = <String>{};
  for (final PlatformShopMemberRecord member in members) {
    if (member.uid.trim() != target || member.shopId.trim().isEmpty) continue;
    if (ownedIds.contains(member.shopId)) continue;
    if (!workplaceIds.add(member.shopId)) continue;
    final String named = (shopNamesById[member.shopId] ?? '').trim();
    workplaces.add(
      PlatformWorkplaceView(
        shopId: member.shopId,
        name: named.isEmpty ? '未命名店家' : named,
        roleLabel: platformShopRoleLabel(member.role),
      ),
    );
  }

  return PlatformMemberShopIdentity(owned: owned, workplaces: workplaces);
}

Map<String, PlatformMemberShopIdentity> indexPlatformMemberShopIdentities({
  required List<PlatformShopRecord> shops,
  required List<PlatformShopMemberRecord> members,
}) {
  final Map<String, String> names = <String, String>{
    for (final PlatformShopRecord shop in shops)
      if (shop.shopId.isNotEmpty) shop.shopId: shop.name,
  };
  final Set<String> uids = <String>{
    for (final PlatformShopRecord shop in shops)
      if (shop.ownerUid.trim().isNotEmpty) shop.ownerUid.trim(),
    for (final PlatformShopMemberRecord member in members)
      if (member.uid.trim().isNotEmpty) member.uid.trim(),
  };
  return <String, PlatformMemberShopIdentity>{
    for (final String uid in uids)
      uid: assemblePlatformMemberShopIdentity(
        uid: uid,
        shops: shops,
        members: members,
        shopNamesById: names,
      ),
  };
}

String _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final String key in keys) {
    final String value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
