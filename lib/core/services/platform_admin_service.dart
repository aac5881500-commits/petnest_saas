// 檔案名稱：lib/core/services/platform_admin_service.dart
// 功能說明：讀取平台管理員資料、判斷最高權限與個別權限
// 👑 平台管理員與權限 Service
// 並提供平台員工清單及權限更新功能。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/platform_permission_keys.dart';
import '../constants/platform_root_admin.dart';
import '../models/platform_admin_model.dart';

class PlatformAdminService {
  PlatformAdminService._();

  static final PlatformAdminService instance = PlatformAdminService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-east1',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _adminsReference {
    return _firestore.collection('platform_users');
  }

  /// 目前登入使用者 UID
  String? get currentUserId => _auth.currentUser?.uid;

  /// 讀取指定平台管理員
  Future<PlatformAdminModel?> getAdmin(String uid) async {
    final snapshot = await _adminsReference.doc(uid).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    final data = Map<String, dynamic>.from(snapshot.data()!);

    data['uid'] = snapshot.id;

    return PlatformAdminModel.fromMap(data);
  }

  /// 讀取目前登入者的平台管理員資料
  Future<PlatformAdminModel?> getCurrentAdmin() async {
    final uid = currentUserId;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return getAdmin(uid);
  }

  /// 即時監聽目前登入者的平台權限
  Stream<PlatformAdminModel?> streamCurrentAdmin() {
    final uid = currentUserId;

    if (uid == null || uid.isEmpty) {
      return Stream<PlatformAdminModel?>.value(null);
    }

    return _adminsReference.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);

      data['uid'] = snapshot.id;

      return PlatformAdminModel.fromMap(data);
    });
  }

  /// 是否為已啟用的平台管理員
  Future<bool> isPlatformAdmin() async {
    final uid = currentUserId;

    if (PlatformRootAdmin.isRoot(uid)) {
      return true;
    }

    final admin = await getCurrentAdmin();

    return admin != null && admin.enabled;
  }

  /// 是否為平台最高管理員
  Future<bool> isSuperAdmin() async {
    final uid = currentUserId;

    if (PlatformRootAdmin.isRoot(uid)) {
      return true;
    }

    final admin = await getCurrentAdmin();

    if (admin == null || !admin.enabled) {
      return false;
    }

    return admin.role == PlatformAdminRoles.superAdmin ||
        admin.permissions.contains(PlatformPermissionKeys.all);
  }

  /// 判斷目前登入者是否擁有指定權限
  Future<bool> hasPermission(String permission) async {
    final uid = currentUserId;

    if (PlatformRootAdmin.isRoot(uid)) {
      return true;
    }

    final admin = await getCurrentAdmin();

    return adminHasPermission(admin, permission);
  }

  /// 使用已讀取的管理員資料判斷權限
  ///
  /// 畫面已經透過 StreamBuilder 或 FutureBuilder 取得資料時，
  /// 可以直接使用這個方法，避免重複讀取 Firestore。
  bool adminHasPermission(PlatformAdminModel? admin, String permission) {
    if (PlatformRootAdmin.isRoot(admin?.uid)) {
      return true;
    }

    if (admin == null || !admin.enabled) {
      return false;
    }

    if (admin.role == PlatformAdminRoles.superAdmin) {
      return true;
    }

    if (admin.permissions.contains(PlatformPermissionKeys.all)) {
      return true;
    }

    return admin.permissions.contains(permission);
  }

  /// 監聽全部平台管理員與平台員工
  Stream<List<PlatformAdminModel>> streamAdmins() {
    return _adminsReference
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            final data = Map<String, dynamic>.from(document.data());

            data['uid'] = document.id;

            return PlatformAdminModel.fromMap(data);
          }).toList();
        });
  }

  /// 使用 Email 新增平台人員
  ///
  /// 後端會透過 Firebase Authentication 查詢 Email 對應 UID，
  /// 再建立 platform_users/{uid}。
  Future<void> createAdminByEmail({
    required String email,
    required String name,
    required String role,
    required bool enabled,
    required List<String> permissions,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Email 不能為空');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('姓名或稱呼不能為空');
    }

    if (!PlatformAdminRoles.values.contains(role)) {
      throw ArgumentError('無效的平台人員角色：$role');
    }

    if (role == PlatformAdminRoles.superAdmin) {
      throw StateError('不能透過新增頁建立平台最高管理員');
    }

    final sanitizedPermissions = permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet()
        .toList();

    try {
      final callable = _functions.httpsCallable('createPlatformUserByEmail');

      await callable.call(<String, dynamic>{
        'email': normalizedEmail,
        'name': normalizedName,
        'role': role,
        'enabled': enabled,
        'permissions': sanitizedPermissions,
      });
    } on FirebaseFunctionsException catch (error) {
      final message = error.message?.trim();

      if (message != null && message.isNotEmpty) {
        throw StateError(message);
      }

      throw StateError('新增平台人員失敗，請稍後再試');
    }
  }

  /// 新增平台人員
  ///
  /// 僅用於第一次建立 platform_users 文件。
  /// 如果指定 UID 已存在，會直接阻止，避免覆蓋既有人員資料。
  Future<void> createAdmin({
    required String uid,
    required String name,
    required String email,
    required String role,
    required bool enabled,
    required List<String> permissions,
  }) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    final normalizedUid = uid.trim();
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError('Firebase UID 不能為空');
    }

    if (PlatformRootAdmin.isRoot(normalizedUid)) {
      throw StateError('此 UID 已是永久根管理員，不需要再次新增');
    }

    if (role == PlatformAdminRoles.superAdmin) {
      throw StateError('新增頁不能建立平台最高管理員');
    }

    if (!PlatformAdminRoles.values.contains(role)) {
      throw ArgumentError('無效的平台管理員角色：$role');
    }

    final documentReference = _adminsReference.doc(normalizedUid);
    final existingSnapshot = await documentReference.get();

    if (existingSnapshot.exists) {
      throw StateError('此 UID 已經是平台人員，請改至編輯頁修改');
    }

    final sanitizedPermissions = permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet()
        .toList();

    await documentReference.set({
      'uid': normalizedUid,
      'name': normalizedName,
      'email': normalizedEmail,
      'role': role,
      'enabled': enabled,
      'permissions': sanitizedPermissions,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': operatorUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': operatorUid,
    });
  }

  /// 建立或更新平台管理員資料
  ///
  /// 後續會透過 Firestore Rules 限制：
  /// 只有最高管理員或具有管理平台人員權限者才可以操作。
  Future<void> saveAdmin({
    required String uid,
    required String name,
    required String email,
    required String role,
    required bool enabled,
    required List<String> permissions,
  }) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    final targetIsRootAdmin = PlatformRootAdmin.isRoot(uid);

    if (targetIsRootAdmin) {
      if (role != PlatformAdminRoles.superAdmin) {
        throw StateError('根管理員不能被降級');
      }

      if (!enabled) {
        throw StateError('根管理員不能被停用');
      }
    }

    if (!PlatformAdminRoles.values.contains(role)) {
      throw ArgumentError('無效的平台管理員角色：$role');
    }

    final sanitizedPermissions = permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet()
        .toList();

    final existingSnapshot = await _adminsReference.doc(uid).get();

    final data = <String, dynamic>{
      'uid': uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'enabled': enabled,
      'permissions': targetIsRootAdmin || role == PlatformAdminRoles.superAdmin
          ? <String>[PlatformPermissionKeys.all]
          : sanitizedPermissions,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': operatorUid,
    };

    if (!existingSnapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = operatorUid;
    }

    await _adminsReference.doc(uid).set(data, SetOptions(merge: true));
  }

  /// 更新平台人員基本資料
  ///
  /// 更新姓名與 Email，不修改角色、啟用狀態及權限。
  Future<void> updateBasicInfo({
    required String uid,
    required String name,
    required String email,
  }) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    final normalizedUid = uid.trim();
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();

    if (normalizedUid.isEmpty) {
      throw ArgumentError('平台人員 UID 不能為空');
    }

    if (PlatformRootAdmin.isRoot(normalizedUid)) {
      throw StateError('不能修改永久根管理員的基本資料');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('姓名或稱呼不能為空');
    }

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Email 不能為空');
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(normalizedEmail)) {
      throw ArgumentError('Email 格式不正確');
    }

    final targetAdmin = await getAdmin(normalizedUid);

    if (targetAdmin == null) {
      throw StateError('找不到平台人員資料');
    }

    await _adminsReference.doc(normalizedUid).update({
      'name': normalizedName,
      'email': normalizedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': operatorUid,
    });
  }

  /// 更新平台管理員是否啟用
  Future<void> updateEnabled({
    required String uid,
    required bool enabled,
  }) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    final targetAdmin = await getAdmin(uid);

    if (targetAdmin == null) {
      throw StateError('找不到平台管理員資料');
    }

    if (PlatformRootAdmin.isRoot(uid)) {
      throw StateError('不能停用根管理員');
    }

    if (targetAdmin.role == PlatformAdminRoles.superAdmin) {
      throw StateError('不能停用平台最高管理員');
    }

    await _adminsReference.doc(uid).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': operatorUid,
    });
  }

  /// 更新平台員工的角色與權限
  Future<void> updateRoleAndPermissions({
    required String uid,
    required String role,
    required List<String> permissions,
  }) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    if (PlatformRootAdmin.isRoot(uid)) {
      throw StateError('不能修改根管理員的角色與權限');
    }

    if (role == PlatformAdminRoles.superAdmin) {
      throw StateError('不能透過一般權限畫面授予最高管理員角色');
    }

    if (!PlatformAdminRoles.values.contains(role)) {
      throw ArgumentError('無效的平台管理員角色：$role');
    }

    final sanitizedPermissions = permissions
        .where(PlatformPermissionKeys.assignableValues.contains)
        .toSet()
        .toList();

    await _adminsReference.doc(uid).update({
      'role': role,
      'permissions': sanitizedPermissions,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': operatorUid,
    });
  }

  /// 刪除平台員工資料
  ///
  /// 這只會移除 platform_admins 權限資料，
  /// 不會刪除 Firebase Authentication 帳號。
  Future<void> removeAdmin(String uid) async {
    final operatorUid = currentUserId;

    if (operatorUid == null || operatorUid.isEmpty) {
      throw StateError('目前沒有登入使用者');
    }

    final targetAdmin = await getAdmin(uid);

    if (PlatformRootAdmin.isRoot(uid)) {
      throw StateError('不能刪除根管理員');
    }

    if (targetAdmin == null) {
      return;
    }

    if (targetAdmin.role == PlatformAdminRoles.superAdmin) {
      throw StateError('不能刪除平台最高管理員');
    }

    await _adminsReference.doc(uid).delete();
  }
}
