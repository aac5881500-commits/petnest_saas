// 檔案名稱：test/storage_platform_media_rules_test.dart
// 功能說明：驗證平台外觀圖庫 Storage 規則與平台後台 platform_users 權限來源一致。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/constants/platform_permission_keys.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/models/platform_admin_model.dart';

class PlatformMediaStorageAccess {
  const PlatformMediaStorageAccess({
    this.authUid,
    this.platformUser,
    this.contentType = 'image/jpeg',
    this.sizeBytes = 1024,
  });

  static const String rootUid = PlatformRootAdmin.uid;
  static const int maxBytes = 5 * 1024 * 1024;

  final String? authUid;
  final PlatformAdminModel? platformUser;
  final String contentType;
  final int sizeBytes;

  bool get signedIn => authUid != null && authUid!.isNotEmpty;

  bool get isRootAdmin => signedIn && authUid == rootUid;

  bool get isValidLibraryImage {
    final String type = contentType.toLowerCase();
    return type.startsWith('image/jpeg') ||
        type.startsWith('image/jpg') ||
        type.startsWith('image/png') ||
        type.startsWith('image/webp');
  }

  bool get isUnder5Mb => sizeBytes <= maxBytes;

  bool get canManagePlatformMedia {
    if (isRootAdmin) {
      return true;
    }
    if (!signedIn || platformUser == null || !platformUser!.enabled) {
      return false;
    }
    if (platformUser!.role == 'super_admin') {
      return true;
    }
    if (platformUser!.permissions.contains(PlatformPermissionKeys.all)) {
      return true;
    }
    return platformUser!.permissions.contains(
      PlatformPermissionKeys.managePlatformMedia,
    );
  }

  bool canWriteLibraryObject() {
    return canManagePlatformMedia && isValidLibraryImage && isUnder5Mb;
  }
}

void main() {
  late String rules;

  setUpAll(() {
    rules = File('storage.rules').readAsStringSync();
  });

  test('規則讀取 platform_users，不讀 platform_admins / user_profiles', () {
    expect(rules.contains('platform_users'), isTrue);
    expect(
      rules.contains('match /platform/media_library/{assetId}/{fileName}'),
      isTrue,
    );
    expect(rules.contains('manage_platform_media'), isTrue);
    expect(rules.contains("data.role == 'super_admin'"), isTrue);
    expect(rules.contains("hasAny(['all', 'manage_platform_media'])"), isTrue);
    expect(rules.contains('permissions is list'), isFalse);
    expect(rules.contains('/platform_admins/'), isFalse);
    expect(
      rules.contains('documents/user_profiles/\$(request.auth.uid)'),
      isFalse,
    );
  });

  test('圖庫寫入限制 JPG/PNG/WEBP 且 5MB，不可寫到其他路徑', () {
    final int begin = rules.indexOf(
      'match /platform/media_library/{assetId}/{fileName}',
    );
    final int end = rules.indexOf('match /{allPaths=**}', begin);
    final String block = rules.substring(begin, end);
    expect(block.contains('isPlatformLibraryImage()'), isTrue);
    expect(block.contains('isUnder5MB()'), isTrue);
    expect(block.contains('canManagePlatformMedia()'), isTrue);
    expect(block.contains('allow write: if signedIn()'), isFalse);
    expect(rules.contains("allow read, write: if true"), isFalse);
    expect(rules.contains('image/jpeg'), isTrue);
    expect(rules.contains('image/png'), isTrue);
    expect(rules.contains('image/webp'), isTrue);
    expect(rules.contains('5 * 1024 * 1024'), isTrue);
  });

  test('root 可上傳', () {
    expect(
      const PlatformMediaStorageAccess(
        authUid: PlatformRootAdmin.uid,
      ).canWriteLibraryObject(),
      isTrue,
    );
  });

  test('manage_platform_media 可上傳', () {
    const PlatformAdminModel staff = PlatformAdminModel(
      uid: 'staff-1',
      name: '員工',
      email: 'staff@example.com',
      role: 'platform_staff',
      enabled: true,
      permissions: <String>[PlatformPermissionKeys.managePlatformMedia],
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-1',
        platformUser: staff,
      ).canWriteLibraryObject(),
      isTrue,
    );
  });

  test('super_admin / all 可上傳', () {
    const PlatformAdminModel superAdmin = PlatformAdminModel(
      uid: 'sa-1',
      name: '最高',
      email: 'sa@example.com',
      role: 'super_admin',
      enabled: true,
      permissions: <String>[],
    );
    const PlatformAdminModel allPerms = PlatformAdminModel(
      uid: 'all-1',
      name: '全權',
      email: 'all@example.com',
      role: 'platform_staff',
      enabled: true,
      permissions: <String>[PlatformPermissionKeys.all],
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'sa-1',
        platformUser: superAdmin,
      ).canWriteLibraryObject(),
      isTrue,
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'all-1',
        platformUser: allPerms,
      ).canWriteLibraryObject(),
      isTrue,
    );
  });

  test('無權限登入者被拒絕', () {
    const PlatformAdminModel staff = PlatformAdminModel(
      uid: 'staff-2',
      name: '員工',
      email: 'staff2@example.com',
      role: 'platform_staff',
      enabled: true,
      permissions: <String>[PlatformPermissionKeys.viewPaymentStatus],
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-2',
        platformUser: staff,
      ).canWriteLibraryObject(),
      isFalse,
    );
  });

  test('店主不可寫入平台圖庫', () {
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'shop-owner-1',
      ).canWriteLibraryObject(),
      isFalse,
    );
  });

  test('停用平台人員不可寫入', () {
    const PlatformAdminModel disabled = PlatformAdminModel(
      uid: 'staff-3',
      name: '停用',
      email: 'off@example.com',
      role: 'platform_staff',
      enabled: false,
      permissions: <String>[PlatformPermissionKeys.managePlatformMedia],
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-3',
        platformUser: disabled,
      ).canWriteLibraryObject(),
      isFalse,
    );
  });

  test('非圖片或超過 5 MB 被拒絕', () {
    const PlatformAdminModel staff = PlatformAdminModel(
      uid: 'staff-4',
      name: '員工',
      email: 'staff4@example.com',
      role: 'platform_staff',
      enabled: true,
      permissions: <String>[PlatformPermissionKeys.managePlatformMedia],
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-4',
        platformUser: staff,
        contentType: 'application/pdf',
      ).canWriteLibraryObject(),
      isFalse,
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-4',
        platformUser: staff,
        contentType: 'image/gif',
      ).canWriteLibraryObject(),
      isFalse,
    );
    expect(
      const PlatformMediaStorageAccess(
        authUid: 'staff-4',
        platformUser: staff,
        sizeBytes: 5 * 1024 * 1024 + 1,
      ).canWriteLibraryObject(),
      isFalse,
    );
  });
}
