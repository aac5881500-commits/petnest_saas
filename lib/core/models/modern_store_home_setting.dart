// lib/core/models/modern_store_home_setting.dart
// 🛒 新版 Beta 首頁「寵物賣場入口卡片」外觀
// 掛在 shops/{shopId}.homeAppearance.modern，不進 store_settings。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';

class ModernStoreCardOverlays {
  static const String none = 'none';
  static const String light = 'light';
  static const String standard = 'standard';
  static const String deep = 'deep';
  static const List<String> all = <String>[none, light, standard, deep];

  static String label(String value) {
    switch (value) {
      case light:
        return '淡';
      case standard:
        return '標準';
      case deep:
        return '深';
      default:
        return '無';
    }
  }

  static double opacity(String value) {
    switch (value) {
      case light:
        return 0.15;
      case standard:
        return 0.30;
      case deep:
        return 0.45;
      default:
        return 0;
    }
  }
}

class ModernStoreCardOverlayTones {
  static const String dark = 'dark';
  static const String light = 'light';
  static const List<String> all = <String>[dark, light];

  static String label(String value) {
    return value == light ? '白色遮罩' : '黑色遮罩';
  }

  static Color colorOf(String value) {
    return value == light ? const Color(0xFFFFFFFF) : const Color(0xFF1A1410);
  }
}

class ModernStoreCardTextColors {
  static const String dark = 'dark';
  static const String light = 'light';
  static const String brand = 'brand';
  static const List<String> all = <String>[dark, light, brand];

  static String label(String value) {
    switch (value) {
      case light:
        return '白色';
      case brand:
        return '品牌色';
      default:
        return '深色';
    }
  }

  static Color colorOf(String value, HomeThemeModel theme) {
    switch (value) {
      case light:
        return const Color(0xFFFFFFFF);
      case brand:
        return theme.primaryColor;
      default:
        return const Color(0xFF2A221C);
    }
  }
}

class ModernStoreCardButtonColors {
  static const String brand = 'brand';
  static const String white = 'white';
  static const String dark = 'dark';
  static const List<String> all = <String>[brand, white, dark];

  static String label(String value) {
    switch (value) {
      case white:
        return '白底';
      case dark:
        return '深色';
      default:
        return '品牌色';
    }
  }

  static Color backgroundOf(String value, HomeThemeModel theme) {
    switch (value) {
      case white:
        return const Color(0xFFFFFFFF);
      case dark:
        return const Color(0xFF2A221C);
      default:
        return theme.primaryColor;
    }
  }

  static Color foregroundOf(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF2A221C)
        : const Color(0xFFFFFFFF);
  }
}

class ModernStoreCardFits {
  static const String cover = ModernBannerFrameSetting.fitFill;
  static const String contain = ModernBannerFrameSetting.fitContain;
  static const List<String> all = <String>[cover, contain];

  static String label(String value) {
    return value == contain ? '完整顯示' : '填滿卡片';
  }
}

class ModernStoreCardAlignments {
  static const String top = ModernBannerFrameSetting.alignTop;
  static const String center = ModernBannerFrameSetting.alignCenter;
  static const String bottom = ModernBannerFrameSetting.alignBottom;
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

class ModernStoreCardPositions {
  static const String topLeft = 'topLeft';
  static const String centerLeft = 'centerLeft';
  static const String bottomLeft = 'bottomLeft';
  static const String center = 'center';
  static const List<String> all = <String>[
    topLeft,
    centerLeft,
    bottomLeft,
    center,
  ];

  static String label(String value) {
    switch (value) {
      case topLeft:
        return '左上';
      case bottomLeft:
        return '左下';
      case center:
        return '中央';
      default:
        return '左中';
    }
  }

  static Alignment alignment(String value) {
    switch (value) {
      case topLeft:
        return Alignment.topLeft;
      case bottomLeft:
        return Alignment.bottomLeft;
      case center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  static CrossAxisAlignment cross(String value) {
    return value == center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
  }

  static TextAlign textAlign(String value) {
    return value == center ? TextAlign.center : TextAlign.left;
  }
}

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
    this.storeBannerImageStoragePath = '',
    this.storeBannerBackgroundFit = ModernStoreCardFits.cover,
    this.storeBannerBackgroundAlignment = ModernStoreCardAlignments.center,
    this.storeBannerOverlayPreset = ModernStoreCardOverlays.standard,
    this.storeBannerOverlayTone = ModernStoreCardOverlayTones.dark,
    this.storeBannerTitleColorPreset = ModernStoreCardTextColors.dark,
    this.storeBannerSubtitleColorPreset = ModernStoreCardTextColors.dark,
    this.storeBannerButtonColorPreset = ModernStoreCardButtonColors.brand,
    this.storeBannerContentPosition = ModernStoreCardPositions.centerLeft,
  });

  final bool showFeaturedProducts;
  final String featuredTitle;
  final bool showStoreBanner;
  final String storeBannerTitle;
  final String storeBannerSubtitle;
  final String storeBannerButtonText;
  final String storeBannerImageUrl;
  final String storeBannerImageStoragePath;
  final String storeBannerBackgroundFit;
  final String storeBannerBackgroundAlignment;
  final String storeBannerOverlayPreset;
  final String storeBannerOverlayTone;
  final String storeBannerTitleColorPreset;
  final String storeBannerSubtitleColorPreset;
  final String storeBannerButtonColorPreset;
  final String storeBannerContentPosition;

  bool get hasBackgroundImage => storeBannerImageUrl.trim().isNotEmpty;

  String get resolvedTitle =>
      _textOrDefault(storeBannerTitle, defaultBannerTitle);

  String get resolvedSubtitle =>
      _textOrDefault(storeBannerSubtitle, defaultBannerSubtitle);

  String get resolvedButtonText =>
      _textOrDefault(storeBannerButtonText, defaultBannerButtonText);

  BoxFit get backgroundBoxFit {
    return storeBannerBackgroundFit == ModernStoreCardFits.contain
        ? BoxFit.contain
        : BoxFit.cover;
  }

  Alignment get backgroundAlignment {
    return ModernStoreCardAlignments.geometry(storeBannerBackgroundAlignment);
  }

  factory ModernStoreHomeSetting.fromMap(Map<String, dynamic> map) {
    String pick(List<String> allowed, dynamic raw, String fallback) {
      final String value = (raw ?? fallback).toString();
      return allowed.contains(value) ? value : fallback;
    }

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
      storeBannerImageStoragePath: (map['storeBannerImageStoragePath'] ?? '')
          .toString()
          .trim(),
      storeBannerBackgroundFit: pick(
        ModernStoreCardFits.all,
        map['storeBannerBackgroundFit'],
        ModernStoreCardFits.cover,
      ),
      storeBannerBackgroundAlignment: pick(
        ModernStoreCardAlignments.all,
        map['storeBannerBackgroundAlignment'],
        ModernStoreCardAlignments.center,
      ),
      storeBannerOverlayPreset: pick(
        ModernStoreCardOverlays.all,
        map['storeBannerOverlayPreset'],
        map['storeBannerImageUrl']?.toString().trim().isNotEmpty == true
            ? ModernStoreCardOverlays.standard
            : ModernStoreCardOverlays.none,
      ),
      storeBannerOverlayTone: pick(
        ModernStoreCardOverlayTones.all,
        map['storeBannerOverlayTone'],
        ModernStoreCardOverlayTones.dark,
      ),
      storeBannerTitleColorPreset: pick(
        ModernStoreCardTextColors.all,
        map['storeBannerTitleColorPreset'],
        ModernStoreCardTextColors.dark,
      ),
      storeBannerSubtitleColorPreset: pick(
        ModernStoreCardTextColors.all,
        map['storeBannerSubtitleColorPreset'],
        ModernStoreCardTextColors.dark,
      ),
      storeBannerButtonColorPreset: pick(
        ModernStoreCardButtonColors.all,
        map['storeBannerButtonColorPreset'],
        ModernStoreCardButtonColors.brand,
      ),
      storeBannerContentPosition: pick(
        ModernStoreCardPositions.all,
        map['storeBannerContentPosition'],
        ModernStoreCardPositions.centerLeft,
      ),
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
      'storeBannerImageUrl': storeBannerImageUrl.trim(),
      'storeBannerImageStoragePath': storeBannerImageStoragePath.trim(),
      'storeBannerBackgroundFit': storeBannerBackgroundFit,
      'storeBannerBackgroundAlignment': storeBannerBackgroundAlignment,
      'storeBannerOverlayPreset': storeBannerOverlayPreset,
      'storeBannerOverlayTone': storeBannerOverlayTone,
      'storeBannerTitleColorPreset': storeBannerTitleColorPreset,
      'storeBannerSubtitleColorPreset': storeBannerSubtitleColorPreset,
      'storeBannerButtonColorPreset': storeBannerButtonColorPreset,
      'storeBannerContentPosition': storeBannerContentPosition,
    };
  }

  ModernStoreHomeSetting copyWith({
    bool? showFeaturedProducts,
    String? featuredTitle,
    bool? showStoreBanner,
    String? storeBannerTitle,
    String? storeBannerSubtitle,
    String? storeBannerButtonText,
    String? storeBannerImageUrl,
    String? storeBannerImageStoragePath,
    String? storeBannerBackgroundFit,
    String? storeBannerBackgroundAlignment,
    String? storeBannerOverlayPreset,
    String? storeBannerOverlayTone,
    String? storeBannerTitleColorPreset,
    String? storeBannerSubtitleColorPreset,
    String? storeBannerButtonColorPreset,
    String? storeBannerContentPosition,
  }) {
    return ModernStoreHomeSetting(
      showFeaturedProducts: showFeaturedProducts ?? this.showFeaturedProducts,
      featuredTitle: featuredTitle ?? this.featuredTitle,
      showStoreBanner: showStoreBanner ?? this.showStoreBanner,
      storeBannerTitle: storeBannerTitle ?? this.storeBannerTitle,
      storeBannerSubtitle: storeBannerSubtitle ?? this.storeBannerSubtitle,
      storeBannerButtonText:
          storeBannerButtonText ?? this.storeBannerButtonText,
      storeBannerImageUrl: storeBannerImageUrl ?? this.storeBannerImageUrl,
      storeBannerImageStoragePath:
          storeBannerImageStoragePath ?? this.storeBannerImageStoragePath,
      storeBannerBackgroundFit:
          storeBannerBackgroundFit ?? this.storeBannerBackgroundFit,
      storeBannerBackgroundAlignment:
          storeBannerBackgroundAlignment ?? this.storeBannerBackgroundAlignment,
      storeBannerOverlayPreset:
          storeBannerOverlayPreset ?? this.storeBannerOverlayPreset,
      storeBannerOverlayTone:
          storeBannerOverlayTone ?? this.storeBannerOverlayTone,
      storeBannerTitleColorPreset:
          storeBannerTitleColorPreset ?? this.storeBannerTitleColorPreset,
      storeBannerSubtitleColorPreset:
          storeBannerSubtitleColorPreset ?? this.storeBannerSubtitleColorPreset,
      storeBannerButtonColorPreset:
          storeBannerButtonColorPreset ?? this.storeBannerButtonColorPreset,
      storeBannerContentPosition:
          storeBannerContentPosition ?? this.storeBannerContentPosition,
    );
  }

  static String _textOrDefault(dynamic value, String fallback) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
