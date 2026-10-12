// 檔案名稱：lib/core/constants/platform_permission_keys.dart
// 功能說明：集中定義平台最高管理員、開發帳號與平台員工可分配的權限。
// 🔐 平台管理權限常數

/// 平台管理員角色
abstract final class PlatformAdminRoles {
  /// 平台最高權限，只能由系統預先指定
  static const String superAdmin = 'super_admin';

  /// 平台日常管理員。不能取得最高管理員專屬權限。
  static const String platformAdmin = 'platform_admin';

  /// 開發與系統測試帳號。既有文件維持這個值。
  static const String developerAdmin = 'developer_admin';

  /// 一般平台員工
  static const String platformStaff = 'platform_staff';

  static const Set<String> values = {
    superAdmin,
    platformAdmin,
    developerAdmin,
    platformStaff,
  };

  static const List<String> assignableRoles = <String>[
    platformAdmin,
    developerAdmin,
    platformStaff,
  ];

  static String label(String role) {
    switch (role) {
      case superAdmin:
        return '最高管理員';
      case platformAdmin:
        return '平台管理員';
      case developerAdmin:
        return '開發管理員';
      case platformStaff:
        return '平台員工';
      default:
        return '未知角色';
    }
  }
}

/// 平台可分配權限
abstract final class PlatformPermissionKeys {
  /// 最高管理員的完整權限標記
  static const String all = 'all';

  // ─────────────────────────────
  // 店家管理
  // ─────────────────────────────

  /// 查看所有店家
  static const String viewShops = 'view_shops';

  /// 修改店家狀態、限制與停權
  static const String manageShopStatus = 'manage_shop_status';

  /// 審核店家資料、認證與公開申請
  static const String reviewShopRequests = 'review_shop_requests';

  /// 修改店家方案與到期日
  static const String manageShopSubscriptions = 'manage_shop_subscriptions';

  // ─────────────────────────────
  // 金流管理
  // ─────────────────────────────

  /// 查看店家金流啟用與審核狀態
  static const String viewPaymentStatus = 'view_payment_status';

  /// 審核店家金流申請
  static const String reviewPaymentApplications = 'review_payment_applications';

  /// 查看金流敏感資料
  static const String viewPaymentSensitiveData = 'view_payment_sensitive_data';

  /// 修改平台與店家金流設定
  static const String managePaymentSettings = 'manage_payment_settings';

  /// 緊急關閉店家或平台金流
  static const String emergencyDisablePayment = 'emergency_disable_payment';

  // ─────────────────────────────
  // 會員與客服
  // ─────────────────────────────

  /// 查看平台會員
  static const String viewPlatformMembers = 'view_platform_members';

  /// 管理平台會員與封鎖狀態
  static const String managePlatformMembers = 'manage_platform_members';

  /// 處理聯絡平台案件
  static const String manageSupportRequests = 'manage_support_requests';

  /// 處理帳號刪除申請
  static const String manageAccountDeleteRequests =
      'manage_account_delete_requests';

  /// 管理全平台評價
  static const String managePlatformReviews = 'manage_platform_reviews';

  // ─────────────────────────────
  // 平台設定
  // ─────────────────────────────

  /// 管理平台條款
  static const String managePlatformPolicies = 'manage_platform_policies';

  /// 管理創店激活碼
  static const String manageActivationCodes = 'manage_activation_codes';

  /// 建立與調整業務、店家歸屬
  static const String manageSales = 'manage_sales';

  /// 業務只查看自己的客戶與業績
  static const String viewOwnSales = 'view_own_sales';

  /// 確認店家訂閱收款、退款與分潤發放
  static const String manageSubscriptionFinance =
      'manage_subscription_finance';

  /// 查看平台操作紀錄
  static const String viewPlatformLogs = 'view_platform_logs';

  /// 管理平台員工及分配權限
  static const String managePlatformAdmins = 'manage_platform_admins';

  /// 上傳與管理平台外觀圖庫
  static const String managePlatformMedia = 'manage_platform_media';

  /// 使用開發與測試工具
  static const String accessDeveloperTools = 'access_developer_tools';

  /// 可以透過權限開關分配的全部項目
  ///
  /// 不包含 [all]，因為一般帳號不能透過開關取得最高完整權限。
  static const List<String> assignableValues = [
    viewShops,
    manageShopStatus,
    reviewShopRequests,
    manageShopSubscriptions,
    viewPaymentStatus,
    reviewPaymentApplications,
    viewPaymentSensitiveData,
    managePaymentSettings,
    emergencyDisablePayment,
    viewPlatformMembers,
    managePlatformMembers,
    manageSupportRequests,
    manageAccountDeleteRequests,
    managePlatformReviews,
    managePlatformPolicies,
    manageActivationCodes,
    manageSales,
    viewOwnSales,
    manageSubscriptionFinance,
    viewPlatformLogs,
    managePlatformAdmins,
    managePlatformMedia,
    accessDeveloperTools,
  ];

  static String label(String permission) {
    switch (permission) {
      case viewShops:
        return '查看所有店家';
      case manageShopStatus:
        return '管理店家狀態與停權';
      case reviewShopRequests:
        return '審核店家資料與認證';
      case manageShopSubscriptions:
        return '管理店家方案與期限';
      case viewPaymentStatus:
        return '查看金流狀態';
      case reviewPaymentApplications:
        return '審核金流申請';
      case viewPaymentSensitiveData:
        return '查看金流敏感資料';
      case managePaymentSettings:
        return '修改金流設定';
      case emergencyDisablePayment:
        return '緊急關閉金流';
      case viewPlatformMembers:
        return '查看平台會員';
      case managePlatformMembers:
        return '管理平台會員';
      case manageSupportRequests:
        return '處理聯絡平台案件';
      case manageAccountDeleteRequests:
        return '處理帳號刪除申請';
      case managePlatformReviews:
        return '管理全平台評價';
      case managePlatformPolicies:
        return '管理平台條款';
      case manageActivationCodes:
        return '管理創店激活碼';
      case manageSales:
        return '管理業務與店家歸屬';
      case viewOwnSales:
        return '查看自己的業務客戶';
      case manageSubscriptionFinance:
        return '管理店家訂閱收款與分潤';
      case viewPlatformLogs:
        return '查看平台操作紀錄';
      case managePlatformAdmins:
        return '管理平台員工與權限';
      case managePlatformMedia:
        return '管理平台外觀圖庫';
      case accessDeveloperTools:
        return '使用開發測試工具';
      case all:
        return '全部最高權限';
      default:
        return permission;
    }
  }

  static String description(String permission) {
    switch (permission) {
      case viewPaymentSensitiveData:
        return '敏感權限，可查看店家金流識別與申請資料。';
      case managePaymentSettings:
        return '高風險權限，可修改平台或店家的金流設定。';
      case emergencyDisablePayment:
        return '高風險權限，可立即停止金流交易。';
      case manageSubscriptionFinance:
        return '可確認店家方案收款、退款與分潤，不能由查看業者名單取得。';
      case manageSales:
        return '可建立業務、交接目前負責人，並在填寫理由後更正原始開發業務。';
      case viewOwnSales:
        return '只能查看綁定業務自己的客戶與月份業績，不能改比例或發放分潤。';
      case managePlatformAdmins:
        return '高風險權限，可建立平台員工並調整其權限。';
      case managePlatformMedia:
        return '上傳、編輯、啟用、停用與刪除平台提供的背景圖片。';
      case accessDeveloperTools:
        return '僅供開發、測試及系統維護帳號使用。';
      default:
        return '';
    }
  }

  static bool isSensitive(String permission) {
    return permission == viewPaymentSensitiveData ||
        permission == managePaymentSettings ||
        permission == emergencyDisablePayment ||
        permission == managePlatformAdmins ||
        permission == manageSubscriptionFinance ||
        permission == accessDeveloperTools;
  }
}
