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
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreFrontHomeSettingsSection> createState() =>
      StoreFrontHomeSettingsSectionState();
}

class StoreFrontHomeSettingsSectionState
    extends State<StoreFrontHomeSettingsSection> {
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

  bool _loaded = false;
  bool _saving = false;
  late final Future<void> _loading;
  bool _uploading = false;
  bool _showFeatured = true;
  bool _showBanner = true;
  bool _removeImage = false;
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
  HomeThemeModel _theme = HomeThemeModel.modernDefault;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  void dispose() {
    _discardPending();
    _featuredTitle.dispose();
    _bannerTitle.dispose();
    _bannerSubtitle.dispose();
    _bannerButton.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
    _pendingUrl = '';
    _pendingPath = '';
    _removeImage = false;
  }

  ModernStoreHomeSetting get _draft {
    final String imageUrl = _removeImage
        ? ''
        : (_pendingUrl.isNotEmpty ? _pendingUrl : _committedUrl);
    final String imagePath = _removeImage
        ? ''
        : (_pendingPath.isNotEmpty ? _pendingPath : _committedPath);
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
              'homeAppearance.modern.${entry.key}': entry.value,
          });
      if (_removeImage || _pendingPath.isNotEmpty) {
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

  Future<void> _pickImage() async {
    try {
      setState(() => _uploading = true);
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
      if (result == null || !mounted) {
        return;
      }
      await _discardPending();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingUrl = result.imageUrl;
        _pendingPath = result.imageStoragePath;
        _removeImage = false;
        if (_overlay == ModernStoreCardOverlays.none) {
          _overlay = ModernStoreCardOverlays.standard;
        }
        if (_titleColor == ModernStoreCardTextColors.dark) {
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
        setState(() => _uploading = false);
      }
    }
  }

  void _markRemoveImage() {
    final String pendingUrl = _pendingUrl;
    final String pendingPath = _pendingPath;
    setState(() {
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
        const SizedBox(height: 28),
        const Text(
          '旅館首頁商城展示',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('控制旅館首頁要不要介紹商城，以及用哪一種方式呈現。不會關閉商城本身。'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示商城內容'),
          subtitle: const Text('關閉後，商城仍可使用，只是不在旅館首頁顯示商城區塊。'),
          value: _showFeatured || _showBanner,
          onChanged: enabled
              ? (bool value) => setState(() {
                  _showFeatured = value;
                  _showBanner = value;
                })
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('首頁顯示精選商品'),
          value: _showFeatured,
          onChanged: enabled
              ? (bool value) => setState(() => _showFeatured = value)
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
          (String value) => setState(() => _featuredLayout = value),
        ),
        _option(
          ModernFeaturedProductLayouts.featured,
          _featuredLayout,
          '精選大卡',
          enabled,
          (String value) => setState(() => _featuredLayout = value),
        ),
        _option(
          ModernFeaturedProductLayouts.grid,
          _featuredLayout,
          '雙欄商品',
          enabled,
          (String value) => setState(() => _featuredLayout = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('顯示商城入口'),
          value: _showBanner,
          onChanged: enabled
              ? (bool value) => setState(() => _showBanner = value)
              : null,
        ),
        const Text('商城入口樣式', style: TextStyle(fontWeight: FontWeight.w700)),
        _option(
          ModernStoreEntryLayouts.banner,
          _entryLayout,
          '橫幅',
          enabled,
          (String value) => setState(() => _entryLayout = value),
        ),
        _option(
          ModernStoreEntryLayouts.brand,
          _entryLayout,
          '品牌卡',
          enabled,
          (String value) => setState(() => _entryLayout = value),
        ),
        _option(
          ModernStoreEntryLayouts.showcase,
          _entryLayout,
          '商品櫥窗',
          enabled,
          (String value) => setState(() => _entryLayout = value),
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
            theme: _theme,
            setting: _draft,
            height: _entryLayout == ModernStoreEntryLayouts.brand ? 210 : 176,
            previewChrome: true,
          ),
        ),
        TextField(
          controller: _bannerTitle,
          enabled: enabled && _showBanner,
          maxLength: 12,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '卡片標題',
            helperText: '預設：寵物賣場',
          ),
        ),
        TextField(
          controller: _bannerSubtitle,
          enabled: enabled && _showBanner,
          maxLength: 24,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '副標',
            helperText: '預設：精選毛孩好物，把喜歡帶回家',
          ),
        ),
        TextField(
          controller: _bannerButton,
          enabled: enabled && _showBanner,
          maxLength: 10,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '按鈕文字',
            helperText: '預設：逛逛賣場',
          ),
        ),
        _fold('背景', <Widget>[
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
            (String value) => setState(() => _fit = value),
          ),
          _choices(
            '圖片焦點',
            ModernStoreCardAlignments.all,
            _alignment,
            ModernStoreCardAlignments.label,
            enabled && _showBanner,
            (String value) => setState(() => _alignment = value),
          ),
          _choices(
            '背景遮罩',
            ModernStoreCardOverlays.all,
            _overlay,
            ModernStoreCardOverlays.label,
            enabled && _showBanner,
            (String value) => setState(() => _overlay = value),
          ),
          if (_overlay != ModernStoreCardOverlays.none)
            _choices(
              '遮罩顏色',
              ModernStoreCardOverlayTones.all,
              _overlayTone,
              ModernStoreCardOverlayTones.label,
              enabled && _showBanner,
              (String value) => setState(() => _overlayTone = value),
            ),
        ]),
        _fold('文字', <Widget>[
          _choices(
            '主要文字顏色',
            ModernStoreCardTextColors.all,
            _titleColor,
            ModernStoreCardTextColors.label,
            enabled && _showBanner,
            (String value) => setState(() => _titleColor = value),
          ),
          _choices(
            '次要文字顏色',
            ModernStoreCardTextColors.all,
            _subtitleColor,
            ModernStoreCardTextColors.label,
            enabled && _showBanner,
            (String value) => setState(() => _subtitleColor = value),
          ),
        ]),
        _fold('按鈕', <Widget>[
          _choices(
            '按鈕顏色',
            ModernStoreCardButtonColors.all,
            _buttonColor,
            ModernStoreCardButtonColors.label,
            enabled && _showBanner,
            (String value) => setState(() => _buttonColor = value),
          ),
        ]),
        _fold('位置', <Widget>[
          _choices(
            '文字位置',
            ModernStoreCardPositions.all,
            _position,
            ModernStoreCardPositions.label,
            enabled && _showBanner,
            (String value) => setState(() => _position = value),
          ),
        ]),
      ],
    );
  }

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
