import 'package:flutter/material.dart';

/// 首頁展示卡片的共用外觀。存在 homeAppearance.modern.displayStyle。
///
/// 沒有這份資料時，各區塊繼續用自己原本的樣式，不會被新預設蓋掉。
class HomeDisplayTextPositions {
  static const String above = 'above';
  static const String overlay = 'overlay';
  static const String below = 'below';
  static const List<String> all = <String>[above, overlay, below];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : below;
  }
}

class HomeDisplaySizes {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
  static const List<String> all = <String>[small, medium, large];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : medium;
  }
}

class HomeDisplayWeights {
  static const String regular = 'regular';
  static const String medium = 'medium';
  static const String bold = 'bold';
  static const List<String> all = <String>[regular, medium, bold];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : bold;
  }
}

class HomeDisplayAligns {
  static const String start = 'start';
  static const String center = 'center';
  static const String end = 'end';
  static const List<String> all = <String>[start, center, end];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : start;
  }
}

class HomeDisplayColorModes {
  static const String unified = 'unified';
  static const String separate = 'separate';

  static String migrate(Object? raw) {
    return raw == separate ? separate : unified;
  }
}

class HomeDisplaySpacings {
  static const String compact = 'compact';
  static const String normal = 'normal';
  static const String relaxed = 'relaxed';
  static const List<String> all = <String>[compact, normal, relaxed];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : normal;
  }

  static double gap(String value) {
    switch (migrate(value)) {
      case compact:
        return 4;
      case relaxed:
        return 14;
      default:
        return 8;
    }
  }
}

class HomeDisplayBackgrounds {
  static const String filled = 'filled';
  static const String outlined = 'outlined';
  static const String transparent = 'transparent';
  static const List<String> all = <String>[filled, outlined, transparent];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : filled;
  }
}

class HomeDisplayRadii {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
  static const List<String> all = <String>[small, medium, large];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : medium;
  }

  static double pixels(String value) {
    switch (migrate(value)) {
      case small:
        return 10;
      case large:
        return 22;
      default:
        return 16;
    }
  }
}

class HomeDisplayFits {
  static const String cover = 'cover';
  static const String contain = 'contain';

  static String migrate(Object? raw) {
    return raw == contain ? contain : cover;
  }
}

class HomeDisplayShadows {
  static const String none = 'none';
  static const String soft = 'soft';
  static const String strong = 'strong';

  static String migrate(Object? raw) {
    return switch (raw?.toString().trim()) {
      soft => soft,
      strong => strong,
      _ => none,
    };
  }
}

class HomeDisplayMasks {
  static const String none = 'none';
  static const String light = 'light';
  static const String strong = 'strong';
  static const List<String> all = <String>[none, light, strong];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : none;
  }
}

class HomeDisplayStyleModes {
  static const String inherit = 'inherit';
  static const String custom = 'custom';
}

class HomeDisplaySections {
  static const String rooms = 'rooms';
  static const String facilities = 'facilities';
  static const String about = 'about';
  static const String announcements = 'announcements';
  static const String reviews = 'reviews';
  static const String featured = 'featured';
  static const List<String> all = <String>[
    rooms,
    facilities,
    about,
    announcements,
    reviews,
    featured,
  ];

  static String label(String id) {
    switch (id) {
      case facilities:
        return '環境介紹';
      case about:
        return '關於我們';
      case announcements:
        return '消息展示';
      case reviews:
        return '顧客評價';
      case featured:
        return '精選商品';
      default:
        return '房型介紹';
    }
  }
}

class HomeDisplayStyle {
  const HomeDisplayStyle({
    this.textPosition = HomeDisplayTextPositions.below,
    this.titleSize = HomeDisplaySizes.medium,
    this.titleWeight = HomeDisplayWeights.bold,
    this.titleAlign = HomeDisplayAligns.start,
    this.titleColor = 0xFF3A2A20,
    this.bodySize = HomeDisplaySizes.small,
    this.bodyWeight = HomeDisplayWeights.medium,
    this.bodyAlign = HomeDisplayAligns.start,
    this.bodyColor = 0xFF8A7568,
    this.colorMode = HomeDisplayColorModes.unified,
    this.spacing = HomeDisplaySpacings.normal,
    this.cardBackground = HomeDisplayBackgrounds.filled,
    this.cardRadius = HomeDisplayRadii.medium,
    this.cardBorder = true,
    this.cardShadow = HomeDisplayShadows.none,
    this.imageAspect = 'square',
    this.imageRadius = HomeDisplayRadii.medium,
    this.imageFit = HomeDisplayFits.cover,
    this.cardPadding = HomeDisplaySpacings.normal,
    this.cardGap = HomeDisplaySpacings.normal,
    this.imageMask = HomeDisplayMasks.none,
  });

  static const HomeDisplayStyle classic = HomeDisplayStyle();

  /// 房型簡約入口原本的預設：文字在圖片下方、置中。
  static const HomeDisplayStyle roomsBaseline = HomeDisplayStyle(
    titleAlign: HomeDisplayAligns.center,
    bodyAlign: HomeDisplayAligns.center,
  );

  /// 環境照片卡原本的預設是文字蓋在圖片上。
  static const HomeDisplayStyle facilitiesBaseline = HomeDisplayStyle(
    textPosition: HomeDisplayTextPositions.overlay,
  );

  final String textPosition;
  final String titleSize;
  final String titleWeight;
  final String titleAlign;
  final int titleColor;
  final String bodySize;
  final String bodyWeight;
  final String bodyAlign;
  final int bodyColor;
  final String colorMode;
  final String spacing;
  final String cardBackground;
  final String cardRadius;
  final bool cardBorder;
  final String cardShadow;
  final String imageAspect;
  final String imageRadius;
  final String imageFit;
  final String cardPadding;
  final String cardGap;
  final String imageMask;

  int get effectiveBodyColor {
    return colorMode == HomeDisplayColorModes.separate ? bodyColor : titleColor;
  }

  HomeDisplayStyle copyWith({
    String? textPosition,
    String? titleSize,
    String? titleWeight,
    String? titleAlign,
    int? titleColor,
    String? bodySize,
    String? bodyWeight,
    String? bodyAlign,
    int? bodyColor,
    String? colorMode,
    String? spacing,
    String? cardBackground,
    String? cardRadius,
    bool? cardBorder,
    String? cardShadow,
    String? imageAspect,
    String? imageRadius,
    String? imageFit,
    String? cardPadding,
    String? cardGap,
    String? imageMask,
  }) {
    return HomeDisplayStyle(
      textPosition: textPosition ?? this.textPosition,
      titleSize: titleSize ?? this.titleSize,
      titleWeight: titleWeight ?? this.titleWeight,
      titleAlign: titleAlign ?? this.titleAlign,
      titleColor: titleColor ?? this.titleColor,
      bodySize: bodySize ?? this.bodySize,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      bodyAlign: bodyAlign ?? this.bodyAlign,
      bodyColor: bodyColor ?? this.bodyColor,
      colorMode: colorMode ?? this.colorMode,
      spacing: spacing ?? this.spacing,
      cardBackground: cardBackground ?? this.cardBackground,
      cardRadius: cardRadius ?? this.cardRadius,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      imageAspect: imageAspect ?? this.imageAspect,
      imageRadius: imageRadius ?? this.imageRadius,
      imageFit: imageFit ?? this.imageFit,
      cardPadding: cardPadding ?? this.cardPadding,
      cardGap: cardGap ?? this.cardGap,
      imageMask: imageMask ?? this.imageMask,
    );
  }

  HomeDisplayStyle apply(HomeDisplayStyleOverride override) {
    return copyWith(
      textPosition: override.textPosition,
      titleSize: override.titleSize,
      titleWeight: override.titleWeight,
      titleAlign: override.titleAlign,
      titleColor: override.titleColor,
      bodySize: override.bodySize,
      bodyWeight: override.bodyWeight,
      bodyAlign: override.bodyAlign,
      bodyColor: override.bodyColor,
      colorMode: override.colorMode,
      spacing: override.spacing,
      cardBackground: override.cardBackground,
      cardRadius: override.cardRadius,
      cardBorder: override.cardBorder,
      cardShadow: override.cardShadow,
      imageAspect: override.imageAspect,
      imageRadius: override.imageRadius,
      imageFit: override.imageFit,
      cardPadding: override.cardPadding,
      cardGap: override.cardGap,
      imageMask: override.imageMask,
    );
  }

  bool sameLook(HomeDisplayStyle other) {
    return textPosition == other.textPosition &&
        titleSize == other.titleSize &&
        titleWeight == other.titleWeight &&
        titleAlign == other.titleAlign &&
        titleColor == other.titleColor &&
        bodySize == other.bodySize &&
        bodyWeight == other.bodyWeight &&
        bodyAlign == other.bodyAlign &&
        bodyColor == other.bodyColor &&
        colorMode == other.colorMode &&
        spacing == other.spacing &&
        cardBackground == other.cardBackground &&
        cardRadius == other.cardRadius &&
        cardBorder == other.cardBorder &&
        cardShadow == other.cardShadow &&
        imageAspect == other.imageAspect &&
        imageRadius == other.imageRadius &&
        imageFit == other.imageFit &&
        cardPadding == other.cardPadding &&
        cardGap == other.cardGap &&
        imageMask == other.imageMask;
  }

  /// 只留下和 [base] 不同的項目，其餘繼續跟共用樣式。
  HomeDisplayStyleOverride diff(HomeDisplayStyle base) {
    return HomeDisplayStyleOverride(
      textPosition: textPosition == base.textPosition ? null : textPosition,
      titleSize: titleSize == base.titleSize ? null : titleSize,
      titleWeight: titleWeight == base.titleWeight ? null : titleWeight,
      titleAlign: titleAlign == base.titleAlign ? null : titleAlign,
      titleColor: titleColor == base.titleColor ? null : titleColor,
      bodySize: bodySize == base.bodySize ? null : bodySize,
      bodyWeight: bodyWeight == base.bodyWeight ? null : bodyWeight,
      bodyAlign: bodyAlign == base.bodyAlign ? null : bodyAlign,
      bodyColor: bodyColor == base.bodyColor ? null : bodyColor,
      colorMode: colorMode == base.colorMode ? null : colorMode,
      spacing: spacing == base.spacing ? null : spacing,
      cardBackground: cardBackground == base.cardBackground
          ? null
          : cardBackground,
      cardRadius: cardRadius == base.cardRadius ? null : cardRadius,
      cardBorder: cardBorder == base.cardBorder ? null : cardBorder,
      cardShadow: cardShadow == base.cardShadow ? null : cardShadow,
      imageAspect: imageAspect == base.imageAspect ? null : imageAspect,
      imageRadius: imageRadius == base.imageRadius ? null : imageRadius,
      imageFit: imageFit == base.imageFit ? null : imageFit,
      cardPadding: cardPadding == base.cardPadding ? null : cardPadding,
      cardGap: cardGap == base.cardGap ? null : cardGap,
      imageMask: imageMask == base.imageMask ? null : imageMask,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'textPosition': HomeDisplayTextPositions.migrate(textPosition),
      'titleSize': HomeDisplaySizes.migrate(titleSize),
      'titleWeight': HomeDisplayWeights.migrate(titleWeight),
      'titleAlign': HomeDisplayAligns.migrate(titleAlign),
      'titleColor': titleColor,
      'bodySize': HomeDisplaySizes.migrate(bodySize),
      'bodyWeight': HomeDisplayWeights.migrate(bodyWeight),
      'bodyAlign': HomeDisplayAligns.migrate(bodyAlign),
      'bodyColor': bodyColor,
      'colorMode': HomeDisplayColorModes.migrate(colorMode),
      'spacing': HomeDisplaySpacings.migrate(spacing),
      'cardBackground': HomeDisplayBackgrounds.migrate(cardBackground),
      'cardRadius': HomeDisplayRadii.migrate(cardRadius),
      'cardBorder': cardBorder,
      'cardShadow': HomeDisplayShadows.migrate(cardShadow),
      'imageAspect': imageAspect,
      'imageRadius': HomeDisplayRadii.migrate(imageRadius),
      'imageFit': HomeDisplayFits.migrate(imageFit),
      'cardPadding': HomeDisplaySpacings.migrate(cardPadding),
      'cardGap': HomeDisplaySpacings.migrate(cardGap),
      'imageMask': HomeDisplayMasks.migrate(imageMask),
    };
  }

  static HomeDisplayStyle fromMap(Object? raw) {
    if (raw is! Map) {
      return classic;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return classic.copyWith(
      textPosition: HomeDisplayTextPositions.migrate(map['textPosition']),
      titleSize: HomeDisplaySizes.migrate(map['titleSize']),
      titleWeight: HomeDisplayWeights.migrate(map['titleWeight']),
      titleAlign: HomeDisplayAligns.migrate(map['titleAlign']),
      titleColor: _color(map['titleColor'], classic.titleColor),
      bodySize: HomeDisplaySizes.migrate(map['bodySize']),
      bodyWeight: HomeDisplayWeights.migrate(map['bodyWeight']),
      bodyAlign: HomeDisplayAligns.migrate(map['bodyAlign']),
      bodyColor: _color(map['bodyColor'], classic.bodyColor),
      colorMode: HomeDisplayColorModes.migrate(map['colorMode']),
      spacing: HomeDisplaySpacings.migrate(map['spacing']),
      cardBackground: HomeDisplayBackgrounds.migrate(map['cardBackground']),
      cardRadius: HomeDisplayRadii.migrate(map['cardRadius']),
      cardBorder: map['cardBorder'] is bool
          ? map['cardBorder'] as bool
          : classic.cardBorder,
      cardShadow: HomeDisplayShadows.migrate(map['cardShadow']),
      imageAspect: _aspect(map['imageAspect']),
      imageRadius: HomeDisplayRadii.migrate(map['imageRadius']),
      imageFit: HomeDisplayFits.migrate(map['imageFit']),
      cardPadding: HomeDisplaySpacings.migrate(map['cardPadding']),
      cardGap: HomeDisplaySpacings.migrate(map['cardGap']),
      imageMask: HomeDisplayMasks.migrate(map['imageMask']),
    );
  }
}

class HomeDisplayStyleOverride {
  const HomeDisplayStyleOverride({
    this.textPosition,
    this.titleSize,
    this.titleWeight,
    this.titleAlign,
    this.titleColor,
    this.bodySize,
    this.bodyWeight,
    this.bodyAlign,
    this.bodyColor,
    this.colorMode,
    this.spacing,
    this.cardBackground,
    this.cardRadius,
    this.cardBorder,
    this.cardShadow,
    this.imageAspect,
    this.imageRadius,
    this.imageFit,
    this.cardPadding,
    this.cardGap,
    this.imageMask,
  });

  final String? textPosition;
  final String? titleSize;
  final String? titleWeight;
  final String? titleAlign;
  final int? titleColor;
  final String? bodySize;
  final String? bodyWeight;
  final String? bodyAlign;
  final int? bodyColor;
  final String? colorMode;
  final String? spacing;
  final String? cardBackground;
  final String? cardRadius;
  final bool? cardBorder;
  final String? cardShadow;
  final String? imageAspect;
  final String? imageRadius;
  final String? imageFit;
  final String? cardPadding;
  final String? cardGap;
  final String? imageMask;

  bool get isEmpty => toMap().isEmpty;

  HomeDisplayStyleOverride merge(HomeDisplayStyleOverride next) {
    return HomeDisplayStyleOverride(
      textPosition: next.textPosition ?? textPosition,
      titleSize: next.titleSize ?? titleSize,
      titleWeight: next.titleWeight ?? titleWeight,
      titleAlign: next.titleAlign ?? titleAlign,
      titleColor: next.titleColor ?? titleColor,
      bodySize: next.bodySize ?? bodySize,
      bodyWeight: next.bodyWeight ?? bodyWeight,
      bodyAlign: next.bodyAlign ?? bodyAlign,
      bodyColor: next.bodyColor ?? bodyColor,
      colorMode: next.colorMode ?? colorMode,
      spacing: next.spacing ?? spacing,
      cardBackground: next.cardBackground ?? cardBackground,
      cardRadius: next.cardRadius ?? cardRadius,
      cardBorder: next.cardBorder ?? cardBorder,
      cardShadow: next.cardShadow ?? cardShadow,
      imageAspect: next.imageAspect ?? imageAspect,
      imageRadius: next.imageRadius ?? imageRadius,
      imageFit: next.imageFit ?? imageFit,
      cardPadding: next.cardPadding ?? cardPadding,
      cardGap: next.cardGap ?? cardGap,
      imageMask: next.imageMask ?? imageMask,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (textPosition != null) 'textPosition': textPosition,
      if (titleSize != null) 'titleSize': titleSize,
      if (titleWeight != null) 'titleWeight': titleWeight,
      if (titleAlign != null) 'titleAlign': titleAlign,
      if (titleColor != null) 'titleColor': titleColor,
      if (bodySize != null) 'bodySize': bodySize,
      if (bodyWeight != null) 'bodyWeight': bodyWeight,
      if (bodyAlign != null) 'bodyAlign': bodyAlign,
      if (bodyColor != null) 'bodyColor': bodyColor,
      if (colorMode != null) 'colorMode': colorMode,
      if (spacing != null) 'spacing': spacing,
      if (cardBackground != null) 'cardBackground': cardBackground,
      if (cardRadius != null) 'cardRadius': cardRadius,
      if (cardBorder != null) 'cardBorder': cardBorder,
      if (cardShadow != null) 'cardShadow': cardShadow,
      if (imageAspect != null) 'imageAspect': imageAspect,
      if (imageRadius != null) 'imageRadius': imageRadius,
      if (imageFit != null) 'imageFit': imageFit,
      if (cardPadding != null) 'cardPadding': cardPadding,
      if (cardGap != null) 'cardGap': cardGap,
      if (imageMask != null) 'imageMask': imageMask,
    };
  }

  static HomeDisplayStyleOverride fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeDisplayStyleOverride();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return HomeDisplayStyleOverride(
      textPosition: _optional(
        map,
        'textPosition',
        HomeDisplayTextPositions.migrate,
      ),
      titleSize: _optional(map, 'titleSize', HomeDisplaySizes.migrate),
      titleWeight: _optional(map, 'titleWeight', HomeDisplayWeights.migrate),
      titleAlign: _optional(map, 'titleAlign', HomeDisplayAligns.migrate),
      titleColor: map.containsKey('titleColor')
          ? _color(map['titleColor'], 0)
          : null,
      bodySize: _optional(map, 'bodySize', HomeDisplaySizes.migrate),
      bodyWeight: _optional(map, 'bodyWeight', HomeDisplayWeights.migrate),
      bodyAlign: _optional(map, 'bodyAlign', HomeDisplayAligns.migrate),
      bodyColor: map.containsKey('bodyColor')
          ? _color(map['bodyColor'], 0)
          : null,
      colorMode: _optional(map, 'colorMode', HomeDisplayColorModes.migrate),
      spacing: _optional(map, 'spacing', HomeDisplaySpacings.migrate),
      cardBackground: _optional(
        map,
        'cardBackground',
        HomeDisplayBackgrounds.migrate,
      ),
      cardRadius: _optional(map, 'cardRadius', HomeDisplayRadii.migrate),
      cardBorder: map['cardBorder'] is bool ? map['cardBorder'] as bool : null,
      cardShadow: _optional(map, 'cardShadow', HomeDisplayShadows.migrate),
      imageAspect: map.containsKey('imageAspect')
          ? _aspect(map['imageAspect'])
          : null,
      imageRadius: _optional(map, 'imageRadius', HomeDisplayRadii.migrate),
      imageFit: _optional(map, 'imageFit', HomeDisplayFits.migrate),
      cardPadding: _optional(map, 'cardPadding', HomeDisplaySpacings.migrate),
      cardGap: _optional(map, 'cardGap', HomeDisplaySpacings.migrate),
      imageMask: _optional(map, 'imageMask', HomeDisplayMasks.migrate),
    );
  }
}

class HomeDisplaySectionChoice {
  const HomeDisplaySectionChoice({
    this.mode,
    this.override = const HomeDisplayStyleOverride(),
  });

  final String? mode;
  final HomeDisplayStyleOverride override;
}

class HomeDisplayStyleSetting {
  const HomeDisplayStyleSetting({
    this.saved = false,
    this.style = HomeDisplayStyle.classic,
    this.sections = const <String, HomeDisplaySectionChoice>{},
  });

  static const String mapKey = 'displayStyle';
  static const HomeDisplayStyleSetting unset = HomeDisplayStyleSetting();

  final bool saved;
  final HomeDisplayStyle style;
  final Map<String, HomeDisplaySectionChoice> sections;

  HomeDisplayStyleSetting copyWith({
    bool? saved,
    HomeDisplayStyle? style,
    Map<String, HomeDisplaySectionChoice>? sections,
  }) {
    return HomeDisplayStyleSetting(
      saved: saved ?? this.saved,
      style: style ?? this.style,
      sections: sections ?? this.sections,
    );
  }

  HomeDisplayStyleSetting updateSection(
    String sectionId, {
    String? mode,
    HomeDisplayStyleOverride? override,
    bool clearOverride = false,
  }) {
    final Map<String, HomeDisplaySectionChoice> next =
        Map<String, HomeDisplaySectionChoice>.from(sections);
    final HomeDisplaySectionChoice current =
        next[sectionId] ?? const HomeDisplaySectionChoice();
    next[sectionId] = HomeDisplaySectionChoice(
      mode: mode ?? current.mode,
      override: clearOverride
          ? const HomeDisplayStyleOverride()
          : override ?? current.override,
    );
    return copyWith(saved: true, sections: next);
  }

  String effectiveMode({
    required String sectionId,
    required HomeDisplayStyle legacy,
    required HomeDisplayStyle baseline,
  }) {
    final String? mode = sections[sectionId]?.mode;
    if (mode == HomeDisplayStyleModes.inherit ||
        mode == HomeDisplayStyleModes.custom) {
      return mode!;
    }
    return legacy.sameLook(baseline)
        ? HomeDisplayStyleModes.inherit
        : HomeDisplayStyleModes.custom;
  }

  /// 正式前台與預覽都走這裡。
  /// [saved] 為 false 時直接回傳區塊原本的樣子。
  HomeDisplayStyle resolve({
    required String sectionId,
    required HomeDisplayStyle legacy,
    required HomeDisplayStyle baseline,
  }) {
    if (!saved) {
      return legacy;
    }
    final HomeDisplaySectionChoice? choice = sections[sectionId];
    if (choice?.mode == HomeDisplayStyleModes.inherit) {
      return style;
    }
    if (choice?.mode == HomeDisplayStyleModes.custom) {
      return style.apply(choice?.override ?? const HomeDisplayStyleOverride());
    }
    return style.apply(legacy.diff(baseline));
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      ...style.toMap(),
      'sections': <String, dynamic>{
        for (final MapEntry<String, HomeDisplaySectionChoice> entry
            in sections.entries)
          entry.key: <String, dynamic>{
            if (entry.value.mode != null) 'mode': entry.value.mode,
            ...entry.value.override.toMap(),
          },
      },
    };
  }

  static HomeDisplayStyleSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return unset;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final Map<String, HomeDisplaySectionChoice> sections =
        <String, HomeDisplaySectionChoice>{};
    final Object? rawSections = map['sections'];
    if (rawSections is Map) {
      rawSections.forEach((Object? key, Object? value) {
        final String id = key.toString().trim();
        if (!HomeDisplaySections.all.contains(id) || value is! Map) {
          return;
        }
        final Map<String, dynamic> section = Map<String, dynamic>.from(value);
        final Object? mode = section['mode'];
        sections[id] = HomeDisplaySectionChoice(
          mode:
              mode == HomeDisplayStyleModes.custom ||
                  mode == HomeDisplayStyleModes.inherit
              ? mode.toString()
              : null,
          override: HomeDisplayStyleOverride.fromMap(section),
        );
      });
    }
    return HomeDisplayStyleSetting(
      saved: true,
      style: HomeDisplayStyle.fromMap(map),
      sections: sections,
    );
  }
}

double homeDisplayFontSize(String size, {required double fallback}) {
  switch (HomeDisplaySizes.migrate(size)) {
    case HomeDisplaySizes.small:
      return (fallback - 2).clamp(11, 28);
    case HomeDisplaySizes.large:
      return (fallback + 3).clamp(11, 28);
    default:
      return fallback;
  }
}

FontWeight homeDisplayFontWeight(String weight) {
  switch (HomeDisplayWeights.migrate(weight)) {
    case HomeDisplayWeights.regular:
      return FontWeight.w400;
    case HomeDisplayWeights.medium:
      return FontWeight.w600;
    default:
      return FontWeight.w800;
  }
}

TextAlign homeDisplayTextAlign(String align) {
  switch (HomeDisplayAligns.migrate(align)) {
    case HomeDisplayAligns.center:
      return TextAlign.center;
    case HomeDisplayAligns.end:
      return TextAlign.end;
    default:
      return TextAlign.start;
  }
}

CrossAxisAlignment homeDisplayCrossAlign(String align) {
  switch (HomeDisplayAligns.migrate(align)) {
    case HomeDisplayAligns.center:
      return CrossAxisAlignment.center;
    case HomeDisplayAligns.end:
      return CrossAxisAlignment.end;
    default:
      return CrossAxisAlignment.start;
  }
}

int _color(Object? raw, int fallback) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return fallback;
}

String _aspect(Object? raw) {
  final String value = raw?.toString().trim() ?? '';
  if (value == 'portrait' || value == 'landscape' || value == 'square') {
    return value;
  }
  return 'square';
}

String? _optional(
  Map<String, dynamic> map,
  String key,
  String Function(Object?) migrate,
) {
  if (!map.containsKey(key)) {
    return null;
  }
  return migrate(map[key]);
}
