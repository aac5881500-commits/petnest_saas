import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/features/shop/theme/home_color_palette.dart';
import 'package:petnest_saas/features/shop/widgets/platform_media_asset_picker.dart';
import 'package:petnest_saas/features/shop/widgets/shop_app_backdrop.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_banner_color_field.dart';

/// 首頁色彩分頁。顏色仍寫回同一份 [HomeThemeModel]，這裡不另存狀態。
class HomeColorSettingsPanel extends StatefulWidget {
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
  State<HomeColorSettingsPanel> createState() => _HomeColorSettingsPanelState();
}

class _HomeColorSettingsPanelState extends State<HomeColorSettingsPanel> {
  String? _openEditor;
  bool _paletteExpanded = false;

  HomeThemeModel get theme => widget.theme;

  void _toggleEditor(String id) {
    setState(() => _openEditor = _openEditor == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final HomeColorPreset? preset = HomeColorPalette.matching(theme);
    final bool lowContrast = HomeColorContrast.pageNeedsAttention(theme);
    final String paletteName = preset?.name ?? '自訂配色';
    final bool imageBackground =
        theme.appBackgroundMode == ShopAppBackground.modeImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FoldGroup(
          title: '首頁色彩',
          subtitle: '配色：$paletteName',
          initiallyExpanded: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _QuickPaletteCard(
                expanded: _paletteExpanded,
                presetName: preset?.name,
                colors: preset == null
                    ? <int>[
                        theme.backgroundColorValue,
                        theme.cardColorValue,
                        theme.primaryColorValue,
                        theme.textColorValue,
                      ]
                    : preset.preview.take(4).toList(),
                onToggle: () =>
                    setState(() => _paletteExpanded = !_paletteExpanded),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columns = constraints.maxWidth >= 640 ? 2 : 1;
                    final double width =
                        (constraints.maxWidth - 12 * (columns - 1)) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        for (final HomeColorPreset item
                            in HomeColorPalette.presets)
                          SizedBox(
                            width: width,
                            child: _PresetCard(
                              preset: item,
                              selected: preset?.id == item.id,
                              onTap: () => widget.onChanged(item.apply(theme)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => _confirm(
                      context,
                      title: '恢復進入時的色彩',
                      message: '會把首頁色彩還原成打開這個分頁時的顏色。',
                      apply: () => widget.onChanged(
                        widget.entryTheme
                            .copyWith(drawerSetting: theme.drawerSetting)
                            .withBackdropFrom(theme),
                      ),
                    ),
                    child: const Text('恢復進入時的色彩'),
                  ),
                  OutlinedButton(
                    onPressed: () => _confirm(
                      context,
                      title: '恢復系統預設色彩',
                      message: '會改回新版首頁的預設配色，不會改導覽或店家資訊。',
                      apply: () => widget.onChanged(
                        HomeThemeModel.modernDefault
                            .copyWith(drawerSetting: theme.drawerSetting)
                            .withBackdropFrom(theme),
                      ),
                    ),
                    child: const Text('恢復系統預設色彩'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _FoldGroup(
          title: 'App 整體背景',
          subtitle: imageBackground ? '目前使用圖庫圖片' : '目前使用純色背景',
          child: _AppBackgroundEditor(
            theme: theme,
            onChanged: widget.onChanged,
          ),
        ),
        _FoldGroup(
          title: '卡片與外框',
          subtitle: '頁面背景、卡片底色與外框',
          child: Column(
            children: <Widget>[
              _ColorSettingTile(
                editorId: 'background',
                expanded: _openEditor == 'background',
                onToggle: () => _toggleEditor('background'),
                name: '頁面背景色',
                description: '純色背景，以及圖片留白時的底色。',
                colorValue: theme.backgroundColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.backgroundColorValue,
                onChanged: (int value) => widget.onChanged(
                  theme.copyWith(backgroundColorValue: value),
                ),
              ),
              _ColorSettingTile(
                editorId: 'card',
                expanded: _openEditor == 'card',
                onToggle: () => _toggleEditor('card'),
                name: '卡片背景色',
                description: '房型、服務、公告與評價等卡片底色。',
                colorValue: theme.cardColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.cardColorValue,
                onChanged: (int value) =>
                    widget.onChanged(theme.copyWith(cardColorValue: value)),
              ),
              _ColorSettingTile(
                editorId: 'border',
                expanded: _openEditor == 'border',
                onToggle: () => _toggleEditor('border'),
                name: '卡片外框色',
                description: '卡片邊線與區塊分隔顏色。',
                colorValue: theme.cardBorderColorValue,
                swatches: HomeColorPalette.surfaces,
                allowAlpha: true,
                fallback: HomeThemeModel.modernDefault.cardBorderColorValue,
                onChanged: (int value) => widget.onChanged(
                  theme.copyWith(cardBorderColorValue: value),
                ),
              ),
            ],
          ),
        ),
        _FoldGroup(
          title: '品牌與按鈕',
          subtitle: '主題重點色、按鈕背景與按鈕文字',
          child: Column(
            children: <Widget>[
              _ColorSettingTile(
                editorId: 'primary',
                expanded: _openEditor == 'primary',
                onToggle: () => _toggleEditor('primary'),
                name: '主題重點色',
                description: '圖示、選中狀態、連結及重要互動元素。',
                colorValue: theme.primaryColorValue,
                swatches: HomeColorPalette.accents,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.primaryColorValue,
                onChanged: (int value) => widget.onChanged(
                  theme.copyWith(primaryColorValue: _opaque(value)),
                ),
              ),
              _ButtonColorTile(
                theme: theme,
                openEditor: _openEditor,
                onToggle: _toggleEditor,
                onChanged: widget.onChanged,
              ),
            ],
          ),
        ),
        _FoldGroup(
          title: '文字顏色',
          subtitle: '標題、內文與說明',
          child: Column(
            children: <Widget>[
              _ColorSettingTile(
                editorId: 'text',
                expanded: _openEditor == 'text',
                onToggle: () => _toggleEditor('text'),
                name: '主要文字色',
                description: '標題及主要內容。',
                colorValue: theme.textColorValue,
                swatches: HomeColorPalette.inks,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.textColorValue,
                onChanged: (int value) => widget.onChanged(
                  theme.copyWith(textColorValue: _opaque(value)),
                ),
              ),
              _ColorSettingTile(
                editorId: 'secondary',
                expanded: _openEditor == 'secondary',
                onToggle: () => _toggleEditor('secondary'),
                name: '次要文字色',
                description: '說明文字、提示及次要資訊。',
                colorValue: theme.secondaryTextColor.toARGB32(),
                swatches: HomeColorPalette.inks,
                allowAlpha: false,
                fallback: HomeThemeModel.modernDefault.textColor
                    .withValues(alpha: 0.65)
                    .toARGB32(),
                onChanged: (int value) => widget.onChanged(
                  theme.copyWith(secondaryTextColorValue: _opaque(value)),
                ),
                onReset: () => widget.onChanged(
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
                      onPressed: () => widget.onChanged(_autoFix(theme)),
                      child: const Text('自動修正文字顏色'),
                    ),
                  ],
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

class _QuickPaletteCard extends StatelessWidget {
  const _QuickPaletteCard({
    required this.expanded,
    required this.presetName,
    required this.colors,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final String? presetName;
  final List<int> colors;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String current = presetName == null ? '自訂配色' : presetName!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E8EC)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                key: const ValueKey<String>('home-quick-palette-header'),
                onTap: onToggle,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '快速配色',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '目前套用：$current',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final int color in colors.take(4))
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x22000000)),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
              if (expanded) ...<Widget>[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text(
                    '選一組完整配色，之後仍可逐項微調。點選不會立刻儲存。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBackgroundEditor extends StatelessWidget {
  const _AppBackgroundEditor({required this.theme, required this.onChanged});

  final HomeThemeModel theme;
  final ValueChanged<HomeThemeModel> onChanged;

  bool get _image => theme.appBackgroundMode == ShopAppBackground.modeImage;

  Future<void> _pick(BuildContext context) async {
    final PlatformMediaAsset? asset = await showPlatformMediaAssetPicker(
      context: context,
      category: PlatformMediaCategories.dailyCarePage,
      selectedId: theme.appBackgroundAssetId,
      title: '選擇背景圖片',
    );
    if (asset == null ||
        !asset.enabled ||
        asset.category != PlatformMediaCategories.dailyCarePage) {
      return;
    }
    onChanged(
      theme.copyWith(
        appBackgroundMode: ShopAppBackground.modeImage,
        appBackgroundAssetId: asset.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '套用在這家店的顧客端頁面底層，不會改卡片或海報。',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _SourceCard(
                  label: '純色背景',
                  selected: !_image,
                  onTap: () => onChanged(
                    theme.copyWith(
                      appBackgroundMode: ShopAppBackground.modeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SourceCard(
                  label: '圖庫圖片',
                  selected: _image,
                  onTap: () => onChanged(
                    theme.copyWith(
                      appBackgroundMode: ShopAppBackground.modeImage,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_image) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: 96, child: ShopAppBackdrop(theme: theme)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    theme.appBackgroundAssetId.trim().isEmpty
                        ? '選擇背景圖片'
                        : '更換圖片',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onChanged(
                    theme.copyWith(
                      appBackgroundMode: ShopAppBackground.modeColor,
                    ),
                  ),
                  child: const Text('改回純色'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 560;
                final Widget fit = _ChoiceBlock(
                  title: '圖片顯示方式',
                  children: <Widget>[
                    _ChoiceChip(
                      label: '填滿裁切',
                      selected:
                          theme.appBackgroundFit == ShopAppBackground.fitCover,
                      onTap: () => onChanged(
                        theme.copyWith(
                          appBackgroundFit: ShopAppBackground.fitCover,
                        ),
                      ),
                    ),
                    _ChoiceChip(
                      label: '完整顯示',
                      selected:
                          theme.appBackgroundFit ==
                          ShopAppBackground.fitContain,
                      onTap: () => onChanged(
                        theme.copyWith(
                          appBackgroundFit: ShopAppBackground.fitContain,
                        ),
                      ),
                    ),
                  ],
                );
                final Widget align = _ChoiceBlock(
                  title: '圖片對齊',
                  children: <Widget>[
                    _ChoiceChip(
                      label: '靠上',
                      selected:
                          theme.appBackgroundAlign ==
                          ShopAppBackground.alignTop,
                      onTap: () => onChanged(
                        theme.copyWith(
                          appBackgroundAlign: ShopAppBackground.alignTop,
                        ),
                      ),
                    ),
                    _ChoiceChip(
                      label: '置中',
                      selected:
                          theme.appBackgroundAlign ==
                          ShopAppBackground.alignCenter,
                      onTap: () => onChanged(
                        theme.copyWith(
                          appBackgroundAlign: ShopAppBackground.alignCenter,
                        ),
                      ),
                    ),
                    _ChoiceChip(
                      label: '靠下',
                      selected:
                          theme.appBackgroundAlign ==
                          ShopAppBackground.alignBottom,
                      onTap: () => onChanged(
                        theme.copyWith(
                          appBackgroundAlign: ShopAppBackground.alignBottom,
                        ),
                      ),
                    ),
                  ],
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[fit, const SizedBox(height: 10), align],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: fit),
                    const SizedBox(width: 12),
                    Expanded(child: align),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            const Text('背景遮罩', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final ({String label, double opacity}) item
                    in ShopAppBackground.scrims)
                  _ChoiceChip(
                    label: item.label,
                    selected:
                        (theme.appBackgroundScrim - item.opacity).abs() < 0.011,
                    onTap: () => onChanged(
                      theme.copyWith(appBackgroundScrim: item.opacity),
                    ),
                  ),
              ],
            ),
            Slider(
              value: theme.appBackgroundScrim.clamp(0, 0.72),
              min: 0,
              max: 0.72,
              onChanged: (double value) =>
                  onChanged(theme.copyWith(appBackgroundScrim: value)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF6EE) : const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFB86B18)
                  : const Color(0xFFE6E8EC),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PresetPreview extends StatelessWidget {
  const _PresetPreview({required this.preset});

  final HomeColorPreset preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color(preset.background),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(preset.card),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(preset.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(width: 34, height: 4, color: Color(preset.text)),
              const SizedBox(height: 4),
              Container(width: 24, height: 3, color: Color(preset.secondary)),
              const Spacer(),
              Container(
                width: 22,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(preset.primary),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoldGroup extends StatefulWidget {
  const _FoldGroup({
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_FoldGroup> createState() => _FoldGroupState();
}

class _FoldGroupState extends State<_FoldGroup> {
  late bool _expanded = widget.initiallyExpanded;

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
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                widget.child,
              ],
            ],
          ),
        ),
      ),
    );
  }
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _PresetPreview(preset: preset),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
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
    required this.editorId,
    required this.expanded,
    required this.onToggle,
    required this.name,
    required this.description,
    required this.colorValue,
    required this.swatches,
    required this.allowAlpha,
    required this.fallback,
    required this.onChanged,
    this.onReset,
  });

  final String editorId;
  final bool expanded;
  final VoidCallback onToggle;
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
    final String hex = HomeColorPalette.hexOf(
      colorValue,
      forceAlpha: allowAlpha,
    );
    return Column(
      key: ValueKey<String>(editorId),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x33000000)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hex,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: onToggle,
              child: Text(expanded ? '收合' : '調整'),
            ),
          ],
        ),
        if (expanded) ...<Widget>[
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final HomeColorSwatch swatch in swatches)
                HomeColorSwatchButton(
                  swatch: swatch,
                  selected:
                      (colorValue & 0x00FFFFFF) == (swatch.argb & 0x00FFFFFF),
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
      ],
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
              icon: Icon(_advanced ? Icons.tune : Icons.tune_outlined),
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
  const _ButtonColorTile({
    required this.theme,
    required this.openEditor,
    required this.onToggle,
    required this.onChanged,
  });

  final HomeThemeModel theme;
  final String? openEditor;
  final ValueChanged<String> onToggle;
  final ValueChanged<HomeThemeModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final String mode = switch (theme.buttonTextMode) {
      'light' || 'dark' || 'custom' => theme.buttonTextMode,
      _ => 'auto',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            editorId: 'buttonBg',
            expanded: openEditor == 'buttonBg',
            onToggle: () => onToggle('buttonBg'),
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
            onReset: () =>
                onChanged(theme.copyWith(buttonBackgroundColorValue: null)),
          ),
        const SizedBox(height: 4),
        const Text('按鈕文字色', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          '可自動對比，或改成淺色、深色、自訂。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (String id, String label) in const <(String, String)>[
              ('auto', '自動'),
              ('light', '淺色'),
              ('dark', '深色'),
              ('custom', '自訂'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: mode == id,
                onSelected: (_) =>
                    onChanged(theme.copyWith(buttonTextMode: id)),
              ),
          ],
        ),
        if (theme.buttonTextMode == 'custom')
          _ColorSettingTile(
            editorId: 'buttonText',
            expanded: openEditor == 'buttonText',
            onToggle: () => onToggle('buttonText'),
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
