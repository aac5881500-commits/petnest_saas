// lib/core/widgets/daily_care_card_surface.dart
// 🐾 每日照護內容卡片共用外觀
// 功能：每張卡片各自依自己的 bounds 鋪同一張 card background，
// 使用 DecorationImage，避免 Web 上 Image 只顯示中間一條。

import 'package:flutter/material.dart';

import '../models/daily_care_setting_model.dart';

class DailyCareCardSurface extends StatelessWidget {
  const DailyCareCardSurface({
    super.key,
    required this.setting,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
    this.longText = false,
  });

  final DailyCareSettingModel setting;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool longText;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFFFFFDFB)),
          ),
          if (setting.hasCardBackgroundVisual)
            Positioned.fill(
              child: DailyCareCardBackgroundFill(setting: setting),
            ),
          if (setting.hasCardBackgroundVisual)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(
                    alpha: setting.resolvedCardOverlayOpacity(
                      longText: longText,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.08),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 依「這一張卡片」的寬高鋪滿背景圖，不跟其他卡片共用同一張畫布。
class DailyCareCardBackgroundFill extends StatelessWidget {
  const DailyCareCardBackgroundFill({super.key, required this.setting});

  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const ColoredBox(color: Color(0xFFFFFDFB));
        }

        return SizedBox(
          width: width,
          height: height,
          child: _fill(width: width, height: height),
        );
      },
    );
  }

  Widget _fill({required double width, required double height}) {
    if (setting.hasCustomCardBackgroundImage) {
      return _networkFill(
        url: setting.cardBackgroundImageUrl,
        repeat: setting.cardBackgroundImageFit ==
            DailyCareJournalTheme.fitContain,
      );
    }

    final DailyCareCardBackgroundPreset preset = setting.resolvedCardPreset;
    if (preset.hasAsset) {
      return _assetFill(
        assetPath: preset.assetPath,
        repeat: setting.cardBackgroundImageFit ==
            DailyCareJournalTheme.fitContain,
        fallbackKey: preset.key,
      );
    }

    return CustomPaint(
      size: Size(width, height),
      painter: DailyCareCardPresetPainter(
        presetKey: preset.key,
        sparse: true,
      ),
    );
  }

  Widget _networkFill({
    required String url,
    required bool repeat,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(url),
          fit: repeat ? BoxFit.contain : BoxFit.cover,
          repeat: repeat ? ImageRepeat.repeat : ImageRepeat.noRepeat,
          alignment: Alignment.center,
          onError: (error, stackTrace) {},
        ),
      ),
    );
  }

  Widget _assetFill({
    required String assetPath,
    required bool repeat,
    required String fallbackKey,
  }) {
    return Image.asset(
      assetPath,
      fit: repeat ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      repeat: repeat ? ImageRepeat.repeat : ImageRepeat.noRepeat,
      errorBuilder: (context, error, stackTrace) {
        return CustomPaint(
          painter: DailyCareCardPresetPainter(
            presetKey: fallbackKey,
            sparse: true,
          ),
        );
      },
    );
  }
}

/// 整頁日誌背景，與卡片背景分開控制。
class DailyCareJournalPageBackground extends StatelessWidget {
  const DailyCareJournalPageBackground({super.key, required this.setting});

  final DailyCareSettingModel setting;

  @override
  Widget build(BuildContext context) {
    if (!setting.hasCustomBackgroundImage) {
      return ColoredBox(color: setting.resolvedPageColor());
    }

    final bool contain =
        setting.backgroundImageFit == DailyCareJournalTheme.fitContain;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: setting.resolvedPageColor()),
        DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(setting.backgroundImageUrl),
              fit: contain ? BoxFit.contain : BoxFit.cover,
              repeat: contain ? ImageRepeat.repeat : ImageRepeat.noRepeat,
              alignment: Alignment.center,
              onError: (error, stackTrace) {},
            ),
          ),
        ),
        ColoredBox(color: setting.resolvedPageOverlayColor()),
      ],
    );
  }
}

/// 內建圖尚未放入 assets 時的辨識用 fallback，不是店家上傳圖。
class DailyCareCardPresetPainter extends CustomPainter {
  const DailyCareCardPresetPainter({
    required this.presetKey,
    this.sparse = false,
  });

  final String presetKey;
  final bool sparse;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    switch (presetKey) {
      case DailyCareJournalTheme.cardPresetPaw:
        _paintPaws(canvas, size);
        return;
      case DailyCareJournalTheme.cardPresetLeaf:
        _paintLeaves(canvas, size);
        return;
      case DailyCareJournalTheme.cardPresetCat:
        _paintCats(canvas, size);
        return;
      case DailyCareJournalTheme.cardPresetHome:
        _paintHomes(canvas, size);
        return;
      case DailyCareJournalTheme.cardPresetGeo:
        _paintGeo(canvas, size);
        return;
      default:
        return;
    }
  }

  void _paintPaws(Canvas canvas, Size size) {
    final double stepX = sparse ? 118 : 72;
    final double stepY = sparse ? 108 : 64;
    final Paint paint = Paint()
      ..color = Color(0xFFD7C4B0).withValues(alpha: sparse ? 0.36 : 0.48)
      ..style = PaintingStyle.fill;
    for (double y = 22; y < size.height; y += stepY) {
      for (double x = 28; x < size.width; x += stepX) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 14, height: 11),
          paint,
        );
        canvas.drawCircle(Offset(x - 10, y - 11), 3, paint);
        canvas.drawCircle(Offset(x - 2, y - 13), 3, paint);
        canvas.drawCircle(Offset(x + 6, y - 13), 3, paint);
        canvas.drawCircle(Offset(x + 12, y - 9), 3, paint);
      }
    }
  }

  void _paintLeaves(Canvas canvas, Size size) {
    final double stepX = sparse ? 96 : 52;
    final double stepY = sparse ? 88 : 48;
    final Paint paint = Paint()
      ..color = Color(0xFFB7CDB8).withValues(alpha: sparse ? 0.20 : 0.36)
      ..style = PaintingStyle.fill;
    for (double y = 18; y < size.height; y += stepY) {
      for (double x = 20; x < size.width; x += stepX) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 18, height: 9),
          paint,
        );
      }
    }
  }

  void _paintCats(Canvas canvas, Size size) {
    final double stepX = sparse ? 120 : 72;
    final double stepY = sparse ? 104 : 60;
    final Paint paint = Paint()
      ..color = Color(0xFFC9B8C4).withValues(alpha: sparse ? 0.22 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (double y = 28; y < size.height; y += stepY) {
      for (double x = 28; x < size.width; x += stepX) {
        canvas.drawCircle(Offset(x, y), 9, paint);
        canvas.drawLine(Offset(x - 6, y - 7), Offset(x - 11, y - 16), paint);
        canvas.drawLine(Offset(x + 6, y - 7), Offset(x + 11, y - 16), paint);
      }
    }
  }

  void _paintHomes(Canvas canvas, Size size) {
    final double stepX = sparse ? 116 : 68;
    final double stepY = sparse ? 100 : 56;
    final Paint paint = Paint()
      ..color = Color(0xFFC8BBA8).withValues(alpha: sparse ? 0.20 : 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (double y = 28; y < size.height; y += stepY) {
      for (double x = 22; x < size.width; x += stepX) {
        canvas.drawRect(Rect.fromLTWH(x, y, 18, 13), paint);
        canvas.drawLine(Offset(x, y), Offset(x + 9, y - 9), paint);
        canvas.drawLine(Offset(x + 18, y), Offset(x + 9, y - 9), paint);
      }
    }
  }

  void _paintGeo(Canvas canvas, Size size) {
    final double step = sparse ? 72 : 40;
    final Paint paint = Paint()
      ..color = Color(0xFFB8B6C9).withValues(alpha: sparse ? 0.18 : 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = 20; y < size.height; y += step) {
      for (double x = 20; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DailyCareCardPresetPainter oldDelegate) {
    return oldDelegate.presetKey != presetKey || oldDelegate.sparse != sparse;
  }
}
