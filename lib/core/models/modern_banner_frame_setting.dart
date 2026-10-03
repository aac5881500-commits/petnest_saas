// 檔案名稱：lib/core/models/modern_banner_frame_setting.dart
// 功能說明：新版首頁 Banner 外框。寬度與高度分開設定。

import 'package:flutter/material.dart';

enum HomeBannerDisplaySize { small, standard, large }

enum HomeBannerWidthPreset { narrow, standard, full }

enum HomeBannerHeightPreset { short, standard, tall }

class ModernBannerFrameSetting {
  const ModernBannerFrameSetting({
    this.widthPreset = HomeBannerWidthPreset.standard,
    this.heightPreset = HomeBannerHeightPreset.standard,
    this.bannerImageFit = fitFill,
    this.bannerImageAlignment = alignCenter,
  });

  static const String fitFill = 'cover';
  static const String fitContain = 'contain';
  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';

  final HomeBannerWidthPreset widthPreset;
  final HomeBannerHeightPreset heightPreset;
  final String bannerImageFit;
  final String bannerImageAlignment;

  /// 舊欄位相容。只跟寬度走，不再決定高度。
  HomeBannerDisplaySize get displaySize {
    switch (widthPreset) {
      case HomeBannerWidthPreset.narrow:
        return HomeBannerDisplaySize.small;
      case HomeBannerWidthPreset.standard:
        return HomeBannerDisplaySize.standard;
      case HomeBannerWidthPreset.full:
        return HomeBannerDisplaySize.large;
    }
  }

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

  String get widthPresetKey {
    switch (widthPreset) {
      case HomeBannerWidthPreset.narrow:
        return 'narrow';
      case HomeBannerWidthPreset.standard:
        return 'standard';
      case HomeBannerWidthPreset.full:
        return 'full';
    }
  }

  String get heightPresetKey {
    switch (heightPreset) {
      case HomeBannerHeightPreset.short:
        return 'short';
      case HomeBannerHeightPreset.standard:
        return 'standard';
      case HomeBannerHeightPreset.tall:
        return 'tall';
    }
  }

  /// 矮版較扁、標準 16:9、高版較高。寬度由 container 決定。
  double get frameAspectRatio {
    switch (heightPreset) {
      case HomeBannerHeightPreset.short:
        return 2.20;
      case HomeBannerHeightPreset.standard:
        return 16 / 9;
      case HomeBannerHeightPreset.tall:
        return 3 / 2;
    }
  }

  double get aspectRatio => frameAspectRatio;

  /// 標準高度完整放入 16:9 成品；其餘高度填滿並裁切邊緣。
  BoxFit get completePosterFit {
    return heightPreset == HomeBannerHeightPreset.standard
        ? BoxFit.contain
        : BoxFit.cover;
  }

  bool get isUltraCompact => widthPreset == HomeBannerWidthPreset.narrow;
  bool get isCompact => widthPreset == HomeBannerWidthPreset.narrow;
  bool get isStandard =>
      widthPreset == HomeBannerWidthPreset.standard &&
      heightPreset == HomeBannerHeightPreset.standard;
  bool get isLarge => widthPreset == HomeBannerWidthPreset.full;

  String get legacyHeightPreset {
    switch (widthPreset) {
      case HomeBannerWidthPreset.narrow:
        return 'compact';
      case HomeBannerWidthPreset.standard:
        return 'standard';
      case HomeBannerWidthPreset.full:
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
    return width / frameAspectRatio;
  }

  ModernBannerFrameSetting copyWith({
    HomeBannerWidthPreset? widthPreset,
    HomeBannerHeightPreset? heightPreset,
    String? bannerImageFit,
    String? bannerImageAlignment,
  }) {
    return ModernBannerFrameSetting(
      widthPreset: widthPreset ?? this.widthPreset,
      heightPreset: heightPreset ?? this.heightPreset,
      bannerImageFit: bannerImageFit ?? this.bannerImageFit,
      bannerImageAlignment: bannerImageAlignment ?? this.bannerImageAlignment,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'homeBannerWidthPreset': widthPresetKey,
      'homeBannerHeightPreset': heightPresetKey,
      'homeBannerDisplaySize': displaySizeKey,
      'bannerHeightPreset': legacyHeightPreset,
      'bannerImageFit': bannerImageFit,
      'bannerImageAlignment': bannerImageAlignment,
    };
  }

  factory ModernBannerFrameSetting.fromMap(Map<String, dynamic> map) {
    return ModernBannerFrameSetting(
      widthPreset: _parseWidth(map),
      heightPreset: _parseHeight(map),
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

  @override
  bool operator ==(Object other) {
    return other is ModernBannerFrameSetting &&
        other.widthPreset == widthPreset &&
        other.heightPreset == heightPreset &&
        other.bannerImageFit == bannerImageFit &&
        other.bannerImageAlignment == bannerImageAlignment;
  }

  @override
  int get hashCode => Object.hash(
    widthPreset,
    heightPreset,
    bannerImageFit,
    bannerImageAlignment,
  );

  static HomeBannerWidthPreset _parseWidth(Map<String, dynamic> map) {
    switch ((map['homeBannerWidthPreset'] ?? '').toString().trim()) {
      case 'narrow':
        return HomeBannerWidthPreset.narrow;
      case 'standard':
        return HomeBannerWidthPreset.standard;
      case 'full':
        return HomeBannerWidthPreset.full;
    }
    switch ((map['homeBannerDisplaySize'] ?? '').toString().trim()) {
      case 'small':
        return HomeBannerWidthPreset.narrow;
      case 'standard':
        return HomeBannerWidthPreset.standard;
      case 'large':
        return HomeBannerWidthPreset.full;
    }
    switch ((map['bannerHeightPreset'] ?? '').toString()) {
      case 'ultraCompact':
      case 'compact':
        return HomeBannerWidthPreset.narrow;
      case 'large':
        return HomeBannerWidthPreset.full;
      default:
        return HomeBannerWidthPreset.standard;
    }
  }

  static HomeBannerHeightPreset _parseHeight(Map<String, dynamic> map) {
    switch ((map['homeBannerHeightPreset'] ?? '').toString().trim()) {
      case 'short':
        return HomeBannerHeightPreset.short;
      case 'tall':
        return HomeBannerHeightPreset.tall;
      case 'standard':
        return HomeBannerHeightPreset.standard;
      default:
        return HomeBannerHeightPreset.standard;
    }
  }
}
