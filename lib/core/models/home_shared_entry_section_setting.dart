import 'package:petnest_saas/core/models/home_display_style.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';

/// 首頁共用精緻小卡區。存在 shops/{shopId}.homeAppearance.modern.sharedEntrySection。
///
/// 這裡只記區域開關、標題、每排張數與加入順序。
/// 卡片圖片、文字與外觀仍留在各功能自己的設定。
class HomeSharedEntrySources {
  const HomeSharedEntrySources._();

  static const String rooms = 'rooms';
  static const String facilities = 'facilities';
  static const String about = 'about';
  static const String announcements = 'announcements';
  static const String quickBooking = 'quickBooking';
  static const String policy = 'policy';
  static const String faq = 'faq';
  static const String reviews = 'reviews';

  /// 有既有顧客頁面、可以做成入口卡的功能。
  static const List<String> joinable = <String>[
    rooms,
    facilities,
    about,
    announcements,
    quickBooking,
    policy,
    faq,
    reviews,
  ];

  static bool canJoin(String sourceId) => joinable.contains(sourceId);

  static String label(String sourceId) {
    switch (sourceId) {
      case rooms:
        return '房型介紹';
      case facilities:
        return '環境介紹';
      case about:
        return '關於我們';
      case announcements:
        return '最新消息';
      case quickBooking:
        return '快捷預約';
      case policy:
        return '入住須知';
      case faq:
        return '常見問題';
      case reviews:
        return '顧客評價';
      default:
        return sourceId;
    }
  }
}

/// 精緻小卡的文字落點。圖片下方與圖片外下方是兩種效果。
class HomeSharedEntryPlacements {
  const HomeSharedEntryPlacements._();

  static const String above = 'above';
  static const String center = 'center';
  static const String insideBottom = 'insideBottom';
  static const String outsideBelow = 'outsideBelow';
  static const List<String> all = <String>[
    above,
    center,
    insideBottom,
    outsideBelow,
  ];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : outsideBelow;
  }

  static String label(String value) {
    switch (migrate(value)) {
      case above:
        return '圖片上方';
      case center:
        return '圖片中央';
      case insideBottom:
        return '圖片內下方';
      default:
        return '圖片外下方';
    }
  }
}

/// 精緻小卡區的每排張數。舊資料的 4 張會收成 3 張，避免載入失敗。
int sharedEntryColumns(Object? raw) {
  final int value = raw is num
      ? raw.toInt()
      : int.tryParse(raw?.toString().trim() ?? '') ?? 3;
  if (value == 1 || value == 2) {
    return value;
  }
  return 3;
}

class HomeSharedEntryOverflows {
  const HomeSharedEntryOverflows._();

  static const String wrap = 'wrap';
  static const String scroll = 'scroll';

  static String migrate(Object? raw) {
    return raw?.toString().trim() == scroll ? scroll : wrap;
  }
}

class HomeSharedEntryImageScales {
  const HomeSharedEntryImageScales._();

  static const String small = 'small';
  static const String standard = 'standard';
  static const String large = 'large';
  static const List<String> all = <String>[small, standard, large];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : standard;
  }

  static double factor(Object? raw) {
    if (raw is num) {
      return raw.toDouble().clamp(0.7, 1);
    }
    return switch (migrate(raw)) {
      small => 0.82,
      large => 1,
      _ => 0.9,
    };
  }

  static String label(String value) {
    return switch (migrate(value)) {
      small => '精緻小',
      large => '稍大',
      _ => '標準',
    };
  }
}

class HomeSharedEntryDensities {
  const HomeSharedEntryDensities._();

  static const String compact = 'compact';
  static const String standard = 'standard';
  static const String relaxed = 'relaxed';
  static const List<String> all = <String>[compact, standard, relaxed];

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    return all.contains(value) ? value : standard;
  }

  static String label(String value) {
    return switch (migrate(value)) {
      compact => '緊湊',
      relaxed => '寬鬆',
      _ => '標準',
    };
  }
}

double sharedEntrySpacing(
  Object? raw, {
  required double fallback,
  required double compact,
  required double standard,
  required double relaxed,
  double min = 0,
  double max = 40,
}) {
  if (raw is num) {
    return raw.toDouble().clamp(min, max);
  }
  return switch (raw?.toString().trim()) {
    HomeSharedEntryDensities.compact => compact,
    HomeSharedEntryDensities.relaxed => relaxed,
    HomeSharedEntryDensities.standard => standard,
    _ => fallback,
  };
}

double sharedEntryIconSize(Object? raw) {
  if (raw is num) {
    return raw.toDouble().clamp(28, 72);
  }
  return 44;
}

class HomeSharedEntryPresets {
  const HomeSharedEntryPresets._();

  static const String compact = 'compact';
  static const String airy = 'airy';
  static const String custom = 'custom';

  /// 尺寸改版前的緊湊感：圖片滿欄、間距 8、沒有額外左右留白。
  /// 不是從舊版檔案還原的逐欄位紀錄。
  static const HomeSharedEntryStyle compactStyle = HomeSharedEntryStyle(
    imageScale: 1,
    gapX: 8,
    gapY: 8,
    gapText: 6,
    insetX: 0,
    iconSize: 40,
    radius: HomeRoomSimpleRadii.medium,
    showBorder: true,
    cardShadow: HomeDisplayShadows.none,
  );

  static const HomeSharedEntryStyle airyStyle = HomeSharedEntryStyle(
    imageScale: 0.86,
    gapX: 16,
    gapY: 18,
    gapText: 12,
    insetX: 12,
    iconSize: 52,
    radius: HomeRoomSimpleRadii.large,
    showBorder: false,
    cardShadow: HomeDisplayShadows.none,
  );

  static HomeSharedEntryStyle apply(
    HomeSharedEntryStyle current,
    String preset,
  ) {
    final HomeSharedEntryStyle next = preset == airy ? airyStyle : compactStyle;
    return current.copyWith(
      imageScale: next.imageScale,
      gapX: next.gapX,
      gapY: next.gapY,
      gapText: next.gapText,
      insetX: next.insetX,
      iconSize: next.iconSize,
      radius: next.radius,
      showBorder: next.showBorder,
      cardShadow: next.cardShadow,
    );
  }

  static String match(HomeSharedEntryStyle style) {
    if (_sameMetrics(style, compactStyle)) {
      return compact;
    }
    if (_sameMetrics(style, airyStyle)) {
      return airy;
    }
    return custom;
  }

  static bool _sameMetrics(
    HomeSharedEntryStyle style,
    HomeSharedEntryStyle preset,
  ) {
    return (style.imageScale - preset.imageScale).abs() < 0.011 &&
        (style.gapX - preset.gapX).abs() < 0.51 &&
        (style.gapY - preset.gapY).abs() < 0.51 &&
        (style.gapText - preset.gapText).abs() < 0.51 &&
        (style.insetX - preset.insetX).abs() < 0.51 &&
        (style.iconSize - preset.iconSize).abs() < 0.51 &&
        style.radius == preset.radius &&
        style.showBorder == preset.showBorder &&
        style.cardShadow == preset.cardShadow;
  }
}

/// 間距用邏輯像素，並依這一列的寬度稍微縮放，避免寫死桌機像素。
double sharedEntryMeasure(
  Object? density,
  double width, {
  required double compact,
  required double standard,
  required double relaxed,
}) {
  final double base = switch (HomeSharedEntryDensities.migrate(density)) {
    HomeSharedEntryDensities.compact => compact,
    HomeSharedEntryDensities.relaxed => relaxed,
    _ => standard,
  };
  final double scale = !width.isFinite || width <= 0
      ? 1
      : (width / 360).clamp(0.92, 1.08);
  return base * scale;
}

class HomeSharedEntryColorModes {
  const HomeSharedEntryColorModes._();

  static const String theme = 'theme';
  static const String custom = 'custom';

  static String migrate(Object? raw) {
    return raw?.toString().trim() == custom ? custom : theme;
  }
}

/// 小卡區共用的外觀。只影響精緻小卡，不套到房型列表或環境照片。
class HomeSharedEntryStyle {
  const HomeSharedEntryStyle({
    this.fontFamily = '',
    this.titleSize = HomeRoomSimpleTextSizes.medium,
    this.bodySize = HomeRoomSimpleTextSizes.small,
    this.titleWeight = HomeRoomSimpleTextWeights.bold,
    this.bodyWeight = HomeRoomSimpleTextWeights.medium,
    this.textAlign = 'start',
    this.textPlacement = HomeSharedEntryPlacements.outsideBelow,
    this.aspect = HomeRoomSimpleAspects.square,
    this.imageFit = 'cover',
    this.radius = HomeRoomSimpleRadii.medium,
    this.mask = HomeRoomSimpleMasks.none,
    this.surface = HomeRoomSimpleSurfaces.filled,
    this.showBorder = true,
    this.cardShadow = HomeDisplayShadows.none,
    this.textScrim = true,
    this.imageScale = 0.9,
    this.gapX = 12,
    this.gapY = 14,
    this.gapText = 8,
    this.insetX = 8,
    this.iconSize = 44,
  });

  final String fontFamily;
  final String titleSize;
  final String bodySize;
  final String titleWeight;
  final String bodyWeight;
  final String textAlign;
  final String textPlacement;
  final String aspect;
  final String imageFit;
  final String radius;
  final String mask;
  final String surface;
  final bool showBorder;
  final String cardShadow;
  final bool textScrim;
  final double imageScale;
  final double gapX;
  final double gapY;
  final double gapText;
  final double insetX;
  final double iconSize;

  String? get appliedFontFamily {
    final String value = fontFamily.trim();
    if (HomeRoomSectionSetting.fontFamilies.contains(value)) {
      return value;
    }
    return null;
  }

  HomeSharedEntryStyle copyWith({
    String? fontFamily,
    String? titleSize,
    String? bodySize,
    String? titleWeight,
    String? bodyWeight,
    String? textAlign,
    String? textPlacement,
    String? aspect,
    String? imageFit,
    String? radius,
    String? mask,
    String? surface,
    bool? showBorder,
    String? cardShadow,
    bool? textScrim,
    double? imageScale,
    double? gapX,
    double? gapY,
    double? gapText,
    double? insetX,
    double? iconSize,
  }) {
    return HomeSharedEntryStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      titleSize: titleSize ?? this.titleSize,
      bodySize: bodySize ?? this.bodySize,
      titleWeight: titleWeight ?? this.titleWeight,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      textAlign: textAlign ?? this.textAlign,
      textPlacement: textPlacement ?? this.textPlacement,
      aspect: aspect ?? this.aspect,
      imageFit: imageFit ?? this.imageFit,
      radius: radius ?? this.radius,
      mask: mask ?? this.mask,
      surface: surface ?? this.surface,
      showBorder: showBorder ?? this.showBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      textScrim: textScrim ?? this.textScrim,
      imageScale: imageScale ?? this.imageScale,
      gapX: gapX ?? this.gapX,
      gapY: gapY ?? this.gapY,
      gapText: gapText ?? this.gapText,
      insetX: insetX ?? this.insetX,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fontFamily': appliedFontFamily ?? '',
      'titleSize': _choice(
        titleSize,
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.medium,
      ),
      'bodySize': _choice(
        bodySize,
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.small,
      ),
      'titleWeight': _choice(
        titleWeight,
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.bold,
      ),
      'bodyWeight': _choice(
        bodyWeight,
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.medium,
      ),
      'textAlign': _align(textAlign),
      'textPlacement': HomeSharedEntryPlacements.migrate(textPlacement),
      'aspect': _choice(
        aspect,
        HomeRoomSimpleAspects.all,
        HomeRoomSimpleAspects.square,
      ),
      'imageFit': imageFit == 'contain' ? 'contain' : 'cover',
      'radius': _choice(
        radius,
        HomeRoomSimpleRadii.all,
        HomeRoomSimpleRadii.medium,
      ),
      'mask': _choice(mask, HomeRoomSimpleMasks.all, HomeRoomSimpleMasks.none),
      'surface': _choice(
        surface,
        HomeRoomSimpleSurfaces.all,
        HomeRoomSimpleSurfaces.filled,
      ),
      'showBorder': showBorder,
      'cardShadow': HomeDisplayShadows.migrate(cardShadow),
      'textScrim': textScrim,
      'imageScale': imageScale,
      'gapX': gapX,
      'gapY': gapY,
      'gapText': gapText,
      'insetX': insetX,
      'iconSize': iconSize,
    };
  }

  static HomeSharedEntryStyle fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeSharedEntryStyle();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return const HomeSharedEntryStyle().copyWith(
      fontFamily: _font(map['fontFamily']),
      titleSize: _choice(
        map['titleSize'],
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.medium,
      ),
      bodySize: _choice(
        map['bodySize'],
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.small,
      ),
      titleWeight: _choice(
        map['titleWeight'],
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.bold,
      ),
      bodyWeight: _choice(
        map['bodyWeight'],
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.medium,
      ),
      textAlign: _align(map['textAlign']),
      textPlacement: HomeSharedEntryPlacements.migrate(map['textPlacement']),
      aspect: _choice(
        map['aspect'],
        HomeRoomSimpleAspects.all,
        HomeRoomSimpleAspects.square,
      ),
      imageFit: map['imageFit'] == 'contain' ? 'contain' : 'cover',
      radius: _choice(
        map['radius'],
        HomeRoomSimpleRadii.all,
        HomeRoomSimpleRadii.medium,
      ),
      mask: _choice(
        map['mask'],
        HomeRoomSimpleMasks.all,
        HomeRoomSimpleMasks.none,
      ),
      surface: _choice(
        map['surface'],
        HomeRoomSimpleSurfaces.all,
        HomeRoomSimpleSurfaces.filled,
      ),
      showBorder: map['showBorder'] is bool ? map['showBorder'] as bool : true,
      cardShadow: HomeDisplayShadows.migrate(map['cardShadow']),
      textScrim: map['textScrim'] is bool ? map['textScrim'] as bool : true,
      imageScale: HomeSharedEntryImageScales.factor(map['imageScale']),
      gapX: sharedEntrySpacing(
        map['gapX'],
        fallback: 12,
        compact: 6,
        standard: 12,
        relaxed: 18,
        max: 28,
      ),
      gapY: sharedEntrySpacing(
        map['gapY'],
        fallback: 14,
        compact: 8,
        standard: 14,
        relaxed: 22,
        max: 36,
      ),
      gapText: sharedEntrySpacing(
        map['gapText'],
        fallback: 8,
        compact: 4,
        standard: 8,
        relaxed: 12,
        max: 24,
      ),
      insetX: sharedEntrySpacing(
        map['insetX'],
        fallback: 8,
        compact: 0,
        standard: 8,
        relaxed: 16,
        max: 28,
      ),
      iconSize: sharedEntryIconSize(map['iconSize']),
    );
  }
}

/// 一張精緻小卡自己的內容。外觀改由小卡區統一設定，這裡留下的舊外觀欄位不再覆蓋畫面。
class HomeSharedEntryCardSetting {
  const HomeSharedEntryCardSetting({
    this.title = '',
    this.showTitle = true,
    this.subtitle = '',
    this.showSubtitle = true,
    this.imageAssetId = '',
    this.useSourceImage = true,
    this.fontFamily = '',
    this.titleSize = HomeRoomSimpleTextSizes.medium,
    this.bodySize = HomeRoomSimpleTextSizes.small,
    this.titleWeight = HomeRoomSimpleTextWeights.bold,
    this.bodyWeight = HomeRoomSimpleTextWeights.medium,
    this.textColor = 0xFF3A2A20,
    this.titleColorMode = HomeSharedEntryColorModes.theme,
    this.bodyColorMode = HomeSharedEntryColorModes.theme,
    this.bodyColor = 0xFF8A7568,
    this.textAlign = 'start',
    this.textPlacement = HomeSharedEntryPlacements.outsideBelow,
    this.aspect = HomeRoomSimpleAspects.square,
    this.imageFit = 'cover',
    this.radius = HomeRoomSimpleRadii.medium,
    this.mask = HomeRoomSimpleMasks.none,
    this.surface = HomeRoomSimpleSurfaces.filled,
    this.recentImageAssetIds = const <String>[],
  });

  final String title;
  final bool showTitle;
  final String subtitle;
  final bool showSubtitle;
  final String imageAssetId;
  final bool useSourceImage;
  final String fontFamily;
  final String titleSize;
  final String bodySize;
  final String titleWeight;
  final String bodyWeight;
  final int textColor;
  final String titleColorMode;
  final String bodyColorMode;
  final int bodyColor;
  final String textAlign;
  final String textPlacement;
  final String aspect;
  final String imageFit;
  final String radius;
  final String mask;
  final String surface;

  /// 這張入口最近選過的平台圖庫編號，最多 5 個。只記引用，不記圖片檔。
  final List<String> recentImageAssetIds;

  static const int recentImageLimit = 5;

  static HomeSharedEntryCardSetting fallback(String sourceId) {
    return HomeSharedEntryCardSetting(
      title: HomeSharedEntrySources.label(sourceId),
    );
  }

  String? get appliedFontFamily {
    final String value = fontFamily.trim();
    if (HomeRoomSectionSetting.fontFamilies.contains(value)) {
      return value;
    }
    return null;
  }

  HomeSharedEntryCardSetting copyWith({
    String? title,
    bool? showTitle,
    String? subtitle,
    bool? showSubtitle,
    String? imageAssetId,
    bool? useSourceImage,
    String? fontFamily,
    String? titleSize,
    String? bodySize,
    String? titleWeight,
    String? bodyWeight,
    int? textColor,
    String? titleColorMode,
    String? bodyColorMode,
    int? bodyColor,
    String? textAlign,
    String? textPlacement,
    String? aspect,
    String? imageFit,
    String? radius,
    String? mask,
    String? surface,
    List<String>? recentImageAssetIds,
  }) {
    return HomeSharedEntryCardSetting(
      title: title ?? this.title,
      showTitle: showTitle ?? this.showTitle,
      subtitle: subtitle ?? this.subtitle,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      imageAssetId: imageAssetId ?? this.imageAssetId,
      useSourceImage: useSourceImage ?? this.useSourceImage,
      fontFamily: fontFamily ?? this.fontFamily,
      titleSize: titleSize ?? this.titleSize,
      bodySize: bodySize ?? this.bodySize,
      titleWeight: titleWeight ?? this.titleWeight,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      textColor: textColor ?? this.textColor,
      titleColorMode: titleColorMode ?? this.titleColorMode,
      bodyColorMode: bodyColorMode ?? this.bodyColorMode,
      bodyColor: bodyColor ?? this.bodyColor,
      textAlign: textAlign ?? this.textAlign,
      textPlacement: textPlacement ?? this.textPlacement,
      aspect: aspect ?? this.aspect,
      imageFit: imageFit ?? this.imageFit,
      radius: radius ?? this.radius,
      mask: mask ?? this.mask,
      surface: surface ?? this.surface,
      recentImageAssetIds: recentImageAssetIds ?? this.recentImageAssetIds,
    );
  }

  /// 把成功選用的圖庫編號放到最前面。重複的只留一筆，超過 5 筆去掉最舊的。
  HomeSharedEntryCardSetting rememberImage(String assetId) {
    final String id = _assetId(assetId);
    if (id.isEmpty) {
      return this;
    }
    final List<String> next = <String>[
      id,
      for (final String existing in recentImageAssetIds)
        if (existing != id) existing,
    ];
    if (next.length > recentImageLimit) {
      next.removeRange(recentImageLimit, next.length);
    }
    return copyWith(recentImageAssetIds: next);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': _clip(title, 24),
      'showTitle': showTitle,
      'subtitle': _clip(subtitle, 40),
      'showSubtitle': showSubtitle,
      'imageAssetId': _assetId(imageAssetId),
      'useSourceImage': useSourceImage,
      'fontFamily': appliedFontFamily ?? '',
      'titleSize': _choice(
        titleSize,
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.medium,
      ),
      'bodySize': _choice(
        bodySize,
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.small,
      ),
      'titleWeight': _choice(
        titleWeight,
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.bold,
      ),
      'bodyWeight': _choice(
        bodyWeight,
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.medium,
      ),
      'textColor': textColor,
      'titleColorMode': HomeSharedEntryColorModes.migrate(titleColorMode),
      'bodyColorMode': HomeSharedEntryColorModes.migrate(bodyColorMode),
      'bodyColor': bodyColor,
      'textAlign': _align(textAlign),
      'textPlacement': HomeSharedEntryPlacements.migrate(textPlacement),
      'aspect': _choice(
        aspect,
        HomeRoomSimpleAspects.all,
        HomeRoomSimpleAspects.square,
      ),
      'imageFit': imageFit == 'contain' ? 'contain' : 'cover',
      'radius': _choice(
        radius,
        HomeRoomSimpleRadii.all,
        HomeRoomSimpleRadii.medium,
      ),
      'mask': _choice(mask, HomeRoomSimpleMasks.all, HomeRoomSimpleMasks.none),
      'surface': _choice(
        surface,
        HomeRoomSimpleSurfaces.all,
        HomeRoomSimpleSurfaces.filled,
      ),
      'recentImageAssetIds': recentImageAssetIds,
    };
  }

  static HomeSharedEntryCardSetting fromMap(Object? raw, String sourceId) {
    final HomeSharedEntryCardSetting fallbackCard = fallback(sourceId);
    if (raw is! Map) {
      return fallbackCard;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final Object? title = map['title'];
    return HomeSharedEntryCardSetting(
      title: title is String ? _clip(title, 24) : fallbackCard.title,
      showTitle: map['showTitle'] is bool ? map['showTitle'] as bool : true,
      subtitle: map['subtitle'] is String
          ? _clip(map['subtitle'] as String, 40)
          : '',
      showSubtitle: map['showSubtitle'] is bool
          ? map['showSubtitle'] as bool
          : true,
      imageAssetId: _assetId(map['imageAssetId']),
      useSourceImage: map['useSourceImage'] is bool
          ? map['useSourceImage'] as bool
          : true,
      fontFamily: _font(map['fontFamily']),
      titleSize: _choice(
        map['titleSize'],
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.medium,
      ),
      bodySize: _choice(
        map['bodySize'],
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.small,
      ),
      titleWeight: _choice(
        map['titleWeight'],
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.bold,
      ),
      bodyWeight: _choice(
        map['bodyWeight'],
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.medium,
      ),
      textColor: map['textColor'] is num
          ? (map['textColor'] as num).toInt()
          : 0xFF3A2A20,
      titleColorMode: _colorMode(map, 'titleColorMode'),
      bodyColorMode: _colorMode(map, 'bodyColorMode'),
      bodyColor: map['bodyColor'] is num
          ? (map['bodyColor'] as num).toInt()
          : map['textColor'] is num
          ? (map['textColor'] as num).toInt()
          : 0xFF8A7568,
      textAlign: _align(map['textAlign']),
      textPlacement: HomeSharedEntryPlacements.migrate(map['textPlacement']),
      aspect: _choice(
        map['aspect'],
        HomeRoomSimpleAspects.all,
        HomeRoomSimpleAspects.square,
      ),
      imageFit: map['imageFit'] == 'contain' ? 'contain' : 'cover',
      radius: _choice(
        map['radius'],
        HomeRoomSimpleRadii.all,
        HomeRoomSimpleRadii.medium,
      ),
      mask: _choice(
        map['mask'],
        HomeRoomSimpleMasks.all,
        HomeRoomSimpleMasks.none,
      ),
      surface: _choice(
        map['surface'],
        HomeRoomSimpleSurfaces.all,
        HomeRoomSimpleSurfaces.filled,
      ),
      recentImageAssetIds: _recentIds(map['recentImageAssetIds']),
    );
  }
}

class HomeSharedEntrySectionSetting {
  const HomeSharedEntrySectionSetting({
    this.enabled = false,
    this.title = '我們的服務',
    this.showTitle = true,
    this.columns = 3,
    this.overflow = HomeSharedEntryOverflows.wrap,
    this.style = const HomeSharedEntryStyle(),
    this.cardOrder = const <String>[],
    this.cards = const <String, HomeSharedEntryCardSetting>{},
  });

  static const String mapKey = 'sharedEntrySection';

  final bool enabled;
  final String title;
  final bool showTitle;
  final int columns;
  final String overflow;
  final HomeSharedEntryStyle style;
  final List<String> cardOrder;
  final Map<String, HomeSharedEntryCardSetting> cards;

  bool isJoined(String sourceId) => cardOrder.contains(sourceId);

  HomeSharedEntryCardSetting cardOf(String sourceId) {
    return cards[sourceId] ?? HomeSharedEntryCardSetting.fallback(sourceId);
  }

  HomeSharedEntrySectionSetting copyWith({
    bool? enabled,
    String? title,
    bool? showTitle,
    int? columns,
    String? overflow,
    HomeSharedEntryStyle? style,
    List<String>? cardOrder,
    Map<String, HomeSharedEntryCardSetting>? cards,
  }) {
    return HomeSharedEntrySectionSetting(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      showTitle: showTitle ?? this.showTitle,
      columns: columns == null ? this.columns : sharedEntryColumns(columns),
      overflow: overflow == null
          ? this.overflow
          : HomeSharedEntryOverflows.migrate(overflow),
      style: style ?? this.style,
      cardOrder: cardOrder ?? this.cardOrder,
      cards: cards ?? this.cards,
    );
  }

  /// 加入小卡。已在順序裡時不重複新增，已存過的卡片內容維持不變。
  HomeSharedEntrySectionSetting including(
    String sourceId, {
    required bool when,
    HomeSharedEntryCardSetting? seed,
  }) {
    if (!when || !HomeSharedEntrySources.canJoin(sourceId)) {
      return this;
    }
    final bool known = cardOrder.contains(sourceId);
    if (known && (seed == null || cards.containsKey(sourceId))) {
      return this;
    }
    final Map<String, HomeSharedEntryCardSetting> nextCards =
        Map<String, HomeSharedEntryCardSetting>.from(cards);
    if (seed != null) {
      nextCards.putIfAbsent(sourceId, () => seed);
    }
    return copyWith(
      cardOrder: known ? cardOrder : <String>[...cardOrder, sourceId],
      cards: nextCards,
    );
  }

  /// 一次套用勾選結果。已顯示的維持原順序，新勾選的依清單順序接在最後。
  /// 取消勾選只移出首頁，不刪除卡片內容。
  HomeSharedEntrySectionSetting applyJoined(Iterable<String> selected) {
    final List<String> wanted = <String>[];
    for (final String raw in selected) {
      final String id = raw.trim();
      if (!HomeSharedEntrySources.canJoin(id) || wanted.contains(id)) {
        continue;
      }
      wanted.add(id);
    }
    final Set<String> keep = wanted.toSet();
    final List<String> order = <String>[
      for (final String id in cardOrder)
        if (!HomeSharedEntrySources.canJoin(id) || keep.contains(id)) id,
    ];
    for (final String id in wanted) {
      if (!order.contains(id)) {
        order.add(id);
      }
    }
    if (order.length == cardOrder.length) {
      var same = true;
      for (var index = 0; index < order.length; index++) {
        if (order[index] != cardOrder[index]) {
          same = false;
          break;
        }
      }
      if (same) {
        return this;
      }
    }
    return copyWith(cardOrder: order);
  }

  /// 移出小卡區。卡片內容留著，之後再加入會沿用。
  HomeSharedEntrySectionSetting without(String sourceId) {
    if (!cardOrder.contains(sourceId)) {
      return this;
    }
    return copyWith(
      cardOrder: <String>[
        for (final String id in cardOrder)
          if (id != sourceId) id,
      ],
    );
  }

  HomeSharedEntrySectionSetting updateCard(
    String sourceId,
    HomeSharedEntryCardSetting card,
  ) {
    return copyWith(
      cards: <String, HomeSharedEntryCardSetting>{...cards, sourceId: card},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'title': _clip(title, 24),
      'showTitle': showTitle,
      'columns': sharedEntryColumns(columns),
      'overflow': HomeSharedEntryOverflows.migrate(overflow),
      'style': style.toMap(),
      'cardOrder': cardOrder,
      'cards': <String, dynamic>{
        for (final MapEntry<String, HomeSharedEntryCardSetting> entry
            in cards.entries)
          if (HomeSharedEntrySources.canJoin(entry.key))
            entry.key: entry.value.toMap(),
      },
    };
  }

  static HomeSharedEntrySectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeSharedEntrySectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final Object? title = map['title'];
    return HomeSharedEntrySectionSetting(
      enabled: map['enabled'] == true,
      title: title is String ? _clip(title, 24) : '我們的服務',
      showTitle: map['showTitle'] is bool ? map['showTitle'] as bool : true,
      columns: sharedEntryColumns(map['columns']),
      overflow: HomeSharedEntryOverflows.migrate(map['overflow']),
      style: HomeSharedEntryStyle.fromMap(map['style']),
      cardOrder: _ids(map['cardOrder']),
      cards: _cards(map['cards']),
    );
  }
}

/// 簡約入口目前選了共用區，而且房型展示仍是簡約入口。
bool roomSimpleUsesSharedZone(HomeRoomSectionSetting rooms) {
  return rooms.layout == HomeRoomSectionLayouts.simpleEntry &&
      rooms.simple.placement == HomeRoomSimplePlacements.shared;
}

/// 目前要畫出來的小卡。未知來源留在 [cardOrder]，不在這裡顯示。
///
/// 小卡只依自己的順序顯示。舊 placement 相容由 HomeSectionVisibility.read 處理。
List<String> sharedEntryJoinedIds({
  required HomeSharedEntrySectionSetting section,
  required HomeRoomSectionSetting rooms,
}) {
  final List<String> order = List<String>.from(section.cardOrder);
  return <String>[
    for (final String id in order)
      if (HomeSharedEntrySources.canJoin(id)) id,
  ];
}

/// 保留舊呼叫介面；獨立展示不再因加入小卡而自動隱藏。
bool sharedEntryHidesSimpleSection({
  required String sourceId,
  required String layout,
  required String simpleLayout,
  required HomeSharedEntrySectionSetting section,
  required HomeRoomSectionSetting rooms,
}) {
  return false;
}

String sharedEntryCardLabel(String sourceId) {
  return HomeSharedEntrySources.label(sourceId);
}

/// 精緻小卡只使用平台圖庫編號。空字串代表改顯示固定圖示，不讀功能照片。
String sharedEntryGalleryAssetId(HomeSharedEntryCardSetting card) {
  return card.imageAssetId.trim();
}

String _clip(String raw, int max) {
  final String value = raw.trim();
  if (value.length <= max) {
    return value;
  }
  return value.substring(0, max);
}

String _choice(Object? raw, List<String> allowed, String fallback) {
  final String value = raw?.toString().trim() ?? '';
  return allowed.contains(value) ? value : fallback;
}

String _align(Object? raw) {
  switch (raw?.toString().trim()) {
    case 'center':
      return 'center';
    case 'end':
      return 'end';
    default:
      return 'start';
  }
}

/// 沒有新的顏色模式時，沿用舊小卡已存的文字色，避免全部被改成主題色。
String _colorMode(Map<String, dynamic> map, String key) {
  if (map.containsKey(key)) {
    return HomeSharedEntryColorModes.migrate(map[key]);
  }
  return map['textColor'] is num
      ? HomeSharedEntryColorModes.custom
      : HomeSharedEntryColorModes.theme;
}

String _font(Object? raw) {
  final String value = raw?.toString().trim() ?? '';
  if (HomeRoomSectionSetting.fontFamilies.contains(value)) {
    return value;
  }
  return '';
}

String _assetId(Object? raw) {
  final String value = raw?.toString().trim() ?? '';
  if (value.isEmpty || value.length > 128 || value.contains('/')) {
    return '';
  }
  return value;
}

List<String> _recentIds(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  final List<String> ids = <String>[];
  for (final Object? item in raw) {
    final String id = _assetId(item);
    if (id.isEmpty || ids.contains(id)) {
      continue;
    }
    ids.add(id);
    if (ids.length == HomeSharedEntryCardSetting.recentImageLimit) {
      break;
    }
  }
  return ids;
}

Map<String, HomeSharedEntryCardSetting> _cards(Object? raw) {
  if (raw is! Map) {
    return const <String, HomeSharedEntryCardSetting>{};
  }
  final Map<String, HomeSharedEntryCardSetting> cards =
      <String, HomeSharedEntryCardSetting>{};
  raw.forEach((Object? key, Object? value) {
    final String id = key.toString().trim();
    if (!HomeSharedEntrySources.canJoin(id)) {
      return;
    }
    cards[id] = HomeSharedEntryCardSetting.fromMap(value, id);
  });
  return cards;
}

List<String> _ids(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  final List<String> ids = <String>[];
  for (final Object? item in raw) {
    final String id = item.toString().trim();
    if (id.isEmpty || id.length > 64 || id.contains('/') || ids.contains(id)) {
      continue;
    }
    ids.add(id);
  }
  return ids;
}
