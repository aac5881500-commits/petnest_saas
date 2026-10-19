// 檔案名稱：lib/features/shop/widgets/modern_home/home_appearance_preset_strip.dart
// 功能說明：外觀設定頁的快速模板列。套用前先確認，只更新本頁草稿。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class HomeAppearancePresetStrip extends StatefulWidget {
  const HomeAppearancePresetStrip({
    super.key,
    required this.draft,
    required this.presetId,
    required this.accent,
    required this.onPreview,
    required this.onApply,
    required this.onRestore,
    this.previewingId,
    this.showHeading = true,
  });

  final HomeAppearanceDraft draft;
  final String? presetId;
  final String? previewingId;
  final Color accent;
  final ValueChanged<HomeAppearancePreset> onPreview;
  final ValueChanged<HomeAppearancePreset> onApply;
  final VoidCallback onRestore;
  final bool showHeading;

  @override
  State<HomeAppearancePresetStrip> createState() =>
      _HomeAppearancePresetStripState();
}

class _HomeAppearancePresetStripState extends State<HomeAppearancePresetStrip> {
  @override
  Widget build(BuildContext context) {
    final String status = homeAppearancePresetStatus(
      presetId: widget.presetId,
      draft: widget.draft,
    );
    final String? selectedId = widget.previewingId ?? widget.presetId;
    final HomeAppearancePreset? previewingPreset = homeAppearancePresetById(
      widget.previewingId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.showHeading) ...<Widget>[
          const Text(
            '快速套用前台風格',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3A2A20),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '先選一個喜歡的版型，再依照品牌自由調整。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                previewingPreset == null
                    ? '目前：$status'
                    : '正在預覽：${previewingPreset.name}',
                key: const Key('home-preset-current-style'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ),
            if (previewingPreset != null)
              TextButton.icon(
                key: const Key('home-preset-restore-draft'),
                onPressed: widget.onRestore,
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('返回原外觀'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 560 ? 2 : 1;
            final double width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final HomeAppearancePreset preset in homeAppearancePresets)
                  SizedBox(
                    width: width,
                    height: 300,
                    child: _PresetCard(
                      preset: preset,
                      draft: widget.draft,
                      accent: widget.accent,
                      selected: preset.id == selectedId,
                      applied: preset.id == widget.presetId,
                      previewing: preset.id == widget.previewingId,
                      onPreview: () => widget.onPreview(preset),
                      onApply: () => _confirm(context, preset),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    HomeAppearancePreset preset,
  ) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('套用「${preset.name}」？'),
          content: const Text(
            '將調整首頁排版、區塊樣式、色彩與導覽方式。\n店家 Logo、海報、房型、照片、商城圖片與實際內容不會被更換。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('套用模板'),
            ),
          ],
        );
      },
    );
    if (accepted == true) {
      widget.onApply(preset);
    }
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.draft,
    required this.accent,
    required this.selected,
    required this.applied,
    required this.previewing,
    required this.onPreview,
    required this.onApply,
  });

  final HomeAppearancePreset preset;
  final HomeAppearanceDraft draft;
  final Color accent;
  final bool selected;
  final bool applied;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        key: Key('home-preset-${preset.id}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : const Color(0xFFE7E0D8),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A3A2A20),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 164,
                  child: _MiniHome(
                    presetId: preset.id,
                    appearance: preset.apply(draft),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3A2A20),
                        ),
                      ),
                    ),
                    if (applied)
                      Icon(Icons.check_circle, color: accent, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preset.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F1EB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        preset.navigationLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B5344),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      previewing
                          ? '正在預覽'
                          : applied
                          ? '目前已套用'
                          : '點擊預覽',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: previewing ? accent : const Color(0xFF8A7568),
                      ),
                    ),
                    TextButton(
                      key: Key('home-preset-apply-${preset.id}'),
                      onPressed: onApply,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('套用此風格'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniHome extends StatelessWidget {
  const _MiniHome({required this.presetId, required this.appearance});

  final String presetId;
  final HomeAppearanceDraft appearance;

  @override
  Widget build(BuildContext context) {
    final _SitePalette palette = _SitePalette.fromDraft(appearance, presetId);
    final bool drawer = presetId == 'minimal' || presetId == 'brand';
    final bool floating = presetId == 'booking';
    final bool bottom = presetId == 'classic' || presetId == 'warm' || floating;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          children: <Widget>[
            if (drawer) _SideRail(color: palette.rail),
            Expanded(
              child: Column(
                children: <Widget>[
                  _SiteHeader(palette: palette, showMenu: !drawer),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                      child: _siteBody(palette),
                    ),
                  ),
                  if (bottom) _SiteFooter(palette: palette, floating: floating),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _siteBody(_SitePalette palette) {
    return switch (presetId) {
      'minimal' => Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: _Photo(
              palette.hero,
              imageAsset: palette.heroImage,
              label: '',
            ),
          ),
          const SizedBox(height: 3),
          _Bar(color: palette.ink, label: '住宿預約', light: true),
          const SizedBox(height: 3),
          Expanded(
            flex: 4,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(child: _Tile(palette.mist, '環境')),
                      const SizedBox(width: 3),
                      Expanded(child: _Tile(palette.sand, '房間')),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(child: _Tile(palette.sand, '須知')),
                      const SizedBox(width: 3),
                      Expanded(child: _Tile(palette.mist, '關於')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      'brand' => Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _Photo(
              palette.hero,
              imageAsset: palette.heroImage,
              label: '',
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 5,
            child: _Photo(
              palette.room,
              imageAsset: palette.roomImage,
              label: '豪華房',
              caption: true,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 22,
            child: Row(
              children: <Widget>[
                Expanded(child: _Tile(palette.mist, '安靜套房')),
                const SizedBox(width: 3),
                Expanded(
                  flex: 2,
                  child: _Photo(
                    palette.sand,
                    imageAsset: palette.roomImage,
                    label: '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      'booking' => Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _Photo(
              palette.hero,
              imageAsset: palette.heroImage,
              label: '',
            ),
          ),
          const SizedBox(height: 3),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '今天想安排？',
              style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Expanded(child: _Tile(palette.stay, '住宿', light: true)),
                const SizedBox(width: 3),
                Expanded(child: _Tile(palette.care, '安親', light: true)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _Bar(color: palette.sand, label: '熱門房型'),
        ],
      ),
      'warm' => Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _Photo(
              palette.hero,
              imageAsset: palette.heroImage,
              label: '',
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Expanded(flex: 2, child: _Tile(palette.mist, '歡迎來到')),
                const SizedBox(width: 3),
                Expanded(
                  flex: 3,
                  child: _Photo(
                    palette.room,
                    imageAsset: palette.roomImage,
                    label: '環境',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Expanded(flex: 2, child: _Tile(palette.sand, '房型')),
                const SizedBox(width: 3),
                Expanded(
                  flex: 3,
                  child: _Photo(
                    palette.hero,
                    imageAsset: palette.heroImage,
                    label: '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: _Photo(
              palette.hero,
              imageAsset: palette.heroImage,
              label: '',
            ),
          ),
          const SizedBox(height: 3),
          _Bar(color: palette.ink, label: '快速預約', light: true),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: _Tile(palette.room, '房')),
                const SizedBox(width: 3),
                Expanded(child: _Tile(palette.sand, '訊')),
                const SizedBox(width: 3),
                Expanded(child: _Tile(palette.mist, '評')),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _Bar(color: palette.mist, label: '須知  FAQ  關於'),
        ],
      ),
    };
  }
}

class _SitePalette {
  const _SitePalette({
    required this.paper,
    required this.ink,
    required this.hero,
    required this.room,
    required this.sand,
    required this.mist,
    required this.line,
    required this.rail,
    required this.stay,
    required this.care,
    required this.heroImage,
    required this.roomImage,
  });

  final Color paper;
  final Color ink;
  final Color hero;
  final Color room;
  final Color sand;
  final Color mist;
  final Color line;
  final Color rail;
  final Color stay;
  final Color care;
  final String heroImage;
  final String roomImage;

  static _SitePalette fromDraft(HomeAppearanceDraft draft, String presetId) {
    final HomeThemeModel theme = draft.theme;
    final Color paper = theme.backgroundColor;
    final Color accent = theme.primaryColor;
    final Color card = theme.cardColor;
    final String imageRoot = switch (presetId) {
      'brand' => 'assets/images/shop_house/modern_japanese',
      'warm' => 'assets/images/shop_house/romantic_garden',
      _ => 'assets/images/shop_house/warm_wood',
    };
    final String heroImage = switch (presetId) {
      'brand' => '$imageRoot/modern_japanese_courtyard.jpg',
      'warm' => '$imageRoot/romantic_garden_courtyard.jpg',
      _ => '$imageRoot/courtyard_daylight.jpg',
    };
    final String roomImage = switch (presetId) {
      'brand' => '$imageRoot/modern_japanese_cat_default.jpg',
      'warm' => '$imageRoot/romantic_garden_cat_default.jpg',
      _ => '$imageRoot/cat_default.png',
    };
    return _SitePalette(
      paper: paper,
      ink: theme.textColor,
      hero: Color.alphaBlend(accent.withValues(alpha: 0.16), card),
      room: Color.alphaBlend(accent.withValues(alpha: 0.1), card),
      sand: theme.cardBorderColor,
      mist: card,
      line: theme.cardBorderColor,
      rail: draft.brandStyle.resolveHeaderBackground(paper),
      stay: theme.buttonBackgroundColor,
      care: accent,
      heroImage: heroImage,
      roomImage: roomImage,
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.palette, required this.showMenu});

  final _SitePalette palette;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: palette.paper,
      child: Row(
        children: <Widget>[
          if (showMenu) Container(width: 8, height: 1.5, color: palette.ink),
          if (showMenu) const SizedBox(width: 4),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: palette.room,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 3,
                width: 36,
                decoration: BoxDecoration(
                  color: palette.ink.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < 4; index++) ...<Widget>[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFB7A89A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter({required this.palette, required this.floating});

  final _SitePalette palette;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: floating ? 14 : 12,
      margin: floating
          ? const EdgeInsets.fromLTRB(8, 0, 8, 4)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: floating ? palette.ink : palette.mist,
        borderRadius: BorderRadius.circular(floating ? 99 : 0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (int index = 0; index < 4; index++)
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: floating ? Colors.white : palette.sand,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(
    this.color, {
    required this.label,
    this.caption = false,
    this.imageAsset = '',
  });

  final Color color;
  final String label;
  final bool caption;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageAsset.isNotEmpty)
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: color),
              ),
            if (label.isNotEmpty)
              Align(
                alignment: caption ? Alignment.bottomLeft : Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: caption ? Colors.white : const Color(0xFF3A2A20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.color, this.label, {this.light = false});

  final Color color;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w800,
            color: light ? Colors.white : const Color(0xFF3A2A20),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.label, this.light = false});

  final Color color;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: light ? Colors.white : const Color(0xFF3A2A20),
        ),
      ),
    );
  }
}
