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
    this.displayMode = modeClassic,
    this.showSectionTitle = false,
    this.sectionTitle = '活動',
    this.sectionFontFamily = '',
    this.sectionTitleSize = sizeMedium,
    this.sectionTitleWeight = weightBold,
    this.sectionTitleColorMode = colorTheme,
    this.sectionTitleColor = 0xFF3A2A20,
    this.sectionTitleAlign = alignStart,
    this.sectionTitleGap = gapStandard,
    this.activityScroll = scrollManual,
    this.activitySeconds = 5,
    this.activityPeek = peekStandard,
    this.activityGap = gapStandard,
    this.activityWidth = 0.85,
    this.activityHeightFactor = 9 / 16,
    this.activitySpacing = 12,
    this.activityInset = 8,
    this.activityRadius = radiusStandard,
    this.showDots = true,
    this.dotColorMode = colorTheme,
    this.dotColor = 0xFFA56B45,
  });

  static const String fitFill = 'cover';
  static const String fitContain = 'contain';
  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';
  static const String modeClassic = 'classic';
  static const String modeActivity = 'activity';
  static const String scrollManual = 'manual';
  static const String scrollAuto = 'auto';
  static const String peekSlight = 'slight';
  static const String peekStandard = 'standard';
  static const String peekStrong = 'strong';
  static const String gapCompact = 'compact';
  static const String gapStandard = 'standard';
  static const String gapRelaxed = 'relaxed';
  static const String radiusSmall = 'small';
  static const String radiusStandard = 'standard';
  static const String radiusLarge = 'large';
  static const String sizeSmall = 'small';
  static const String sizeMedium = 'medium';
  static const String sizeLarge = 'large';
  static const String weightRegular = 'regular';
  static const String weightMedium = 'medium';
  static const String weightBold = 'bold';
  static const String colorTheme = 'theme';
  static const String colorCustom = 'custom';
  static const String alignStart = 'start';
  static const String alignEnd = 'end';

  final HomeBannerWidthPreset widthPreset;
  final HomeBannerHeightPreset heightPreset;
  final String bannerImageFit;
  final String bannerImageAlignment;
  final String displayMode;
  final bool showSectionTitle;
  final String sectionTitle;
  final String sectionFontFamily;
  final String sectionTitleSize;
  final String sectionTitleWeight;
  final String sectionTitleColorMode;
  final int sectionTitleColor;
  final String sectionTitleAlign;
  final String sectionTitleGap;
  final String activityScroll;
  final int activitySeconds;
  final String activityPeek;
  final String activityGap;
  final double activityWidth;
  final double activityHeightFactor;
  final double activitySpacing;
  final double activityInset;
  final String activityRadius;

  static const double activityWidthDefault = 0.85;
  static const double activityHeightDefault = 9 / 16;
  static const double activityGapDefault = 12;
  static const double activityInsetDefault = 8;
  static const double activityHeightShort = 0.45;
  static const double activityHeightTall = 0.67;
  final bool showDots;
  final String dotColorMode;
  final int dotColor;

  bool get isActivity => displayMode == modeActivity;

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

  /// 主卡頁面佔活動區可用寬度的比例。小於 1 時右側露出下一張。
  double get activityCardFraction => activityWidth.clamp(0.65, 0.95);

  double get activityGapPx => activitySpacing.clamp(4, 24);

  double get activityInsetPx => activityInset.clamp(0, 24);

  double get activityHeightRatio => activityHeightFactor.clamp(0.40, 0.80);

  String? get matchedActivityLayout {
    bool widthOf(double value) => (activityCardFraction - value).abs() <= 0.011;
    bool heightOf(double value) => (activityHeightRatio - value).abs() <= 0.011;
    bool pxOf(double value, double actual) => (actual - value).abs() <= 0.51;
    if (widthOf(0.72) &&
        heightOf(activityHeightShort) &&
        pxOf(8, activityGapPx) &&
        pxOf(16, activityInsetPx) &&
        activityRadius == radiusSmall) {
      return 'narrow';
    }
    if (widthOf(activityWidthDefault) &&
        heightOf(activityHeightDefault) &&
        pxOf(activityGapDefault, activityGapPx) &&
        pxOf(activityInsetDefault, activityInsetPx) &&
        activityRadius == radiusStandard) {
      return 'standard';
    }
    if (widthOf(0.92) &&
        heightOf(0.64) &&
        pxOf(10, activityGapPx) &&
        pxOf(4, activityInsetPx) &&
        activityRadius == radiusLarge) {
      return 'wide';
    }
    return null;
  }

  ModernBannerFrameSetting applyActivityLayout(String id) {
    return switch (id) {
      'narrow' => copyWith(
        activityWidth: 0.72,
        activityHeightFactor: activityHeightShort,
        activitySpacing: 8,
        activityInset: 16,
        activityRadius: radiusSmall,
      ),
      'wide' => copyWith(
        activityWidth: 0.92,
        activityHeightFactor: 0.64,
        activitySpacing: 10,
        activityInset: 4,
        activityRadius: radiusLarge,
      ),
      _ => copyWith(
        activityWidth: activityWidthDefault,
        activityHeightFactor: activityHeightDefault,
        activitySpacing: activityGapDefault,
        activityInset: activityInsetDefault,
        activityRadius: radiusStandard,
      ),
    };
  }

  double get activityRadiusPx {
    return switch (activityRadius) {
      radiusSmall => 10,
      radiusLarge => 24,
      _ => 16,
    };
  }

  double get sectionTitleGapPx {
    return switch (sectionTitleGap) {
      gapCompact => 8,
      gapRelaxed => 18,
      _ => 12,
    };
  }

  double get sectionTitleFontSize {
    return switch (sectionTitleSize) {
      sizeSmall => 15,
      sizeLarge => 20,
      _ => 17,
    };
  }

  FontWeight get sectionTitleFontWeight {
    return switch (sectionTitleWeight) {
      weightRegular => FontWeight.w400,
      weightMedium => FontWeight.w600,
      _ => FontWeight.w800,
    };
  }

  String? get appliedSectionFont {
    const List<String> fonts = <String>[
      'jfOpenHuninn',
      'NotoSansTC',
      'NotoSerifTC',
      'KleeOne',
      'ChironSungHK',
    ];
    return fonts.contains(sectionFontFamily) ? sectionFontFamily : null;
  }

  ModernBannerFrameSetting copyWith({
    HomeBannerWidthPreset? widthPreset,
    HomeBannerHeightPreset? heightPreset,
    String? bannerImageFit,
    String? bannerImageAlignment,
    String? displayMode,
    bool? showSectionTitle,
    String? sectionTitle,
    String? sectionFontFamily,
    String? sectionTitleSize,
    String? sectionTitleWeight,
    String? sectionTitleColorMode,
    int? sectionTitleColor,
    String? sectionTitleAlign,
    String? sectionTitleGap,
    String? activityScroll,
    int? activitySeconds,
    String? activityPeek,
    String? activityGap,
    double? activityWidth,
    double? activityHeightFactor,
    double? activitySpacing,
    double? activityInset,
    String? activityRadius,
    bool? showDots,
    String? dotColorMode,
    int? dotColor,
  }) {
    return ModernBannerFrameSetting(
      widthPreset: widthPreset ?? this.widthPreset,
      heightPreset: heightPreset ?? this.heightPreset,
      bannerImageFit: bannerImageFit ?? this.bannerImageFit,
      bannerImageAlignment: bannerImageAlignment ?? this.bannerImageAlignment,
      displayMode: displayMode ?? this.displayMode,
      showSectionTitle: showSectionTitle ?? this.showSectionTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      sectionFontFamily: sectionFontFamily ?? this.sectionFontFamily,
      sectionTitleSize: sectionTitleSize ?? this.sectionTitleSize,
      sectionTitleWeight: sectionTitleWeight ?? this.sectionTitleWeight,
      sectionTitleColorMode:
          sectionTitleColorMode ?? this.sectionTitleColorMode,
      sectionTitleColor: sectionTitleColor ?? this.sectionTitleColor,
      sectionTitleAlign: sectionTitleAlign ?? this.sectionTitleAlign,
      sectionTitleGap: sectionTitleGap ?? this.sectionTitleGap,
      activityScroll: activityScroll ?? this.activityScroll,
      activitySeconds: activitySeconds ?? this.activitySeconds,
      activityPeek: activityPeek ?? this.activityPeek,
      activityGap: activityGap ?? this.activityGap,
      activityWidth: activityWidth ?? this.activityWidth,
      activityHeightFactor: activityHeightFactor ?? this.activityHeightFactor,
      activitySpacing: activitySpacing ?? this.activitySpacing,
      activityInset: activityInset ?? this.activityInset,
      activityRadius: activityRadius ?? this.activityRadius,
      showDots: showDots ?? this.showDots,
      dotColorMode: dotColorMode ?? this.dotColorMode,
      dotColor: dotColor ?? this.dotColor,
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
      'homeBannerDisplayMode': displayMode == modeActivity
          ? modeActivity
          : modeClassic,
      'homeBannerShowSectionTitle': showSectionTitle,
      'homeBannerSectionTitle': sectionTitle,
      'homeBannerSectionFont': sectionFontFamily,
      'homeBannerSectionTitleSize': sectionTitleSize,
      'homeBannerSectionTitleWeight': sectionTitleWeight,
      'homeBannerSectionTitleColorMode': sectionTitleColorMode,
      'homeBannerSectionTitleColor': sectionTitleColor,
      'homeBannerSectionTitleAlign': sectionTitleAlign,
      'homeBannerSectionTitleGap': sectionTitleGap,
      'homeBannerActivityScroll': activityScroll,
      'homeBannerActivitySeconds': activitySeconds,
      'homeBannerActivityPeek': activityPeek,
      'homeBannerActivityGap': activityGap,
      'homeBannerActivityWidth': activityCardFraction,
      'homeBannerActivityHeight': activityHeightRatio,
      'homeBannerActivityGapPx': activityGapPx,
      'homeBannerActivityInset': activityInsetPx,
      'homeBannerActivityRadius': activityRadius,
      'homeBannerShowDots': showDots,
      'homeBannerDotColorMode': dotColorMode,
      'homeBannerDotColor': dotColor,
    };
  }

  factory ModernBannerFrameSetting.fromMap(Map<String, dynamic> map) {
    return ModernBannerFrameSetting(
      widthPreset: _parseWidth(map),
      heightPreset: _parseHeight(map),
      bannerImageFit: (map['bannerImageFit'] ?? fitFill).toString(),
      bannerImageAlignment: (map['bannerImageAlignment'] ?? alignCenter)
          .toString(),
      displayMode: map['homeBannerDisplayMode'] == modeActivity
          ? modeActivity
          : modeClassic,
      showSectionTitle: map['homeBannerShowSectionTitle'] == true,
      sectionTitle: _text(map['homeBannerSectionTitle'], '活動'),
      sectionFontFamily: (map['homeBannerSectionFont'] ?? '').toString(),
      sectionTitleSize: _choice(map['homeBannerSectionTitleSize'], <String>[
        sizeSmall,
        sizeMedium,
        sizeLarge,
      ], sizeMedium),
      sectionTitleWeight: _choice(map['homeBannerSectionTitleWeight'], <String>[
        weightRegular,
        weightMedium,
        weightBold,
      ], weightBold),
      sectionTitleColorMode:
          map['homeBannerSectionTitleColorMode'] == colorCustom
          ? colorCustom
          : colorTheme,
      sectionTitleColor: _color(map['homeBannerSectionTitleColor'], 0xFF3A2A20),
      sectionTitleAlign: _choice(map['homeBannerSectionTitleAlign'], <String>[
        alignStart,
        alignCenter,
        alignEnd,
      ], alignStart),
      sectionTitleGap: _choice(map['homeBannerSectionTitleGap'], <String>[
        gapCompact,
        gapStandard,
        gapRelaxed,
      ], gapStandard),
      activityScroll: map['homeBannerActivityScroll'] == scrollAuto
          ? scrollAuto
          : scrollManual,
      activitySeconds: _seconds(map['homeBannerActivitySeconds']),
      activityPeek: _choice(map['homeBannerActivityPeek'], <String>[
        peekSlight,
        peekStandard,
        peekStrong,
      ], peekStandard),
      activityGap: _choice(map['homeBannerActivityGap'], <String>[
        gapCompact,
        gapStandard,
        gapRelaxed,
      ], gapStandard),
      activityWidth: map.containsKey('homeBannerActivityWidth')
          ? _range(map['homeBannerActivityWidth'], 0.65, 0.95, 0.85)
          : _widthFromPeek(map['homeBannerActivityPeek']),
      activityHeightFactor: _range(
        map['homeBannerActivityHeight'],
        0.40,
        0.80,
        activityHeightDefault,
      ),
      activitySpacing: map.containsKey('homeBannerActivityGapPx')
          ? _range(map['homeBannerActivityGapPx'], 4, 24, activityGapDefault)
          : _gapFromPreset(map['homeBannerActivityGap']),
      activityInset: _range(
        map['homeBannerActivityInset'],
        0,
        24,
        activityInsetDefault,
      ),
      activityRadius: _choice(map['homeBannerActivityRadius'], <String>[
        radiusSmall,
        radiusStandard,
        radiusLarge,
      ], radiusStandard),
      showDots: map['homeBannerShowDots'] != false,
      dotColorMode: map['homeBannerDotColorMode'] == colorCustom
          ? colorCustom
          : colorTheme,
      dotColor: _color(map['homeBannerDotColor'], 0xFFA56B45),
    );
  }

  static String _text(Object? raw, String fallback) {
    final String value = raw?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static String _choice(Object? raw, List<String> allowed, String fallback) {
    final String value = raw?.toString().trim() ?? '';
    return allowed.contains(value) ? value : fallback;
  }

  static int _color(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
  }

  static double _range(Object? raw, double min, double max, double fallback) {
    final double? value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString().trim() ?? '');
    if (value == null || value.isNaN) {
      return fallback;
    }
    return value.clamp(min, max);
  }

  static double _widthFromPeek(Object? raw) {
    return switch (raw?.toString().trim()) {
      peekSlight => 0.90,
      peekStrong => 0.78,
      _ => 0.85,
    };
  }

  static double _gapFromPreset(Object? raw) {
    return switch (raw?.toString().trim()) {
      gapCompact => 8,
      gapRelaxed => 18,
      _ => 12,
    };
  }

  static int _seconds(Object? raw) {
    final int value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString().trim() ?? '') ?? 5;
    return switch (value) {
      3 => 3,
      8 => 8,
      _ => 5,
    };
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
        other.bannerImageAlignment == bannerImageAlignment &&
        other.displayMode == displayMode &&
        other.showSectionTitle == showSectionTitle &&
        other.sectionTitle == sectionTitle &&
        other.sectionFontFamily == sectionFontFamily &&
        other.sectionTitleSize == sectionTitleSize &&
        other.sectionTitleWeight == sectionTitleWeight &&
        other.sectionTitleColorMode == sectionTitleColorMode &&
        other.sectionTitleColor == sectionTitleColor &&
        other.sectionTitleAlign == sectionTitleAlign &&
        other.sectionTitleGap == sectionTitleGap &&
        other.activityScroll == activityScroll &&
        other.activitySeconds == activitySeconds &&
        other.activityPeek == activityPeek &&
        other.activityGap == activityGap &&
        other.activityWidth == activityWidth &&
        other.activityHeightFactor == activityHeightFactor &&
        other.activitySpacing == activitySpacing &&
        other.activityInset == activityInset &&
        other.activityRadius == activityRadius &&
        other.showDots == showDots &&
        other.dotColorMode == dotColorMode &&
        other.dotColor == dotColor;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    widthPreset,
    heightPreset,
    bannerImageFit,
    bannerImageAlignment,
    displayMode,
    showSectionTitle,
    sectionTitle,
    sectionFontFamily,
    sectionTitleSize,
    sectionTitleWeight,
    sectionTitleColorMode,
    sectionTitleColor,
    sectionTitleAlign,
    sectionTitleGap,
    activityScroll,
    activitySeconds,
    activityPeek,
    activityGap,
    activityWidth,
    activityHeightFactor,
    activitySpacing,
    activityInset,
    activityRadius,
    showDots,
    dotColorMode,
    dotColor,
  ]);

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
