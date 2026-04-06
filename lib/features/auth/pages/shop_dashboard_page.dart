// 檔案名稱：lib/features/auth/pages/shop_dashboard_page.dart
// 說明：店家後台首頁（模組分頁骨架版）
//
// 目前目標：
// - 後台首頁改成上方模組分頁
// - 依 enabledModules / role 顯示可見模組
// - 貓咪旅店先接現有預約管理頁
// - 其他模組先保留模板位置
// - 表格統計先保留入口，部分內容可鎖 owner

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/shop_basic_info_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_booking_manage_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_business_info_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_module_settings_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_permission_settings_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_room_type_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_room_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_room_calendar_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_policy_logs_page.dart';


class ShopDashboardPage extends StatefulWidget {
  const ShopDashboardPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopDashboardPage> createState() => _ShopDashboardPageState();
}

class _ShopDashboardPageState extends State<ShopDashboardPage> {
  String? _currentUserRole;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
      return;
    }

    try {
      final role = await ShopService.instance.getUserRoleInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );

      if (!mounted) return;
      setState(() {
        _currentUserRole = role;
        _roleLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
    }
  }

  bool _isProfileComplete(Map<String, dynamic> shop) {
    return (shop['businessType'] ?? '') != '' &&
        (shop['city'] ?? '') != '' &&
        (shop['address'] ?? '') != '' &&
        (shop['phone'] ?? '') != '';
  }

  List<String> _buildVisibleModules({
    required List<String> enabledModules,
    required String? role,
  }) {
    final result = <String>[];

    for (final module in ShopModules.all) {
      final isEnabled = enabledModules.contains(module);

      if (!isEnabled) continue;

      // 目前 staff 先不開 dashboard 管理頁
      if (role == ShopRoles.staff) continue;

      result.add(module);
    }

    if (result.isEmpty) {
      return [...ShopModules.defaultEnabled];
    }

    return result;
  }

  String _moduleLabel(String module) {
    switch (module) {
      case ShopModules.basicInfo:
        return '基本資訊';
      case ShopModules.catHotel:
        return '貓咪旅店';
      case ShopModules.dogHotel:
        return '狗狗旅店';
      case ShopModules.grooming:
        return '美容功能';
      case ShopModules.hospital:
        return '動物醫院';
      case ShopModules.store:
        return '賣場功能';
      case ShopModules.reports:
        return '表格統計';
      default:
        return module;
    }
  }

  IconData _moduleIcon(String module) {
    switch (module) {
      case ShopModules.basicInfo:
        return Icons.store;
      case ShopModules.catHotel:
        return Icons.pets;
      case ShopModules.dogHotel:
        return Icons.cruelty_free;
      case ShopModules.grooming:
        return Icons.content_cut;
      case ShopModules.hospital:
        return Icons.local_hospital;
      case ShopModules.store:
        return Icons.shopping_bag;
      case ShopModules.reports:
        return Icons.bar_chart;
      default:
        return Icons.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserRole == null) {
      return const Scaffold(
        body: Center(child: Text('查無店家權限')),
      );
    }

    if (!ShopService.instance.canManageShop(_currentUserRole)) {
      return const Scaffold(
        body: Center(child: Text('你沒有管理權限')),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('店家後台')),
            body: Center(child: Text('讀取失敗：${snapshot.error}')),
          );
        }

        final shop = snapshot.data;
        if (shop == null) {
          return const Scaffold(
            body: Center(child: Text('找不到店家資料')),
          );
        }

        final isComplete = _isProfileComplete(shop);
        final enabledModules =
            ShopService.instance.normalizeEnabledModules(shop['enabledModules']);
        final visibleModules = _buildVisibleModules(
          enabledModules: enabledModules,
          role: _currentUserRole,
        );

        return DefaultTabController(
          length: visibleModules.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(shop['name'] ?? '店家後台'),
              bottom: TabBar(
                isScrollable: true,
                tabs: visibleModules
                    .map(
                      (module) => Tab(
                        text: _moduleLabel(module),
                        icon: Icon(_moduleIcon(module)),
                      ),
                    )
                    .toList(),
              ),
            ),
            body: Column(
              children: [
                if (!isComplete)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ 請先完成店家基本資料，才能使用完整功能',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: visibleModules.map((module) {
                      switch (module) {
                        case ShopModules.basicInfo:
                          return _BasicInfoTab(
  shopId: widget.shopId,
  currentUserRole: _currentUserRole,
);
                        case ShopModules.catHotel:
                          return _CatHotelTab(
                            shopId: widget.shopId,
                            isProfileComplete: isComplete,
                          );
                        case ShopModules.dogHotel:
                          return const _ModuleTemplateTab(
                            title: '狗狗旅店',
                            description: '這裡先保留給狗狗住宿 / 寄宿 / 安親 / 預約管理模板。',
                          );
                        case ShopModules.grooming:
                          return const _ModuleTemplateTab(
                            title: '美容功能',
                            description: '這裡先保留給美容預約、價目表、美容師排班、服務項目模板。',
                          );
                        case ShopModules.hospital:
                          return const _ModuleTemplateTab(
                            title: '動物醫院',
                            description: '這裡先保留給門診預約、看診項目、醫師班表、病歷延伸模板。',
                          );
                        case ShopModules.store:
                          return const _ModuleTemplateTab(
                            title: '賣場功能',
                            description: '這裡先保留給商品管理、訂單、上下架、曝光位模板。',
                          );
                        case ShopModules.reports:
                          return _ReportsTab(
                            currentUserRole: _currentUserRole,
                          );
                        default:
                          return const Center(child: Text('模組尚未定義'));
                      }
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ===== 基本資訊分頁 =====
class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({
    required this.shopId,
    required this.currentUserRole,
  });

  final String shopId;
  final String? currentUserRole;

  bool get _canManageModules =>
      currentUserRole == ShopRoles.owner ||
      currentUserRole == ShopRoles.manager;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MenuTile(
          title: '店家基本資料',
          subtitle: '設定店名、類型、地址、電話與介紹',
          icon: Icons.store,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopBasicInfoPage(shopId: shopId),
              ),
            );
          },
        ),
        _MenuTile(
          title: '營業資訊',
          subtitle: '設定營業時間與服務項目',
          icon: Icons.schedule,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopBusinessInfoPage(shopId: shopId),
              ),
            );
          },
        ),
        _MenuTile(
          title: '店家封面 ',
          subtitle: '上傳 Logo 與封面圖片',
          icon: Icons.image,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopMediaPage(shopId: shopId),
              ),
            );
          },
        ),
        _MenuTile(
          title: '前台預覽',
          subtitle: '查看客戶看到的頁面',
          icon: Icons.visibility,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopPublicPage(shopId: shopId),
              ),
            );
          },
        ),
        _MenuTile(
          title: '模組設定',
          subtitle: _canManageModules
              ? '控制哪些模組顯示在後台'
              : '目前只有 owner / manager 可修改',
          icon: Icons.dashboard_customize,
          enabled: _canManageModules,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopModuleSettingsPage(
                  shopId: shopId,
                  currentUserRole: currentUserRole,
                ),
              ),
            );
          },
        ),
        _MenuTile(
  title: '權限設定',
  subtitle: _canManageModules
      ? '用 Email 指定主管 / 員工，並設定功能開關'
      : '目前只有 owner / manager 可查看',
  icon: Icons.admin_panel_settings,
  enabled: _canManageModules,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPermissionSettingsPage(
          shopId: shopId,
          currentUserRole: currentUserRole,
        ),
      ),
    );
  },
),

_MenuTile(
  title: '會員管理',
  subtitle: '查看會員資料與訂單紀錄（即將開放）',
  icon: Icons.people,
enabled: true,
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AdminMemberListPage(),
    ),
  );
},
),

      ],
    );
  }
}

/// ===== 貓咪旅店分頁 =====
class _CatHotelTab extends StatelessWidget {
  const _CatHotelTab({
    required this.shopId,
    required this.isProfileComplete,
  });

  final String shopId;
  final bool isProfileComplete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MenuTile(
          title: '預約管理',
          subtitle: isProfileComplete ? '管理房數、關閉日期、促銷價與預約列表' : '請先完成基本資料',
          icon: Icons.calendar_month,
          enabled: isProfileComplete,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopBookingManagePage(shopId: shopId),
              ),
            );
          },
        ),

_MenuTile(
  title: '訂單管理',
  subtitle: '查看與管理所有預約訂單',
  icon: Icons.receipt_long,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBookingListPage(
          shopId: shopId,
        ),
      ),
    );
  },
),

        _MenuTile(
  title: '房型管理',
  subtitle: '設定不同房型、可住數量與價格',
  icon: Icons.home_work,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopRoomTypePage(
  shopId: shopId,
),
      ),
    );
  },
),
_MenuTile(
  title: '房間管理',
  subtitle: '建立實際房間（A1 / A2 / B1）',
  icon: Icons.meeting_room,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopRoomPage(
          shopId: shopId,
        ),
      ),
    );
  },
),
_MenuTile(
  title: '房間日曆',
  subtitle: '設定某天房間是否可用 / 整修',
  icon: Icons.date_range,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopRoomCalendarPage(
          shopId: shopId,
        ),
      ),
    );
  },
),
        const _TemplateCard(
          title: '住宿加購 / 附加服務',
          description: '先預留位置，之後可擴充接送、陪玩、額外清潔、餵藥等功能。',
        ),
        _MenuTile(
  title: '入住規則 / 貓咪條件',
  subtitle: '設定入住條款（客戶預約前需同意）',
  icon: Icons.rule,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPolicyPage(
          shopId: shopId,
        ),
      ),
    );
  },
),

_MenuTile(
  title: '條款同意紀錄',
  subtitle: '查看哪些會員已同意條款',
  icon: Icons.list_alt,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPolicyLogsPage(
          shopId: shopId,
        ),
      ),
    );
  },
),

      ],
    );
  }
}

/// ===== 表格統計分頁 =====
class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.currentUserRole,
  });

  final String? currentUserRole;

  bool get _isOwner => currentUserRole == ShopRoles.owner;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _TemplateCard(
          title: '營運總覽',
          description: '先預留給訂單數、入住率、營業額、常用報表。',
        ),
        const _TemplateCard(
          title: '日期統計表',
          description: '先預留給每日預約、每日營收、房況統計。',
        ),
        const _TemplateCard(
          title: '會員 / 客戶統計',
          description: '先預留給客戶回訪率、新舊客比例、來源分析。',
        ),
        _TemplateCard(
          title: '老闆專屬內容',
          description: _isOwner
              ? '你是 owner，未來可放金流連結、內部成本、敏感報表。'
              : '此區未來只開放 owner 查看。',
          locked: !_isOwner,
        ),
      ],
    );
  }
}

/// ===== 未開發模組模板 =====
class _ModuleTemplateTab extends StatelessWidget {
  const _ModuleTemplateTab({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TemplateCard(
          title: title,
          description: description,
        ),
        const _TemplateCard(
          title: '功能清單預留',
          description: '這個模組目前先留位置，不一定顯示，不重做資料結構。',
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.description,
    this.locked = false,
  });

  final String title;
  final String description;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Card(
        child: ListTile(
          leading: Icon(locked ? Icons.lock : Icons.grid_view_rounded),
          title: Text(title),
          subtitle: Text(description),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}