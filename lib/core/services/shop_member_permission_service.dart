// lib/core/services/shop_member_permission_service.dart
// 🔐 店家成員與權限服務
// 功能：處理店家成員、邀請、權限設定、成員移除

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
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
}
