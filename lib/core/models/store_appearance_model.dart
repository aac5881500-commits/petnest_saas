// 檔案名稱：lib/core/models/store_appearance_model.dart
// 功能說明：商城獨立外觀與首頁 Banner（存在 store_settings/main）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';

export 'package:petnest_saas/core/models/store_banner_model.dart';

class StoreAppearancePresets {
  static const String system = 'system';
  static const String warmCream = 'warmCream';
  static const String milkTea = 'milkTea';
  static const String blush = 'blush';
  static const String mint = 'mint';
  static const String sky = 'sky';
  static const String grayWhite = 'grayWhite';
  static const String followShop = 'followShop';

  static const List<String> all = <String>[
    system,
    warmCream,
    milkTea,
    blush,
    mint,
    sky,
    grayWhite,
    followShop,
  ];

  static String label(String preset) {
    switch (preset) {
      case warmCream:
        return '暖米色';
      case milkTea:
        return '奶茶色';
      case blush:
        return '淡粉';
      case mint:
        return '淡綠';
      case sky:
        return '淡藍';
      case grayWhite:
        return '灰白';
      case followShop:
        return '跟隨店家主題';
      default:
        return '系統預設';
    }
  }

  static HomeThemeModel themeOf(String preset, HomeThemeModel shopTheme) {
    switch (preset) {
      case warmCream:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFFFF6EC,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFE8D3B8,
          primaryColorValue: 0xFFC47A3A,
          textColorValue: 0xFF3A2A20,
        );
      case milkTea:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFF6EFE6,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFDCC8B0,
          primaryColorValue: 0xFF9B7653,
          textColorValue: 0xFF3A2A20,
        );
      case blush:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFFFF4F5,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFF0C9CF,
          primaryColorValue: 0xFFD77887,
          textColorValue: 0xFF3A2A20,
        );
      case mint:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFF3F8F4,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFC7D9CC,
          primaryColorValue: 0xFF4F7D61,
          textColorValue: 0xFF2A3A30,
        );
      case sky:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFF3F7FB,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFC5D4E2,
          primaryColorValue: 0xFF4A7BA7,
          textColorValue: 0xFF243044,
        );
      case grayWhite:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFF5F5F5,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFE0E0E0,
          primaryColorValue: 0xFF5A5A5A,
          textColorValue: 0xFF2A2A2A,
        );
      case followShop:
        return shopTheme;
      default:
        return const HomeThemeModel(
          backgroundColorValue: 0xFFFFFBF7,
          cardColorValue: 0xFFFFFFFF,
          cardBorderColorValue: 0xFFFFD9B3,
          primaryColorValue: 0xFFFF8A00,
          textColorValue: 0xFF3A2A20,
        );
    }
  }

  static Color swatchOf(String preset) {
    return Color(
      themeOf(preset, HomeThemeModel.modernDefault).primaryColorValue,
    );
  }
}

class StoreHomeDisplaySettings {
  const StoreHomeDisplaySettings({
    this.announcement = '',
    this.showAnnouncement = true,
    this.showBanners = true,
    this.showCategories = true,
    this.showFeaturedProducts = true,
    this.showPromoProducts = true,
    this.appearancePreset = StoreAppearancePresets.system,
    this.banners = const <StoreBannerModel>[],
    this.bannerAutoPlay = true,
    this.bannerAutoPlaySeconds = 5,
    this.hideOutOfStock = false,
    this.showStockToCustomer = true,
    this.featuredCount = 6,
    this.storeName = '',
    this.storeDescription = '',
    this.storeAppearance = const StoreAppearanceSetting(),
  });

  final String announcement;
  final bool showAnnouncement;
  final bool showBanners;
  final bool showCategories;
  final bool showFeaturedProducts;
  final bool showPromoProducts;
  final String appearancePreset;
  final List<StoreBannerModel> banners;
  final bool bannerAutoPlay;
  final int bannerAutoPlaySeconds;
  final bool hideOutOfStock;
  final bool showStockToCustomer;
  final int featuredCount;
  final String storeName;
  final String storeDescription;
  final StoreAppearanceSetting storeAppearance;

  /// 商城名稱：storeName 為 source of truth，storeTitle 僅舊資料 fallback。
  String get resolvedStorefrontTitle {
    if (storeName.trim().isNotEmpty) {
      return storeName.trim();
    }
    if (storeAppearance.storeTitle.trim().isNotEmpty) {
      return storeAppearance.storeTitle.trim();
    }
    return StoreAppearanceSetting.defaultStoreTitle;
  }

  /// 商城副標：storeAppearance.storeSubtitle 為主，storeDescription 為舊資料 fallback。
  String get resolvedStorefrontSubtitle {
    if (storeAppearance.storeSubtitle.trim().isNotEmpty) {
      return storeAppearance.storeSubtitle.trim();
    }
    if (storeDescription.trim().isNotEmpty) {
      return storeDescription.trim();
    }
    return '';
  }

  bool get hasStorefrontSubtitle => resolvedStorefrontSubtitle.isNotEmpty;

  List<StoreBannerModel> get enabledBanners {
    final List<StoreBannerModel> items =
        banners
            .where((StoreBannerModel item) => item.enabled && item.hasImage)
            .toList()
          ..sort((StoreBannerModel a, StoreBannerModel b) {
            return a.sortOrder.compareTo(b.sortOrder);
          });
    if (items.length > 5) {
      return items.sublist(0, 5);
    }
    return items;
  }

  String get announcementText => announcement.trim();

  bool get hasAnnouncement => showAnnouncement && announcementText.isNotEmpty;

  factory StoreHomeDisplaySettings.fromMap(Map<String, dynamic> data) {
    final Object? rawBanners = data['banners'];
    final List<StoreBannerModel> banners = rawBanners is List
        ? rawBanners
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> item) =>
                    StoreBannerModel.fromMap(Map<String, dynamic>.from(item)),
              )
              .where((StoreBannerModel item) => item.id.isNotEmpty)
              .toList()
        : <StoreBannerModel>[];
    final int count = data['featuredCount'] is int
        ? data['featuredCount'] as int
        : int.tryParse(data['featuredCount']?.toString() ?? '') ?? 6;
    return StoreHomeDisplaySettings(
      announcement: (data['announcement'] ?? '').toString(),
      showAnnouncement: data['showAnnouncement'] != false,
      showBanners: data['showBanners'] != false,
      showCategories: data['showCategories'] != false,
      showFeaturedProducts: data['showFeaturedProducts'] != false,
      showPromoProducts: data['showPromoProducts'] != false,
      appearancePreset:
          StoreAppearancePresets.all.contains(
            (data['appearancePreset'] ?? StoreAppearancePresets.system)
                .toString(),
          )
          ? (data['appearancePreset'] ?? StoreAppearancePresets.system)
                .toString()
          : StoreAppearancePresets.system,
      banners: banners,
      bannerAutoPlay: data['bannerAutoPlay'] != false,
      bannerAutoPlaySeconds: _autoPlaySecondsOf(data['bannerAutoPlaySeconds']),
      hideOutOfStock: data['hideOutOfStock'] == true,
      showStockToCustomer: data['showStockToCustomer'] != false,
      featuredCount: count == 4 || count == 8 ? count : 6,
      storeName: (data['storeName'] ?? '').toString().trim(),
      storeDescription: (data['storeDescription'] ?? '').toString().trim(),
      storeAppearance: StoreAppearanceSetting.fromMap(
        data['storeAppearance'] is Map
            ? Map<String, dynamic>.from(data['storeAppearance'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }

  HomeThemeModel resolveTheme(HomeThemeModel shopTheme) {
    final HomeThemeModel base = StoreAppearancePresets.themeOf(
      appearancePreset,
      shopTheme,
    );
    return storeAppearance.applyTo(base, shopTheme);
  }

  static int _autoPlaySecondsOf(dynamic value) {
    final int parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '') ?? 5;
    return parsed == 3 || parsed == 8 ? parsed : 5;
  }
}

class StoreCardBackgroundModes {
  static const String solid = 'solid';
  static const String image = 'image';
  static const List<String> all = <String>[solid, image];
}

class StoreCardFits {
  static const String fill = 'fill';
  static const String contain = 'contain';
  static const List<String> all = <String>[fill, contain];

  static String label(String value) {
    return value == contain ? '完整顯示' : '填滿卡片';
  }
}

class StoreCardAlignments {
  static const String top = 'top';
  static const String center = 'center';
  static const String bottom = 'bottom';
  static const List<String> all = <String>[top, center, bottom];

  static String label(String value) {
    switch (value) {
      case top:
        return '上方';
      case bottom:
        return '下方';
      default:
        return '置中';
    }
  }

  static Alignment geometry(String value) {
    switch (value) {
      case top:
        return Alignment.topCenter;
      case bottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }
}

class StoreCardOverlays {
  static const String original = 'original';
  static const String light = 'light';
  static const String veryLight = 'veryLight';
  static const List<String> all = <String>[original, light, veryLight];

  static String label(String value) {
    switch (value) {
      case light:
        return '淡';
      case veryLight:
        return '很淡';
      default:
        return '原圖';
    }
  }

  static double opacity(String value) {
    switch (value) {
      case light:
        return 0.35;
      case veryLight:
        return 0.50;
      default:
        return 0.18;
    }
  }
}

class StoreCardTextPresets {
  static const String darkBrown = 'darkBrown';
  static const String darkGray = 'darkGray';
  static const String white = 'white';
  static const String brand = 'brand';
  static const List<String> all = <String>[darkBrown, darkGray, white, brand];

  static String label(String value) {
    switch (value) {
      case darkGray:
        return '深灰';
      case white:
        return '白色';
      case brand:
        return '品牌色';
      default:
        return '深棕';
    }
  }
}

class StorePageBackgroundPresets {
  static const String followShop = 'followShop';
  static const String warmCream = 'warmCream';
  static const String white = 'white';
  static const String paleGray = 'paleGray';
  static const String blush = 'blush';
  static const String mint = 'mint';
  static const String sky = 'sky';
  static const List<String> all = <String>[
    followShop,
    warmCream,
    white,
    paleGray,
    blush,
    mint,
    sky,
  ];

  static String label(String value) {
    switch (value) {
      case warmCream:
        return '暖米';
      case white:
        return '白色';
      case paleGray:
        return '淡灰';
      case blush:
        return '淡粉';
      case mint:
        return '淡綠';
      case sky:
        return '淡藍';
      default:
        return '跟隨店家';
    }
  }

  static Color colorOf(String value, Color shopBackground) {
    switch (value) {
      case warmCream:
        return const Color(0xFFFFF6EC);
      case white:
        return const Color(0xFFFFFFFF);
      case paleGray:
        return const Color(0xFFF4F4F5);
      case blush:
        return const Color(0xFFFFF4F5);
      case mint:
        return const Color(0xFFF3F8F4);
      case sky:
        return const Color(0xFFF3F7FB);
      default:
        return shopBackground;
    }
  }
}

class StoreCardColorPresets {
  static const String system = 'system';
  static const String warmCream = 'warmCream';
  static const String white = 'white';
  static const String milkTea = 'milkTea';
  static const String blush = 'blush';
  static const String mint = 'mint';
  static const String sky = 'sky';
  static const String grayWhite = 'grayWhite';
  static const List<String> all = <String>[
    system,
    warmCream,
    white,
    milkTea,
    blush,
    mint,
    sky,
    grayWhite,
  ];

  static String label(String value) {
    switch (value) {
      case warmCream:
        return '暖米色';
      case white:
        return '純白';
      case milkTea:
        return '奶茶色';
      case blush:
        return '淡粉';
      case mint:
        return '淡綠';
      case sky:
        return '淡藍';
      case grayWhite:
        return '灰白';
      default:
        return '系統預設';
    }
  }

  static Color colorOf(String value, Color fallback) {
    switch (value) {
      case warmCream:
        return const Color(0xFFFFF6EC);
      case white:
        return const Color(0xFFFFFFFF);
      case milkTea:
        return const Color(0xFFF6EFE6);
      case blush:
        return const Color(0xFFFFF4F5);
      case mint:
        return const Color(0xFFF3F8F4);
      case sky:
        return const Color(0xFFF3F7FB);
      case grayWhite:
        return const Color(0xFFF5F5F5);
      default:
        return fallback;
    }
  }
}

class StoreAccentPresets {
  static const String brand = 'brand';
  static const String orange = 'orange';
  static const String brown = 'brown';
  static const String green = 'green';
  static const String blue = 'blue';
  static const String pink = 'pink';
  static const String charcoal = 'charcoal';
  static const List<String> all = <String>[
    brand,
    orange,
    brown,
    green,
    blue,
    pink,
    charcoal,
  ];

  static String label(String value) {
    switch (value) {
      case orange:
        return '暖橘';
      case brown:
        return '深棕';
      case green:
        return '森林綠';
      case blue:
        return '霧藍';
      case pink:
        return '玫瑰粉';
      case charcoal:
        return '深灰';
      default:
        return '跟隨賣場';
    }
  }

  static Color colorOf(String value, Color brandColor) {
    switch (value) {
      case orange:
        return const Color(0xFFFF8A00);
      case brown:
        return const Color(0xFF8B5A2B);
      case green:
        return const Color(0xFF4F7D61);
      case blue:
        return const Color(0xFF4A7BA7);
      case pink:
        return const Color(0xFFD77887);
      case charcoal:
        return const Color(0xFF4A4A4A);
      default:
        return brandColor;
    }
  }
}

class StoreAppearanceSetting {
  const StoreAppearanceSetting({
    this.pageBackgroundPreset = StorePageBackgroundPresets.followShop,
    this.cardBackgroundMode = StoreCardBackgroundModes.solid,
    this.cardBackgroundPreset = StoreCardColorPresets.system,
    this.cardBackgroundImageUrl = '',
    this.cardBackgroundImageStoragePath = '',
    this.cardBackgroundFit = StoreCardFits.fill,
    this.cardBackgroundAlignment = StoreCardAlignments.center,
    this.cardOverlay = StoreCardOverlays.original,
    this.cardTextPreset = StoreCardTextPresets.darkBrown,
    this.storeTitle = '',
    this.storeSubtitle = '',
    this.featuredTitle = '',
    this.promoTitle = '',
    this.allProductsTitle = '',
    this.latestTitle = '',
    this.primaryButtonPreset = StoreAccentPresets.brand,
    this.secondaryButtonPreset = StoreAccentPresets.charcoal,
    this.accentPreset = StoreAccentPresets.brand,
  });

  final String pageBackgroundPreset;
  final String cardBackgroundMode;
  final String cardBackgroundPreset;
  final String cardBackgroundImageUrl;
  final String cardBackgroundImageStoragePath;
  final String cardBackgroundFit;
  final String cardBackgroundAlignment;
  final String cardOverlay;
  final String cardTextPreset;
  final String storeTitle;
  final String storeSubtitle;
  final String featuredTitle;
  final String promoTitle;
  final String allProductsTitle;
  final String latestTitle;
  final String primaryButtonPreset;
  final String secondaryButtonPreset;
  final String accentPreset;

  static const String defaultStoreTitle = '寵物賣場';
  static const String defaultStoreSubtitle = '為毛孩挑選安心好物';
  static const String defaultFeaturedTitle = '精選商品';
  static const String defaultPromoTitle = '優惠商品';
  static const String defaultAllTitle = '全部商品';
  static const String defaultLatestTitle = '最新商品';

  bool get usesCardImage =>
      cardBackgroundMode == StoreCardBackgroundModes.image &&
      cardBackgroundImageUrl.trim().isNotEmpty;

  String get resolvedStoreTitle =>
      storeTitle.trim().isEmpty ? defaultStoreTitle : storeTitle.trim();

  String get resolvedStoreSubtitle => storeSubtitle.trim().isEmpty
      ? defaultStoreSubtitle
      : storeSubtitle.trim();

  String get resolvedFeaturedTitle => featuredTitle.trim().isEmpty
      ? defaultFeaturedTitle
      : featuredTitle.trim();

  String get resolvedPromoTitle =>
      promoTitle.trim().isEmpty ? defaultPromoTitle : promoTitle.trim();

  String get resolvedAllTitle => allProductsTitle.trim().isEmpty
      ? defaultAllTitle
      : allProductsTitle.trim();

  String get resolvedLatestTitle =>
      latestTitle.trim().isEmpty ? defaultLatestTitle : latestTitle.trim();

  BoxFit get cardBoxFit => cardBackgroundFit == StoreCardFits.contain
      ? BoxFit.contain
      : BoxFit.cover;

  Alignment get cardAlignment =>
      StoreCardAlignments.geometry(cardBackgroundAlignment);

  double get overlayOpacity => StoreCardOverlays.opacity(cardOverlay);

  factory StoreAppearanceSetting.fromMap(Map<String, dynamic> data) {
    String pick(List<String> allowed, dynamic raw, String fallback) {
      final String value = (raw ?? fallback).toString();
      return allowed.contains(value) ? value : fallback;
    }

    return StoreAppearanceSetting(
      pageBackgroundPreset: pick(
        StorePageBackgroundPresets.all,
        data['pageBackgroundPreset'],
        StorePageBackgroundPresets.followShop,
      ),
      cardBackgroundMode: pick(
        StoreCardBackgroundModes.all,
        data['cardBackgroundMode'],
        StoreCardBackgroundModes.solid,
      ),
      cardBackgroundPreset: pick(
        StoreCardColorPresets.all,
        data['cardBackgroundPreset'],
        StoreCardColorPresets.system,
      ),
      cardBackgroundImageUrl: (data['cardBackgroundImageUrl'] ?? '')
          .toString()
          .trim(),
      cardBackgroundImageStoragePath:
          (data['cardBackgroundImageStoragePath'] ?? '').toString().trim(),
      cardBackgroundFit: pick(
        StoreCardFits.all,
        data['cardBackgroundFit'],
        StoreCardFits.fill,
      ),
      cardBackgroundAlignment: pick(
        StoreCardAlignments.all,
        data['cardBackgroundAlignment'],
        StoreCardAlignments.center,
      ),
      cardOverlay: pick(
        StoreCardOverlays.all,
        data['cardOverlay'],
        StoreCardOverlays.original,
      ),
      cardTextPreset: pick(
        StoreCardTextPresets.all,
        data['cardTextPreset'],
        StoreCardTextPresets.darkBrown,
      ),
      storeTitle: (data['storeTitle'] ?? '').toString(),
      storeSubtitle: (data['storeSubtitle'] ?? '').toString(),
      featuredTitle: (data['featuredTitle'] ?? '').toString(),
      promoTitle: (data['promoTitle'] ?? '').toString(),
      allProductsTitle: (data['allProductsTitle'] ?? '').toString(),
      latestTitle: (data['latestTitle'] ?? '').toString(),
      primaryButtonPreset: pick(
        StoreAccentPresets.all,
        data['primaryButtonPreset'],
        StoreAccentPresets.brand,
      ),
      secondaryButtonPreset: pick(
        StoreAccentPresets.all,
        data['secondaryButtonPreset'],
        StoreAccentPresets.charcoal,
      ),
      accentPreset: pick(
        StoreAccentPresets.all,
        data['accentPreset'],
        StoreAccentPresets.brand,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pageBackgroundPreset': pageBackgroundPreset,
      'cardBackgroundMode': cardBackgroundMode,
      'cardBackgroundPreset': cardBackgroundPreset,
      'cardBackgroundImageUrl': cardBackgroundImageUrl.trim(),
      'cardBackgroundImageStoragePath': cardBackgroundImageStoragePath.trim(),
      'cardBackgroundFit': cardBackgroundFit,
      'cardBackgroundAlignment': cardBackgroundAlignment,
      'cardOverlay': cardOverlay,
      'cardTextPreset': cardTextPreset,
      'storeTitle': storeTitle.trim(),
      'storeSubtitle': storeSubtitle.trim(),
      'featuredTitle': featuredTitle.trim(),
      'promoTitle': promoTitle.trim(),
      'allProductsTitle': allProductsTitle.trim(),
      'latestTitle': latestTitle.trim(),
      'primaryButtonPreset': primaryButtonPreset,
      'secondaryButtonPreset': secondaryButtonPreset,
      'accentPreset': accentPreset,
    };
  }

  StoreAppearanceSetting copyWith({
    String? pageBackgroundPreset,
    String? cardBackgroundMode,
    String? cardBackgroundPreset,
    String? cardBackgroundImageUrl,
    String? cardBackgroundImageStoragePath,
    String? cardBackgroundFit,
    String? cardBackgroundAlignment,
    String? cardOverlay,
    String? cardTextPreset,
    String? storeTitle,
    String? storeSubtitle,
    String? featuredTitle,
    String? promoTitle,
    String? allProductsTitle,
    String? latestTitle,
    String? primaryButtonPreset,
    String? secondaryButtonPreset,
    String? accentPreset,
  }) {
    return StoreAppearanceSetting(
      pageBackgroundPreset: pageBackgroundPreset ?? this.pageBackgroundPreset,
      cardBackgroundMode: cardBackgroundMode ?? this.cardBackgroundMode,
      cardBackgroundPreset: cardBackgroundPreset ?? this.cardBackgroundPreset,
      cardBackgroundImageUrl:
          cardBackgroundImageUrl ?? this.cardBackgroundImageUrl,
      cardBackgroundImageStoragePath:
          cardBackgroundImageStoragePath ?? this.cardBackgroundImageStoragePath,
      cardBackgroundFit: cardBackgroundFit ?? this.cardBackgroundFit,
      cardBackgroundAlignment:
          cardBackgroundAlignment ?? this.cardBackgroundAlignment,
      cardOverlay: cardOverlay ?? this.cardOverlay,
      cardTextPreset: cardTextPreset ?? this.cardTextPreset,
      storeTitle: storeTitle ?? this.storeTitle,
      storeSubtitle: storeSubtitle ?? this.storeSubtitle,
      featuredTitle: featuredTitle ?? this.featuredTitle,
      promoTitle: promoTitle ?? this.promoTitle,
      allProductsTitle: allProductsTitle ?? this.allProductsTitle,
      latestTitle: latestTitle ?? this.latestTitle,
      primaryButtonPreset: primaryButtonPreset ?? this.primaryButtonPreset,
      secondaryButtonPreset:
          secondaryButtonPreset ?? this.secondaryButtonPreset,
      accentPreset: accentPreset ?? this.accentPreset,
    );
  }

  Color accentColor(HomeThemeModel theme) {
    return StoreAccentPresets.colorOf(accentPreset, theme.primaryColor);
  }

  Color cardSolidColor(HomeThemeModel theme) {
    return StoreCardColorPresets.colorOf(cardBackgroundPreset, theme.cardColor);
  }

  Color primaryTextColor(HomeThemeModel theme) {
    switch (cardTextPreset) {
      case StoreCardTextPresets.darkGray:
        return const Color(0xFF2A2A2A);
      case StoreCardTextPresets.white:
        return const Color(0xFFFFFFFF);
      case StoreCardTextPresets.brand:
        return accentColor(theme);
      default:
        return const Color(0xFF3A2A20);
    }
  }

  Color secondaryTextColor(HomeThemeModel theme) {
    final Color main = primaryTextColor(theme);
    return main.withValues(
      alpha: cardTextPreset == StoreCardTextPresets.white ? 0.78 : 0.62,
    );
  }

  Color priceColor(HomeThemeModel theme) {
    if (cardTextPreset == StoreCardTextPresets.white) {
      return const Color(0xFFFFFFFF);
    }
    return accentColor(theme);
  }

  Color overlayColor(HomeThemeModel theme) {
    return cardTextPreset == StoreCardTextPresets.white
        ? const Color(0xFF1A1410)
        : const Color(0xFFFFFBF7);
  }

  Color primaryButtonColor(HomeThemeModel theme) {
    return StoreAccentPresets.colorOf(primaryButtonPreset, accentColor(theme));
  }

  Color secondaryButtonColor(HomeThemeModel theme) {
    return StoreAccentPresets.colorOf(
      secondaryButtonPreset,
      const Color(0xFF4A4A4A),
    );
  }

  static Color onColor(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF2A221C)
        : const Color(0xFFFFFFFF);
  }

  HomeThemeModel applyTo(HomeThemeModel base, HomeThemeModel shopTheme) {
    final Color page = StorePageBackgroundPresets.colorOf(
      pageBackgroundPreset,
      shopTheme.backgroundColor,
    );
    return base.copyWith(
      backgroundColorValue: page.toARGB32(),
      cardColorValue: cardSolidColor(base).toARGB32(),
      primaryColorValue: accentColor(base).toARGB32(),
      textColorValue: primaryTextColor(base).toARGB32(),
    );
  }
}
