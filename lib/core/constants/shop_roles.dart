// 檔案名稱：lib/core/constants/shop_roles.dart
// 功能說明：店家角色定義

class ShopRoles {
  /// 老闆（最高權限）
  static const owner = 'owner';

  /// 店長（日常營運，不能取得老闆專屬權限）
  static const manager = 'manager';

  /// 員工（由老闆或授權店長自訂權限）
  static const staff = 'staff';

  /// 所有角色。既有 owner / staff 文件維持原值。
  static const all = [owner, manager, staff];

  static String label(String role) {
    switch (role) {
      case owner:
        return '老闆';
      case manager:
        return '店長';
      case staff:
        return '員工';
      default:
        return role;
    }
  }
}
