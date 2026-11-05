import '../modern_home/store_entry_photo.dart';
import 'package:petnest_saas/core/models/store_entry_builtin_images.dart';
// 檔案名稱：lib/features/shop/widgets/store/store_front_home_settings_section.dart
// 功能說明：編輯旅館首頁上的商城展示。資料仍寫回 homeAppearance.modern。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_image_pick_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_store_card.dart';

class StoreFrontHomeSettingsSection extends StatefulWidget {
  const StoreFrontHomeSettingsSection({
    super.key,
    required this.shopId,
    required this.canManage,
    this.initialSetting,
    this.theme,
    this.onChanged,
    this.onBusyChanged,
    this.entryOnly = false,
    this.fallbackImageUrl = '',
  });

  final String shopId;
  final bool canManage;
  final ModernStoreHomeSetting? initialSetting;
  final HomeThemeModel? theme;
  final ValueChanged<ModernStoreHomeSetting>? onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool entryOnly;
  final String fallbackImageUrl;

  @override
  State<StoreFrontHomeSettingsSection> createState() =>
      StoreFrontHomeSettingsSectionState();
}

class StoreFrontHomeSettingsSectionState
    extends State<StoreFrontHomeSettingsSection>
    with AutomaticKeepAliveClientMixin<StoreFrontHomeSettingsSection> {
  final TextEditingController _featuredTitle = TextEditingController(
    text: ModernStoreHomeSetting.defaultFeaturedTitle,
  );
  final TextEditingController _bannerTitle = TextEditingController(
    text: ModernStoreHomeSetting.defaultBannerTitle,
  );
  final TextEditingController _bannerSubtitle = TextEditingController(
    text: ModernStoreHomeSetting.defaultBannerSubtitle,
  );
  final TextEditingController _bannerButton = TextEditingController(
    text: ModernStoreHomeSetting.defaultBannerButtonText,
  );

  final TextEditingController _sectionTitleController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  late final Future<void> _loading;
  bool _uploading = false;
  bool _showFeatured = true;
  bool _showBanner = true;
  bool _removeImage = false;
  String _entryPlacement = 'standalone', _sectionTitle = '';
  bool _headingAccent = true;
  String _featuredLayout = ModernFeaturedProductLayouts.horizontal;
  String _entryLayout = ModernStoreEntryLayouts.banner;
  String _fit = ModernStoreCardFits.cover;
  String _alignment = ModernStoreCardAlignments.center;
  String _overlay = ModernStoreCardOverlays.none;
  String _overlayTone = ModernStoreCardOverlayTones.dark;
  String _titleColor = ModernStoreCardTextColors.dark;
  String _subtitleColor = ModernStoreCardTextColors.dark;
  String _buttonColor = ModernStoreCardButtonColors.brand;
  String _position = ModernStoreCardPositions.centerLeft;
  String _committedUrl = '';
  String _committedPath = '';
  String _pendingUrl = '';
  String _pendingPath = '';
  String _secondUrl = '';
  String _secondPath = '';
  String _pendingSecondUrl = '';
  String _pendingSecondPath = '';
  HomeThemeModel _theme = HomeThemeModel.modernDefault;

  @override
  void initState() {
    super.initState();
    _loading = _load();
    for (final controller in [_bannerTitle, _bannerSubtitle, _bannerButton]) {
      controller.addListener(_notifyDraft);
    }
  }

  @override
  void dispose() {
    _discardPending();
    _discardSecondPending();
    _featuredTitle.dispose();
    _sectionTitleController.dispose();
    _bannerTitle.dispose();
    _bannerSubtitle.dispose();
    _bannerButton.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  bool _applying = false;
  void _notifyDraft() {
    if (_loaded && !_applying) widget.onChanged?.call(_draft);
  }

  void _edit(VoidCallback action) {
    setState(action);
    _notifyDraft();
  }

  Future<void> acceptSaved(ModernStoreHomeSetting saved) async {
    final oldUrl = _committedUrl;
    final oldPath = _committedPath;
    final oldSecondUrl = _secondUrl;
    final oldSecondPath = _secondPath;
    setState(() => _apply(saved));
    if (oldSecondPath.isNotEmpty &&
        oldSecondPath != saved.storeEntrySecondImageStoragePath) {
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: oldSecondUrl,
        imageStoragePath: oldSecondPath,
      );
    }
    if (oldPath.isNotEmpty && oldPath != saved.storeBannerImageStoragePath) {
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: oldUrl,
        imageStoragePath: oldPath,
      );
    }
  }

  @override
  void didUpdateWidget(covariant StoreFrontHomeSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialSetting;
    if (next != null) {
      _entryLayout = next.storeEntryLayout;
      _showBanner = next.showStoreBanner;
    }
  }

  Future<void> _load() async {
    if (widget.initialSetting != null) {
      _apply(widget.initialSetting!);
      _theme = widget.theme ?? HomeThemeModel.modernDefault;
      _loaded = true;
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .get();
    if (!mounted) {
      return;
    }
    final Map<String, dynamic> shop = snapshot.data() ?? <String, dynamic>{};
    final Object? rawAppearance = shop['homeAppearance'];
    final Map<String, dynamic> appearance = rawAppearance is Map
        ? Map<String, dynamic>.from(rawAppearance)
        : <String, dynamic>{};
    final Object? rawModern = appearance['modern'];
    final Map<String, dynamic> modern = rawModern is Map
        ? Map<String, dynamic>.from(rawModern)
        : <String, dynamic>{};
    final ModernStoreHomeSetting setting = ModernStoreHomeSetting.fromMap(
      modern,
    );
    setState(() {
      _apply(setting);
      _theme = HomeThemeModel.fromMap(
        modern['themeColors'],
        fallback: HomeThemeModel.modernDefault,
      );
      _loaded = true;
    });
  }

  void _apply(ModernStoreHomeSetting setting) {
    _applying = true;
    _entryLayout = setting.storeEntryLayout;
    _entryPlacement = setting.storeEntryPlacement;
    _sectionTitle = setting.storeSectionTitle;
    if (_sectionTitleController.text != _sectionTitle) {
      _sectionTitleController.text = _sectionTitle;
    }
    _headingAccent = setting.storeHeadingAccent;
    _showFeatured = setting.showFeaturedProducts;
    _featuredTitle.text = setting.featuredTitle;
    _featuredLayout = setting.featuredProductLayout;
    _showBanner = setting.showStoreBanner;
    _bannerTitle.text = setting.storeBannerTitle;
    _bannerSubtitle.text = setting.storeBannerSubtitle;
    _bannerButton.text = setting.storeBannerButtonText;
    _fit = setting.storeBannerBackgroundFit;
    _alignment = setting.storeBannerBackgroundAlignment;
    _overlay = setting.storeBannerOverlayPreset;
    _overlayTone = setting.storeBannerOverlayTone;
    _titleColor = setting.storeBannerTitleColorPreset;
    _subtitleColor = setting.storeBannerSubtitleColorPreset;
    _buttonColor = setting.storeBannerButtonColorPreset;
    _position = setting.storeBannerContentPosition;
    _committedUrl = setting.storeBannerImageUrl;
    _committedPath = setting.storeBannerImageStoragePath;
    _secondUrl = setting.storeEntrySecondImageUrl;
    _secondPath = setting.storeEntrySecondImageStoragePath;
    _pendingSecondUrl = '';
    _pendingSecondPath = '';
    _pendingUrl = '';
    _pendingPath = '';
    _removeImage = false;
    _applying = false;
  }

  ModernStoreHomeSetting get _draft {
    final String imageUrl = _removeImage
        ? ''
        : (_pendingUrl.isNotEmpty ? _pendingUrl : _committedUrl);
    final String imagePath = _removeImage
        ? ''
        : (_pendingUrl.isNotEmpty ? _pendingPath : _committedPath);
    return ModernStoreHomeSetting(
      showFeaturedProducts: _showFeatured,
      featuredTitle: _featuredTitle.text.trim(),
      featuredProductLayout: _featuredLayout,
      showStoreBanner: _showBanner,
      storeBannerTitle: _bannerTitle.text.trim(),
      storeBannerSubtitle: _bannerSubtitle.text.trim(),
      storeBannerButtonText: _bannerButton.text.trim(),
      storeBannerImageUrl: imageUrl,
      storeBannerImageStoragePath: imagePath,
      storeBannerBackgroundFit: _fit,
      storeBannerBackgroundAlignment: _alignment,
      storeBannerOverlayPreset: _overlay,
      storeBannerOverlayTone: _overlayTone,
      storeBannerTitleColorPreset: _titleColor,
      storeBannerSubtitleColorPreset: _subtitleColor,
      storeBannerButtonColorPreset: _buttonColor,
      storeBannerContentPosition: _position,
      storeEntryLayout: _entryLayout,
      storeEntryPlacement: _entryPlacement,
      storeSectionTitle: _sectionTitle,
      storeHeadingAccent: _headingAccent,
      storeEntrySecondImageUrl: _pendingSecondUrl.isNotEmpty
          ? _pendingSecondUrl
          : _secondUrl,
      storeEntrySecondImageStoragePath: _pendingSecondUrl.isNotEmpty
          ? _pendingSecondPath
          : _secondPath,
    );
  }

  Future<void> save() async {
    await _loading;
    if (!_loaded || _saving || !widget.canManage) {
      return;
    }
    setState(() => _saving = true);
    try {
      final ModernStoreHomeSetting setting = _draft;
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update(<String, dynamic>{
            for (final MapEntry<String, dynamic> entry
                in setting.toMap().entries)
              if (widget.entryOnly ||
                  const {
                    'showFeaturedStoreProducts',
                    'featuredStoreTitle',
                    'featuredProductLayout',
                  }.contains(entry.key))
                'homeAppearance.modern.${entry.key}': entry.value,
          });
      if (widget.entryOnly && (_removeImage || _pendingPath.isNotEmpty)) {
        final bool replaced =
            _committedPath.isNotEmpty &&
            _committedPath != setting.storeBannerImageStoragePath;
        if (replaced || _removeImage) {
          await InventoryImageService.instance.tryDeleteImage(
            imageUrl: _committedUrl,
            imageStoragePath: _committedPath,
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() => _apply(setting));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _discardPending() async {
    final String path = _pendingPath.trim();
    final String url = _pendingUrl.trim();
    if (path.isEmpty && url.isEmpty) {
      return;
    }
    if (path == _committedPath || url == _committedUrl) {
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: url,
      imageStoragePath: path,
    );
  }

  Future<void> _discardSecondPending() async {
    if (_pendingSecondPath.isNotEmpty && _pendingSecondPath != _secondPath) {
      await InventoryImageService.instance.tryDeleteImage(
        imageUrl: _pendingSecondUrl,
        imageStoragePath: _pendingSecondPath,
      );
    }
  }

  Future<void> _pickImage({bool secondary = false}) async {
    try {
      _edit(() => _uploading = true);
      widget.onBusyChanged?.call(true);
      final result = await FixedImagePickFlow.pickCropAndUpload(
        context: context,
        spec: FixedImageSpec.storeEntryBackground,
        title: secondary ? '裁切商城入口第二張圖片' : '裁切商城入口圖片',
        shopId: widget.shopId,
        itemId: 'store_entry_card/p_${DateTime.now().millisecondsSinceEpoch}',
        folder: 'home',
        imageType: 'home_store_entry_card',
        idMetadataKey: 'storeEntryCardId',
      );
      if (result == null || !mounted) {
        return;
      }
      if (secondary) {
        await _discardSecondPending();
        if (!mounted) return;
        _edit(() {
          _pendingSecondUrl = result.imageUrl;
          _pendingSecondPath = result.imageStoragePath;
        });
        return;
      }
      await _discardPending();
      if (!mounted) {
        return;
      }
      _edit(() {
        _pendingUrl = result.imageUrl;
        _pendingPath = result.imageStoragePath;
        _removeImage = false;
        if ((!ModernStoreEntryLayouts.quickTemplates.containsKey(
                  _entryLayout,
                ) ||
                _entryLayout == ModernStoreEntryLayouts.photoBanner) &&
            _overlay == ModernStoreCardOverlays.none) {
          _overlay = ModernStoreCardOverlays.standard;
        }
        if ((!ModernStoreEntryLayouts.quickTemplates.containsKey(
                  _entryLayout,
                ) ||
                _entryLayout == ModernStoreEntryLayouts.photoBanner) &&
            _titleColor == ModernStoreCardTextColors.dark) {
          _titleColor = ModernStoreCardTextColors.light;
          _subtitleColor = ModernStoreCardTextColors.light;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('5MB') || message.contains('5 MB')
                ? '圖片不可超過 5 MB'
                : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        _edit(() => _uploading = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  void _markRemoveImage() {
    final String pendingUrl = _pendingUrl;
    final String pendingPath = _pendingPath;
    _edit(() {
      _removeImage = true;
      _pendingUrl = '';
      _pendingPath = '';
    });
    if (pendingUrl.isNotEmpty || pendingPath.isNotEmpty) {
      InventoryImageService.instance.tryDeleteImage(
        imageUrl: pendingUrl,
        imageStoragePath: pendingPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final bool enabled = widget.canManage && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!widget.entryOnly) ...[
          const SizedBox(height: 28),
          const Text(
            '旅館首頁精選商品',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('首頁商城入口的版型、圖片與文字已移至「前台外觀設定 → 商城入口」。'),
        ],
        if (!widget.entryOnly) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('首頁顯示精選商品'),
            value: _showFeatured,
            onChanged: enabled
                ? (bool value) => _edit(() => _showFeatured = value)
                : null,
          ),
          TextField(
            controller: _featuredTitle,
            enabled: enabled && _showFeatured,
            maxLength: 12,
            decoration: const InputDecoration(
              labelText: '首頁精選商品標題',
              helperText: '預設：精選商品',
            ),
          ),
          const Text('商品排列', style: TextStyle(fontWeight: FontWeight.w700)),
          _option(
            ModernFeaturedProductLayouts.horizontal,
            _featuredLayout,
            '橫向滑動',
            enabled,
            (String value) => _edit(() => _featuredLayout = value),
          ),
          _option(
            ModernFeaturedProductLayouts.featured,
            _featuredLayout,
            '精選大卡',
            enabled,
            (String value) => _edit(() => _featuredLayout = value),
          ),
          _option(
            ModernFeaturedProductLayouts.grid,
            _featuredLayout,
            '雙欄商品',
            enabled,
            (String value) => _edit(() => _featuredLayout = value),
          ),
        ],
        if (widget.entryOnly) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示商城入口'),
            value: _showBanner,
            onChanged: enabled
                ? (bool value) => _edit(() => _showBanner = value)
                : null,
          ),
          TextFormField(
            controller: _sectionTitleController,
            decoration: const InputDecoration(
              labelText: '商城區塊標題（留空不顯示）',
              helperText: '例如：好物商城；與卡片內的商城名稱分開設定',
            ),
            maxLength: 24,
            onFieldSubmitted: (value) =>
                _edit(() => _sectionTitle = value.trim()),
            onChanged: (value) {
              _sectionTitle = value;
              _notifyDraft();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('標題左側主題色豎線（暖橘色槓）'),
            value: _headingAccent,
            onChanged: enabled
                ? (value) => _edit(() => _headingAccent = value)
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _entryPlacement,
            decoration: const InputDecoration(labelText: '商城入口位置'),
            items: const [
              DropdownMenuItem(value: 'standalone', child: Text('獨立區塊')),
              DropdownMenuItem(value: 'news', child: Text('消息右側並排卡')),
              DropdownMenuItem(value: 'rooms', child: Text('房型標題右側按鈕')),
            ],
            onChanged: enabled
                ? (value) => _edit(() => _entryPlacement = value!)
                : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('並排模式的區塊標題在「消息展示」設定；房型標題右側按鈕沿用下方按鈕文字。'),
          ),
          _quickTemplates(enabled),
          const Text('商城入口樣式', style: TextStyle(fontWeight: FontWeight.w700)),
          _option(
            ModernStoreEntryLayouts.banner,
            _entryLayout,
            '橫幅',
            enabled,
            (String value) => _edit(() => _entryLayout = value),
          ),
          _option(
            ModernStoreEntryLayouts.brand,
            _entryLayout,
            '品牌卡',
            enabled,
            (String value) => _edit(() => _entryLayout = value),
          ),
          _option(
            ModernStoreEntryLayouts.showcase,
            _entryLayout,
            '商品櫥窗',
            enabled,
            (String value) => _edit(() => _entryLayout = value),
          ),
          const SizedBox(height: 24),
          const Text(
            '商城入口外觀',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('即時預覽', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          IgnorePointer(
            child: ModernHomeStoreCard(
              theme: widget.theme ?? _theme,
              setting: _draft,
              height: _entryLayout == ModernStoreEntryLayouts.brand ? 210 : 176,
              fallbackImageUrl: widget.fallbackImageUrl,
              previewChrome: true,
            ),
          ),
          TextField(
            controller: _bannerTitle,
            enabled: enabled && _showBanner,
            maxLength: 12,
            onChanged: (_) => _edit(() {}),
            decoration: const InputDecoration(
              labelText: '卡片標題',
              helperText: '預設：寵物賣場',
            ),
          ),
          TextField(
            controller: _bannerSubtitle,
            enabled: enabled && _showBanner,
            maxLength: 24,
            onChanged: (_) => _edit(() {}),
            decoration: const InputDecoration(
              labelText: '副標',
              helperText: '預設：精選毛孩好物，把喜歡帶回家',
            ),
          ),
          TextField(
            controller: _bannerButton,
            enabled: enabled && _showBanner,
            maxLength: 10,
            onChanged: (_) => _edit(() {}),
            decoration: const InputDecoration(
              labelText: '按鈕文字',
              helperText: '預設：逛逛賣場',
            ),
          ),
          if (_entryLayout == ModernStoreEntryLayouts.layeredPhotos) ...[
            const SizedBox(height: 16),
            const Text('第二張照片', style: TextStyle(fontWeight: FontWeight.w700)),
            const Text('兩張照片分開上傳；切換其他模板仍會保留。'),
            if (_draft.storeEntrySecondImageUrl.isNotEmpty)
              SizedBox(
                height: 100,
                child: StoreEntryPhoto(
                  _draft.storeEntrySecondImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            OutlinedButton.icon(
              onPressed: enabled && !_uploading
                  ? () => _pickImage(secondary: true)
                  : null,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('更換第二張照片'),
            ),
          ],
          _fold('背景', <Widget>[
            if (ModernStoreEntryLayouts.quickTemplates.containsKey(
                  _entryLayout,
                ) &&
                StoreEntryBuiltinImages.primary(_entryLayout).isNotEmpty)
              OutlinedButton.icon(
                onPressed: enabled && !_uploading
                    ? () => _edit(() => _useDefaultPhotos(replace: true))
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: const Text('使用模板預設圖片'),
              ),
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
                  onPressed: !enabled || !_showBanner || _uploading
                      ? null
                      : _pickImage,
                  child: Text(_draft.hasBackgroundImage ? '更換圖片' : '上傳圖片'),
                ),
                if (_draft.hasBackgroundImage)
                  TextButton(
                    onPressed: !enabled || _uploading ? null : _markRemoveImage,
                    child: const Text('移除圖片'),
                  ),
              ],
            ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            _choices(
              '背景圖片顯示方式',
              ModernStoreCardFits.all,
              _fit,
              ModernStoreCardFits.label,
              enabled && _showBanner,
              (String value) => _edit(() => _fit = value),
            ),
            _choices(
              '圖片焦點',
              ModernStoreCardAlignments.all,
              _alignment,
              ModernStoreCardAlignments.label,
              enabled && _showBanner,
              (String value) => _edit(() => _alignment = value),
            ),
            _choices(
              '背景遮罩',
              ModernStoreCardOverlays.all,
              _overlay,
              ModernStoreCardOverlays.label,
              enabled && _showBanner,
              (String value) => _edit(() => _overlay = value),
            ),
            if (_overlay != ModernStoreCardOverlays.none)
              _choices(
                '遮罩顏色',
                ModernStoreCardOverlayTones.all,
                _overlayTone,
                ModernStoreCardOverlayTones.label,
                enabled && _showBanner,
                (String value) => _edit(() => _overlayTone = value),
              ),
          ]),
          _fold('文字', <Widget>[
            _choices(
              '主要文字顏色',
              ModernStoreCardTextColors.all,
              _titleColor,
              ModernStoreCardTextColors.label,
              enabled && _showBanner,
              (String value) => _edit(() => _titleColor = value),
            ),
            _choices(
              '次要文字顏色',
              ModernStoreCardTextColors.all,
              _subtitleColor,
              ModernStoreCardTextColors.label,
              enabled && _showBanner,
              (String value) => _edit(() => _subtitleColor = value),
            ),
          ]),
          _fold('按鈕', <Widget>[
            _choices(
              '按鈕顏色',
              ModernStoreCardButtonColors.all,
              _buttonColor,
              ModernStoreCardButtonColors.label,
              enabled && _showBanner,
              (String value) => _edit(() => _buttonColor = value),
            ),
          ]),
          _fold('位置', <Widget>[
            _choices(
              '文字位置',
              ModernStoreCardPositions.all,
              _position,
              ModernStoreCardPositions.label,
              enabled && _showBanner,
              (String value) => _edit(() => _position = value),
            ),
          ]),
        ],
      ],
    );
  }

  void _useDefaultPhotos({bool replace = false}) {
    final current = _draft;
    final primary = StoreEntryBuiltinImages.primary(_entryLayout);
    if (primary.isNotEmpty &&
        (replace ||
            current.storeBannerImageUrl.isEmpty ||
            StoreEntryBuiltinImages.asset(current.storeBannerImageUrl) !=
                null)) {
      if (_pendingPath.isNotEmpty) {
        InventoryImageService.instance.tryDeleteImage(
          imageUrl: _pendingUrl,
          imageStoragePath: _pendingPath,
        );
      }
      _pendingUrl = primary;
      _pendingPath = '';
      _removeImage = false;
    }
    if (_entryLayout == ModernStoreEntryLayouts.layeredPhotos &&
        (replace ||
            current.storeEntrySecondImageUrl.isEmpty ||
            StoreEntryBuiltinImages.asset(current.storeEntrySecondImageUrl) !=
                null)) {
      if (_pendingSecondPath.isNotEmpty) {
        InventoryImageService.instance.tryDeleteImage(
          imageUrl: _pendingSecondUrl,
          imageStoragePath: _pendingSecondPath,
        );
      }
      _pendingSecondUrl = StoreEntryBuiltinImages.url('feather');
      _pendingSecondPath = '';
    }
  }

  void _applyTemplate(String id) => _edit(() {
    _entryLayout = id;
    _useDefaultPhotos();
    _overlay = id == ModernStoreEntryLayouts.photoBanner
        ? ModernStoreCardOverlays.standard
        : ModernStoreCardOverlays.none;
    _titleColor = id == ModernStoreEntryLayouts.photoBanner
        ? ModernStoreCardTextColors.light
        : ModernStoreCardTextColors.dark;
    _subtitleColor = _titleColor;
    _buttonColor = ModernStoreCardButtonColors.brand;
    _position = ModernStoreCardPositions.centerLeft;
  });

  Widget _quickTemplates(bool enabled) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      const Text(
        '商城入口快速模板',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        '套用排版與內建圖片，保留自訂文字及已上傳照片。下方可繼續更換圖片。',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 650
              ? 3
              : c.maxWidth >= 380
              ? 2
              : 1;
          final width = (c.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry
                  in ModernStoreEntryLayouts.quickTemplates.entries)
                SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    selected: _entryLayout == entry.key,
                    label: '套用${entry.value}模板',
                    child: InkWell(
                      key: ValueKey('store-quick-template-${entry.key}'),
                      onTap: enabled && !_uploading
                          ? () => _applyTemplate(entry.key)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _entryLayout == entry.key
                                ? (widget.theme ?? _theme).primaryColor
                                : const Color(0xFFE7E0D8),
                            width: _entryLayout == entry.key ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 95,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/template_previews/store_entry_${entry.key}.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (_entryLayout == entry.key)
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color:
                                        (widget.theme ?? _theme).primaryColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _option(
    String value,
    String group,
    String label,
    bool enabled,
    ValueChanged<String> onChanged,
  ) {
    final bool selected = value == group;
    return InkWell(
      onTap: enabled ? () => onChanged(value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected
                  ? const Color(0xFF8A5A44)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  Widget _fold(String title, List<Widget> children) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      children: children,
    );
  }

  Widget _choices(
    String label,
    List<String> values,
    String selected,
    String Function(String value) labelOf,
    bool enabled,
    ValueChanged<String> onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((String value) {
              return ChoiceChip(
                label: Text(labelOf(value)),
                selected: selected == value,
                onSelected: enabled ? (_) => onSelected(value) : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
