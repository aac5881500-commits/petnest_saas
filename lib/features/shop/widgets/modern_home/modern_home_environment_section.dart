import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
import 'environment_end_entry.dart';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'environment_home_image_resolver.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

/// 新版首頁環境展示。正式前台與外觀預覽共用。
class ModernHomeEnvironmentSection extends StatelessWidget {
  const ModernHomeEnvironmentSection({
    super.key,
    required this.theme,
    required this.setting,
    required this.environmentIntro,
    required this.facilityKeys,
    required this.preview,
    required this.onOpen,
    this.imageProvider,
    this.displayStyle,
  });

  final HomeThemeModel theme;
  final HomeEnvironmentSectionSetting setting;
  final Map<String, dynamic> environmentIntro;
  final List<String> facilityKeys;
  final bool preview;
  final VoidCallback onOpen;
  final ImageProvider<Object>? imageProvider;
  final HomeDisplayStyle? displayStyle;

  static List<Map<String, dynamic>> facilitiesFor(
    List<String> keys, {
    Map<String, dynamic>? introduction,
  }) {
    final raw = introduction?['environmentPresentation'];
    final order = raw is Map && raw['facilityOrder'] is List
        ? (raw['facilityOrder'] as List).whereType<String>().toList()
        : <String>[];
    final hidden = raw is Map && raw['hiddenFacilityKeys'] is List
        ? (raw['hiddenFacilityKeys'] as List).whereType<String>().toSet()
        : <String>{};
    final options = {
      for (final item in environmentFacilityOptions)
        item['key'].toString(): item,
    };
    return {...order, ...keys.where((key) => !order.contains(key))}
        .where(
          (key) =>
              keys.contains(key) &&
              options.containsKey(key) &&
              !hidden.contains(key),
        )
        .map((key) => options[key]!)
        .toList();
  }

  Widget _content(BuildContext context, String resolvedImageUrl) {
    final List<Map<String, dynamic>> facilities = setting.selectedFacilities(
      facilitiesFor(facilityKeys, introduction: environmentIntro),
    );
    switch (setting.layout) {
      case HomeEnvironmentLayouts.simpleEntry:
        return _entry(resolvedImageUrl);
      case HomeEnvironmentLayouts.imageEntry:
        final String imageUrl = resolvedImageUrl;
        if (imageUrl.isEmpty && imageProvider == null) {
          return _entry();
        }
        return _imageCard(imageUrl);
      case HomeEnvironmentLayouts.editorial:
        final String editorialUrl = resolvedImageUrl;
        if (editorialUrl.isEmpty && imageProvider == null) {
          return _entry();
        }
        return _editorial(editorialUrl);
      default:
        if (facilities.isEmpty) {
          return const SizedBox.shrink();
        }
        return _facilityScroll(facilities);
    }
  }

  bool get _showCardTitle =>
      setting.cardTitle.trim().isNotEmpty &&
      !(setting.showTitle && setting.title.trim() == setting.cardTitle.trim());
  bool get _showCardSubtitle =>
      setting.showSubtitle &&
      setting.cardSubtitle.trim().isNotEmpty &&
      !(setting.showDescription &&
          setting.subtitle.trim() == setting.cardSubtitle.trim());
  @override
  Widget build(BuildContext context) => EnvironmentHomeImageResolver(
    setting: setting,
    environmentIntro: environmentIntro,
    builder: (context, image) => _resolved(context, image.url),
  );

  Widget _resolved(BuildContext context, String imageUrl) {
    if (!ShopIntroContent.environment({'environmentIntro': environmentIntro})) {
      return const SizedBox.shrink();
    }
    if (setting.layout == HomeEnvironmentLayouts.facilityScroll &&
        setting
            .selectedFacilities(
              facilitiesFor(facilityKeys, introduction: environmentIntro),
            )
            .isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (setting.showTitle && setting.title.trim().isNotEmpty) ...[
          Text(
            setting.title.trim(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: displayStyle == null
                  ? theme.textColor
                  : Color(displayStyle!.titleColor),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (setting.showDescription && setting.subtitle.trim().isNotEmpty) ...[
          Text(
            setting.subtitle.trim(),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: displayStyle == null
                  ? theme.secondaryTextColor
                  : Color(displayStyle!.effectiveBodyColor),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _content(context, imageUrl),
      ],
    );
  }

  void _open() {
    if (preview) {
      return;
    }
    onOpen();
  }

  IconData get _icon {
    switch (setting.simpleIcon) {
      case HomeEnvironmentIcons.yard:
        return Icons.yard_outlined;
      case HomeEnvironmentIcons.pets:
        return Icons.pets_outlined;
      case HomeEnvironmentIcons.shield:
        return Icons.verified_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  Widget _editorial(String imageUrl) {
    final Widget photo = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: _photo(imageUrl, double.infinity, Alignment.center),
      ),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_showCardTitle)
          Text(
            setting.entryTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: homeDisplayFontSize(
                displayStyle?.titleSize ?? HomeDisplaySizes.medium,
                fallback: 18,
              ),
              height: 1.25,
              fontWeight: homeDisplayFontWeight(
                displayStyle?.titleWeight ?? HomeDisplayWeights.bold,
              ),
              color: displayStyle == null
                  ? theme.textColor
                  : Color(displayStyle!.titleColor),
            ),
          ),
        if (_showCardSubtitle) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            setting.cardSubtitle.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: homeDisplayFontSize(
                displayStyle?.bodySize ?? HomeDisplaySizes.small,
                fallback: 13,
              ),
              height: 1.45,
              fontWeight: homeDisplayFontWeight(
                displayStyle?.bodyWeight ?? HomeDisplayWeights.medium,
              ),
              color: displayStyle == null
                  ? theme.secondaryTextColor
                  : Color(displayStyle!.effectiveBodyColor),
            ),
          ),
        ],
      ],
    );
    return InkWell(
      key: const Key('home-environment-editorial'),
      onTap: _open,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[photo, const SizedBox(height: 10), copy],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (setting.editorialImageLeft) ...[
                Expanded(flex: 3, child: photo),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: copy),
              ] else ...[
                Expanded(flex: 2, child: copy),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: photo),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _entry([String imageUrl = '']) {
    return ModernHomeEntryCard(
      cardKey: const Key('home-environment-entry'),
      backgroundImage:
          setting.layout == HomeEnvironmentLayouts.simpleEntry &&
              setting.usesPlatformImage
          ? imageProvider ?? (imageUrl.isEmpty ? null : NetworkImage(imageUrl))
          : null,
      theme: theme,
      title: setting.entryTitle,
      subtitle: setting.cardSubtitle,
      showSubtitle: _showCardSubtitle,
      showTitle: _showCardTitle,
      cardSize: setting.simpleCardSize,
      surface: setting.simpleSurface,
      icon: _icon,
      actionLabel: '查看環境介紹',
      onTap: _open,
    );
  }

  Widget _facilityScroll(List<Map<String, dynamic>> facilities) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth * .28).clamp(78.0, 108.0);
        final height = 58 + 28 * MediaQuery.textScalerOf(context).scale(1);
        return SizedBox(
          height: height,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                key: const Key('home-environment-scroll'),
                scrollDirection: Axis.horizontal,
                primary: false,
                padding: EdgeInsets.only(
                  right: setting.showEndEntryCard ? 8 : 0,
                ),
                itemCount:
                    facilities.length + (setting.showEndEntryCard ? 1 : 0),
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == facilities.length) {
                    return Center(
                      widthFactor: 1,
                      child: EnvironmentEndEntry(
                        key: const Key('home-environment-end'),
                        style: setting.endEntryStyle,
                        color: theme.primaryColor,
                        onPressed: _open,
                      ),
                    );
                  }
                  final item = facilities[index];
                  return _facilityCard(
                    width: cardWidth,
                    icon: item['icon'] is IconData
                        ? item['icon'] as IconData
                        : Icons.pets_outlined,
                    label: (item['title'] ?? '照護設備').toString(),
                    cardKey: ValueKey(
                      'home-environment-facility-${item['key']}',
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _facilityCard({
    required double width,
    required IconData icon,
    required String label,
    required Key cardKey,
  }) {
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        child: Ink(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: theme.primaryColor),
                ),
                const SizedBox(height: 6),
                Text(
                  label.trim().isEmpty ? '照護設備' : label.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageCard(String imageUrl) {
    final double height = HomeEnvironmentImageHeights.pixels(
      setting.imageHeight,
    );
    final Alignment alignment = _imageAlignment();
    final String textPosition =
        displayStyle?.textPosition ??
        (setting.imageTextPlacement == HomeEnvironmentTextPlacements.below
            ? HomeDisplayTextPositions.below
            : HomeDisplayTextPositions.overlay);
    final bool overlay = textPosition == HomeDisplayTextPositions.overlay;
    final bool above = textPosition == HomeDisplayTextPositions.above;
    final double radius = displayStyle == null
        ? 14
        : HomeDisplayRadii.pixels(displayStyle!.cardRadius);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(radius),
      elevation: displayStyle?.cardShadow == HomeDisplayShadows.soft ? 1 : 0,
      child: InkWell(
        key: const Key('home-environment-image'),
        borderRadius: BorderRadius.circular(radius),
        onTap: _open,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: displayStyle?.cardBorder == false
                ? null
                : Border.all(color: theme.cardBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: overlay
                ? SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _photo(imageUrl, height, alignment),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x00000000),
                                Color(0xCC000000),
                              ],
                              stops: <double>[0.42, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 8,
                          bottom: 8,
                          child: LayoutBuilder(
                            builder:
                                (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  return FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomLeft,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: _imageCaption(onImage: true),
                                    ),
                                  );
                                },
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (above)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: _imageCaption(onImage: false),
                        ),
                      SizedBox(
                        height: height,
                        width: double.infinity,
                        child: _photo(imageUrl, height, alignment),
                      ),
                      if (!above)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: _imageCaption(onImage: false),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Alignment _imageAlignment() {
    final EnvironmentImageFrameSetting frame =
        EnvironmentImageFrameSetting.heroFromMap(environmentIntro);
    switch (frame.imageAlignment) {
      case EnvironmentImageFrameSetting.alignTop:
        return Alignment.topCenter;
      case EnvironmentImageFrameSetting.alignBottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }

  Widget _photo(String imageUrl, double height, Alignment alignment) {
    final ImageProvider<Object>? provider = imageProvider;
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: height,
        errorBuilder: (_, _, _) => _photoFallback(),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _photoFallback(),
    );
  }

  Widget _photoFallback() {
    return ColoredBox(color: theme.primaryColor.withValues(alpha: 0.12));
  }

  Widget _imageCaption({required bool onImage}) {
    final Color titleColor = onImage
        ? Colors.white
        : displayStyle == null
        ? theme.textColor
        : Color(displayStyle!.titleColor);
    final Color subtitleColor = onImage
        ? Colors.white.withValues(alpha: 0.92)
        : displayStyle == null
        ? theme.secondaryTextColor
        : Color(displayStyle!.effectiveBodyColor);
    final Color hintColor = onImage ? Colors.white : theme.primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_showCardTitle)
          Text(
            setting.entryTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: homeDisplayFontSize(
                displayStyle?.titleSize ?? HomeDisplaySizes.medium,
                fallback: 16,
              ),
              height: 1.2,
              fontWeight: homeDisplayFontWeight(
                displayStyle?.titleWeight ?? HomeDisplayWeights.bold,
              ),
              color: titleColor,
            ),
          ),
        if (_showCardSubtitle) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            setting.cardSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: homeDisplayFontSize(
                displayStyle?.bodySize ?? HomeDisplaySizes.small,
                fallback: 12,
              ),
              height: 1.2,
              fontWeight: homeDisplayFontWeight(
                displayStyle?.bodyWeight ?? HomeDisplayWeights.medium,
              ),
              color: subtitleColor,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                '查看環境',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: hintColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: hintColor),
          ],
        ),
      ],
    );
  }
}
