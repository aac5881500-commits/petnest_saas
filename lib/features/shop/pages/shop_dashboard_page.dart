// 檔案名稱：lib/features/shop/pages/shop_dashboard_page.dart
// 功能說明：店家後台首頁，支援手機單欄與桌機多欄的響應式模組導覽。

import 'dart:math' as math;

import 'daily_care_setting_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/shop_member_permission_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/shop_task_center_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_app_bar_button.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_desktop_workspace.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_entry.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_test_panel.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_phone_preview.dart';
import 'package:petnest_saas/features/shop/pages/shop_basic_info_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_business_info_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_module_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_permission_settings_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_daycare_board_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daycare_settings_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_payment_center_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_pre_arrival_guide_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_custom_form_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_logs_page.dart';
import 'package:petnest_saas/features/room/pages/room_dashboard_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_addon_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_payment_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_manage_page.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_hub_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_contact_platform_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_theme_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_manage_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_platform_notification_page.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_payout_setting_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_device_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_review_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_redemption_list_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_inventory_list_page.dart';
import 'package:petnest_saas/features/shop/pages/inventory/shop_booking_supply_settings_page.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/services/daily_care_report_center_service.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_report_center_page.dart';

class ShopDashboardPage extends StatefulWidget {
  const ShopDashboardPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopDashboardPage> createState() => _ShopDashboardPageState();
}

class _ShopDashboardPageState extends State<ShopDashboardPage> {
  late final ShopAdminWorkspaceController _workspace =
      ShopAdminWorkspaceController();

  String? _currentUserRole;
  Map<String, dynamic>? _currentMemberData;
  bool _roleLoaded = false;
  bool _frontendPrefsLoaded = false;
  bool _frontendOpenPref = false;
  bool _chatSurfacesOnTop = false;
  bool _wasChatVisible = false;
  int _frontendHomeToken = 0;
  final GlobalKey _frontendTabBarViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRole();
    _updateLastActiveAt();
    _loadFrontendPrefs();
    _workspace.chat.addListener(_onChatSurfacesChanged);
  }

  @override
  void dispose() {
    _workspace.chat.removeListener(_onChatSurfacesChanged);
    _workspace.dispose();
    super.dispose();
  }

  Future<void> _updateLastActiveAt() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final doc = await userRef.get();
    final data = doc.data();

    final lastActiveAt = data?['lastActiveAt'];

    if (lastActiveAt is Timestamp) {
      final diff = DateTime.now().difference(lastActiveAt.toDate());

      if (diff.inMinutes < 10) {
        return;
      }
    }

    await userRef.set({
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      await ShopMemberPermissionService.instance.syncOwnerMembershipForShop(
        widget.shopId,
      );
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
      _workspace.canUseChat = _can(ShopPermissionKeys.manageChat);
      _workspace.bindChat(
        shopId: widget.shopId,
        uid: FirebaseAuth.instance.currentUser?.uid ?? 'anon',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
    }
  }

  String _frontendPrefUid() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  }

  String _frontendOpenPrefKey() {
    return 'shop_dashboard_frontend_open_${_frontendPrefUid()}_${widget.shopId}';
  }

  Future<void> _loadFrontendPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _frontendOpenPref = prefs.getBool(_frontendOpenPrefKey()) ?? false;
      _frontendPrefsLoaded = true;
    });
  }

  Future<void> _saveFrontendOpen(bool open) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_frontendOpenPrefKey(), open);
  }

  void _onChatSurfacesChanged() {
    final bool visible =
        _workspace.chat.inboxOpen || _workspace.chat.showDockWindows;
    if (visible && !_wasChatVisible) {
      _wasChatVisible = true;
      if (mounted && !_chatSurfacesOnTop) {
        setState(() {
          _chatSurfacesOnTop = true;
        });
      }
      return;
    }
    if (!visible) {
      _wasChatVisible = false;
    }
  }

  void _toggleFrontendPanel() {
    final bool next = !_frontendOpenPref;
    setState(() {
      _frontendOpenPref = next;
      if (next) {
        _chatSurfacesOnTop = false;
      }
    });
    _saveFrontendOpen(next);
  }

  void _openFrontendPanelAndGoHome() {
    setState(() {
      _frontendOpenPref = true;
      _frontendHomeToken++;
      _chatSurfacesOnTop = false;
    });
    _saveFrontendOpen(true);
  }

  void _closeFrontendPanel() {
    if (!_frontendOpenPref) {
      return;
    }
    setState(() {
      _frontendOpenPref = false;
    });
    _saveFrontendOpen(false);
  }

  void _handleFrontendPreview({required String shopCode, bool goHome = false}) {
    if (goHome) {
      _openFrontendPanelAndGoHome();
      return;
    }
    _toggleFrontendPanel();
  }

  Widget _buildFrontendAppBarButton({
    required bool canUse,
    required bool isProfileComplete,
    required bool canUsePublicPage,
    required bool panelOpen,
    required bool showLabel,
    required String shopCode,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String tooltip;
    if (!isProfileComplete) {
      tooltip = '請先完成基本資料';
    } else if (!canUsePublicPage) {
      tooltip = '升級方案解鎖';
    } else {
      tooltip = panelOpen ? '收起實際前台' : '開啟實際前台';
    }

    final VoidCallback? onPressed = !canUse
        ? null
        : () => _handleFrontendPreview(shopCode: shopCode);

    final bool selected = canUse && panelOpen;
    final Color? selectedColor = selected ? colors.primary : null;

    if (showLabel) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Tooltip(
          message: tooltip,
          child: TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: selectedColor ?? _DashboardLayout.ink,
              backgroundColor: selected
                  ? colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            icon: Icon(Icons.storefront_outlined, color: selectedColor),
            label: const Text('前台'),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: selected
          ? IconButton.styleFrom(
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              foregroundColor: colors.primary,
            )
          : null,
      icon: const Icon(Icons.storefront_outlined),
    );
  }

  bool _isProfileComplete(Map<String, dynamic> shop) {
    return (shop['phone'] ?? '').toString().trim().isNotEmpty &&
        (shop['address'] ?? '').toString().trim().isNotEmpty;
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
        _can(ShopPermissionKeys.manageFrontendContent) ||
        _can(ShopPermissionKeys.manageReviews);
    final canSeeCatHotel =
        _can(ShopPermissionKeys.manageBookings) ||
        _can(ShopPermissionKeys.manageBookingSettings) ||
        _can(ShopPermissionKeys.manageRoomDashboard) ||
        _can(ShopPermissionKeys.manageRoomTypes) ||
        _can(ShopPermissionKeys.manageRooms) ||
        _can(ShopPermissionKeys.managePaymentSettings) ||
        _can(ShopPermissionKeys.manageAddons) ||
        _can(ShopPermissionKeys.manageDevices) ||
        _can(ShopPermissionKeys.managePolicy) ||
        _can(ShopPermissionKeys.manageChat);
    final canSeeReports =
        _currentUserRole == ShopRoles.owner ||
        _can(ShopPermissionKeys.viewReports) ||
        _can(ShopPermissionKeys.viewActionLogs);
    final canSeeInventory =
        _currentUserRole == ShopRoles.owner ||
        _can(ShopPermissionKeys.viewInventory) ||
        _can(ShopPermissionKeys.manageInventory) ||
        _can(ShopPermissionKeys.receiveInventory) ||
        _can(ShopPermissionKeys.adjustInventory);
    final canSeeStore =
        _currentUserRole == ShopRoles.owner ||
        _can(ShopPermissionKeys.viewStoreOrders) ||
        _can(ShopPermissionKeys.manageStoreProducts) ||
        _can(ShopPermissionKeys.manageStoreOrders) ||
        _can(ShopPermissionKeys.manageStoreSettings);

    if (enabledModules.contains(ShopModules.basicInfo) &&
        (canSeeBasicInfo || _currentUserRole == ShopRoles.staff)) {
      result.add(ShopModules.basicInfo);
    }

    if (enabledModules.contains(ShopModules.catHotel) && canSeeCatHotel) {
      result.add(ShopModules.catHotel);
    }

    if (_currentUserRole == ShopRoles.owner ||
        (enabledModules.contains(ShopModules.reports) && canSeeReports)) {
      result.add(ShopModules.reports);
    }

    if (canSeeInventory) {
      result.add(ShopModules.inventory);
    }

    if (enabledModules.contains(ShopModules.store) && canSeeStore) {
      result.add(ShopModules.store);
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
      case ShopModules.inventory:
        return '庫存管理';
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
      case ShopModules.inventory:
        return Icons.inventory_2_outlined;
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

        final accountStatus = (shop['accountStatus'] ?? 'normal').toString();
        final shopStatus = (shop['status'] ?? 'active').toString();

        if (accountStatus == 'suspended' || shopStatus == 'suspended') {
          return Scaffold(
            appBar: AppBar(title: const Text('帳號停權')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 72, color: Colors.red),

                    const SizedBox(height: 20),

                    const Text(
                      '此店家帳號目前已停權',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text('如有疑問請聯絡平台處理', textAlign: TextAlign.center),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.support_agent),
                        label: const Text('聯絡平台'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopContactPlatformPage(
                                shopId: widget.shopId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        }

        final isComplete = _isProfileComplete(shop);
        final bool canUsePublicPage = ShopPlanService.canUsePublicPage(shop);
        final bool canOpenFrontend = isComplete && canUsePublicPage;
        final String shopCode = (shop['shopCode'] ?? '').toString().trim();
        final enabledModules = ShopService.instance.normalizeEnabledModules(
          shop['enabledModules'],
        );
        final visibleModules = _buildVisibleModules(
          enabledModules: enabledModules,
        );
        final ColorScheme colors = Theme.of(context).colorScheme;
        final double pageWidth = MediaQuery.sizeOf(context).width;
        final _DashboardMetrics metrics = _DashboardLayout.metrics(pageWidth);
        return ShopAdminWorkspaceScope(
          controller: _workspace,
          child: DefaultTabController(
            length: visibleModules.length,
            child: Scaffold(
              backgroundColor: _DashboardLayout.pageBg,
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: _DashboardLayout.ink,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  shop['name'] ?? '店家後台',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: metrics.appBarTitleSize,
                    fontWeight: FontWeight.w700,
                    color: _DashboardLayout.ink,
                  ),
                ),
                actions: <Widget>[
                  _buildFrontendAppBarButton(
                    canUse: canOpenFrontend,
                    isProfileComplete: isComplete,
                    canUsePublicPage: canUsePublicPage,
                    panelOpen: _frontendOpenPref && canOpenFrontend,
                    showLabel: pageWidth >= _DashboardLayout.phoneBreakpoint,
                    shopCode: shopCode,
                  ),
                  if (_can(ShopPermissionKeys.manageChat))
                    ShopChatAppBarButton(shopId: widget.shopId),
                  ShopTaskCenterButton(shopId: widget.shopId),
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: colors.primary,
                  unselectedLabelColor: const Color(0xFF4B5563),
                  labelStyle: TextStyle(
                    fontSize: metrics.tabLabelSelected,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: metrics.tabLabelUnselected,
                    fontWeight: FontWeight.w600,
                  ),
                  labelPadding: EdgeInsets.symmetric(
                    horizontal: metrics.tabLabelPadH,
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: UnderlineTabIndicator(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      width: metrics.tabIndicatorHeight,
                      color: colors.primary,
                    ),
                  ),
                  dividerColor: _DashboardLayout.cardBorder,
                  tabs: visibleModules
                      .map(
                        (module) => Tab(
                          height: metrics.tabHeight,
                          text: _moduleLabel(module),
                          icon: Icon(
                            _moduleIcon(module),
                            size: metrics.tabIconSize,
                          ),
                          iconMargin: EdgeInsets.only(
                            bottom: metrics.tabIconGap,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              body: Column(
                children: [
                  if (!isComplete)
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _DashboardLayout.maxContentWidth(pageWidth),
                        ),
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.fromLTRB(
                            metrics.pagePadH,
                            metrics.pagePadV,
                            metrics.pagePadH,
                            0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD8A8)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '⚠️ 請先完成店家基本資料，才能使用完整功能',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _DashboardLayout.ink,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Widget tabViews = TabBarView(
                              key: _frontendTabBarViewKey,
                              children: visibleModules.map((module) {
                                switch (module) {
                                  case ShopModules.basicInfo:
                                    return _BasicInfoTab(
                                      shopId: widget.shopId,
                                      shop: shop,
                                      currentUserRole: _currentUserRole,
                                      memberData: _currentMemberData,
                                      isProfileComplete: isComplete,
                                      onPreviewFrontend: () =>
                                          _handleFrontendPreview(
                                            shopCode: shopCode,
                                            goHome: true,
                                          ),
                                    );
                                  case ShopModules.catHotel:
                                    return _CatHotelTab(
                                      shopId: widget.shopId,
                                      shop: shop,
                                      isProfileComplete: isComplete,
                                      memberData: _currentMemberData,
                                    );
                                  case ShopModules.dogHotel:
                                    return const _ModuleTemplateTab(
                                      title: '狗狗旅店',
                                      description:
                                          '這裡先保留給狗狗住宿 / 寄宿 / 安親 / 預約管理模板。',
                                    );
                                  case ShopModules.grooming:
                                    return const _ModuleTemplateTab(
                                      title: '美容功能',
                                      description:
                                          '這裡先保留給美容預約、價目表、美容師排班、服務項目模板。',
                                    );
                                  case ShopModules.hospital:
                                    return const _ModuleTemplateTab(
                                      title: '動物醫院',
                                      description:
                                          '這裡先保留給門診預約、看診項目、醫師班表、病歷延伸模板。',
                                    );
                                  case ShopModules.store:
                                    return ShopStoreHubPage(
                                      shopId: widget.shopId,
                                      memberData: _currentMemberData,
                                    );
                                  case ShopModules.reports:
                                    return _ReportsTab(
                                      shopId: widget.shopId,
                                      currentUserRole: _currentUserRole,
                                    );
                                  case ShopModules.inventory:
                                    return _InventoryTab(
                                      shopId: widget.shopId,
                                      isProfileComplete: isComplete,
                                      memberData: _currentMemberData,
                                    );
                                  default:
                                    return const Center(child: Text('模組尚未定義'));
                                }
                              }).toList(),
                            );

                            final bool chatAllowed = _can(
                              ShopPermissionKeys.manageChat,
                            );
                            final bool frontendOpen =
                                _frontendPrefsLoaded &&
                                _frontendOpenPref &&
                                canOpenFrontend;
                            final double frontendScale =
                                ShopFrontendPhoneFrame.scaleFor(
                                  availableWidth: 430,
                                  availableHeight: math.max(
                                    200,
                                    constraints.maxHeight - 72,
                                  ),
                                );
                            final double frontendWidth =
                                430 * frontendScale + 16;

                            final Widget liveFrontend = ShopFrontendTestPanel(
                              key: ValueKey<String>(
                                'frontend-panel-${widget.shopId}',
                              ),
                              shopId: widget.shopId,
                              shopCode: shopCode,
                              homeResetToken: _frontendHomeToken,
                              onClose: _closeFrontendPanel,
                            );

                            return ListenableBuilder(
                              listenable: Listenable.merge(<Listenable>[
                                _workspace,
                                _workspace.chat,
                              ]),
                              builder: (BuildContext context, Widget? child) {
                                final bool desktopChatOpen =
                                    chatAllowed &&
                                    ShopChatLayout.shouldShowDesktopDock(
                                      pageWidth: pageWidth,
                                      inboxOpen: _workspace.chat.inboxOpen,
                                    );
                                final Widget frontendLayer = Positioned(
                                  key: ShopDashboardLiveFrontendOverlay
                                      .overlayKey,
                                  left: 12,
                                  top: 8,
                                  bottom: 12,
                                  width: frontendWidth,
                                  child: Listener(
                                    onPointerDown: (_) {
                                      if (_chatSurfacesOnTop) {
                                        setState(() {
                                          _chatSurfacesOnTop = false;
                                        });
                                      }
                                    },
                                    child: liveFrontend,
                                  ),
                                );
                                final List<Widget> chatLayers = <Widget>[
                                  if (desktopChatOpen)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: ShopChatLayout.dockWidthFor(
                                        pageWidth,
                                      ),
                                      child: Listener(
                                        onPointerDown: (_) {
                                          if (!_chatSurfacesOnTop) {
                                            setState(() {
                                              _chatSurfacesOnTop = true;
                                            });
                                          }
                                        },
                                        child: ShopChatDesktopWorkspace(
                                          shopId: widget.shopId,
                                          controller: _workspace.chat,
                                        ),
                                      ),
                                    ),
                                ];
                                return Stack(
                                  children: <Widget>[
                                    tabViews,
                                    if (frontendOpen && _chatSurfacesOnTop)
                                      frontendLayer,
                                    ...chatLayers,
                                    if (frontendOpen && !_chatSurfacesOnTop)
                                      frontendLayer,
                                  ],
                                );
                              },
                            );
                          },
                    ),
                  ),
                ],
              ),
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
    required this.shop,
    required this.currentUserRole,
    required this.memberData,
    required this.isProfileComplete,
    required this.onPreviewFrontend,
  });
  final Map<String, dynamic> shop;
  final String shopId;
  final String? currentUserRole;
  final Map<String, dynamic>? memberData;
  final bool isProfileComplete;
  final VoidCallback onPreviewFrontend;
  bool _can(String permissionKey) {
    return ShopService.instance.hasPermission(memberData, permissionKey);
  }

  @override
  Widget build(BuildContext context) {
    final canUsePublicPage = ShopPlanService.canUsePublicPage(shop);
    final canUseAnnouncement = ShopPlanService.canUseAnnouncement(shop);
    final canUseFaq = ShopPlanService.canUseFaq(shop);

    final canUseBusinessInfo = ShopPlanService.canUseBusinessInfo(shop);
    final canUseShopBanner = ShopPlanService.canUseShopBanner(shop);
    final canUseEnvironment = ShopPlanService.canUseEnvironment(shop);
    final canUseAboutUs = ShopPlanService.canUseAboutUs(shop);

    return _DashboardResponsiveBody(
      children: [
        _ShopPlanStatusCard(shopId: shopId),
        _DashboardSection(
          title: '店家資料',
          children: [
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
                subtitle: canUseBusinessInfo ? '設定營業時間與服務項目' : '升級方案解鎖',
                icon: Icons.schedule,
                enabled: canUseBusinessInfo,
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
                title: '店家封面',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseShopBanner ? '上傳封面圖片' : '升級方案解鎖'),
                icon: Icons.image,
                enabled: isProfileComplete && canUseShopBanner,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopMediaPage(shopId: shopId),
                    ),
                  );
                },
              ),
            if (currentUserRole == ShopRoles.owner)
              _MenuTile(
                title: '收款帳戶 / 金流設定',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : '管理銀行轉帳收款資料，未來金流設定也會放這裡',
                icon: Icons.account_balance,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopPayoutSettingPage(shopId: shopId),
                    ),
                  );
                },
              ),
          ],
        ),
        _DashboardSection(
          title: '前台內容',
          children: [
            if (_can(ShopPermissionKeys.manageFrontendContent))
              _MenuTile(
                title: '前台外觀設定',
                subtitle: !isProfileComplete ? '請先完成基本資料' : '設定首頁版型、主題顏色與整體外觀',
                icon: Icons.design_services_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopThemeSettingPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageFrontendContent))
              _MenuTile(
                title: '環境介紹管理',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseEnvironment ? '設定環境照片、介紹文案與展示內容' : '升級方案解鎖'),
                icon: Icons.apartment_rounded,
                enabled: isProfileComplete && canUseEnvironment,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopEnvironmentManagePage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageFrontendContent))
              _MenuTile(
                title: '關於我們管理',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseAboutUs ? '設定品牌故事、理念與介紹內容' : '升級方案解鎖'),
                icon: Icons.favorite_border,
                enabled: isProfileComplete && canUseAboutUs,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopAboutManagePage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageFrontendContent))
              _MenuTile(
                title: '公告管理',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseAnnouncement ? '新增、編輯、上下架店家公告' : '升級方案解鎖'),
                icon: Icons.campaign,
                enabled: isProfileComplete && canUseAnnouncement,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopAnnouncementManagePage(shopId: shopId),
                    ),
                  );
                },
              ),
            if (_can(ShopPermissionKeys.manageFrontendContent))
              _MenuTile(
                title: '常見問題管理',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseFaq ? '新增、編輯、上下架常見問題' : '升級方案解鎖'),
                icon: Icons.help_outline,
                enabled: isProfileComplete && canUseFaq,
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
              subtitle: !isProfileComplete
                  ? '請先完成基本資料'
                  : (canUsePublicPage ? '查看客戶看到的頁面' : '升級方案解鎖'),
              icon: Icons.visibility,
              enabled: isProfileComplete && canUsePublicPage,
              onTap: onPreviewFrontend,
            ),
          ],
        ),
        _DashboardSection(
          title: '會員系統',
          children: [
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
                    enabled: isProfileComplete,
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

            if (_can(ShopPermissionKeys.manageReviews))
              _MenuTile(
                title: '評價管理',
                subtitle: '查看客戶評價、照片與店家回覆',
                icon: Icons.star_rate_rounded,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminReviewListPage(shopId: shopId),
                    ),
                  );
                },
              ),
          ],
        ),
        _DashboardSection(
          title: '後台管理',
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shop_notifications')
                  .where('shopId', isEqualTo: shopId)
                  .where('status', isEqualTo: 'unread')
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
        ),
      ],
    );
  }
}

/// ===== 貓咪旅店分頁 =====
class _CatHotelTab extends StatelessWidget {
  const _CatHotelTab({
    required this.shopId,
    required this.shop,
    required this.isProfileComplete,
    required this.memberData,
  });

  final Map<String, dynamic> shop;
  final String shopId;
  final bool isProfileComplete;
  final Map<String, dynamic>? memberData;

  bool _can(String permissionKey) {
    return ShopService.instance.hasPermission(memberData, permissionKey);
  }

  @override
  Widget build(BuildContext context) {
    final canUseDepositSettings = ShopPlanService.canUseDepositSettings(shop);

    final canUsePolicySettings = ShopPlanService.canUsePolicySettings(shop);

    return _DashboardResponsiveBody(
      children: [
        _DashboardSection(
          title: '今日營運',
          children: [
            if (_can(ShopPermissionKeys.manageChat))
              Builder(
                builder: (BuildContext context) {
                  final ShopAdminWorkspaceController? workspace =
                      ShopAdminWorkspaceScope.maybeOf(context);
                  Widget tile(int unread) {
                    return _MenuTile(
                      title: '店家聊天',
                      subtitle: unread > 0
                          ? '${ShopChatService.badgeLabel(unread)} 則未讀訊息'
                          : '與會員即時聯絡',
                      icon: Icons.chat_bubble_outline,
                      badgeCount: unread > 99 ? 99 : unread,
                      onTap: () {
                        ShopChatEntry.open(
                          context,
                          shopId: shopId,
                          toggleDesktop: false,
                        );
                      },
                    );
                  }

                  if (workspace == null) {
                    return tile(0);
                  }
                  return ValueListenableBuilder<int>(
                    valueListenable: workspace.unreadCount,
                    builder: (BuildContext context, int unread, Widget? child) {
                      return tile(unread);
                    },
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageBookings))
              _BookingManageTile(
                shopId: shopId,
                enabled: isProfileComplete,
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
              _DailyCareReportCenterTile(
                shopId: shopId,
                profileComplete: isProfileComplete,
              ),
          ],
        ),
        StreamBuilder<DaycareSettingsModel>(
          stream: DaycareSettingsService.instance.stream(shopId),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<DaycareSettingsModel> daycareSnap,
              ) {
                final bool daycareOn = DaycareSettingsService.instance
                    .isEnabledForShop(shop: shop, settings: daycareSnap.data);
                final bool showBoard =
                    daycareOn &&
                    (_can(ShopPermissionKeys.viewDaycareBookings) ||
                        _can(ShopPermissionKeys.manageDaycareBookings));
                final bool showSettings =
                    daycareOn && _can(ShopPermissionKeys.manageDaycareSettings);
                final List<Widget> daycareTiles = <Widget>[];
                if (showBoard) {
                  daycareTiles.add(
                    _MenuTile(
                      title: '今日安親看板',
                      subtitle: isProfileComplete
                          ? '只看今天需操作的安親：待確認、等待送達、安親中、即將接回、已超時。'
                          : '請先完成基本資料',
                      icon: Icons.today,
                      enabled: isProfileComplete,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AdminDaycareBoardPage(shopId: shopId),
                          ),
                        );
                      },
                    ),
                  );
                }
                if (showSettings) {
                  daycareTiles.add(
                    _MenuTile(
                      title: '安親設定',
                      subtitle: isProfileComplete
                          ? '時間、方案、加購、付款與入口卡片'
                          : '請先完成基本資料',
                      icon: Icons.settings_suggest_outlined,
                      enabled: isProfileComplete,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ShopDaycareSettingsPage(shopId: shopId),
                          ),
                        );
                      },
                    ),
                  );
                }
                if (daycareTiles.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _DashboardSection(
                  title: showBoard ? '安親' : null,
                  children: daycareTiles,
                );
              },
        ),
        if (_can(ShopPermissionKeys.manageRoomDashboard))
          _DashboardSection(
            title: '房務管理',
            children: [
              _RoomDashboardTile(
                shopId: shopId,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomDashboardPage(shopId: shopId),
                    ),
                  );
                },
              ),
            ],
          ),
        _DashboardSection(
          title: '預約與房型設定',
          children: [
            if (_can(ShopPermissionKeys.manageBookingSettings) ||
                _can(ShopPermissionKeys.manageRoomTypes) ||
                _can(ShopPermissionKeys.manageRooms))
              _MenuTile(
                title: '房型與預約設定',
                subtitle: isProfileComplete ? '依序設定房型、實體房間與預約開放規則' : '請先完成基本資料',
                icon: Icons.home_work_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopBookingSetupCenterPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageBookingSettings) ||
                _can(ShopPermissionKeys.managePolicy))
              _MenuTile(
                title: '入住／安親前準備',
                subtitle: isProfileComplete ? '設定入住前需要攜帶與注意的內容' : '請先完成基本資料',
                icon: Icons.checklist_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopPreArrivalGuideSettingPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageDevices))
              _MenuTile(
                title: '設備管理',
                subtitle: isProfileComplete ? '管理攝影機、溫度監控與房間設備' : '請先完成基本資料',
                icon: Icons.sensors,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDevicePage(shopId: shopId),
                    ),
                  );
                },
              ),
          ],
        ),
        _DashboardSection(
          title: '價格、付款與加購',
          children: [
            if (_can(ShopPermissionKeys.managePaymentSettings))
              _MenuTile(
                title: '金流中心',
                subtitle: isProfileComplete ? '查看交易紀錄、付款狀態與金流資料' : '請先完成基本資料',
                icon: Icons.payments_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminPaymentCenterPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageAddons))
              _MenuTile(
                title: '住宿加購 / 附加服務',
                subtitle: isProfileComplete ? '設定時間加購、額外服務、價格與開關' : '請先完成基本資料',
                icon: Icons.add_box,
                enabled: isProfileComplete,
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
                title: '營運設定',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUseDepositSettings ? '設定訂金、優惠與點數制度' : '升級方案解鎖'),
                icon: Icons.payments,
                enabled: isProfileComplete && canUseDepositSettings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopPaymentSettingPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.managePointRedemptions))
              _MenuTile(
                title: '實體商品核銷中心',
                subtitle: isProfileComplete ? '搜尋領取碼、查看待領取商品及完成交付' : '請先完成基本資料',
                icon: Icons.inventory_2_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointRedemptionListPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),
          ],
        ),
        _DashboardSection(
          title: '規則與紀錄',
          children: [
            if (_can(ShopPermissionKeys.managePolicy))
              _MenuTile(
                title: '入住規則 / 貓咪條件',
                subtitle: !isProfileComplete
                    ? '請先完成基本資料'
                    : (canUsePolicySettings ? '設定入住條款與貓咪入住條件' : '升級方案解鎖'),
                icon: Icons.rule,
                enabled: isProfileComplete && canUsePolicySettings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopPolicyPage(shopId: shopId),
                    ),
                  );
                },
              ),

            if (_can(ShopPermissionKeys.manageBookingSettings))
              _MenuTile(
                title: '自訂表單設定',
                subtitle: isProfileComplete
                    ? '設定新增寵物與送出訂單時要填寫的自訂問題'
                    : '請先完成基本資料',
                icon: Icons.edit_note_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ShopCustomFormSettingsPage(shopId: shopId),
                    ),
                  );
                },
              ),

            _MenuTile(
              title: '條款同意紀錄',
              subtitle: isProfileComplete ? '查看會員條款同意與簽署紀錄' : '請先完成基本資料',
              icon: Icons.list_alt,
              enabled: isProfileComplete,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopPolicyLogsPage(shopId: shopId),
                  ),
                );
              },
            ),
            _MenuTile(
              title: '每日照護紀錄設定',
              subtitle: isProfileComplete
                  ? '設定每日回報次數、照護項目、照片與退房下載期限'
                  : '請先完成基本資料',
              icon: Icons.pets_outlined,
              enabled: isProfileComplete,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyCareSettingPage(shopId: shopId),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// ===== 庫存管理分頁 =====
class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
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
    return _DashboardResponsiveBody(
      children: [
        _DashboardSection(
          title: '中央庫存',
          children: [
            if (_can(ShopPermissionKeys.viewInventory) ||
                _can(ShopPermissionKeys.manageInventory) ||
                _can(ShopPermissionKeys.receiveInventory) ||
                _can(ShopPermissionKeys.adjustInventory))
              _MenuTile(
                title: '庫存管理',
                subtitle: isProfileComplete
                    ? '管理庫存品項、進貨、出庫、盤點與異動流水'
                    : '請先完成基本資料',
                icon: Icons.inventory_2_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return ShopInventoryListPage(
                          shopId: shopId,
                          memberData: memberData,
                        );
                      },
                    ),
                  );
                },
              ),
            if (_can(ShopPermissionKeys.manageInventory) ||
                _can(ShopPermissionKeys.viewInventory))
              _MenuTile(
                title: '住宿耗材設定',
                subtitle: isProfileComplete ? '設定入住必要用品，可選擇綁定中央庫存' : '請先完成基本資料',
                icon: Icons.cleaning_services_outlined,
                enabled: isProfileComplete,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return ShopBookingSupplySettingsPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// ===== 表格統計分頁 =====
class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.shopId, required this.currentUserRole});

  final String shopId;
  final String? currentUserRole;

  bool get _isOwner => currentUserRole == ShopRoles.owner;

  @override
  Widget build(BuildContext context) {
    return _DashboardResponsiveBody(
      children: [
        _DashboardSection(
          title: '營運報表',
          children: [
            _MenuTile(
              title: '營運報表中心',
              subtitle: '營運總覽、日期、營收、房型、加購、會員與 Excel 匯出',
              icon: Icons.analytics,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopReportPage(shopId: shopId),
                  ),
                );
              },
            ),
            _TemplateCard(
              title: '老闆專屬內容',
              description: _isOwner ? '未來可放金流分析、成本分析與進階統計' : '此區未來只開放 owner 查看',
              locked: !_isOwner,
            ),
          ],
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
    return _DashboardResponsiveBody(
      children: [
        _DashboardSection(
          title: title,
          children: [
            _TemplateCard(title: title, description: description),
            const _TemplateCard(
              title: '功能清單預留',
              description: '這個模組目前先留位置，不一定顯示，不重做資料結構。',
            ),
          ],
        ),
      ],
    );
  }
}

class _ShopPlanStatusCard extends StatelessWidget {
  const _ShopPlanStatusCard({required this.shopId});

  final String shopId;

  String _planName(String plan) {
    switch (plan) {
      case 'basic':
        return '專業版';

      case 'pro':
        return '旗艦版';

      case 'free':
        return '免費版';

      default:
        return '免費版';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final plan = (data['plan'] ?? 'free').toString();
        final status = (data['status'] ?? 'active').toString();
        final paidUntil = data['paidUntil'];

        var expireText = '尚未設定';
        if (paidUntil is Timestamp) {
          final date = paidUntil.toDate();
          expireText =
              '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
        }

        final now = DateTime.now();

        int? daysLeft;

        if (paidUntil is Timestamp) {
          daysLeft = paidUntil.toDate().difference(now).inDays;
        }

        Color color;
        String statusText;

        if (status == 'suspended') {
          color = Colors.red;
          statusText = '已停權';
        } else if (daysLeft != null && daysLeft < 0) {
          color = Colors.red;
          statusText = '已到期';
        } else if (daysLeft != null && daysLeft <= 7) {
          color = Colors.orange;
          statusText = '即將到期';
        } else {
          color = Colors.green;
          statusText = '正常使用';
        }

        final _DashboardMetrics metrics = _DashboardLayout.metrics(
          MediaQuery.sizeOf(context).width,
        );
        final bool phone = metrics.isPhone;
        final Widget iconBox = Container(
          width: phone ? 34 : (metrics.isDesktop ? 46 : 42),
          height: phone ? 34 : (metrics.isDesktop ? 46 : 42),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(phone ? 10 : 12),
          ),
          child: Icon(
            Icons.workspace_premium,
            color: color,
            size: phone ? 18 : (metrics.isDesktop ? 24 : 22),
          ),
        );
        final Widget statusChip = Container(
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 8 : 10,
            vertical: phone ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: phone ? 11 : 13,
            ),
          ),
        );
        Widget metric(String label, Widget value) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: metrics.isDesktop ? 13 : 12,
                  color: _DashboardLayout.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              value,
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(phone ? 11 : (metrics.isDesktop ? 19 : 14)),
          decoration: _DashboardLayout.cardDecorationFor(metrics),
          child: phone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconBox,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '目前方案：${_planName(plan)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _DashboardLayout.ink,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        statusChip,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text(
                          '到期：$expireText',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _DashboardLayout.muted,
                          ),
                        ),
                        Text(
                          daysLeft == null ? '剩餘：—' : '剩餘：$daysLeft 天',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _DashboardLayout.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '目前方案：${_planName(plan)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: metrics.isDesktop ? 19 : 17,
                          fontWeight: FontWeight.w700,
                          color: _DashboardLayout.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: metric(
                        '到期時間',
                        Text(
                          expireText,
                          style: TextStyle(
                            fontSize: metrics.isDesktop ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: _DashboardLayout.ink,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: metric(
                        '剩餘天數',
                        Text(
                          daysLeft == null ? '—' : '$daysLeft 天',
                          style: TextStyle(
                            fontSize: metrics.isDesktop ? 15 : 14,
                            fontWeight: FontWeight.w600,
                            color: _DashboardLayout.ink,
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: metric('使用狀態', statusChip)),
                  ],
                ),
        );
      },
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
    return _MenuTile(
      title: title,
      subtitle: description,
      icon: locked ? Icons.lock : Icons.grid_view_rounded,
      enabled: !locked,
    );
  }
}

class _RoomDashboardTile extends StatelessWidget {
  const _RoomDashboardTile({
    required this.shopId,
    required this.onTap,
    required this.enabled,
  });

  final String shopId;
  final VoidCallback onTap;
  final bool enabled;

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

        return StreamBuilder<ShopTaskCenterSnapshot>(
          stream: ShopTaskCenterService.instance.streamSnapshot(
            shopId: shopId,
            canViewBookings: false,
            canFillDailyCare: true,
          ),
          builder: (context, taskSnapshot) {
            final int checkedInRooms =
                taskSnapshot.data?.checkedInRoomCount ?? 0;
            final int carePending = taskSnapshot.data?.dailyCareCount ?? 0;

            return _MenuTile(
              title: '房務管理',
              subtitle: !enabled
                  ? '請先完成基本資料'
                  : '入住 $checkedInRooms 房・照護待填 $carePending 筆',
              icon: Icons.grid_view,
              enabled: enabled,
              badgeCount: enabled ? unassignedCount : 0,
              onTap: onTap,
            );
          },
        );
      },
    );
  }
}

class _DailyCareReportCenterTile extends StatelessWidget {
  const _DailyCareReportCenterTile({
    required this.shopId,
    required this.profileComplete,
  });

  final String shopId;
  final bool profileComplete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyCareReportCenterSnapshot>(
      stream: DailyCareReportCenterService.instance.streamToday(
        shopId: shopId,
        canOperate: profileComplete,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DailyCareReportCenterSnapshot> snapshot,
          ) {
            final DailyCareReportCenterSnapshot data =
                snapshot.data ?? DailyCareReportCenterSnapshot.empty;
            if (snapshot.hasError || data.hasError) {
              return _MenuTile(
                title: '每日回報中心',
                subtitle: profileComplete ? '目前無法取得每日回報' : '請先完成基本資料',
                icon: Icons.assignment_turned_in_outlined,
                enabled: false,
              );
            }
            if (!data.settingEnabled) {
              return const SizedBox.shrink();
            }
            return _MenuTile(
              title: '每日回報中心',
              subtitle: DailyCareReportCenterMenuCopy.subtitle(
                profileComplete: profileComplete,
                snapshot: data,
              ),
              icon: Icons.assignment_turned_in_outlined,
              enabled: profileComplete,
              badgeCount: profileComplete ? data.pendingCount : 0,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DailyCareReportCenterPage(
                      shopId: shopId,
                      canOperate: profileComplete,
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}

class _BookingManageTile extends StatelessWidget {
  const _BookingManageTile({
    required this.shopId,
    required this.onTap,
    required this.enabled,
  });

  final String shopId;
  final VoidCallback onTap;
  final bool enabled;
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
        int unreadMessageCount = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final status = (data['status'] ?? '').toString();

            final depositStatus = (data['depositStatus'] ?? '').toString();

            final shopUnreadMessageCount =
                (data['shopUnreadMessageCount'] ?? 0) as int;

            unreadMessageCount += shopUnreadMessageCount;

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

        final totalCount =
            pendingCount + paymentUploadedCount + unreadMessageCount;

        return _MenuTile(
          title: '訂單管理',
          subtitle: enabled
              ? '待確認 $pendingCount 筆 ・ 已回傳付款 $paymentUploadedCount 筆 ・ 新留言 $unreadMessageCount 則'
              : '請先完成基本資料',
          icon: Icons.receipt_long,
          enabled: enabled,
          badgeCount: totalCount,
          onTap: onTap,
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
    this.onTap,
    this.enabled = true,
    this.badgeCount = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _DashboardMetrics metrics = _DashboardLayout.metrics(
      MediaQuery.sizeOf(context).width,
    );
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: _DashboardLayout.cardDecorationFor(metrics),
          child: InkWell(
            onTap: enabled && onTap != null ? onTap : null,
            borderRadius: BorderRadius.circular(metrics.cardRadius),
            mouseCursor: enabled && onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            hoverColor: colors.primary.withValues(alpha: 0.04),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: metrics.tileMinHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.tilePadH,
                  vertical: metrics.tilePadV,
                ),
                child: Row(
                  children: [
                    Container(
                      width: metrics.iconBox,
                      height: metrics.iconBox,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(metrics.iconRadius),
                      ),
                      child: Icon(
                        icon,
                        color: colors.primary,
                        size: metrics.iconSize,
                      ),
                    ),
                    SizedBox(width: metrics.iconTextGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: metrics.titleSize,
                              fontWeight: FontWeight.w700,
                              color: _DashboardLayout.ink,
                              height: metrics.titleHeight,
                            ),
                          ),
                          SizedBox(height: metrics.titleSubtitleGap),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: metrics.subtitleSize,
                              color: _DashboardLayout.muted,
                              height: metrics.subtitleHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: metrics.badgeMin,
                          minHeight: metrics.badgeMin,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$badgeCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: metrics.badgeFont,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: metrics.chevronSize,
                      color: _DashboardLayout.muted.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.density,
    required this.appBarTitleSize,
    required this.tabHeight,
    required this.tabIconSize,
    required this.tabIconGap,
    required this.tabLabelSelected,
    required this.tabLabelUnselected,
    required this.tabLabelPadH,
    required this.tabIndicatorHeight,
    required this.pagePadH,
    required this.pagePadV,
    required this.itemGap,
    required this.sectionGap,
    required this.sectionPad,
    required this.sectionRadius,
    required this.sectionTitleSize,
    required this.sectionBarW,
    required this.sectionBarH,
    required this.sectionTitleGap,
    required this.tileMinHeight,
    required this.tilePadH,
    required this.tilePadV,
    required this.iconBox,
    required this.iconSize,
    required this.iconRadius,
    required this.iconTextGap,
    required this.titleSize,
    required this.titleHeight,
    required this.subtitleSize,
    required this.subtitleHeight,
    required this.titleSubtitleGap,
    required this.chevronSize,
    required this.badgeMin,
    required this.badgeFont,
    required this.cardRadius,
    required this.cardShadowBlur,
    required this.cardShadowAlpha,
  });

  final _DashboardDensity density;
  final double appBarTitleSize;
  final double tabHeight;
  final double tabIconSize;
  final double tabIconGap;
  final double tabLabelSelected;
  final double tabLabelUnselected;
  final double tabLabelPadH;
  final double tabIndicatorHeight;
  final double pagePadH;
  final double pagePadV;
  final double itemGap;
  final double sectionGap;
  final double sectionPad;
  final double sectionRadius;
  final double sectionTitleSize;
  final double sectionBarW;
  final double sectionBarH;
  final double sectionTitleGap;
  final double tileMinHeight;
  final double tilePadH;
  final double tilePadV;
  final double iconBox;
  final double iconSize;
  final double iconRadius;
  final double iconTextGap;
  final double titleSize;
  final double titleHeight;
  final double subtitleSize;
  final double subtitleHeight;
  final double titleSubtitleGap;
  final double chevronSize;
  final double badgeMin;
  final double badgeFont;
  final double cardRadius;
  final double cardShadowBlur;
  final double cardShadowAlpha;

  bool get isPhone => density == _DashboardDensity.phone;
  bool get isDesktop => density == _DashboardDensity.desktop;
}

enum _DashboardDensity { phone, tablet, desktop }

class _DashboardLayout {
  static const Color pageBg = Color(0xFFF7F8FC);
  static const Color ink = Color(0xFF20242C);
  static const Color muted = Color(0xFF667085);
  static const Color cardBorder = Color(0xFFE6EAF0);
  static const double phoneBreakpoint = 720;
  static const double desktopBreakpoint = 1100;
  static const double tabletMaxWidth = 1000;
  static const double desktopMaxWidth = 1280;
  static const double minComfortableTripleCol = 920;

  static const _DashboardMetrics phone = _DashboardMetrics(
    density: _DashboardDensity.phone,
    appBarTitleSize: 18,
    tabHeight: 45,
    tabIconSize: 18,
    tabIconGap: 2,
    tabLabelSelected: 12,
    tabLabelUnselected: 11.5,
    tabLabelPadH: 10,
    tabIndicatorHeight: 2.5,
    pagePadH: 10,
    pagePadV: 10,
    itemGap: 7,
    sectionGap: 15,
    sectionPad: 0,
    sectionRadius: 14,
    sectionTitleSize: 14,
    sectionBarW: 3,
    sectionBarH: 14,
    sectionTitleGap: 8,
    tileMinHeight: 60,
    tilePadH: 10,
    tilePadV: 8,
    iconBox: 34,
    iconSize: 18,
    iconRadius: 10,
    iconTextGap: 10,
    titleSize: 15,
    titleHeight: 1.18,
    subtitleSize: 12,
    subtitleHeight: 1.25,
    titleSubtitleGap: 2,
    chevronSize: 18,
    badgeMin: 22,
    badgeFont: 11,
    cardRadius: 14,
    cardShadowBlur: 8,
    cardShadowAlpha: 0.035,
  );

  static const _DashboardMetrics tablet = _DashboardMetrics(
    density: _DashboardDensity.tablet,
    appBarTitleSize: 20,
    tabHeight: 52,
    tabIconSize: 20,
    tabIconGap: 3,
    tabLabelSelected: 13,
    tabLabelUnselected: 12,
    tabLabelPadH: 16,
    tabIndicatorHeight: 3,
    pagePadH: 20,
    pagePadV: 18,
    itemGap: 11,
    sectionGap: 18,
    sectionPad: 16,
    sectionRadius: 18,
    sectionTitleSize: 16,
    sectionBarW: 4,
    sectionBarH: 16,
    sectionTitleGap: 12,
    tileMinHeight: 76,
    tilePadH: 14,
    tilePadV: 14,
    iconBox: 42,
    iconSize: 22,
    iconRadius: 12,
    iconTextGap: 12,
    titleSize: 16,
    titleHeight: 1.22,
    subtitleSize: 13,
    subtitleHeight: 1.3,
    titleSubtitleGap: 3,
    chevronSize: 20,
    badgeMin: 24,
    badgeFont: 12,
    cardRadius: 16,
    cardShadowBlur: 10,
    cardShadowAlpha: 0.045,
  );

  static const _DashboardMetrics desktop = _DashboardMetrics(
    density: _DashboardDensity.desktop,
    appBarTitleSize: 22,
    tabHeight: 56,
    tabIconSize: 22,
    tabIconGap: 4,
    tabLabelSelected: 14,
    tabLabelUnselected: 13,
    tabLabelPadH: 20,
    tabIndicatorHeight: 3,
    pagePadH: 26,
    pagePadV: 22,
    itemGap: 13,
    sectionGap: 22,
    sectionPad: 19,
    sectionRadius: 20,
    sectionTitleSize: 17,
    sectionBarW: 4,
    sectionBarH: 18,
    sectionTitleGap: 12,
    tileMinHeight: 84,
    tilePadH: 16,
    tilePadV: 16,
    iconBox: 46,
    iconSize: 24,
    iconRadius: 13,
    iconTextGap: 14,
    titleSize: 16.5,
    titleHeight: 1.22,
    subtitleSize: 13.5,
    subtitleHeight: 1.32,
    titleSubtitleGap: 4,
    chevronSize: 21,
    badgeMin: 24,
    badgeFont: 12,
    cardRadius: 16,
    cardShadowBlur: 12,
    cardShadowAlpha: 0.05,
  );

  static _DashboardMetrics metrics(double width) {
    if (width < phoneBreakpoint) return phone;
    if (width < desktopBreakpoint) return tablet;
    return desktop;
  }

  static int columns(double pageWidth, {double availableWidth = 0}) {
    final double inner = availableWidth > 0 ? availableWidth : pageWidth;
    if (inner < phoneBreakpoint) return 1;
    if (inner < desktopBreakpoint) return 2;
    if (inner < minComfortableTripleCol) return 2;
    return 3;
  }

  static double maxContentWidth(double width) {
    if (width < phoneBreakpoint) return width;
    if (width < desktopBreakpoint) return tabletMaxWidth;
    return desktopMaxWidth;
  }

  static BoxDecoration cardDecorationFor(_DashboardMetrics metrics) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(metrics.cardRadius),
      border: Border.all(color: cardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: metrics.cardShadowAlpha),
          blurRadius: metrics.cardShadowBlur,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}

class _DashboardResponsiveBody extends StatelessWidget {
  const _DashboardResponsiveBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final double pageWidth = MediaQuery.sizeOf(context).width;
    final _DashboardMetrics metrics = _DashboardLayout.metrics(pageWidth);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _DashboardLayout.maxContentWidth(pageWidth),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            metrics.pagePadH,
            metrics.pagePadV,
            metrics.pagePadH,
            metrics.pagePadV,
          ),
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: metrics.sectionGap),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _DashboardMetrics metrics = _DashboardLayout.metrics(
      MediaQuery.sizeOf(context).width,
    );
    final Widget header = title == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(bottom: metrics.sectionTitleGap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: metrics.sectionBarW,
                      height: metrics.sectionBarH,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: metrics.sectionTitleSize,
                          fontWeight: FontWeight.w700,
                          color: _DashboardLayout.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (metrics.isDesktop) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: _DashboardLayout.cardBorder,
                  ),
                ],
              ],
            ),
          );
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        _DashboardMenuGrid(children: children),
      ],
    );
    if (metrics.isPhone) return body;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.sectionPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(metrics.sectionRadius),
        border: Border.all(color: _DashboardLayout.cardBorder),
        boxShadow: metrics.isDesktop
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: body,
    );
  }
}

class _DashboardMenuGrid extends StatelessWidget {
  const _DashboardMenuGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double pageWidth = MediaQuery.sizeOf(context).width;
        final _DashboardMetrics metrics = _DashboardLayout.metrics(pageWidth);
        final int cols = _DashboardLayout.columns(
          pageWidth,
          availableWidth: constraints.maxWidth,
        );
        final double gap = metrics.itemGap;
        final double width = constraints.maxWidth;
        final double itemWidth = cols == 1
            ? width
            : (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
