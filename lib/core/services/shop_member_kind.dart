// 檔案名稱：lib/core/services/shop_member_kind.dart
// 功能說明：與會員管理同一套 source 欄位判斷店家會員／手動會員。

class ShopMemberKind {
  ShopMemberKind._();

  static const String adminSource = 'admin';
  static const String appSource = 'app';

  /// 與會員列表相同：`source == 'admin'` 為手動會員；其餘（含缺欄）為店家會員。
  /// 尚未寫入的快速建立會員以 `isTempAdminMember` 視為手動會員。
  static String sourceOf(Map<String, dynamic>? member) {
    if (member == null) {
      return appSource;
    }
    if (member['isTempAdminMember'] == true) {
      return adminSource;
    }
    final String source = (member['source'] ?? '').toString().trim();
    return source == adminSource ? adminSource : appSource;
  }

  static bool isManualMember(Map<String, dynamic>? member) {
    return sourceOf(member) == adminSource;
  }

  static bool isShopMember(Map<String, dynamic>? member) {
    return !isManualMember(member);
  }
}
