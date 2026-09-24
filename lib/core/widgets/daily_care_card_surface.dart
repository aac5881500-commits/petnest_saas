// 檔案名稱：lib/core/widgets/daily_care_card_surface.dart
// 功能說明：每張卡片各自依自己的 bounds 鋪背景，支援單色／透明／霧化／圖庫。
// 🐾 每日照護內容卡片共用外觀
// 使用 DecorationImage，避免 Web 上 Image 只顯示中間一條。

import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/daily_care_journal_appearance.dart';
import '../models/daily_care_journal_layout.dart';
import '../models/daily_care_setting_model.dart';
import '../models/platform_media_asset.dart';
import 'platform_media_library_scope.dart';

class DailyCareCardSurface extends StatelessWidget {
  const DailyCareCardSurface({
    super.key,
    required this.setting,
    required this.child,
    this.layout,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
    this.longText = false,
    this.imageOverride,
    this.fill,
  });

  final DailyCareSettingModel setting;
  final Widget child;
  final DailyCareJournalCardLayout? layout;
  final EdgeInsetsGeometry padding;
  final bool longText;
  final ImageProvider? imageOverride;
  final Color? fill;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color solidFill =
        fill ??
        DailyCareJournalThemeTokensFill.of(
          layout?.colorKey ?? DailyCareJournalCardStyle.colorTheme,
        );
    PlatformMediaAsset? lookup(String id) {
      return PlatformMediaLibraryScope.lookup(context, id);
    }

    final DailyCareResolvedCardLook look = layout == null
        ? DailyCareJournalAppearance.defaultLook(
            setting,
            fill: solidFill,
            assetLookup: lookup,
          )
        : DailyCareJournalAppearance.cardLook(
            setting,
            layout!,
            fill: solidFill,
            assetLookup: lookup,
          );

    final bool translucent = look.isTransparent || look.isFrosted;
    final double overlay = DailyCareJournalAppearance.cardWashOpacity(
      look: look,
      setting: setting,
      longText: longText,
    );
    final double textVeil =
        DailyCareJournalAppearance.textReadabilityVeilOpacity(
          look: look,
          setting: setting,
        );
    final bool showImage = imageOverride != null || look.hasImageVisual;

    Widget surface = Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          child: ColoredBox(
            color: translucent
                ? Colors.white.withValues(alpha: 0.12)
                : (showImage ? const Color(0xFFFFFDFB) : solidFill),
          ),
        ),
        if (showImage)
          Positioned.fill(
            child: DailyCareCardBackgroundFill(
              setting: setting,
              look: look,
              imageOverride: imageOverride,
            ),
          ),
        if (showImage || translucent)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.white.withValues(alpha: overlay)),
            ),
          ),
        Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(setting.cardRadius),
            border: Border.all(color: colors.outline.withValues(alpha: 0.12)),
            gradient: textVeil > 0
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: textVeil),
                      Colors.white.withValues(alpha: textVeil * 0.88),
                    ],
                  )
                : null,
          ),
          child: child,
        ),
      ],
    );

    surface = ClipRRect(
      borderRadius: BorderRadius.circular(setting.cardRadius),
      child: surface,
    );

    if (DailyCareJournalAppearance.shouldApplyFrostedBackdrop(look)) {
      surface = DailyCareFrostedGlass(
        borderRadius: setting.cardRadius,
        child: surface,
      );
    }

    return surface;
  }
}

/// Web／Android／iOS 都優先 BackdropFilter；僅建立 filter 失敗時退回半透明。
class DailyCareFrostedGlass extends StatefulWidget {
  const DailyCareFrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = DailyCareCardSurface.radius,
  });

  final Widget child;
  final double borderRadius;

  @override
  State<DailyCareFrostedGlass> createState() => _DailyCareFrostedGlassState();
}

class _DailyCareFrostedGlassState extends State<DailyCareFrostedGlass> {
  ImageFilter? _filter;

  @override
  void initState() {
    super.initState();
    try {
      _filter = ImageFilter.blur(sigmaX: 16, sigmaY: 16);
    } catch (_) {
      _filter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: widget.child,
    );
    final ImageFilter? filter = _filter;
    if (filter == null) {
      return clipped;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(filter: filter, child: clipped),
    );
  }
}

/// 給 ink 對比用的淺色填色，避免再複製 ThemeTokens。
class DailyCareJournalThemeTokensFill {
  DailyCareJournalThemeTokensFill._();

  static Color of(String colorKey) {
    switch (colorKey) {
      case DailyCareJournalCardStyle.colorCream:
        return const Color(0xFFFFF8EE);
      case DailyCareJournalCardStyle.colorMint:
        return const Color(0xFFEAF4EC);
      case DailyCareJournalCardStyle.colorBlue:
        return const Color(0xFFE8F1F8);
      case DailyCareJournalCardStyle.colorOrange:
        return const Color(0xFFFFF1E6);
      case DailyCareJournalCardStyle.colorPink:
        return const Color(0xFFF8E9EE);
      case DailyCareJournalCardStyle.colorTheme:
      default:
        return const Color(0xFFFFFDFB);
    }
  }
}

/// 依「這一張卡片」的寬高鋪滿背景圖，不跟其他卡片共用同一張畫布。
class DailyCareCardBackgroundFill extends StatelessWidget {
  const DailyCareCardBackgroundFill({
    super.key,
    required this.setting,
    this.look,
    this.imageOverride,
  });

  final DailyCareSettingModel setting;
  final DailyCareResolvedCardLook? look;
  final ImageProvider? imageOverride;

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
          child: _fill(context, width: width, height: height),
        );
      },
    );
  }

  Widget _fill(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final bool repeat =
        setting.cardBackgroundImageFit == DailyCareJournalTheme.fitContain;
    if (imageOverride != null) {
      return _providerFill(imageOverride!, repeat: repeat);
    }
    final DailyCareResolvedCardLook? resolved = look;
    final String url = resolved?.resolvedUrl ?? '';
    if (url.isNotEmpty) {
      return _networkFill(url: url, repeat: repeat);
    }
    if (setting.hasCustomCardBackgroundImage) {
      return _networkFill(url: setting.cardBackgroundImageUrl, repeat: repeat);
    }

    final String presetKey =
        resolved?.presetKey ?? setting.resolvedCardPreset.key;
    final DailyCareCardBackgroundPreset preset =
        DailyCareJournalTheme.cardPresetByKey(presetKey) ??
        setting.resolvedCardPreset;
    if (preset.hasAsset) {
      return _assetFill(
        assetPath: preset.assetPath,
        repeat: repeat,
        fallbackKey: preset.key,
      );
    }

    return CustomPaint(
      size: Size(width, height),
      painter: DailyCareCardPresetPainter(presetKey: preset.key, sparse: true),
    );
  }

  Widget _providerFill(ImageProvider image, {required bool repeat}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: image,
          fit: repeat ? BoxFit.contain : BoxFit.cover,
          repeat: repeat ? ImageRepeat.repeat : ImageRepeat.noRepeat,
          alignment: Alignment.center,
          onError: (Object error, StackTrace? stackTrace) {},
        ),
      ),
    );
  }

  Widget _networkFill({required String url, required bool repeat}) {
    return _providerFill(NetworkImage(url), repeat: repeat);
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
  const DailyCareJournalPageBackground({
    super.key,
    required this.setting,
    this.imageOverride,
  });

  final DailyCareSettingModel setting;
  final ImageProvider? imageOverride;

  @override
  Widget build(BuildContext context) {
    final DailyCareResolvedPageLook look = DailyCareJournalAppearance.pageLook(
      setting,
      assetLookup: (String id) => PlatformMediaLibraryScope.lookup(context, id),
    );
    final ImageProvider? image =
        imageOverride ??
        (look.hasImage ? NetworkImage(look.resolvedUrl) : null);
    if (image == null) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: setting.resolvedPageColor()),
          const CustomPaint(
            painter: DailyCareJournalDecorPainter(),
            child: SizedBox.expand(),
          ),
        ],
      );
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
              image: image,
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

/// 低對比裝飾：肉掌／毛線，不影響閱讀。
class DailyCareJournalDecorPainter extends CustomPainter {
  const DailyCareJournalDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final Paint paw = Paint()
      ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;
    final Paint yarn = Paint()
      ..color = const Color(0xFF2F5D50).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (double y = 36; y < size.height; y += 120) {
      for (double x = 28; x < size.width; x += 110) {
        _paw(canvas, Offset(x, y), paw);
      }
    }
    for (double y = 90; y < size.height; y += 160) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.82, y),
          width: 42,
          height: 28,
        ),
        yarn,
      );
    }
  }

  void _paw(Canvas canvas, Offset origin, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: origin, width: 14, height: 11),
      paint,
    );
    canvas.drawCircle(origin + const Offset(-8, -8), 3.2, paint);
    canvas.drawCircle(origin + const Offset(-2, -10), 3.2, paint);
    canvas.drawCircle(origin + const Offset(4, -10), 3.2, paint);
    canvas.drawCircle(origin + const Offset(9, -7), 3.2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
