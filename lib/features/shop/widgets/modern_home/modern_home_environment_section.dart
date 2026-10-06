import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
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
  });

  final HomeThemeModel theme;
  final HomeEnvironmentSectionSetting setting;
  final Map<String, dynamic> environmentIntro;
  final List<String> facilityKeys;
  final bool preview;
  final VoidCallback onOpen;
  final ImageProvider<Object>? imageProvider;

  static List<Map<String, dynamic>> facilitiesFor(List<String> keys) {
    return environmentFacilityOptions.where((Map<String, dynamic> item) {
      final String key = (item['key'] ?? '').toString();
      return key.isNotEmpty && keys.contains(key);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> facilities = facilitiesFor(facilityKeys);
    switch (setting.layout) {
      case HomeEnvironmentLayouts.simpleEntry:
        return _entry();
      case HomeEnvironmentLayouts.imageEntry:
        final String imageUrl = HomeEnvironmentSectionSetting.resolveImageUrl(
          environmentIntro,
        );
        if (imageUrl.isEmpty && imageProvider == null) {
          return _entry();
        }
        return _imageCard(imageUrl);
      case HomeEnvironmentLayouts.editorial:
        final String editorialUrl =
            HomeEnvironmentSectionSetting.resolveImageUrl(environmentIntro);
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
      child: _photo(imageUrl, 168, Alignment.center),
    );
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          setting.entryTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: theme.textColor,
          ),
        ),
        if (setting.showSubtitle &&
            setting.subtitle.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            setting.subtitle.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: theme.secondaryTextColor,
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
              Expanded(flex: 3, child: photo),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: copy),
            ],
          );
        },
      ),
    );
  }

  Widget _entry() {
    return ModernHomeEntryCard(
      cardKey: const Key('home-environment-entry'),
      theme: theme,
      title: setting.entryTitle,
      subtitle: setting.subtitle,
      showSubtitle: setting.showSubtitle,
      cardSize: setting.simpleCardSize,
      surface: setting.simpleSurface,
      icon: _icon,
      actionLabel: '查看環境介紹',
      onTap: _open,
    );
  }

  Widget _facilityScroll(List<Map<String, dynamic>> facilities) {
    final int extra = setting.showEndEntryCard ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (setting.showTitle) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.yard_outlined, size: 16, color: theme.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  setting.facilityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 320;
            final double cardWidth = (maxWidth * 0.28).clamp(78.0, 108.0);
            final double textScale = MediaQuery.textScalerOf(context).scale(1);
            final double height = 58 + 28 * textScale;
            return SizedBox(
              height: height,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
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
                    key: const Key('home-environment-scroll'),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    primary: false,
                    itemCount: facilities.length + extra,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= facilities.length) {
                        return _facilityCard(
                          width: cardWidth,
                          icon: Icons.keyboard_double_arrow_right_rounded,
                          label: '環境介紹',
                          cardKey: const Key('home-environment-end'),
                        );
                      }
                      final Map<String, dynamic> facility = facilities[index];
                      final IconData icon = facility['icon'] is IconData
                          ? facility['icon'] as IconData
                          : Icons.pets_outlined;
                      return _facilityCard(
                        width: cardWidth,
                        icon: icon,
                        label: (facility['title'] ?? '照護設備').toString(),
                        cardKey: Key('home-environment-facility-$index'),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
    final bool overlay =
        setting.imageTextPlacement == HomeEnvironmentTextPlacements.overlay;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home-environment-image'),
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorderColor),
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
                      SizedBox(
                        height: height,
                        width: double.infinity,
                        child: _photo(imageUrl, height, alignment),
                      ),
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
    final Color titleColor = onImage ? Colors.white : theme.textColor;
    final Color subtitleColor = onImage
        ? Colors.white.withValues(alpha: 0.92)
        : theme.secondaryTextColor;
    final Color hintColor = onImage ? Colors.white : theme.primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          setting.entryTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        if (setting.showSubtitle) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            setting.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.2, color: subtitleColor),
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
