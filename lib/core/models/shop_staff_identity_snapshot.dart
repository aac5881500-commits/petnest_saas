// 檔案名稱：lib/core/models/shop_staff_identity_snapshot.dart
// 功能說明：店主／店員 Firestore 身分對照（規則實際檢查的路徑）

class ShopStaffIdentitySnapshot {
  const ShopStaffIdentitySnapshot({
    required this.currentUid,
    required this.shopId,
    required this.bookingShopId,
    required this.ownerUid,
    required this.isRoot,
    required this.canonicalMemberExists,
    required this.canonicalMemberRole,
    required this.fieldMemberDocIds,
    required this.settlementLocked,
    required this.previousOwnerUid,
  });

  final String currentUid;
  final String shopId;
  final String bookingShopId;
  final String ownerUid;
  final bool isRoot;
  final bool canonicalMemberExists;
  final String canonicalMemberRole;
  final List<String> fieldMemberDocIds;
  final bool settlementLocked;
  final String previousOwnerUid;

  String get canonicalMemberId {
    if (shopId.isEmpty || currentUid.isEmpty) return '';
    return '${shopId}_$currentUid';
  }

  bool get isOwnerUidMatch =>
      currentUid.isNotEmpty && ownerUid.isNotEmpty && currentUid == ownerUid;

  bool get isCanonicalMember => canonicalMemberExists;

  bool get rulesWouldAllowShopStaffUpdate {
    if (settlementLocked) return false;
    return isRoot || isCanonicalMember || isOwnerUidMatch;
  }
}

class ShopOwnerIdentity {
  ShopOwnerIdentity._();

  static String memberDocId(String shopId, String uid) {
    return '${shopId.trim()}_${uid.trim()}';
  }

  static List<String> extraOwnerDocIds({
    required String newOwnerUid,
    required Iterable<Map<String, dynamic>> members,
  }) {
    final String keep = newOwnerUid.trim();
    final List<String> ids = <String>[];
    for (final Map<String, dynamic> member in members) {
      final String role = (member['role'] ?? '').toString();
      final String uid = (member['uid'] ?? '').toString();
      final String id = (member['id'] ?? '').toString();
      if (role != 'owner') continue;
      if (uid == keep) continue;
      if (id.isEmpty) continue;
      ids.add(id);
    }
    return ids;
  }

  static List<String> duplicateMemberDocIds({
    required String shopId,
    required String uid,
    required Iterable<Map<String, dynamic>> members,
  }) {
    final String canonical = memberDocId(shopId, uid);
    final List<String> ids = <String>[];
    for (final Map<String, dynamic> member in members) {
      final String memberUid = (member['uid'] ?? '').toString();
      final String memberShopId = (member['shopId'] ?? '').toString();
      final String id = (member['id'] ?? '').toString();
      if (memberUid != uid || memberShopId != shopId) continue;
      if (id.isEmpty || id == canonical) continue;
      ids.add(id);
    }
    return ids;
  }

  static String debugText(ShopStaffIdentitySnapshot snapshot) {
    return <String>[
      'SHOP_IDENTITY currentUid=${snapshot.currentUid}',
      'SHOP_IDENTITY booking.shopId=${snapshot.bookingShopId}',
      'SHOP_IDENTITY inspect.shopId=${snapshot.shopId}',
      'SHOP_IDENTITY isRoot=${snapshot.isRoot}',
      'SHOP_IDENTITY isShopMembersMember=${snapshot.isCanonicalMember} '
          'doc=${snapshot.canonicalMemberId} role=${snapshot.canonicalMemberRole}',
      'SHOP_IDENTITY equalsOwnerUid=${snapshot.isOwnerUidMatch} '
          'shops.ownerUid=${snapshot.ownerUid}',
      'SHOP_IDENTITY previousOwnerUid=${snapshot.previousOwnerUid}',
      'SHOP_IDENTITY fieldMemberDocIds=${snapshot.fieldMemberDocIds.join(',')}',
      'SHOP_IDENTITY settlementLocked=${snapshot.settlementLocked}',
      'SHOP_IDENTITY rulesWouldAllow=${snapshot.rulesWouldAllowShopStaffUpdate}',
      if (!snapshot.rulesWouldAllowShopStaffUpdate && snapshot.isRoot)
        'SHOP_IDENTITY hint=root仍非店主：請到平台店家管理→轉移店主→暫時轉給我',
      if (!snapshot.rulesWouldAllowShopStaffUpdate &&
          !snapshot.isRoot &&
          !snapshot.isOwnerUidMatch)
        'SHOP_IDENTITY hint=目前UID不是shops.ownerUid，也沒有正規shop_members文件',
    ].join('\n');
  }
}
