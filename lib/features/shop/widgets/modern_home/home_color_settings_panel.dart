import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

/// 首頁色彩分頁。顏色仍寫回同一份 [HomeThemeModel]，這裡不另存狀態。
class HomeColorSettingsPanel extends StatelessWidget {
  const HomeColorSettingsPanel({
    super.key,
    required this.theme,
    required this.entryTheme,
    required this.onChanged,
  });

  final HomeThemeModel theme;
  final HomeThemeModel entryTheme;
  final ValueChanged<HomeThemeModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final HomeColorPreset? preset = HomeColorPalette.matching(theme);
    final bool lowContrast = HomeColorContrast.pageNeedsAttention(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ColorSection(
          title: '主題快速套用',
          subtitle: '一次填入整組顏色，之後仍可逐項微調',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                preset == null ? '自訂配色' : '目前：${preset.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 560;
                  final double width = wide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      for (final HomeColorPreset item in HomeColorPalette.presets)
                        SizedBox(
                          width: width,
                          child: _PresetCard(
                            preset: item,
                            selected: preset?.id == item.id,
                            onTap: () => onChanged(item.apply(theme)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _ColorSection(
          title: '頁面與卡片',
          subtitle: '首頁底層、卡片與分隔線',
          child: _tileGrid(
            children: <Widget>[
              _ColorSettingTile(
                name: '頁面背景色',
                description: '新版首頁最底層的整體背景。',
                colorValue: theme.backgroundColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.backgroundColorValue,
                onChanged: (int value) => onChanged(
                  theme.copyWith(backgroundColorValue: value),
                ),
              ),
              _ColorSettingTile(
                name: '卡片背景色',
                description: '房型、服務、公告與評價等卡片底色。',
                colorValue: theme.cardColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.cardColorValue,
                onChanged: (int value) =>
                    onChanged(theme.copyWith(cardColorValue: value)),
              ),
              _ColorSettingTile(
                name: '卡片外框色',
                description: '卡片邊線與區塊分隔顏色。',
                colorValue: theme.cardBorderColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.cardBorderColorValue,
                onChanged: (int value) =>
                    onChanged(theme.copyWith(cardBorderColorValue: value)),
              ),
            ],
          ),
        ),
        _ColorSection(
          title: '品牌與互動',
          subtitle: '圖示、選取狀態與按鈕',
          child: _tileGrid(
            children: <Widget>[
              _ColorSettingTile(
                name: '主題重點色',
                description: '圖示、選中狀態、連結及重要互動元素。',
                colorValue: theme.primaryColorValue,
                swatches: HomeColorPalette.accents,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.primaryColorValue,
                onChanged: (int value) => onChanged(
                  theme.copyWith(primaryColorValue: _opaque(value)),
                ),
              ),
              _ButtonColorTile(theme: theme, onChanged: onChanged),
            ],
          ),
        ),
        _ColorSection(
          title: '文字顏色',
          subtitle: '標題、內文與說明',
          child: _tileGrid(
            children: <Widget>[
              _ColorSettingTile(
                name: '主要文字色',
                description: '標題及主要內容。',
                colorValue: theme.textColorValue,
                swatches: HomeColorPalette.inks,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.textColorValue,
                onChanged: (int value) => onChanged(
                  theme.copyWith(textColorValue: _opaque(value)),
                ),
              ),
              _ColorSettingTile(
                name: '次要文字色',
                description: '說明文字、提示及次要資訊。',
                colorValue: theme.secondaryTextColor.toARGB32(),
                swatches: HomeColorPalette.inks,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.textColor
                    .withValues(alpha: 0.65)
                    .toARGB32(),
                onChanged: (int value) => onChanged(
                  theme.copyWith(secondaryTextColorValue: _opaque(value)),
                ),
                onReset: () => onChanged(
                  theme.copyWith(secondaryTextColorValue: null),
                ),
              ),
            ],
          ),
        ),
        if (lowContrast)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0C48A)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '目前文字與背景對比較低，部分顧客可能較難閱讀。',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => onChanged(_autoFix(theme)),
                      child: const Text('自動修正文字顏色'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _ColorSection(
          title: '目前色彩',
          subtitle: '確認這組顏色在卡片與按鈕上的樣子',
          child: _SummaryCard(
            theme: theme,
            onRestoreEntry: () => _confirm(
              context,
              title: '恢復進入時的色彩',
              message: '會把首頁色彩還原成打開這個分頁時的顏色。',
              apply: () => onChanged(
                entryTheme.copyWith(drawerSetting: theme.drawerSetting),
              ),
            ),
            onRestoreDefault: () => _confirm(
              context,
              title: '恢復系統預設色彩',
              message: '會改回新版首頁的預設配色，不會改導覽或店家資訊。',
              apply: () => onChanged(
                HomeThemeModel.modernDefault.copyWith(
                  drawerSetting: theme.drawerSetting,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static int _opaque(int argb) => 0xFF000000 | (argb & 0x00FFFFFF);

  static HomeThemeModel _autoFix(HomeThemeModel theme) {
    final Color ink = HomeColorContrast.readableInk(theme.backgroundColor);
    final Color buttonInk = HomeColorContrast.readableInk(
      theme.buttonBackgroundColor,
    );
    return theme.copyWith(
      textColorValue: ink.toARGB32(),
      secondaryTextColorValue: ink.toARGB32(),
      buttonTextMode: buttonInk == const Color(0xFFFFFFFF) ? 'light' : 'dark',
    );
  }

  static Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback apply,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確定恢復'),
            ),
          ],
        );
      },
    );
    if (ok == true && context.mounted) {
      apply();
    }
  }
}

class _ColorSection extends StatelessWidget {
  const _ColorSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _tileGrid({required List<Widget> children}) {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool two = constraints.maxWidth >= 680;
      final double width = two
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          for (final Widget child in children)
            SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final HomeColorPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF6EE) : const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFB86B18)
                  : const Color(0xFFE6E8EC),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      preset.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFFB86B18),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preset.description,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (final int color in preset.preview) ...<Widget>[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x22000000)),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSettingTile extends StatelessWidget {
  const _ColorSettingTile({
    required this.name,
    required this.description,
    required this.colorValue,
    required this.swatches,
    required this.allowAlpha,
    required this.fallback,
    required this.onChanged,
    this.onReset,
  });

  final String name;
  final String description;
  final int colorValue;
  final List<HomeColorSwatch> swatches;
  final bool allowAlpha;
  final int fallback;
  final ValueChanged<int> onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(colorValue);
    final String hex = HomeColorPalette.hexOf(colorValue, forceAlpha: allowAlpha);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33000000)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        hex,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (final HomeColorSwatch swatch in swatches)
                  HomeColorSwatchButton(
                    swatch: swatch,
                    selected: (colorValue & 0x00FFFFFF) ==
                        (swatch.argb & 0x00FFFFFF),
                    onTap: () {
                      final double alpha = allowAlpha
                          ? HomeColorPalette.alphaOf(colorValue)
                          : 1;
                      onChanged(HomeColorPalette.withAlpha(swatch.argb, alpha));
                    },
                  ),
              ],
            ),
            if (allowAlpha) ...<Widget>[
              const SizedBox(height: 8),
              _AlphaControl(colorValue: colorValue, onChanged: onChanged),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final int? next = await showHomeColorPicker(
                      context,
                      initial: color,
                      allowAlpha: allowAlpha,
                    );
                    if (next != null && context.mounted) {
                      onChanged(next);
                    }
                  },
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('自訂顏色'),
                ),
                OutlinedButton.icon(
                  onPressed: onReset ?? () => onChanged(fallback),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('恢復預設'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlphaControl extends StatefulWidget {
  const _AlphaControl({required this.colorValue, required this.onChanged});

  final int colorValue;
  final ValueChanged<int> onChanged;

  @override
  State<_AlphaControl> createState() => _AlphaControlState();
}

class _AlphaControlState extends State<_AlphaControl> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    final double alpha = HomeColorPalette.alphaOf(widget.colorValue);
    final int percent = (alpha * 100).round();
    final String step = percent >= 90
        ? 'solid'
        : percent >= 45
        ? 'half'
        : 'clear';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'solid', label: Text('不透明')),
                  ButtonSegment<String>(value: 'half', label: Text('半透明')),
                  ButtonSegment<String>(value: 'clear', label: Text('透明')),
                ],
                selected: <String>{step},
                onSelectionChanged: (Set<String> value) {
                  final double next = switch (value.first) {
                    'half' => 0.6,
                    'clear' => 0.3,
                    _ => 1,
                  };
                  widget.onChanged(
                    HomeColorPalette.withAlpha(widget.colorValue, next),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '進階調整',
              onPressed: () => setState(() => _advanced = !_advanced),
              icon: Icon(
                _advanced ? Icons.tune : Icons.tune_outlined,
              ),
            ),
          ],
        ),
        if (_advanced)
          Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: alpha.clamp(0, 1),
                  onChanged: (double value) {
                    widget.onChanged(
                      HomeColorPalette.withAlpha(widget.colorValue, value),
                    );
                  },
                ),
              ),
              SizedBox(width: 42, child: Text('$percent%')),
            ],
          ),
        if (alpha < 0.35)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '透明度偏低，文字可能較難閱讀。',
              style: TextStyle(fontSize: 12, color: Color(0xFF9A5B12)),
            ),
          ),
      ],
    );
  }
}

class _ButtonColorTile extends StatelessWidget {
  const _ButtonColorTile({required this.theme, required this.onChanged});

  final HomeThemeModel theme;
  final ValueChanged<HomeThemeModel> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('按鈕背景跟隨主題重點色'),
              subtitle: const Text('關閉後可單獨選按鈕背景色'),
              value: theme.buttonFollowsPrimary,
              onChanged: (bool follow) {
                onChanged(
                  theme.copyWith(
                    buttonBackgroundColorValue: follow
                        ? null
                        : theme.primaryColorValue,
                  ),
                );
              },
            ),
            if (!theme.buttonFollowsPrimary)
              _ColorSettingTile(
                name: '按鈕背景色',
                description: '主要按鈕的底色。',
                colorValue: theme.buttonBackgroundColorValue!,
                swatches: HomeColorPalette.accents,
                allowAlpha: false,
                fallback: theme.primaryColorValue,
                onChanged: (int value) => onChanged(
                  theme.copyWith(
                    buttonBackgroundColorValue: 0xFF000000 | (value & 0xFFFFFF),
                  ),
                ),
                onReset: () => onChanged(
                  theme.copyWith(buttonBackgroundColorValue: null),
                ),
              ),
            const SizedBox(height: 8),
            const Text('按鈕文字色', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              '可自動對比，或改成淺色、深色、自訂。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'auto', label: Text('自動')),
                ButtonSegment<String>(value: 'light', label: Text('淺色')),
                ButtonSegment<String>(value: 'dark', label: Text('深色')),
                ButtonSegment<String>(value: 'custom', label: Text('自訂')),
              ],
              selected: <String>{
                switch (theme.buttonTextMode) {
                  'light' || 'dark' || 'custom' => theme.buttonTextMode,
                  _ => 'auto',
                },
              },
              onSelectionChanged: (Set<String> value) {
                onChanged(theme.copyWith(buttonTextMode: value.first));
              },
            ),
            if (theme.buttonTextMode == 'custom') ...<Widget>[
              const SizedBox(height: 8),
              _ColorSettingTile(
                name: '自訂按鈕文字',
                description: '只在選擇自訂時使用。',
                colorValue: theme.buttonTextColorValue ?? 0xFFFFFFFF,
                swatches: HomeColorPalette.inks,
                allowAlpha: false,
                fallback: 0xFFFFFFFF,
                onChanged: (int value) => onChanged(
                  theme.copyWith(
                    buttonTextMode: 'custom',
                    buttonTextColorValue: 0xFF000000 | (value & 0xFFFFFF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeColorSwatchButton extends StatelessWidget {
  const HomeColorSwatchButton({
    super.key,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final HomeColorSwatch swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(swatch.argb);
    final bool light = color.computeLuminance() > 0.85;
    return Tooltip(
      message: '${swatch.name} ${swatch.hex}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: selected ? 30 : 26,
              height: selected ? 30 : 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFB86B18)
                      : light
                      ? const Color(0xFFCBD5E1)
                      : const Color(0x22000000),
                  width: selected ? 2.4 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: color.computeLuminance() > 0.55
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.theme,
    required this.onRestoreEntry,
    required this.onRestoreDefault,
  });

  final HomeThemeModel theme;
  final VoidCallback onRestoreEntry;
  final VoidCallback onRestoreDefault;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.cardBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '店家標題',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '說明文字與提示',
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(Icons.pets, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.buttonBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          '主要按鈕',
                          style: TextStyle(
                            color: theme.buttonForegroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            _hexLine('背景', theme.backgroundColorValue),
            _hexLine('卡片', theme.cardColorValue),
            _hexLine('外框', theme.cardBorderColorValue),
            _hexLine('重點色', theme.primaryColorValue),
            _hexLine('主文字', theme.textColorValue),
            _hexLine('次文字', theme.secondaryTextColor.toARGB32()),
            _hexLine('按鈕', theme.buttonBackgroundColor.toARGB32()),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: onRestoreEntry,
              child: const Text('恢復進入時的色彩'),
            ),
            OutlinedButton(
              onPressed: onRestoreDefault,
              child: const Text('恢復系統預設色彩'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hexLine(String label, int argb) {
    return Text(
      '$label ${HomeColorPalette.hexOf(argb)}',
      style: const TextStyle(fontSize: 12),
    );
  }
}
