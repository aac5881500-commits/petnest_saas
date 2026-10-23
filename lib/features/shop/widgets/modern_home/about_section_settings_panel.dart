import 'home_card_image.dart';
import 'home_section_settings_group.dart';
import 'home_section_layout_option_card.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/about_section_layout_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_bridge.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_display_style_editor.dart';

/// 關於我們右側設定。只改草稿，不直接寫入 Firestore。
class AboutSectionSettingsPanel extends StatefulWidget {
  const AboutSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.imageChoices,
    required this.onChanged,
    this.onManage,
    this.shop = const {},
    this.environmentIntro = const {},
    this.displayStyles,
    this.onDisplayStyles,
  });

  final VoidCallback? onManage;
  final Map<String, dynamic> shop, environmentIntro;
  final HomeAboutSectionSetting setting;
  final HomeThemeModel theme;
  final List<Map<String, String>> imageChoices;
  final ValueChanged<HomeAboutSectionSetting> onChanged;
  final HomeDisplayStyleSetting? displayStyles;
  final ValueChanged<HomeDisplayStyleSetting>? onDisplayStyles;

  @override
  State<AboutSectionSettingsPanel> createState() =>
      _AboutSectionSettingsPanelState();
}

class _AboutSectionSettingsPanelState extends State<AboutSectionSettingsPanel> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _buttonController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setting.title);
    _subtitleController = TextEditingController(text: widget.setting.subtitle);
    _buttonController = TextEditingController(text: widget.setting.buttonText);
  }

  @override
  void didUpdateWidget(AboutSectionSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_titleController, widget.setting.title);
    _sync(_subtitleController, widget.setting.subtitle);
    _sync(_buttonController, widget.setting.buttonText);
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _update(HomeAboutSectionSetting next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('about-section-settings'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: [
        HomeSectionSettingsGroup(
          title: '首頁顯示',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用關於我們首頁區塊'),
              subtitle: const Text('只控制獨立展示，不修改我們的服務入口。'),
              value: widget.setting.enabled,
              onChanged: (v) => _update(widget.setting.copyWith(enabled: v)),
            ),
          ],
        ),
        HomeSectionSettingsGroup(
          title: '展示版型',
          children: [
            HomeSectionLayoutPicker(
              theme: widget.theme,
              selectedId: HomeAboutLayouts.migrate(widget.setting.layout),
              onSelected: (value) =>
                  _update(widget.setting.copyWith(layout: value)),
              choices: [
                for (final item in HomeAboutLayouts.all)
                  HomeSectionLayoutChoice(
                    id: item,
                    title: HomeAboutLayouts.label(item),
                    description: switch (item) {
                      HomeAboutLayouts.imageEntry => '主照片與介紹並排或上下排列',
                      HomeAboutLayouts.brandIntro => '主照片、Logo 與品牌介紹分開呈現',
                      _ => '緊湊入口，可套用圖庫卡片背景',
                    },
                    badge: '',
                    preview: AboutSectionLayoutPreview(
                      layout: item,
                      theme: widget.theme,
                    ),
                  ),
              ],
            ),
          ],
        ),
        HomeSectionSettingsGroup(title: '目前版型設定', children: [_details()]),
      ],
    );
  }

  Widget _details() {
    final HomeAboutSectionSetting setting = widget.setting;
    final String layout = HomeAboutLayouts.migrate(setting.layout);
    final String cardSize = HomeAboutCardSizes.migrate(setting.cardSize);
    final bool simple = layout == HomeAboutLayouts.simpleEntry;
    final bool image = layout == HomeAboutLayouts.imageEntry;
    final bool brand = layout == HomeAboutLayouts.brandIntro;
    final bool longCard = simple && cardSize == HomeAboutCardSizes.wide;
    final bool wideCard = simple && cardSize == HomeAboutCardSizes.standard;
    final bool showArrow = image || wideCard || longCard;
    final bool showButton = image || brand || longCard;
    final bool showLogo = (simple && !setting.cardImage.usesLibrary) || brand;
    final bool showImage = image || brand;
    final bool hasImage =
        setting.imageSource == 'platformCard' || widget.imageChoices.isNotEmpty;
    final bool imageAdjustable = showImage && hasImage && setting.showImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (brand) ...<Widget>[
          const Text('標題來源', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _chips(
            values: const <String>['shop', 'custom'],
            labelOf: (String value) => value == 'shop' ? '使用店家名稱' : '使用自訂標題',
            selected: setting.useShopNameAsTitle ? 'shop' : 'custom',
            onChanged: (String value) {
              _update(setting.copyWith(useShopNameAsTitle: value == 'shop'));
            },
          ),
          const SizedBox(height: 12),
        ],
        if (!brand || !setting.useShopNameAsTitle)
          TextField(
            controller: _titleController,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '首頁標題',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(setting.copyWith(title: value.trim()));
            },
          ),
        _chips(
          values: const ['legacy', 'shop', 'custom'],
          labelOf: (v) => switch (v) {
            'shop' => '沿用店家簡介',
            'custom' => '自訂短文',
            _ => '既有短文設定',
          },
          selected: setting.summarySource,
          onChanged: (v) => _update(setting.copyWith(summarySource: v)),
        ),
        const SizedBox(height: 12),
        if (setting.summarySource != 'shop')
          TextField(
            controller: _subtitleController,
            maxLength: 80,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: brand ? '品牌摘要' : '首頁簡介',
              border: const OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(setting.copyWith(subtitle: value.trim()));
            },
          ),
        _switch('顯示副標題', setting.showSubtitle, (bool value) {
          _update(setting.copyWith(showSubtitle: value));
        }),
        if (simple)
          HomeCardImageSettings(
            setting: setting.cardImage,
            onChanged: (value) => _update(setting.copyWith(cardImage: value)),
          ),
        if (simple) ...<Widget>[
          const Text('卡片尺寸', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _chips(
            values: HomeAboutCardSizes.all,
            labelOf: HomeAboutCardSizes.label,
            selected: cardSize,
            onChanged: (String value) {
              _update(setting.copyWith(cardSize: value));
            },
          ),
          const SizedBox(height: 8),
        ],
        if (image) ...<Widget>[
          const Text('圖文位置', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _chips(
            values: HomeAboutImagePositions.all,
            labelOf: HomeAboutImagePositions.label,
            selected: setting.imagePosition,
            onChanged: (String value) {
              _update(setting.copyWith(imagePosition: value));
            },
          ),
        ],
        if (showImage) ..._imageControls(adjustable: imageAdjustable),
        if (showLogo)
          _switch('顯示 Logo', setting.showLogo, (bool value) {
            _update(setting.copyWith(showLogo: value));
          }, subtitle: '關閉時使用內建愛心圖示'),
        if (showArrow)
          _switch('顯示箭頭', setting.showArrow, (bool value) {
            _update(setting.copyWith(showArrow: value));
          }),
        if (showButton)
          _switch('顯示按鈕', setting.showButton, (bool value) {
            _update(setting.copyWith(showButton: value));
          }),
        if (showButton && setting.showButton)
          TextField(
            controller: _buttonController,
            maxLength: 12,
            decoration: const InputDecoration(
              labelText: '按鈕文字',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _update(setting.copyWith(buttonText: value.trim()));
            },
          ),
        HomeSectionSettingsGroup(
          title: '進階外觀',
          storageId: 'about-section-advanced-appearance',
          children: [
            if (widget.onDisplayStyles != null) _styleEditor(),
            if (widget.onDisplayStyles == null) ...<Widget>[
              const Text('文字對齊', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _chips(
                values: HomeAboutTextAligns.all,
                labelOf: HomeAboutTextAligns.label,
                selected: setting.textAlign,
                onChanged: (String value) {
                  _update(setting.copyWith(textAlign: value));
                },
              ),
              const SizedBox(height: 12),
              const Text('卡片外觀', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _chips(
                values: HomeAboutSurfaces.all,
                labelOf: HomeAboutSurfaces.label,
                selected: setting.surfaceStyle,
                onChanged: (String value) {
                  _update(setting.copyWith(surfaceStyle: value));
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<Widget> _imageControls({required bool adjustable}) {
    return <Widget>[
      _switch('顯示圖片', widget.setting.showImage, (bool value) {
        _update(widget.setting.copyWith(showImage: value));
      }),
      if (widget.setting.showImage) ...[
        _chips(
          values: [
            if (widget.setting.imageSource == 'legacy') 'legacy',
            'aboutCover',
            'galleryFirst',
            'platformCard',
          ],
          labelOf: (v) => switch (v) {
            'aboutCover' => '關於我們封面',
            'galleryFirst' => '環境相簿第一張',
            'platformCard' => '圖庫卡片圖片',
            _ => '既有選圖設定',
          },
          selected: widget.setting.imageSource,
          onChanged: (v) => _update(widget.setting.copyWith(imageSource: v)),
        ),
        if (widget.setting.imageSource == 'legacy' &&
            widget.imageChoices.isNotEmpty)
          _chips(
            values: [
              '',
              ...widget.imageChoices.map((item) => item['url']!).toSet(),
            ],
            labelOf: (url) => url.isEmpty
                ? '既有自動選圖'
                : widget.imageChoices.firstWhere(
                        (item) => item['url'] == url,
                      )['label'] ??
                      '既有照片',
            selected: widget.setting.imageUrl,
            onChanged: (url) => _update(widget.setting.copyWith(imageUrl: url)),
          ),
        HomeCardImageSettings(
          setting: widget.setting.cardImage.copyWith(
            source: widget.setting.imageSource == 'platformCard'
                ? 'platformCard'
                : 'icon',
          ),
          showSource: false,
          sourceLabel: switch (widget.setting.imageSource) {
            'aboutCover' => '關於我們封面',
            'galleryFirst' => '環境相簿第一張',
            _ => '既有選圖設定',
          },
          fallbackUrl: HomeAboutSectionSetting.resolveImageUrl(
            setting: widget.setting,
            shop: widget.shop,
            environmentIntro: widget.environmentIntro,
          ),
          onManage: widget.onManage,
          onChanged: (value) => _update(
            widget.setting.copyWith(
              cardImage: value.copyWith(
                source: widget.setting.cardImage.source,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      const Text('圖片填滿', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _chips(
        values: HomeAboutImageFits.all,
        labelOf: (String value) =>
            value == HomeAboutImageFits.contain ? '完整顯示' : '填滿裁切',
        selected: widget.setting.imageFit,
        enabled: adjustable,
        onChanged: (String value) {
          _update(widget.setting.copyWith(imageFit: value));
        },
      ),
      const SizedBox(height: 12),
      const Text('圖片裁切', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _chips(
        values: HomeAboutImageAligns.all,
        labelOf: HomeAboutImageAligns.label,
        selected: widget.setting.imageAlign,
        enabled: adjustable,
        onChanged: (String value) {
          _update(widget.setting.copyWith(imageAlign: value));
        },
      ),
    ];
  }

  Widget _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _styleEditor() {
    final HomeDisplayStyleSetting display =
        widget.displayStyles ?? HomeDisplayStyleSetting.unset;
    final HomeDisplayStyle legacy = aboutDisplayLegacy(widget.setting);
    final String mode = display.effectiveMode(
      sectionId: HomeDisplaySections.about,
      legacy: legacy,
      baseline: HomeDisplayStyle.classic,
    );
    final HomeDisplayStyle effective = display.resolve(
      sectionId: HomeDisplaySections.about,
      legacy: legacy,
      baseline: HomeDisplayStyle.classic,
    );
    return HomeDisplaySectionOverride(
      basicAppearanceOnly: true,
      label: '關於我們',
      shared: display.style,
      mode: mode,
      effective: effective,
      onInherit: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.about,
            mode: HomeDisplayStyleModes.inherit,
            clearOverride: true,
          ),
        );
      },
      onCustom: () {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.about,
            mode: HomeDisplayStyleModes.custom,
          ),
        );
      },
      onEdit: (HomeDisplayStyle edited) {
        widget.onDisplayStyles?.call(
          display.updateSection(
            HomeDisplaySections.about,
            mode: HomeDisplayStyleModes.custom,
            override: edited.diff(display.style),
          ),
        );
      },
    );
  }

  Widget _chips({
    required List<String> values,
    required String Function(String value) labelOf,
    required String selected,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: selected == value,
            onSelected: enabled ? (_) => onChanged(value) : null,
          ),
      ],
    );
  }
}
