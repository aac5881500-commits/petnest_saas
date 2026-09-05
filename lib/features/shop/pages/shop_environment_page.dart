// 檔案名稱：lib/features/shop/pages/shop_environment_page.dart
// 功能說明：前台環境介紹頁
// 顯示店家環境介紹、安心設備、環境照片牆

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_image_frame_setting.dart';
import 'package:petnest_saas/core/models/environment_intro_style.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/data/environment_facility_options.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_intro_view.dart';

const String _environmentHeroImageUrl =
    'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=1200';

const String _environmentBannerImageUrl =
    'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=1000';

const String _environmentHeroTitle = '讓每一隻貓咪\n都能像在家一樣放鬆';

const String _environmentHeroSubtitle = '安心・舒適・乾淨的貓咪住宿空間';

const String _environmentBannerTitle = '用心打造每一個細節\n只為給貓咪更好的住宿體驗';

const String _environmentBottomNote = '每隻貓咪個性不同，實際住宿安排會依照貓咪狀況與店家現場評估調整。';

const List<Map<String, String>> _environmentFeatures = [
  {
    'icon': 'home',
    'title': '獨立住宿空間',
    'description': '每間房皆為獨立空間，降低貓咪壓力，提供安靜舒適的休息環境。',
    'imageUrl':
        'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=800',
  },
  {
    'icon': 'clean',
    'title': '每日清潔消毒',
    'description': '每日定時清潔與消毒，維持環境乾淨，也讓貓咪住得更安心。',
    'imageUrl':
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800',
  },
  {
    'icon': 'air',
    'title': '24 小時冷氣空調',
    'description': '全館恆溫控制，讓貓咪在炎熱或潮濕天氣中也能舒適休息。',
    'imageUrl':
        'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=800',
  },
];

const List<String> _environmentGalleryImages = [
  'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
  'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=600',
  'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=600',
  'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=600',
  'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=600',
  'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=600',
];

const List<String> _defaultFacilityKeys = <String>[
  'air_cleaner',
  'camera_24h',
  'hospital',
  'water',
  'sunlight',
  'disinfect',
];

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
    this.facilityKeys,
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
  final List<String>? facilityKeys;

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
            final bool hasSavedIntro = environmentIntro != null;

            final EnvironmentIntroStyle resolvedStyle =
                style ?? EnvironmentIntroStyle.fromMap(environmentIntro);

            final String displayHeroTitle =
                heroTitle ??
                (hasSavedIntro
                    ? (environmentIntro['heroTitle'] ?? '').toString()
                    : _environmentHeroTitle);

            final String displayHeroSubtitle =
                heroSubtitle ??
                (hasSavedIntro
                    ? (environmentIntro['heroSubtitle'] ?? '').toString()
                    : _environmentHeroSubtitle);

            final String displayBannerTitle =
                bannerTitle ??
                (hasSavedIntro
                    ? (environmentIntro['bannerTitle'] ?? '').toString()
                    : _environmentBannerTitle);

            final String displayBottomNote =
                bottomNote ??
                (hasSavedIntro
                    ? (environmentIntro['bottomNote'] ?? '').toString()
                    : _environmentBottomNote);

            final List<Map<String, dynamic>> displayFeatures =
                features ??
                List<Map<String, dynamic>>.from(
                  environmentIntro?['features'] ??
                      (hasSavedIntro
                          ? const <Map<String, dynamic>>[]
                          : _environmentFeatures),
                );

            final List<String> displayGalleryImages =
                galleryImages ??
                _readGalleryImageUrls(
                  environmentIntro?['galleryImages'] ??
                      (hasSavedIntro
                          ? const <String>[]
                          : _environmentGalleryImages),
                );

            final List<String> selectedFacilityKeys =
                facilityKeys ??
                List<String>.from(
                  environmentIntro?['facilityKeys'] ??
                      (hasSavedIntro ? const <String>[] : _defaultFacilityKeys),
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
                (hasSavedIntro
                        ? (environmentIntro['heroImageUrl'] ?? '')
                        : _environmentHeroImageUrl)
                    .toString();

            final String displayBannerImageUrl =
                bannerImageUrl ??
                (hasSavedIntro
                        ? (environmentIntro['bannerImageUrl'] ?? '')
                        : _environmentBannerImageUrl)
                    .toString();

            final EnvironmentImageFrameSetting resolvedHeroFrame =
                heroFrame ??
                EnvironmentImageFrameSetting.heroFromMap(environmentIntro);
            final EnvironmentImageFrameSetting resolvedBannerFrame =
                bannerFrame ??
                EnvironmentImageFrameSetting.bannerFromMap(environmentIntro);

            return Scaffold(
              backgroundColor: theme.backgroundColor,
              appBar: AppBar(
                backgroundColor: theme.backgroundColor,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                title: Text(
                  '環境介紹',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: resolvedStyle.pageTitleSize,
                    color: theme.textColor,
                  ),
                ),
              ),
              body: EnvironmentIntroView(
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
                careItems: displayCareItems,
                bottomNote: displayBottomNote,
                imageBuilder: _networkImage,
                featureIconOf: _environmentIcon,
              ),
            );
          },
    );
  }
}

IconData _environmentIcon(String key) {
  switch (key) {
    case 'home':
      return Icons.home_rounded;
    case 'clean':
      return Icons.cleaning_services_rounded;
    case 'air':
      return Icons.ac_unit_rounded;
    case 'camera':
      return Icons.videocam_rounded;
    case 'hospital':
      return Icons.local_hospital_rounded;
    case 'water':
      return Icons.water_drop_rounded;
    case 'sun':
      return Icons.wb_sunny_rounded;
    case 'clean_hand':
      return Icons.clean_hands_rounded;
    case 'pets':
      return Icons.pets_rounded;
    case 'toys':
      return Icons.toys_rounded;
    default:
      return Icons.pets_rounded;
  }
}

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

Widget _networkImage({
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
