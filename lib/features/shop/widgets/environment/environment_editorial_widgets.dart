import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_layout_settings.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'environment_photo.dart';

class EnvironmentSplitPhoto extends StatelessWidget {
  const EnvironmentSplitPhoto({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.settings,
    this.hero = false,
  });
  final String imageUrl, title, subtitle;
  final EnvironmentLayoutSettings settings;
  final bool hero;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = c.maxWidth >= 800;
      final textSize = hero
          ? settings.number('heroTitleSize', 27, 18, 42) * (desktop ? 1.6 : 1)
          : settings.number('bannerTitleSize', 20, 14, 34) *
                (desktop ? 1.5 : 1);
      final photoWidth =
          c.maxWidth *
          (hero
              ? settings.number('heroPhotoFraction', .62, .3, .85) *
                    (desktop ? .9 : 1)
              : settings.number('bannerPhotoFraction', .42, .25, .65));
      final textWidth = c.maxWidth * (hero ? (desktop ? .55 : .82) : .64);
      final minHeight = hero
          ? settings.number('heroHeight', 240, 140, 420) * (desktop ? 1.125 : 1)
          : settings.number('bannerHeight', 92, 72, 220) * (desktop ? 1.26 : 1);
      final ink = settings.color(
        hero ? 'heroTextColor' : 'bannerTextColor',
        Colors.white,
      );
      final fill = settings.color(
        hero ? 'heroFill' : 'bannerFill',
        hero ? const Color(0xff58452e) : const Color(0xff718064),
      );
      final text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hero && settings.text('heroEyebrow').isNotEmpty) ...[
            Text(
              settings.text('heroEyebrow'),
              style: TextStyle(fontSize: desktop ? 12 : 10, color: ink),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            hero && !desktop && settings.text('heroLineBreak') == 'punctuation'
                ? title.replaceFirst('，', '，\n')
                : title,
            style: TextStyle(
              fontSize: textSize,
              height: 1.3,
              color: ink,
              fontWeight: hero ? FontWeight.w600 : FontWeight.normal,
              fontFamily: hero
                  ? null
                  : settings.text('bannerFontFamily').isEmpty
                  ? null
                  : settings.text('bannerFontFamily'),
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            SizedBox(height: hero ? 14 : 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: desktop ? 14 : 11,
                height: 1.7,
                color: ink.withValues(alpha: .92),
              ),
            ),
          ],
        ],
      );
      // The non-positioned text supplies intrinsic height, so large text never clips.
      return ClipRRect(
        borderRadius: BorderRadius.circular(hero ? 0 : settings.cardRadius),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            if (hero && settings.text('heroBackdrop').isNotEmpty)
              Positioned.fill(
                child: EnvironmentPhoto(
                  imageUrl: settings.text('heroBackdrop'),
                  fit: BoxFit.fill,
                ),
              ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: photoWidth,
              child: EnvironmentPhoto(imageUrl: imageUrl),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      fill.withValues(
                        alpha: hero && settings.text('heroBackdrop').isNotEmpty
                            ? .5
                            : 1,
                      ),
                      fill.withValues(
                        alpha: hero && settings.text('heroBackdrop').isNotEmpty
                            ? .7
                            : .94,
                      ),
                      fill.withValues(alpha: 0),
                    ],
                    stops: hero ? [0, .30, .77] : [0, .40, .78],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hero ? (desktop ? 44 : 20) : 22,
                    vertical: hero ? 32 : 16,
                  ),
                  child: SizedBox(
                    width: math.max(1, textWidth - (hero ? 40 : 24)),
                    child: Center(widthFactor: 1, child: text),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class EnvironmentPhotoSideCard extends StatelessWidget {
  const EnvironmentPhotoSideCard({
    super.key,
    required this.item,
    required this.settings,
    required this.theme,
    required this.icon,
    this.wideLayout = false,
  });
  final Map<String, dynamic> item;
  final EnvironmentLayoutSettings settings;
  final HomeThemeModel theme;
  final IconData icon;
  final bool wideLayout;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = wideLayout;
      final title = (item['title'] ?? '').toString(),
          subtitle = (item['subtitle'] ?? '').toString(),
          description = (item['description'] ?? '').toString();
      final hasImage = (item['imageUrl'] ?? '').toString().trim().isNotEmpty;
      final fraction = desktop
          ? (settings.photoFraction + .13).clamp(.3, .65)
          : settings.photoFraction;
      final imageWidth = hasImage ? c.maxWidth * fraction : 0.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(settings.cardRadius),
        child: ColoredBox(
          color: settings.color('featureFill', theme.cardColor),
          child: Stack(
            children: [
              if (hasImage)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: imageWidth,
                  child: EnvironmentPhoto(
                    imageUrl: item['imageUrl'].toString(),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(left: imageWidth),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: desktop
                        ? settings.photoHeight * 1.7
                        : settings.photoHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(desktop ? 22 : 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (settings.showFeatureIcon) ...[
                          Icon(icon, color: theme.primaryColor, size: 18),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: settings.titleSize + (desktop ? 3 : 0),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: desktop ? 14 : 11,
                              height: 1.5,
                              color: theme.textColor,
                            ),
                          ),
                        if (settings.showDivider && desktop)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 32,
                              child: Divider(
                                height: 1,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: desktop ? 12 : 10,
                              height: 1.7,
                              color: theme.secondaryTextColor,
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
      );
    },
  );
}

class EnvironmentMediaStrip extends StatelessWidget {
  const EnvironmentMediaStrip({
    super.key,
    required this.items,
    required this.theme,
    required this.settings,
    required this.iconOf,
  });
  final List<Map<String, dynamic>> items;
  final HomeThemeModel theme;
  final EnvironmentLayoutSettings settings;
  final IconData Function(String) iconOf;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final desktop = c.maxWidth >= 800;
      Widget card(Map<String, dynamic> item) => Padding(
        padding: EdgeInsets.all(desktop ? 14 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              item['icon'] is IconData
                  ? item['icon'] as IconData
                  : iconOf((item['icon'] ?? 'pets').toString()),
              size: 30,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 12),
            if ((item['imageUrl'] ?? '').toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: desktop ? 74 : 64,
                  height: desktop ? 84 : 64,
                  child: EnvironmentPhoto(
                    imageUrl: item['imageUrl'].toString(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['title'] ?? '').toString(),
                    style: TextStyle(
                      fontSize: desktop ? 16 : 14,
                      color: theme.textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (item['description'] ?? '').toString(),
                    style: TextStyle(
                      fontSize: desktop ? 11 : 10,
                      height: 1.6,
                      color: theme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: settings.color('equipmentFill', const Color(0xffeff0e5)),
          borderRadius: BorderRadius.circular(settings.cardRadius),
        ),
        child: desktop
            ? Column(
                children: [
                  for (var start = 0; start < items.length; start += 3)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var i = start;
                            i < math.min(start + 3, items.length);
                            i++
                          ) ...[
                            if (i > start)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                child: VerticalDivider(
                                  width: 1,
                                  color: theme.primaryColor.withValues(
                                    alpha: .25,
                                  ),
                                ),
                              ),
                            Expanded(child: card(items[i])),
                          ],
                        ],
                      ),
                    ),
                ],
              )
            : Column(children: [for (final item in items) card(item)]),
      );
    },
  );
}
