// 檔案名稱：lib/core/constants/platform_root_admin.dart
// 功能說明：定義永久最高管理員 UID。
// 👑 PetNest 根管理員設定
// 即使 platform_users 被誤刪，根管理員仍可恢復平台。

abstract final class PlatformRootAdmin {
  /// 永久根管理員 UID
  static const String uid = '7FNrECQeqAca9Vu8lBBzTSdcJcg1';

  /// 是否為根管理員
  static bool isRoot(String? uid) {
    if (uid == null) return false;
    return uid == PlatformRootAdmin.uid;
  }
}
