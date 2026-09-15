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
    food,
    toilet,
    activity,
    relax,
    generalNote,
    photos,
  ];

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
  });

  final String key;
  final bool visible;
  final String width;
  final String colorKey;
  final int order;

  bool get isHalf => width == DailyCareJournalCardStyle.widthHalf;

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
    return DailyCareJournalCardLayout(
      key: key,
      visible: map['visible'] != false,
      width: width == DailyCareJournalCardStyle.widthHalf
          ? DailyCareJournalCardStyle.widthHalf
          : DailyCareJournalCardStyle.widthFull,
      colorKey: DailyCareJournalCardStyle.colorKeys.contains(colorKey)
          ? colorKey
          : fallback.colorKey,
      order: map['order'] is num
          ? (map['order'] as num).round()
          : fallback.order,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'visible': visible,
      'width': width,
      'colorKey': colorKey,
      'order': order,
    };
  }

  DailyCareJournalCardLayout copyWith({
    bool? visible,
    String? width,
    String? colorKey,
    int? order,
  }) {
    return DailyCareJournalCardLayout(
      key: key,
      visible: visible ?? this.visible,
      width: width ?? this.width,
      colorKey: colorKey ?? this.colorKey,
      order: order ?? this.order,
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
        key: DailyCareJournalCardKeys.food,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorBlue,
        order: 1,
      ),
      DailyCareJournalCardLayout(
        key: DailyCareJournalCardKeys.toilet,
        width: DailyCareJournalCardStyle.widthHalf,
        colorKey: DailyCareJournalCardStyle.colorCream,
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
      showShopName: map['showShopName'] != false,
      showRoomOrOffer: map['showRoomOrOffer'] != false,
      showPetNames: map['showPetNames'] != false,
      showServiceDate: map['showServiceDate'] != false,
      showFilledTime: map['showFilledTime'] != false,
      showPhotoSection: map['showPhotoSection'] != false,
      showTemperature: map['showTemperature'] != false,
      showHumidity: map['showHumidity'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showShopName': showShopName,
      'showRoomOrOffer': true,
      'showPetNames': true,
      'showServiceDate': true,
      'showFilledTime': true,
      'showPhotoSection': showPhotoSection,
      'showTemperature': showTemperature,
      'showHumidity': showHumidity,
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
