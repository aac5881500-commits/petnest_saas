// 檔案名稱：lib/features/shop/widgets/modern_home/home_banner_display_settings.dart
// 功能說明：首頁活動海報的顯示模式、區域標題與活動滑動設定。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

class HomeBannerDisplaySettings extends StatefulWidget {
  const HomeBannerDisplaySettings({
    super.key,
    required this.frame,
    required this.bannerCount,
    required this.onChanged,
    required this.onManage,
  });

  final ModernBannerFrameSetting frame;
  final int bannerCount;
  final ValueChanged<ModernBannerFrameSetting> onChanged;
  final VoidCallback onManage;

  @override
  State<HomeBannerDisplaySettings> createState() =>
      _HomeBannerDisplaySettingsState();
}

class _HomeBannerDisplaySettingsState extends State<HomeBannerDisplaySettings> {
  late final TextEditingController _title = TextEditingController(
    text: widget.frame.sectionTitle,
  );
  bool _writingTitle = false;

  ModernBannerFrameSetting get frame => widget.frame;

  @override
  void didUpdateWidget(HomeBannerDisplaySettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_writingTitle && _title.text != widget.frame.sectionTitle) {
      _title.text = widget.frame.sectionTitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _set(ModernBannerFrameSetting next) {
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 680;
        final bool activity = frame.isActivity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _pair(wide, _titleCard(), _modeCard()),
            const SizedBox(height: 12),
            if (activity)
              _pair(wide, _motionCard(), _activityLookCard())
            else
              _classicSizeCard(),
            if (widget.bannerCount == 0) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                '尚未設定活動海報。請到活動海報管理新增圖片，兩種顯示模式會共用同一批海報。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: widget.onManage,
                icon: const Icon(Icons.collections_outlined),
                label: const Text('管理活動海報'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pair(bool wide, Widget first, Widget second) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[first, const SizedBox(height: 12), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  Widget _titleCard() {
    return _Fold(
      title: '區域標題',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile(
            key: const Key('banner-title-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('顯示區域標題'),
            value: frame.showSectionTitle,
            onChanged: (bool value) {
              _set(frame.copyWith(showSectionTitle: value));
            },
          ),
          TextField(
            key: const Key('banner-title-field'),
            controller: _title,
            decoration: const InputDecoration(
              labelText: '標題文字',
              hintText: '活動',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String value) {
              _writingTitle = true;
              _set(frame.copyWith(sectionTitle: value));
              _writingTitle = false;
            },
          ),
          if (frame.showSectionTitle) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'banner-title-font-${frame.sectionFontFamily}',
              ),
              initialValue: frame.appliedSectionFont ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '字體',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: '', child: Text('系統預設')),
                DropdownMenuItem<String>(
                  value: 'jfOpenHuninn',
                  child: Text('jf open 粉圓'),
                ),
                DropdownMenuItem<String>(
                  value: 'NotoSansTC',
                  child: Text('Noto Sans TC'),
                ),
                DropdownMenuItem<String>(
                  value: 'NotoSerifTC',
                  child: Text('Noto Serif TC'),
                ),
                DropdownMenuItem<String>(
                  value: 'KleeOne',
                  child: Text('Klee One'),
                ),
                DropdownMenuItem<String>(
                  value: 'ChironSungHK',
                  child: Text('昭源宋體'),
                ),
              ],
              onChanged: (String? value) {
                _set(frame.copyWith(sectionFontFamily: value ?? ''));
              },
            ),
            const SizedBox(height: 12),
            _choices(
              title: '字體大小',
              selected: frame.sectionTitleSize,
              options: const <(String, String)>[
                (ModernBannerFrameSetting.sizeSmall, '小'),
                (ModernBannerFrameSetting.sizeMedium, '中'),
                (ModernBannerFrameSetting.sizeLarge, '大'),
              ],
              onSelected: (String value) {
                _set(frame.copyWith(sectionTitleSize: value));
              },
            ),
            const SizedBox(height: 10),
            _choices(
              title: '字重',
              selected: frame.sectionTitleWeight,
              options: const <(String, String)>[
                (ModernBannerFrameSetting.weightRegular, '一般'),
                (ModernBannerFrameSetting.weightMedium, '中等'),
                (ModernBannerFrameSetting.weightBold, '粗體'),
              ],
              onSelected: (String value) {
                _set(frame.copyWith(sectionTitleWeight: value));
              },
            ),
            const SizedBox(height: 10),
            _choices(
              title: '對齊',
              selected: frame.sectionTitleAlign,
              options: const <(String, String)>[
                (ModernBannerFrameSetting.alignStart, '靠左'),
                (ModernBannerFrameSetting.alignCenter, '置中'),
                (ModernBannerFrameSetting.alignEnd, '靠右'),
              ],
              onSelected: (String value) {
                _set(frame.copyWith(sectionTitleAlign: value));
              },
            ),
            const SizedBox(height: 10),
            _choices(
              title: '標題與海報間距',
              selected: frame.sectionTitleGap,
              options: const <(String, String)>[
                (ModernBannerFrameSetting.gapCompact, '緊湊'),
                (ModernBannerFrameSetting.gapStandard, '標準'),
                (ModernBannerFrameSetting.gapRelaxed, '寬鬆'),
              ],
              onSelected: (String value) {
                _set(frame.copyWith(sectionTitleGap: value));
              },
            ),
            const SizedBox(height: 10),
            _colorRow(
              title: '文字顏色',
              themeLabel: '跟隨主題',
              mode: frame.sectionTitleColorMode,
              color: frame.sectionTitleColor,
              onMode: (String value) {
                _set(frame.copyWith(sectionTitleColorMode: value));
              },
              onPick: () => _pickColor(
                frame.sectionTitleColor,
                (int color) => frame.copyWith(
                  sectionTitleColorMode: ModernBannerFrameSetting.colorCustom,
                  sectionTitleColor: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeCard() {
    return _Fold(
      title: '海報顯示模式',
      child: Column(
        children: <Widget>[
          _modeOption(
            key: const Key('banner-mode-classic'),
            title: '經典完整海報',
            caption: '一次顯示一張完整海報，適合形象封面。',
            selected: !frame.isActivity,
            diagram: const _PosterDiagram(peek: false),
            onTap: () {
              _set(
                frame.copyWith(
                  displayMode: ModernBannerFrameSetting.modeClassic,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _modeOption(
            key: const Key('banner-mode-activity'),
            title: '活動滑動海報',
            caption: '主卡縮小，右側露出下一張，左右滑動查看。',
            selected: frame.isActivity,
            diagram: const _PosterDiagram(peek: true),
            onTap: () {
              _set(
                frame.copyWith(
                  displayMode: ModernBannerFrameSetting.modeActivity,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _motionCard() {
    return _Fold(
      title: '活動滑動設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '手動橫向滑動。整排海報一起移動，右側會露出下一張，不會自動切換。',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            key: const Key('banner-dots-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('圓點指示器'),
            value: frame.showDots,
            onChanged: (bool value) => _set(frame.copyWith(showDots: value)),
          ),
          if (frame.showDots)
            _colorRow(
              title: '圓點顏色',
              mode: frame.dotColorMode,
              color: frame.dotColor,
              onMode: (String value) {
                _set(frame.copyWith(dotColorMode: value));
              },
              onPick: () => _pickColor(
                frame.dotColor,
                (int color) => frame.copyWith(
                  dotColorMode: ModernBannerFrameSetting.colorCustom,
                  dotColor: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityLookCard() {
    final String? preset = frame.matchedActivityLayout;
    return _Fold(
      title: '尺寸與外觀',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 520;
          final List<Widget> metrics = <Widget>[
            _metric(
              label: '海報寬度',
              value: frame.activityCardFraction,
              min: 0.65,
              max: 0.95,
              valueLabel: '${(frame.activityCardFraction * 100).round()}%',
              resetValue: ModernBannerFrameSetting.activityWidthDefault,
              onChanged: (double value) {
                _set(frame.copyWith(activityWidth: value));
              },
            ),
            _metric(
              label: '海報高度',
              value: frame.activityHeightRatio,
              min: 0.40,
              max: 0.80,
              valueLabel: '${(frame.activityHeightRatio * 100).round()}%',
              resetValue: ModernBannerFrameSetting.activityHeightDefault,
              onChanged: (double value) {
                _set(frame.copyWith(activityHeightFactor: value));
              },
            ),
            _metric(
              label: '海報間距',
              value: frame.activityGapPx,
              min: 4,
              max: 24,
              valueLabel: '${frame.activityGapPx.round()} px',
              resetValue: ModernBannerFrameSetting.activityGapDefault,
              onChanged: (double value) {
                _set(frame.copyWith(activitySpacing: value));
              },
            ),
            _metric(
              label: '左右留白',
              value: frame.activityInsetPx,
              min: 0,
              max: 24,
              valueLabel: '${frame.activityInsetPx.round()} px',
              resetValue: ModernBannerFrameSetting.activityInsetDefault,
              onChanged: (double value) {
                _set(frame.copyWith(activityInset: value));
              },
            ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('快速版型', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    key: const Key('banner-layout-narrow'),
                    label: const Text('精緻窄版'),
                    selected: preset == 'narrow',
                    onSelected: (_) =>
                        _set(frame.applyActivityLayout('narrow')),
                  ),
                  ChoiceChip(
                    key: const Key('banner-layout-standard'),
                    label: const Text('標準活動'),
                    selected: preset == 'standard',
                    onSelected: (_) =>
                        _set(frame.applyActivityLayout('standard')),
                  ),
                  ChoiceChip(
                    key: const Key('banner-layout-wide'),
                    label: const Text('寬版展示'),
                    selected: preset == 'wide',
                    onSelected: (_) => _set(frame.applyActivityLayout('wide')),
                  ),
                  if (preset == null)
                    const Chip(
                      label: Text('自訂'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _choices(
                title: '高度快速選項',
                selected: _heightChoice(frame.activityHeightRatio),
                options: const <(String, String)>[
                  ('short', '矮版'),
                  ('standard', '標準'),
                  ('tall', '高版'),
                ],
                onSelected: (String value) {
                  _set(
                    frame.copyWith(
                      activityHeightFactor: switch (value) {
                        'short' => ModernBannerFrameSetting.activityHeightShort,
                        'tall' => ModernBannerFrameSetting.activityHeightTall,
                        _ => ModernBannerFrameSetting.activityHeightDefault,
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: metrics[0]),
                    const SizedBox(width: 12),
                    Expanded(child: metrics[1]),
                  ],
                )
              else ...<Widget>[metrics[0], metrics[1]],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: metrics[2]),
                    const SizedBox(width: 12),
                    Expanded(child: metrics[3]),
                  ],
                )
              else ...<Widget>[metrics[2], metrics[3]],
              _choices(
                title: '海報圓角',
                selected: frame.activityRadius,
                options: const <(String, String)>[
                  (ModernBannerFrameSetting.radiusSmall, '小圓角'),
                  (ModernBannerFrameSetting.radiusStandard, '標準圓角'),
                  (ModernBannerFrameSetting.radiusLarge, '大圓角'),
                ],
                onSelected: (String value) {
                  _set(frame.copyWith(activityRadius: value));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _heightChoice(double value) {
    if ((value - ModernBannerFrameSetting.activityHeightShort).abs() <= 0.011) {
      return 'short';
    }
    if ((value - ModernBannerFrameSetting.activityHeightTall).abs() <= 0.011) {
      return 'tall';
    }
    if ((value - ModernBannerFrameSetting.activityHeightDefault).abs() <=
        0.011) {
      return 'standard';
    }
    return '';
  }

  Widget _metric({
    required String label,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required double resetValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(valueLabel, style: const TextStyle(fontSize: 12)),
            IconButton(
              tooltip: '還原預設',
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(resetValue),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _classicSizeCard() {
    return _Fold(
      title: '尺寸與外觀',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '經典模式一次顯示完整海報。寬度與高度沿用原本設定。',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          _choices(
            title: '海報寬度',
            selected: frame.widthPreset.name,
            options: const <(String, String)>[
              ('narrow', '窄版'),
              ('standard', '標準'),
              ('full', '滿寬'),
            ],
            onSelected: (String value) {
              _set(
                frame.copyWith(
                  widthPreset: switch (value) {
                    'narrow' => HomeBannerWidthPreset.narrow,
                    'full' => HomeBannerWidthPreset.full,
                    _ => HomeBannerWidthPreset.standard,
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _choices(
            title: '海報高度',
            selected: frame.heightPreset.name,
            options: const <(String, String)>[
              ('short', '矮版'),
              ('standard', '標準'),
              ('tall', '高版'),
            ],
            onSelected: (String value) {
              _set(
                frame.copyWith(
                  heightPreset: switch (value) {
                    'short' => HomeBannerHeightPreset.short,
                    'tall' => HomeBannerHeightPreset.tall,
                    _ => HomeBannerHeightPreset.standard,
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            '標準高度完整顯示 16:9 海報；矮版或高版會填滿版面，可能裁切圖片邊緣。',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _choices({
    required String title,
    required String selected,
    required List<(String, String)> options,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (String value, String label) in options)
              ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (bool on) {
                  if (on) {
                    onSelected(value);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _colorRow({
    required String title,
    required String mode,
    String themeLabel = '店家主色',
    required int color,
    required ValueChanged<String> onMode,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ChoiceChip(
              label: Text(themeLabel),
              selected: mode != ModernBannerFrameSetting.colorCustom,
              onSelected: (bool on) {
                if (on) {
                  onMode(ModernBannerFrameSetting.colorTheme);
                }
              },
            ),
            ChoiceChip(
              label: const Text('自訂顏色'),
              selected: mode == ModernBannerFrameSetting.colorCustom,
              onSelected: (bool on) {
                if (on) {
                  onMode(ModernBannerFrameSetting.colorCustom);
                }
              },
            ),
            if (mode == ModernBannerFrameSetting.colorCustom)
              InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE6E8EC)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickColor(
    int current,
    ModernBannerFrameSetting Function(int color) next,
  ) async {
    final int? picked = await showHomeColorPicker(
      context,
      initial: Color(current),
    );
    if (picked == null || !mounted) {
      return;
    }
    _set(next(picked));
  }

  Widget _modeOption({
    required Key key,
    required String title,
    required String caption,
    required bool selected,
    required Widget diagram,
    required VoidCallback onTap,
  }) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : const Color(0xFFF8F6F3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE6E8EC),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              diagram,
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterDiagram extends StatelessWidget {
  const _PosterDiagram({required this.peek});

  final bool peek;

  @override
  Widget build(BuildContext context) {
    const Color fill = Color(0xFFE7D3C4);
    const Color edge = Color(0xFFC4A48E);
    return SizedBox(
      height: 42,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: peek ? 5 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: edge),
              ),
            ),
          ),
          if (peek) ...<Widget>[
            const SizedBox(width: 6),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E7DE),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  border: Border.all(color: edge),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fold extends StatefulWidget {
  const _Fold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
            ),
            if (_open) widget.child,
          ],
        ),
      ),
    );
  }
}
