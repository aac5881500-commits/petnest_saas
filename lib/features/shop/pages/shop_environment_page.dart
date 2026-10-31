import '../data/environment_feature_icons.dart';
import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
// 檔案名稱：lib/features/shop/pages/shop_environment_page.dart
// 功能說明：前台環境介紹頁
// 顯示店家環境介紹、安心設備、環境照片牆

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_intro_view.dart';

class ShopEnvironmentPage extends StatelessWidget {
  const ShopEnvironmentPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.classicDefault,
    this.heroTitle,
    this.heroSubtitle,
    this.bannerTitle,
    this.bottomNote,
    this.heroImageUrl,
    this.bannerImageUrl,
    this.heroFrame,
    this.bannerFrame,
    this.style,
    this.features,
    this.galleryImages,
    this.galleryCaptions,
    this.facilityKeys,
    this.presentation,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String? heroTitle;
  final String? heroSubtitle;
  final String? bannerTitle;
  final String? bottomNote;
  final String? heroImageUrl;
  final String? bannerImageUrl;
  final EnvironmentImageFrameSetting? heroFrame;
  final EnvironmentImageFrameSetting? bannerFrame;
  final EnvironmentIntroStyle? style;
  final List<Map<String, dynamic>>? features;
  final List<String>? galleryImages;
  final List<String>? galleryCaptions;
  final List<String>? facilityKeys;
  final EnvironmentPresentation? presentation;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .snapshots(),
      builder:
          (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            final Map<String, dynamic>? shopData =
                snapshot.data?.data() as Map<String, dynamic>?;
            final Map<String, dynamic>? environmentIntro =
                shopData?['environmentIntro'] as Map<String, dynamic>?;
            if (snapshot.hasError) {
              return const Scaffold(body: Center(child: Text('環境介紹暫時無法載入')));
            }
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final hasPreview =
                heroTitle != null ||
                features != null ||
                galleryImages != null ||
                presentation != null;
            if (!hasPreview && !ShopIntroContent.environment(shopData ?? {})) {
              return const Scaffold(body: SizedBox.shrink());
            }
            final bool hasSavedIntro = environmentIntro != null;

            final EnvironmentIntroStyle resolvedStyle =
                style ?? EnvironmentIntroStyle.fromMap(environmentIntro);

            final String displayHeroTitle =
                heroTitle ??
                (hasSavedIntro
                    ? (environmentIntro['heroTitle'] ?? '').toString()
                    : '');

            final String displayHeroSubtitle =
                heroSubtitle ??
                (hasSavedIntro
                    ? (environmentIntro['heroSubtitle'] ?? '').toString()
                    : '');

            final String displayBannerTitle =
                bannerTitle ??
                (hasSavedIntro
                    ? (environmentIntro['bannerTitle'] ?? '').toString()
                    : '');

            final String displayBottomNote =
                bottomNote ??
                (hasSavedIntro
                    ? (environmentIntro['bottomNote'] ?? '').toString()
                    : '');

            final List<Map<String, dynamic>> displayFeatures =
                features ??
                List<Map<String, dynamic>>.from(
                  environmentIntro?['features'] ??
                      (hasSavedIntro
                          ? const <Map<String, dynamic>>[]
                          : const <Map<String, dynamic>>[]),
                );

            final List<String> displayGalleryImages =
                galleryImages ??
                _readGalleryImageUrls(
                  environmentIntro?['galleryImages'] ??
                      (hasSavedIntro ? const <String>[] : const <String>[]),
                );

            final List<String> selectedFacilityKeys =
                facilityKeys ??
                List<String>.from(
                  environmentIntro?['facilityKeys'] ??
                      (hasSavedIntro ? const <String>[] : const <String>[]),
                );

            final List<Map<String, dynamic>> displayCareItems =
                environmentFacilityOptions
                    .where(
                      (Map<String, dynamic> item) =>
                          selectedFacilityKeys.contains(item['key']),
                    )
                    .toList();

            final String displayHeroImageUrl =
                heroImageUrl ??
                (hasSavedIntro ? (environmentIntro['heroImageUrl'] ?? '') : '')
                    .toString();

            final String displayBannerImageUrl =
                bannerImageUrl ??
                (hasSavedIntro
                        ? (environmentIntro['bannerImageUrl'] ?? '')
                        : '')
                    .toString();

            final EnvironmentImageFrameSetting resolvedHeroFrame =
                heroFrame ??
                EnvironmentImageFrameSetting.heroFromMap(environmentIntro);
            final EnvironmentImageFrameSetting resolvedBannerFrame =
                bannerFrame ??
                EnvironmentImageFrameSetting.bannerFromMap(environmentIntro);

            final resolvedPresentation =
                presentation ??
                EnvironmentPresentation.fromMap(
                  environmentIntro?['environmentPresentation'],
                );
            final pageTheme = resolvedPresentation.appearance.resolve(theme);
            return Scaffold(
              backgroundColor: pageTheme.backgroundColor,
              appBar: AppBar(
                backgroundColor: pageTheme.backgroundColor,
                foregroundColor: resolvedPresentation.appearance.hasColors
                    ? pageTheme.primaryColor
                    : null,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                title: Text(
                  '環境介紹',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: resolvedStyle.pageTitleSize,
                    color: pageTheme.textColor,
                    fontFamily: resolvedPresentation.appearance.fontFamily,
                  ),
                ),
              ),
              body: EnvironmentIntroView(
                presentation: resolvedPresentation,
                style: resolvedStyle,
                theme: theme,
                heroTitle: displayHeroTitle,
                heroSubtitle: displayHeroSubtitle,
                heroImageUrl: displayHeroImageUrl,
                heroFrame: resolvedHeroFrame,
                bannerTitle: displayBannerTitle,
                bannerImageUrl: displayBannerImageUrl,
                bannerFrame: resolvedBannerFrame,
                features: displayFeatures,
                galleryImages: displayGalleryImages,
                galleryCaptions:
                    galleryCaptions ??
                    displayGalleryImages.map((url) {
                      final raw = environmentIntro?['galleryImages'];
                      if (raw is! List) return '';
                      final matches = raw.whereType<Map>().where(
                        (item) => item['imageUrl']?.toString().trim() == url,
                      );
                      return matches.isEmpty
                          ? ''
                          : (matches.first['caption'] ?? '').toString();
                    }).toList(),
                careItems: displayCareItems,
                bottomNote: displayBottomNote,
                imageBuilder: environmentIntroNetworkImage,
                featureIconOf: environmentIntroIcon,
              ),
            );
          },
    );
  }
}

IconData environmentIntroIcon(String key) => environmentFeatureIcon(key);

List<String> _readGalleryImageUrls(dynamic raw) {
  if (raw is! List) {
    return <String>[];
  }

  final List<String> urls = <String>[];
  for (final Object? item in raw) {
    if (item is String && item.trim().isNotEmpty) {
      urls.add(item.trim());
      continue;
    }
    if (item is Map) {
      final String imageUrl = (item['imageUrl'] ?? '').toString().trim();
      if (imageUrl.isNotEmpty) {
        urls.add(imageUrl);
      }
    }
  }
  return urls;
}

Widget environmentIntroNetworkImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder:
        (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF5EBDD),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF5EBDD),
        child: const Icon(
          Icons.image_not_supported_rounded,
          color: Color(0xFFB87535),
        ),
      );
    },
  );
}
