// 檔案名稱：lib/core/constants/shop_roles.dart
// 功能說明：店家角色定義

class ShopRoles {
  /// 老闆（最高權限）
  static const owner = 'owner';

  /// 員工（由老闆自訂權限）
  static const staff = 'staff';

  /// 所有角色
  static const all = [owner, staff];
}
