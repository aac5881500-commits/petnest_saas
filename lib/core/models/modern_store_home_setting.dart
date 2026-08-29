// lib/core/models/modern_store_home_setting.dart
// 🛒 新版 Beta 首頁賣場區塊外觀設定
// 功能：掛在既有 homeAppearance.modern 底下，不另開一套主題色。

class ModernStoreHomeSetting {
  static const String defaultFeaturedTitle = '精選商品';
  static const String defaultBannerTitle = '寵物賣場';
  static const String defaultBannerSubtitle = '精選毛孩好物，把喜歡帶回家';
  static const String defaultBannerButtonText = '逛逛賣場';

  const ModernStoreHomeSetting({
    this.showFeaturedProducts = true,
    this.featuredTitle = defaultFeaturedTitle,
    this.showStoreBanner = true,
    this.storeBannerTitle = defaultBannerTitle,
    this.storeBannerSubtitle = defaultBannerSubtitle,
    this.storeBannerButtonText = defaultBannerButtonText,
    this.storeBannerImageUrl = '',
  });

  final bool showFeaturedProducts;
  final String featuredTitle;
  final bool showStoreBanner;
  final String storeBannerTitle;
  final String storeBannerSubtitle;
  final String storeBannerButtonText;
  final String storeBannerImageUrl;

  factory ModernStoreHomeSetting.fromMap(Map<String, dynamic> map) {
    return ModernStoreHomeSetting(
      showFeaturedProducts: map['showFeaturedStoreProducts'] != false,
      featuredTitle: _textOrDefault(
        map['featuredStoreTitle'],
        defaultFeaturedTitle,
      ),
      showStoreBanner: map['showStoreBanner'] != false,
      storeBannerTitle: _textOrDefault(
        map['storeBannerTitle'],
        defaultBannerTitle,
      ),
      storeBannerSubtitle: _textOrDefault(
        map['storeBannerSubtitle'],
        defaultBannerSubtitle,
      ),
      storeBannerButtonText: _textOrDefault(
        map['storeBannerButtonText'],
        defaultBannerButtonText,
      ),
      storeBannerImageUrl: (map['storeBannerImageUrl'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showFeaturedStoreProducts': showFeaturedProducts,
      'featuredStoreTitle': featuredTitle,
      'showStoreBanner': showStoreBanner,
      'storeBannerTitle': storeBannerTitle,
      'storeBannerSubtitle': storeBannerSubtitle,
      'storeBannerButtonText': storeBannerButtonText,
      'storeBannerImageUrl': storeBannerImageUrl,
    };
  }

  static String _textOrDefault(dynamic value, String fallback) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
