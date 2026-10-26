import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/models/store_banner_templates.dart';

class StoreBannerTemplatePicker extends StatelessWidget {
  const StoreBannerTemplatePicker({
    super.key,
    required this.scope,
    required this.onSelected,
  });
  final PetNestBannerScope scope;
  final ValueChanged<String> onSelected;

  String _label(String id) =>
      id == StoreBannerTemplates.promo && scope == PetNestBannerScope.home
      ? '活動宣傳'
      : StoreBannerTemplates.label(id);

  Widget _card(BuildContext context, String id, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('poster-template-$id'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(
                    painter: _TemplateDiagram(id, colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _label(id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          const Expanded(
            child: Text('快速版型', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(onPressed: () => _all(context), child: const Text('查看全部')),
        ],
      ),
      SizedBox(
        height: 96 + MediaQuery.textScalerOf(context).scale(14),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: <PointerDeviceKind>{
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: ListView.separated(
            key: const ValueKey<String>('poster-template-strip'),
            primary: false,
            scrollDirection: Axis.horizontal,
            itemCount: StoreBannerTemplates.idsFor(scope).length,
            separatorBuilder: (_, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final id = StoreBannerTemplates.idsFor(scope)[index];
              return SizedBox(
                width: 120,
                child: _card(context, id, () => onSelected(id)),
              );
            },
          ),
        ),
      ),
    ],
  );

  void _all(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  '選擇海報構圖',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('先選構圖，再修改文案；套用前會再次確認。'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    childAspectRatio: 1.1,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: StoreBannerTemplates.idsFor(scope).length,
                  itemBuilder: (context, index) {
                    final id = StoreBannerTemplates.idsFor(scope)[index];
                    return _card(context, id, () {
                      Navigator.pop(sheetContext);
                      onSelected(id);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateDiagram extends CustomPainter {
  _TemplateDiagram(this.id, this.accent);
  final String id;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF2E6D7),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .48,
        -size.height * .15,
        size.width * .7,
        size.height * 1.4,
      ),
      Paint()..color = const Color(0xFFD5B897),
    );
    if (id == StoreBannerTemplates.imageOnly) return;
    final banner = StoreBannerTemplates.apply(
      const StoreBannerModel(id: 'diagram'),
      id,
    );
    final scale = size.width / 1600;
    for (final text in banner.textElements) {
      final width =
          StoreBannerTextWidthPresets.ratio(text.maxWidthPreset) * size.width;
      final left = text.textAlign == StoreBannerTextAligns.right
          ? size.width * .94 - width
          : text.positionX * size.width;
      final y = text.positionY * size.height;
      final lineWidth = width * .82;
      final lineLeft = text.textAlign == StoreBannerTextAligns.center
          ? left + (width - lineWidth) / 2
          : text.textAlign == StoreBannerTextAligns.right
          ? left + width - lineWidth
          : left;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            lineLeft,
            y,
            lineWidth,
            (text.posterFontPx * scale * .6).clamp(2.0, 6.0),
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white,
      );
    }
    final box = StoreBannerCtaSizes.box(banner.ctaSize);
    final width = size.width * .22;
    final left = banner.ctaPositionX >= .99
        ? size.width * .94 - width
        : banner.ctaPositionX * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          banner.ctaPositionY * size.height,
          width,
          (box.occupiedHeight * scale).clamp(5.0, 12.0),
        ),
        const Radius.circular(3),
      ),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _TemplateDiagram old) =>
      old.id != id || old.accent != accent;
}
