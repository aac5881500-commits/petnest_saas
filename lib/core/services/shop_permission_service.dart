// 檔案名稱：lib/core/services/shop_permission_service.dart
// 功能說明：判斷店家是否限制模式或停權
// 🔐 店家權限狀態服務

class ShopPermissionService {
  static String accountStatus(Map<String, dynamic> shop) {
    return shop['accountStatus']?.toString() ?? 'normal';
  }

  static bool isRestricted(Map<String, dynamic> shop) {
    return accountStatus(shop) == 'restricted';
  }

  static bool isReadOnlyMode(Map<String, dynamic> shop) {
    return isRestricted(shop) || isSuspended(shop);
  }

  static String restrictionReason(Map<String, dynamic> shop) {
    final reason = shop['restrictionReason']?.toString().trim() ?? '';

    if (reason.isEmpty) {
      return '未填寫';
    }

    return reason;
  }

  static String restrictedMessage({String reason = ''}) {
    final reasonText = reason.trim();

    if (reasonText.isEmpty || reasonText == '未填寫') {
      return '帳號目前為限制模式，只能查看資料，無法新增、修改或刪除，請聯絡平台處理';
    }

    return '帳號目前為限制模式，原因：$reasonText。只能查看資料，無法新增、修改或刪除，請聯絡平台處理';
  }

  static String suspendedMessage() {
    return '帳號已停權，目前只保留聯絡平台功能';
  }

  static bool isSuspended(Map<String, dynamic> shop) {
    return accountStatus(shop) == 'suspended' ||
        shop['status']?.toString() == 'suspended';
  }

  static bool canCreateOrder(Map<String, dynamic> shop) {
    return !isRestricted(shop) && !isSuspended(shop);
  }

  static bool canCreateMember(Map<String, dynamic> shop) {
    return !isRestricted(shop) && !isSuspended(shop);
  }

  static bool canEditShopData(Map<String, dynamic> shop) {
    return !isRestricted(shop) && !isSuspended(shop);
  }
}
