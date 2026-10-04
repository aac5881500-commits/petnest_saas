import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/about_section_layout_preview.dart';

/// 關於我們右側設定。只改草稿，不直接寫入 Firestore。
class AboutSectionSettingsPanel extends StatefulWidget {
  const AboutSectionSettingsPanel({
    super.key,
    required this.setting,
    required this.theme,
    required this.imageChoices,
    required this.onChanged,
  });

  final HomeAboutSectionSetting setting;
  final HomeThemeModel theme;
  final List<Map<String, String>> imageChoices;
  final ValueChanged<HomeAboutSectionSetting> onChanged;

  @override
  State<AboutSectionSettingsPanel> createState() =>
      _AboutSectionSettingsPanelState();
}

class _AboutSectionSettingsPanelState extends State<AboutSectionSettingsPanel> {
  int _pane = 0;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(
                value: 0,
                label: Text('版型'),
                icon: Icon(Icons.dashboard_customize_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('顯示細節'),
                icon: Icon(Icons.tune),
              ),
            ],
            selected: <int>{_pane},
            onSelectionChanged: (Set<int> value) {
              setState(() => _pane = value.first);
            },
          ),
        ),
        Expanded(child: _pane == 1 ? _details() : _layouts()),
      ],
    );
  }

  Widget _layouts() {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        for (final String layout in HomeAboutLayouts.all) _choice(layout),
      ],
    );
  }

  Widget _choice(String layout) {
    final bool selected = widget.setting.layout == layout;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('about-layout-$layout'),
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (selected) {
              return;
            }
            _update(widget.setting.copyWith(layout: layout));
          },
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? widget.theme.primaryColor
                    : const Color(0xFFE6E8EC),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AboutSectionLayoutPreview(layout: layout, theme: widget.theme),
                const SizedBox(height: 8),
                Text(
                  HomeAboutLayouts.label(layout),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final bool showLogo = simple || brand;
    final bool showImage = image || brand;
    final bool hasImage = widget.imageChoices.isNotEmpty;
    final bool imageAdjustable = showImage && hasImage && setting.showImage;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('啟用關於我們首頁區塊'),
          value: setting.enabled,
          onChanged: (bool value) {
            _update(setting.copyWith(enabled: value));
          },
        ),
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
    );
  }

  List<Widget> _imageControls({required bool adjustable}) {
    return <Widget>[
      _switch('顯示圖片', widget.setting.showImage, (bool value) {
        _update(widget.setting.copyWith(showImage: value));
      }),
      if (widget.imageChoices.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '目前沒有可用圖片，將使用內建圖示',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        )
      else ...<Widget>[
        const Text('圖片來源', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          '只套用店裡已有的圖片網址，不會另外上傳一份。',
          style: TextStyle(fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 8),
        _chips(
          values: <String>[
            '',
            ...widget.imageChoices.map(
              (Map<String, String> item) => item['url']!,
            ),
          ],
          labelOf: (String value) {
            if (value.isEmpty) {
              return '自動';
            }
            for (final Map<String, String> item in widget.imageChoices) {
              if (item['url'] == value) {
                return item['label'] ?? '圖片';
              }
            }
            return '已指定';
          },
          selected: widget.setting.imageUrl,
          onChanged: (String value) {
            _update(widget.setting.copyWith(imageUrl: value));
          },
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
