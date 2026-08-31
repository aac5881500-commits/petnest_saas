import 'package:flutter/material.dart';

enum HomeBannerDisplaySize { small, standard, large }

class ModernBannerFrameSetting {
  const ModernBannerFrameSetting({
    this.displaySize = HomeBannerDisplaySize.standard,
    this.bannerImageFit = fitFill,
    this.bannerImageAlignment = alignCenter,
  });

  static const String fitFill = 'cover';
  static const String fitContain = 'contain';
  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';

  final HomeBannerDisplaySize displaySize;
  final String bannerImageFit;
  final String bannerImageAlignment;

  String get displaySizeKey {
    switch (displaySize) {
      case HomeBannerDisplaySize.small:
        return 'small';
      case HomeBannerDisplaySize.standard:
        return 'standard';
      case HomeBannerDisplaySize.large:
        return 'large';
    }
  }

  /// 小 2.4:1、標準 16:9、大 3:2。寬度由 container 決定，高度等比縮放。
  double get aspectRatio {
    switch (displaySize) {
      case HomeBannerDisplaySize.small:
        return 2.4;
      case HomeBannerDisplaySize.standard:
        return 16 / 9;
      case HomeBannerDisplaySize.large:
        return 3 / 2;
    }
  }

  /// 相容舊 UI／評論徽章：小 = 舊極簡+精簡。
  bool get isUltraCompact => displaySize == HomeBannerDisplaySize.small;
  bool get isCompact => displaySize == HomeBannerDisplaySize.small;
  bool get isStandard => displaySize == HomeBannerDisplaySize.standard;
  bool get isLarge => displaySize == HomeBannerDisplaySize.large;

  String get heightPreset {
    switch (displaySize) {
      case HomeBannerDisplaySize.small:
        return 'compact';
      case HomeBannerDisplaySize.standard:
        return 'standard';
      case HomeBannerDisplaySize.large:
        return 'large';
    }
  }

  String get imageFit => bannerImageFit;
  String get imageAlignment => bannerImageAlignment;
  bool get usesCoverFit => bannerImageFit != fitContain;
  BoxFit get boxFit => parsedBannerImageFit;
  Alignment get alignment => parsedBannerImageAlignment;

  Alignment get parsedBannerImageAlignment {
    switch (bannerImageAlignment) {
      case alignTop:
        return Alignment.topCenter;
      case alignBottom:
        return Alignment.bottomCenter;
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  BoxFit get parsedBannerImageFit {
    return bannerImageFit == fitContain ? BoxFit.contain : BoxFit.cover;
  }

  double heightForWidth(double width) {
    if (width <= 0) {
      return 0;
    }
    return width / aspectRatio;
  }

  ModernBannerFrameSetting copyWith({
    HomeBannerDisplaySize? displaySize,
    String? bannerImageFit,
    String? bannerImageAlignment,
  }) {
    return ModernBannerFrameSetting(
      displaySize: displaySize ?? this.displaySize,
      bannerImageFit: bannerImageFit ?? this.bannerImageFit,
      bannerImageAlignment: bannerImageAlignment ?? this.bannerImageAlignment,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'homeBannerDisplaySize': displaySizeKey,
      'bannerHeightPreset': heightPreset,
      'bannerImageFit': bannerImageFit,
      'bannerImageAlignment': bannerImageAlignment,
    };
  }

  factory ModernBannerFrameSetting.fromMap(Map<String, dynamic> map) {
    return ModernBannerFrameSetting(
      displaySize: _parseDisplaySize(map),
      bannerImageFit: (map['bannerImageFit'] ?? fitFill).toString(),
      bannerImageAlignment: (map['bannerImageAlignment'] ?? alignCenter)
          .toString(),
    );
  }

  factory ModernBannerFrameSetting.fromShop(Map<String, dynamic>? shop) {
    final Object? appearance = shop?['homeAppearance'];
    if (appearance is! Map) {
      return const ModernBannerFrameSetting();
    }
    final Object? modern = appearance['modern'];
    if (modern is! Map) {
      return const ModernBannerFrameSetting();
    }
    return ModernBannerFrameSetting.fromMap(Map<String, dynamic>.from(modern));
  }

  static HomeBannerDisplaySize _parseDisplaySize(Map<String, dynamic> map) {
    final String size = (map['homeBannerDisplaySize'] ?? '').toString().trim();
    switch (size) {
      case 'small':
        return HomeBannerDisplaySize.small;
      case 'standard':
        return HomeBannerDisplaySize.standard;
      case 'large':
        return HomeBannerDisplaySize.large;
    }

    switch ((map['bannerHeightPreset'] ?? 'standard').toString()) {
      case 'ultraCompact':
      case 'compact':
        return HomeBannerDisplaySize.small;
      case 'large':
        return HomeBannerDisplaySize.large;
      default:
        return HomeBannerDisplaySize.standard;
    }
  }
}
