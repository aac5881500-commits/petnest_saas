// 檔案名稱：lib/core/services/shop_permission_catalog.dart
// 功能說明：店家權限 V2。沿用既有 permission keys，不另建權限集合。
// 老闆專屬能力不寫進可勾選權限，避免「全選」放大權限。

import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';

class ShopPermissionItem {
  const ShopPermissionItem({
    required this.key,
    required this.title,
    required this.description,
    this.highRisk = false,
  });

  final String key;
  final String title;
  final String description;
  final bool highRisk;
}

class ShopPermissionCategory {
  const ShopPermissionCategory({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<ShopPermissionItem> items;
}

class ShopPermissionChange {
  const ShopPermissionChange({
    required this.key,
    required this.title,
    required this.enabled,
  });

  final String key;
  final String title;
  final bool enabled;
}

class ShopPermissionLogText {
  const ShopPermissionLogText({required this.headline, required this.details});

  final String headline;
  final List<String> details;
}

class ShopPermissionCatalog {
  ShopPermissionCatalog._();

  /// 只存在於角色判斷，不能被店長或員工勾選。
  static const List<String> ownerCapabilities = <String>[
    '轉移店家所有權',
    '任命或撤銷店長',
    '修改店長權限',
    '金流串接與金鑰',
    '收款銀行帳戶',
    '平台訂閱與付款方式',
    '平台帳單與重要財務設定',
    '店家核心安全設定',
  ];

  /// 既有鍵。非老闆即使資料裡是 true，存取時也不算授權。
  static const Set<String> ownerOnlyKeys = <String>{
    ShopPermissionKeys.managePaymentSettings,
  };

  static const Set<String> highRiskKeys = <String>{
    ShopPermissionKeys.manageMemberPoints,
    ShopPermissionKeys.sendMemberCampaigns,
    ShopPermissionKeys.adjustDaycarePrice,
    ShopPermissionKeys.viewInventoryCost,
    ShopPermissionKeys.adjustInventory,
  };

  static const List<ShopPermissionCategory> categories =
      <ShopPermissionCategory>[
        ShopPermissionCategory(
          id: 'profile',
          title: '基本資料',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.editBasicInfo,
              title: '修改一般店家資訊',
              description: '修改店名、介紹等一般資料。查看資料不需要另外授權。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.editBusinessInfo,
              title: '管理營業時間',
              description: '修改營業時間與營業資訊。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageFrontendContent,
              title: '管理公告與 FAQ',
              description: '管理前台公告、FAQ 與相關內容。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.editMedia,
              title: '管理店家圖片',
              description: '修改 Logo 與封面。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'campaigns',
          title: '會員推廣與通知',
          items: [
            ShopPermissionItem(
              key: ShopPermissionKeys.manageCampaignDrafts,
              title: '建立推廣草稿',
              description: '撰寫內容、選擇本店會員與預覽；不能正式發送。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.sendMemberCampaigns,
              title: '發送會員推廣與通知',
              description: '可正式送出本店會員通知，包含指定會員與群發。',
              highRisk: true,
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.viewMemberCampaigns,
              title: '查看推廣發送紀錄',
              description: '查看發送內容、對象與處理結果。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'bookings',
          title: '訂單管理',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.manageBookings,
              title: '查看與處理訂單',
              description: '沿用現有訂單權限，包含查看、確認、修改、分配房間、入住、退房與取消。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageBookingSettings,
              title: '管理預約設定',
              description: '修改預約規則與可預約日期。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageChat,
              title: '回覆店家聊天',
              description: '查看並回覆客人訊息。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'rooms',
          title: '房務管理',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.manageRoomDashboard,
              title: '查看與更新房務',
              description: '查看房務並修改房間狀態、清潔狀態。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageRooms,
              title: '管理房間',
              description: '維護房間資料。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageRoomTypes,
              title: '管理房型',
              description: '維護房型。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'care',
          title: '每日照護',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.viewDaycareBookings,
              title: '查看照護與安親紀錄',
              description: '查看照護與安親訂單。每日照護入口同時沿用訂單與房務權限。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageDaycareBookings,
              title: '填寫照護回報',
              description: '填寫並處理照護、安親回報。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageDaycareSettings,
              title: '管理照護設定',
              description: '修改照護與安親設定。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'members',
          title: '會員管理',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.manageMembers,
              title: '查看與修改會員',
              description: '查看會員、修改資料，以及 VIP、黑名單與封存等會員管理。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'staff',
          title: '員工管理',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.manageStaff,
              title: '管理一般員工',
              description: '查看並管理一般員工與員工邀請。不能任命店長，也不能修改老闆。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'inventory',
          title: '庫存及商城',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.viewInventory,
              title: '查看庫存',
              description: '查看庫存數量。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.receiveInventory,
              title: '進貨',
              description: '登錄進貨。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageInventory,
              title: '管理庫存',
              description: '管理庫存品項。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.viewStoreOrders,
              title: '查看商城訂單',
              description: '查看商城訂單。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.manageStoreProducts,
              title: '管理商城商品',
              description: '管理商品與分類。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'reports',
          title: '營運報表',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.viewReports,
              title: '查看營運統計',
              description: '查看基本營運統計。營業額與詳細財務仍受既有報表權限約束。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.viewActionLogs,
              title: '查看操作紀錄',
              description: '查看店家操作紀錄。',
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'finance',
          title: '財務操作',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.manageMemberPoints,
              title: '調整訂單結算發點',
              description: '結算時調整會員點數。預設不開放，須由老闆明確授權。',
              highRisk: true,
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.adjustDaycarePrice,
              title: '調整安親價格',
              description: '改價屬於高風險操作，預設關閉。',
              highRisk: true,
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.viewInventoryCost,
              title: '查看成本',
              description: '查看進貨與庫存成本。',
              highRisk: true,
            ),
          ],
        ),
        ShopPermissionCategory(
          id: 'platform',
          title: '平台聯絡與通知',
          items: <ShopPermissionItem>[
            ShopPermissionItem(
              key: ShopPermissionKeys.viewPlatformNotices,
              title: '查看平台一般公告',
              description: '查看一般公告與營運通知。重要安全公告只給老闆，不受這個開關影響。',
            ),
            ShopPermissionItem(
              key: ShopPermissionKeys.contactPlatformSupport,
              title: '聯絡平台客服',
              description: '聯絡平台客服並查看回覆。與金流、訂閱和店主專屬設定無關。',
            ),
          ],
        ),
      ];

  static List<ShopPermissionItem> get items => categories
      .expand((ShopPermissionCategory category) => category.items)
      .toList();

  static ShopPermissionItem? itemFor(String key) {
    for (final ShopPermissionItem item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  static String labelFor(String key) => itemFor(key)?.title ?? key;

  /// 操作紀錄用。對不到目錄時不輸出原始 key。
  static String displayLabel(String key) {
    final String known = itemFor(key)?.title ?? _storedKeyLabels[key] ?? '';
    if (known.isNotEmpty) return known;
    return '其他權限';
  }

  static const Map<String, String> _storedKeyLabels = <String, String>{
    ShopPermissionKeys.managePaymentSettings: '金流與收款設定',
    ShopPermissionKeys.manageModules: '模組設定',
    ShopPermissionKeys.manageDevices: '設備與攝影機',
    ShopPermissionKeys.managePolicy: '入住規則',
    ShopPermissionKeys.manageAddons: '加購服務',
    ShopPermissionKeys.manageEnvironment: '環境介紹',
    ShopPermissionKeys.manageAbout: '關於我們',
    ShopPermissionKeys.manageReviews: '評價',
    ShopPermissionKeys.managePointRedemptions: '實體商品核銷',
    ShopPermissionKeys.adjustInventory: '出庫與盤點',
    ShopPermissionKeys.manageStoreOrders: '管理商城訂單',
    ShopPermissionKeys.manageStoreSettings: '賣場設定',
    ShopPermissionKeys.manageDaycarePricing: '安親方案價格',
    ShopPermissionKeys.convertDaycareToAccommodation: '臨托轉住宿',
  };

  static bool isOwnerOnlyKey(String key) => ownerOnlyKeys.contains(key);

  static Map<String, bool> emptyGrantable() {
    return <String, bool>{
      for (final ShopPermissionItem item in items) item.key: false,
    };
  }

  /// 舊的固定模板仍保留給相容與測試。本階段畫面不再提供一鍵套用。
  /// 下一階段若要店家自訂模板，從這裡延伸，不另建全平台共用集合。
  static const bool quickTemplatesEnabled = false;

  static Map<String, bool> templateBasicStaff() {
    return _with(<String>[
      ShopPermissionKeys.manageBookings,
      ShopPermissionKeys.manageRoomDashboard,
      ShopPermissionKeys.manageDaycareBookings,
      ShopPermissionKeys.viewDaycareBookings,
    ]);
  }

  static Map<String, bool> templateAdvancedStaff() {
    return _with(<String>[
      ...templateBasicStaff().entries
          .where((MapEntry<String, bool> entry) => entry.value)
          .map((MapEntry<String, bool> entry) => entry.key),
      ShopPermissionKeys.manageMembers,
      ShopPermissionKeys.viewInventory,
      ShopPermissionKeys.receiveInventory,
      ShopPermissionKeys.viewStoreOrders,
    ]);
  }

  static Map<String, bool> templateManager() {
    return _with(<String>[
      ShopPermissionKeys.editBasicInfo,
      ShopPermissionKeys.editBusinessInfo,
      ShopPermissionKeys.manageFrontendContent,
      ShopPermissionKeys.manageBookings,
      ShopPermissionKeys.manageBookingSettings,
      ShopPermissionKeys.manageChat,
      ShopPermissionKeys.manageRoomDashboard,
      ShopPermissionKeys.manageRooms,
      ShopPermissionKeys.manageRoomTypes,
      ShopPermissionKeys.viewDaycareBookings,
      ShopPermissionKeys.manageDaycareBookings,
      ShopPermissionKeys.manageDaycareSettings,
      ShopPermissionKeys.manageMembers,
      ShopPermissionKeys.manageStaff,
      ShopPermissionKeys.viewInventory,
      ShopPermissionKeys.viewStoreOrders,
      ShopPermissionKeys.viewReports,
      ShopPermissionKeys.viewPlatformNotices,
      ShopPermissionKeys.contactPlatformSupport,
    ]);
  }

  static Map<String, bool> _with(List<String> enabled) {
    final Map<String, bool> result = emptyGrantable();
    for (final String key in enabled) {
      if (!isOwnerOnlyKey(key)) result[key] = true;
    }
    for (final String key in ownerOnlyKeys) {
      result.remove(key);
    }
    return result;
  }

  static Map<String, bool> stripOwnerOnly(Map<String, bool> permissions) {
    final Map<String, bool> result = Map<String, bool>.from(permissions);
    for (final String key in ownerOnlyKeys) {
      result[key] = false;
    }
    return result;
  }

  static int enabledCount(Map<String, bool> permissions) {
    return items.where((ShopPermissionItem item) {
      return permissions[item.key] == true && !isOwnerOnlyKey(item.key);
    }).length;
  }

  static int enabledCountIn(
    ShopPermissionCategory category,
    Map<String, bool> permissions,
  ) {
    return category.items.where((ShopPermissionItem item) {
      return permissions[item.key] == true;
    }).length;
  }

  static List<ShopPermissionChange> diff(
    Map<String, bool> before,
    Map<String, bool> after,
  ) {
    final List<ShopPermissionChange> changes = <ShopPermissionChange>[];
    for (final ShopPermissionItem item in items) {
      final bool oldValue = before[item.key] == true;
      final bool newValue = after[item.key] == true;
      if (oldValue == newValue) continue;
      changes.add(
        ShopPermissionChange(
          key: item.key,
          title: item.title,
          enabled: newValue,
        ),
      );
    }
    return changes;
  }

  static bool sameGrantable(Map<String, bool> before, Map<String, bool> after) {
    return diff(before, after).isEmpty;
  }

  /// 非老闆不能升成老闆或店長，也不能改自己的權限。
  static String? roleChangeBlock({
    required String operatorRole,
    required String targetCurrentRole,
    required String nextRole,
    required bool editingSelf,
  }) {
    if (nextRole == ShopRoles.owner || targetCurrentRole == ShopRoles.owner) {
      return '不可變更老闆角色';
    }
    if (operatorRole == ShopRoles.staff) {
      return '員工不可修改權限';
    }
    if (operatorRole == ShopRoles.manager) {
      if (editingSelf) return '店長不可修改自己的權限';
      if (targetCurrentRole == ShopRoles.manager ||
          nextRole != ShopRoles.staff) {
        return '店長不可任命或修改店長';
      }
    }
    if (operatorRole != ShopRoles.owner && operatorRole != ShopRoles.manager) {
      return '沒有權限管理成員';
    }
    return null;
  }

  /// 店長只能授予自己已有、且不是老闆專屬的權限。
  static Map<String, bool> clampForOperator({
    required String operatorRole,
    required Map<String, bool> operatorPermissions,
    required Map<String, bool> requested,
  }) {
    final Map<String, bool> result = stripOwnerOnly(requested);
    if (operatorRole == ShopRoles.owner) return result;
    for (final ShopPermissionItem item in items) {
      if (result[item.key] == true && operatorPermissions[item.key] != true) {
        result[item.key] = false;
      }
    }
    result[ShopPermissionKeys.manageStaff] = false;
    return result;
  }

  static bool isActiveManager(Map<String, dynamic> member) {
    if (member['role']?.toString() != ShopRoles.manager) return false;
    final String status = member['status']?.toString() ?? 'active';
    return status != 'disabled' &&
        status != 'inactive' &&
        status != 'removed' &&
        status != 'suspended';
  }

  static int activeManagerCount(Iterable<Map<String, dynamic>> members) {
    return members.where(isActiveManager).length;
  }

  /// 畫面阻擋第二名店長。這不是交易，也不能防止同時寫入。
  static String? secondManagerBlock({
    required String nextRole,
    required String? editingMemberId,
    required Iterable<Map<String, dynamic>> members,
    required Iterable<Map<String, dynamic>> invites,
  }) {
    if (nextRole != ShopRoles.manager) return null;
    final bool editingCurrentManager = members.any((
      Map<String, dynamic> member,
    ) {
      return member['id']?.toString() == editingMemberId &&
          isActiveManager(member);
    });
    if (editingCurrentManager) return null;
    final Iterable<Map<String, dynamic>> active = members.where(
      isActiveManager,
    );
    if (active.isNotEmpty) {
      final String email = active.first['email']?.toString() ?? '';
      final String who = email.isEmpty ? '現任店長' : email;
      return '此店已有店長（$who），請先撤換現任店長後再任命';
    }
    final bool pending = invites.any(
      (Map<String, dynamic> invite) =>
          invite['role']?.toString() == ShopRoles.manager,
    );
    if (pending) return '已有待接受的店長邀請，請先取消後再任命';
    return null;
  }

  /// 新角色不能使用的權限。只會列出要關閉的項目，不會自動打開任何權限。
  static List<ShopPermissionChange> permissionsLostOnRole({
    required String nextRole,
    required Map<String, bool> permissions,
  }) {
    if (nextRole != ShopRoles.staff) return const <ShopPermissionChange>[];
    if (permissions[ShopPermissionKeys.manageStaff] != true) {
      return const <ShopPermissionChange>[];
    }
    return <ShopPermissionChange>[
      ShopPermissionChange(
        key: ShopPermissionKeys.manageStaff,
        title: displayLabel(ShopPermissionKeys.manageStaff),
        enabled: false,
      ),
    ];
  }

  static ShopPermissionLogText describeActionLog({
    required String action,
    required String operatorRole,
    required String timeText,
    required Map<String, dynamic> payload,
  }) {
    final String actor = ShopRoles.label(operatorRole);
    final List<Map<String, dynamic>> changes = _permissionChanges(payload);
    final int added = changes
        .where((Map<String, dynamic> item) => item['newValue'] == true)
        .length;
    final int removed = changes.length - added;
    final String previousRole = payload['previousRole']?.toString() ?? '';
    final String nextRole = payload['memberRole']?.toString() ?? '';
    final bool roleChanged =
        previousRole.isNotEmpty &&
        nextRole.isNotEmpty &&
        previousRole != nextRole;
    final String changeCount = (added == 0 && removed == 0)
        ? ''
        : '｜新增 $added 項、移除 $removed 項';
    final String headline = switch (action) {
      'update_member_permission' =>
        roleChanged
            ? '$timeText｜$actor將${ShopRoles.label(previousRole)}改為${ShopRoles.label(nextRole)}$changeCount'
            : '$timeText｜$actor修改員工權限｜新增 $added 項、移除 $removed 項',
      'create_invite' => '$timeText｜$actor建立邀請',
      'invite_accepted' => '$timeText｜接受邀請',
      'remove_member_invite' => '$timeText｜$actor取消邀請',
      'remove_member' => '$timeText｜$actor移除成員',
      'update_permission' => '$timeText｜$actor更新權限設定',
      _ => '$timeText｜$actor更新成員資料',
    };
    final List<String> details = <String>[
      if ((payload['memberEmail'] ?? '').toString().isNotEmpty)
        '對象：${payload['memberEmail']}',
      if (roleChanged)
        '角色：${ShopRoles.label(previousRole)} → ${ShopRoles.label(nextRole)}',
      ...changes.map((Map<String, dynamic> item) {
        final String title = displayLabel(item['key']?.toString() ?? '');
        final String from = item['oldValue'] == true ? '開啟' : '關閉';
        final String to = item['newValue'] == true ? '開啟' : '關閉';
        return '$title：$from → $to';
      }),
    ];
    return ShopPermissionLogText(headline: headline, details: details);
  }

  static List<Map<String, dynamic>> _permissionChanges(
    Map<String, dynamic> payload,
  ) {
    final dynamic raw = payload['changedPermissions'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static bool canReadNotice({
    required String role,
    required bool canViewAnnouncements,
    required String type,
    required String audience,
  }) {
    if (role == ShopRoles.owner) return true;
    final String scope = audience.isEmpty ? _legacyAudience(type) : audience;
    switch (scope) {
      case 'owner':
        return false;
      case 'managers':
        return role == ShopRoles.manager;
      case 'announcement':
        return role == ShopRoles.manager || canViewAnnouncements;
      case 'everyone':
        return role == ShopRoles.manager || role == ShopRoles.staff;
      default:
        return false;
    }
  }

  static String audienceForType(String type) {
    switch (type) {
      case 'system':
        return 'everyone';
      case 'update':
      case 'review':
        return 'announcement';
      case 'warning':
        return 'managers';
      case 'plan':
      case 'suspend':
      case 'payment_failed':
      case 'payout_account':
      case 'account_security':
        return 'owner';
      default:
        return 'owner';
    }
  }

  static String _legacyAudience(String type) {
    switch (type) {
      case 'system':
        return 'everyone';
      case 'update':
      case 'review':
      case 'warning':
        return 'managers';
      default:
        return 'owner';
    }
  }
}
