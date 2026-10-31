// 檔案名稱：lib/features/shop/widgets/environment/environment_intro_view.dart
// 功能說明：環境介紹前台 Renderer：預覽與正式頁共用，避免兩套排版。

import 'package:flutter/material.dart';
import 'environment_appearance_surface.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'environment_service_section.dart';
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
    this.scrollController,
    this.presentation,
    this.sectionKeys,
    this.emptyState,
    this.galleryCaptions = const [],
  });

  /// Editor-only guidance; customer pages keep their existing empty behavior.
  final Widget? emptyState;
  final EnvironmentPresentation? presentation;
  final Map<String, GlobalKey>? sectionKeys;
  final EnvironmentIntroStyle style;
  final ScrollController? scrollController;
  final HomeThemeModel theme;
  final String heroTitle;
  final String heroSubtitle;
  final String heroImageUrl;
  final EnvironmentImageFrameSetting heroFrame;
  final String bannerTitle;
  final String bannerImageUrl;
  final EnvironmentImageFrameSetting bannerFrame;
  final List<Map<String, dynamic>> features;
  final List<String> galleryImages, galleryCaptions;
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
    final p = presentation ?? EnvironmentPresentation();
    return EnvironmentAppearanceSurface(
      appearance: p.appearance,
      baseTheme: theme,
      actionTextSize: style.bottomNoteSize,
      contentBuilder: (context, theme) {
        final modern =
            p.groupedFacilities ||
            p.preset.isNotEmpty ||
            p.equipmentLayout != 'legacy' ||
            p.serviceLayout != 'legacy' ||
            p.services.isNotEmpty ||
            p.hiddenFacilityKeys.isNotEmpty ||
            p.facilityOrder.isNotEmpty;
        final sections = <String, List<Widget>>{
          'hero': [
            if (_showHero)
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return EnvironmentHeroSection(
                    imageUrl: heroImageUrl,
                    title: heroTitle,
                    subtitle: heroSubtitle,
                    height: p.photoHeight(
                      'hero',
                      constraints.maxWidth,
                      heroFrame.heightForWidth(constraints.maxWidth) *
                          style.heroHeightScale,
                    ),
                    imageFit: p.photoFit(
                      'hero',
                      constraints.maxWidth,
                      heroFrame.boxFit,
                    ),
                    imageAlignment: p.photoAlignment(
                      'hero',
                      constraints.maxWidth,
                      heroFrame.alignment,
                    ),
                    titleSize: style.heroTitleSize,
                    subtitleSize: style.heroSubtitleSize,
                    radius: style.heroRadius,
                    horizontalMargin: style.pagePadding,
                    imageBuilder: imageBuilder,
                    titleColor: p.appearance.color('textColor'),
                    subtitleColor: p.appearance.color('secondaryTextColor'),
                  );
                },
              ),
          ],
          'features': [
            if (features.isNotEmpty) ...<Widget>[
              EnvironmentSectionTitle(
                icon: Icons.pets,
                title: p.sectionTitle('features', '我們的環境特色'),
                theme: theme,
                fontSize: style.sectionTitleSize,
                iconSize: style.sectionIconSize,
                horizontalPadding: style.pagePadding,
              ),
              SizedBox(height: style.itemGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 800;
                  final featureStyle =
                      desktop && p.desktopCardLayout != 'inherit'
                      ? style.copyWith(cardLayout: p.desktopCardLayout)
                      : style;
                  final columns =
                      desktop &&
                          p.desktopColumns != 'single' &&
                          (p.desktopColumns == 'double' ||
                              featureStyle.isVerticalCard)
                      ? 2
                      : 1;
                  Widget card(int index) {
                    final item = features[index];
                    return EnvironmentFeatureCard(
                      icon: featureIconOf((item['icon'] ?? '').toString()),
                      title: (item['title'] ?? '').toString(),
                      description: (item['description'] ?? '').toString(),
                      imageUrl: (item['imageUrl'] ?? '').toString(),
                      imageBuilder: imageBuilder,
                      theme: theme,
                      style: featureStyle,
                      maxImageHeight: p.featureImageMaxHeight,
                      reverse: p.preset == 'warm'
                          ? index.isOdd
                          : item['layout'] == 'imageLeft',
                      minimal: p.preset == 'minimal',
                    );
                  }

                  return Column(
                    children: [
                      for (
                        var start = 0;
                        start < features.length;
                        start += columns
                      )
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var i = start;
                              i < start + columns && i < features.length;
                              i++
                            )
                              Expanded(child: card(i)),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
          'banner': [
            if (_showBanner) ...<Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return EnvironmentImageBanner(
                    imageUrl: bannerImageUrl,
                    title: bannerTitle,
                    height: p.photoHeight(
                      'banner',
                      constraints.maxWidth,
                      bannerFrame.heightForWidth(constraints.maxWidth) *
                          style.bannerHeightScale,
                    ),
                    imageFit: p.photoFit(
                      'banner',
                      constraints.maxWidth,
                      bannerFrame.boxFit,
                    ),
                    imageAlignment: p.photoAlignment(
                      'banner',
                      constraints.maxWidth,
                      bannerFrame.alignment,
                    ),
                    titleSize: style.bannerTitleSize,
                    radius: style.cardRadius,
                    horizontalMargin: style.pagePadding,
                    imageBuilder: imageBuilder,
                    titleColor: p.appearance.color('textColor'),
                  );
                },
              ),
            ],
          ],
          'care': [
            if (!modern && careItems.isNotEmpty) ...<Widget>[
              EnvironmentSectionTitle(
                icon: Icons.verified_user_rounded,
                title: p.sectionTitle('care', '安心照護設備'),
                theme: theme,
                fontSize: style.sectionTitleSize,
                iconSize: style.sectionIconSize,
                horizontalPadding: style.pagePadding,
              ),
              SizedBox(height: style.itemGap),
              EnvironmentLegacyCareGrid(
                items: careItems,
                theme: theme,
                style: style,
              ),
            ],

            if (modern &&
                (careItems.any(
                      (item) => !p.hiddenFacilityKeys.contains(item['key']),
                    ) ||
                    p.services.any((s) => s.visible))) ...[
              EnvironmentServiceSection(
                presentation: p,
                items: careItems,
                theme: theme,
                style: style,
                iconOf: featureIconOf,
                imageBuilder: imageBuilder,
              ),
            ],
          ],
          'note': [
            if (bottomNote.trim().isNotEmpty) ...<Widget>[
              EnvironmentBottomNote(
                text: bottomNote,
                theme: theme,
                fontSize: style.bottomNoteSize,
                padding: style.bottomNotePadding,
                horizontalMargin: style.pagePadding,
              ),
            ],
          ],
          'gallery': [
            if (galleryImages.isNotEmpty) ...<Widget>[
              EnvironmentSectionTitle(
                icon: Icons.photo_library_rounded,
                title: p.sectionTitle('gallery', '環境照片'),
                theme: theme,
                fontSize: style.sectionTitleSize,
                iconSize: style.sectionIconSize,
                horizontalPadding: style.pagePadding,
              ),
              SizedBox(height: style.itemGap),
              EnvironmentGalleryGrid(
                images: galleryImages,
                captions: galleryCaptions,
                layout: p.galleryLayout,
                imageBuilder: imageBuilder,
                horizontalPadding: style.pagePadding,
                spacing: style.gallerySpacing,
                columnsBuilder: style.galleryColumns,
              ),
            ],
          ],
        };
        if (sections.entries
                .where((entry) => !p.hiddenSections.contains(entry.key))
                .every((entry) => entry.value.isEmpty) &&
            emptyState != null) {
          return emptyState!;
        }
        final order = p.sectionOrder.where(
          (id) => !p.hiddenSections.contains(id),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: p.contentMaxWidth),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(bottom: style.sectionGap + 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final id in order)
                    if (sections[id]!.isNotEmpty)
                      Column(
                        key: sectionKeys?[id] ?? ValueKey('environment-$id'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: p.sectionGap(
                              id,
                              id == 'hero' ? 0 : style.sectionGap,
                            ),
                          ),
                          ...sections[id]!,
                        ],
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
