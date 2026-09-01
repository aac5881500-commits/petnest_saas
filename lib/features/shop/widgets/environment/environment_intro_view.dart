// lib/features/shop/widgets/environment/environment_intro_view.dart
// 🐾 環境介紹前台 Renderer：預覽與正式頁共用，避免兩套排版。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_bottom_note.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_care_item.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_card.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_grid.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_hero_section.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_image_banner.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_section_title.dart';

class EnvironmentIntroView extends StatelessWidget {
  const EnvironmentIntroView({
    super.key,
    required this.style,
    required this.theme,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroImageUrl,
    required this.heroFrame,
    required this.bannerTitle,
    required this.bannerImageUrl,
    required this.bannerFrame,
    required this.features,
    required this.galleryImages,
    required this.careItems,
    required this.bottomNote,
    required this.imageBuilder,
    required this.featureIconOf,
  });

  final EnvironmentIntroStyle style;
  final HomeThemeModel theme;
  final String heroTitle;
  final String heroSubtitle;
  final String heroImageUrl;
  final EnvironmentImageFrameSetting heroFrame;
  final String bannerTitle;
  final String bannerImageUrl;
  final EnvironmentImageFrameSetting bannerFrame;
  final List<Map<String, dynamic>> features;
  final List<String> galleryImages;
  final List<Map<String, dynamic>> careItems;
  final String bottomNote;
  final Widget Function({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit,
  })
  imageBuilder;
  final IconData Function(String key) featureIconOf;

  bool get _showHero =>
      heroImageUrl.trim().isNotEmpty ||
      heroTitle.trim().isNotEmpty ||
      heroSubtitle.trim().isNotEmpty;

  bool get _showBanner =>
      bannerImageUrl.trim().isNotEmpty || bannerTitle.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: style.sectionGap + 8),
      children: <Widget>[
        if (_showHero)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return EnvironmentHeroSection(
                imageUrl: heroImageUrl,
                title: heroTitle,
                subtitle: heroSubtitle,
                height:
                    heroFrame.heightForWidth(constraints.maxWidth) *
                    style.heroHeightScale,
                imageFit: heroFrame.boxFit,
                imageAlignment: heroFrame.alignment,
                titleSize: style.heroTitleSize,
                subtitleSize: style.heroSubtitleSize,
                radius: style.heroRadius,
                horizontalMargin: style.pagePadding,
                imageBuilder: imageBuilder,
              );
            },
          ),
        if (features.isNotEmpty) ...<Widget>[
          SizedBox(height: style.sectionGap),
          EnvironmentSectionTitle(
            icon: Icons.pets,
            title: '我們的環境特色',
            theme: theme,
            fontSize: style.sectionTitleSize,
            iconSize: style.sectionIconSize,
            horizontalPadding: style.pagePadding,
          ),
          SizedBox(height: style.itemGap),
          ...features.map((Map<String, dynamic> item) {
            return EnvironmentFeatureCard(
              icon: featureIconOf((item['icon'] ?? '').toString()),
              title: (item['title'] ?? '').toString(),
              description: (item['description'] ?? '').toString(),
              imageUrl: (item['imageUrl'] ?? '').toString(),
              imageBuilder: imageBuilder,
              theme: theme,
              style: style,
              reverse: item['layout'] == 'imageLeft',
            );
          }),
        ],
        if (_showBanner) ...<Widget>[
          SizedBox(height: style.sectionGap),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return EnvironmentImageBanner(
                imageUrl: bannerImageUrl,
                title: bannerTitle,
                height:
                    bannerFrame.heightForWidth(constraints.maxWidth) *
                    style.bannerHeightScale,
                imageFit: bannerFrame.boxFit,
                imageAlignment: bannerFrame.alignment,
                titleSize: style.bannerTitleSize,
                radius: style.cardRadius,
                horizontalMargin: style.pagePadding,
                imageBuilder: imageBuilder,
              );
            },
          ),
        ],
        if (careItems.isNotEmpty) ...<Widget>[
          SizedBox(height: style.sectionGap),
          EnvironmentSectionTitle(
            icon: Icons.verified_user_rounded,
            title: '安心照護設備',
            theme: theme,
            fontSize: style.sectionTitleSize,
            iconSize: style.sectionIconSize,
            horizontalPadding: style.pagePadding,
          ),
          SizedBox(height: style.itemGap),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: style.pagePadding),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int cols = style.careColumns(constraints.maxWidth);
                final double gap = style.careSpacing;
                final double itemWidth =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: careItems.map((Map<String, dynamic> item) {
                    return SizedBox(
                      width: itemWidth,
                      child: EnvironmentCareItem(
                        icon: item['icon'] as IconData,
                        title: (item['title'] ?? '').toString(),
                        subtitle: (item['description'] ?? '').toString(),
                        theme: theme,
                        titleSize: style.careTitleSize,
                        subtitleSize: style.careDescriptionSize,
                        iconSize: style.careIconSize,
                        padding: style.carePadding,
                        avatarRadius: style.careAvatarRadius,
                        radius: style.cardRadius - 2,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
        if (bottomNote.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: style.sectionGap),
          EnvironmentBottomNote(
            text: bottomNote,
            theme: theme,
            fontSize: style.bottomNoteSize,
            padding: style.bottomNotePadding,
            horizontalMargin: style.pagePadding,
          ),
        ],
        if (galleryImages.isNotEmpty) ...<Widget>[
          SizedBox(height: style.sectionGap),
          EnvironmentSectionTitle(
            icon: Icons.photo_library_rounded,
            title: '環境照片',
            theme: theme,
            fontSize: style.sectionTitleSize,
            iconSize: style.sectionIconSize,
            horizontalPadding: style.pagePadding,
          ),
          SizedBox(height: style.itemGap),
          EnvironmentGalleryGrid(
            images: galleryImages,
            imageBuilder: imageBuilder,
            horizontalPadding: style.pagePadding,
            spacing: style.gallerySpacing,
            columnsBuilder: style.galleryColumns,
          ),
        ],
      ],
    );
  }
}
