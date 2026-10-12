// 檔案名稱：lib/core/services/platform_permission_catalog.dart
// 功能說明：平台權限 V2 分類。沿用既有 permission keys，不另建權限集合。

import 'package:petnest_saas/core/constants/platform_permission_keys.dart';

class PlatformPermissionGroup {
  const PlatformPermissionGroup({
    required this.id,
    required this.title,
    required this.keys,
  });

  final String id;
  final String title;
  final List<String> keys;
}

class PlatformPermissionCatalog {
  PlatformPermissionCatalog._();

  /// 非最高管理員不能新授予。已存在的值不會在這次儲存被清掉。
  static const Set<String> superOnlyKeys = <String>{
    PlatformPermissionKeys.viewPaymentSensitiveData,
    PlatformPermissionKeys.managePaymentSettings,
    PlatformPermissionKeys.emergencyDisablePayment,
    PlatformPermissionKeys.accessDeveloperTools,
    PlatformPermissionKeys.all,
  };

  static const List<PlatformPermissionGroup> groups = <PlatformPermissionGroup>[
    PlatformPermissionGroup(
      id: 'shops',
      title: '店家管理',
      keys: <String>[
        PlatformPermissionKeys.viewShops,
        PlatformPermissionKeys.reviewShopRequests,
        PlatformPermissionKeys.manageShopStatus,
        PlatformPermissionKeys.manageShopSubscriptions,
      ],
    ),
    PlatformPermissionGroup(
      id: 'members',
      title: '會員管理',
      keys: <String>[
        PlatformPermissionKeys.viewPlatformMembers,
        PlatformPermissionKeys.managePlatformMembers,
      ],
    ),
    PlatformPermissionGroup(
      id: 'support',
      title: '平台客服',
      keys: <String>[
        PlatformPermissionKeys.manageSupportRequests,
        PlatformPermissionKeys.manageAccountDeleteRequests,
        PlatformPermissionKeys.managePlatformReviews,
      ],
    ),
    PlatformPermissionGroup(
      id: 'sales',
      title: '業務與激活碼',
      keys: <String>[
        PlatformPermissionKeys.viewOwnSales,
        PlatformPermissionKeys.manageSales,
        PlatformPermissionKeys.manageActivationCodes,
      ],
    ),
    PlatformPermissionGroup(
      id: 'subscription',
      title: '訂閱與分潤',
      keys: <String>[PlatformPermissionKeys.manageSubscriptionFinance],
    ),
    PlatformPermissionGroup(
      id: 'payments',
      title: '金流管理',
      keys: <String>[
        PlatformPermissionKeys.viewPaymentStatus,
        PlatformPermissionKeys.reviewPaymentApplications,
        PlatformPermissionKeys.viewPaymentSensitiveData,
        PlatformPermissionKeys.managePaymentSettings,
        PlatformPermissionKeys.emergencyDisablePayment,
      ],
    ),
    PlatformPermissionGroup(
      id: 'security',
      title: '系統與人員',
      keys: <String>[
        PlatformPermissionKeys.viewPlatformLogs,
        PlatformPermissionKeys.managePlatformAdmins,
        PlatformPermissionKeys.managePlatformPolicies,
        PlatformPermissionKeys.managePlatformMedia,
        PlatformPermissionKeys.accessDeveloperTools,
      ],
    ),
  ];

  static bool isSuperOnly(String key) => superOnlyKeys.contains(key);

  static String explain(String key) {
    final String existing = PlatformPermissionKeys.description(key);
    if (existing.isNotEmpty) return existing;
    switch (key) {
      case PlatformPermissionKeys.viewShops:
        return '查看平台上的店家名單。這與只看自己負責的店家不同。';
      case PlatformPermissionKeys.manageShopStatus:
        return '調整店家狀態、限制與停權。';
      case PlatformPermissionKeys.reviewShopRequests:
        return '審核店家資料、認證與公開申請。';
      case PlatformPermissionKeys.manageShopSubscriptions:
        return '調整店家方案與使用期限。';
      case PlatformPermissionKeys.viewPlatformMembers:
        return '查看平台會員名單。';
      case PlatformPermissionKeys.managePlatformMembers:
        return '修改會員一般資料與封鎖狀態。';
      case PlatformPermissionKeys.manageSupportRequests:
        return '查看並回覆聯絡平台的客服案件。';
      case PlatformPermissionKeys.manageAccountDeleteRequests:
        return '處理會員提出的帳號刪除申請。';
      case PlatformPermissionKeys.managePlatformReviews:
        return '查看與處理全平台評價。';
      case PlatformPermissionKeys.managePlatformPolicies:
        return '管理平台條款版本。';
      case PlatformPermissionKeys.manageActivationCodes:
        return '建立與管理創店激活碼。';
      case PlatformPermissionKeys.viewPlatformLogs:
        return '查看平台操作紀錄。';
      case PlatformPermissionKeys.viewPaymentStatus:
        return '查看店家金流是否已啟用。';
      case PlatformPermissionKeys.reviewPaymentApplications:
        return '審核店家送出的金流申請。';
      default:
        return '依授權使用這項平台功能。';
    }
  }

  static String lockReason(String key) {
    if (isSuperOnly(key)) return '僅最高管理員。不能授權給平台管理員或員工。';
    return '超出你能授予的範圍。';
  }

  static int enabledCount(Iterable<String> permissions) {
    final Set<String> owned = permissions.toSet();
    return PlatformPermissionKeys.assignableValues
        .where((String key) => owned.contains(key) && !isSuperOnly(key))
        .length;
  }

  static int enabledCountIn(PlatformPermissionGroup group, Set<String> owned) {
    return group.keys.where((String key) => owned.contains(key) && !isSuperOnly(key)).length;
  }

  static List<String> added(Set<String> before, Set<String> after) {
    return after.where((String key) => !before.contains(key)).toList();
  }

  static List<String> removed(Set<String> before, Set<String> after) {
    return before.where((String key) => !after.contains(key)).toList();
  }

  static const Set<String> paymentKeys = <String>{
    PlatformPermissionKeys.viewPaymentStatus,
    PlatformPermissionKeys.reviewPaymentApplications,
    PlatformPermissionKeys.viewPaymentSensitiveData,
    PlatformPermissionKeys.managePaymentSettings,
    PlatformPermissionKeys.emergencyDisablePayment,
  };

  static const Set<String> securityKeys = <String>{
    PlatformPermissionKeys.viewPlatformLogs,
    PlatformPermissionKeys.managePlatformAdmins,
    PlatformPermissionKeys.managePlatformPolicies,
    PlatformPermissionKeys.managePlatformMedia,
    PlatformPermissionKeys.accessDeveloperTools,
  };

  static bool needsRiskNotice({
    required String previousRole,
    required String nextRole,
    required bool previousEnabled,
    required bool nextEnabled,
    required List<String> added,
    required List<String> removed,
  }) {
    if (previousRole != nextRole) return true;
    if (previousEnabled &&
        !nextEnabled &&
        previousRole != PlatformAdminRoles.platformStaff) {
      return true;
    }
    final Iterable<String> changed = <String>[...added, ...removed];
    return changed.any(
      (String key) =>
          PlatformPermissionKeys.isSensitive(key) ||
          paymentKeys.contains(key) ||
          securityKeys.contains(key),
    );
  }

  static String changeHeadline({
    required String operatorRole,
    required int addedCount,
    required int removedCount,
    required bool enabledChanged,
    required bool nextEnabled,
  }) {
    final String actor = PlatformAdminRoles.label(operatorRole);
    if (enabledChanged && addedCount == 0 && removedCount == 0) {
      return '$actor${nextEnabled ? '啟用' : '停用'}平台帳號';
    }
    return '$actor修改員工權限';
  }

  static String changeDetail({
    required int addedCount,
    required int removedCount,
    required bool enabledChanged,
    required bool nextEnabled,
    required bool roleChanged,
  }) {
    final List<String> parts = <String>[];
    if (roleChanged) parts.add('角色已變更');
    if (enabledChanged) parts.add(nextEnabled ? '改為啟用' : '改為停用');
    if (addedCount > 0) parts.add('新增 $addedCount 項');
    if (removedCount > 0) parts.add('移除 $removedCount 項');
    if (parts.isEmpty) return '更新帳號資料';
    return parts.join('、');
  }
}
