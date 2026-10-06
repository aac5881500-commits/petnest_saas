// 檔案名稱：lib/features/shop/pages/shop_theme_setting_page.dart
// 功能說明：設定首頁版型、主題顏色、卡片與圖示樣式
// 🎨 店家前台外觀設定頁

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_text_style_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/pages/store/shop_store_settings_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_type_page.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/frontend_navigation_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_editor_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_settings_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/about_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_appearance_preset_strip.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_appearance_tabs.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/faq_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/policy_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/review_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/news_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/quick_booking_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/environment_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_settings_panel.dart';

class ShopThemeSettingPage extends StatefulWidget {
  const ShopThemeSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopThemeSettingPage> createState() => _ShopThemeSettingPageState();
}

class _ShopThemeSettingPageState extends State<ShopThemeSettingPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();

  String _modernLogoUrl = '';
  Uint8List? _modernLogoPreviewBytes;
  bool _isUploadingModernLogo = false;
  final TextEditingController _modernHeaderSubtitleController =
      TextEditingController();
  final TextEditingController _modernBannerTitleController =
      TextEditingController();
  final TextEditingController _modernBannerSubtitleController =
      TextEditingController();

  final TextEditingController _modernBannerButtonTextController =
      TextEditingController();
  final TextEditingController _featuredStoreTitleController =
      TextEditingController(text: ModernStoreHomeSetting.defaultFeaturedTitle);
  final TextEditingController _storeBannerTitleController =
      TextEditingController(text: ModernStoreHomeSetting.defaultBannerTitle);
  final TextEditingController _storeBannerSubtitleController =
      TextEditingController(text: ModernStoreHomeSetting.defaultBannerSubtitle);
  final TextEditingController _storeBannerButtonTextController =
      TextEditingController(
        text: ModernStoreHomeSetting.defaultBannerButtonText,
      );
  bool _showFeaturedStoreProducts = true;
  bool _showStoreBanner = true;
  String _storeCardBackgroundFit = ModernStoreCardFits.cover;
  String _storeCardBackgroundAlignment = ModernStoreCardAlignments.center;
  String _storeCardOverlayPreset = ModernStoreCardOverlays.none;
  String _storeCardOverlayTone = ModernStoreCardOverlayTones.dark;
  String _storeCardTitleColorPreset = ModernStoreCardTextColors.dark;
  String _storeCardSubtitleColorPreset = ModernStoreCardTextColors.dark;
  String _storeCardButtonColorPreset = ModernStoreCardButtonColors.brand;
  String _storeCardContentPosition = ModernStoreCardPositions.centerLeft;
  String _featuredProductLayout = ModernFeaturedProductLayouts.horizontal;
  String _storeEntryLayout = ModernStoreEntryLayouts.banner;
  String _loadedFeaturedProductLayout = ModernFeaturedProductLayouts.horizontal;
  String _loadedStoreEntryLayout = ModernStoreEntryLayouts.banner;
  String _committedStoreCardImageUrl = '';
  String _committedStoreCardImagePath = '';
  String _selectedLayout = 'classic';
  String _selectedTheme = 'warmOrange';
  String _selectedBackground = 'warmWhite';
  String _selectedCardStyle = 'standard';
  String _selectedIconStyle = 'circle';
  String _selectedDensity = 'comfortable';
  StoreBrandStyle _brandStyle = const StoreBrandStyle();
  List<String> _homeSectionOrder = HomeSectionOrder.normalize(null);
  HomeRoomSectionSetting _roomSection = const HomeRoomSectionSetting();
  HomeEnvironmentSectionSetting _environmentSection =
      const HomeEnvironmentSectionSetting();
  HomeAboutSectionSetting _aboutSection = const HomeAboutSectionSetting();
  HomeNewsSectionSetting _newsSection = const HomeNewsSectionSetting();
  HomeQuickBookingSectionSetting _quickBookingSection =
      const HomeQuickBookingSectionSetting();
  HomeInformationSectionsSetting _informationSections =
      const HomeInformationSectionsSetting();
  int _environmentFocusToken = 0;
  int _aboutFocusToken = 0;
  int _newsFocusToken = 0;
  int _quickBookingFocusToken = 0;
  StreamSubscription<DaycareSettingsModel>? _daycareSettingsSub;
  DaycareSettingsModel? _daycareSettings;
  int _policyFocusToken = 0;
  int _faqFocusToken = 0;
  int _reviewFocusToken = 0;
  final GlobalKey _appearanceTabBarKey = GlobalKey();
  String? _selectedRoomTypeId;
  int _roomFocusToken = 0;
  HomeTextStyleModel _modernBannerTitleStyle = const HomeTextStyleModel(
    fontSize: 22,
    colorValue: 0xFFFFFFFF,
    isBold: true,
    hasShadow: true,
    alignment: 'left',
  );

  HomeTextStyleModel _modernBannerSubtitleStyle = const HomeTextStyleModel(
    fontSize: 13,
    colorValue: 0xFFFFFFFF,
    isBold: true,
    hasShadow: true,
    alignment: 'left',
  );
  HomeThemeModel _modernTheme = const HomeThemeModel(
    backgroundColorValue: 0xFFFFFBF7,
    cardColorValue: 0xFFFFFFFF,
    cardBorderColorValue: 0xFFFFD9B3,
    primaryColorValue: 0xFFFF8A00,
    textColorValue: 0xFF3A2A20,
  );

  int _modernBannerButtonColorValue = 0xFFFF7A1A;
  int _modernBannerButtonTextColorValue = 0xFFFFFFFF;
  ModernBannerFrameSetting _modernBannerFrame =
      const ModernBannerFrameSetting();
  String _modernBannerPreviewImageUrl = '';
  int _enabledHomeBannerCount = 0;
  late final TabController _tabController;
  final Map<String, Map<String, String>> _layoutSettings = {
    'classic': {
      'theme': 'warmOrange',
      'background': 'warmWhite',
      'cardStyle': 'standard',
      'iconStyle': 'circle',
      'density': 'comfortable',
    },
    'modern': {
      'theme': 'warmOrange',
      'background': 'warmWhite',
      'cardStyle': 'standard',
      'iconStyle': 'circle',
      'density': 'comfortable',
    },
  };

  bool _isSaving = false;
  bool _isLoading = true;
  bool _appearanceDirty = false;
  String? _appearancePresetId;
  String? _browsingPresetId;
  bool _showStayServiceStrip = true;
  Map<String, dynamic> _loadedShop = <String, dynamic>{};
  FrontendNavigationConfig _navigationConfig =
      FrontendNavigationConfig.defaults();
  FrontendNavigationConfig _savedNavigation =
      FrontendNavigationConfig.defaults();
  final ScrollController _appearanceScroll = ScrollController();
  final ScrollController _colorScroll = ScrollController();
  final ScrollController _navigationScroll = ScrollController();
  HomeThemeModel _colorEntryTheme = HomeThemeModel.modernDefault;
  String? _selectedHomeSection;
  int _homeCanvasPane = 0;
  final GlobalKey _headerSettingsKey = GlobalKey();
  final GlobalKey _bannerSettingsKey = GlobalKey();
  final GlobalKey _storeSettingsKey = GlobalKey();
  final GlobalKey _pendingSettingsKey = GlobalKey();
  final ScrollController _featureScroll = ScrollController();
  // ========================
  // 快速聯絡按鈕
  // ========================

  bool _floatingButtonEnabled = false;
  String _floatingButtonSize = 'medium';
  String _floatingButtonType = ShopChatService.floatingTypePetnestChat;
  String _shopPhone = '';
  String _shopLineUrl = '';
  String _shopFacebookUrl = '';
  String _shopInstagramUrl = '';

  final TextEditingController _floatingButtonLabelController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ModernHomeAppearanceTabs.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _bindModernDraftListeners();
    _daycareSettingsSub = DaycareSettingsService.instance
        .stream(widget.shopId)
        .listen((DaycareSettingsModel settings) {
          if (!mounted) {
            return;
          }
          setState(() => _daycareSettings = settings);
        }, onError: (Object _) {});
    _loadSettings();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) {
      return;
    }
    setState(() {
      if (_tabController.index == ModernHomeAppearanceTabs.rooms &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'rooms';
        _roomFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.facilities &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'facilities';
        _environmentFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.about &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'about';
        _aboutFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.news &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'announcements';
        _newsFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.quickBooking &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'quickBooking';
        _quickBookingFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.policy &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'policy';
        _policyFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.faq &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'faq';
        _faqFocusToken++;
      }
      if (_tabController.index == ModernHomeAppearanceTabs.reviews &&
          _selectedLayout == 'modern') {
        _selectedHomeSection = 'reviews';
        _reviewFocusToken++;
      }
    });
  }

  void _bindModernDraftListeners() {
    for (final TextEditingController controller in <TextEditingController>[
      _modernHeaderSubtitleController,
      _modernBannerTitleController,
      _modernBannerSubtitleController,
      _modernBannerButtonTextController,
      _featuredStoreTitleController,
      _storeBannerTitleController,
      _storeBannerSubtitleController,
      _storeBannerButtonTextController,
    ]) {
      controller.addListener(_onModernDraftChanged);
    }
  }

  void _onModernDraftChanged() {
    if (!mounted || _isLoading || _selectedLayout != 'modern') {
      return;
    }
    _appearanceDirty = true;
    setState(() {});
  }

  @override
  void dispose() {
    _daycareSettingsSub?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (final TextEditingController controller in <TextEditingController>[
      _modernHeaderSubtitleController,
      _modernBannerTitleController,
      _modernBannerSubtitleController,
      _modernBannerButtonTextController,
      _featuredStoreTitleController,
      _storeBannerTitleController,
      _storeBannerSubtitleController,
      _storeBannerButtonTextController,
    ]) {
      controller.removeListener(_onModernDraftChanged);
    }
    _modernHeaderSubtitleController.dispose();
    _modernBannerTitleController.dispose();
    _modernBannerSubtitleController.dispose();
    _modernBannerButtonTextController.dispose();
    _featuredStoreTitleController.dispose();
    _storeBannerTitleController.dispose();
    _storeBannerSubtitleController.dispose();
    _storeBannerButtonTextController.dispose();
    _floatingButtonLabelController.dispose();
    _appearanceScroll.dispose();
    _colorScroll.dispose();
    _navigationScroll.dispose();
    _featureScroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _draftModernAppearance {
    return <String, dynamic>{
      ...Map<String, String>.from(_layoutSettings['modern']!),
      'headerSubtitle': StoreBrandTextPolicy.sanitizeSubtitle(
        _modernHeaderSubtitleController.text,
      ),
      'bannerTitle': _modernBannerTitleController.text.trim(),
      'bannerSubtitle': _modernBannerSubtitleController.text.trim(),
      'bannerTitleStyle': _modernBannerTitleStyle.toMap(),
      'bannerSubtitleStyle': _modernBannerSubtitleStyle.toMap(),
      'bannerButtonText': _modernBannerButtonTextController.text.trim(),
      'bannerButtonColor': _modernBannerButtonColorValue,
      'bannerButtonTextColor': _modernBannerButtonTextColorValue,
      ..._modernBannerFrame.toMap(),
      'themeColors': _modernTheme.toMap(),
      ..._brandStyle.toMap(),
      'homeSectionOrder': _homeSectionOrder,
      'roomSection': _roomSection.toMap(),
      'environmentSection': _environmentSection.toMap(),
      'aboutSection': _aboutSection.toMap(),
      'newsSection': _newsSection.toMap(),
      'quickBookingSection': _quickBookingSection.toMap(),
      'informationSections': _informationSections.toMap(),
      homeAppearancePresetIdKey: ?_appearancePresetId,
      'showStayServiceStrip': _showStayServiceStrip,
      ..._draftStoreHomeSetting.toMap(),
      ..._navigationConfig.toMap(),
    };
  }

  String get _bannerStatusText {
    final String width = switch (_modernBannerFrame.widthPreset) {
      HomeBannerWidthPreset.narrow => '窄版',
      HomeBannerWidthPreset.standard => '標準寬',
      HomeBannerWidthPreset.full => '滿寬',
    };
    final String height = switch (_modernBannerFrame.heightPreset) {
      HomeBannerHeightPreset.short => '矮版',
      HomeBannerHeightPreset.standard => '標準高',
      HomeBannerHeightPreset.tall => '高版',
    };
    return '已啟用・$_enabledHomeBannerCount 張海報・$width／$height';
  }

  ModernStoreHomeSetting get _draftStoreHomeSetting {
    final String imageUrl = _committedStoreCardImageUrl;
    final String imagePath = _committedStoreCardImagePath;
    return ModernStoreHomeSetting(
      showFeaturedProducts: _showFeaturedStoreProducts,
      featuredTitle: _featuredStoreTitleController.text.trim(),
      featuredProductLayout: _featuredProductLayout,
      showStoreBanner: _showStoreBanner,
      storeBannerTitle: _storeBannerTitleController.text.trim(),
      storeBannerSubtitle: _storeBannerSubtitleController.text.trim(),
      storeBannerButtonText: _storeBannerButtonTextController.text.trim(),
      storeBannerImageUrl: imageUrl,
      storeBannerImageStoragePath: imagePath,
      storeBannerBackgroundFit: _storeCardBackgroundFit,
      storeBannerBackgroundAlignment: _storeCardBackgroundAlignment,
      storeBannerOverlayPreset: _storeCardOverlayPreset,
      storeBannerOverlayTone: _storeCardOverlayTone,
      storeBannerTitleColorPreset: _storeCardTitleColorPreset,
      storeBannerSubtitleColorPreset: _storeCardSubtitleColorPreset,
      storeBannerButtonColorPreset: _storeCardButtonColorPreset,
      storeBannerContentPosition: _storeCardContentPosition,
      storeEntryLayout: _storeEntryLayout,
    );
  }

  void _adoptStoreHome(ModernStoreHomeSetting setting) {
    _showFeaturedStoreProducts = setting.showFeaturedProducts;
    _featuredStoreTitleController.text = setting.featuredTitle;
    _showStoreBanner = setting.showStoreBanner;
    _storeBannerTitleController.text = setting.storeBannerTitle;
    _storeBannerSubtitleController.text = setting.storeBannerSubtitle;
    _storeBannerButtonTextController.text = setting.storeBannerButtonText;
    _storeCardBackgroundFit = setting.storeBannerBackgroundFit;
    _storeCardBackgroundAlignment = setting.storeBannerBackgroundAlignment;
    _storeCardOverlayPreset = setting.storeBannerOverlayPreset;
    _storeCardOverlayTone = setting.storeBannerOverlayTone;
    _storeCardTitleColorPreset = setting.storeBannerTitleColorPreset;
    _storeCardSubtitleColorPreset = setting.storeBannerSubtitleColorPreset;
    _storeCardButtonColorPreset = setting.storeBannerButtonColorPreset;
    _storeCardContentPosition = setting.storeBannerContentPosition;
    _featuredProductLayout = setting.featuredProductLayout;
    _storeEntryLayout = setting.storeEntryLayout;
    _loadedFeaturedProductLayout = setting.featuredProductLayout;
    _loadedStoreEntryLayout = setting.storeEntryLayout;
    _committedStoreCardImageUrl = setting.storeBannerImageUrl;
    _committedStoreCardImagePath = setting.storeBannerImageStoragePath;
  }

  Future<ModernStoreHomeSetting> _storeHomeSettingForSave() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();
    final Object? rawAppearance = snapshot.data()?['homeAppearance'];
    final Map<String, dynamic> appearance = rawAppearance is Map
        ? Map<String, dynamic>.from(rawAppearance)
        : <String, dynamic>{};
    final Object? rawModern = appearance['modern'];
    final Map<String, dynamic> modern = rawModern is Map
        ? Map<String, dynamic>.from(rawModern)
        : <String, dynamic>{};
    final ModernStoreHomeSetting latest = ModernStoreHomeSetting.fromMap(
      modern,
    );
    return latest.copyWith(
      featuredProductLayout:
          _featuredProductLayout == _loadedFeaturedProductLayout
          ? null
          : _featuredProductLayout,
      storeEntryLayout: _storeEntryLayout == _loadedStoreEntryLayout
          ? null
          : _storeEntryLayout,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();

      final shopData = snapshot.data();

      _shopPhone = (shopData?['phone'] ?? '').toString().trim();
      _shopLineUrl = (shopData?['lineUrl'] ?? '').toString().trim();
      _shopFacebookUrl = (shopData?['fbUrl'] ?? '').toString().trim();
      _shopInstagramUrl = (shopData?['igUrl'] ?? '').toString().trim();

      final rawFloatingButton = shopData?['floatingContactButton'];

      if (rawFloatingButton is Map) {
        final floatingButton = Map<String, dynamic>.from(rawFloatingButton);

        _floatingButtonEnabled = floatingButton['enabled'] == true;

        _floatingButtonType = (floatingButton['type'] ?? 'line').toString();

        final loadedSize = (floatingButton['size'] ?? 'medium').toString();

        _floatingButtonSize =
            const ['small', 'medium', 'large'].contains(loadedSize)
            ? loadedSize
            : 'medium';

        final bool legacyChat =
            shopData?['storeChatEnabled'] == true && _floatingButtonEnabled;
        if (legacyChat &&
            _floatingButtonType != ShopChatService.floatingTypePetnestChat) {
          _floatingButtonType = ShopChatService.floatingTypePetnestChat;
        }

        final availableTypes = _availableFloatingTypes();

        if (!availableTypes.contains(_floatingButtonType) &&
            availableTypes.isNotEmpty) {
          _floatingButtonType = availableTypes.first;
        }

        _floatingButtonLabelController.text = (floatingButton['label'] ?? '')
            .toString();
      }

      _modernLogoUrl = (shopData?['logoUrl'] ?? '').toString().trim();
      _enabledHomeBannerCount = shopData == null
          ? 0
          : HomeBannerService.instance
                .parseEnabledFrontBanners(Map<String, dynamic>.from(shopData))
                .length;

      final rawAppearance = shopData?['homeAppearance'];

      if (rawAppearance is Map) {
        final appearance = Map<String, dynamic>.from(rawAppearance);

        _selectedLayout = (appearance['layout'] ?? 'classic').toString();

        if (_selectedLayout != 'classic' && _selectedLayout != 'modern') {
          _selectedLayout = 'classic';
        }

        final legacySettings = <String, String>{
          'theme': (appearance['theme'] ?? 'warmOrange').toString(),
          'background': (appearance['background'] ?? 'warmWhite').toString(),
          'cardStyle': (appearance['cardStyle'] ?? 'standard').toString(),
          'iconStyle': (appearance['iconStyle'] ?? 'circle').toString(),
          'density': (appearance['density'] ?? 'comfortable').toString(),
        };

        for (final layout in ['classic', 'modern']) {
          final rawLayoutSettings = appearance[layout];

          final layoutData = rawLayoutSettings is Map
              ? Map<String, dynamic>.from(rawLayoutSettings)
              : <String, dynamic>{};

          _layoutSettings[layout] = {
            'theme': (layoutData['theme'] ?? legacySettings['theme']!)
                .toString(),
            'background':
                (layoutData['background'] ?? legacySettings['background']!)
                    .toString(),
            'cardStyle':
                (layoutData['cardStyle'] ?? legacySettings['cardStyle']!)
                    .toString(),
            'iconStyle':
                (layoutData['iconStyle'] ?? legacySettings['iconStyle']!)
                    .toString(),
            'density': (layoutData['density'] ?? legacySettings['density']!)
                .toString(),
          };
        }

        _applySelectedLayoutSettings();
        final rawModernAppearance = appearance['modern'];

        final modernAppearance = rawModernAppearance is Map
            ? Map<String, dynamic>.from(rawModernAppearance)
            : <String, dynamic>{};
        _modernTheme = HomeThemeModel.fromMap(
          modernAppearance['themeColors'],
          fallback: HomeThemeModel.modernDefault,
        );
        _colorEntryTheme = _modernTheme;

        _modernHeaderSubtitleController.text =
            StoreBrandTextPolicy.sanitizeSubtitle(
              (modernAppearance['headerSubtitle'] ?? '讓每一隻貓咪都有溫暖的家').toString(),
            );
        _modernBannerTitleController.text =
            (modernAppearance['bannerTitle'] ?? '安心住宿').toString();
        _modernBannerSubtitleController.text =
            (modernAppearance['bannerSubtitle'] ?? '毛孩的第二個家').toString();

        _modernBannerButtonTextController.text =
            (modernAppearance['bannerButtonText'] ?? '立即預約住宿').toString();

        _modernBannerTitleStyle = HomeTextStyleModel.fromMap(
          modernAppearance['bannerTitleStyle'],
          fallback: const HomeTextStyleModel(
            fontSize: 22,
            colorValue: 0xFFFFFFFF,
            isBold: true,
            hasShadow: true,
            alignment: 'left',
          ),
        );

        _modernBannerSubtitleStyle = HomeTextStyleModel.fromMap(
          modernAppearance['bannerSubtitleStyle'],
          fallback: const HomeTextStyleModel(
            fontSize: 13,
            colorValue: 0xFFFFFFFF,
            isBold: true,
            hasShadow: true,
            alignment: 'left',
          ),
        );

        final rawButtonColor = modernAppearance['bannerButtonColor'];
        _modernBannerButtonColorValue = rawButtonColor is num
            ? rawButtonColor.toInt()
            : 0xFFFF7A1A;

        final rawButtonTextColor = modernAppearance['bannerButtonTextColor'];

        _modernBannerButtonTextColorValue = rawButtonTextColor is num
            ? rawButtonTextColor.toInt()
            : 0xFFFFFFFF;
        _modernBannerFrame = ModernBannerFrameSetting.fromMap(modernAppearance);
        _homeSectionOrder = HomeSectionOrder.normalize(
          modernAppearance['homeSectionOrder'],
        );
        _roomSection = HomeRoomSectionSetting.fromMap(
          modernAppearance['roomSection'],
        );
        _environmentSection = HomeEnvironmentSectionSetting.fromMap(
          modernAppearance['environmentSection'],
        );
        _aboutSection = HomeAboutSectionSetting.fromMap(
          modernAppearance['aboutSection'],
        );
        _newsSection = HomeNewsSectionSetting.fromMap(
          modernAppearance['newsSection'],
        );
        _quickBookingSection = HomeQuickBookingSectionSetting.fromMap(
          modernAppearance['quickBookingSection'],
        );
        _informationSections = HomeInformationSectionsSetting.fromMap(
          modernAppearance['informationSections'],
        );
        _appearancePresetId = homeAppearancePresetById(
          modernAppearance[homeAppearancePresetIdKey]?.toString(),
        )?.id;
        _browsingPresetId = null;
        _showStayServiceStrip =
            modernAppearance['showStayServiceStrip'] != false;
        _modernBannerPreviewImageUrl = _firstActiveBannerUrl(shopData);
        _brandStyle = StoreBrandStyle.fromMap(
          modernAppearance,
          logoUrl: _modernLogoUrl,
        );

        final storeHomeSetting = ModernStoreHomeSetting.fromMap(
          modernAppearance,
        );
        _showFeaturedStoreProducts = storeHomeSetting.showFeaturedProducts;
        _featuredStoreTitleController.text = storeHomeSetting.featuredTitle;
        _showStoreBanner = storeHomeSetting.showStoreBanner;
        _storeBannerTitleController.text = storeHomeSetting.storeBannerTitle;
        _storeBannerSubtitleController.text =
            storeHomeSetting.storeBannerSubtitle;
        _storeBannerButtonTextController.text =
            storeHomeSetting.storeBannerButtonText;
        _storeCardBackgroundFit = storeHomeSetting.storeBannerBackgroundFit;
        _storeCardBackgroundAlignment =
            storeHomeSetting.storeBannerBackgroundAlignment;
        _storeCardOverlayPreset = storeHomeSetting.storeBannerOverlayPreset;
        _storeCardOverlayTone = storeHomeSetting.storeBannerOverlayTone;
        _storeCardTitleColorPreset =
            storeHomeSetting.storeBannerTitleColorPreset;
        _storeCardSubtitleColorPreset =
            storeHomeSetting.storeBannerSubtitleColorPreset;
        _storeCardButtonColorPreset =
            storeHomeSetting.storeBannerButtonColorPreset;
        _storeCardContentPosition = storeHomeSetting.storeBannerContentPosition;
        _featuredProductLayout = storeHomeSetting.featuredProductLayout;
        _storeEntryLayout = storeHomeSetting.storeEntryLayout;
        _loadedFeaturedProductLayout = storeHomeSetting.featuredProductLayout;
        _loadedStoreEntryLayout = storeHomeSetting.storeEntryLayout;
        _committedStoreCardImageUrl = storeHomeSetting.storeBannerImageUrl;
        _committedStoreCardImagePath =
            storeHomeSetting.storeBannerImageStoragePath;
        _loadedShop = shopData == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(shopData);
        _navigationConfig = FrontendNavigationConfig.fromMap(modernAppearance);
        _savedNavigation = _navigationConfig;
        _appearanceDirty = false;
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('讀取外觀設定失敗：$error')));
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadModernLogo() async {
    if (_isUploadingModernLogo) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (pickedFile == null) return;

      final Uint8List bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _modernLogoPreviewBytes = bytes;
        _isUploadingModernLogo = true;
      });

      final String uploadedUrl = await ShopService.instance.uploadShopLogo(
        shopId: widget.shopId,
        bytes: bytes,
      );

      if (!mounted) return;

      setState(() {
        _modernLogoUrl = uploadedUrl;
        _modernLogoPreviewBytes = null;
        _isUploadingModernLogo = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('新版首頁 Logo 已更新')));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _modernLogoPreviewBytes = null;
        _isUploadingModernLogo = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logo 上傳失敗：$error')));
    }
  }

  String _firstActiveBannerUrl(Map<String, dynamic>? shopData) {
    final Object? rawBanners = shopData?['banners'];
    if (rawBanners is! List) {
      return '';
    }

    for (final Object? item in rawBanners) {
      if (item is! Map) {
        continue;
      }
      if (item['isActive'] == false) {
        continue;
      }
      final String imageUrl = (item['imageUrl'] ?? '').toString().trim();
      if (imageUrl.isNotEmpty) {
        return imageUrl;
      }
    }
    return '';
  }

  void _storeSelectedLayoutSettings() {
    _layoutSettings[_selectedLayout] = {
      'theme': _selectedTheme,
      'background': _selectedBackground,
      'cardStyle': _selectedCardStyle,
      'iconStyle': _selectedIconStyle,
      'density': _selectedDensity,
    };
  }

  void _applySelectedLayoutSettings() {
    final settings = _layoutSettings[_selectedLayout];

    if (settings == null) return;

    _selectedTheme = settings['theme'] ?? 'warmOrange';
    _selectedBackground = settings['background'] ?? 'warmWhite';
    _selectedCardStyle = settings['cardStyle'] ?? 'standard';
    _selectedIconStyle = settings['iconStyle'] ?? 'circle';
    _selectedDensity = settings['density'] ?? 'comfortable';
  }

  void _changeLayout(String layout) {
    if (layout == _selectedLayout) return;

    setState(() {
      _storeSelectedLayoutSettings();
      _selectedLayout = layout;
      _applySelectedLayoutSettings();
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      _storeSelectedLayoutSettings();
      final ModernStoreHomeSetting storeHomeForSave =
          await _storeHomeSettingForSave();

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .set({
            'homeAppearance': {
              'layout': _selectedLayout,
              'classic': Map<String, String>.from(_layoutSettings['classic']!),
              'modern': {
                ...Map<String, String>.from(_layoutSettings['modern']!),
                'headerSubtitle': StoreBrandTextPolicy.sanitizeSubtitle(
                  _modernHeaderSubtitleController.text,
                ),

                'bannerTitle': _modernBannerTitleController.text.trim(),

                'bannerSubtitle': _modernBannerSubtitleController.text.trim(),

                'bannerTitleStyle': _modernBannerTitleStyle.toMap(),

                'bannerSubtitleStyle': _modernBannerSubtitleStyle.toMap(),

                'bannerButtonText': _modernBannerButtonTextController.text
                    .trim(),

                'bannerButtonColor': _modernBannerButtonColorValue,

                'bannerButtonTextColor': _modernBannerButtonTextColorValue,

                ..._modernBannerFrame.toMap(),

                'themeColors': _modernTheme.toMap(),

                ..._brandStyle.toMap(),
                'homeSectionOrder': _homeSectionOrder,
                'roomSection': _roomSection.toMap(),
                'environmentSection': _environmentSection.toMap(),
                'aboutSection': _aboutSection.toMap(),
                'newsSection': _newsSection.toMap(),
                'quickBookingSection': _quickBookingSection.toMap(),
                'informationSections': _informationSections.toMap(),
                homeAppearancePresetIdKey: ?_appearancePresetId,
                'showStayServiceStrip': _showStayServiceStrip,

                ...storeHomeForSave.toMap(),
                ..._navigationConfig.toMap(),
              },
            },
            'floatingContactButton': {
              'enabled': _floatingButtonEnabled,
              'type': _floatingButtonType,
              'size': _floatingButtonSize,
              'label': _floatingButtonLabelController.text.trim(),
            },
            'storeChatEnabled':
                _floatingButtonType == ShopChatService.floatingTypePetnestChat,
          }, SetOptions(merge: true));

      _adoptStoreHome(storeHomeForSave);
      _savedNavigation = _navigationConfig;
      _appearanceDirty = false;

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('前台外觀設定已儲存')));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? '儲存失敗：Firestore 權限尚未開放'
                : '儲存失敗：${error.message ?? error.code}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('前台外觀設定')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bool desktopModern =
        MediaQuery.sizeOf(context).width >= 1100 && _selectedLayout == 'modern';
    final bool pinSaveOnEditor =
        desktopModern &&
        _tabController.index != ModernHomeAppearanceTabs.features;
    return PopScope(
      canPop: !_hasUnsaved,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || !_hasUnsaved) {
          return;
        }
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCF7),
        appBar: AppBar(
          title: const Text('前台外觀設定'),
          backgroundColor: const Color(0xFFFFFCF7),
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Listener(
              onPointerSignal: _onAppearanceTabSignal,
              child: TabBar(
                key: _appearanceTabBarKey,
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Icon(Icons.palette_outlined), text: '外觀設定'),
                  Tab(icon: Icon(Icons.color_lens_outlined), text: '首頁色彩'),
                  Tab(icon: Icon(Icons.bedroom_parent_outlined), text: '房型展示'),
                  Tab(icon: Icon(Icons.yard_outlined), text: '環境展示'),
                  Tab(icon: Icon(Icons.favorite_border), text: '關於我們'),
                  Tab(icon: Icon(Icons.campaign_outlined), text: '消息展示'),
                  Tab(icon: Icon(Icons.event_available_outlined), text: '快速預約'),
                  Tab(icon: Icon(Icons.description_outlined), text: '入住須知'),
                  Tab(icon: Icon(Icons.quiz_outlined), text: '常見問題'),
                  Tab(icon: Icon(Icons.star_outline), text: '顧客評價'),
                  Tab(icon: Icon(Icons.menu_rounded), text: '導覽設定'),
                  Tab(icon: Icon(Icons.widgets_outlined), text: '前台功能'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAppearancePane(desktopModern),
            _buildColorPane(desktopModern),
            _buildRoomPane(desktopModern),
            _buildEnvironmentPane(desktopModern),
            _buildAboutPane(desktopModern),
            _buildNewsPane(desktopModern),
            _buildQuickBookingPane(desktopModern),
            _buildPolicyPane(desktopModern),
            _buildFaqPane(desktopModern),
            _buildReviewPane(desktopModern),
            _buildNavigationPane(desktopModern),

            Scrollbar(
              controller: _featureScroll,
              thumbVisibility: true,
              child: ListView(
                controller: _featureScroll,
                primary: false,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildSectionTitle(
                    icon: Icons.support_agent,
                    title: '快速聯絡按鈕',
                    description: '設定前台右下角固定顯示的快速聯絡按鈕',
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _floatingButtonEnabled,
                            onChanged: (value) {
                              setState(() {
                                _floatingButtonEnabled = value;
                              });
                            },
                            title: const Text('啟用快速聯絡按鈕'),
                            subtitle: const Text('開啟後，前台右下角會顯示一顆聯絡按鈕'),
                          ),

                          const Divider(),

                          DropdownButtonFormField<String>(
                            value:
                                _availableFloatingTypes().contains(
                                  _floatingButtonType,
                                )
                                ? _floatingButtonType
                                : ShopChatService.floatingTypePetnestChat,
                            decoration: const InputDecoration(
                              labelText: '按鈕功能',
                              border: OutlineInputBorder(),
                            ),
                            items: _buildAvailableContactItems(),
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                _floatingButtonType = value;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          _buildFloatingTypeHint(),

                          const SizedBox(height: 16),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '按鈕大小',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment<String>(
                                  value: 'small',
                                  label: Text('小'),
                                  icon: Icon(Icons.circle, size: 12),
                                ),
                                ButtonSegment<String>(
                                  value: 'medium',
                                  label: Text('中'),
                                  icon: Icon(Icons.circle, size: 16),
                                ),
                                ButtonSegment<String>(
                                  value: 'large',
                                  label: Text('大'),
                                  icon: Icon(Icons.circle, size: 20),
                                ),
                              ],
                              selected: {_floatingButtonSize},
                              showSelectedIcon: false,
                              onSelectionChanged: (selectedSizes) {
                                if (selectedSizes.isEmpty) return;

                                setState(() {
                                  _floatingButtonSize = selectedSizes.first;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _floatingButtonSize == 'small'
                                ? '小尺寸：44 px'
                                : _floatingButtonSize == 'large'
                                ? '大尺寸：58 px'
                                : '中尺寸：52 px',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: _floatingButtonLabelController,
                            decoration: InputDecoration(
                              labelText: '按鈕文字',
                              hintText: ShopChatService.defaultLabelForType(
                                _floatingButtonType,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: pinSaveOnEditor ? null : _saveBar(),
      ),
    );
  }

  bool get _hasUnsaved {
    return _appearanceDirty || _navigationConfig != _savedNavigation;
  }

  Future<void> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('尚未儲存'),
          content: const Text('導覽與外觀的修改尚未儲存，要放棄這些變更嗎？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('繼續編輯'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放棄變更'),
            ),
          ],
        );
      },
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  FrontendNavShopState get _navShopState {
    return FrontendNavShopState.fromShop(
      _loadedShop,
      showMemberCenter: _modernTheme.drawerSetting.showMemberCenter,
      showShopMenus: _modernTheme.drawerSetting.showShopMenus,
      loggedIn: true,
    );
  }

  void _replaceModernTheme(HomeThemeModel value) {
    setState(() {
      _modernTheme = value;
      _appearanceDirty = true;
    });
  }

  HomeAppearanceDraft get _appearanceDraft {
    return HomeAppearanceDraft(
      theme: _modernTheme,
      sectionOrder: _homeSectionOrder,
      rooms: _roomSection,
      environment: _environmentSection,
      about: _aboutSection,
      news: _newsSection,
      quickBooking: _quickBookingSection,
      information: _informationSections,
      navigation: _navigationConfig,
      bannerFrame: _modernBannerFrame,
      showStayServiceStrip: _showStayServiceStrip,
      featuredProductLayout: _featuredProductLayout,
      storeEntryLayout: _storeEntryLayout,
    );
  }

  Map<String, dynamic> get _previewModernAppearance {
    final HomeAppearancePreset? browsing = homeAppearancePresetById(
      _browsingPresetId,
    );
    if (browsing == null) {
      return _draftModernAppearance;
    }
    final HomeAppearanceDraft next = browsing.apply(_appearanceDraft);
    return <String, dynamic>{
      ..._draftModernAppearance,
      'themeColors': next.theme.toMap(),
      'homeSectionOrder': next.sectionOrder,
      'roomSection': next.rooms.toMap(),
      'environmentSection': next.environment.toMap(),
      'aboutSection': next.about.toMap(),
      'newsSection': next.news.toMap(),
      'quickBookingSection': next.quickBooking.toMap(),
      'informationSections': next.information.toMap(),
      'showStayServiceStrip': next.showStayServiceStrip,
      'featuredProductLayout': next.featuredProductLayout,
      'storeEntryLayout': next.storeEntryLayout,
      ...next.bannerFrame.toMap(),
      ...next.navigation.toMap(),
    };
  }

  void _applyAppearancePreset(HomeAppearancePreset preset) {
    final HomeAppearanceDraft next = preset.apply(_appearanceDraft);
    setState(() {
      if (_selectedLayout != 'modern') {
        _storeSelectedLayoutSettings();
        _selectedLayout = 'modern';
        _applySelectedLayoutSettings();
      }
      _modernTheme = next.theme;
      _homeSectionOrder = next.sectionOrder;
      _roomSection = next.rooms;
      _environmentSection = next.environment;
      _aboutSection = next.about;
      _newsSection = next.news;
      _quickBookingSection = next.quickBooking;
      _informationSections = next.information;
      _navigationConfig = next.navigation;
      _modernBannerFrame = next.bannerFrame;
      _showStayServiceStrip = next.showStayServiceStrip;
      _featuredProductLayout = next.featuredProductLayout;
      _storeEntryLayout = next.storeEntryLayout;
      _appearancePresetId = preset.id;
      _browsingPresetId = null;
      _appearanceDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已套用『${preset.name}』預覽，確認後請儲存外觀設定。')),
    );
  }

  Widget _appearancePresetStrip() {
    return HomeAppearancePresetStrip(
      draft: _appearanceDraft,
      presetId: _appearancePresetId,
      previewingId: _browsingPresetId,
      accent: _modernTheme.primaryColor,
      onPreview: (HomeAppearancePreset preset) {
        setState(() => _browsingPresetId = preset.id);
      },
      onApply: _applyAppearancePreset,
    );
  }

  Widget _buildRoomPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text('房型展示只套用在新版前台。請先在外觀設定改用新版首頁。', style: TextStyle(height: 1.4)),
        ],
      );
    }
    final Widget settings = RoomSectionSettingsPanel(
      shopId: widget.shopId,
      setting: _roomSection,
      theme: _modernTheme,
      selectedRoomTypeId: _selectedRoomTypeId,
      onChanged: (HomeRoomSectionSetting value) {
        setState(() {
          _roomSection = value;
          _appearanceDirty = true;
        });
      },
      onManageRooms: _openRoomManagement,
    );
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'roomDesktop',
                focusSectionId: 'rooms',
                focusSectionToken: _roomFocusToken,
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openRoomSectionPreview,
              icon: const Icon(Icons.smartphone_outlined),
              label: const Text('預覽房型區塊'),
            ),
          ),
        ),
        Expanded(child: settings),
      ],
    );
  }

  Widget _buildEnvironmentPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text('環境展示只套用在新版前台。請先在外觀設定改用新版首頁。', style: TextStyle(height: 1.4)),
        ],
      );
    }
    final Widget settings = EnvironmentSectionSettingsPanel(
      setting: _environmentSection,
      theme: _modernTheme,
      onChanged: (HomeEnvironmentSectionSetting value) {
        setState(() {
          _environmentSection = value;
          _appearanceDirty = true;
        });
      },
    );
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'environmentDesktop',
                focusSectionId: 'facilities',
                focusSectionToken: _environmentFocusToken,
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openEnvironmentSectionPreview,
              icon: const Icon(Icons.smartphone_outlined),
              label: const Text('預覽環境區塊'),
            ),
          ),
        ),
        Expanded(child: settings),
      ],
    );
  }

  void _openEnvironmentSectionPreview() {
    setState(() => _environmentFocusToken++);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('預覽環境區塊'),
              leading: const CloseButton(),
            ),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: 'environmentDialog',
              focusSectionId: 'facilities',
              focusSectionToken: _environmentFocusToken,
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text(
            '關於我們首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
            style: TextStyle(height: 1.4),
          ),
        ],
      );
    }
    final Map<String, dynamic> intro = _loadedShop['environmentIntro'] is Map
        ? Map<String, dynamic>.from(_loadedShop['environmentIntro'] as Map)
        : <String, dynamic>{};
    final Widget settings = AboutSectionSettingsPanel(
      setting: _aboutSection,
      theme: _modernTheme,
      imageChoices: HomeAboutSectionSetting.imageChoices(
        shop: _loadedShop,
        environmentIntro: intro,
      ),
      onChanged: (HomeAboutSectionSetting value) {
        setState(() {
          _aboutSection = value;
          _appearanceDirty = true;
        });
      },
    );
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'aboutDesktop',
                focusSectionId: 'about',
                focusSectionToken: _aboutFocusToken,
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openAboutSectionPreview,
              icon: const Icon(Icons.smartphone_outlined),
              label: const Text('預覽關於我們'),
            ),
          ),
        ),
        Expanded(child: settings),
      ],
    );
  }

  Widget _buildNewsPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text(
            '最新消息首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
            style: TextStyle(height: 1.4),
          ),
        ],
      );
    }
    final Widget settings = NewsSectionSettingsPanel(
      setting: _newsSection,
      theme: _modernTheme,
      locked: _loadedShop['showAnnouncementSection'] == false,
      onOpenFeatures: () {
        _tabController.animateTo(ModernHomeAppearanceTabs.features);
      },
      onChanged: (HomeNewsSectionSetting value) {
        setState(() {
          _newsSection = value;
          _appearanceDirty = true;
        });
      },
    );
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'newsDesktop',
                focusSectionId: 'announcements',
                focusSectionToken: _newsFocusToken,
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openNewsSectionPreview,
              icon: const Icon(Icons.smartphone_outlined),
              label: const Text('預覽最新消息'),
            ),
          ),
        ),
        Expanded(child: settings),
      ],
    );
  }

  void _openNewsSectionPreview() {
    setState(() => _newsFocusToken++);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('預覽最新消息'),
              leading: const CloseButton(),
            ),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: 'newsDialog',
              focusSectionId: 'announcements',
              focusSectionToken: _newsFocusToken,
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  void _openAboutSectionPreview() {
    setState(() => _aboutFocusToken++);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('預覽關於我們'),
              leading: const CloseButton(),
            ),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: 'aboutDialog',
              focusSectionId: 'about',
              focusSectionToken: _aboutFocusToken,
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  void _openRoomManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopRoomTypePage(shopId: widget.shopId),
      ),
    );
  }

  void _openRoomSectionPreview() {
    setState(() => _roomFocusToken++);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('預覽房型區塊'),
              leading: const CloseButton(),
            ),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: 'roomDialog',
              focusSectionId: 'rooms',
              focusSectionToken: _roomFocusToken,
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text(
            '首頁色彩的細項設定套用在新版前台。請先在外觀設定改用新版首頁。經典版的主題與背景仍留在外觀設定。',
            style: TextStyle(height: 1.4),
          ),
        ],
      );
    }
    final Widget settings = Scrollbar(
      controller: _colorScroll,
      thumbVisibility: true,
      child: ListView(
        controller: _colorScroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 24),
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: HomeColorSettingsPanel(
                theme: _modernTheme,
                entryTheme: _colorEntryTheme,
                onChanged: _replaceModernTheme,
              ),
            ),
          ),
        ],
      ),
    );
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'desktop',
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('預覽'),
                icon: Icon(Icons.smartphone_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('設定'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: <int>{_homeCanvasPane},
            onSelectionChanged: (Set<int> value) {
              setState(() => _homeCanvasPane = value.first);
            },
          ),
        ),
        Expanded(
          child: _homeCanvasPane == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _homeCanvasPreview(
                    showCaption: false,
                    canvasMode: 'mobile',
                  ),
                )
              : settings,
        ),
      ],
    );
  }

  void _onAppearanceTabSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    final BuildContext? root = _appearanceTabBarKey.currentContext;
    if (root == null) {
      return;
    }
    ScrollableState? scrollable;
    void visit(Element element) {
      if (scrollable != null) {
        return;
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        scrollable = element.state as ScrollableState;
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildElements(visit);
    final ScrollPosition? position = scrollable?.position;
    if (position == null || !position.hasContentDimensions) {
      return;
    }
    final double delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) {
      return;
    }
    position.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  bool get _accommodationAvailable => _loadedShop['bookingEnabled'] != false;

  bool get _daycareAvailable => DaycareSettingsService.instance
      .isEnabledForShop(shop: _loadedShop, settings: _daycareSettings);

  Widget _buildQuickBookingPane(bool desktopModern) {
    return _sectionEditorPane(
      desktopModern: desktopModern,
      classicMessage: '快速預約首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
      previewLabel: '預覽快速預約',
      focusSectionId: 'quickBooking',
      focusSectionToken: _quickBookingFocusToken,
      canvasMode: 'quickBooking',
      settings: QuickBookingSectionSettingsPanel(
        setting: _quickBookingSection,
        theme: _modernTheme,
        accommodationAvailable: _accommodationAvailable,
        daycareAvailable: _daycareAvailable,
        onChanged: (HomeQuickBookingSectionSetting value) {
          setState(() {
            _quickBookingSection = value;
            _appearanceDirty = true;
          });
        },
      ),
    );
  }

  Widget _buildPolicyPane(bool desktopModern) {
    return _sectionEditorPane(
      desktopModern: desktopModern,
      classicMessage: '入住須知首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
      previewLabel: '預覽入住須知',
      focusSectionId: 'policy',
      focusSectionToken: _policyFocusToken,
      canvasMode: 'policy',
      settings: PolicySectionSettingsPanel(
        setting: _informationSections,
        theme: _modernTheme,
        onChanged: (HomeInformationSectionsSetting value) {
          setState(() {
            _informationSections = value;
            _appearanceDirty = true;
          });
        },
      ),
    );
  }

  Widget _buildFaqPane(bool desktopModern) {
    return _sectionEditorPane(
      desktopModern: desktopModern,
      classicMessage: '常見問題首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
      previewLabel: '預覽常見問題',
      focusSectionId: 'faq',
      focusSectionToken: _faqFocusToken,
      canvasMode: 'faq',
      settings: FaqSectionSettingsPanel(
        setting: _informationSections,
        theme: _modernTheme,
        locked: _loadedShop['showFaqSection'] == false,
        onOpenFeatures: () {
          _tabController.animateTo(ModernHomeAppearanceTabs.features);
        },
        onChanged: (HomeInformationSectionsSetting value) {
          setState(() {
            _informationSections = value;
            _appearanceDirty = true;
          });
        },
      ),
    );
  }

  Widget _buildReviewPane(bool desktopModern) {
    return _sectionEditorPane(
      desktopModern: desktopModern,
      classicMessage: '顧客評價首頁區塊只套用在新版前台。請先在外觀設定改用新版首頁。',
      previewLabel: '預覽顧客評價',
      focusSectionId: 'reviews',
      focusSectionToken: _reviewFocusToken,
      canvasMode: 'reviews',
      settings: ReviewSectionSettingsPanel(
        setting: _informationSections,
        theme: _modernTheme,
        onChanged: (HomeInformationSectionsSetting value) {
          setState(() {
            _informationSections = value;
            _appearanceDirty = true;
          });
        },
      ),
    );
  }

  Widget _sectionEditorPane({
    required bool desktopModern,
    required String classicMessage,
    required String previewLabel,
    required String focusSectionId,
    required int focusSectionToken,
    required String canvasMode,
    required Widget settings,
  }) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(classicMessage, style: const TextStyle(height: 1.4)),
        ],
      );
    }
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: '${canvasMode}Desktop',
                focusSectionId: focusSectionId,
                focusSectionToken: focusSectionToken,
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: settings),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openSectionPreview(
                title: previewLabel,
                focusSectionId: focusSectionId,
                canvasMode: canvasMode,
              ),
              icon: const Icon(Icons.smartphone_outlined),
              label: Text(previewLabel),
            ),
          ),
        ),
        Expanded(child: settings),
      ],
    );
  }

  void _openSectionPreview({
    required String title,
    required String focusSectionId,
    required String canvasMode,
  }) {
    setState(() {
      if (focusSectionId == 'quickBooking') {
        _quickBookingFocusToken++;
      } else if (focusSectionId == 'policy') {
        _policyFocusToken++;
      } else if (focusSectionId == 'faq') {
        _faqFocusToken++;
      } else if (focusSectionId == 'reviews') {
        _reviewFocusToken++;
      }
    });
    final int token = switch (focusSectionId) {
      'quickBooking' => _quickBookingFocusToken,
      'faq' => _faqFocusToken,
      'reviews' => _reviewFocusToken,
      _ => _policyFocusToken,
    };
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: Text(title), leading: const CloseButton()),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: '${canvasMode}Dialog',
              focusSectionId: focusSectionId,
              focusSectionToken: token,
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text('導覽設定只套用在新版前台。請先在外觀設定改用新版首頁。', style: TextStyle(height: 1.4)),
        ],
      );
    }
    if (desktopModern) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 452,
              child: _homeCanvasPreview(
                showCaption: true,
                canvasMode: 'desktop',
              ),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: _navigationSettingsScroll()),
                  _saveBar(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('預覽'),
                icon: Icon(Icons.smartphone_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('設定'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: <int>{_homeCanvasPane},
            onSelectionChanged: (Set<int> value) {
              setState(() => _homeCanvasPane = value.first);
            },
          ),
        ),
        Expanded(
          child: _homeCanvasPane == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _homeCanvasPreview(
                    showCaption: false,
                    canvasMode: 'mobile',
                  ),
                )
              : _navigationSettingsScroll(),
        ),
      ],
    );
  }

  Widget _navigationSettingsScroll() {
    return Scrollbar(
      controller: _navigationScroll,
      thumbVisibility: true,
      child: ListView(
        controller: _navigationScroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 24),
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: FrontendNavigationPanel(
                config: _navigationConfig,
                shopState: _navShopState,
                onChanged: (FrontendNavigationConfig value) {
                  setState(() {
                    _navigationConfig = value;
                    _appearanceDirty = true;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearancePane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return _classicAppearanceList();
    }
    if (desktopModern) {
      return _modernDesktopWorkspace();
    }
    return _modernMobileWorkspace();
  }

  bool get _desktopModernLayout =>
      MediaQuery.sizeOf(context).width >= 1100 && _selectedLayout == 'modern';

  void _selectHomeSection(String sectionId) {
    final int? tab = ModernHomeAppearanceTabs.sectionTab(sectionId);
    if (tab != null) {
      setState(() {
        _selectedHomeSection = sectionId;
        if (sectionId == 'policy') {
          _policyFocusToken++;
        } else if (sectionId == 'faq') {
          _faqFocusToken++;
        } else if (sectionId == 'reviews') {
          _reviewFocusToken++;
        } else if (sectionId == 'rooms') {
          _roomFocusToken++;
        } else if (sectionId == 'facilities') {
          _environmentFocusToken++;
        } else if (sectionId == 'about') {
          _aboutFocusToken++;
        } else if (sectionId == 'announcements') {
          _newsFocusToken++;
        } else if (sectionId == 'quickBooking') {
          _quickBookingFocusToken++;
        }
      });
      if (_tabController.index != tab) {
        _tabController.animateTo(tab);
      }
      return;
    }
    if (_selectedHomeSection == sectionId) {
      return;
    }
    setState(() {
      _selectedHomeSection = sectionId;
      if (!_desktopModernLayout) {
        _homeCanvasPane = 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final BuildContext? target = _settingsKeyFor(sectionId).currentContext;
      if (target == null) {
        return;
      }
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    });
  }

  GlobalKey _settingsKeyFor(String sectionId) {
    switch (sectionId) {
      case 'header':
        return _headerSettingsKey;
      case 'banners':
        return _bannerSettingsKey;
      case 'featured':
      case 'storeEntrance':
        return _storeSettingsKey;
      default:
        return _pendingSettingsKey;
    }
  }

  String _pendingSectionLabel(String? sectionId) {
    switch (sectionId) {
      case 'facilities':
        return '設備特色';
      case 'announcements':
        return '最新公告';
      case 'dailyCare':
        return '住宿日誌';
      case 'services':
        return '住宿服務';
      case 'footer':
        return '店家資訊';
      default:
        return '此區塊';
    }
  }

  bool get _pendingSectionSelected {
    switch (_selectedHomeSection) {
      case 'facilities':
      case 'announcements':
      case 'dailyCare':
      case 'services':
      case 'footer':
        return true;
      default:
        return false;
    }
  }

  Widget _homeCanvasPreview({
    required bool showCaption,
    required String canvasMode,
    bool embeddedAdminPreview = true,
    String? focusSectionId,
    int focusSectionToken = 0,
  }) {
    return ModernHomeEditorPreview(
      shopId: widget.shopId,
      draftModernAppearance: _previewModernAppearance,
      draftLogoUrl: _modernLogoUrl,
      showCaption: showCaption,
      showPhoneChrome: false,
      layoutCanvas: true,
      isEmbeddedAdminPreview: embeddedAdminPreview,
      canvasMode: canvasMode,
      frameWidth: 390,
      selectedSectionId: _selectedHomeSection,
      focusSectionId: focusSectionId,
      focusSectionToken: focusSectionToken,
      selectedRoomTypeId: _selectedRoomTypeId,
      onSelectRoomType: (String roomTypeId) {
        setState(() {
          _selectedRoomTypeId = roomTypeId.isEmpty ? null : roomTypeId;
        });
      },
      onSelectSection: _selectHomeSection,
      onBrandStyleChanged: (StoreBrandStyle style) {
        setState(() {
          _brandStyle = style;
          _appearanceDirty = true;
        });
      },
      onHomeSectionOrderChanged: (List<String> order) {
        setState(() {
          _homeSectionOrder = HomeSectionOrder.normalize(order);
          _appearanceDirty = true;
        });
      },
    );
  }

  Widget _classicAppearanceList() {
    return Scrollbar(
      controller: _appearanceScroll,
      thumbVisibility: true,
      child: ListView(
        controller: _appearanceScroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          _appearancePresetStrip(),
          const SizedBox(height: 18),
          _buildSectionTitle(
            icon: Icons.view_quilt_outlined,
            title: '首頁版型',
            description: '選擇顧客進入店家首頁時看到的排版',
          ),
          const SizedBox(height: 10),
          _buildLayoutSelector(),
          const SizedBox(height: 24),
          _buildSectionTitle(
            icon: Icons.palette_outlined,
            title: '主題顏色',
            description: '控制按鈕、圖示與重點文字的主要顏色',
          ),
          const SizedBox(height: 10),
          _buildThemeSelector(),
          const SizedBox(height: 24),
          _buildSectionTitle(
            icon: Icons.format_paint_outlined,
            title: '背景顏色',
            description: '選擇店家前台整體背景色',
          ),
          const SizedBox(height: 10),
          _buildBackgroundSelector(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _modernDesktopWorkspace() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 452,
            child: _homeCanvasPreview(showCaption: true, canvasMode: 'desktop'),
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, color: Color(0xFFE6E8EC)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: _modernSettingsScroll(includePreviewButton: false),
                ),
                _saveBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernSettingsScroll({required bool includePreviewButton}) {
    return Scrollbar(
      controller: _appearanceScroll,
      thumbVisibility: true,
      child: ListView(
        controller: _appearanceScroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 24),
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (includePreviewButton) ...<Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _openModernPreview,
                        icon: const Icon(Icons.smartphone_outlined),
                        label: const Text('預覽新版首頁'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._modernEditorSections(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernMobileWorkspace() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('預覽'),
                icon: Icon(Icons.smartphone_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('設定'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: <int>{_homeCanvasPane},
            onSelectionChanged: (Set<int> value) {
              setState(() => _homeCanvasPane = value.first);
            },
          ),
        ),
        Expanded(
          child: _homeCanvasPane == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _homeCanvasPreview(
                    showCaption: false,
                    canvasMode: 'mobile',
                  ),
                )
              : _modernSettingsScroll(includePreviewButton: false),
        ),
      ],
    );
  }

  void _openModernPreview() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('預覽新版首頁'),
              leading: const CloseButton(),
            ),
            body: _homeCanvasPreview(
              showCaption: false,
              canvasMode: 'dialog',
              embeddedAdminPreview: false,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _modernEditorSections() {
    return <Widget>[
      _appearancePresetStrip(),
      const SizedBox(height: 16),
      _editorCard(
        title: '新版首頁基本外觀',
        subtitle: '目前使用新版首頁',
        trailing: TextButton(
          onPressed: () => _changeLayout('classic'),
          child: const Text('改用經典版'),
        ),
        child: const Text(
          '顧客進入店家時會看到新版 Beta。經典版的顏色設定會保留。',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
      KeyedSubtree(
        key: _headerSettingsKey,
        child: _editorCard(
          title: '店家識別',
          subtitle: '固定在海報上方。可在左側預覽左右拖曳。',
          trailing: const Text(
            '固定顯示',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          child: StoreBrandSettingsCard(
            style: _brandStyle,
            theme: _modernTheme,
            subtitleController: _modernHeaderSubtitleController,
            logoSection: _buildModernLogoSettings(),
            hasLogo:
                _modernLogoUrl.trim().isNotEmpty ||
                _modernLogoPreviewBytes != null,
            onChanged: (StoreBrandStyle style) {
              setState(() {
                _brandStyle = style;
                _appearanceDirty = true;
              });
            },
          ),
        ),
      ),
      KeyedSubtree(
        key: _bannerSettingsKey,
        child: _editorCard(
          title: '首頁活動海報',
          subtitle: '影響首頁上方活動海報的顯示大小。圖片與按鈕仍到活動海報管理編輯。',
          summary: _bannerStatusText,
          child: _buildHomeBannerDisplaySettings(),
        ),
      ),
      if (StorefrontAccess.isModuleEnabled(_loadedShop))
        KeyedSubtree(
          key: _storeSettingsKey,
          child: _editorCard(
            title: '商城',
            subtitle: '商城首頁與商品展示已移至商城專屬設定。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '此區塊內容與外觀請至商城設定管理。首頁排序只決定它出現的位置。',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ShopStoreSettingsPage(
                            shopId: widget.shopId,
                            canManage: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('前往商城設定 →'),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_pendingSectionSelected)
        KeyedSubtree(
          key: _pendingSettingsKey,
          child: _editorCard(
            title: _pendingSectionLabel(_selectedHomeSection),
            subtitle: '此區塊設定後續開放',
            child: const Text(
              '此區塊設定後續開放',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ),
      _editorCard(
        title: '側邊選單',
        subtitle: '影響新版首頁左上角選單要顯示的內容',
        child: _buildModernDrawerSettings(),
      ),
    ];
  }

  Widget _editorCard({
    required String title,
    required String subtitle,
    required Widget child,
    String? summary,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A5B12),
                      ),
                    ),
                  ],
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveSettings,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? '儲存中...' : '儲存外觀設定'),
        ),
      ),
    );
  }

  List<String> _availableFloatingTypes() {
    return <String>[
      ShopChatService.floatingTypePetnestChat,
      if (_shopPhone.isNotEmpty) ShopChatService.floatingTypePhone,
      if (_shopLineUrl.isNotEmpty) ShopChatService.floatingTypeLine,
      if (_shopFacebookUrl.isNotEmpty) ShopChatService.floatingTypeFacebook,
      if (_shopInstagramUrl.isNotEmpty) ShopChatService.floatingTypeInstagram,
    ];
  }

  Widget _buildFloatingTypeHint() {
    switch (_floatingButtonType) {
      case ShopChatService.floatingTypePetnestChat:
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '會員點擊後會直接開啟與目前店家的 PetNest 對話。',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        );
      case ShopChatService.floatingTypePhone:
        return _buildContactDataHint(
          label: '電話號碼',
          value: _shopPhone,
          emptyHint: '請先在店家基本資料填寫電話。',
        );
      case ShopChatService.floatingTypeLine:
        return _buildContactDataHint(
          label: 'LINE 連結',
          value: _shopLineUrl,
          emptyHint: '請先在店家基本資料填寫 LINE 連結。',
        );
      case ShopChatService.floatingTypeFacebook:
        return _buildContactDataHint(
          label: 'Facebook 連結',
          value: _shopFacebookUrl,
          emptyHint: '請先在店家基本資料填寫 Facebook 連結。',
        );
      case ShopChatService.floatingTypeInstagram:
        return _buildContactDataHint(
          label: 'Instagram 連結',
          value: _shopInstagramUrl,
          emptyHint: '請先在店家基本資料填寫 Instagram 連結。',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContactDataHint({
    required String label,
    required String value,
    required String emptyHint,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? emptyHint : '$label：$value',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }

  bool get _hasAvailableContactMethod {
    return _shopPhone.isNotEmpty ||
        _shopLineUrl.isNotEmpty ||
        _shopFacebookUrl.isNotEmpty ||
        _shopInstagramUrl.isNotEmpty;
  }

  List<DropdownMenuItem<String>> _buildAvailableContactItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: ShopChatService.floatingTypePetnestChat,
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 20),
            SizedBox(width: 10),
            Text('PetNest 店家聊天'),
          ],
        ),
      ),
    ];

    if (_shopPhone.isNotEmpty) {
      items.add(
        const DropdownMenuItem(
          value: 'phone',
          child: Row(
            children: [
              Icon(Icons.phone_outlined, size: 20),
              SizedBox(width: 10),
              Text('電話'),
            ],
          ),
        ),
      );
    }

    if (_shopLineUrl.isNotEmpty) {
      items.add(
        const DropdownMenuItem(
          value: 'line',
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 20),
              SizedBox(width: 10),
              Text('LINE'),
            ],
          ),
        ),
      );
    }

    if (_shopFacebookUrl.isNotEmpty) {
      items.add(
        const DropdownMenuItem(
          value: 'facebook',
          child: Row(
            children: [
              Icon(Icons.facebook_outlined, size: 20),
              SizedBox(width: 10),
              Text('Facebook'),
            ],
          ),
        ),
      );
    }

    if (_shopInstagramUrl.isNotEmpty) {
      items.add(
        const DropdownMenuItem(
          value: 'instagram',
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 20),
              SizedBox(width: 10),
              Text('Instagram'),
            ],
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.brown.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutSelector() {
    return Column(
      children: [
        _buildLayoutCard(
          value: 'classic',
          title: '經典版',
          subtitle: '目前穩定使用中的首頁版面',
          icon: Icons.dashboard_outlined,
        ),
        const SizedBox(height: 10),
        _buildLayoutCard(
          value: 'modern',
          title: '新版 Beta',
          subtitle: '較緊湊、房型與評價資訊更醒目',
          icon: Icons.auto_awesome_outlined,
          beta: true,
        ),
      ],
    );
  }

  Widget _buildLayoutCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    bool beta = false,
  }) {
    final selected = _selectedLayout == value;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _changeLayout(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade300,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected
                  ? Colors.orange.shade100
                  : Colors.grey.shade100,
              child: Icon(
                icon,
                color: selected ? Colors.orange.shade800 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (beta) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Beta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedLayout,
              onChanged: (newValue) {
                if (newValue == null) return;

                _changeLayout(newValue);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLogoSettings() {
    final bool hasPreview = _modernLogoPreviewBytes != null;
    final bool hasNetworkLogo = _modernLogoUrl.trim().isNotEmpty;

    Widget logoPreview;

    if (hasPreview) {
      logoPreview = Image.memory(_modernLogoPreviewBytes!, fit: BoxFit.contain);
    } else if (hasNetworkLogo) {
      logoPreview = Image.network(
        _modernLogoUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.pets_rounded,
            size: 42,
            color: Color(0xFFFF8A00),
          );
        },
      );
    } else {
      logoPreview = const Icon(
        Icons.pets_rounded,
        size: 42,
        color: Color(0xFFFF8A00),
      );
    }

    final Widget logoButton = FilledButton.icon(
      onPressed: _isUploadingModernLogo ? null : _pickAndUploadModernLogo,
      icon: _isUploadingModernLogo
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.photo_library_outlined),
      label: Text(
        _isUploadingModernLogo
            ? '上傳中'
            : hasNetworkLogo
            ? '更換 Logo'
            : '上傳 Logo',
      ),
    );
    final Widget logoThumb = Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: logoPreview,
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inline = constraints.maxWidth >= 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (inline)
              Row(
                children: <Widget>[
                  logoThumb,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '店家 Logo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasNetworkLogo || hasPreview
                              ? '新版 Footer 會顯示目前圖片'
                              : '尚未設定時，會顯示預設腳印',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  logoButton,
                ],
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  logoThumb,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasNetworkLogo || hasPreview
                          ? '新版 Footer 會顯示目前圖片'
                          : '尚未設定時，會顯示預設腳印',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: logoButton),
            ],
            const SizedBox(height: 8),
            const Text(
              '建議 600 × 600 px，PNG 或 JPG，最大 5 MB。圖片會完整顯示。',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFrameChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) {
        if (value) {
          onSelected();
        }
      },
    );
  }

  Widget _buildModernBannerFramePreview() {
    return Padding(
      padding: HomeBannerDisplay.outerPadding(_modernBannerFrame.widthPreset),
      child: AspectRatio(
        aspectRatio: _modernBannerFrame.frameAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ColoredBox(
            color: Colors.black,
            child: _modernBannerPreviewImageUrl.isEmpty
                ? Center(
                    child: Text(
                      '尚未設定活動海報',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  )
                : Image.network(
                    _modernBannerPreviewImageUrl,
                    fit: _modernBannerFrame.completePosterFit,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                            ),
                          );
                        },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBannerDisplaySettings() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '海報顯示尺寸',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '分別設定首頁海報的寬度與高度，所有輪播海報會使用相同尺寸。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 12),
          _buildModernBannerFramePreview(),
          const SizedBox(height: 14),
          const Text('海報寬度', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildFrameChoiceChip(
                label: '窄版',
                selected:
                    _modernBannerFrame.widthPreset ==
                    HomeBannerWidthPreset.narrow,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      widthPreset: HomeBannerWidthPreset.narrow,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '標準',
                selected:
                    _modernBannerFrame.widthPreset ==
                    HomeBannerWidthPreset.standard,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      widthPreset: HomeBannerWidthPreset.standard,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '滿寬',
                selected:
                    _modernBannerFrame.widthPreset ==
                    HomeBannerWidthPreset.full,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      widthPreset: HomeBannerWidthPreset.full,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('海報高度', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildFrameChoiceChip(
                label: '矮版',
                selected:
                    _modernBannerFrame.heightPreset ==
                    HomeBannerHeightPreset.short,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      heightPreset: HomeBannerHeightPreset.short,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '標準',
                selected:
                    _modernBannerFrame.heightPreset ==
                    HomeBannerHeightPreset.standard,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      heightPreset: HomeBannerHeightPreset.standard,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '高版',
                selected:
                    _modernBannerFrame.heightPreset ==
                    HomeBannerHeightPreset.tall,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      heightPreset: HomeBannerHeightPreset.tall,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '標準高度完整顯示16:9海報；矮版或高版會填滿版面，可能裁切圖片邊緣。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 4),
          const Text(
            '矮版或高版可能裁切海報邊緣，重要文字請放在圖片中央安全範圍。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopMediaPage(shopId: widget.shopId),
                ),
              );
            },
            icon: const Icon(Icons.collections_outlined),
            label: const Text('管理活動海報'),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDrawerSettings() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示會員區'),
            subtitle: const Text('會員中心、我的訂單、我的評價'),
            value: _modernTheme.drawerSetting.showMemberCenter,
            onChanged: (value) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  drawerSetting: _modernTheme.drawerSetting.copyWith(
                    showMemberCenter: value,
                  ),
                );
              });
            },
          ),

          const Divider(),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示最新訂單'),
            value: _modernTheme.drawerSetting.showLatestBooking,
            onChanged: (value) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  drawerSetting: _modernTheme.drawerSetting.copyWith(
                    showLatestBooking: value,
                  ),
                );
              });
            },
          ),

          if (!_hasAvailableContactMethod)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '目前尚未設定電話、LINE、Facebook 或 Instagram，請先到店家基本資料完成設定。',
                    ),
                  ),
                ],
              ),
            ),

          const Divider(),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示店家功能'),
            value: _modernTheme.drawerSetting.showShopMenus,
            onChanged: (value) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  drawerSetting: _modernTheme.drawerSetting.copyWith(
                    showShopMenus: value,
                  ),
                );
              });
            },
          ),

          const Divider(),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示底部店家資訊'),
            value: _modernTheme.drawerSetting.showFooter,
            onChanged: (value) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  drawerSetting: _modernTheme.drawerSetting.copyWith(
                    showFooter: value,
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    const themes = [
      _ColorOption(value: 'warmOrange', title: '暖橘', color: Color(0xFFC96E18)),
      _ColorOption(value: 'milkTea', title: '奶茶', color: Color(0xFF9B7653)),
      _ColorOption(value: 'rosePink', title: '柔粉', color: Color(0xFFD77887)),
      _ColorOption(
        value: 'forestGreen',
        title: '森林綠',
        color: Color(0xFF4F7D61),
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: themes.map((theme) {
        final selected = _selectedTheme == theme.value;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedTheme = theme.value;
            });
          },
          child: Container(
            width: 98,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? theme.color : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.color,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  theme.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundSelector() {
    const backgrounds = [
      _ColorOption(value: 'warmWhite', title: '暖白', color: Color(0xFFFFFCF7)),
      _ColorOption(value: 'cream', title: '奶油', color: Color(0xFFFFF5E8)),
      _ColorOption(value: 'lightPink', title: '淡粉', color: Color(0xFFFFF4F5)),
      _ColorOption(value: 'lightGray', title: '淡灰', color: Color(0xFFF5F5F5)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: backgrounds.map((background) {
        final selected = _selectedBackground == background.value;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedBackground = background.value;
            });
          },
          child: Container(
            width: 98,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: background.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Colors.orange : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: background.color,
                  child: selected
                      ? const Icon(Icons.check, color: Colors.brown, size: 20)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  background.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorOption {
  const _ColorOption({
    required this.value,
    required this.title,
    required this.color,
  });

  final String value;
  final String title;
  final Color color;
}
