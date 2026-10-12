import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.shopName = '',
    required this.subtitleController,
    required this.logoSection,
    required this.hasLogo,
    required this.onChanged,
  });

  final StoreBrandStyle style;
  final HomeThemeModel theme;
  final String shopName;
  final TextEditingController subtitleController;
  final Widget logoSection;
  final bool hasLogo;
  final ValueChanged<StoreBrandStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '店家品牌設定',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            '顯示在首頁最上方。位置可在左側預覽直接拖曳。',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          _subhead('品牌基本資料'),
          _identityBody(),
          _subhead('Logo 顯示方式'),
          _logoBody(),
          _subhead('店名與副標樣式'),
          _textBody(context),
        ],
      ),
    );
  }

  Widget _subhead(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EC)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _identityBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        logoSection,
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: '店名',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: Text(
            _shopNameLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: style.appliedNameFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: subtitleController,
          maxLength: StoreBrandTextPolicy.subtitleMaxCharacters,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(
              StoreBrandTextPolicy.subtitleMaxCharacters,
            ),
          ],
          decoration: const InputDecoration(
            labelText: '店名下方副標',
            helperText: '留空則不顯示。最多 24 字。',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _logoBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Logo 顯示', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _toggle(
              label: '使用店家 Logo',
              selected: style.markType == 'logo',
              onSelected: () => onChanged(style.copyWith(markType: 'logo')),
            ),
            _toggle(
              label: '使用內建小圖示',
              selected: style.markType == 'builtinIcon',
              onSelected: () =>
                  onChanged(style.copyWith(markType: 'builtinIcon')),
            ),
            _toggle(
              label: '不顯示',
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
          const SizedBox(height: 10),
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
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide = constraints.maxWidth >= 520;
              final Widget placement = _optionGroup(
                label: 'Logo 位置',
                children: <Widget>[
                  _toggle(
                    label: '店名左側',
                    selected: style.logoPlacement == 'leading',
                    onSelected: () =>
                        onChanged(style.copyWith(logoPlacement: 'leading')),
                  ),
                  _toggle(
                    label: '店名右側',
                    selected: style.logoPlacement == 'trailing',
                    onSelected: () =>
                        onChanged(style.copyWith(logoPlacement: 'trailing')),
                  ),
                ],
              );
              final Widget size = _optionGroup(
                label: 'Logo 大小',
                children: <Widget>[
                  _toggle(
                    label: '小',
                    selected: style.logoSize == 'small',
                    onSelected: () =>
                        onChanged(style.copyWith(logoSize: 'small')),
                  ),
                  _toggle(
                    label: '中',
                    selected: style.logoSize == 'medium',
                    onSelected: () =>
                        onChanged(style.copyWith(logoSize: 'medium')),
                  ),
                  _toggle(
                    label: '大',
                    selected: style.logoSize == 'large',
                    onSelected: () =>
                        onChanged(style.copyWith(logoSize: 'large')),
                  ),
                ],
              );
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    placement,
                    const SizedBox(height: 10),
                    size,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: placement),
                  const SizedBox(width: 16),
                  Expanded(child: size),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _textBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('字體', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _nameFontDropdown(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget nameSize = _fontSlider(
              label: '店名',
              value: style.nameFontSize,
              min: StoreBrandStyle.minNameFont,
              max: StoreBrandStyle.maxNameFont,
              onChanged: (double value) {
                onChanged(style.copyWith(nameFontSize: value));
              },
            );
            final Widget subtitleSize = _fontSlider(
              label: '副標',
              value: style.subtitleFontSize,
              min: StoreBrandStyle.minSubtitleFont,
              max: StoreBrandStyle.maxSubtitleFont,
              onChanged: (double value) {
                onChanged(style.copyWith(subtitleFontSize: value));
              },
            );
            if (constraints.maxWidth < 520) {
              return Column(
                children: <Widget>[
                  nameSize,
                  const SizedBox(height: 4),
                  subtitleSize,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: nameSize),
                const SizedBox(width: 16),
                Expanded(child: subtitleSize),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        const Text('文字對齊', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _toggle(
              label: '靠左',
              selected: style.textAlign == 'left',
              onSelected: () => onChanged(style.copyWith(textAlign: 'left')),
            ),
            _toggle(
              label: '置中',
              selected: style.textAlign == 'center',
              onSelected: () => onChanged(style.copyWith(textAlign: 'center')),
            ),
            _toggle(
              label: '靠右',
              selected: style.textAlign == 'right',
              onSelected: () => onChanged(style.copyWith(textAlign: 'right')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('文字陰影', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text(
                    '讓文字在背景上更清楚。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Switch(
              value: style.textShadowEnabled,
              onChanged: (bool value) {
                onChanged(style.copyWith(textShadowEnabled: value));
              },
            ),
          ],
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget nameColor = _BrandColorField(
              label: '店名顏色',
              value: style.nameColor(theme.textColor),
              themeChoice: theme.primaryColor,
              onPick: (Color color) {
                onChanged(style.copyWith(nameColorValue: color.toARGB32()));
              },
            );
            final Widget subtitleColor = _BrandColorField(
              label: '副標顏色',
              value: style.subtitleColor(theme.textColor),
              themeChoice: theme.primaryColor,
              onPick: (Color color) {
                onChanged(style.copyWith(subtitleColorValue: color.toARGB32()));
              },
            );
            if (constraints.maxWidth < 520) {
              return Column(
                children: <Widget>[
                  nameColor,
                  const SizedBox(height: 8),
                  subtitleColor,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: nameColor),
                const SizedBox(width: 12),
                Expanded(child: subtitleColor),
              ],
            );
          },
        ),
      ],
    );
  }

  String get _shopNameLabel {
    final String name = shopName.trim();
    return name.isEmpty ? '店家' : name;
  }

  String get _selectedNameFont {
    if (StoreBrandStyle.nameFontFamilies.contains(style.nameFontFamily)) {
      return style.nameFontFamily;
    }
    return StoreBrandStyle.defaultNameFontFamily;
  }

  Widget _nameFontDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedNameFont,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: <DropdownMenuItem<String>>[
        for (final _NameFontOption option in _NameFontOption.values)
          DropdownMenuItem<String>(
            value: option.family,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (String? value) {
        if (value == null || value == style.nameFontFamily) {
          return;
        }
        onChanged(style.copyWith(nameFontFamily: value));
      },
    );
  }

  Widget _optionGroup({required String label, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _toggle({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final Color accent = theme.primaryColor;
    return Material(
      color: selected ? accent.withValues(alpha: 0.1) : const Color(0xFFF8F9FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? accent : const Color(0xFFE6E8EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : const Color(0xFF334155),
            ),
          ),
        ),
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
    final int pixels = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              '$pixels px',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: '$pixels',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BrandColorField extends StatefulWidget {
  const _BrandColorField({
    required this.label,
    required this.value,
    required this.themeChoice,
    required this.onPick,
  });

  final String label;
  final Color value;
  final Color themeChoice;
  final ValueChanged<Color> onPick;

  @override
  State<_BrandColorField> createState() => _BrandColorFieldState();
}

class _BrandColorFieldState extends State<_BrandColorField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final int current = widget.value.toARGB32();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.value,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _open ? '收合' : '選擇',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...<Widget>[
          const SizedBox(height: 4),
          Wrap(
            spacing: 0,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final HomeColorSwatch swatch in _swatches)
                HomeColorSwatchButton(
                  swatch: swatch,
                  selected: _sameColor(current, swatch.argb),
                  onTap: () => widget.onPick(Color(swatch.argb)),
                ),
              OutlinedButton(
                onPressed: () async {
                  final int? next = await showHomeColorPicker(
                    context,
                    initial: widget.value,
                  );
                  if (next == null) {
                    return;
                  }
                  widget.onPick(Color(next));
                },
                child: const Text('自訂顏色'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<HomeColorSwatch> get _swatches {
    return <HomeColorSwatch>[
      const HomeColorSwatch('深棕', 0xFF3A2A20),
      const HomeColorSwatch('黑色', 0xFF111111),
      const HomeColorSwatch('深灰', 0xFF4B5563),
      const HomeColorSwatch('白色', 0xFFFFFFFF),
      HomeColorSwatch('主題色', widget.themeChoice.toARGB32()),
      const HomeColorSwatch('橘色', 0xFFFF8A00),
      const HomeColorSwatch('暖黃色', 0xFFE6A23C),
      const HomeColorSwatch('粉紅色', 0xFFE06B84),
      const HomeColorSwatch('紫色', 0xFF7C5CBF),
      const HomeColorSwatch('藍色', 0xFF3B82C4),
      const HomeColorSwatch('綠色', 0xFF4F7D61),
      const HomeColorSwatch('紅色', 0xFFD64545),
    ];
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

class _NameFontOption {
  const _NameFontOption(this.family, this.label);

  final String family;
  final String label;

  static const List<_NameFontOption> values = <_NameFontOption>[
    _NameFontOption(StoreBrandStyle.defaultNameFontFamily, '系統預設'),
    _NameFontOption('jfOpenHuninn', 'jf open 粉圓'),
    _NameFontOption('NotoSansTC', 'Noto Sans TC 現代黑體'),
    _NameFontOption('NotoSerifTC', 'Noto Serif TC 傳統宋體'),
    _NameFontOption('KleeOne', 'Klee One 日系手寫'),
    _NameFontOption('ChironSungHK', '昭源宋體 Chiron Sung HK'),
  ];
}
