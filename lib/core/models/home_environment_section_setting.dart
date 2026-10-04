/// 新版首頁環境展示。只決定入口怎麼顯示，不改 environmentIntro 內容。
class HomeEnvironmentLayouts {
  static const String facilityScroll = 'facilityScroll';
  static const String simpleEntry = 'simpleEntry';
  static const String imageEntry = 'imageEntry';
  static const List<String> all = <String>[
    facilityScroll,
    simpleEntry,
    imageEntry,
  ];

  static String label(String value) {
    switch (migrate(value)) {
      case simpleEntry:
        return '簡約入口';
      case imageEntry:
        return '環境照片卡';
      default:
        return '設備橫滑';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return facilityScroll;
  }
}

class HomeEnvironmentCardSizes {
  static const String small = 'small';
  static const String single = 'single';
  static const String wide = 'wide';
  static const List<String> all = <String>[small, single, wide];

  static String label(String value) {
    switch (migrate(value)) {
      case small:
        return '小卡';
      case single:
        return '單卡';
      default:
        return '長卡';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return wide;
  }
}

class HomeEnvironmentSurfaces {
  static const String filled = 'filled';
  static const String outlined = 'outlined';
  static const String transparent = 'transparent';
  static const List<String> all = <String>[filled, outlined, transparent];

  static String label(String value) {
    switch (migrate(value)) {
      case outlined:
        return '只有框線';
      case transparent:
        return '透明';
      default:
        return '淡色底';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return filled;
  }
}

class HomeEnvironmentIcons {
  static const String home = 'home';
  static const String yard = 'yard';
  static const String pets = 'pets';
  static const String shield = 'shield';
  static const List<String> all = <String>[home, yard, pets, shield];

  static String label(String value) {
    switch (migrate(value)) {
      case yard:
        return '庭院';
      case pets:
        return '寵物';
      case shield:
        return '安心';
      default:
        return '房屋';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return home;
  }
}

class HomeEnvironmentImageHeights {
  static const String compact = 'compact';
  static const String standard = 'standard';
  static const String tall = 'tall';
  static const List<String> all = <String>[compact, standard, tall];

  static String label(String value) {
    switch (migrate(value)) {
      case compact:
        return '精簡';
      case tall:
        return '加高';
      default:
        return '標準';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return standard;
  }

  static double pixels(String value) {
    switch (migrate(value)) {
      case compact:
        return 132;
      case tall:
        return 220;
      default:
        return 176;
    }
  }
}

class HomeEnvironmentTextPlacements {
  static const String below = 'below';
  static const String overlay = 'overlay';
  static const List<String> all = <String>[below, overlay];

  static String label(String value) {
    switch (migrate(value)) {
      case below:
        return '圖片下方';
      default:
        return '圖片內';
    }
  }

  static String migrate(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    if (all.contains(value)) {
      return value;
    }
    return overlay;
  }
}

class HomeEnvironmentSectionSetting {
  const HomeEnvironmentSectionSetting({
    this.schemaVersion = 1,
    this.layout = HomeEnvironmentLayouts.facilityScroll,
    this.title = '環境介紹',
    this.subtitle = '查看住宿環境與安心設備',
    this.showTitle = false,
    this.showSubtitle = true,
    this.showEndEntryCard = true,
    this.simpleCardSize = HomeEnvironmentCardSizes.wide,
    this.simpleSurface = HomeEnvironmentSurfaces.filled,
    this.simpleIcon = HomeEnvironmentIcons.home,
    this.imageHeight = HomeEnvironmentImageHeights.standard,
    this.imageTextPlacement = HomeEnvironmentTextPlacements.overlay,
  });

  final int schemaVersion;
  final String layout;
  final String title;
  final String subtitle;
  final bool showTitle;
  final bool showSubtitle;
  final bool showEndEntryCard;
  final String simpleCardSize;
  final String simpleSurface;
  final String simpleIcon;
  final String imageHeight;
  final String imageTextPlacement;

  /// 設備橫滑沒有設備時不占首頁。簡約入口與照片卡仍會顯示。
  bool showsOnHome({required bool hasFacilities}) {
    if (layout == HomeEnvironmentLayouts.facilityScroll) {
      return hasFacilities;
    }
    return true;
  }

  String get entryTitle {
    final String text = title.trim();
    return text.isEmpty ? '環境介紹' : text;
  }

  String get facilityTitle {
    final String text = title.trim();
    return text.isEmpty ? '環境設備' : text;
  }

  HomeEnvironmentSectionSetting copyWith({
    int? schemaVersion,
    String? layout,
    String? title,
    String? subtitle,
    bool? showTitle,
    bool? showSubtitle,
    bool? showEndEntryCard,
    String? simpleCardSize,
    String? simpleSurface,
    String? simpleIcon,
    String? imageHeight,
    String? imageTextPlacement,
  }) {
    return HomeEnvironmentSectionSetting(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      layout: layout ?? this.layout,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      showTitle: showTitle ?? this.showTitle,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      showEndEntryCard: showEndEntryCard ?? this.showEndEntryCard,
      simpleCardSize: simpleCardSize ?? this.simpleCardSize,
      simpleSurface: simpleSurface ?? this.simpleSurface,
      simpleIcon: simpleIcon ?? this.simpleIcon,
      imageHeight: imageHeight ?? this.imageHeight,
      imageTextPlacement: imageTextPlacement ?? this.imageTextPlacement,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'layout': HomeEnvironmentLayouts.migrate(layout),
      'title': title,
      'subtitle': subtitle,
      'showTitle': showTitle,
      'showSubtitle': showSubtitle,
      'showEndEntryCard': showEndEntryCard,
      'simpleCardSize': HomeEnvironmentCardSizes.migrate(simpleCardSize),
      'simpleSurface': HomeEnvironmentSurfaces.migrate(simpleSurface),
      'simpleIcon': HomeEnvironmentIcons.migrate(simpleIcon),
      'imageHeight': HomeEnvironmentImageHeights.migrate(imageHeight),
      'imageTextPlacement': HomeEnvironmentTextPlacements.migrate(
        imageTextPlacement,
      ),
    };
  }

  static HomeEnvironmentSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeEnvironmentSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 24);
    final String subtitle = _clip(map['subtitle'], 40);
    return HomeEnvironmentSectionSetting(
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
      layout: HomeEnvironmentLayouts.migrate(map['layout']),
      title: title.isEmpty ? '環境介紹' : title,
      subtitle: subtitle.isEmpty ? '查看住宿環境與安心設備' : subtitle,
      showTitle: map['showTitle'] is bool ? map['showTitle'] as bool : false,
      showSubtitle: map['showSubtitle'] is bool
          ? map['showSubtitle'] as bool
          : true,
      showEndEntryCard: map['showEndEntryCard'] is bool
          ? map['showEndEntryCard'] as bool
          : true,
      simpleCardSize: HomeEnvironmentCardSizes.migrate(map['simpleCardSize']),
      simpleSurface: HomeEnvironmentSurfaces.migrate(map['simpleSurface']),
      simpleIcon: HomeEnvironmentIcons.migrate(map['simpleIcon']),
      imageHeight: HomeEnvironmentImageHeights.migrate(map['imageHeight']),
      imageTextPlacement: HomeEnvironmentTextPlacements.migrate(
        map['imageTextPlacement'],
      ),
    );
  }

  /// hero → gallery 第一張 → features 第一張。都沒有就回傳空字串。
  static String resolveImageUrl(Object? intro) {
    if (intro is! Map) {
      return '';
    }
    final String hero = (intro['heroImageUrl'] ?? '').toString().trim();
    if (hero.isNotEmpty) {
      return hero;
    }
    final String gallery = _firstUrl(intro['galleryImages']);
    if (gallery.isNotEmpty) {
      return gallery;
    }
    return _firstUrl(intro['features']);
  }

  static String _firstUrl(Object? raw) {
    if (raw is! List) {
      return '';
    }
    for (final Object? item in raw) {
      if (item is Map) {
        final String url = (item['imageUrl'] ?? item['url'] ?? '')
            .toString()
            .trim();
        if (url.isNotEmpty) {
          return url;
        }
        continue;
      }
      final String url = item?.toString().trim() ?? '';
      if (url.isNotEmpty && url != 'null') {
        return url;
      }
    }
    return '';
  }
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.length <= maxCharacters) {
    return value;
  }
  return value.substring(0, maxCharacters);
}
