// 檔案名稱：lib/features/shop/pages/shop_public_modern_page.dart
// 功能說明：讀取店家資料，顯示適合手機的緊湊型頂部與 Banner
// ✨ 店家新版前台首頁 Beta

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_actions.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_menu_button.dart';
import 'package:petnest_saas/features/shop/widgets/shop_dashboard_embedded_scope.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editable_home_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_editor_overlay.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_review_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_staying_daily_care_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_about_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_faq_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_review_list_page.dart';
import 'package:petnest_saas/features/shop/widgets/floating_contact_button.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/home_banner_navigation.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/featured_store_products_section.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_entrance_banner.dart';

class ShopPublicModernPage extends StatefulWidget {
  const ShopPublicModernPage({
    super.key,
    required this.shopId,
    this.platformPreview = false,
    this.isPreview = false,
    this.layoutCanvas = false,
    this.isEmbeddedAdminPreview = false,
    this.canvasMode = 'canvas',
    this.selectedSectionId,
    this.onSelectSection,
    this.onBrandStyleChanged,
    this.onHomeSectionOrderChanged,
    this.draftModernAppearance,
    this.draftLogoUrl,
    this.draftHomeBanners,
    this.initialPreviewBannerId,
    this.onPreviewBannerChanged,
    this.onPreviewTextSelected,
    this.onPreviewCtaSelected,
    this.previewImageBytes,
    this.previewSelectedTextId,
    this.previewCtaSelected = false,
  });

  final String shopId;
  final bool platformPreview;

  /// 外觀設定預覽：沿用這套首頁，但不導頁、不開聊天。
  final bool isPreview;

  /// 前台外觀的首頁編排畫布：只畫顧客首頁本體，不帶導覽殼層。
  final bool layoutCanvas;
  final bool isEmbeddedAdminPreview;

  /// 桌面、手機或對話框各自一份畫布時，key 要帶這個識別。
  final String canvasMode;
  final String? selectedSectionId;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<StoreBrandStyle>? onBrandStyleChanged;
  final ValueChanged<List<String>>? onHomeSectionOrderChanged;

  /// 尚未儲存的新版外觀。正式前台不傳，仍讀 Firestore。
  final Map<String, dynamic>? draftModernAppearance;

  /// 預覽用 Logo。正式前台不傳。
  final String? draftLogoUrl;

  /// 後台海報預覽用的草稿清單。正式前台不傳，仍讀 Firestore。
  final List<StoreBannerModel>? draftHomeBanners;

  /// 預覽時先顯示這張海報，並用草稿即時合成。
  final String? initialPreviewBannerId;
  final ValueChanged<StoreBannerModel>? onPreviewBannerChanged;
  final ValueChanged<String?>? onPreviewTextSelected;
  final VoidCallback? onPreviewCtaSelected;
  final Uint8List? previewImageBytes;
  final String? previewSelectedTextId;
  final bool previewCtaSelected;

  @override
  State<ShopPublicModernPage> createState() => _ShopPublicModernPageState();
}

class _ShopPublicModernPageState extends State<ShopPublicModernPage> {
  static const Color _backgroundColor = Color(0xFFFFFCF7);

  late final Stream<Map<String, dynamic>?> _shopStream;
  late final Stream<List<Map<String, dynamic>>> _roomTypesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _announcementsStream;
  final ScrollController _homeScroll = ScrollController();
  final ValueNotifier<Rect?> _menuRect = ValueNotifier<Rect?>(null);
  final ValueNotifier<Rect?> _contactRect = ValueNotifier<Rect?>(null);
  bool _canOpenAdmin = false;
  String _selectedNavId = FrontendNavigationRegistry.homeId;

  @override
  void initState() {
    super.initState();
    _shopStream = ShopService.instance.streamShop(widget.shopId);
    _roomTypesStream = ShopService.instance.streamRoomTypes(widget.shopId);
    _announcementsStream = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('announcements')
        .where('isPublished', isEqualTo: true)
        .snapshots();
    _loadAdminAccess();
  }

  Future<void> _loadAdminAccess() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final Map<String, dynamic>? data = await ShopService.instance
        .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _canOpenAdmin = shopMemberCanOpenAdmin(data?['role']?.toString());
    });
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    _menuRect.dispose();
    _contactRect.dispose();
    super.dispose();
  }

  void _scrollHomeToTop() {
    if (_homeScroll.hasClients) {
      _homeScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  FrontendNavigationLaunch _launch({
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
    required bool embeddedPreview,
    required FrontendNavigationConfig navigation,
    required FrontendNavShopState shopState,
  }) {
    return FrontendNavigationLaunch(
      shopId: widget.shopId,
      shop: shop,
      theme: theme,
      previewOnly: widget.layoutCanvas,
      isEmbeddedAdminPreview: embeddedPreview,
      shellTabs: navigation.usesBottomBar(MediaQuery.sizeOf(context).width),
      navigation: navigation,
      shopState: shopState,
      canOpenAdmin: _canOpenAdmin,
      onPreviewSelect: (String id) {
        if (!mounted) {
          return;
        }
        setState(() => _selectedNavId = id);
      },
      onScrollHomeToTop: _scrollHomeToTop,
      onReturnedToHome: () {
        if (!mounted) {
          return;
        }
        setState(() => _selectedNavId = FrontendNavigationRegistry.homeId);
      },
    );
  }

  ModernAppDrawer _modernDrawer({
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
    required FrontendNavigationConfig navigation,
    required bool embeddedPreview,
  }) {
    return ModernAppDrawer(
      shopId: widget.shopId,
      shop: shop,
      theme: theme,
      platformPreview: widget.platformPreview,
      navigation: navigation,
      previewOnly: widget.layoutCanvas,
      isEmbeddedAdminPreview: embeddedPreview,
      canOpenAdmin: _canOpenAdmin,
      selectedItemId: _selectedNavId,
      onPreviewSelect: (String id) {
        setState(() => _selectedNavId = id);
      },
      onScrollHomeToTop: _scrollHomeToTop,
    );
  }

  Widget _bottomBar({
    required Map<String, dynamic> shop,
    required HomeThemeModel theme,
    required FrontendNavigationConfig navigation,
    required FrontendNavShopState shopState,
    required bool embeddedPreview,
  }) {
    return ModernBottomNavigation(
      slots: navigation.resolvedBottomSlots(shopState),
      theme: theme,
      selectedId: _selectedNavId,
      appearance: navigation.bottomAppearance,
      surface: navigation.bottomSurface,
      onSelect: (FrontendNavigationItem item) {
        if (item.id == _selectedNavId) {
          if (item.id == FrontendNavigationRegistry.homeId) {
            _scrollHomeToTop();
          }
          return;
        }
        setState(() => _selectedNavId = item.id);
        _launch(
          shop: shop,
          theme: theme,
          embeddedPreview: embeddedPreview,
          navigation: navigation,
          shopState: shopState,
        ).open(context, item);
      },
    );
  }

  Widget _shopMenuButton({
    required Map<String, dynamic> shop,
    required String shopName,
    required HomeThemeModel theme,
    required FrontendNavigationConfig navigation,
    required bool embeddedPreview,
  }) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool allowNavigation = !embeddedPreview;
    return ShopMenuButton(
      shopId: widget.shopId,
      userId: userId,
      shopName: shopName,
      logoUrl: (shop['logoUrl'] ?? '').toString(),
      theme: theme,
      surface: navigation.bottomSurface,
      bottomBarHeight: ModernBottomNavigation.slotHeight(
        navigation.bottomAppearance,
        safeBottom,
      ),
      visible: _canOpenAdmin || embeddedPreview,
      persistPosition: allowNavigation && userId.isNotEmpty,
      allowNavigation: allowNavigation,
      peerRect: _contactRect,
      ownRect: _menuRect,
      onPlatform: () {
        if (!allowNavigation) {
          return;
        }
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
      },
      onAdmin: () {
        if (!allowNavigation) {
          return;
        }
        FrontendNavigationLaunch(
          shopId: widget.shopId,
          shop: shop,
          theme: theme,
          previewOnly: false,
          isEmbeddedAdminPreview: false,
        ).open(context, FrontendNavigationRegistry.find('admin')!);
      },
    );
  }

  ModernShopFooter _shopFooter({
    required Map<String, dynamic> shop,
    required String shopName,
    required HomeThemeModel theme,
  }) {
    return ModernShopFooter(
      shopId: widget.shopId,
      shop: shop,
      shopName: shopName,
      primaryColor: theme.primaryColor,
      darkTextColor: theme.textColor,
      secondaryTextColor: theme.secondaryTextColor,
      cardColor: theme.cardColor,
      borderColor: theme.cardBorderColor,
      isPreview: widget.isPreview || widget.layoutCanvas,
    );
  }

  Widget _shopInfoPanel({
    required Map<String, dynamic> shop,
    required String shopName,
    required HomeThemeModel theme,
  }) {
    return ModernShopInfoPanel(
      footer: _shopFooter(shop: shop, shopName: shopName, theme: theme),
    );
  }

  List<StoreBannerModel> _enabledHomeBanners(Map<String, dynamic> shop) {
    return HomeBannerService.instance.parseEnabledFrontBanners(shop);
  }

  void _openPage(Widget page) {
    if (!mounted || widget.isPreview || widget.layoutCanvas) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _shopStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(
              child: Text(
                '讀取失敗：${snapshot.error}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }

        final loadedShop = snapshot.data;

        if (loadedShop == null) {
          return const Scaffold(
            backgroundColor: _backgroundColor,
            body: Center(
              child: Text(
                '找不到店家資料',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          );
        }

        final Map<String, dynamic> shop = widget.draftLogoUrl == null
            ? loadedShop
            : <String, dynamic>{...loadedShop, 'logoUrl': widget.draftLogoUrl};
        final shopName = (shop['name'] ?? '店家').toString().trim();
        final rawHomeAppearance = shop['homeAppearance'];

        final homeAppearance = rawHomeAppearance is Map
            ? Map<String, dynamic>.from(rawHomeAppearance)
            : <String, dynamic>{};

        final rawModernAppearance =
            widget.draftModernAppearance ?? homeAppearance['modern'];

        final modernAppearance = rawModernAppearance is Map
            ? Map<String, dynamic>.from(rawModernAppearance)
            : <String, dynamic>{};
        final modernTheme = HomeThemeModel.fromMap(
          modernAppearance['themeColors'],
          fallback: const HomeThemeModel(
            backgroundColorValue: 0xFFFFFBF7,
            cardColorValue: 0xFFFFFFFF,
            cardBorderColorValue: 0xFFFFD9B3,
            primaryColorValue: 0xFFFF8A00,
            textColorValue: 0xFF3A2A20,
          ),
        );
        final hasHeaderSubtitleSetting = modernAppearance.containsKey(
          'headerSubtitle',
        );

        final headerSubtitle = hasHeaderSubtitleSetting
            ? (modernAppearance['headerSubtitle'] ?? '').toString().trim()
            : '讓每一隻貓咪都有溫暖的家';
        final storeHomeSetting = ModernStoreHomeSetting.fromMap(
          modernAppearance,
        );
        final bannerFrameSetting = ModernBannerFrameSetting.fromMap(
          modernAppearance,
        );
        final String logoUrl = (shop['logoUrl'] ?? '').toString();
        final StoreBrandStyle brandStyle = StoreBrandStyle.fromMap(
          modernAppearance,
          logoUrl: logoUrl,
        );

        final rawEnvironmentIntro = shop['environmentIntro'];

        final environmentIntro = rawEnvironmentIntro is Map
            ? Map<String, dynamic>.from(rawEnvironmentIntro)
            : <String, dynamic>{};

        final rawFacilityKeys = environmentIntro['facilityKeys'];

        final facilityKeys = <String>[];

        if (rawFacilityKeys is List) {
          for (final item in rawFacilityKeys) {
            final value = item.toString().trim();

            if (value.isNotEmpty) {
              facilityKeys.add(value);
            }
          }
        }

        final banners = widget.draftHomeBanners ?? _enabledHomeBanners(shop);
        final FrontendNavigationConfig navigation =
            FrontendNavigationConfig.fromMap(modernAppearance);
        final bool embeddedPreview =
            widget.isEmbeddedAdminPreview ||
            ShopDashboardEmbeddedScope.isEmbeddedInShopDashboard(context);
        final FrontendNavShopState navShop = FrontendNavShopState.fromShop(
          shop,
          showMemberCenter: modernTheme.drawerSetting.showMemberCenter,
          showShopMenus: modernTheme.drawerSetting.showShopMenus,
          loggedIn: FirebaseAuth.instance.currentUser != null,
        );
        final bool useBottomBar = navigation.usesBottomBar(
          MediaQuery.sizeOf(context).width,
        );
        final List<String> sectionOrder = HomeSectionOrder.normalize(
          modernAppearance['homeSectionOrder'],
        );
        final bool showAnnouncements = shop['showAnnouncementSection'] != false;
        final List<String> visibleSections = HomeSectionOrder.visible(
          sectionOrder,
          showAnnouncements: showAnnouncements,
        );
        Widget sectionBody(String sectionId) {
          return _homeSection(
            sectionId: sectionId,
            shop: shop,
            shopName: shopName,
            headerSubtitle: headerSubtitle,
            brandStyle: brandStyle,
            logoUrl: logoUrl,
            theme: modernTheme,
            facilityKeys: facilityKeys,
            banners: banners,
            storeHomeSetting: storeHomeSetting,
            frameSetting: bannerFrameSetting,
            useBottomBar: useBottomBar,
          );
        }

        if (widget.layoutCanvas) {
          return _buildLayoutCanvas(
            shop: shop,
            shopName: shopName,
            theme: modernTheme,
            navigation: navigation,
            navShop: navShop,
            embeddedPreview: embeddedPreview,
            useBottomBar: useBottomBar,
            sectionOrder: sectionOrder,
            visibleSectionIds: visibleSections,
            buildSection: sectionBody,
          );
        }

        return Scaffold(
          extendBody: useBottomBar,
          backgroundColor: modernTheme.backgroundColor,

          drawer: useBottomBar
              ? null
              : _modernDrawer(
                  shop: shop,
                  theme: modernTheme,
                  navigation: navigation,
                  embeddedPreview: embeddedPreview,
                ),
          bottomNavigationBar: useBottomBar
              ? _bottomBar(
                  shop: shop,
                  theme: modernTheme,
                  navigation: navigation,
                  shopState: navShop,
                  embeddedPreview: embeddedPreview,
                )
              : SafeArea(
                  top: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ModernShopFooter(
                        shopId: widget.shopId,
                        shop: shop,
                        shopName: shopName,
                        primaryColor: modernTheme.primaryColor,
                        darkTextColor: modernTheme.textColor,
                        secondaryTextColor: modernTheme.textColor.withValues(
                          alpha: 0.65,
                        ),
                        cardColor: modernTheme.cardColor,
                        borderColor: modernTheme.cardBorderColor,
                        isPreview: widget.isPreview,
                      ).showShopInfoSheet(context);
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;

                      if (velocity < -100) {
                        ModernShopFooter(
                          shopId: widget.shopId,
                          shop: shop,
                          shopName: shopName,
                          primaryColor: modernTheme.primaryColor,
                          darkTextColor: modernTheme.textColor,
                          secondaryTextColor: modernTheme.textColor.withValues(
                            alpha: 0.65,
                          ),
                          cardColor: modernTheme.cardColor,
                          borderColor: modernTheme.cardBorderColor,
                          isPreview: widget.isPreview,
                        ).showShopInfoSheet(context);
                      }
                    },
                    child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: modernTheme.backgroundColor,
                        border: Border(
                          top: BorderSide(
                            color: modernTheme.cardBorderColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 15,
                            color: modernTheme.primaryColor,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '店家資訊',
                            style: TextStyle(
                              fontSize: 9,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: modernTheme.textColor.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

          body: SafeArea(
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Column(
                    children: <Widget>[
                      StoreBrandTopBar(
                        style: brandStyle,
                        shopName: shopName,
                        subtitle: headerSubtitle,
                        logoUrl: logoUrl,
                        theme: modernTheme,
                        backgroundColor: modernTheme.backgroundColor,
                        leading: _brandLeading(
                          hideMenu: useBottomBar,
                          textColor: modernTheme.textColor,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenHeight = constraints.maxHeight;

                            // 含精選商品與賣場 Banner 後的首頁估算高度
                            const estimatedContentHeight = 1120.0;

                            final canScroll =
                                estimatedContentHeight > screenHeight;

                            return ListView(
                              controller: _homeScroll,
                              primary: false,
                              physics: canScroll || useBottomBar
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                12,
                                5,
                                12,
                                useBottomBar
                                    ? ModernBottomNavigation.contentClearance(
                                        navigation.bottomAppearance,
                                        MediaQuery.paddingOf(context).bottom,
                                      )
                                    : 12,
                              ),
                              children: <Widget>[
                                for (final String sectionId
                                    in visibleSections) ...<Widget>[
                                  sectionBody(sectionId),
                                  if (HomeSectionOrder.gapAfter(sectionId) > 0)
                                    SizedBox(
                                      height: HomeSectionOrder.gapAfter(
                                        sectionId,
                                      ),
                                    ),
                                ],
                                if (useBottomBar) ...<Widget>[
                                  const SizedBox(height: 18),
                                  sectionBody('shopInfo'),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                FloatingContactButton(
                  shop: shop,
                  shopId: widget.shopId,
                  isPreview: widget.isPreview || widget.layoutCanvas,
                  bottomBarHeight: useBottomBar
                      ? ModernBottomNavigation.slotHeight(
                          navigation.bottomAppearance,
                          MediaQuery.paddingOf(context).bottom,
                        )
                      : 0,
                  peerRect: _menuRect,
                  ownRect: _contactRect,
                ),
                if (useBottomBar &&
                    showHomeShopMenu(
                      layoutCanvas: widget.layoutCanvas,
                      isPreview: widget.isPreview,
                    ))
                  _shopMenuButton(
                    shop: shop,
                    shopName: shopName,
                    theme: modernTheme,
                    navigation: navigation,
                    embeddedPreview: embeddedPreview,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStayServiceSection(
    Map<String, dynamic> shop, {
    required HomeThemeModel theme,
  }) {
    final showCamera = shop['showCameraSection'] != false;

    final services = <Map<String, dynamic>>[
      {
        'icon': Icons.home_outlined,
        'title': '環境介紹',
        'onTap': () {
          _openPage(ShopEnvironmentPage(shopId: widget.shopId, theme: theme));
        },
      },
      {
        'icon': Icons.bedroom_parent_outlined,
        'title': '全部房型',
        'onTap': () {
          _openPage(ShopRoomIntroPage(shopId: widget.shopId, theme: theme));
        },
      },
      {
        'icon': Icons.description_outlined,
        'title': '入住須知',
        'onTap': () {
          _openPage(
            ShopPolicyViewPage(
              shopId: widget.shopId,
              theme: theme,
              readOnly: true,
            ),
          );
        },
      },
      if (showCamera)
        {
          'icon': Icons.videocam_outlined,
          'title': '觀看攝影機',
          'onTap': () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('攝影機需於入住期間開放')));
          },
        },
      {
        'icon': Icons.favorite_border_rounded,
        'title': '關於我們',
        'onTap': () {
          _openPage(ShopAboutPage(shopId: widget.shopId, theme: theme));
        },
      },
      {
        'icon': Icons.star_border_rounded,
        'title': '評價專區',
        'onTap': () {
          _openPage(ShopReviewListPage(shopId: widget.shopId, theme: theme));
        },
      },
      if (shop['showFaqSection'] != false)
        {
          'icon': Icons.help_outline_rounded,
          'title': '常見問題',
          'onTap': () {
            _openPage(ShopFaqPage(shopId: widget.shopId, theme: theme));
          },
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hotel_outlined, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              '住宿服務',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final service = services[index];

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: service['onTap'] as VoidCallback,
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          service['icon'] as IconData,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        service['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRoomSection({required HomeThemeModel theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pets_rounded, size: 16, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(
              '熱門房型',
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _roomTypesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 196,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: Text(
                  '房型資料讀取失敗',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryTextColor,
                  ),
                ),
              );
            }

            final roomTypes = snapshot.data ?? [];

            if (roomTypes.isEmpty) {
              return Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorderColor),
                ),
                child: Text(
                  '目前尚未建立房型',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryTextColor,
                  ),
                ),
              );
            }

            return SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: roomTypes.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == roomTypes.length) {
                    return _buildAllRoomsCard(context, theme: theme);
                  }
                  return _buildRoomTypeCard(
                    context: context,
                    roomType: roomTypes[index],
                    theme: theme,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoomTypeCard({
    required BuildContext context,
    required Map<String, dynamic> roomType,
    required HomeThemeModel theme,
  }) {
    final name = (roomType['name'] ?? '未命名房型').toString().trim();

    final rawImages = roomType['images'];
    final images = rawImages is List
        ? rawImages
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];

    final imageUrl = images.isNotEmpty ? images.first : '';

    final rawPrice = roomType['price'];
    final price = rawPrice is num
        ? rawPrice.toInt()
        : int.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _openPage(
          RoomTypeDetailPage(
            shopId: widget.shopId,
            roomType: roomType,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 1)),
            theme: theme,
            isIntroMode: true,
          ),
        );
      },
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 70,
                width: double.infinity,
                child: imageUrl.isEmpty
                    ? Container(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.bedroom_parent_outlined,
                          size: 30,
                          color: theme.primaryColor,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: theme.primaryColor.withValues(alpha: 0.12),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 28,
                              color: theme.primaryColor,
                            ),
                          );
                        },
                      ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 5, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 12,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      price > 0 ? '\$$price / 天起' : '價格洽店家',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllRoomsCard(
    BuildContext context, {
    required HomeThemeModel theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _openPage(ShopRoomIntroPage(shopId: widget.shopId, theme: theme));
      },
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '>>',
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '全部房型',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeSection({
    required String sectionId,
    required Map<String, dynamic> shop,
    required String shopName,
    required String headerSubtitle,
    required StoreBrandStyle brandStyle,
    required String logoUrl,
    required HomeThemeModel theme,
    required List<String> facilityKeys,
    required List<StoreBannerModel> banners,
    required ModernStoreHomeSetting storeHomeSetting,
    required ModernBannerFrameSetting frameSetting,
    required bool useBottomBar,
  }) {
    switch (sectionId) {
      case 'header':
        return StoreBrandTopBar(
          style: brandStyle,
          shopName: shopName,
          subtitle: headerSubtitle,
          logoUrl: logoUrl,
          theme: theme,
          backgroundColor: theme.backgroundColor,
          editable: widget.layoutCanvas,
          onChanged: widget.onBrandStyleChanged,
          leading: _brandLeading(
            hideMenu: useBottomBar,
            textColor: theme.textColor,
          ),
        );
      case 'footer':
        return _canvasFooter(theme: theme);
      case 'banners':
        return _buildBannerSection(
          shop: shop,
          banners: banners,
          theme: theme,
          frameSetting: frameSetting,
        );
      case 'facilities':
        return _buildEnvironmentFeatureSection(
          facilityKeys: facilityKeys,
          theme: theme,
        );
      case 'announcements':
        return _buildLatestAnnouncementSection(theme: theme);
      case 'dailyCare':
        return ModernStayingDailyCareSection(
          shopId: widget.shopId,
          theme: theme,
          platformPreview: widget.platformPreview,
        );
      case 'rooms':
        return _buildPopularRoomSection(theme: theme);
      case 'featured':
        return FeaturedStoreProductsSection(
          shopId: widget.shopId,
          shop: shop,
          theme: theme,
          setting: storeHomeSetting,
        );
      case 'storeEntrance':
        return StoreEntranceBanner(
          shopId: widget.shopId,
          shop: shop,
          theme: theme,
          setting: storeHomeSetting,
        );
      case 'services':
        return _buildStayServiceSection(shop, theme: theme);
      case 'reviews':
        return ModernReviewSection(
          shopId: widget.shopId,
          primaryColor: theme.primaryColor,
          darkTextColor: theme.textColor,
          secondaryTextColor: theme.secondaryTextColor,
          cardColor: theme.cardColor,
          borderColor: theme.cardBorderColor,
          theme: theme,
        );
      case 'shopInfo':
        return _shopInfoPanel(shop: shop, shopName: shopName, theme: theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLayoutCanvas({
    required Map<String, dynamic> shop,
    required String shopName,
    required HomeThemeModel theme,
    required FrontendNavigationConfig navigation,
    required FrontendNavShopState navShop,
    required bool embeddedPreview,
    required bool useBottomBar,
    required List<String> sectionOrder,
    required List<String> visibleSectionIds,
    required Widget Function(String sectionId) buildSection,
  }) {
    return Scaffold(
      extendBody: useBottomBar,
      backgroundColor: theme.backgroundColor,
      drawer: useBottomBar
          ? null
          : _modernDrawer(
              shop: shop,
              theme: theme,
              navigation: navigation,
              embeddedPreview: embeddedPreview,
            ),
      bottomNavigationBar: useBottomBar
          ? _bottomBar(
              shop: shop,
              theme: theme,
              navigation: navigation,
              shopState: navShop,
              embeddedPreview: embeddedPreview,
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _HomeLayoutCanvas(
            background: theme.backgroundColor,
            sectionIds: visibleSectionIds,
            sectionOrder: sectionOrder,
            pinFooter: !useBottomBar,
            shopInfo: useBottomBar ? buildSection('shopInfo') : null,
            bottomInset: useBottomBar
                ? ModernBottomNavigation.contentClearance(
                    navigation.bottomAppearance,
                    MediaQuery.paddingOf(context).bottom,
                  )
                : 12,
            selectedSectionId: widget.selectedSectionId,
            onSelectSection: widget.onSelectSection,
            onSectionOrderChanged: widget.onHomeSectionOrderChanged,
            buildSection: buildSection,
          ),
          FloatingContactButton(
            shop: shop,
            shopId: widget.shopId,
            isPreview: true,
            bottomBarHeight: useBottomBar
                ? ModernBottomNavigation.slotHeight(
                    navigation.bottomAppearance,
                    MediaQuery.paddingOf(context).bottom,
                  )
                : 0,
            peerRect: _menuRect,
            ownRect: _contactRect,
          ),
        ],
      ),
    );
  }

  Widget? _brandLeading({required bool hideMenu, required Color textColor}) {
    if (widget.platformPreview) {
      return IconButton(
        tooltip: '返回',
        icon: Icon(Icons.arrow_back_rounded, color: textColor),
        onPressed: () => Navigator.pop(context),
      );
    }
    if (hideMenu) {
      return null;
    }
    return Builder(
      builder: (BuildContext drawerContext) {
        return IconButton(
          tooltip: '選單',
          icon: Icon(Icons.menu_rounded, size: 25, color: textColor),
          onPressed: () {
            Scaffold.of(drawerContext).openDrawer();
          },
        );
      },
    );
  }

  Widget _canvasFooter({required HomeThemeModel theme}) {
    return ColoredBox(
      color: theme.backgroundColor,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.cardBorderColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 15,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 3),
            Text(
              '店家資訊',
              style: TextStyle(
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w700,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection({
    required Map<String, dynamic> shop,
    required List<StoreBannerModel> banners,
    required HomeThemeModel theme,
    required ModernBannerFrameSetting frameSetting,
  }) {
    if (widget.layoutCanvas && banners.isEmpty) {
      return Padding(
        padding: HomeBannerDisplay.outerPadding(frameSetting.widthPreset),
        child: AspectRatio(
          aspectRatio: frameSetting.frameAspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.cardBorderColor),
            ),
            child: Center(
              child: Text(
                '尚未發布活動海報',
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
            ),
          ),
        ),
      );
    }
    final bool composeLive = widget.isPreview && !widget.layoutCanvas;
    return ModernHomeBannerCarousel(
      key: ValueKey<String>(
        widget.layoutCanvas
            ? '${widget.canvasMode}_banners_${widget.shopId}'
            : 'modern-home-banner-${widget.shopId}',
      ),
      scrollStorageKey: widget.layoutCanvas
          ? '${widget.canvasMode}_banner_pager_${widget.shopId}'
          : 'modern-home-banner-pageview',
      banners: banners,
      theme: theme,
      frameSetting: frameSetting,
      liveComposeBannerId: composeLive ? widget.initialPreviewBannerId : null,
      initialBannerId: widget.initialPreviewBannerId,
      onComposeChanged: composeLive ? widget.onPreviewBannerChanged : null,
      onComposeTextSelected: composeLive ? widget.onPreviewTextSelected : null,
      onComposeCtaSelected: composeLive ? widget.onPreviewCtaSelected : null,
      composeImageBytes: composeLive ? widget.previewImageBytes : null,
      composeSelectedTextId: composeLive ? widget.previewSelectedTextId : null,
      composeCtaSelected: composeLive && widget.previewCtaSelected,
      onBannerTap: widget.isPreview
          ? null
          : (StoreBannerModel banner) {
              HomeBannerNavigation.open(
                context: context,
                shopId: widget.shopId,
                shop: shop,
                theme: theme,
                banner: banner,
                useModernDrawer: true,
              );
            },
    );
  }

  Widget _buildEnvironmentFeatureSection({
    required List<String> facilityKeys,
    required HomeThemeModel theme,
  }) {
    if (facilityKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedFacilities = environmentFacilityOptions.where((item) {
      final key = (item['key'] ?? '').toString();
      return facilityKeys.contains(key);
    }).toList();

    if (selectedFacilities.isEmpty) {
      return const SizedBox.shrink();
    }

    void openEnvironmentPage() {
      _openPage(ShopEnvironmentPage(shopId: widget.shopId, theme: theme));
    }

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: selectedFacilities.length + 1,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final isLastButton = index == selectedFacilities.length;

          if (isLastButton) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: openEnvironmentPage,
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 32,
                      color: theme.primaryColor,
                    ),
                    SizedBox(height: 5),
                    Text(
                      '環境介紹',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final facility = selectedFacilities[index];

          final title = (facility['title'] ?? '照護設備').toString().trim();

          final icon = facility['icon'] is IconData
              ? facility['icon'] as IconData
              : Icons.pets_outlined;

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: openEnvironmentPage,
            child: Container(
              width: 72,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: theme.primaryColor),
                  ),

                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestAnnouncementSection({required HomeThemeModel theme}) {
    void openAnnouncementPage() {
      _openPage(ShopAnnouncementPage(shopId: widget.shopId, theme: theme));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        String title = '目前尚無公告';
        String type = 'normal';
        bool hasAnnouncement = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final docs = snapshot.data!.docs.toList();

          docs.sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aPinned = aData['isPinned'] == true;
            final bPinned = bData['isPinned'] == true;

            if (aPinned != bPinned) {
              return aPinned ? -1 : 1;
            }

            final aTime = aData['createdAt'];
            final bTime = bData['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          final announcement = docs.first.data();

          title = (announcement['title'] ?? '未命名公告').toString().trim();
          type = (announcement['type'] ?? 'normal').toString();
          hasAnnouncement = true;
        }

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openAnnouncementPage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _announcementIcon(type),
                    size: 18,
                    color: theme.primaryColor,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '最新公告',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: hasAnnouncement
                              ? theme.secondaryTextColor
                              : theme.textColor.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _announcementIcon(String type) {
    switch (type) {
      case 'important':
        return Icons.priority_high_rounded;
      case 'business_hours':
        return Icons.schedule_rounded;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'checkin_notice':
        return Icons.notifications_active_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }
}

class _HomeLayoutCanvas extends StatefulWidget {
  const _HomeLayoutCanvas({
    required this.background,
    required this.sectionIds,
    required this.sectionOrder,
    required this.pinFooter,
    required this.shopInfo,
    required this.bottomInset,
    required this.selectedSectionId,
    required this.onSelectSection,
    required this.onSectionOrderChanged,
    required this.buildSection,
  });

  final Color background;
  final List<String> sectionIds;
  final List<String> sectionOrder;
  final bool pinFooter;
  final Widget? shopInfo;
  final double bottomInset;
  final String? selectedSectionId;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<List<String>>? onSectionOrderChanged;
  final Widget Function(String sectionId) buildSection;

  @override
  State<_HomeLayoutCanvas> createState() => _HomeLayoutCanvasState();
}

class _HomeLayoutCanvasState extends State<_HomeLayoutCanvas> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _fixedSection(String sectionId) {
    return EditableHomeSection(
      key: ValueKey<String>(sectionId),
      sectionId: sectionId,
      selected: widget.selectedSectionId == sectionId,
      onSelect: () => widget.onSelectSection?.call(sectionId),
      child: widget.buildSection(sectionId),
    );
  }

  Widget _orderedSection(String sectionId, int index) {
    final double gap = HomeSectionOrder.gapAfter(sectionId);
    return EditableHomeSection(
      key: ValueKey<String>(sectionId),
      sectionId: sectionId,
      selected: widget.selectedSectionId == sectionId,
      onSelect: () => widget.onSelectSection?.call(sectionId),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: widget.buildSection(sectionId),
          ),
          if (sectionId == 'banners')
            Positioned(
              top: 4,
              right: 4,
              child: ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: '拖曳整個海報區塊',
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.94),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final List<String> next = HomeSectionOrder.reorderVisible(
      saved: widget.sectionOrder,
      visible: widget.sectionIds,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (_sameOrder(next, widget.sectionOrder)) {
      return;
    }
    widget.onSectionOrderChanged?.call(next);
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.background,
      child: Column(
        children: <Widget>[
          _fixedSection('header'),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: _scrollController,
              primary: false,
              buildDefaultDragHandles: false,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12, 5, 12, widget.bottomInset),
              itemCount: widget.sectionIds.length,
              onReorder: _onReorder,
              onReorderEnd: (_) {
                widget.onSelectSection?.call('banners');
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (BuildContext context, Widget? lifted) {
                        final double elevation = Tween<double>(
                          begin: 0,
                          end: 8,
                        ).evaluate(animation);
                        return Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          shadowColor: Colors.black26,
                          child: lifted,
                        );
                      },
                      child: child,
                    );
                  },
              footer: widget.shopInfo == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: widget.shopInfo,
                    ),
              itemBuilder: (BuildContext context, int index) {
                return _orderedSection(widget.sectionIds[index], index);
              },
            ),
          ),
          if (widget.pinFooter) _fixedSection('footer'),
        ],
      ),
    );
  }
}
