// 檔案名稱：lib/features/shop/widgets/modern_home/home_appearance_preset_strip.dart
// 功能說明：外觀設定頁的快速模板列。套用前先確認，只更新本頁草稿。

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';

class HomeAppearancePresetStrip extends StatefulWidget {
  const HomeAppearancePresetStrip({
    super.key,
    required this.draft,
    required this.presetId,
    required this.accent,
    required this.onPreview,
    required this.onApply,
    this.previewingId,
  });

  final HomeAppearanceDraft draft;
  final String? presetId;
  final String? previewingId;
  final Color accent;
  final ValueChanged<HomeAppearancePreset> onPreview;
  final ValueChanged<HomeAppearancePreset> onApply;

  @override
  State<HomeAppearancePresetStrip> createState() =>
      _HomeAppearancePresetStripState();
}

class _HomeAppearancePresetStripState extends State<HomeAppearancePresetStrip> {
  static const double _cardWidth = 240;
  static const double _cardGap = 12;
  final ScrollController _scroll = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncArrows);
    _scroll.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    final bool back = position.pixels > 1;
    final bool forward = position.pixels < position.maxScrollExtent - 1;
    if (back == _canBack && forward == _canForward) {
      return;
    }
    setState(() {
      _canBack = back;
      _canForward = forward;
    });
  }

  void _nudge(int direction) {
    if (!_scroll.hasClients) {
      return;
    }
    final double distance = (_cardWidth + _cardGap) * 1.5;
    final double max = _scroll.position.maxScrollExtent;
    final double target = (_scroll.offset + direction * distance).clamp(0, max);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) {
      return;
    }
    final bool shift =
        HardwareKeyboard.instance.isShiftPressed ||
        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs();
    if (!shift) {
      return;
    }
    final double delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent _,
    ) {
      final double max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo((_scroll.offset + delta).clamp(0, max));
    });
  }

  @override
  Widget build(BuildContext context) {
    final String status = homeAppearancePresetStatus(
      presetId: widget.presetId,
      draft: widget.draft,
    );
    final bool showArrows = MediaQuery.sizeOf(context).width >= 720;
    final String? selectedId = widget.previewingId ?? widget.presetId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Text(
                '快速套用前台風格',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3A2A20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '目前：$status',
                key: const Key('home-preset-current-style'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '先選一個喜歡的版型，再依照品牌自由調整。',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 318,
          child: Row(
            children: <Widget>[
              if (showArrows)
                _ArrowButton(
                  icon: Icons.chevron_left,
                  enabled: _canBack,
                  onPressed: () => _nudge(-1),
                ),
              Expanded(
                child: Listener(
                  onPointerSignal: _onPointerSignal,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: const <PointerDeviceKind>{
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView.separated(
                      key: const Key('home-preset-carousel'),
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(2, 4, 20, 8),
                      itemCount: homeAppearancePresets.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(width: _cardGap),
                      itemBuilder: (BuildContext context, int index) {
                        final HomeAppearancePreset preset =
                            homeAppearancePresets[index];
                        return _PresetCard(
                          preset: preset,
                          accent: widget.accent,
                          selected: preset.id == selectedId,
                          applied: preset.id == widget.presetId,
                          previewing: preset.id == widget.previewingId,
                          onPreview: () => widget.onPreview(preset),
                          onApply: () => _confirm(context, preset),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (showArrows)
                _ArrowButton(
                  icon: Icons.chevron_right,
                  enabled: _canForward,
                  onPressed: () => _nudge(1),
                ),
            ],
          ),
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
    required this.accent,
    required this.selected,
    required this.applied,
    required this.previewing,
    required this.onPreview,
    required this.onApply,
  });

  final HomeAppearancePreset preset;
  final Color accent;
  final bool selected;
  final bool applied;
  final bool previewing;
  final VoidCallback onPreview;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
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
                SizedBox(height: 164, child: _MiniHome(presetId: preset.id)),
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
                      previewing ? '正在預覽' : '預覽',
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
                      child: const Text('套用'),
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

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 20),
      color: const Color(0xFF6B5344),
      disabledColor: const Color(0xFFD7C4B0),
    );
  }
}

class _MiniHome extends StatelessWidget {
  const _MiniHome({required this.presetId});

  final String presetId;

  @override
  Widget build(BuildContext context) {
    final _SitePalette palette = _SitePalette.of(presetId);
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
          Expanded(flex: 5, child: _Photo(palette.hero, label: 'HERO')),
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
          Expanded(flex: 3, child: _Photo(palette.hero, label: '')),
          const SizedBox(height: 3),
          Expanded(
            flex: 5,
            child: _Photo(palette.room, label: '豪華房', caption: true),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 22,
            child: Row(
              children: <Widget>[
                Expanded(child: _Tile(palette.mist, '安靜套房')),
                const SizedBox(width: 3),
                Expanded(flex: 2, child: _Photo(palette.sand, label: '')),
              ],
            ),
          ),
        ],
      ),
      'booking' => Column(
        children: <Widget>[
          Expanded(flex: 3, child: _Photo(palette.hero, label: '')),
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
          Expanded(flex: 3, child: _Photo(palette.hero, label: '')),
          const SizedBox(height: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Expanded(flex: 2, child: _Tile(palette.mist, '歡迎來到')),
                const SizedBox(width: 3),
                Expanded(flex: 3, child: _Photo(palette.room, label: '環境')),
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
                Expanded(flex: 3, child: _Photo(palette.hero, label: '')),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: <Widget>[
          Expanded(flex: 4, child: _Photo(palette.hero, label: '')),
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

  static _SitePalette of(String id) {
    return switch (id) {
      'minimal' => const _SitePalette(
        paper: Color(0xFFF7F5F2),
        ink: Color(0xFF1F1A17),
        hero: Color(0xFFD9D3CC),
        room: Color(0xFFE7E1DA),
        sand: Color(0xFFE4DDD6),
        mist: Color(0xFFF3F0EC),
        line: Color(0xFFE4DDD6),
        rail: Color(0xFFECE7E1),
        stay: Color(0xFF1F1A17),
        care: Color(0xFF6E675F),
      ),
      'brand' => const _SitePalette(
        paper: Color(0xFFF3EEE8),
        ink: Color(0xFF2A241F),
        hero: Color(0xFF2E2926),
        room: Color(0xFF8D735B),
        sand: Color(0xFFCDB8A2),
        mist: Color(0xFFF7F1EA),
        line: Color(0xFFE4D8CC),
        rail: Color(0xFFE8DFD4),
        stay: Color(0xFF2E2926),
        care: Color(0xFF8D735B),
      ),
      'booking' => const _SitePalette(
        paper: Color(0xFFFFF8F4),
        ink: Color(0xFF3A2A20),
        hero: Color(0xFFE7D3C4),
        room: Color(0xFFD7BBA6),
        sand: Color(0xFFF0E2D6),
        mist: Color(0xFFFFF1E8),
        line: Color(0xFFF0D9CC),
        rail: Color(0xFFFFF1E8),
        stay: Color(0xFFC4654A),
        care: Color(0xFF3E6B58),
      ),
      'warm' => const _SitePalette(
        paper: Color(0xFFFBF3EA),
        ink: Color(0xFF5C4636),
        hero: Color(0xFFE2C2A4),
        room: Color(0xFFC9956C),
        sand: Color(0xFFF6E7D8),
        mist: Color(0xFFFFF6EE),
        line: Color(0xFFEBD9C8),
        rail: Color(0xFFF6E7D8),
        stay: Color(0xFF9A6B4F),
        care: Color(0xFFC9956C),
      ),
      _ => const _SitePalette(
        paper: Color(0xFFFFFBF7),
        ink: Color(0xFF8C5A3C),
        hero: Color(0xFFC4A484),
        room: Color(0xFFE7D5C4),
        sand: Color(0xFFF3E6D8),
        mist: Color(0xFFFFF6EE),
        line: Color(0xFFE7E0D8),
        rail: Color(0xFFF6F1EB),
        stay: Color(0xFF8C5A3C),
        care: Color(0xFFC4A484),
      ),
    };
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
  const _Photo(this.color, {required this.label, this.caption = false});

  final Color color;
  final String label;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: <Widget>[
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
