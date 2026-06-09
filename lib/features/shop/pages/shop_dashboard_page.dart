// 檔案名稱：lib/features/shop/pages/shop_dashboard_page.dart
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_basic_info_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_business_info_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_module_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_permission_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_type_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_logs_page.dart';
import 'package:petnest_saas/features/room/pages/room_dashboard_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_addon_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_payment_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_manage_page.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/pages/shop_contact_platform_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_platform_notification_page.dart';

class ShopDashboardPage extends StatefulWidget {
  const ShopDashboardPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopDashboardPage> createState() => _ShopDashboardPageState();
}

class _ShopDashboardPageState extends State<ShopDashboardPage> {
  String? _currentUserRole;
  Map<String, dynamic>? _currentMemberData;
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
      final memberData = await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );

      if (!mounted) return;
      setState(() {
        _currentMemberData = memberData;
        _currentUserRole = memberData?['role']?.toString();
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

  bool _can(String permissionKey) {
    return ShopService.instance.hasPermission(
      _currentMemberData,
      permissionKey,
    );
  }

  bool get _hasAnyDashboardPermission {
    if (_currentUserRole == ShopRoles.owner) return true;

    for (final key in ShopPermissionKeys.all) {
      if (_can(key)) return true;
    }

    return false;
  }

  List<String> _buildVisibleModules({required List<String> enabledModules}) {
    final result = <String>[];

    final canSeeBasicInfo =
        _can(ShopPermissionKeys.editBasicInfo) ||
        _can(ShopPermissionKeys.editBusinessInfo) ||
        _can(ShopPermissionKeys.editMedia) ||
        _can(ShopPermissionKeys.manageEnvironment) ||
        _can(ShopPermissionKeys.manageAbout) ||
        _can(ShopPermissionKeys.manageModules) ||
        _can(ShopPermissionKeys.manageMembers);

    final canSeeCatHotel =
        _can(ShopPermissionKeys.manageBookings) ||
        _can(ShopPermissionKeys.manageBookingSettings) ||
        _can(ShopPermissionKeys.manageRoomDashboard) ||
        _can(ShopPermissionKeys.manageRoomTypes) ||
        _can(ShopPermissionKeys.manageRooms) ||
        _can(ShopPermissionKeys.managePaymentSettings) ||
        _can(ShopPermissionKeys.managePolicy);

    final canSeeReports =
        _can(ShopPermissionKeys.viewReports) ||
        _can(ShopPermissionKeys.viewActionLogs);

    if (enabledModules.contains(ShopModules.basicInfo) &&
        (canSeeBasicInfo || _currentUserRole == ShopRoles.staff)) {
      result.add(ShopModules.basicInfo);
    }

    if (enabledModules.contains(ShopModules.catHotel) && canSeeCatHotel) {
      result.add(ShopModules.catHotel);
    }

    if (enabledModules.contains(ShopModules.reports) && canSeeReports) {
      result.add(ShopModules.reports);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserRole == null) {
      return const Scaffold(body: Center(child: Text('查無店家權限')));
    }

    if (!_hasAnyDashboardPermission && _currentUserRole != ShopRoles.staff) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          title: const Text('權限限制'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ),
        body: const Center(child: Text('你沒有任何後台功能權限')),
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
          return const Scaffold(body: Center(child: Text('找不到店家資料')));
        }

        final isComplete = _isProfileComplete(shop);
        final enabledModules = ShopService.instance.normalizeEnabledModules(
          shop['enabledModules'],
        );
        final visibleModules = _buildVisibleModules(
          enabledModules: enabledModules,
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
                            memberData: _currentMemberData,
                          );
                        case ShopModules.catHotel:
                          return _CatHotelTab(
                            shopId: widget.shopId,
                            isProfileComplete: isComplete,
                            memberData: _currentMemberData,
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
                          return _ReportsTab(currentUserRole: _currentUserRole);
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
    required this.memberData,
  });

  final String shopId;
  final String? currentUserRole;
  final Map<String, dynamic>? memberData;
  bool _can(String permissionKey) {
    return ShopService.instance.hasPermission(memberData, permissionKey);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _MenuSectionTitle('會員系統'),

        if (_can(ShopPermissionKeys.manageMembers))
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('member_link_requests')
                .where('shopId', isEqualTo: shopId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;

              return _MenuTile(
                title: '會員管理',
                subtitle: count > 0
                    ? '查看會員資料與訂單紀錄｜有 $count 筆會員綁定申請'
                    : '查看會員資料與訂單紀錄',
                icon: Icons.people,
                enabled: true,
                badgeCount: count,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminMemberListPage(shopId: shopId),
                    ),
                  );
                },
              );
            },
          ),

        const _MenuSectionTitle('店家資料'),

        if (currentUserRole == ShopRoles.owner)
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

        if (_can(ShopPermissionKeys.editBusinessInfo))
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

        if (_can(ShopPermissionKeys.editMedia))
          _MenuTile(
            title: '店家封面 ',
            subtitle: '上傳封面圖片',
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

        const _MenuSectionTitle('前台內容'),

        if (_can(ShopPermissionKeys.manageEnvironment))
          _MenuTile(
            title: '環境介紹管理',
            subtitle: '設定環境照片、介紹文案與展示內容',
            icon: Icons.apartment_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopEnvironmentManagePage(shopId: shopId),
                ),
              );
            },
          ),

        if (_can(ShopPermissionKeys.manageAbout))
          _MenuTile(
            title: '關於我們管理',
            subtitle: '設定品牌故事、理念與介紹內容',
            icon: Icons.favorite_border,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopAboutManagePage(shopId: shopId),
                ),
              );
            },
          ),

        _MenuTile(
          title: '公告管理',
          subtitle: '新增、編輯、上下架店家公告',
          icon: Icons.campaign,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopAnnouncementManagePage(shopId: shopId),
              ),
            );
          },
        ),

        _MenuTile(
          title: '常見問題管理',
          subtitle: '新增、編輯、上下架常見問題',
          icon: Icons.help_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopFaqManagePage(shopId: shopId),
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
              MaterialPageRoute(builder: (_) => ShopPublicPage(shopId: shopId)),
            );
          },
        ),

        const _MenuSectionTitle('後台管理'),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shop_notifications')
              .snapshots(),
          builder: (context, snapshot) {
            final unreadCount = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return (data['shopId'] ?? '').toString() == shopId &&
                  (data['status'] ?? '').toString() == 'unread';
            }).length;

            return _MenuTile(
              title: '平台通知',
              subtitle: unreadCount > 0
                  ? '有 $unreadCount 則未讀平台通知'
                  : '查看平台發送的方案、停權、審核與系統通知',
              icon: Icons.notifications_active_outlined,
              badgeCount: unreadCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShopPlatformNotificationPage(shopId: shopId),
                  ),
                );
              },
            );
          },
        ),

        _MenuTile(
          title: '聯絡平台',
          subtitle: '向平台回報問題、提出需求或聯絡客服',
          icon: Icons.support_agent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopContactPlatformPage(shopId: shopId),
              ),
            );
          },
        ),

        _MenuTile(
          title: '模組設定',
          subtitle: currentUserRole == ShopRoles.owner
              ? '控制哪些模組顯示在後台'
              : '目前只有老闆可修改',
          icon: Icons.dashboard_customize,
          enabled: currentUserRole == ShopRoles.owner,
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
          subtitle: currentUserRole == ShopRoles.owner
              ? '用 Email 指定員工，並設定功能開關'
              : '目前只有老闆可修改',
          icon: Icons.admin_panel_settings,
          enabled: currentUserRole == ShopRoles.owner,
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
      ],
    );
  }
}

/// ===== 貓咪旅店分頁 =====
class _CatHotelTab extends StatelessWidget {
  const _CatHotelTab({
    required this.shopId,
    required this.isProfileComplete,
    required this.memberData,
  });

  final String shopId;
  final bool isProfileComplete;
  final Map<String, dynamic>? memberData;

  bool _can(String permissionKey) {
    return ShopService.instance.hasPermission(memberData, permissionKey);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _MenuSectionTitle('今日營運'),

        if (_can(ShopPermissionKeys.manageBookings))
          _BookingManageTile(
            shopId: shopId,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminBookingListPage(shopId: shopId),
                ),
              );
            },
          ),

        if (_can(ShopPermissionKeys.manageRoomDashboard))
          _RoomDashboardTile(
            shopId: shopId,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomDashboardPage(shopId: shopId),
                ),
              );
            },
          ),

        const _MenuSectionTitle('預約與房型設定'),

        if (_can(ShopPermissionKeys.manageBookingSettings))
          _MenuTile(
            title: '預約管理',
            subtitle: isProfileComplete ? '管理房數開放預約時間設定' : '請先完成基本資料',
            icon: Icons.calendar_month,
            enabled: isProfileComplete,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopBookingSettingsPage(shopId: shopId),
                ),
              );
            },
          ),

        if (_can(ShopPermissionKeys.manageRoomTypes))
          _MenuTile(
            title: '房型管理',
            subtitle: '設定房型、容量、價格與介紹內容',
            icon: Icons.home_work,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopRoomTypePage(shopId: shopId),
                ),
              );
            },
          ),

        if (_can(ShopPermissionKeys.manageRooms))
          _MenuTile(
            title: '房間管理',
            subtitle: '管理實際房號與房間開關',
            icon: Icons.meeting_room,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopRoomPage(shopId: shopId)),
              );
            },
          ),

        const _MenuSectionTitle('付款與加購'),

        if (_can(ShopPermissionKeys.managePaymentSettings))
          _MenuTile(
            title: '住宿加購 / 附加服務',
            subtitle: '設定時間加購、額外服務、價格與開關',
            icon: Icons.add_box,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopAddonPage(shopId: shopId),
                ),
              );
            },
          ),

        if (_can(ShopPermissionKeys.managePaymentSettings))
          _MenuTile(
            title: '付款 / 訂金設定',
            subtitle: '設定是否需要訂金、付款方式與收款資訊',
            icon: Icons.payments,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopPaymentSettingPage(shopId: shopId),
                ),
              );
            },
          ),

        const _MenuSectionTitle('規則與紀錄'),

        if (_can(ShopPermissionKeys.managePolicy))
          _MenuTile(
            title: '入住規則 / 貓咪條件',
            subtitle: '設定入住條款與貓咪入住條件',
            icon: Icons.rule,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopPolicyPage(shopId: shopId),
                ),
              );
            },
          ),

        _MenuTile(
          title: '條款同意紀錄',
          subtitle: '查看會員條款同意與簽署紀錄',
          icon: Icons.list_alt,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopPolicyLogsPage(shopId: shopId),
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
  const _ReportsTab({required this.currentUserRole});

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
        const _TemplateCard(title: '日期統計表', description: '先預留給每日預約、每日營收、房況統計。'),
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
  const _ModuleTemplateTab({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TemplateCard(title: title, description: description),
        const _TemplateCard(
          title: '功能清單預留',
          description: '這個模組目前先留位置，不一定顯示，不重做資料結構。',
        ),
      ],
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
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

class _RoomDashboardTile extends StatelessWidget {
  const _RoomDashboardTile({required this.shopId, required this.onTap});

  final String shopId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where(
            'status',
            whereIn: ['pending', 'payment_uploaded', 'confirmed', 'checked_in'],
          )
          .snapshots(),
      builder: (context, snapshot) {
        int unassignedCount = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final assignStatus = (data['assignStatus'] ?? '').toString();

            final roomId = (data['roomId'] ?? '').toString();

            if (assignStatus == 'unassigned' || roomId.isEmpty) {
              unassignedCount++;
            }
          }
        }

        return _MenuTile(
          title: '房務管理',
          subtitle: unassignedCount > 0
              ? '待分房 $unassignedCount 間 ・ 查看所有房間狀態'
              : '查看房況、待分房與入住狀態',
          icon: Icons.grid_view,
          badgeCount: unassignedCount,
          onTap: onTap,
        );
      },
    );
  }
}

class _BookingManageTile extends StatelessWidget {
  const _BookingManageTile({required this.shopId, required this.onTap});

  final String shopId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('shopId', isEqualTo: shopId)
          .where('status', whereIn: ['pending', 'payment_uploaded'])
          .snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        int paymentUploadedCount = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final status = (data['status'] ?? '').toString();

            final depositStatus = (data['depositStatus'] ?? '').toString();

            if (status == 'pending' || status == 'unpaid') {
              pendingCount++;
            }

            if (depositStatus == 'pending_review' &&
                status != 'completed' &&
                status != 'cancelled') {
              paymentUploadedCount++;
            }
          }
        }

        final totalCount = pendingCount + paymentUploadedCount;

        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),

            title: const Text('訂單管理'),

            subtitle: Text(
              '待確認 $pendingCount 筆 ・ 已回傳付款 $paymentUploadedCount 筆',
            ),

            trailing: totalCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const Icon(Icons.chevron_right),

            onTap: onTap,
          ),
        );
      },
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
    this.badgeCount = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
