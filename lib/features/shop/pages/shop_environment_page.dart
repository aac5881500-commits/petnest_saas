// lib/features/shop/pages/shop_environment_page.dart
// 🐾 前台環境介紹頁
// 顯示店家環境介紹、安心設備、環境照片牆
// 第一版先用固定模板 + 假資料，之後再接後台設定與 Firestore

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_hero_section.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_feature_card.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_care_item.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_gallery_grid.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_image_banner.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_bottom_note.dart';
import 'package:petnest_saas/features/shop/widgets/environment/environment_section_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


const String _environmentHeroImageUrl =
    'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=1200';

const String _environmentBannerImageUrl =
    'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=1000';

const String _environmentHeroTitle = '讓每一隻貓咪\n都能像在家一樣放鬆';

const String _environmentHeroSubtitle = '安心・舒適・乾淨的貓咪住宿空間';

const String _environmentBannerTitle = '用心打造每一個細節\n只為給貓咪更好的住宿體驗';

const String _environmentBottomNote =
    '每隻貓咪個性不同，實際住宿安排會依照貓咪狀況與店家現場評估調整。';

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

const List<Map<String, String>> _environmentCareItems = [
  {
    'icon': 'air',
    'title': '空氣清淨',
    'subtitle': '維持空氣流通',
  },
  {
    'icon': 'camera',
    'title': '監視設備',
    'subtitle': '住宿更安心',
  },
  {
    'icon': 'hospital',
    'title': '緊急送醫',
    'subtitle': '即時協助',
  },
  {
    'icon': 'water',
    'title': '飲水設備',
    'subtitle': '補充水分',
  },
  {
    'icon': 'sun',
    'title': '日照空間',
    'subtitle': '舒適放鬆',
  },
  {
    'icon': 'clean_hand',
    'title': '定期消毒',
    'subtitle': '乾淨衛生',
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

class ShopEnvironmentPage extends StatelessWidget {
  const ShopEnvironmentPage({
  super.key,
  required this.shopId,
  this.heroTitle,
  this.heroSubtitle,
  this.bannerTitle,
  this.bottomNote,
});

  final String shopId;
  final String? heroTitle;
final String? heroSubtitle;
final String? bannerTitle;
final String? bottomNote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '環境介紹',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF3A2A1A),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .snapshots(),
  builder: (context, snapshot) {
    final shopData = snapshot.data?.data() as Map<String, dynamic>?;

    final environmentIntro =
        shopData?['environmentIntro'] as Map<String, dynamic>?;

    final displayHeroTitle =
        heroTitle ?? environmentIntro?['heroTitle'] ?? _environmentHeroTitle;

    final displayHeroSubtitle =
        heroSubtitle ?? environmentIntro?['heroSubtitle'] ?? _environmentHeroSubtitle;

    final displayBannerTitle =
        bannerTitle ?? environmentIntro?['bannerTitle'] ?? _environmentBannerTitle;

    final displayBottomNote =
        bottomNote ?? environmentIntro?['bottomNote'] ?? _environmentBottomNote;
            final displayGalleryImages =
        List<String>.from(environmentIntro?['galleryImages'] ?? _environmentGalleryImages);
            final displayHeroImageUrl =
        environmentIntro?['heroImageUrl'] ?? _environmentHeroImageUrl;

    final displayBannerImageUrl =
        environmentIntro?['bannerImageUrl'] ?? _environmentBannerImageUrl;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
         EnvironmentHeroSection(
  imageUrl: displayHeroImageUrl,
  title: displayHeroTitle,
  subtitle: displayHeroSubtitle,
  imageBuilder: _networkImage,
),

          const SizedBox(height: 22),
EnvironmentSectionTitle(
  icon: Icons.pets,
  title: '我們的環境特色',
),
          const SizedBox(height: 12),

         ..._environmentFeatures.map((item) {
  return EnvironmentFeatureCard(
  icon: _environmentIcon(item['icon'] ?? ''),
  title: item['title'] ?? '',
  description: item['description'] ?? '',
  imageUrl: item['imageUrl'] ?? '',
  imageBuilder: _networkImage,
);
}),

          const SizedBox(height: 18),

          EnvironmentSectionTitle(
            icon: Icons.verified_user_rounded,
            title: '安心照護設備',
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.88,
             children: _environmentCareItems.map((item) {
  return EnvironmentCareItem(
  icon: _environmentIcon(item['icon'] ?? ''),
  title: item['title'] ?? '',
  subtitle: item['subtitle'] ?? '',
);
}).toList(),
            ),
          ),

          const SizedBox(height: 24),

          EnvironmentImageBanner(
  imageUrl: displayBannerImageUrl,
  title: displayBannerTitle,
  imageBuilder: _networkImage,
),

          const SizedBox(height: 24),

          EnvironmentSectionTitle(
            icon: Icons.photo_library_rounded,
            title: '環境照片',
          ),

          const SizedBox(height: 12),

          EnvironmentGalleryGrid(
  images: displayGalleryImages,
  imageBuilder: _networkImage,
),

const SizedBox(height: 24),

EnvironmentBottomNote(
  text: displayBottomNote,
),
                ],
      );
    },
  ),
);
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
    default:
      return Icons.pets_rounded;
  }
}
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
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;

      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF5EBDD),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
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

