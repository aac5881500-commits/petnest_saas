// 檔案名稱：lib/core/widgets/daily_care_illustrations.dart
// 功能說明：每日照護日誌原創 SVG 路徑與套色圖示。

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/daily_care_journal_appearance.dart';
import '../models/daily_care_journal_layout.dart';
import '../models/daily_care_setting_model.dart';
import 'daily_care_card_surface.dart';
import 'platform_media_library_scope.dart';

class DailyCareIllustrations {
  DailyCareIllustrations._();

  static const String folder = 'assets/daily_care/illustrations';

  static const String environment = '$folder/environment_thermometer.svg';
  static const String humidity = '$folder/environment_humidity.svg';
  static const String toilet = '$folder/toilet_care.svg';
  static const String meal = '$folder/meal_care.svg';
  static const String activity = '$folder/activity_care.svg';
  static const String relax = '$folder/relax_care.svg';
  static const String summary = '$folder/summary_care.svg';
  static const String photo = '$folder/photo_care.svg';
  static const String paw = '$folder/paw_decor.svg';
  static const String leaf = '$folder/leaf_decor.svg';
  static const String careDefault = '$folder/care_default.svg';

  static String forCard(String key) {
    switch (key) {
      case DailyCareJournalCardKeys.environment:
        return environment;
      case DailyCareJournalCardKeys.toilet:
        return toilet;
      case DailyCareJournalCardKeys.food:
        return meal;
      case DailyCareJournalCardKeys.activity:
        return activity;
      case DailyCareJournalCardKeys.relax:
        return relax;
      case DailyCareJournalCardKeys.generalNote:
        return summary;
      case DailyCareJournalCardKeys.photos:
        return photo;
      default:
        return careDefault;
    }
  }

  /// 腳印／樹葉裝飾素材仍保留，但照護內容卡片不再疊加。
  static String decorFor(String key) {
    if (key == DailyCareJournalCardKeys.environment) {
      return leaf;
    }
    return paw;
  }
}

class DailyCareInk {
  DailyCareInk._();

  static const Color dark = Color(0xFF3A332C);
  static const Color light = Color(0xFFF6F0E6);

  static Color of({
    required DailyCareJournalCardLayout layout,
    required Color fill,
    required ColorScheme colors,
    DailyCareResolvedCardLook? look,
  }) {
    switch (layout.inkMode) {
      case DailyCareJournalCardStyle.inkDark:
        return dark;
      case DailyCareJournalCardStyle.inkLight:
        return light;
      case DailyCareJournalCardStyle.inkCustom:
        if (layout.inkColorArgb == 0) {
          return dark;
        }
        return Color(layout.inkColorArgb);
      case DailyCareJournalCardStyle.inkAuto:
      default:
        if (look == null ||
            look.isTransparent ||
            look.isFrosted ||
            look.needsPhotoTextVeil ||
            look.mode == DailyCareJournalCardStyle.surfaceSolid) {
          return dark;
        }
        return dark;
    }
  }

  static Color headerOf({
    required DailyCareJournalHeaderStyle header,
    required Color fill,
    required ColorScheme colors,
  }) {
    return of(layout: header.asInkLayout, fill: fill, colors: colors);
  }

  static Color chipFill(Color ink, Color cardFill) {
    if (ink.computeLuminance() > 0.62) {
      return Color.alphaBlend(
        ink.withValues(alpha: 0.22),
        const Color(0xFF3A332C),
      );
    }
    return Color.alphaBlend(ink.withValues(alpha: 0.16), cardFill);
  }
}

class DailyCareTitleIcon extends StatelessWidget {
  const DailyCareTitleIcon({
    super.key,
    required this.layout,
    required this.color,
    this.size = 22,
    this.imageProviderBuilder,
  });

  static const double frameSize = 24;

  final DailyCareJournalCardLayout layout;
  final Color color;
  final double size;
  final ImageProvider Function(String url)? imageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final double glyph = size;
    final double frame = glyph <= 22 ? DailyCareTitleIcon.frameSize : glyph + 2;
    final Widget fallback = DailyCareSvgIcon(
      asset: DailyCareIllustrations.forCard(layout.key),
      color: color,
      size: glyph,
    );
    final String url = DailyCareJournalAppearance.titleIconUrl(
      layout,
      assetLookup: (String id) => PlatformMediaLibraryScope.lookup(context, id),
    );
    final Widget child = url.isEmpty
        ? fallback
        : Image(
            image: imageProviderBuilder?.call(url) ?? NetworkImage(url),
            width: glyph,
            height: glyph,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => fallback,
          );
    return SizedBox(
      width: frame,
      height: frame,
      child: Center(child: child),
    );
  }
}

class DailyCareSvgIcon extends StatelessWidget {
  const DailyCareSvgIcon({
    super.key,
    required this.asset,
    required this.color,
    this.size = 22,
    this.opacity = 1,
  });

  final String asset;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

class DailyCareIllustratedShell extends StatelessWidget {
  const DailyCareIllustratedShell({
    super.key,
    required this.layout,
    required this.title,
    required this.child,
    required this.fill,
    this.setting,
    this.ink,
    this.trailing,
    this.longText = false,
    this.radius = 16,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
  });

  final DailyCareJournalCardLayout layout;
  final String title;
  final Widget child;
  final Color fill;
  final DailyCareSettingModel? setting;
  final Color? ink;
  final Widget? trailing;
  final bool longText;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color text =
        ink ?? DailyCareInk.of(layout: layout, fill: fill, colors: colors);
    final Widget header = Row(
      children: <Widget>[
        DailyCareTitleIcon(layout: layout, color: text),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ),
        ?trailing,
      ],
    );
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[header, const SizedBox(height: 10), child],
    );
    final DailyCareSettingModel visual = setting == null
        ? const DailyCareSettingModel()
        : setting!;
    return DailyCareCardSurface(
      setting: visual,
      layout: layout,
      fill: fill,
      padding: padding,
      longText: longText,
      child: body,
    );
  }
}
