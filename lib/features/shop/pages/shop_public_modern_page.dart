// 檔案名稱：lib/features/shop/pages/shop_public_modern_page.dart
// 功能說明：讀取店家資料，顯示適合手機的緊湊型頂部與 Banner
// ✨ 店家新版前台首頁 Beta

import 'dart:async';
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
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/core/services/discount_campaign_service.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_layout_canvas.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_about_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_faq_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_news_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_policy_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_editor_overlay.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_app_drawer.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';
import 'package:petnest_saas/features/shop/pages/room_type_detail_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_environment_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_intro_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_type_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_environment_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_room_section.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_entry_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_view_page.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_quick_booking_section.dart';
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
    this.selectedRoomTypeId,
    this.onSelectRoomType,
    this.focusSectionId,
    this.focusSectionToken = 0,
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
  final String? selectedRoomTypeId;
  final ValueChanged<String>? onSelectRoomType;

  /// 外觀設定切到房型展示時，把編排畫布捲到房型區塊。
  final String? focusSectionId;
  final int focusSectionToken;

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
  StreamSubscription<List<Map<String, dynamic>>>? _roomTypesSub;
  List<Map<String, dynamic>>? _roomTypes;
  bool _roomTypesFailed = false;
  String? _roomShopId;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _announcementsStream;
  late final Stream<List<DiscountCampaignModel>> _campaignsStream;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _announcementsSub;
  late final StreamSubscription<List<DiscountCampaignModel>> _campaignsSub;
  List<Map<String, dynamic>> _publishedNotices = const <Map<String, dynamic>>[];
  List<DiscountCampaignModel> _publicCampaigns =
      const <DiscountCampaignModel>[];
  bool _noticesReady = false;
  bool _campaignsReady = false;
  bool _noticesFailed = false;
  bool _campaignsFailed = false;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  _policySub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _faqsSub;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
  _reviewsSub;
  Map<String, dynamic>? _policyDoc;
  List<Map<String, dynamic>> _publishedFaqs = const <Map<String, dynamic>>[];
  List<ReviewModel> _publicReviews = const <ReviewModel>[];
  bool _policyReady = false;
  bool _faqsReady = false;
  bool _reviewsReady = false;
  bool _policyFailed = false;
  bool _faqsFailed = false;
  bool _reviewsFailed = false;
  late final StreamSubscription<DaycareSettingsModel> _daycareSettingsSub;
  DaycareSettingsModel? _daycareSettings;
  final ScrollController _homeScroll = ScrollController();
  final ValueNotifier<Rect?> _menuRect = ValueNotifier<Rect?>(null);
  final ValueNotifier<Rect?> _contactRect = ValueNotifier<Rect?>(null);
  bool _canOpenAdmin = false;
  String _selectedNavId = FrontendNavigationRegistry.homeId;

  @override
  void initState() {
    super.initState();
    _shopStream = ShopService.instance.streamShop(widget.shopId);
    _listenRoomTypes();
    _announcementsStream = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('announcements')
        .where('isPublished', isEqualTo: true)
        .snapshots();
    _campaignsStream = DiscountCampaignService.instance.streamPublicCampaigns(
      widget.shopId,
    );
    _announcementsSub = _announcementsStream.listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted) {
          return;
        }
        setState(() {
          _noticesReady = true;
          _noticesFailed = false;
          _publishedNotices = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    <String, dynamic>{...doc.data(), 'id': doc.id},
              )
              .toList();
        });
      },
      onError: (Object _) {
        if (!mounted) {
          return;
        }
        setState(() {
          _noticesReady = true;
          _noticesFailed = true;
          _publishedNotices = const <Map<String, dynamic>>[];
        });
      },
    );
    _campaignsSub = _campaignsStream.listen(
      (List<DiscountCampaignModel> campaigns) {
        if (!mounted) {
          return;
        }
        setState(() {
          _campaignsReady = true;
          _campaignsFailed = false;
          _publicCampaigns = campaigns;
        });
      },
      onError: (Object _) {
        if (!mounted) {
          return;
        }
        setState(() {
          _campaignsReady = true;
          _campaignsFailed = true;
          _publicCampaigns = const <DiscountCampaignModel>[];
        });
      },
    );
    _policySub = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('policies')
        .doc('checkin_policy')
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted) {
              return;
            }
            setState(() {
              _policyReady = true;
              _policyFailed = false;
              _policyDoc = snapshot.data();
            });
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _policyReady = true;
              _policyFailed = true;
              _policyDoc = null;
            });
          },
        );
    _faqsSub = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('faqs')
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted) {
              return;
            }
            setState(() {
              _faqsReady = true;
              _faqsFailed = false;
              _publishedFaqs = snapshot.docs
                  .map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        <String, dynamic>{...doc.data(), 'id': doc.id},
                  )
                  .toList();
            });
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _faqsReady = true;
              _faqsFailed = true;
              _publishedFaqs = const <Map<String, dynamic>>[];
            });
          },
        );
    _reviewsSub = FirebaseFirestore.instance
        .collection('reviews')
        .where('shopId', isEqualTo: widget.shopId)
        .where('status', isEqualTo: 'visible')
        .snapshots()
        .listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted) {
              return;
            }
            setState(() {
              _reviewsReady = true;
              _reviewsFailed = false;
              _publicReviews = snapshot.docs.map(ReviewModel.fromDoc).toList();
            });
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _reviewsReady = true;
              _reviewsFailed = true;
              _publicReviews = const <ReviewModel>[];
            });
          },
        );
    _daycareSettingsSub = DaycareSettingsService.instance
        .stream(widget.shopId)
        .listen((DaycareSettingsModel settings) {
          if (!mounted) {
            return;
          }
          setState(() => _daycareSettings = settings);
        }, onError: (Object _) {});
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
  void didUpdateWidget(ShopPublicModernPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _listenRoomTypes();
    }
  }

  void _listenRoomTypes() {
    _roomTypesSub?.cancel();
    if (widget.shopId != _roomShopId) {
      _roomTypes = null;
      _roomTypesFailed = false;
      _roomShopId = widget.shopId;
    }
    _roomTypesSub = ShopService.instance
        .streamRoomTypes(widget.shopId)
        .listen(
          (List<Map<String, dynamic>> rooms) {
            if (!mounted) {
              return;
            }
            setState(() {
              _roomTypes = rooms;
              _roomTypesFailed = false;
            });
          },
          onError: (Object _) {
            if (!mounted) {
              return;
            }
            setState(() {
              _roomTypesFailed = true;
              _roomTypes ??= const <Map<String, dynamic>>[];
            });
          },
        );
  }

  @override
  void dispose() {
    _roomTypesSub?.cancel();
    _announcementsSub.cancel();
    _campaignsSub.cancel();
    _policySub.cancel();
    _faqsSub.cancel();
    _reviewsSub.cancel();
    _daycareSettingsSub.cancel();
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
        final HomeRoomSectionSetting roomSection =
            HomeRoomSectionSetting.fromMap(modernAppearance['roomSection']);
        final HomeEnvironmentSectionSetting environmentSection =
            HomeEnvironmentSectionSetting.fromMap(
              modernAppearance['environmentSection'],
            );
        final bool environmentVisible = environmentSection.showsOnHome(
          hasFacilities: ModernHomeEnvironmentSection.facilitiesFor(
            facilityKeys,
          ).isNotEmpty,
        );
        final HomeAboutSectionSetting aboutSection =
            HomeAboutSectionSetting.fromMap(modernAppearance['aboutSection']);
        final bool aboutVisible = aboutSection.showsOnHome;
        final HomeNewsSectionSetting newsSection =
            HomeNewsSectionSetting.fromMap(modernAppearance['newsSection']);
        final List<HomeNewsItem> newsItems = mergeHomeNews(
          source: newsSection.source,
          notices: HomeNewsItem.noticesFromMaps(_publishedNotices),
          campaigns: _publicCampaigns.map(HomeNewsItem.campaign).toList(),
        );
        final HomeNewsSectionPhase newsPhase = resolveHomeNewsPhase(
          featureEnabled: shop['showAnnouncementSection'] != false,
          editorPreview: widget.layoutCanvas || widget.isPreview,
          source: newsSection.source,
          load: HomeNewsLoadState(
            noticesReady: _noticesReady,
            campaignsReady: _campaignsReady,
            noticesFailed: _noticesFailed,
            campaignsFailed: _campaignsFailed,
          ),
          hasItems: newsItems.isNotEmpty,
        );
        final bool showAnnouncements = homeNewsOccupiesSection(newsPhase);
        final HomeInformationSectionsSetting informationSections =
            HomeInformationSectionsSetting.fromMap(
              modernAppearance['informationSections'],
            );
        final bool editorPreview = widget.layoutCanvas || widget.isPreview;
        final HomePolicySnapshot policySnapshot = readHomePolicySnapshot(
          _policyDoc,
        );
        final List<HomeFaqItem> faqItems = homeFaqsFromMaps(_publishedFaqs);
        final List<ReviewModel> reviewItems = sortPublicReviews(_publicReviews);
        final HomeInfoSectionPhase policyPhase = resolveHomeInfoPhase(
          showOnHome: informationSections.policy.showOnHome,
          editorPreview: editorPreview,
          ready: _policyReady,
          failed: _policyFailed,
          hasContent: policySnapshot.hasContent,
        );
        final HomeInfoSectionPhase faqPhase = resolveHomeInfoPhase(
          showOnHome: informationSections.faq.showOnHome,
          editorPreview: editorPreview,
          featureEnabled: shop['showFaqSection'] != false,
          ready: _faqsReady,
          failed: _faqsFailed,
          hasContent: faqItems.isNotEmpty,
        );
        final HomeInfoSectionPhase reviewPhase = resolveHomeInfoPhase(
          showOnHome: informationSections.reviews.showOnHome,
          editorPreview: editorPreview,
          ready: _reviewsReady,
          failed: _reviewsFailed,
          hasContent: reviewItems.isNotEmpty,
        );
        final HomeQuickBookingSectionSetting quickBookingSection =
            HomeQuickBookingSectionSetting.fromMap(
              modernAppearance['quickBookingSection'],
            );
        final bool accommodationAvailable = shop['bookingEnabled'] != false;
        final bool daycareAvailable = DaycareSettingsService.instance
            .isEnabledForShop(shop: shop, settings: _daycareSettings);
        final bool showAnnouncementsOnHome =
            showAnnouncements &&
            !(newsPhase == HomeNewsSectionPhase.empty &&
                !newsSection.showEmptyPlaceholder);
        final bool showStayServiceStrip =
            modernAppearance['showStayServiceStrip'] != false;
        final bool storeModuleEnabled = StorefrontAccess.isModuleEnabled(shop);
        final List<String> visibleSections = HomeSectionOrder.visible(
          sectionOrder,
          showAnnouncements: showAnnouncementsOnHome,
          showAbout: aboutVisible,
          showPolicy: homeInfoOccupiesSection(policyPhase),
          showFaq: homeInfoOccupiesSection(faqPhase),
          showReviews: homeInfoOccupiesSection(reviewPhase),
          showFacilities: environmentVisible,
          showQuickBooking: homeQuickBookingVisible(
            setting: quickBookingSection,
            editorPreview: editorPreview,
            accommodationAvailable: accommodationAvailable,
            daycareAvailable: daycareAvailable,
          ),
          showServices: showStayServiceStrip,
          showFeatured:
              storeModuleEnabled && storeHomeSetting.showFeaturedProducts,
          showStoreEntrance:
              storeModuleEnabled && storeHomeSetting.showStoreBanner,
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
            roomSection: roomSection,
            environmentIntro: environmentIntro,
            environmentSection: environmentSection,
            aboutSection: aboutSection,
            newsSection: newsSection,
            newsItems: newsItems,
            newsPhase: newsPhase,
            informationSections: informationSections,
            policySnapshot: policySnapshot,
            faqItems: faqItems,
            reviewItems: reviewItems,
            policyPhase: policyPhase,
            faqPhase: faqPhase,
            reviewPhase: reviewPhase,
            showEnvironmentService: !environmentVisible,
            showAboutService: stayServiceShowsAbout(aboutSection),
            quickBookingSection: quickBookingSection,
            accommodationAvailable: accommodationAvailable,
            daycareAvailable: daycareAvailable,
          );
        }

        HomeSectionSpan spanOf(String sectionId) {
          return homeSectionSpan(
            sectionId: sectionId,
            rooms: roomSection,
            environment: environmentSection,
            about: aboutSection,
            news: newsSection,
            information: informationSections,
            quickBooking: quickBookingSection,
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
            spanOf: spanOf,
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
                                ...buildHomeSectionRows(
                                  sectionIds: visibleSections,
                                  spanOf: spanOf,
                                  gap: constraints.maxWidth < 760 ? 8 : 10,
                                  itemBuilder: sectionBody,
                                ),
                                if (useBottomBar) ...<Widget>[
                                  const SizedBox(height: 8),
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
    required bool showEnvironmentEntry,
    required bool showAboutEntry,
    required HomeInformationSectionsSetting information,
  }) {
    final showCamera = shop['showCameraSection'] != false;

    final services = <Map<String, dynamic>>[
      if (showEnvironmentEntry)
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
      if (showPolicyServiceEntry(information.policy))
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
      if (showAboutEntry)
        {
          'icon': Icons.favorite_border_rounded,
          'title': '關於我們',
          'onTap': () {
            _openPage(ShopAboutPage(shopId: widget.shopId, theme: theme));
          },
        },
      if (showReviewServiceEntry(information.reviews))
        {
          'icon': Icons.star_border_rounded,
          'title': '評價專區',
          'onTap': () {
            _openPage(ShopReviewListPage(shopId: widget.shopId, theme: theme));
          },
        },
      if (showFaqServiceEntry(
        information.faq,
        featureEnabled: shop['showFaqSection'] != false,
      ))
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

  Widget _buildPopularRoomSection({
    required HomeThemeModel theme,
    required HomeRoomSectionSetting roomSection,
  }) {
    final bool preview = widget.layoutCanvas || widget.isPreview;
    if (_roomTypes == null && !_roomTypesFailed) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ModernHomeRoomSection(
      theme: theme,
      setting: roomSection,
      roomTypes: _roomTypes ?? const <Map<String, dynamic>>[],
      preview: preview,
      loadFailed: _roomTypesFailed && (_roomTypes?.isEmpty ?? true),
      selectedRoomTypeId: widget.selectedRoomTypeId,
      onSelectRoomType: (String roomTypeId) {
        widget.onSelectRoomType?.call(roomTypeId);
        widget.onSelectSection?.call('rooms');
      },
      onOpenRoom: preview
          ? null
          : (Map<String, dynamic> roomType) {
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
      onOpenAllRooms: preview
          ? null
          : () {
              _openPage(ShopRoomIntroPage(shopId: widget.shopId, theme: theme));
            },
      onManageRooms: preview
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ShopRoomTypePage(shopId: widget.shopId),
                ),
              );
            }
          : null,
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
    required HomeRoomSectionSetting roomSection,
    required Map<String, dynamic> environmentIntro,
    required HomeEnvironmentSectionSetting environmentSection,
    required HomeAboutSectionSetting aboutSection,
    required HomeNewsSectionSetting newsSection,
    required List<HomeNewsItem> newsItems,
    required HomeNewsSectionPhase newsPhase,
    required HomeInformationSectionsSetting informationSections,
    required HomePolicySnapshot policySnapshot,
    required List<HomeFaqItem> faqItems,
    required List<ReviewModel> reviewItems,
    required HomeInfoSectionPhase policyPhase,
    required HomeInfoSectionPhase faqPhase,
    required HomeInfoSectionPhase reviewPhase,
    required bool showEnvironmentService,
    required bool showAboutService,
    required HomeQuickBookingSectionSetting quickBookingSection,
    required bool accommodationAvailable,
    required bool daycareAvailable,
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
      case 'about':
        return ModernHomeAboutSection(
          theme: theme,
          setting: aboutSection,
          shop: shop,
          environmentIntro: environmentIntro,
          shopName: shopName,
          logoUrl: logoUrl,
          preview: widget.layoutCanvas || widget.isPreview,
          onOpen: () {
            _openPage(ShopAboutPage(shopId: widget.shopId, theme: theme));
          },
        );
      case 'facilities':
        return ModernHomeEnvironmentSection(
          theme: theme,
          setting: environmentSection,
          environmentIntro: environmentIntro,
          facilityKeys: facilityKeys,
          preview: widget.layoutCanvas || widget.isPreview,
          onOpen: () {
            _openPage(ShopEnvironmentPage(shopId: widget.shopId, theme: theme));
          },
        );
      case 'announcements':
        return ModernHomeNewsSection(
          theme: theme,
          setting: newsSection,
          items: newsItems,
          phase: newsPhase,
          preview: widget.layoutCanvas || widget.isPreview,
          onOpen: (ShopAnnouncementSection section) {
            _openPage(
              ShopAnnouncementPage(
                shopId: widget.shopId,
                theme: theme,
                initialSection: section,
              ),
            );
          },
        );
      case 'dailyCare':
        return ModernStayingDailyCareSection(
          shopId: widget.shopId,
          theme: theme,
          platformPreview: widget.platformPreview,
        );
      case 'rooms':
        return _buildPopularRoomSection(theme: theme, roomSection: roomSection);
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
        return _buildStayServiceSection(
          shop,
          theme: theme,
          showEnvironmentEntry: showEnvironmentService,
          showAboutEntry: showAboutService,
          information: informationSections,
        );
      case 'policy':
        return ModernHomePolicySection(
          theme: theme,
          setting: informationSections.policy,
          snapshot: policySnapshot,
          phase: policyPhase,
          onOpen: (String serviceType) {
            _openPage(
              ShopPolicyViewPage(
                shopId: widget.shopId,
                theme: theme,
                readOnly: true,
                serviceType: serviceType,
              ),
            );
          },
        );
      case 'faq':
        return ModernHomeFaqSection(
          theme: theme,
          setting: informationSections.faq,
          items: faqItems,
          phase: faqPhase,
          onOpen: () {
            _openPage(ShopFaqPage(shopId: widget.shopId, theme: theme));
          },
        );
      case 'quickBooking':
        return ModernHomeQuickBookingSection(
          theme: theme,
          setting: quickBookingSection,
          accommodationAvailable: accommodationAvailable,
          daycareAvailable: daycareAvailable,
          preview: widget.layoutCanvas || widget.isPreview,
          onOpenAutomatic: () {
            _openPage(
              ShopBookingEntryPage(
                shopId: widget.shopId,
                theme: theme,
                useModernDrawer: true,
              ),
            );
          },
          onOpenAccommodation: () {
            _openPage(
              ShopBookingEntryPage(
                shopId: widget.shopId,
                theme: theme,
                useModernDrawer: true,
                initialService: BookingEntryInitialService.accommodation,
              ),
            );
          },
          onOpenDaycare: () {
            _openPage(
              ShopBookingEntryPage(
                shopId: widget.shopId,
                theme: theme,
                useModernDrawer: true,
                initialService: BookingEntryInitialService.daycare,
              ),
            );
          },
        );
      case 'reviews':
        return ModernReviewSection(
          theme: theme,
          setting: informationSections.reviews,
          reviews: reviewItems,
          phase: reviewPhase,
          onOpen: () {
            _openPage(ShopReviewListPage(shopId: widget.shopId, theme: theme));
          },
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
    required HomeSectionSpan Function(String sectionId) spanOf,
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
          HomeLayoutCanvas(
            background: theme.backgroundColor,
            sectionIds: visibleSectionIds,
            sectionOrder: sectionOrder,
            spanOf: spanOf,
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
            focusSectionId: widget.focusSectionId,
            focusSectionToken: widget.focusSectionToken,
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
}
