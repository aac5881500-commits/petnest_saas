// 檔案名稱：lib/features/shop/pages/shop_theme_setting_page.dart
// 功能說明：設定首頁版型、主題顏色、卡片與圖示樣式
// 🎨 店家前台外觀設定頁

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/home_text_style_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_banner_display.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/home_banner_service.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/frontend_navigation_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_editor_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_settings_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';

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
  String _committedStoreCardImageUrl = '';
  String _committedStoreCardImagePath = '';
  String _pendingStoreCardImageUrl = '';
  String _pendingStoreCardImagePath = '';
  bool _removeStoreCardImage = false;
  bool _uploadingStoreCardImage = false;
  String _selectedLayout = 'classic';
  String _selectedTheme = 'warmOrange';
  String _selectedBackground = 'warmWhite';
  String _selectedCardStyle = 'standard';
  String _selectedIconStyle = 'circle';
  String _selectedDensity = 'comfortable';
  StoreBrandStyle _brandStyle = const StoreBrandStyle();
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
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _bindModernDraftListeners();
    _loadSettings();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) {
      return;
    }
    setState(() {});
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
    _discardPendingStoreCardImage();
    super.dispose();
  }

  Map<String, dynamic> get _draftModernAppearance {
    return <String, dynamic>{
      ...Map<String, String>.from(_layoutSettings['modern']!),
      'headerSubtitle': _modernHeaderSubtitleController.text.trim(),
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
      ..._draftStoreHomeSetting.toMap(),
      ..._navigationConfig.toMap(),
    };
  }

  String get _bannerStatusText {
    final String size = switch (_modernBannerFrame.displaySize) {
      HomeBannerDisplaySize.small => '精簡',
      HomeBannerDisplaySize.large => '寬版',
      HomeBannerDisplaySize.standard => '標準',
    };
    return '已啟用・$_enabledHomeBannerCount 張海報・$size';
  }

  HomeThemeModel get _shopThemeForStore {
    if (_selectedLayout == 'modern') {
      return _modernTheme;
    }
    return HomeThemeModel.fromClassicSettings(
      rawData: <String, String>{
        'theme': _selectedTheme,
        'background': _selectedBackground,
      },
    );
  }

  ModernStoreHomeSetting get _draftStoreHomeSetting {
    final String imageUrl = _removeStoreCardImage
        ? ''
        : (_pendingStoreCardImageUrl.isNotEmpty
              ? _pendingStoreCardImageUrl
              : _committedStoreCardImageUrl);
    final String imagePath = _removeStoreCardImage
        ? ''
        : (_pendingStoreCardImagePath.isNotEmpty
              ? _pendingStoreCardImagePath
              : _committedStoreCardImagePath);
    return ModernStoreHomeSetting(
      showFeaturedProducts: _showFeaturedStoreProducts,
      featuredTitle: _featuredStoreTitleController.text.trim(),
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
    );
  }

  Future<void> _discardPendingStoreCardImage() async {
    final String path = _pendingStoreCardImagePath.trim();
    final String url = _pendingStoreCardImageUrl.trim();
    if (path.isEmpty && url.isEmpty) {
      return;
    }
    if (path == _committedStoreCardImagePath ||
        url == _committedStoreCardImageUrl) {
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: url,
      imageStoragePath: path,
    );
  }

  String _storeCardImageError(Object error) {
    final String message = error.toString();
    if (message.contains('5MB') || message.contains('5 MB')) {
      return '圖片不可超過 5 MB';
    }
    return message;
  }

  Future<void> _pickStoreEntryCardImage() async {
    try {
      setState(() => _uploadingStoreCardImage = true);
      final result = await FixedImagePickFlow.pickCropAndUpload(
        context: context,
        spec: FixedImageSpec.storeEntryBackground,
        title: '裁切商城入口背景',
        shopId: widget.shopId,
        itemId: 'store_entry_card/p_${DateTime.now().millisecondsSinceEpoch}',
        folder: 'home',
        imageType: 'home_store_entry_card',
        idMetadataKey: 'storeEntryCardId',
      );
      if (result == null) {
        return;
      }
      await _discardPendingStoreCardImage();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingStoreCardImageUrl = result.imageUrl;
        _pendingStoreCardImagePath = result.imageStoragePath;
        _removeStoreCardImage = false;
        if (_storeCardOverlayPreset == ModernStoreCardOverlays.none) {
          _storeCardOverlayPreset = ModernStoreCardOverlays.standard;
        }
        if (_storeCardTitleColorPreset == ModernStoreCardTextColors.dark) {
          _storeCardTitleColorPreset = ModernStoreCardTextColors.light;
          _storeCardSubtitleColorPreset = ModernStoreCardTextColors.light;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_storeCardImageError(error))));
    } finally {
      if (mounted) {
        setState(() => _uploadingStoreCardImage = false);
      }
    }
  }

  void _markRemoveStoreEntryCardImage() {
    final String pendingUrl = _pendingStoreCardImageUrl;
    final String pendingPath = _pendingStoreCardImagePath;
    setState(() {
      _removeStoreCardImage = true;
      _pendingStoreCardImageUrl = '';
      _pendingStoreCardImagePath = '';
    });
    if (pendingUrl.isNotEmpty || pendingPath.isNotEmpty) {
      InventoryImageService.instance.tryDeleteImage(
        imageUrl: pendingUrl,
        imageStoragePath: pendingPath,
      );
    }
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
            (modernAppearance['headerSubtitle'] ?? '讓每一隻貓咪都有溫暖的家').toString();
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
        _committedStoreCardImageUrl = storeHomeSetting.storeBannerImageUrl;
        _committedStoreCardImagePath =
            storeHomeSetting.storeBannerImageStoragePath;
        _pendingStoreCardImageUrl = '';
        _pendingStoreCardImagePath = '';
        _removeStoreCardImage = false;
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

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .set({
            'homeAppearance': {
              'layout': _selectedLayout,
              'classic': Map<String, String>.from(_layoutSettings['classic']!),
              'modern': {
                ...Map<String, String>.from(_layoutSettings['modern']!),
                'headerSubtitle': _modernHeaderSubtitleController.text.trim(),

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

                ..._draftStoreHomeSetting.toMap(),
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

      final ModernStoreHomeSetting savedStoreCard = _draftStoreHomeSetting;
      if (_removeStoreCardImage) {
        await _discardPendingStoreCardImage();
      }
      if (_removeStoreCardImage || _pendingStoreCardImagePath.isNotEmpty) {
        final bool replacedOfficial =
            _committedStoreCardImagePath.isNotEmpty &&
            _committedStoreCardImagePath !=
                savedStoreCard.storeBannerImageStoragePath;
        if (replacedOfficial || _removeStoreCardImage) {
          await InventoryImageService.instance.tryDeleteImage(
            imageUrl: _committedStoreCardImageUrl,
            imageStoragePath: _committedStoreCardImagePath,
          );
        }
      }
      _committedStoreCardImageUrl = savedStoreCard.storeBannerImageUrl;
      _committedStoreCardImagePath = savedStoreCard.storeBannerImageStoragePath;
      _pendingStoreCardImageUrl = '';
      _pendingStoreCardImagePath = '';
      _removeStoreCardImage = false;
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
        desktopModern && _tabController.index != 3;
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: MediaQuery.sizeOf(context).width < 760,
          tabAlignment: MediaQuery.sizeOf(context).width < 760
              ? TabAlignment.start
              : TabAlignment.fill,
          tabs: const [
            Tab(icon: Icon(Icons.palette_outlined), text: '外觀設定'),
            Tab(icon: Icon(Icons.color_lens_outlined), text: '首頁色彩'),
            Tab(icon: Icon(Icons.menu_rounded), text: '導覽設定'),
            Tab(icon: Icon(Icons.widgets_outlined), text: '前台功能'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildAppearancePane(desktopModern),
          _buildColorPane(desktopModern),
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

  Widget _buildNavigationPane(bool desktopModern) {
    if (_selectedLayout != 'modern') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const <Widget>[
          Text(
            '導覽設定只套用在新版前台。請先在外觀設定改用新版首頁。',
            style: TextStyle(height: 1.4),
          ),
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
      case 'rooms':
        return '熱門房型';
      case 'services':
        return '住宿服務';
      case 'reviews':
        return '顧客評價';
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
      case 'rooms':
      case 'services':
      case 'reviews':
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
  }) {
    return ModernHomeEditorPreview(
      shopId: widget.shopId,
      draftModernAppearance: _draftModernAppearance,
      draftLogoUrl: _modernLogoUrl,
      showCaption: showCaption,
      showPhoneChrome: false,
      layoutCanvas: true,
      isEmbeddedAdminPreview: embeddedAdminPreview,
      canvasMode: canvasMode,
      frameWidth: 390,
      selectedSectionId: _selectedHomeSection,
      onSelectSection: _selectHomeSection,
      onBrandStyleChanged: (StoreBrandStyle style) {
        setState(() {
          _brandStyle = style;
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
      KeyedSubtree(
        key: _storeSettingsKey,
        child: _editorCard(
          title: '首頁賣場入口',
          subtitle: '影響首頁精選商品與寵物賣場入口卡片，不改商城頁面',
          child: _buildModernStoreHomeSettings(),
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
      padding: HomeBannerDisplay.outerPadding(_modernBannerFrame.displaySize),
      child: AspectRatio(
        aspectRatio: HomeBannerDisplay.aspectRatio,
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
                    fit: BoxFit.contain,
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
            '海報顯示大小',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '只調整首頁海報的外距。完整海報固定 16:9，不會改比例或裁切圖片。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildModernBannerFramePreview(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildFrameChoiceChip(
                label: '精簡',
                selected:
                    _modernBannerFrame.displaySize ==
                    HomeBannerDisplaySize.small,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      displaySize: HomeBannerDisplaySize.small,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '標準',
                selected:
                    _modernBannerFrame.displaySize ==
                    HomeBannerDisplaySize.standard,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      displaySize: HomeBannerDisplaySize.standard,
                    );
                  });
                },
              ),
              _buildFrameChoiceChip(
                label: '寬版',
                selected:
                    _modernBannerFrame.displaySize ==
                    HomeBannerDisplaySize.large,
                onSelected: () {
                  setState(() {
                    _modernBannerFrame = _modernBannerFrame.copyWith(
                      displaySize: HomeBannerDisplaySize.large,
                    );
                  });
                },
              ),
            ],
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

  Widget _buildModernStoreHomeSettings() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示精選商品'),
            subtitle: const Text('關閉後，新版首頁不顯示精選商品區'),
            value: _showFeaturedStoreProducts,
            onChanged: (bool value) {
              setState(() {
                _showFeaturedStoreProducts = value;
              });
            },
          ),
          TextField(
            controller: _featuredStoreTitleController,
            maxLength: 12,
            enabled: _showFeaturedStoreProducts,
            decoration: const InputDecoration(
              labelText: '精選商品標題',
              helperText: '預設：精選商品',
              border: OutlineInputBorder(),
            ),
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示首頁賣場卡片'),
            subtitle: const Text('關閉後，新版首頁不顯示寵物賣場入口'),
            value: _showStoreBanner,
            onChanged: (bool value) {
              setState(() {
                _showStoreBanner = value;
              });
            },
          ),
          const Text('預覽', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          IgnorePointer(
            child: ModernHomeStoreCard(
              theme: _shopThemeForStore,
              setting: _draftStoreHomeSetting,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _storeBannerTitleController,
            maxLength: 12,
            enabled: _showStoreBanner,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '卡片標題',
              helperText: '預設：寵物賣場',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _storeBannerSubtitleController,
            maxLength: 24,
            enabled: _showStoreBanner,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '卡片副標',
              helperText: '預設：精選毛孩好物，把喜歡帶回家',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _storeBannerButtonTextController,
            maxLength: 10,
            enabled: _showStoreBanner,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '按鈕文字',
              helperText: '預設：逛逛賣場',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('按鈕顏色', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: ModernStoreCardButtonColors.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardButtonColors.label(value)),
                selected: _storeCardButtonColorPreset == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardButtonColorPreset = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('主要文字顏色', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: ModernStoreCardTextColors.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardTextColors.label(value)),
                selected: _storeCardTitleColorPreset == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardTitleColorPreset = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('次要文字顏色', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: ModernStoreCardTextColors.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardTextColors.label(value)),
                selected: _storeCardSubtitleColorPreset == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardSubtitleColorPreset = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('文字位置', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: ModernStoreCardPositions.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardPositions.label(value)),
                selected: _storeCardContentPosition == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardContentPosition = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('卡片背景圖片', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            FixedImageSpec.storeEntryBackground.hintText,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: !_showStoreBanner || _uploadingStoreCardImage
                    ? null
                    : _pickStoreEntryCardImage,
                child: Text(
                  _draftStoreHomeSetting.hasBackgroundImage ? '更換圖片' : '上傳圖片',
                ),
              ),
              if (_draftStoreHomeSetting.hasBackgroundImage)
                TextButton(
                  onPressed: _uploadingStoreCardImage
                      ? null
                      : _markRemoveStoreEntryCardImage,
                  child: const Text('移除圖片'),
                ),
            ],
          ),
          if (_uploadingStoreCardImage)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          const Text('背景圖片顯示方式'),
          Wrap(
            spacing: 8,
            children: ModernStoreCardFits.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardFits.label(value)),
                selected: _storeCardBackgroundFit == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardBackgroundFit = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('圖片焦點'),
          Wrap(
            spacing: 8,
            children: ModernStoreCardAlignments.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardAlignments.label(value)),
                selected: _storeCardBackgroundAlignment == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardBackgroundAlignment = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Text('背景遮罩'),
          Wrap(
            spacing: 8,
            children: ModernStoreCardOverlays.all.map((String value) {
              return ChoiceChip(
                label: Text(ModernStoreCardOverlays.label(value)),
                selected: _storeCardOverlayPreset == value,
                onSelected: _showStoreBanner
                    ? (_) {
                        setState(() => _storeCardOverlayPreset = value);
                      }
                    : null,
              );
            }).toList(),
          ),
          if (_storeCardOverlayPreset !=
              ModernStoreCardOverlays.none) ...<Widget>[
            const SizedBox(height: 8),
            const Text('遮罩顏色'),
            Wrap(
              spacing: 8,
              children: ModernStoreCardOverlayTones.all.map((String value) {
                return ChoiceChip(
                  label: Text(ModernStoreCardOverlayTones.label(value)),
                  selected: _storeCardOverlayTone == value,
                  onSelected: _showStoreBanner
                      ? (_) {
                          setState(() => _storeCardOverlayTone = value);
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
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
