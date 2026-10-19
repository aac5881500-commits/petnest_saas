// 檔案名稱：lib/features/auth/pages/home_page.dart
// 功能說明：登入後首頁、建立店家、我的店家列表、登出
// 🏠 HomePage（登入後首頁）

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/app_state_panel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/auth_service.dart';
import 'package:petnest_saas/core/services/shop_home_stats_service.dart';
import 'package:petnest_saas/core/models/shop_house_appearance.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/auth/pages/shop_activation_code_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_dashboard_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_shop_list_page.dart';
import 'package:petnest_saas/features/platform/pages/platform_admin_page.dart';
import 'package:petnest_saas/features/auth/widgets/my_shop_open_status_helper.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_card_media_page.dart';
import 'package:petnest_saas/features/auth/widgets/desktop_pwa_install_button.dart';
import 'package:petnest_saas/features/auth/widgets/shop_entry_panel.dart';
import 'package:petnest_saas/features/auth/widgets/shop_house_scene.dart';
import 'package:petnest_saas/core/services/notification_service.dart';
import 'package:petnest_saas/features/notifications/pages/notification_center_page.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/platform_root_admin.dart';
import 'package:petnest_saas/core/models/platform_admin_model.dart';
import 'package:petnest_saas/core/services/platform_admin_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<Map<String, dynamic>>>? _shopsFuture;
  final PageController _shopPageController = PageController();
  int _selectedShopIndex = 0;
  final Map<String, double> _shopHeroHeights = <String, double>{};
  String _heroLayoutKey = '';
  bool _hasShopIdentity = false;
  final Map<String, Future<Map<String, int>>> _shopStats = {};

  @override
  void initState() {
    super.initState();

    _shopsFuture = ShopService.instance.getMyShops();
  }

  @override
  void dispose() {
    _shopPageController.dispose();
    super.dispose();
  }

  Future<void> _reloadShops() async {
    _shopStats.clear();
    setState(() {
      _shopsFuture = ShopService.instance.getMyShops();
    });
  }

  Future<Map<String, int>> _statsFor(String shopId) {
    return _shopStats.putIfAbsent(
      shopId,
      () => ShopHomeStatsService.instance.getShopHomeStats(shopId),
    );
  }

  Future<void> _openCreateShopPage() async {
    final bool created = await ShopActivationCodePage.open(context);
    if (!mounted || !created) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('建立成功')));
    await _reloadShops();
  }

  String _businessTypeLabel(String value) {
    switch (value) {
      case 'cat_hotel':
        return '貓咪旅館';
      case 'dog_hotel':
        return '狗狗旅館';
      case 'grooming':
        return '寵物美容';
      case 'hospital':
        return '動物醫院';
      case 'shop':
        return '寵物賣場';
      default:
        return '其他服務';
    }
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'owner':
        return '店主';
      case 'manager':
        return '主管';
      case 'staff':
        return '員工';
      default:
        return value;
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _openShop(String shopId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShopDashboardPage(shopId: shopId),
      ),
    );
  }

  void _openShopMedia(
    String shopId, {
    required String coverUrl,
    required String logoUrl,
    required Object? houseAppearance,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MyShopCardMediaPage(
          shopId: shopId,
          coverUrl: coverUrl,
          logoUrl: logoUrl,
          houseAppearance: houseAppearance,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _reloadShops();
      }
    });
  }

  void _openFindShop() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PlatformShopListPage()),
    );
  }

  ShopEntryPanel _panelFor(
    Map<String, dynamic> shop, {
    Key? key,
    bool showHero = true,
    bool showDetails = true,
  }) {
    final String shopId = shop['shopId'].toString();
    final String shopCode =
        shop['shopCode']?.toString().trim().isNotEmpty == true
        ? shop['shopCode'].toString()
        : shopId;
    final ShopHouseAppearance appearance = ShopHouseAppearance.fromMap(
      shop['houseAppearance'],
    );
    return ShopEntryPanel(
      key: key,
      shopName: (shop['name'] ?? '未命名店家').toString(),
      shopId: shopId,
      shopCode: shopCode,
      businessType: _businessTypeLabel(shop['businessType']?.toString() ?? ''),
      city: shop['city']?.toString() ?? '',
      district: shop['district']?.toString() ?? '',
      role: _roleLabel(shop['role']?.toString() ?? ''),
      coverUrl:
          shop['platformHomeCoverUrl']?.toString().trim().isNotEmpty == true
          ? shop['platformHomeCoverUrl'].toString()
          : shop['coverUrl']?.toString() ?? '',
      logoUrl: shop['platformHomeLogoUrl']?.toString().trim().isNotEmpty == true
          ? shop['platformHomeLogoUrl'].toString()
          : shop['logoUrl']?.toString() ?? '',
      houseAppearance: appearance,
      fallbackLogoUrl: shop['logoUrl']?.toString() ?? '',
      fallbackCoverUrl: shop['coverUrl']?.toString() ?? '',
      isOpenNow: isShopOpenNow(
        isOpen: shop['isOpen'] == true,
        openTime: shop['openTime']?.toString() ?? '',
        closeTime: shop['closeTime']?.toString() ?? '',
      ),
      isPublic: shop['isPublic'] == true,
      enabledModules: List<String>.from(shop['enabledModules'] ?? <dynamic>[]),
      openTime: shop['openTime']?.toString() ?? '',
      closeTime: shop['closeTime']?.toString() ?? '',
      licenseNumber: shop['licenseNumber']?.toString() ?? '',
      taxId: shop['taxId']?.toString() ?? '',
      updatedAt: shop['updatedAt'],
      showHero: showHero,
      showDetails: showDetails,
      allowPhotoHint: shop['role']?.toString() == 'owner',
      statsFuture: _statsFor(shopId),
      onEnter: () => _openShop(shopId),
      onEditMedia: () => _openShopMedia(
        shopId,
        coverUrl: shop['platformHomeCoverUrl']?.toString() ?? '',
        logoUrl: shop['platformHomeLogoUrl']?.toString() ?? '',
        houseAppearance: shop['houseAppearance'],
      ),
    );
  }

  void _showShop(int index) {
    if (!_shopPageController.hasClients) {
      return;
    }
    _shopPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double width = MediaQuery.sizeOf(context).width;
    final bool desktop = width >= 1100;
    final bool tablet = width >= 700;
    final double horizontal = desktop ? 28 : (tablet ? 20 : 16);
    // 寬螢幕保留建築比例，同時提供照片與店務足夠的展示寬度。
    final double maxWidth = desktop ? 1400 + horizontal * 2 : double.infinity;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      appBar: AppBar(
        toolbarHeight: tablet ? 64 : 56,
        title: Image.asset(
          'assets/images/petnest_logo.png',
          height: tablet ? 40 : 32,
          fit: BoxFit.contain,
        ),
        actions: <Widget>[
          if (desktop) ...<Widget>[
            TextButton.icon(
              onPressed: _openFindShop,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('找店'),
            ),
            TextButton.icon(
              onPressed: _openCreateShopPage,
              icon: const Icon(Icons.add_business, size: 18),
              label: const Text('開店'),
            ),
            if (kIsWeb && _hasShopIdentity) const ShopDesktopAppNavButton(),
          ],
          _notificationButton(colors),
          _platformAdminButton(uid, compact: !tablet),
          _accountMenu(user, uid, showDesktopApp: desktop && kIsWeb),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors.brightness == Brightness.dark
                ? [const Color(0xFF252F30), const Color(0xFF292D25)]
                : [
                    const Color(0xFFF0F6F6),
                    const Color(0xFFFAF7EF),
                    const Color(0xFFEDF2E5),
                  ],
          ),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _pageHeading(colors, showShopActions: !desktop),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _shopsFuture,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                          ) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _ShopHomeLoading();
                            }
                            if (snapshot.hasError) {
                              _rememberShopIdentity(false);
                              return AppStatePanel(
                                title: '店家列表暫時無法載入',
                                message: '請確認網路連線後，重新載入你的店家。',
                                onRetry: _reloadShops,
                              );
                            }
                            final List<Map<String, dynamic>> shops =
                                snapshot.data ?? <Map<String, dynamic>>[];
                            _rememberShopIdentity(
                              shops.any((Map<String, dynamic> shop) {
                                final String role = '${shop['role'] ?? ''}';
                                return role == ShopRoles.owner ||
                                    role == ShopRoles.manager ||
                                    role == ShopRoles.staff;
                              }),
                            );
                            if (shops.isEmpty) {
                              return _EmptyShops(onCreate: _openCreateShopPage);
                            }
                            final int selected = _selectedShopIndex < 0
                                ? 0
                                : (_selectedShopIndex >= shops.length
                                      ? shops.length - 1
                                      : _selectedShopIndex);
                            if (selected != _selectedShopIndex) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted ||
                                    _selectedShopIndex == selected) {
                                  return;
                                }
                                setState(() => _selectedShopIndex = selected);
                                if (_shopPageController.hasClients) {
                                  _shopPageController.jumpToPage(selected);
                                }
                              });
                            }
                            final Map<String, dynamic> current =
                                shops[selected];
                            final double bounded = width > maxWidth
                                ? maxWidth
                                : width;
                            final double contentWidth =
                                bounded - horizontal * 2;
                            final double textScale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1);
                            final String layoutKey = '$contentWidth/$textScale';
                            if (_heroLayoutKey != layoutKey) {
                              _heroLayoutKey = layoutKey;
                              _shopHeroHeights.clear();
                            }
                            final double heroHeight =
                                _shopHeroHeights[current['shopId']
                                    .toString()] ??
                                ShopEntryPanel.heroHeightFor(
                                  contentWidth,
                                  textScale: textScale,
                                );
                            return ListView(
                              children: <Widget>[
                                if (desktop && shops.length > 1)
                                  _DesktopShopSwitch(
                                    name: (current['name'] ?? '未命名店家')
                                        .toString(),
                                    index: selected,
                                    count: shops.length,
                                    onPrevious: selected > 0
                                        ? () => _showShop(selected - 1)
                                        : null,
                                    onNext: selected < shops.length - 1
                                        ? () => _showShop(selected + 1)
                                        : null,
                                  ),
                                if (!desktop && shops.length > 1) ...<Widget>[
                                  _ShopPageCue(
                                    index: selected,
                                    count: shops.length,
                                    name: (current['name'] ?? '未命名店家')
                                        .toString(),
                                    onPrevious: selected > 0
                                        ? () => _showShop(selected - 1)
                                        : null,
                                    onNext: selected < shops.length - 1
                                        ? () => _showShop(selected + 1)
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  height: heroHeight,
                                  child: ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          dragDevices:
                                              const <PointerDeviceKind>{
                                                PointerDeviceKind.touch,
                                                PointerDeviceKind.mouse,
                                                PointerDeviceKind.stylus,
                                                PointerDeviceKind.trackpad,
                                              },
                                        ),
                                    child: PageView.builder(
                                      controller: _shopPageController,
                                      itemCount: shops.length,
                                      physics: shops.length < 2
                                          ? const NeverScrollableScrollPhysics()
                                          : const PageScrollPhysics(),
                                      onPageChanged: (int index) {
                                        setState(
                                          () => _selectedShopIndex = index,
                                        );
                                      },
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final shop = shops[index];
                                            final id = shop['shopId']
                                                .toString();
                                            return ShopHouseMeasuredBody(
                                              key: ValueKey<String>(
                                                '$id/$layoutKey',
                                              ),
                                              onHeight: (height) {
                                                if (!mounted ||
                                                    _heroLayoutKey !=
                                                        layoutKey ||
                                                    _shopHeroHeights[id] ==
                                                        height) {
                                                  return;
                                                }
                                                setState(
                                                  () => _shopHeroHeights[id] =
                                                      height,
                                                );
                                              },
                                              child: _panelFor(
                                                shop,
                                                showDetails: false,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _panelFor(
                                  current,
                                  key: ValueKey<String>(
                                    current['shopId'].toString(),
                                  ),
                                  showHero: false,
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeading(ColorScheme colors, {required bool showShopActions}) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: <Widget>[
            Text(
              '我的店家',
              style: text.headlineSmall?.copyWith(
                fontSize: showShopActions ? 24 : 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            if (showShopActions) ...<Widget>[
              TextButton.icon(
                onPressed: _openFindShop,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('找店'),
              ),
              TextButton.icon(
                onPressed: _openCreateShopPage,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增店家'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Icon(Icons.pets_outlined, size: 16, color: const Color(0xFFD4894C)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '歡迎回來，今天也一起照顧好每一位毛孩。',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant.withValues(
                    alpha: showShopActions ? 1 : 0.82,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notificationButton(ColorScheme colors) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream(),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int unreadCount = snapshot.data ?? 0;
        return IconButton(
          tooltip: '通知中心',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationCenterPage(),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Icon(Icons.notifications_outlined),
              if (unreadCount > 0)
                Positioned(
                  top: -6,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _platformAdminButton(String? uid, {required bool compact}) {
    return StreamBuilder<PlatformAdminModel?>(
      stream: PlatformAdminService.instance.streamCurrentAdmin(),
      builder:
          (BuildContext context, AsyncSnapshot<PlatformAdminModel?> snapshot) {
            final bool isRootAdmin = PlatformRootAdmin.isRoot(uid);
            final PlatformAdminModel? currentAdmin = snapshot.data;
            final bool canEnterPlatformAdmin =
                isRootAdmin || (currentAdmin != null && currentAdmin.enabled);
            if (!canEnterPlatformAdmin) {
              return const SizedBox.shrink();
            }
            void open() {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PlatformAdminPage(),
                ),
              );
            }

            if (compact) {
              return IconButton(
                tooltip: '平台後台',
                onPressed: open,
                icon: const Icon(Icons.admin_panel_settings_outlined),
              );
            }
            return TextButton.icon(
              onPressed: open,
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text('平台後台'),
            );
          },
    );
  }

  Widget _accountMenu(User? user, String? uid, {required bool showDesktopApp}) {
    return PopupMenuButton<String>(
      tooltip: '帳號',
      icon: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
      onSelected: (String value) async {
        if (value == 'desktop-app') {
          await showShopDesktopAppDialog(context);
          return;
        }
        if (value == 'logout') {
          await _logout();
        }
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '目前登入',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  uid ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (showDesktopApp && _hasShopIdentity)
            const PopupMenuItem<String>(
              value: 'desktop-app',
              child: Row(
                children: <Widget>[
                  Icon(Icons.computer_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('店家管理電腦版'),
                ],
              ),
            ),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: <Widget>[
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('登出'),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _rememberShopIdentity(bool value) {
    if (_hasShopIdentity == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasShopIdentity == value) return;
      setState(() => _hasShopIdentity = value);
    });
  }
}

class _DesktopShopSwitch extends StatelessWidget {
  const _DesktopShopSwitch({
    required this.name,
    required this.index,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final String name;
  final int index;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Row(
            children: <Widget>[
              _RoundShopArrow(tooltip: '上一家', onPressed: onPrevious),
              Expanded(
                child: Text(
                  '$name · ${index + 1} / $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _RoundShopArrow(
                tooltip: '下一家',
                icon: Icons.chevron_right,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopPageCue extends StatelessWidget {
  const _ShopPageCue({
    required this.index,
    required this.count,
    required this.name,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int count;
  final String name;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(
          children: <Widget>[
            _RoundShopArrow(tooltip: '上一家', onPressed: onPrevious),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (count > 5)
                    Text(
                      '${index + 1} / $count',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int dot = 0; dot < count; dot++) ...<Widget>[
                          if (dot > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: dot == index ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dot == index
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            _RoundShopArrow(
              tooltip: '下一家',
              icon: Icons.chevron_right,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundShopArrow extends StatelessWidget {
  const _RoundShopArrow({
    required this.tooltip,
    required this.onPressed,
    this.icon = Icons.chevron_left,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.primary,
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _EmptyShops extends StatelessWidget {
  const _EmptyShops({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.storefront_outlined, size: 40, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              '還沒有自己的店家',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '建立店家後，就可以開始管理預約與日常營運。',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_business),
              label: const Text('開店'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopHomeLoading extends StatelessWidget {
  const _ShopHomeLoading();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    Widget block(double height) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return ListView(
      children: <Widget>[
        block(220),
        const SizedBox(height: 14),
        block(120),
        const SizedBox(height: 12),
        block(160),
      ],
    );
  }
}
