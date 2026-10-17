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

  /// 只查看自己業務的激活碼，不能建立或改別人的碼
  static const String viewOwnActivationCodes = 'view_own_activation_codes';

  /// 預留。目前授予後仍不能自行產生激活碼。
  static const String issueOwnActivationCodes = 'issue_own_activation_codes';

  /// 建立與調整業務、店家歸屬
  static const String manageSales = 'manage_sales';

  /// 查看業務名單，不含其他業務的聯絡與分潤
  static const String viewSales = 'view_sales';

  /// 業務只查看自己的客戶與業績
  static const String viewOwnSales = 'view_own_sales';

  /// 只查看自己的分潤，不能看其他業務或改結算
  static const String viewOwnCommission = 'view_own_commission';

  /// 交接目前負責業務，不能改原始開發來源
  static const String transferShopSales = 'transfer_shop_sales';

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
    viewOwnActivationCodes,
    issueOwnActivationCodes,
    manageSales,
    viewSales,
    viewOwnSales,
    viewOwnCommission,
    transferShopSales,
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
      case viewOwnActivationCodes:
        return '查看自己的激活碼';
      case issueOwnActivationCodes:
        return '預留：自行產生激活碼';
      case manageSales:
        return '管理所有業務';
      case viewSales:
        return '查看業務列表';
      case viewOwnSales:
        return '查看自己的業務資料';
      case viewOwnCommission:
        return '查看自己的分潤';
      case transferShopSales:
        return '交接目前負責業務';
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
        return '可指派平台會員為業務、查看全部業務，並在填寫理由後更正原始開發業務。';
      case viewSales:
        return '可查看業務名單與啟用狀態，不能看其他業務的聯絡資料或分潤。';
      case viewOwnSales:
        return '只能查看綁定到自己的業務資料、負責店家與業績。';
      case viewOwnActivationCodes:
        return '只能查看自己業務的激活碼，不能建立或修改。';
      case issueOwnActivationCodes:
        return '預留權限。目前即使授予，也不能自行產生激活碼。';
      case viewOwnCommission:
        return '只能查看自己的分潤，不能看其他業務或修改結算。';
      case transferShopSales:
        return '可交接店家目前負責人。不能改原始開發業務，也不改已確認的分潤。';
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
