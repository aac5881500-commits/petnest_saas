// 檔案名稱：lib/core/services/shop_member_permission_service.dart
// 功能說明：處理店家成員、邀請、權限設定、成員移除
// 🔐 店家成員與權限服務

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/models/shop_staff_identity_snapshot.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';

class ShopMemberPermissionService {
  ShopMemberPermissionService._();
  static final instance = ShopMemberPermissionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _shopMembers =>
      _firestore.collection('shop_members');

  CollectionReference<Map<String, dynamic>> get _shopMemberInvites =>
      _firestore.collection('shop_member_invites');

  String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  Map<String, bool> ownerDefaultPermissions() {
    return {for (final key in ShopPermissionKeys.all) key: true};
  }

  Map<String, bool> managerDefaultPermissions() {
    return {
      ShopPermissionKeys.manageMembers: false,
      ShopPermissionKeys.editBasicInfo: true,
      ShopPermissionKeys.editBusinessInfo: true,
      ShopPermissionKeys.editMedia: true,
      ShopPermissionKeys.manageBookings: true,
      ShopPermissionKeys.manageChat: true,
      ShopPermissionKeys.manageMemberPoints: true,
      ShopPermissionKeys.managePointRedemptions: true,
      ShopPermissionKeys.viewInventory: true,
      ShopPermissionKeys.receiveInventory: true,
      ShopPermissionKeys.viewStoreOrders: true,
      ShopPermissionKeys.manageStoreOrders: true,
      ShopPermissionKeys.viewReports: true,
      ShopPermissionKeys.viewActionLogs: true,
      ShopPermissionKeys.viewDaycareBookings: true,
      ShopPermissionKeys.manageDaycareBookings: true,
      ShopPermissionKeys.manageDaycareSettings: true,
      ShopPermissionKeys.manageDaycarePricing: true,
      ShopPermissionKeys.convertDaycareToAccommodation: true,
      ShopPermissionKeys.adjustDaycarePrice: false,
    };
  }

  Map<String, bool> staffDefaultPermissions() {
    return {
      ShopPermissionKeys.manageMembers: false,
      ShopPermissionKeys.editBasicInfo: false,
      ShopPermissionKeys.editBusinessInfo: false,
      ShopPermissionKeys.editMedia: false,
      ShopPermissionKeys.manageBookings: true,
      ShopPermissionKeys.manageChat: true,
      ShopPermissionKeys.manageMemberPoints: true,

      // 店員預設可以處理會員到店領取實體商品。
      ShopPermissionKeys.managePointRedemptions: true,

      // 店員預設可查看庫存數量，但不能進貨、盤點或看成本。
      ShopPermissionKeys.viewInventory: true,
      ShopPermissionKeys.manageInventory: false,
      ShopPermissionKeys.receiveInventory: false,
      ShopPermissionKeys.adjustInventory: false,
      ShopPermissionKeys.viewInventoryCost: false,

      ShopPermissionKeys.viewStoreOrders: true,
      ShopPermissionKeys.manageStoreProducts: false,
      ShopPermissionKeys.manageStoreOrders: false,
      ShopPermissionKeys.manageStoreSettings: false,

      ShopPermissionKeys.viewReports: false,
      ShopPermissionKeys.viewActionLogs: false,
      ShopPermissionKeys.viewDaycareBookings: true,
      ShopPermissionKeys.manageDaycareBookings: true,
      ShopPermissionKeys.manageDaycareSettings: false,
      ShopPermissionKeys.manageDaycarePricing: false,
      ShopPermissionKeys.convertDaycareToAccommodation: false,
      ShopPermissionKeys.adjustDaycarePrice: false,
    };
  }

  Map<String, bool> defaultPermissionsByRole(String role) {
    switch (role) {
      case ShopRoles.owner:
        return ownerDefaultPermissions();

      case ShopRoles.staff:
      default:
        return staffDefaultPermissions();
    }
  }

  Map<String, bool> normalizePermissions(dynamic value, {String? role}) {
    final base = defaultPermissionsByRole(role ?? ShopRoles.staff);

    if (value is! Map) {
      return base;
    }

    final result = <String, bool>{...base};

    for (final key in ShopPermissionKeys.all) {
      final raw = value[key];
      if (raw is bool) {
        result[key] = raw;
      }
    }

    return result;
  }

  bool hasPermission(Map<String, dynamic>? memberData, String permissionKey) {
    if (memberData == null) return false;

    final role = memberData['role']?.toString();

    if (role == ShopRoles.owner) return true;

    final permissions = normalizePermissions(
      memberData['permissions'],
      role: role,
    );

    return permissions[permissionKey] == true;
  }

  Stream<List<Map<String, dynamic>>> streamShopMembers(String shopId) {
    return _shopMembers.where('shopId', isEqualTo: shopId).snapshots().map((
      snapshot,
    ) {
      final result = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      result.sort((a, b) {
        final aRole = a['role']?.toString() ?? '';
        final bRole = b['role']?.toString() ?? '';
        return aRole.compareTo(bRole);
      });

      return result;
    });
  }

  Stream<List<Map<String, dynamic>>> streamShopMemberInvites(String shopId) {
    return _shopMemberInvites
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  Future<void> upsertMemberPermissionByEmail({
    required String shopId,
    required String email,
    required String role,
    required Map<String, bool> permissions,
    required String operatorUid,
    required String operatorRole,
  }) async {
    final normalizedEmail = normalizeEmail(email);

    if (normalizedEmail.isEmpty) {
      throw Exception('Email 不可為空');
    }

    final existingMembers = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .get();

    for (final doc in existingMembers.docs) {
      final data = doc.data();
      if (data['emailKey'] == normalizedEmail) {
        final oldPermissions = normalizePermissions(
          data['permissions'],
          role: data['role']?.toString(),
        );

        final newPermissions = normalizePermissions(permissions, role: role);

        final changedPermissions = ShopPermissionKeys.all
            .where((key) => oldPermissions[key] != newPermissions[key])
            .map(
              (key) => {
                'key': key,
                'oldValue': oldPermissions[key] ?? false,
                'newValue': newPermissions[key] ?? false,
              },
            )
            .toList();

        await _shopMembers.doc(doc.id).update({
          'role': role,
          'permissions': newPermissions,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await ActionLogService.instance.logAction(
          shopId: shopId,
          targetType: 'shop_member',
          targetId: doc.id,
          action: 'update_member_permission',
          operatorUid: operatorUid,
          operatorRole: operatorRole,
          payload: {
            'memberEmail': data['email'] ?? '',
            'memberRole': role,
            'changedPermissions': changedPermissions,
          },
        );

        return;
      }
    }

    final inviteDocId = '${shopId}_$normalizedEmail';

    await _shopMemberInvites.doc(inviteDocId).set({
      'shopId': shopId,
      'email': normalizedEmail,
      'emailKey': normalizedEmail,
      'role': role,
      'permissions': normalizePermissions(permissions, role: role),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop_member_invite',
      targetId: inviteDocId,
      action: 'create_invite',
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> updateMemberPermission({
    required String memberDocId,
    required String shopId,
    required String role,
    required Map<String, bool> permissions,
    required String operatorUid,
    required String operatorRole,
  }) async {
    final oldDoc = await _shopMembers.doc(memberDocId).get();
    final oldData = oldDoc.data() ?? {};

    final oldPermissions = normalizePermissions(
      oldData['permissions'],
      role: oldData['role']?.toString(),
    );

    final newPermissions = normalizePermissions(permissions, role: role);

    final changedPermissions = ShopPermissionKeys.all
        .where((key) => oldPermissions[key] != newPermissions[key])
        .map(
          (key) => {
            'key': key,
            'oldValue': oldPermissions[key] ?? false,
            'newValue': newPermissions[key] ?? false,
          },
        )
        .toList();

    await _shopMembers.doc(memberDocId).update({
      'role': role,
      'permissions': newPermissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop_member',
      targetId: memberDocId,
      action: 'update_member_permission',
      operatorUid: operatorUid,
      operatorRole: operatorRole,
      payload: {
        'memberEmail': oldData['email'] ?? '',
        'memberRole': role,
        'changedPermissions': changedPermissions,
      },
    );
  }

  Future<void> removeMember({
    required String memberDocId,
    required String shopId,
    required String operatorUid,
    required String operatorRole,
  }) async {
    final doc = await _shopMembers.doc(memberDocId).get();

    if (!doc.exists) {
      throw Exception('找不到成員');
    }

    final data = doc.data() as Map<String, dynamic>;
    final role = data['role']?.toString();

    if (role == 'owner') {
      throw Exception('不可刪除老闆');
    }

    await _shopMembers.doc(memberDocId).delete();

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop_member',
      targetId: memberDocId,
      action: 'remove_member',
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> removeMemberInvite({
    required String inviteDocId,
    required String shopId,
    required String operatorUid,
    required String operatorRole,
  }) async {
    await _shopMemberInvites.doc(inviteDocId).delete();

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop_member_invite',
      targetId: inviteDocId,
      action: 'delete_member_invite',
      operatorUid: operatorUid,
      operatorRole: operatorRole,
    );
  }

  Future<void> syncPendingInvitesForCurrentUser() async {
    final user = _currentUser;
    if (user == null) return;

    final email = normalizeEmail(user.email ?? '');

    final invites = await _shopMemberInvites
        .where('emailKey', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final inviteDoc in invites.docs) {
      final invite = inviteDoc.data();
      final shopId = invite['shopId'];

      final memberDocId = '${shopId}_${user.uid}';

      await _shopMembers.doc(memberDocId).set({
        'shopId': shopId,
        'uid': user.uid,
        'email': email,
        'emailKey': email,
        'role': invite['role'],
        'permissions': normalizePermissions(
          invite['permissions'],
          role: invite['role'],
        ),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await inviteDoc.reference.update({'status': 'accepted'});

      await ActionLogService.instance.logAction(
        shopId: shopId,
        targetType: 'shop_member',
        targetId: memberDocId,
        action: 'invite_accepted',
        operatorUid: user.uid,
        operatorRole: invite['role'],
      );
    }
  }

  Future<Map<String, dynamic>?> getUserMemberInShop({
    required String shopId,
    required String uid,
  }) async {
    if (shopId.isEmpty || uid.isEmpty) return null;

    final DocumentSnapshot<Map<String, dynamic>> canonical = await _shopMembers
        .doc(ShopOwnerIdentity.memberDocId(shopId, uid))
        .get();
    if (canonical.exists) {
      return {'id': canonical.id, ...?canonical.data()};
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .where('uid', isEqualTo: uid)
        .limit(5)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  Future<ShopStaffIdentitySnapshot> inspectShopIdentity({
    required String shopId,
    String bookingShopId = '',
    bool settlementLocked = false,
  }) async {
    final String uid = _currentUser?.uid ?? '';
    final DocumentSnapshot<Map<String, dynamic>> shopSnap = await _firestore
        .collection('shops')
        .doc(shopId)
        .get();
    final Map<String, dynamic> shop = shopSnap.data() ?? <String, dynamic>{};
    final String ownerUid = (shop['ownerUid'] ?? '').toString();
    final String previousOwnerUid = (shop['previousOwnerUid'] ?? '').toString();
    bool canonicalExists = false;
    String canonicalRole = '';
    List<String> fieldMemberDocIds = const <String>[];
    if (uid.isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> canonical =
          await _shopMembers
              .doc(ShopOwnerIdentity.memberDocId(shopId, uid))
              .get();
      canonicalExists = canonical.exists;
      canonicalRole = (canonical.data()?['role'] ?? '').toString();
      final QuerySnapshot<Map<String, dynamic>> fieldMembers =
          await _shopMembers
              .where('shopId', isEqualTo: shopId)
              .where('uid', isEqualTo: uid)
              .limit(10)
              .get();
      fieldMemberDocIds = fieldMembers.docs.map((d) => d.id).toList();
    }

    return ShopStaffIdentitySnapshot(
      currentUid: uid,
      shopId: shopId,
      bookingShopId: bookingShopId.isEmpty ? shopId : bookingShopId,
      ownerUid: ownerUid,
      isRoot: PlatformRootAdmin.isRoot(uid),
      canonicalMemberExists: canonicalExists,
      canonicalMemberRole: canonicalRole,
      fieldMemberDocIds: fieldMemberDocIds,
      settlementLocked: settlementLocked,
      previousOwnerUid: previousOwnerUid,
    );
  }

  /// 目前登入者若已是 shops.ownerUid，補齊規則路徑 shop_members/{shopId}_{uid}。
  Future<void> syncOwnerMembershipForCurrentUser() async {
    final User? user = _currentUser;
    if (user == null) return;

    final QuerySnapshot<Map<String, dynamic>> owned = await _firestore
        .collection('shops')
        .where('ownerUid', isEqualTo: user.uid)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> shop in owned.docs) {
      await ensureCanonicalOwnerMember(
        shopId: shop.id,
        ownerUid: user.uid,
        email: user.email ?? '',
      );
    }
  }

  Future<void> syncOwnerMembershipForShop(String shopId) async {
    final User? user = _currentUser;
    if (user == null || shopId.trim().isEmpty) return;
    final DocumentSnapshot<Map<String, dynamic>> shopSnap = await _firestore
        .collection('shops')
        .doc(shopId)
        .get();
    final String ownerUid = (shopSnap.data()?['ownerUid'] ?? '').toString();
    if (ownerUid != user.uid) return;
    await ensureCanonicalOwnerMember(
      shopId: shopId,
      ownerUid: user.uid,
      email: user.email ?? '',
    );
  }

  Future<void> ensureCanonicalOwnerMember({
    required String shopId,
    required String ownerUid,
    required String email,
  }) async {
    final String canonicalId = ShopOwnerIdentity.memberDocId(shopId, ownerUid);
    final QuerySnapshot<Map<String, dynamic>> existing = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .get();
    final List<Map<String, dynamic>> members = existing.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();

    Map<String, dynamic> seed = <String, dynamic>{};
    for (final Map<String, dynamic> member in members) {
      if ((member['uid'] ?? '').toString() == ownerUid) {
        seed = member;
        break;
      }
    }

    final String emailKey = normalizeEmail(
      email.isNotEmpty ? email : (seed['email'] ?? '').toString(),
    );
    final Map<String, bool> permissions = normalizePermissions(
      seed['permissions'],
      role: ShopRoles.owner,
    );

    await _shopMembers.doc(canonicalId).set({
      'shopId': shopId,
      'uid': ownerUid,
      'email': emailKey,
      'emailKey': emailKey,
      'role': ShopRoles.owner,
      'permissions': permissions,
      'status': 'active',
      'createdAt': seed['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final String duplicateId in ShopOwnerIdentity.duplicateMemberDocIds(
      shopId: shopId,
      uid: ownerUid,
      members: members,
    )) {
      await _shopMembers.doc(duplicateId).delete();
    }
  }

  /// 平台根管理員轉移唯一店主：更新 ownerUid，並把其他 owner 降為 staff。
  Future<void> transferShopOwner({
    required String shopId,
    required String newOwnerUid,
  }) async {
    final User? operator = _currentUser;
    if (!PlatformRootAdmin.isRoot(operator?.uid)) {
      throw Exception('只有平台最高管理員可以轉移店主');
    }
    final String nextUid = newOwnerUid.trim();
    if (shopId.trim().isEmpty || nextUid.isEmpty) {
      throw Exception('店家與新店主 UID 不可為空');
    }

    final DocumentReference<Map<String, dynamic>> shopRef = _firestore
        .collection('shops')
        .doc(shopId);
    final DocumentSnapshot<Map<String, dynamic>> shopSnap = await shopRef.get();
    if (!shopSnap.exists) {
      throw Exception('找不到店家');
    }
    final Map<String, dynamic> shop = shopSnap.data() ?? <String, dynamic>{};
    final String previousUid = (shop['ownerUid'] ?? '').toString();

    final DocumentSnapshot<Map<String, dynamic>> userSnap = await _firestore
        .collection('users')
        .doc(nextUid)
        .get();
    final String email = (userSnap.data()?['email'] ?? '').toString();

    await ensureCanonicalOwnerMember(
      shopId: shopId,
      ownerUid: nextUid,
      email: email,
    );

    await shopRef.set({
      'ownerUid': nextUid,
      'previousOwnerUid': previousUid == nextUid
          ? (shop['previousOwnerUid'] ?? '')
          : previousUid,
      'ownerTransferredAt': FieldValue.serverTimestamp(),
      'ownerTransferredBy': operator!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final QuerySnapshot<Map<String, dynamic>> members = await _shopMembers
        .where('shopId', isEqualTo: shopId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in members.docs) {
      final Map<String, dynamic> data = doc.data();
      final String uid = (data['uid'] ?? '').toString();
      final String role = (data['role'] ?? '').toString();
      if (uid == nextUid || role != ShopRoles.owner) continue;
      await doc.reference.update({
        'role': ShopRoles.staff,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await ActionLogService.instance.logAction(
      shopId: shopId,
      targetType: 'shop',
      targetId: shopId,
      action: 'transfer_shop_owner',
      operatorUid: operator.uid,
      operatorRole: 'root',
      payload: {'previousOwnerUid': previousUid, 'newOwnerUid': nextUid},
    );
  }
}
