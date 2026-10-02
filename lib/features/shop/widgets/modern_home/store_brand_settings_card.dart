import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_color_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/store_brand_style.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

class StoreBrandSettingsCard extends StatelessWidget {
  const StoreBrandSettingsCard({
    super.key,
    required this.style,
    required this.theme,
    required this.subtitleController,
    required this.logoSection,
    required this.hasLogo,
    required this.onChanged,
  });

  final StoreBrandStyle style;
  final HomeThemeModel theme;
  final TextEditingController subtitleController;
  final Widget logoSection;
  final bool hasLogo;
  final ValueChanged<StoreBrandStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _section(
          title: '店家內容',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              logoSection,
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '店名下方副標',
                  helperText: '留空並儲存後，新版首頁不顯示副標',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          title: '店家識別圖示',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _choice(
                    label: '使用店家 Logo',
                    selected: style.markType == 'logo',
                    onSelected: () => onChanged(style.copyWith(markType: 'logo')),
                  ),
                  _choice(
                    label: '使用內建小圖示',
                    selected: style.markType == 'builtinIcon',
                    onSelected: () =>
                        onChanged(style.copyWith(markType: 'builtinIcon')),
                  ),
                  _choice(
                    label: '不顯示圖示',
                    selected: style.markType == 'none',
                    onSelected: () => onChanged(style.copyWith(markType: 'none')),
                  ),
                ],
              ),
              if (style.markType == 'logo' && !hasLogo) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  '請先上傳店家 Logo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
              if (style.markType == 'builtinIcon') ...<Widget>[
                const SizedBox(height: 12),
                const Text('內建圖示', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final _BrandIcon icon in _BrandIcon.values)
                      ChoiceChip(
                        label: Text(icon.label),
                        avatar: Icon(icon.data, size: 16),
                        selected: style.fallbackIcon == icon.id,
                        onSelected: (bool selected) {
                          if (selected) {
                            onChanged(style.copyWith(fallbackIcon: icon.id));
                          }
                        },
                      ),
                  ],
                ),
              ],
              if (style.showsMark) ...<Widget>[
                const SizedBox(height: 12),
                const Text('圖示位置', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _choice(
                      label: '文字左側',
                      selected: style.logoPlacement == 'leading',
                      onSelected: () =>
                          onChanged(style.copyWith(logoPlacement: 'leading')),
                    ),
                    _choice(
                      label: '文字右側',
                      selected: style.logoPlacement == 'trailing',
                      onSelected: () =>
                          onChanged(style.copyWith(logoPlacement: 'trailing')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('圖示大小', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _choice(
                      label: '小',
                      selected: style.logoSize == 'small',
                      onSelected: () => onChanged(style.copyWith(logoSize: 'small')),
                    ),
                    _choice(
                      label: '中',
                      selected: style.logoSize == 'medium',
                      onSelected: () =>
                          onChanged(style.copyWith(logoSize: 'medium')),
                    ),
                    _choice(
                      label: '大',
                      selected: style.logoSize == 'large',
                      onSelected: () => onChanged(style.copyWith(logoSize: 'large')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          title: '文字樣式',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('文字對齊', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  _choice(
                    label: '靠左',
                    selected: style.textAlign == 'left',
                    onSelected: () => onChanged(style.copyWith(textAlign: 'left')),
                  ),
                  _choice(
                    label: '置中',
                    selected: style.textAlign == 'center',
                    onSelected: () => onChanged(style.copyWith(textAlign: 'center')),
                  ),
                  _choice(
                    label: '靠右',
                    selected: style.textAlign == 'right',
                    onSelected: () => onChanged(style.copyWith(textAlign: 'right')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _colorRow(
                context: context,
                label: '店家名稱顏色',
                value: style.nameColor(theme.textColor),
                themeChoice: theme.primaryColor,
                onPick: (Color color) {
                  onChanged(style.copyWith(nameColorValue: color.toARGB32()));
                },
              ),
              const SizedBox(height: 12),
              _colorRow(
                context: context,
                label: '副標文字顏色',
                value: style.subtitleColor(theme.textColor),
                themeChoice: theme.primaryColor,
                onPick: (Color color) {
                  onChanged(
                    style.copyWith(subtitleColorValue: color.toARGB32()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _fontSlider(
                label: '店名字體大小',
                value: style.nameFontSize,
                min: StoreBrandStyle.minNameFont,
                max: StoreBrandStyle.maxNameFont,
                onChanged: (double value) {
                  onChanged(style.copyWith(nameFontSize: value));
                },
              ),
              _fontSlider(
                label: '副標字體大小',
                value: style.subtitleFontSize,
                min: StoreBrandStyle.minSubtitleFont,
                max: StoreBrandStyle.maxSubtitleFont,
                onChanged: (double value) {
                  onChanged(style.copyWith(subtitleFontSize: value));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('文字陰影'),
                subtitle: const Text('為店名與副標加上柔和陰影'),
                value: style.textShadowEnabled,
                onChanged: (bool value) {
                  onChanged(style.copyWith(textShadowEnabled: value));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          title: '水平位置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _choice(
                    label: '靠左',
                    selected: (style.x - 0).abs() < 0.015,
                    onSelected: () => onChanged(style.copyWith(x: 0)),
                  ),
                  _choice(
                    label: '置中',
                    selected: (style.x - 0.5).abs() < 0.015,
                    onSelected: () => onChanged(style.copyWith(x: 0.5)),
                  ),
                  _choice(
                    label: '靠右',
                    selected: (style.x - 1).abs() < 0.015,
                    onSelected: () => onChanged(style.copyWith(x: 1)),
                  ),
                  if (!StoreBrandStyle.isPresetX(style.x))
                    const ChoiceChip(
                      label: Text('自訂位置'),
                      selected: true,
                      onSelected: null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('水平位置 ${(style.x * 100).round()}%'),
              const SizedBox(height: 8),
              const Text(
                '也可以在左側預覽直接左右拖曳',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => onChanged(StoreBrandStyle.resetPlacement(style)),
                  child: const Text('重設位置'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choice({
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

  Widget _section({required String title, required Widget child}) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _fontSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('$label ${value.round()} px'),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _colorRow({
    required BuildContext context,
    required String label,
    required Color value,
    required Color themeChoice,
    required ValueChanged<Color> onPick,
  }) {
    final List<HomeColorSwatch> swatches = <HomeColorSwatch>[
      const HomeColorSwatch('深棕', 0xFF3A2A20),
      const HomeColorSwatch('黑色', 0xFF111111),
      const HomeColorSwatch('深灰', 0xFF4B5563),
      const HomeColorSwatch('白色', 0xFFFFFFFF),
      HomeColorSwatch('主題色', themeChoice.toARGB32()),
      const HomeColorSwatch('橘色', 0xFFFF8A00),
      const HomeColorSwatch('暖黃色', 0xFFE6A23C),
      const HomeColorSwatch('粉紅色', 0xFFE06B84),
      const HomeColorSwatch('紫色', 0xFF7C5CBF),
      const HomeColorSwatch('藍色', 0xFF3B82C4),
      const HomeColorSwatch('綠色', 0xFF4F7D61),
      const HomeColorSwatch('紅色', 0xFFD64545),
    ];
    final int current = value.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 0,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final HomeColorSwatch swatch in swatches)
              HomeColorSwatchButton(
                swatch: swatch,
                selected: _sameColor(current, swatch.argb),
                onTap: () => onPick(Color(swatch.argb)),
              ),
            OutlinedButton(
              onPressed: () async {
                final int? next = await showHomeColorPicker(
                  context,
                  initial: value,
                );
                if (next == null) {
                  return;
                }
                onPick(Color(next));
              },
              child: const Text('自訂顏色'),
            ),
          ],
        ),
      ],
    );
  }

  bool _sameColor(int a, int b) => (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF);
}

class _BrandIcon {
  const _BrandIcon(this.id, this.label, this.data);

  final String id;
  final String label;
  final IconData data;

  static const List<_BrandIcon> values = <_BrandIcon>[
    _BrandIcon('paw', '腳印', Icons.pets_rounded),
    _BrandIcon('heart', '愛心', Icons.favorite_rounded),
    _BrandIcon('star', '星星', Icons.star_rounded),
    _BrandIcon('home', '房屋', Icons.home_rounded),
    _BrandIcon('crown', '皇冠', Icons.workspace_premium_rounded),
  ];
}
