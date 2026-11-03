import 'store_entry_photo.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';

/// Seven reusable entrance layouts; photos and copy always belong to the shop.
class StoreEntryTemplateCard extends StatelessWidget {
  const StoreEntryTemplateCard({
    super.key,
    required this.setting,
    required this.theme,
    this.onTap,
  });
  final ModernStoreHomeSetting setting;
  final HomeThemeModel theme;
  final VoidCallback? onTap;
  Color get accent => theme.primaryColor;
  Color get ink => ModernStoreCardTextColors.colorOf(
    setting.storeBannerTitleColorPreset,
    theme,
  );
  Color get muted => ModernStoreCardTextColors.colorOf(
    setting.storeBannerSubtitleColorPreset,
    theme,
  );
  Color get paper => theme.backgroundColor;

  Widget _photo(String url, {double radius = 14}) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: url.trim().isEmpty
        ? ColoredBox(
            color: accent.withValues(alpha: .08),
            child: Center(
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: accent.withValues(alpha: .6),
                size: 34,
              ),
            ),
          )
        : StoreEntryPhoto(
            url,
            fit: setting.backgroundBoxFit,
            alignment: setting.backgroundAlignment,
            errorBuilder: (_, _, _) => ColoredBox(
              color: accent.withValues(alpha: .08),
              child: Center(
                child: Icon(Icons.image_not_supported_outlined, color: accent),
              ),
            ),
          ),
  );

  Widget _button({bool outline = false}) {
    final bg = ModernStoreCardButtonColors.backgroundOf(
      setting.storeBannerButtonColorPreset,
      theme,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : bg,
        border: Border.all(color: bg),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              setting.resolvedButtonText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: outline
                    ? bg
                    : ModernStoreCardButtonColors.foregroundOf(bg),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: outline ? bg : ModernStoreCardButtonColors.foregroundOf(bg),
          ),
        ],
      ),
    );
  }

  Widget _copy({
    bool center = false,
    bool outline = false,
    double titleSize = 20,
    bool button = true,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        setting.resolvedTitle,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontSize: titleSize,
          height: 1.3,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        setting.resolvedSubtitle,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      if (button) ...[const SizedBox(height: 14), _button(outline: outline)],
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 400;
      final layout = setting.storeEntryLayout;
      final body = switch (layout) {
        ModernStoreEntryLayouts.splitPhoto => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 170),
                  child: _photo(setting.storeBannerImageUrl, radius: 0),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: EdgeInsets.all(narrow ? 16 : 24),
                  child: Center(child: _copy(titleSize: narrow ? 17 : 24)),
                ),
              ),
            ],
          ),
        ),
        ModernStoreEntryLayouts.centeredPhoto => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cottage_outlined, size: 36, color: accent),
              const SizedBox(height: 10),
              _copy(center: true, button: false),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AspectRatio(
                  aspectRatio: 1.9,
                  child: _photo(setting.storeBannerImageUrl),
                ),
              ),
              const SizedBox(height: 18),
              _button(outline: true),
            ],
          ),
        ),
        ModernStoreEntryLayouts.layeredPhotos => Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: accent, size: 30),
                    const SizedBox(height: 10),
                    _copy(titleSize: narrow ? 17 : 22),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: narrow ? 140 : 220,
                    height: narrow ? 160 : 190,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          width: narrow ? 85 : 110,
                          height: narrow ? 112 : 140,
                          child: Transform.rotate(
                            angle: .06,
                            child: _photo(setting.storeEntrySecondImageUrl),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          width: narrow ? 95 : 125,
                          height: narrow ? 112 : 140,
                          child: Transform.rotate(
                            angle: -.04,
                            child: _photo(setting.storeBannerImageUrl),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ModernStoreEntryLayouts.ticket => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: narrow ? 34 : 52,
                  color: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _copy(button: false, titleSize: narrow ? 17 : 23),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 1,
                  child: CustomPaint(
                    painter: _Dashes(accent.withValues(alpha: .35)),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(child: _button()),
              ],
            ),
          ),
        ),
        ModernStoreEntryLayouts.boutique => Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: narrow ? 96 : 150,
                height: narrow ? 110 : 145,
                child: setting.storeBannerImageUrl.isEmpty
                    ? CustomPaint(painter: _Boutique(accent))
                    : _photo(setting.storeBannerImageUrl),
              ),
              const SizedBox(width: 16),
              Expanded(child: _copy(titleSize: narrow ? 18 : 25)),
            ],
          ),
        ),
        ModernStoreEntryLayouts.capsule => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  Icon(Icons.pets, size: narrow ? 38 : 52, color: accent),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _copy(button: false, titleSize: narrow ? 19 : 26),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 30),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: accent.withValues(alpha: .12),
              child: Text(
                '${setting.resolvedButtonText} ›',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ModernStoreCardButtonColors.backgroundOf(
                    setting.storeBannerButtonColorPreset,
                    theme,
                  ),
                ),
              ),
            ),
          ],
        ),
        _ => Stack(
          children: [
            Positioned.fill(
              child: _photo(setting.storeBannerImageUrl, radius: 0),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ModernStoreCardOverlayTones.colorOf(
                        setting.storeBannerOverlayTone,
                      ).withValues(
                        alpha: ModernStoreCardOverlays.opacity(
                          setting.storeBannerOverlayPreset,
                        ),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: ModernStoreCardPositions.alignment(
                    setting.storeBannerContentPosition,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: .65,
                    child: _copy(titleSize: narrow ? 19 : 28, outline: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      };
      final radius = layout == ModernStoreEntryLayouts.capsule ? 36.0 : 18.0;
      return Semantics(
        button: onTap != null,
        child: Material(
          key: ValueKey('store-entry-$layout'),
          color: paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: accent.withValues(alpha: .28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: layout == ModernStoreEntryLayouts.ticket
                ? ClipPath(clipper: _TicketClipper(), child: body)
                : body,
          ),
        ),
      );
    },
  );
}

class _Dashes extends CustomPainter {
  const _Dashes(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + 4, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()
      ..addOval(Rect.fromCircle(center: Offset(size.width * .72, 0), radius: 9))
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * .72, size.height),
          radius: 9,
        ),
      ),
  );
  @override
  bool shouldReclip(_TicketClipper old) => false;
}

/// Code-drawn decoration; a shop can replace it with its own uploaded artwork.
class _Boutique extends CustomPainter {
  const _Boutique(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 130);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color.withValues(alpha: .12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 48, 96, 74),
        const Radius.circular(6),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 48, 96, 74),
        const Radius.circular(6),
      ),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(5, 53)
        ..lineTo(20, 27)
        ..lineTo(100, 27)
        ..lineTo(115, 53)
        ..close(),
      line,
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(10 + i * 21, 40, 17, 13),
        i.isEven ? fill : Paint()
          ..color = Colors.transparent,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 70, 26, 52),
        const Radius.circular(13),
      ),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 72, 30, 30),
        const Radius.circular(4),
      ),
      line,
    );
    canvas.drawCircle(
      const Offset(60, 20),
      14,
      Paint()..color = color.withValues(alpha: .1),
    );
    canvas.drawCircle(const Offset(55, 19), 2, Paint()..color = color);
    canvas.drawCircle(const Offset(65, 19), 2, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(47, 12)
        ..lineTo(46, 3)
        ..lineTo(54, 9)
        ..moveTo(66, 9)
        ..lineTo(74, 3)
        ..lineTo(73, 12),
      line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Boutique old) => old.color != color;
}
