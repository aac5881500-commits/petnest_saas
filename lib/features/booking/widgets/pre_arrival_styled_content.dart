import 'package:petnest_saas/features/booking/models/pre_arrival_item_presentation.dart';
import 'package:petnest_saas/features/booking/widgets/pre_arrival_appearance_surface.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';

/// The same atlas cells used by the three reference designs, drawn without
/// baking text or customer checkboxes into an image.
class ArrivalIllustration extends StatefulWidget {
  const ArrivalIllustration({
    super.key,
    required this.style,
    required this.cell,
    this.size = 100,
  });
  final String style;
  final int cell;
  final double size;
  @override
  State<ArrivalIllustration> createState() => _ArrivalIllustrationState();
}

class _ArrivalIllustrationState extends State<ArrivalIllustration> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener((
    info,
    synchronous,
  ) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  }, onError: (Object error, StackTrace? stack) {});
  void _load() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    _info = null;
    _stream = AssetImage(
      'assets/images/pre_arrival_${widget.style}_atlas_v2.png',
    ).resolve(ImageConfiguration.empty);
    _stream!.addListener(_listener);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ArrivalIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) _load();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _AtlasPainter(_info?.image, widget.cell)),
    ),
  );
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter(this.image, this.cell);
  final ui.Image? image;
  final int cell;
  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final width = image!.width / 3, height = image!.height / 3;
    final source = Rect.fromLTWH(
      (cell % 3) * width,
      (cell ~/ 3) * height,
      width,
      height,
    );
    canvas.drawImageRect(
      image!,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _AtlasPainter old) =>
      old.image != image || old.cell != cell;
}

class _Section {
  _Section(this.title);
  final String title;
  final List<PreArrivalGuideBlock> blocks = [];
}

class PreArrivalStyledContent extends StatelessWidget {
  const PreArrivalStyledContent({
    super.key,
    required this.guide,
    required this.done,
    required this.total,
    required this.isChecked,
    required this.onToggle,
    required this.imageBuilder,
    required this.preview,
    this.palette,
    this.onContact,
    this.onBack,
    this.backLabel = '返回訂單',
  });
  final PreArrivalGuideModel guide;
  final PreArrivalPalette? palette;
  final int done, total;
  final bool Function(PreArrivalGuideBlock) isChecked;
  final void Function(PreArrivalGuideBlock, bool)? onToggle;
  final Widget Function(PreArrivalGuideBlock) imageBuilder;
  final bool preview;
  final VoidCallback? onContact, onBack;
  final String backLabel;
  bool get packing => guide.style == 'packing';
  bool get timeline => guide.style == 'timeline';
  bool get minimal => !packing && !timeline;
  Color get accent =>
      palette?.accent ??
      (packing
          ? const Color(0xFFC16A3C)
          : timeline
          ? const Color(0xFF8061B0)
          : const Color(0xFFAF7C73));
  Color get ink =>
      palette?.ink ??
      (packing
          ? const Color(0xFF59351F)
          : timeline
          ? const Color(0xFF25213F)
          : const Color(0xFF514033));
  Color get paper =>
      palette?.paper ??
      (packing
          ? const Color(0xFFFFF8EE)
          : timeline
          ? const Color(0xFFFCFAFF)
          : const Color(0xFFFCF9F4));
  TextStyle text(double size, {bool bold = false, Color? color}) => TextStyle(
    fontFamily:
        palette?.fontFamily ?? (minimal ? 'NotoSerifTC' : 'jfOpenHuninn'),
    fontFamilyFallback: const ['NotoSansTC', 'jfOpenHuninn'],
    fontSize: size,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    fontVariations:
        (palette?.fontFamily ?? (minimal ? 'NotoSerifTC' : 'jfOpenHuninn')) ==
            'NotoSerifTC'
        ? [FontVariation('wght', bold ? 700 : 500)]
        : null,
    height: 1.6,
    color: color == Colors.white
        ? (palette?.onAccent ?? Colors.white)
        : color ?? ink,
  );

  List<_Section> get _sections {
    final result = <_Section>[];
    for (final block in guide.visibleBlocks) {
      if (block.type == 'heading') {
        result.add(_Section(block.text));
      } else {
        if (result.isEmpty) result.add(_Section('準備清單'));
        result.last.blocks.add(block);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: paper,
    child: LayoutBuilder(
      builder: (context, viewport) {
        final narrow =
            viewport.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(14) > 23;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 20 : 34,
            vertical: 18,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _navigation(narrow),
                    const SizedBox(height: 16),
                    _hero(context, narrow),
                    if (!minimal && total > 0) ...[
                      const SizedBox(height: 14),
                      _progress(narrow),
                    ],
                    const SizedBox(height: 26),
                    if (_sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('尚未新增準備內容', style: text(16)),
                      ),
                    if (packing)
                      _packingSections(context, narrow)
                    else if (timeline)
                      _timelineSections(context, narrow)
                    else
                      for (final section in _sections)
                        _minimalSection(context, section, narrow),
                    const SizedBox(height: 26),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onContact,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor:
                                  palette?.onAccent ?? Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: Icon(
                              minimal
                                  ? Icons.mail_outline
                                  : Icons.chat_bubble_outline,
                              size: 28,
                            ),
                            label: Text(
                              '聯絡店家',
                              style: text(25, bold: true, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      preview
                          ? '預覽模式：可試勾，不會儲存進度。'
                          : '勾選進度只保留在此裝置，供自己整理使用，不會回報店家。',
                      style: text(12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _navigation(bool narrow) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, color: ink, size: 25),
          const SizedBox(width: 8),
          Flexible(child: Text('PetNest', style: text(25, bold: true))),
          if (!narrow) ...[
            const SizedBox(width: 16),
            Text('｜ 入住前準備', style: text(16)),
          ],
        ],
      ),
      TextButton.icon(
        onPressed: onBack,
        style: TextButton.styleFrom(foregroundColor: ink),
        icon: Icon(Icons.arrow_back, size: 20),
        label: Text(backLabel, style: text(16)),
      ),
    ],
  );

  Widget _hero(BuildContext context, bool narrow) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!minimal)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(packing ? 10 : 24),
              border: packing
                  ? Border.all(color: accent.withValues(alpha: .4))
                  : null,
            ),
            child: Text(
              packing ? '行李打包清單' : '出發時間軸',
              style: text(16, bold: true),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          guide.displayTitle,
          style: text(
            narrow ? 36 : 68,
            bold: true,
          ).copyWith(height: 1.3, letterSpacing: 2),
        ),
        const SizedBox(height: 14),
        Text(
          packing
              ? '出發前先確認以下事項，\n讓貓咪的旅宿體驗更安心舒適！'
              : timeline
              ? '依步驟完成出發前的準備，\n讓貓咪入住更安心、順利！'
              : '為了讓貓咪在住宿期間更安心舒適，\n請依下方清單提前準備。',
          style: text(narrow ? 16 : 20),
        ),
      ],
    );
    if (minimal) {
      return LayoutBuilder(
        builder: (context, box) {
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ArrivalIllustration(
                        style: guide.style,
                        cell: 0,
                        size: 140,
                      ),
                    ),
                    if (total > 0) Expanded(child: _minimalProgress()),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 5, child: heading),
              Expanded(
                flex: 3,
                child: ArrivalIllustration(
                  style: guide.style,
                  cell: 0,
                  size: 220,
                ),
              ),
              if (total > 0) Expanded(flex: 3, child: _minimalProgress()),
            ],
          );
        },
      );
    }
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          Center(
            child: ArrivalIllustration(style: guide.style, cell: 0, size: 220),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 5, child: heading),
        Expanded(
          flex: 4,
          child: ArrivalIllustration(style: guide.style, cell: 0, size: 320),
        ),
      ],
    );
  }

  Widget _minimalProgress() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: (palette?.overridden == true
          ? accent.withValues(alpha: .22)
          : const Color(0xFFF3EBE2)),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Column(
      children: [
        Text('準備進度 $done / $total', style: text(16)),
        const SizedBox(height: 4),
        Text('$done / $total', style: text(38, color: accent)),
        const SizedBox(height: 8),
        _bar(),
      ],
    ),
  );
  Widget _bar() => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: LinearProgressIndicator(
      value: total == 0 ? 0 : done / total,
      minHeight: 13,
      color: accent,
      backgroundColor: accent.withValues(alpha: .15),
    ),
  );
  Widget _progress(bool narrow) => Container(
    padding: EdgeInsets.symmetric(horizontal: timeline ? 20 : 4, vertical: 16),
    decoration: BoxDecoration(
      color: timeline ? accent.withValues(alpha: .1) : null,
      borderRadius: BorderRadius.circular(20),
    ),
    child: narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('準備進度 $done / $total', style: text(18, bold: true)),
              const SizedBox(height: 12),
              _bar(),
            ],
          )
        : Row(
            children: [
              Icon(
                packing ? Icons.luggage : Icons.pets,
                color: accent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text('準備進度 $done / $total', style: text(20, bold: true)),
              const SizedBox(width: 26),
              Expanded(child: _bar()),
            ],
          ),
  );

  Widget _packingSections(BuildContext context, bool narrow) {
    final groups = _sections;
    if (narrow) {
      return Column(
        children: [
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _packingCard(context, group, narrow),
            ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < groups.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _packingCard(context, groups[i], narrow)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: i + 1 < groups.length
                        ? _packingCard(context, groups[i + 1], narrow)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _packingCard(BuildContext context, _Section section, bool narrow) =>
      Container(
        padding: EdgeInsets.all(narrow ? 18 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette?.overridden == true
                ? [palette!.card, palette!.card]
                : const [Color(0xFFFFFBF4), Color(0xFFFFF6E8)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: (palette?.overridden == true
                ? accent.withValues(alpha: .22)
                : const Color(0xFFEBD8C4)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x146E482A),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 25,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (palette?.overridden == true
                          ? accent.withValues(alpha: .22)
                          : const Color(0xFFC9996B)),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.circle, color: Color(0xFFC9996B), size: 8),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: palette?.overridden == true
                            ? [accent, accent]
                            : const [Color(0xFFE98E50), Color(0xFFBD5B33)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _sectionIcon(section.title),
                          color: palette?.onAccent ?? Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            section.title,
                            style: text(24, bold: true, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(_description(section.title), style: text(16)),
            const SizedBox(height: 10),
            if (section.title == '店家提供')
              _provided(context, section, narrow)
            else
              for (var i = 0; i < section.blocks.length; i++) ...[
                if (i > 0)
                  Divider(color: accent.withValues(alpha: .12), height: 24),
                _item(context, section.blocks[i], narrow: narrow),
              ],
          ],
        ),
      );

  Widget _timelineSections(BuildContext context, bool narrow) {
    final known = _sections
        .where((s) => ['必須攜帶', '視需要攜帶', '店家提供'].contains(s.title))
        .toList();
    if (known.isEmpty) {
      return Column(
        children: [
          for (var i = 0; i < _sections.length; i++)
            _stage(
              i + 1,
              _sections[i].title,
              Column(
                children: [
                  for (final b in _sections[i].blocks)
                    _item(context, b, narrow: narrow),
                ],
              ),
            ),
        ],
      );
    }
    final arrival = _sections.where((s) => s.title == '到店前提醒');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stage(
          1,
          '提前準備',
          Row(
            children: [
              ArrivalIllustration(
                style: guide.style,
                cell: 7,
                size: narrow ? 60 : 85,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '如有特殊需求（如用藥、特殊照護、行為注意事項），建議提前聯繫店家確認安排。',
                  style: text(16),
                ),
              ),
            ],
          ),
        ),
        _stage(
          2,
          '整理行李',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in known) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: section.title == '店家提供'
                        ? accent.withValues(alpha: .06)
                        : (palette?.overridden == true
                              ? palette!.card
                              : Colors.white.withValues(alpha: .7)),
                    borderRadius: BorderRadius.circular(18),
                    border: section.title == '店家提供'
                        ? Border.all(color: accent.withValues(alpha: .3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (palette?.overridden == true
                                  ? accent.withValues(alpha: .22)
                                  : const Color(0xFFE2D6F6)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              section.title,
                              style: text(19, bold: true),
                            ),
                          ),
                          Text(_description(section.title), style: text(14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (section.title == '店家提供')
                        _provided(context, section, narrow)
                      else
                        for (var i = 0; i < section.blocks.length; i++) ...[
                          if (i > 0)
                            Divider(color: accent.withValues(alpha: .2)),
                          _item(context, section.blocks[i], narrow: narrow),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        if (arrival.isNotEmpty)
          _stage(
            3,
            '出發前',
            Column(
              children: [
                for (final section in arrival)
                  for (final block in section.blocks)
                    _item(context, block, narrow: narrow),
              ],
            ),
          ),
        for (final section in _sections.where(
          (s) => !['必須攜帶', '視需要攜帶', '店家提供', '到店前提醒'].contains(s.title),
        ))
          _stage(
            4,
            section.title,
            Column(
              children: [
                for (final block in section.blocks)
                  _item(context, block, narrow: narrow),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stage(int number, String title, Widget child) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: accent,
                foregroundColor: palette?.onAccent ?? Colors.white,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 4,
                  color: (palette?.overridden == true
                      ? accent.withValues(alpha: .22)
                      : const Color(0xFFD6C5EF)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette?.overridden == true
                    ? [palette!.card, palette!.card]
                    : const [Color(0xFFF4F0FC), Color(0xFFEFE9F8)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (palette?.overridden == true
                          ? accent.withValues(alpha: .22)
                          : const Color(0xFFD9C8F0)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(title, style: text(23, bold: true)),
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _minimalSection(BuildContext context, _Section section, bool narrow) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _eyebrow(section.title),
          style: text(15).copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 10),
        Text(section.title, style: text(27, bold: true)),
        const SizedBox(height: 16),
        Container(
          width: 38,
          height: 3,
          color: (palette?.overridden == true
              ? accent.withValues(alpha: .22)
              : const Color(0xFFD5B2A0)),
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.title == '店家提供') ...[
          Text('以下用品由店家提供，無需自行準備。', style: text(17)),
          const SizedBox(height: 12),
        ],
        if (section.title == '店家提供' &&
            section.blocks.every((b) => b.type == 'text') &&
            section.blocks.any(
              (b) => b.id == 'catalog-litter' || b.id == 'catalog-bowl',
            )) ...[
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              if (section.blocks.any((b) => b.id == 'catalog-litter')) ...[
                _supplyTile('貓砂', 1),
                _supplyTile('砂盆', 2),
              ],
              if (section.blocks.any((b) => b.id == 'catalog-bowl'))
                _supplyTile('餐碗', null),
            ],
          ),
          const SizedBox(height: 12),
          for (final block in section.blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(block.text, style: text(15)),
            ),
        ] else
          for (var i = 0; i < section.blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _item(context, section.blocks[i], narrow: narrow),
          ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: (palette?.overridden == true
                ? accent.withValues(alpha: .22)
                : const Color(0xFFD6C3B7)),
            width: 1,
          ),
        ),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 20), content],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 200, child: label),
                Container(
                  width: 1,
                  height: 150,
                  color: (palette?.overridden == true
                      ? accent.withValues(alpha: .22)
                      : const Color(0xFFDDCEC2)),
                ),
                const SizedBox(width: 28),
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _provided(BuildContext context, _Section section, bool narrow) {
    final descriptions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in section.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: block.type == 'text'
                ? Text(
                    block.text,
                    style: text(16),
                    textAlign: packing ? TextAlign.center : TextAlign.start,
                  )
                : _item(context, block, narrow: narrow),
          ),
      ],
    );
    if (packing) {
      return Column(
        children: [
          ArrivalIllustration(
            style: guide.style,
            cell: 5,
            size: narrow ? 155 : 190,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: (palette?.overridden == true
                  ? accent.withValues(alpha: .22)
                  : const Color(0xFFFFDEB7)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('店內提供用品', style: text(21, bold: true)),
          ),
          const SizedBox(height: 12),
          descriptions,
        ],
      );
    }
    return Row(
      children: [
        ArrivalIllustration(
          style: guide.style,
          cell: 5,
          size: narrow ? 65 : 115,
        ),
        const SizedBox(width: 12),
        Expanded(child: descriptions),
      ],
    );
  }

  Widget _supplyTile(String title, int? cell) => Container(
    width: 145,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: (palette?.overridden == true
          ? accent.withValues(alpha: .22)
          : const Color(0xFFF3EBE2)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        if (cell != null)
          ArrivalIllustration(style: guide.style, cell: cell, size: 75)
        else
          SizedBox(
            height: 75,
            child: Icon(Icons.rice_bowl_outlined, color: ink, size: 52),
          ),
        Text(title, style: text(20)),
      ],
    ),
  );

  Widget _item(
    BuildContext context,
    PreArrivalGuideBlock block, {
    required bool narrow,
  }) {
    if (block.type == 'image') return imageBuilder(block);
    if (block.type == 'heading') {
      return Text(block.text, style: text(21, bold: true));
    }
    final info = PreArrivalItemPresentation.forBlock(block);
    final checkable = block.type == 'checklist';
    final checked = isChecked(block);
    final artSize = narrow
        ? 62.0
        : packing
        ? 95.0
        : 100.0;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (checkable) ...[
            Icon(
              checked ? Icons.check_box_rounded : Icons.check_box_outline_blank,
              color: checked ? accent : ink.withValues(alpha: .8),
              size: narrow ? 26 : 31,
            ),
            SizedBox(width: narrow ? 9 : 14),
          ],
          ...[
            if (info.atlasCell != null && !minimal)
              ArrivalIllustration(
                style: guide.style,
                cell: info.atlasCell!,
                size: artSize,
              )
            else
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(info.icon, size: narrow ? 30 : 40, color: accent),
              ),
            SizedBox(width: narrow ? 8 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.title.isNotEmpty)
                  Text(info.title, style: text(narrow ? 19 : 26, bold: true)),
                Text(block.text, style: text(narrow ? 14 : 16)),
              ],
            ),
          ),
        ],
      ),
    );
    if (!checkable) return content;
    return Semantics(
      checked: checked,
      enabled: onToggle != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('preparation-check-${block.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onToggle == null ? null : () => onToggle!(block, !checked),
          child: content,
        ),
      ),
    );
  }

  String _description(String title) => switch (title) {
    '必須攜帶' => '入住所需的重要物品，請務必準備。',
    '視需要攜帶' => '依貓咪的個別狀況與習慣，酌情準備。',
    '店家提供' => '以下用品由店內備有，無需特別準備。',
    '到店前提醒' => '出發前再確認，讓行程更順利。',
    _ => '',
  };
  String _eyebrow(String title) => switch (title) {
    '必須攜帶' => 'PACKING',
    '視需要攜帶' => 'OPTIONAL',
    '店家提供' => 'PROVIDED',
    '到店前提醒' => 'BEFORE ARRIVAL',
    _ => 'FOR YOUR STAY',
  };
  IconData _sectionIcon(String title) => switch (title) {
    '店家提供' => Icons.home_outlined,
    '到店前提醒' => Icons.notifications_outlined,
    _ => Icons.pets,
  };
}
