// 檔案名稱：lib/core/models/daily_care_journal_layout.dart
// 功能說明：客戶端照護日誌頁首顯示與回報卡片編排，寫入既有 dailyCareSetting。
// 🐾 住宿與安親共用同一套版面解析規則

class DailyCareJournalCardKeys {
  DailyCareJournalCardKeys._();

  static const String environment = 'environment';
  static const String food = 'food';
  static const String toilet = 'toilet';
  static const String activity = 'activity';
  static const String relax = 'relax';
  static const String generalNote = 'generalNote';
  static const String photos = 'photos';

  static const List<String> ordered = <String>[
    environment,
    toilet,
    food,
    activity,
    relax,
    generalNote,
    photos,
  ];

  static bool isPinned(String key) {
    return key == environment || key == toilet;
  }

  static String labelOf(String key) {
    switch (key) {
      case environment:
        return '環境狀況';
      case food:
        return '生活狀況';
      case toilet:
        return '大小便狀況';
      case activity:
        return '活動與玩樂';
      case relax:
        return '放鬆與用品';
      case generalNote:
        return '今日概況';
      case photos:
        return '照護照片';
      default:
        return key;
    }
  }
}

class DailyCareJournalCardStyle {
  DailyCareJournalCardStyle._();

  static const String widthFull = 'full';
  static const String widthHalf = 'half';

  static const String inkAuto = 'auto';
  static const String inkDark = 'dark';
  static const String inkLight = 'light';
  static const String inkCustom = 'custom';

  static const String backgroundFollow = 'follow';
  static const String backgroundPreset = 'preset';

  static const List<String> backgroundSources = <String>[
    backgroundFollow,
    backgroundPreset,
  ];

  static const List<String> inkModes = <String>[
    inkAuto,
    inkDark,
    inkLight,
    inkCustom,
  ];

  static String inkLabel(String key) {
    switch (key) {
      case inkDark:
        return '深色';
      case inkLight:
        return '淺色';
      case inkCustom:
        return '自訂顏色';
      case inkAuto:
      default:
        return '自動';
    }
  }

  static String _readInkMode(Object? value) {
    final String key = (value ?? inkAuto).toString();
    return inkModes.contains(key) ? key : inkAuto;
  }

  static const String colorTheme = 'theme';
  static const String colorCream = 'cream';
  static const String colorMint = 'mint';
  static const String colorBlue = 'blue';
  static const String colorOrange = 'orange';
  static const String colorPink = 'pink';

  static const List<String> colorKeys = <String>[
    colorTheme,
    colorCream,
    colorMint,
    colorBlue,
    colorOrange,
    colorPink,
  ];

  static String colorLabel(String key) {
    switch (key) {
      case colorCream:
        return '奶油';
      case colorMint:
        return '淺綠';
      case colorBlue:
        return '淺藍';
      case colorOrange:
        return '淡橘';
      case colorPink:
        return '淡粉';
      case colorTheme:
      default:
        return '跟隨主題';
    }
  }
}

class DailyCareJournalCardLayout {
  const DailyCareJournalCardLayout({
    required this.key,
    this.visible = true,
    this.width = DailyCareJournalCardStyle.widthFull,
    this.colorKey = DailyCareJournalCardStyle.colorTheme,
    this.order = 0,
    this.inkMode = DailyCareJournalCardStyle.inkAuto,
    this.inkColorArgb = 0,
    this.backgroundSource = DailyCareJournalCardStyle.backgroundFollow,
    this.backgroundPreset = '',
  });

  final String key;
  final bool visible;
  final String width;
  final String colorKey;
  final int order;
  final String inkMode;
  final int inkColorArgb;
  final String backgroundSource;
  final String backgroundPreset;

  bool get isHalf => width == DailyCareJournalCardStyle.widthHalf;
  bool get followsSharedBackground =>
      backgroundSource != DailyCareJournalCardStyle.backgroundPreset ||
      backgroundPreset.trim().isEmpty;
  bool get isPinned => DailyCareJournalCardKeys.isPinned(key);

  factory DailyCareJournalCardLayout.fromMap(
    String key,
    Map<String, dynamic>? map, {
    required DailyCareJournalCardLayout fallback,
  }) {
    if (map == null) {
      return fallback;
    }
    final String width = (map['width'] ?? fallback.width).toString();
    final String colorKey = (map['colorKey'] ?? fallback.colorKey).toString();
    final int inkColorArgb = map['inkColorArgb'] is num
        ? (map['inkColorArgb'] as num).toInt()
        : fallback.inkColorArgb;
    final bool pinned = DailyCareJournalCardKeys.isPinned(key);
    return DailyCareJournalCardLayout(
      key: key,
      visible: pinned ? true : map['visible'] != false,
      width: pinned
          ? DailyCareJournalCardStyle.widthHalf
          : (width == DailyCareJournalCardStyle.widthHalf
                ? DailyCareJournalCardStyle.widthHalf
                : DailyCareJournalCardStyle.widthFull),
      colorKey: DailyCareJournalCardStyle.colorKeys.contains(colorKey)
          ? colorKey
          : fallback.colorKey,
      order: pinned
          ? (key == DailyCareJournalCardKeys.environment ? 0 : 1)
          : (map['order'] is num
                ? (map['order'] as num).round()
                : fallback.order),
      inkMode: DailyCareJournalCardStyle._readInkMode(
        map['inkMode'] ?? fallback.inkMode,
      ),
      inkColorArgb: inkColorArgb,
      backgroundSource: _readBackgroundSource(map['backgroundSource']),
      backgroundPreset: (map['backgroundPreset'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'visible': visible,
      'width': width,
      'colorKey': colorKey,
      'order': order,
      'inkMode': inkMode,
      'inkColorArgb': inkColorArgb,
      'backgroundSource': backgroundSource,
      'backgroundPreset': backgroundPreset,
    };
  }

  static String _readBackgroundSource(Object? value) {
    final String key = (value ?? DailyCareJournalCardStyle.backgroundFollow)
        .toString();
    if (key == DailyCareJournalCardStyle.backgroundPreset) {
      return DailyCareJournalCardStyle.backgroundPreset;
    }
    return DailyCareJournalCardStyle.backgroundFollow;
  }

  DailyCareJournalCardLayout copyWith({
    bool? visible,
    String? width,
    String? colorKey,
    int? order,
    String? inkMode,
    int? inkColorArgb,
    String? backgroundSource,
    String? backgroundPreset,
  }) {
    return DailyCareJournalCardLayout(
      key: key,
      visible: visible ?? this.visible,
      width: width ?? this.width,
      colorKey: colorKey ?? this.colorKey,
      order: order ?? this.order,
      inkMode: inkMode ?? this.inkMode,
      inkColorArgb: inkColorArgb ?? this.inkColorArgb,
      backgroundSource: backgroundSource ?? this.backgroundSource,
      backgroundPreset: backgroundPreset ?? this.backgroundPreset,
    );
  }

  static List<DailyCareJournalCardLayout> defaults() {
    return const <DailyCareJournalCardLayout>[
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.environment,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorMint,
        order: 0,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.toilet,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorCream,
        order: 1,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.food,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorBlue,
        order: 2,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.activity,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorMint,
        order: 3,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.relax,
        colorKey: DailyCareJournalCardStyle.colorBlue,
        order: 4,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.generalNote,
        colorKey: DailyCareJournalCardStyle.colorPink,
        order: 5,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.photos,
        order: 6,
      ),
    ];
  }

  static Map<String, DailyCareJournalCardLayout> mapFrom(Object? raw) {
    final List<DailyCareJournalCardLayout> fallbacks = defaults();
    final Map<String, DailyCareJournalCardLayout> byKey =
        <String, DailyCareJournalCardLayout>{
          for (final DailyCareJournalCardLayout item in fallbacks) item.key: item,
        };
    if (raw is Map) {
      raw.forEach((Object? key, Object? value) {
        final String name = key.toString().trim();
        if (!byKey.containsKey(name) || value is! Map) {
          return;
        }
        byKey[name] = DailyCareJournalCardLayout.fromMap(
          name,
          Map<String, dynamic>.from(value),
          fallback: byKey[name]!,
        );
      });
    }
    return byKey;
  }

  static Map<String, dynamic> mapToFirestore(
    Map<String, DailyCareJournalCardLayout> layouts,
  ) {
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final String key in DailyCareJournalCardKeys.ordered) {
      final DailyCareJournalCardLayout item =
          layouts[key] ??
          defaults().firstWhere(
            (DailyCareJournalCardLayout row) => row.key == key,
          );
      out[key] = item.toMap();
    }
    return out;
  }

  static List<DailyCareJournalCardLayout> sorted(
    Map<String, DailyCareJournalCardLayout> layouts,
  ) {
    final List<DailyCareJournalCardLayout> list = DailyCareJournalCardKeys
        .ordered
        .map(
          (String key) =>
              layouts[key] ??
              defaults().firstWhere(
                (DailyCareJournalCardLayout row) => row.key == key,
              ),
        )
        .toList();
    list.sort((DailyCareJournalCardLayout a, DailyCareJournalCardLayout b) {
      if (a.isPinned && b.isPinned) {
        return DailyCareJournalCardKeys.ordered
            .indexOf(a.key)
            .compareTo(DailyCareJournalCardKeys.ordered.indexOf(b.key));
      }
      if (a.isPinned) {
        return -1;
      }
      if (b.isPinned) {
        return 1;
      }
      final int byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) {
        return byOrder;
      }
      return DailyCareJournalCardKeys.ordered
          .indexOf(a.key)
          .compareTo(DailyCareJournalCardKeys.ordered.indexOf(b.key));
    });
    return list;
  }

  /// 客戶日誌、預覽固定：環境狀況 → 大小便狀況 → 其餘可設定卡片。
  static List<DailyCareJournalCardLayout> displaySorted(
    Map<String, DailyCareJournalCardLayout> layouts,
  ) {
    final List<DailyCareJournalCardLayout> all = sorted(layouts);
    DailyCareJournalCardLayout? environment;
    DailyCareJournalCardLayout? toilet;
    final List<DailyCareJournalCardLayout> rest = <DailyCareJournalCardLayout>[];
    for (final DailyCareJournalCardLayout item in all) {
      if (item.key == DailyCareJournalCardKeys.environment) {
        environment = item;
      } else if (item.key == DailyCareJournalCardKeys.toilet) {
        toilet = item;
      } else {
        rest.add(item);
      }
    }
    return <DailyCareJournalCardLayout>[
      ?environment,
      ?toilet,
      ...rest,
    ];
  }
}

/// 日期／場次／房間基本資訊共用的頁首卡片外觀（與照護內容分類卡分開）。
class DailyCareJournalHeaderStyle {
  const DailyCareJournalHeaderStyle({
    this.inkMode = DailyCareJournalCardStyle.inkAuto,
    this.inkColorArgb = 0,
    this.useCardBackground = false,
  });

  final String inkMode;
  final int inkColorArgb;
  final bool useCardBackground;

  DailyCareJournalCardLayout get asInkLayout {
    return DailyCareJournalCardLayout(
      key: 'header',
      inkMode: inkMode,
      inkColorArgb: inkColorArgb,
    );
  }

  factory DailyCareJournalHeaderStyle.fromMap(Object? raw) {
    if (raw is! Map) {
      return const DailyCareJournalHeaderStyle();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final int inkColorArgb = map['inkColorArgb'] is num
        ? (map['inkColorArgb'] as num).toInt()
        : 0;
    return DailyCareJournalHeaderStyle(
      inkMode: DailyCareJournalCardStyle._readInkMode(map['inkMode']),
      inkColorArgb: inkColorArgb,
      useCardBackground: map['useCardBackground'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inkMode': inkMode,
      'inkColorArgb': inkColorArgb,
      'useCardBackground': useCardBackground,
    };
  }

  DailyCareJournalHeaderStyle copyWith({
    String? inkMode,
    int? inkColorArgb,
    bool? useCardBackground,
  }) {
    return DailyCareJournalHeaderStyle(
      inkMode: inkMode ?? this.inkMode,
      inkColorArgb: inkColorArgb ?? this.inkColorArgb,
      useCardBackground: useCardBackground ?? this.useCardBackground,
    );
  }
}

class DailyCareJournalDisplayFlags {
  const DailyCareJournalDisplayFlags({
    this.showShopName = true,
    this.showRoomOrOffer = true,
    this.showPetNames = true,
    this.showServiceDate = true,
    this.showFilledTime = true,
    this.showPhotoSection = true,
    this.showTemperature = true,
    this.showHumidity = true,
  });

  final bool showShopName;
  final bool showRoomOrOffer;
  final bool showPetNames;
  final bool showServiceDate;
  final bool showFilledTime;
  final bool showPhotoSection;
  final bool showTemperature;
  final bool showHumidity;

  factory DailyCareJournalDisplayFlags.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCareJournalDisplayFlags();
    }
    return DailyCareJournalDisplayFlags(
      showShopName: true,
      showRoomOrOffer: map['showRoomOrOffer'] != false,
      showPetNames: map['showPetNames'] != false,
      showServiceDate: map['showServiceDate'] != false,
      showFilledTime: map['showFilledTime'] != false,
      showPhotoSection: map['showPhotoSection'] != false,
      showTemperature: true,
      showHumidity: true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showPhotoSection': showPhotoSection,
    };
  }

  DailyCareJournalDisplayFlags copyWith({
    bool? showShopName,
    bool? showRoomOrOffer,
    bool? showPetNames,
    bool? showServiceDate,
    bool? showFilledTime,
    bool? showPhotoSection,
    bool? showTemperature,
    bool? showHumidity,
  }) {
    return DailyCareJournalDisplayFlags(
      showShopName: showShopName ?? this.showShopName,
      showRoomOrOffer: showRoomOrOffer ?? this.showRoomOrOffer,
      showPetNames: showPetNames ?? this.showPetNames,
      showServiceDate: showServiceDate ?? this.showServiceDate,
      showFilledTime: showFilledTime ?? this.showFilledTime,
      showPhotoSection: showPhotoSection ?? this.showPhotoSection,
      showTemperature: showTemperature ?? this.showTemperature,
      showHumidity: showHumidity ?? this.showHumidity,
    );
  }
}
