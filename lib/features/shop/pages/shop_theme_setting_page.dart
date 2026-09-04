// lib/features/shop/pages/shop_theme_setting_page.dart
// 🎨 店家前台外觀設定頁
// 功能：設定首頁版型、主題顏色、卡片與圖示樣式

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/models/home_text_style_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_media_page.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';

class ShopThemeSettingPage extends StatefulWidget {
  const ShopThemeSettingPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopThemeSettingPage> createState() => _ShopThemeSettingPageState();
}

class _ShopThemeSettingPageState extends State<ShopThemeSettingPage> {
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
  bool _showModernLeftHeaderIcon = true;
  bool _showModernRightHeaderIcon = true;
  String _modernLeftHeaderIcon = 'paw';
  String _modernRightHeaderIcon = 'paw';
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

  HomeTextStyleModel _modernBannerShopNameStyle = const HomeTextStyleModel(
    fontSize: 16,
    colorValue: 0xFFFFFFFF,
    isBold: true,
    hasShadow: true,
    alignment: 'left',
  );
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
  final ScrollController _appearanceScroll = ScrollController();
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
    _loadSettings();
  }

  @override
  void dispose() {
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
    _featureScroll.dispose();
    _discardPendingStoreCardImage();
    super.dispose();
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
          fallback: const HomeThemeModel(
            backgroundColorValue: 0xFFFFFBF7,
            cardColorValue: 0xFFFFFFFF,
            cardBorderColorValue: 0xFFFFD9B3,
            primaryColorValue: 0xFFFF8A00,
            textColorValue: 0xFF3A2A20,
          ),
        );

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
        _showModernLeftHeaderIcon =
            modernAppearance['showLeftHeaderIcon'] != false;

        _showModernRightHeaderIcon =
            modernAppearance['showRightHeaderIcon'] != false;
        _modernLeftHeaderIcon = (modernAppearance['leftHeaderIcon'] ?? 'paw')
            .toString();

        _modernRightHeaderIcon = (modernAppearance['rightHeaderIcon'] ?? 'paw')
            .toString();
        _modernBannerShopNameStyle = HomeTextStyleModel.fromMap(
          modernAppearance['bannerShopNameStyle'],
          fallback: const HomeTextStyleModel(
            fontSize: 16,
            colorValue: 0xFFFFFFFF,
            isBold: true,
            hasShadow: true,
            alignment: 'left',
          ),
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

                'showLeftHeaderIcon': _showModernLeftHeaderIcon,
                'showRightHeaderIcon': _showModernRightHeaderIcon,

                'leftHeaderIcon': _modernLeftHeaderIcon,

                'rightHeaderIcon': _modernRightHeaderIcon,

                ..._draftStoreHomeSetting.toMap(),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCF7),
        appBar: AppBar(
          title: const Text('前台外觀設定'),
          backgroundColor: const Color(0xFFFFFCF7),
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.palette_outlined), text: '外觀設定'),
              Tab(icon: Icon(Icons.widgets_outlined), text: '前台功能'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Scrollbar(
              controller: _appearanceScroll,
              thumbVisibility: true,
              child: ListView(
                controller: _appearanceScroll,
                primary: false,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildSectionTitle(
                    icon: Icons.view_quilt_outlined,
                    title: '首頁版型',
                    description: '選擇顧客進入店家首頁時看到的排版',
                  ),

                  const SizedBox(height: 10),

                  _buildLayoutSelector(),

                  if (_selectedLayout == 'modern') ...[
                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.image_outlined,
                      title: '新版店家 Logo',
                      description: '只用於新版首頁 Footer，經典版原有顯示不受影響',
                    ),

                    const SizedBox(height: 10),

                    _buildModernLogoSettings(),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.title_rounded,
                      title: 'Header 文字',
                      description: '只影響新版首頁，不會修改正式店家名稱',
                    ),
                    const SizedBox(height: 10),

                    _buildModernHeaderTextSettings(),

                    const SizedBox(height: 16),

                    _buildSectionTitle(
                      icon: Icons.photo_size_select_large_outlined,
                      title: '首頁活動海報',
                      description: '此設定會套用到首頁所有活動海報。每張海報的圖片、字幕與按鈕請到活動海報管理編輯。',
                    ),
                    const SizedBox(height: 10),
                    _buildHomeBannerDisplaySettings(),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.storefront_outlined,
                      title: '首頁賣場卡片',
                      description: '此設定只影響新版首頁上的「寵物賣場入口卡片」，不影響真正商城頁面的設定。',
                    ),

                    const SizedBox(height: 10),

                    _buildModernStoreHomeSettings(),

                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.color_lens_outlined,
                      title: '新版主題顏色',
                      description: '設定新版首頁的背景、卡片、外框、圖示與文字顏色',
                    ),

                    const SizedBox(height: 10),

                    _buildModernThemeColorSettings(),
                    const SizedBox(height: 24),

                    _buildSectionTitle(
                      icon: Icons.menu_open_rounded,
                      title: '新版 Drawer 設定',
                      description: '控制側邊選單要顯示哪些內容',
                    ),

                    const SizedBox(height: 10),

                    _buildModernDrawerSettings(),
                  ],

                  if (_selectedLayout == 'classic') ...[
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
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),

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
        bottomNavigationBar: SafeArea(
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
          Row(
            children: [
              Container(
                width: 82,
                height: 82,
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '店家 Logo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasNetworkLogo || hasPreview
                          ? '新版 Footer 會顯示目前圖片'
                          : '尚未設定時，會顯示預設腳印',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
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
                  ? 'Logo 上傳中...'
                  : hasNetworkLogo
                  ? '更換 Logo 圖片'
                  : '上傳 Logo 圖片',
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            '建議 Logo 尺寸：600 × 600 px（正方形）\n'
            '支援 PNG（透明背景）或 JPG，最大 5 MB。\n'
            '系統會完整顯示圖片，不會裁切。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeaderTextSettings() {
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
          TextField(
            controller: _modernHeaderSubtitleController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '店名下方副標',
              helperText: '留空並儲存後，新版首頁不顯示副標',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 6),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示左側圖示'),
            subtitle: const Text('控制店家名稱左側的小圖示'),
            value: _showModernLeftHeaderIcon,
            onChanged: (value) {
              setState(() {
                _showModernLeftHeaderIcon = value;
              });
            },
          ),

          if (_showModernLeftHeaderIcon) ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _modernLeftHeaderIcon,
              decoration: const InputDecoration(
                labelText: '左側圖示樣式',
                border: OutlineInputBorder(),
              ),
              items: _buildHeaderIconDropdownItems(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _modernLeftHeaderIcon = value;
                });
              },
            ),
          ],

          const SizedBox(height: 10),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示右側圖示'),
            subtitle: const Text('控制店家名稱右側的小圖示'),
            value: _showModernRightHeaderIcon,
            onChanged: (value) {
              setState(() {
                _showModernRightHeaderIcon = value;
              });
            },
          ),

          if (_showModernRightHeaderIcon) ...[
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _modernRightHeaderIcon,
              decoration: const InputDecoration(
                labelText: '右側圖示樣式',
                border: OutlineInputBorder(),
              ),
              items: _buildHeaderIconDropdownItems(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _modernRightHeaderIcon = value;
                });
              },
            ),
          ],
        ],
      ),
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
    return AspectRatio(
      aspectRatio: _modernBannerFrame.aspectRatio,
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
                  fit: BoxFit.cover,
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
            '此設定會套用到首頁所有活動海報。',
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
                label: '小',
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
                label: '大',
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

  Widget _buildBannerColorOption({
    required int colorValue,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = Color(colorValue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.orange.shade700 : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.computeLuminance() > 0.85
                  ? Colors.grey.shade400
                  : Colors.transparent,
            ),
          ),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: color.computeLuminance() > 0.55
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildModernThemeColorSettings() {
    const backgroundColors = <int>[
      0xFFFFFBF7,
      0xFFFFF5E8,
      0xFFFFF4F5,
      0xFFF5F5F5,
      0xFFF3F7F4,
      0xFFFFFFFF,
    ];

    const cardColors = <int>[
      0xFFFFFFFF,
      0xFFFFFAF4,
      0xFFFFF4F5,
      0xFFF8F8F8,
      0xFFF3F8F5,
      0xFFFFF7E8,
    ];

    const borderColors = <int>[
      0xFFFFD9B3,
      0xFFE5D1BC,
      0xFFF1C6CC,
      0xFFD9D9D9,
      0xFFC9DED0,
      0xFFFFC980,
    ];

    const primaryColors = <int>[
      0xFFFF8A00,
      0xFF9B7653,
      0xFFD77887,
      0xFF4F7D61,
      0xFF5C6BC0,
      0xFFE85D5D,
    ];

    const textColors = <int>[
      0xFF3A2A20,
      0xFF212121,
      0xFF5D4037,
      0xFF37474F,
      0xFF355E45,
      0xFF6D4C41,
    ];

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
          _buildModernThemeColorRow(
            title: '頁面背景色',
            description: '新版首頁最底層的整體背景',
            selectedColorValue: _modernTheme.backgroundColorValue,
            colorValues: backgroundColors,
            onChanged: (colorValue) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  backgroundColorValue: colorValue,
                );
              });
            },
          ),

          const Divider(height: 30),

          _buildModernThemeColorRow(
            title: '卡片背景色',
            description: '房型、服務、公告等卡片的底色',
            selectedColorValue: _modernTheme.cardColorValue,
            colorValues: cardColors,
            onChanged: (colorValue) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  cardColorValue: colorValue,
                );
              });
            },
          ),

          const Divider(height: 30),

          _buildModernThemeColorRow(
            title: '卡片外框色',
            description: '卡片邊框與部分分隔線的顏色',
            selectedColorValue: _modernTheme.cardBorderColorValue,
            colorValues: borderColors,
            onChanged: (colorValue) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  cardBorderColorValue: colorValue,
                );
              });
            },
          ),

          const Divider(height: 30),

          _buildModernThemeColorRow(
            title: '主題重點色',
            description: '圖示、按鈕與重點標題使用的顏色',
            selectedColorValue: _modernTheme.primaryColorValue,
            colorValues: primaryColors,
            onChanged: (colorValue) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  primaryColorValue: colorValue,
                );
              });
            },
          ),

          const Divider(height: 30),

          _buildModernThemeColorRow(
            title: '一般文字色',
            description: '新版首頁主要標題與一般文字的顏色',
            selectedColorValue: _modernTheme.textColorValue,
            colorValues: textColors,
            onChanged: (colorValue) {
              setState(() {
                _modernTheme = _modernTheme.copyWith(
                  textColorValue: colorValue,
                );
              });
            },
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

  Widget _buildModernThemeColorRow({
    required String title,
    required String description,
    required int selectedColorValue,
    required List<int> colorValues,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 3),

        Text(
          description,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colorValues.map((colorValue) {
            return _buildBannerColorOption(
              colorValue: colorValue,
              isSelected: selectedColorValue == colorValue,
              onTap: () {
                onChanged(colorValue);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildHeaderIconDropdownItems() {
    const options = <Map<String, dynamic>>[
      {'value': 'paw', 'label': '腳印', 'icon': Icons.pets_rounded},
      {'value': 'heart', 'label': '愛心', 'icon': Icons.favorite_rounded},
      {'value': 'star', 'label': '星星', 'icon': Icons.star_rounded},
      {'value': 'home', 'label': '房屋', 'icon': Icons.home_rounded},
      {
        'value': 'crown',
        'label': '皇冠',
        'icon': Icons.workspace_premium_rounded,
      },
    ];

    return options.map((option) {
      return DropdownMenuItem<String>(
        value: option['value'] as String,
        child: Row(
          children: [
            Icon(
              option['icon'] as IconData,
              size: 20,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            Text(option['label'] as String),
          ],
        ),
      );
    }).toList();
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

  Widget _buildChoiceCard({
    required String value,
    required List<_SettingOption> options,
    required ValueChanged<String> onChanged,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: options.map((option) {
          final selected = value == option.value;

          return RadioListTile<String>(
            value: option.value,
            groupValue: value,
            onChanged: (newValue) {
              if (newValue == null) return;
              onChanged(newValue);
            },
            secondary: Icon(option.icon),
            title: Text(option.title),
            subtitle: Text(option.subtitle),
            selected: selected,
          );
        }).toList(),
      ),
    );
  }
}

class _SettingOption {
  const _SettingOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
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
