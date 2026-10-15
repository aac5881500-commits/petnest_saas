// 新版首頁房型展示設定。存在 shops/{shopId}.homeAppearance.modern.roomSection。

import 'package:flutter/widgets.dart';

class HomeRoomSectionLayouts {
  static const String horizontalScroll = 'horizontalScroll';
  static const String cardGrid = 'cardGrid';
  static const String simpleEntry = 'simpleEntry';
  static const String featured = 'featured';
  static const String refinedCards = 'refinedCards';
  static const List<String> all = <String>[
    horizontalScroll,
    cardGrid,
    simpleEntry,
    featured,
    refinedCards,
  ];

  static String label(String value) {
    switch (value) {
      case cardGrid:
        return '卡片拼排';
      case simpleEntry:
        return '簡約入口';
      case featured:
        return '精選大圖';
      case refinedCards:
        return '精緻圖片小卡';
      default:
        return '橫向滑動';
    }
  }

  /// 舊版型只在讀取時轉換，不回寫 Firestore，直到店主再次儲存。
  static String migrate(Object? raw) {
    switch (raw?.toString().trim()) {
      case horizontalScroll:
      case 'horizontal':
      case 'scroll':
        return horizontalScroll;
      case cardGrid:
      case 'compactCards':
      case 'mixedGrid':
        return cardGrid;
      case simpleEntry:
        return simpleEntry;
      case featured:
        return featured;
      case refinedCards:
        return refinedCards;
      default:
        return horizontalScroll;
    }
  }
}

class HomeRoomImageHeights {
  static const String compact = 'compact';
  static const String standard = 'standard';
  static const String tall = 'tall';
  static const List<String> all = <String>[compact, standard, tall];

  static String label(String value) {
    switch (value) {
      case compact:
        return '精簡';
      case tall:
        return '加高';
      default:
        return '標準';
    }
  }

  static double compactPixels(String value) {
    switch (value) {
      case compact:
        return 84;
      case tall:
        return 132;
      default:
        return 108;
    }
  }

  static double largePixels(String value) {
    switch (value) {
      case compact:
        return 148;
      case tall:
        return 212;
      default:
        return 176;
    }
  }

  /// 單卡比小卡完整，但不高到像海報。沿用大卡圖片高度的三段設定。
  static double singlePixels(String value) {
    switch (value) {
      case compact:
        return 120;
      case tall:
        return 160;
      default:
        return 140;
    }
  }
}

class HomeRoomAllRoomsPlacements {
  static const String titleRight = 'titleRight';
  static const String endCard = 'endCard';
  static const List<String> all = <String>[titleRight, endCard];
}

class HomeRoomSimpleCardSizes {
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

  /// 沒有欄位、空白或不認識的值都維持目前的滿寬長卡。
  static String migrate(Object? raw) {
    switch (raw?.toString().trim()) {
      case small:
        return small;
      case single:
        return single;
      case wide:
        return wide;
      default:
        return wide;
    }
  }
}

class HomeRoomSimpleIcons {
  static const String bed = 'bed';
  static const String home = 'home';
  static const String hotel = 'hotel';
  static const List<String> all = <String>[bed, home, hotel];

  static String label(String value) {
    switch (value) {
      case home:
        return '房屋';
      case hotel:
        return '寵物旅館';
      default:
        return '床鋪';
    }
  }
}

class HomeRoomSimpleSurfaces {
  static const String filled = 'filled';
  static const String outlined = 'outlined';
  static const String transparent = 'transparent';
  static const List<String> all = <String>[filled, outlined, transparent];

  static String label(String value) {
    switch (value) {
      case outlined:
        return '只有框線';
      case transparent:
        return '透明';
      default:
        return '淡色底';
    }
  }
}

class HomeRoomMixedTextPlacements {
  static const String below = 'below';
  static const String overlay = 'overlay';
  static const List<String> all = <String>[below, overlay];
}

class HomeRoomCardSizes {
  static const String small = 'small';
  static const String single = 'single';
  static const String wide = 'wide';

  /// 舊資料。讀取時轉成 [small]。
  static const String half = 'half';

  /// 舊資料。舊版滿寬卡是直式（圖在上、文字在下），讀取時轉成 [single]。
  static const String full = 'full';

  static const List<String> all = <String>[small, single, wide];

  static String label(String value) {
    switch (migrate(value)) {
      case single:
        return '單卡';
      case wide:
        return '長卡';
      default:
        return '小卡';
    }
  }

  static String migrate(Object? raw) {
    switch (raw?.toString().trim()) {
      case half:
      case small:
        return small;
      case full:
      case single:
        return single;
      case wide:
        return wide;
      default:
        return small;
    }
  }

  static bool occupiesOwnRow(String value) {
    final String size = migrate(value);
    return size == single || size == wide;
  }
}

class HomeRoomCompactSetting {
  const HomeRoomCompactSetting({
    this.columns = 2,
    this.imageHeight = HomeRoomImageHeights.standard,
    this.allRoomsPlacement = HomeRoomAllRoomsPlacements.endCard,
  });

  final int columns;
  final String imageHeight;
  final String allRoomsPlacement;

  int get safeColumns => columns == 1 ? 1 : 2;

  HomeRoomCompactSetting copyWith({
    int? columns,
    String? imageHeight,
    String? allRoomsPlacement,
  }) {
    return HomeRoomCompactSetting(
      columns: columns ?? this.columns,
      imageHeight: imageHeight ?? this.imageHeight,
      allRoomsPlacement: allRoomsPlacement ?? this.allRoomsPlacement,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'columns': safeColumns,
      'imageHeight': imageHeight,
      'allRoomsPlacement': allRoomsPlacement,
    };
  }

  static HomeRoomCompactSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeRoomCompactSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return HomeRoomCompactSetting(
      columns: _columns(map['columns']),
      imageHeight: _choice(
        map['imageHeight'],
        HomeRoomImageHeights.all,
        HomeRoomImageHeights.standard,
      ),
      allRoomsPlacement: _choice(
        map['allRoomsPlacement'],
        HomeRoomAllRoomsPlacements.all,
        HomeRoomAllRoomsPlacements.endCard,
      ),
    );
  }
}

class HomeRoomSimplePlacements {
  static const String independent = 'independent';
  static const String shared = 'shared';

  /// 舊資料沒有這個欄位時，維持原本的獨立簡約入口。
  static String migrate(Object? raw) {
    return raw == shared ? shared : independent;
  }
}

class HomeRoomSimpleColumns {
  static const int two = 2;
  static const int three = 3;
  static const int four = 4;

  /// 舊資料沒有這個欄位時，用一排 3 張的精緻尺寸。
  static int migrate(Object? raw) {
    final int value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString().trim() ?? '') ?? three;
    if (value == two || value == four) {
      return value;
    }
    return three;
  }
}

class HomeRoomSimpleTextModes {
  static const String below = 'below';
  static const String overlay = 'overlay';
  static const String caption = 'caption';
  static const List<String> all = <String>[below, overlay, caption];
}

class HomeRoomSimpleTextAligns {
  static const String bottomStart = 'bottomStart';
  static const String center = 'center';
  static const String bottomEnd = 'bottomEnd';
  static const List<String> all = <String>[bottomStart, center, bottomEnd];
}

class HomeRoomSimpleTextSizes {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
  static const List<String> all = <String>[small, medium, large];
}

class HomeRoomSimpleTextWeights {
  static const String regular = 'regular';
  static const String medium = 'medium';
  static const String bold = 'bold';
  static const List<String> all = <String>[regular, medium, bold];
}

class HomeRoomSimpleTextColors {
  static const String light = 'light';
  static const String dark = 'dark';
  static const String custom = 'custom';
  static const List<String> all = <String>[light, dark, custom];
}

class HomeRoomSimpleAspects {
  static const String square = 'square';
  static const String portrait = 'portrait';
  static const String landscape = 'landscape';
  static const List<String> all = <String>[square, portrait, landscape];
}

class HomeRoomSimpleRadii {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
  static const List<String> all = <String>[small, medium, large];
}

class HomeRoomSimpleMasks {
  static const String none = 'none';
  static const String light = 'light';
  static const String strong = 'strong';
  static const List<String> all = <String>[none, light, strong];
}

class HomeRoomSimpleSetting {
  const HomeRoomSimpleSetting({
    this.subtitle = '查看住宿空間與價格',
    this.showSubtitle = true,
    this.icon = HomeRoomSimpleIcons.bed,
    this.surface = HomeRoomSimpleSurfaces.filled,
    this.cardSize = HomeRoomSimpleCardSizes.wide,
    this.columns = HomeRoomSimpleColumns.three,
    this.placement = HomeRoomSimplePlacements.independent,
    this.imageAssetId = '',
    this.textMode = HomeRoomSimpleTextModes.below,
    this.textAlign = HomeRoomSimpleTextAligns.bottomStart,
    this.textSize = HomeRoomSimpleTextSizes.medium,
    this.textWeight = HomeRoomSimpleTextWeights.bold,
    this.textColor = HomeRoomSimpleTextColors.dark,
    this.textColorValue,
    this.aspect = HomeRoomSimpleAspects.square,
    this.radius = HomeRoomSimpleRadii.medium,
    this.mask = HomeRoomSimpleMasks.none,
  });

  static const Object _keep = Object();

  final String subtitle;
  final bool showSubtitle;
  final String icon;
  final String surface;
  final String cardSize;

  /// 舊版簡約入口曾把每排張數存在這裡。共用區改讀自己的欄數，此欄位只保留相容。
  final int columns;
  final String placement;

  /// 平台圖庫素材 ID。只給簡約入口使用，不寫進房型照片。
  final String imageAssetId;
  final String textMode;
  final String textAlign;
  final String textSize;
  final String textWeight;
  final String textColor;
  final int? textColorValue;
  final String aspect;
  final String radius;
  final String mask;

  HomeRoomSimpleSetting copyWith({
    Object? subtitle = _keep,
    Object? showSubtitle = _keep,
    Object? icon = _keep,
    Object? surface = _keep,
    Object? cardSize = _keep,
    Object? columns = _keep,
    Object? placement = _keep,
    Object? imageAssetId = _keep,
    Object? textMode = _keep,
    Object? textAlign = _keep,
    Object? textSize = _keep,
    Object? textWeight = _keep,
    Object? textColor = _keep,
    Object? textColorValue = _keep,
    Object? aspect = _keep,
    Object? radius = _keep,
    Object? mask = _keep,
  }) {
    return HomeRoomSimpleSetting(
      subtitle: subtitle == _keep ? this.subtitle : subtitle as String,
      showSubtitle: showSubtitle == _keep
          ? this.showSubtitle
          : showSubtitle as bool,
      icon: icon == _keep ? this.icon : icon as String,
      surface: surface == _keep ? this.surface : surface as String,
      cardSize: cardSize == _keep ? this.cardSize : cardSize as String,
      columns: columns == _keep
          ? this.columns
          : HomeRoomSimpleColumns.migrate(columns),
      placement: placement == _keep
          ? this.placement
          : HomeRoomSimplePlacements.migrate(placement),
      imageAssetId: imageAssetId == _keep
          ? this.imageAssetId
          : _assetId(imageAssetId),
      textMode: textMode == _keep ? this.textMode : textMode as String,
      textAlign: textAlign == _keep ? this.textAlign : textAlign as String,
      textSize: textSize == _keep ? this.textSize : textSize as String,
      textWeight: textWeight == _keep ? this.textWeight : textWeight as String,
      textColor: textColor == _keep ? this.textColor : textColor as String,
      textColorValue: textColorValue == _keep
          ? this.textColorValue
          : textColorValue as int?,
      aspect: aspect == _keep ? this.aspect : aspect as String,
      radius: radius == _keep ? this.radius : radius as String,
      mask: mask == _keep ? this.mask : mask as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'subtitle': subtitle,
      'showSubtitle': showSubtitle,
      'icon': icon,
      'surface': surface,
      'cardSize': HomeRoomSimpleCardSizes.migrate(cardSize),
      'columns': HomeRoomSimpleColumns.migrate(columns),
      'placement': HomeRoomSimplePlacements.migrate(placement),
      'imageAssetId': imageAssetId,
      'textMode': textMode,
      'textAlign': textAlign,
      'textSize': textSize,
      'textWeight': textWeight,
      'textColor': textColor,
      if (textColorValue != null) 'textColorValue': textColorValue,
      'aspect': aspect,
      'radius': radius,
      'mask': mask,
    };
  }

  static HomeRoomSimpleSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeRoomSimpleSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String subtitle = _clip(map['subtitle'], 40);
    final Object? colorValue = map['textColorValue'];
    return HomeRoomSimpleSetting(
      subtitle: subtitle.isEmpty ? '查看住宿空間與價格' : subtitle,
      showSubtitle: map['showSubtitle'] is bool
          ? map['showSubtitle'] as bool
          : true,
      icon: _choice(
        map['icon'],
        HomeRoomSimpleIcons.all,
        HomeRoomSimpleIcons.bed,
      ),
      surface: _choice(
        map['surface'],
        HomeRoomSimpleSurfaces.all,
        HomeRoomSimpleSurfaces.filled,
      ),
      cardSize: HomeRoomSimpleCardSizes.migrate(map['cardSize']),
      columns: HomeRoomSimpleColumns.migrate(map['columns']),
      placement: HomeRoomSimplePlacements.migrate(map['placement']),
      imageAssetId: _assetId(map['imageAssetId']),
      textMode: _choice(
        map['textMode'],
        HomeRoomSimpleTextModes.all,
        HomeRoomSimpleTextModes.below,
      ),
      textAlign: _choice(
        map['textAlign'],
        HomeRoomSimpleTextAligns.all,
        HomeRoomSimpleTextAligns.bottomStart,
      ),
      textSize: _choice(
        map['textSize'],
        HomeRoomSimpleTextSizes.all,
        HomeRoomSimpleTextSizes.medium,
      ),
      textWeight: _choice(
        map['textWeight'],
        HomeRoomSimpleTextWeights.all,
        HomeRoomSimpleTextWeights.bold,
      ),
      textColor: _choice(
        map['textColor'],
        HomeRoomSimpleTextColors.all,
        HomeRoomSimpleTextColors.dark,
      ),
      textColorValue: colorValue is num ? colorValue.toInt() : null,
      aspect: _choice(
        map['aspect'],
        HomeRoomSimpleAspects.all,
        HomeRoomSimpleAspects.square,
      ),
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
    );
  }
}

class HomeRoomMixedSetting {
  const HomeRoomMixedSetting({
    this.textPlacement = HomeRoomMixedTextPlacements.below,
    this.largeImageHeight = HomeRoomImageHeights.standard,
    this.smallImageHeight = HomeRoomImageHeights.standard,
    this.defaultCardSize = HomeRoomCardSizes.small,
    this.itemSizes = const <String, String>{},
  });

  final String textPlacement;
  final String largeImageHeight;
  final String smallImageHeight;

  /// 沒有個別尺寸的房型用這個尺寸。舊的一排一張會讀成 single。
  final String defaultCardSize;
  final Map<String, String> itemSizes;

  String sizeOf(String roomTypeId) {
    if (itemSizes.containsKey(roomTypeId)) {
      return HomeRoomCardSizes.migrate(itemSizes[roomTypeId]);
    }
    return HomeRoomCardSizes.migrate(defaultCardSize);
  }

  HomeRoomMixedSetting copyWith({
    String? textPlacement,
    String? largeImageHeight,
    String? smallImageHeight,
    String? defaultCardSize,
    Map<String, String>? itemSizes,
  }) {
    return HomeRoomMixedSetting(
      textPlacement: textPlacement ?? this.textPlacement,
      largeImageHeight: largeImageHeight ?? this.largeImageHeight,
      smallImageHeight: smallImageHeight ?? this.smallImageHeight,
      defaultCardSize: defaultCardSize ?? this.defaultCardSize,
      itemSizes: itemSizes ?? this.itemSizes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'textPlacement': textPlacement,
      'largeImageHeight': largeImageHeight,
      'smallImageHeight': smallImageHeight,
      'defaultCardSize': HomeRoomCardSizes.migrate(defaultCardSize),
      'itemSizes': <String, String>{
        for (final MapEntry<String, String> entry in itemSizes.entries)
          if (entry.key.trim().isNotEmpty)
            entry.key.trim(): HomeRoomCardSizes.migrate(entry.value),
      },
    };
  }

  static HomeRoomMixedSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeRoomMixedSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    return HomeRoomMixedSetting(
      textPlacement: _choice(
        map['textPlacement'],
        HomeRoomMixedTextPlacements.all,
        HomeRoomMixedTextPlacements.below,
      ),
      largeImageHeight: _choice(
        map['largeImageHeight'],
        HomeRoomImageHeights.all,
        HomeRoomImageHeights.standard,
      ),
      smallImageHeight: _choice(
        map['smallImageHeight'],
        HomeRoomImageHeights.all,
        HomeRoomImageHeights.standard,
      ),
      defaultCardSize: HomeRoomCardSizes.migrate(map['defaultCardSize']),
      itemSizes: _itemSizes(map['itemSizes']),
    );
  }
}

/// 一列裡的房型卡或「查看全部房型」補位。
class HomeRoomSlot {
  const HomeRoomSlot.room(
    this.roomTypeId, {
    required this.fullWidth,
    this.size = HomeRoomCardSizes.small,
  }) : allRooms = false;

  const HomeRoomSlot.allRooms({required this.fullWidth})
    : roomTypeId = null,
      allRooms = true,
      size = HomeRoomCardSizes.small;

  final String? roomTypeId;
  final bool allRooms;
  final bool fullWidth;
  final String size;
}

class HomeRoomSectionSetting {
  const HomeRoomSectionSetting({
    this.schemaVersion = 1,
    this.layout = HomeRoomSectionLayouts.horizontalScroll,
    this.title = '房型介紹',
    this.showPrice = true,
    this.fontFamily = '',
    this.fallbackCoverAssetId = '',
    this.roomTypeOrder = const <String>[],
    this.hiddenRoomTypeIds = const <String>[],
    this.compact = const HomeRoomCompactSetting(),
    this.simple = const HomeRoomSimpleSetting(),
    this.mixed = const HomeRoomMixedSetting(),
  });

  /// 與店名字體同一套已安裝字型。空字串代表房型展示維持原本字體。
  static const List<String> fontFamilies = <String>[
    'jfOpenHuninn',
    'NotoSansTC',
    'NotoSerifTC',
    'KleeOne',
    'ChironSungHK',
  ];

  final int schemaVersion;
  final String layout;
  final String title;
  final bool showPrice;

  /// 只影響房型展示文字。空字串不指定 fontFamily。
  final String fontFamily;

  /// 平台圖庫素材 ID。只在房型沒有自己的照片時當作預設圖，不寫回房型。
  final String fallbackCoverAssetId;
  final List<String> roomTypeOrder;
  final List<String> hiddenRoomTypeIds;
  final HomeRoomCompactSetting compact;
  final HomeRoomSimpleSetting simple;
  final HomeRoomMixedSetting mixed;

  /// 可套用的房型展示字體。未知代號回傳 null。
  String? get appliedFontFamily {
    if (fontFamilies.contains(fontFamily)) {
      return fontFamily;
    }
    return null;
  }

  static const Object _keep = Object();

  HomeRoomSectionSetting copyWith({
    Object? schemaVersion = _keep,
    Object? layout = _keep,
    Object? title = _keep,
    Object? showPrice = _keep,
    Object? fontFamily = _keep,
    Object? fallbackCoverAssetId = _keep,
    Object? roomTypeOrder = _keep,
    Object? hiddenRoomTypeIds = _keep,
    Object? compact = _keep,
    Object? simple = _keep,
    Object? mixed = _keep,
  }) {
    return HomeRoomSectionSetting(
      schemaVersion: schemaVersion == _keep
          ? this.schemaVersion
          : schemaVersion as int,
      layout: layout == _keep ? this.layout : layout as String,
      title: title == _keep ? this.title : title as String,
      showPrice: showPrice == _keep ? this.showPrice : showPrice as bool,
      fontFamily: fontFamily == _keep
          ? this.fontFamily
          : _fontFamily(fontFamily),
      fallbackCoverAssetId: fallbackCoverAssetId == _keep
          ? this.fallbackCoverAssetId
          : _assetId(fallbackCoverAssetId),
      roomTypeOrder: roomTypeOrder == _keep
          ? this.roomTypeOrder
          : List<String>.from(roomTypeOrder as List<String>),
      hiddenRoomTypeIds: hiddenRoomTypeIds == _keep
          ? this.hiddenRoomTypeIds
          : List<String>.from(hiddenRoomTypeIds as List<String>),
      compact: compact == _keep
          ? this.compact
          : compact as HomeRoomCompactSetting,
      simple: simple == _keep ? this.simple : simple as HomeRoomSimpleSetting,
      mixed: mixed == _keep ? this.mixed : mixed as HomeRoomMixedSetting,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'layout': layout,
      'title': title,
      'showPrice': showPrice,
      'fontFamily': fontFamily,
      'fallbackCoverAssetId': fallbackCoverAssetId,
      'roomTypeOrder': roomTypeOrder,
      'hiddenRoomTypeIds': hiddenRoomTypeIds,
      'cardGrid': <String, dynamic>{
        ...mixed.toMap(),
        'allRoomsPlacement': compact.allRoomsPlacement,
      },
      'simple': simple.toMap(),
    };
  }

  static HomeRoomSectionSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeRoomSectionSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String title = _clip(map['title'], 24);
    final String rawLayout = map['layout']?.toString().trim() ?? '';
    final HomeRoomCompactSetting compact = HomeRoomCompactSetting.fromMap(
      map['compact'],
    );
    return HomeRoomSectionSetting(
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
      layout: HomeRoomSectionLayouts.migrate(rawLayout),
      title: title.isEmpty ? '房型介紹' : title,
      showPrice: map['showPrice'] is bool ? map['showPrice'] as bool : true,
      fontFamily: _fontFamily(map['fontFamily']),
      fallbackCoverAssetId: _assetId(map['fallbackCoverAssetId']),
      roomTypeOrder: _stringList(map['roomTypeOrder']),
      hiddenRoomTypeIds: _stringList(map['hiddenRoomTypeIds']),
      compact: _placementFrom(map, compact),
      simple: HomeRoomSimpleSetting.fromMap(map['simple']),
      mixed: _cardGridFrom(map, rawLayout, compact),
    );
  }

  static HomeRoomCompactSetting _placementFrom(
    Map<String, dynamic> map,
    HomeRoomCompactSetting compact,
  ) {
    final Object? cardGrid = map['cardGrid'];
    if (cardGrid is Map && cardGrid['allRoomsPlacement'] != null) {
      return compact.copyWith(
        allRoomsPlacement: _choice(
          cardGrid['allRoomsPlacement'],
          HomeRoomAllRoomsPlacements.all,
          compact.allRoomsPlacement,
        ),
      );
    }
    return compact;
  }

  static HomeRoomMixedSetting _cardGridFrom(
    Map<String, dynamic> map,
    String rawLayout,
    HomeRoomCompactSetting compact,
  ) {
    final Object? stored = map['cardGrid'] ?? map['mixed'];
    final HomeRoomMixedSetting mixed = HomeRoomMixedSetting.fromMap(stored);
    if (map['cardGrid'] is Map) {
      return mixed;
    }
    final bool legacyFullRow =
        rawLayout == 'compactCards' && compact.safeColumns == 1;
    if (rawLayout == 'compactCards') {
      return mixed.copyWith(
        smallImageHeight: compact.imageHeight,
        largeImageHeight: compact.imageHeight,
        defaultCardSize: legacyFullRow
            ? HomeRoomCardSizes.single
            : HomeRoomCardSizes.small,
      );
    }
    if (legacyFullRow) {
      return mixed.copyWith(defaultCardSize: HomeRoomCardSizes.single);
    }
    return mixed;
  }

  static String roomTypeIdOf(Map<dynamic, dynamic> room) {
    final Object? id = room['id'] ?? room['roomTypeId'];
    return id == null ? '' : id.toString().trim();
  }

  /// 沒有 isPublished 的舊房型視為已發布。這個判斷不會寫回房型文件。
  static bool isRoomPublished(Map<dynamic, dynamic> room) {
    if (!room.containsKey('isPublished')) {
      return true;
    }
    final Object? value = room['isPublished'];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String text = value.toString().trim().toLowerCase();
    return text != 'false' && text != '0';
  }

  static String priceLabel(Object? rawPrice) {
    final int price = rawPrice is num
        ? rawPrice.toInt()
        : int.tryParse(rawPrice?.toString() ?? '') ?? 0;
    if (price <= 0) {
      return '價格洽店家';
    }
    return 'NT\$$price／晚起';
  }

  static List<String> knownIds(List<Map<dynamic, dynamic>> rooms) {
    final List<String> ids = <String>[];
    for (final Map<dynamic, dynamic> room in rooms) {
      final String id = roomTypeIdOf(room);
      if (id.isEmpty || ids.contains(id)) {
        continue;
      }
      ids.add(id);
    }
    return ids;
  }

  static bool hasPublishedRooms(List<Map<dynamic, dynamic>> rooms) {
    for (final Map<dynamic, dynamic> room in rooms) {
      if (roomTypeIdOf(room).isEmpty) {
        continue;
      }
      if (isRoomPublished(room)) {
        return true;
      }
    }
    return false;
  }

  /// 去掉重複與已刪除的 ID，新房型接在最後。未發布房型仍留在順序裡。
  static List<String> normalizeOrder({
    required List<String> saved,
    required List<String> knownIds,
  }) {
    final Set<String> known = knownIds.toSet();
    final List<String> kept = <String>[];
    for (final String id in saved) {
      final String trimmed = id.trim();
      if (trimmed.isEmpty ||
          !known.contains(trimmed) ||
          kept.contains(trimmed)) {
        continue;
      }
      kept.add(trimmed);
    }
    for (final String id in knownIds) {
      if (!kept.contains(id)) {
        kept.add(id);
      }
    }
    return kept;
  }

  static List<String> reorder({
    required List<String> saved,
    required List<String> visible,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= visible.length || visible.isEmpty) {
      return List<String>.from(saved);
    }
    int target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0) {
      target = 0;
    }
    if (target > visible.length - 1) {
      target = visible.length - 1;
    }
    if (target == oldIndex) {
      return List<String>.from(saved);
    }
    final List<String> nextVisible = List<String>.from(visible);
    final String moved = nextVisible.removeAt(oldIndex);
    nextVisible.insert(target, moved);
    final List<String> queue = List<String>.from(nextVisible);
    return saved.map((String id) {
      if (!visible.contains(id)) {
        return id;
      }
      return queue.removeAt(0);
    }).toList();
  }

  List<String> orderedIds(List<Map<dynamic, dynamic>> rooms) {
    return normalizeOrder(saved: roomTypeOrder, knownIds: knownIds(rooms));
  }

  /// 首頁實際畫出來的已發布、未隱藏房型，沿用儲存順序。
  List<String> homeRoomIds(List<Map<dynamic, dynamic>> rooms) {
    final Set<String> hidden = hiddenRoomTypeIds.toSet();
    final Map<String, Map<dynamic, dynamic>> byId =
        <String, Map<dynamic, dynamic>>{};
    for (final Map<dynamic, dynamic> room in rooms) {
      final String id = roomTypeIdOf(room);
      if (id.isNotEmpty) {
        byId[id] = room;
      }
    }
    return orderedIds(rooms).where((String id) {
      final Map<dynamic, dynamic>? room = byId[id];
      if (room == null || hidden.contains(id)) {
        return false;
      }
      return isRoomPublished(room);
    }).toList();
  }

  /// 排序面板要列出的已發布房型，包含暫時從首頁隱藏的房型。
  List<String> publishedIds(List<Map<dynamic, dynamic>> rooms) {
    final Map<String, Map<dynamic, dynamic>> byId =
        <String, Map<dynamic, dynamic>>{};
    for (final Map<dynamic, dynamic> room in rooms) {
      final String id = roomTypeIdOf(room);
      if (id.isNotEmpty) {
        byId[id] = room;
      }
    }
    return orderedIds(rooms).where((String id) {
      final Map<dynamic, dynamic>? room = byId[id];
      return room != null && isRoomPublished(room);
    }).toList();
  }

  static List<List<HomeRoomSlot>> compactRows({
    required List<String> roomIds,
    required int columns,
    required bool includeEndCard,
  }) {
    final List<HomeRoomSlot> slots = <HomeRoomSlot>[
      for (final String id in roomIds)
        HomeRoomSlot.room(id, fullWidth: columns == 1),
    ];
    if (includeEndCard) {
      slots.add(HomeRoomSlot.allRooms(fullWidth: columns == 1));
    }
    if (columns == 1) {
      return <List<HomeRoomSlot>>[
        for (final HomeRoomSlot slot in slots) <HomeRoomSlot>[slot],
      ];
    }
    final List<List<HomeRoomSlot>> rows = <List<HomeRoomSlot>>[];
    for (int index = 0; index < slots.length; index += 2) {
      if (index + 1 < slots.length) {
        rows.add(<HomeRoomSlot>[slots[index], slots[index + 1]]);
      } else {
        rows.add(<HomeRoomSlot>[slots[index]]);
      }
    }
    return rows;
  }

  /// 小卡兩張一排。單卡與長卡各自一排。落單小卡只在啟用全部房型卡時補一次右側入口。
  static List<List<HomeRoomSlot>> mixedRows({
    required List<String> roomIds,
    required String Function(String id) sizeOf,
    bool fillWithAllRooms = true,
  }) {
    final List<List<HomeRoomSlot>> rows = <List<HomeRoomSlot>>[];
    String? pendingHalf;
    bool usedAllRooms = false;
    void flushPending() {
      final String? pending = pendingHalf;
      if (pending == null) {
        return;
      }
      pendingHalf = null;
      if (fillWithAllRooms && !usedAllRooms) {
        usedAllRooms = true;
        rows.add(<HomeRoomSlot>[
          HomeRoomSlot.room(
            pending,
            fullWidth: false,
            size: HomeRoomCardSizes.small,
          ),
          const HomeRoomSlot.allRooms(fullWidth: false),
        ]);
        return;
      }
      rows.add(<HomeRoomSlot>[
        HomeRoomSlot.room(
          pending,
          fullWidth: false,
          size: HomeRoomCardSizes.small,
        ),
      ]);
    }

    for (final String id in roomIds) {
      final String size = HomeRoomCardSizes.migrate(sizeOf(id));
      if (HomeRoomCardSizes.occupiesOwnRow(size)) {
        flushPending();
        rows.add(<HomeRoomSlot>[
          HomeRoomSlot.room(id, fullWidth: true, size: size),
        ]);
        continue;
      }
      if (pendingHalf == null) {
        pendingHalf = id;
        continue;
      }
      rows.add(<HomeRoomSlot>[
        HomeRoomSlot.room(
          pendingHalf,
          fullWidth: false,
          size: HomeRoomCardSizes.small,
        ),
        HomeRoomSlot.room(id, fullWidth: false, size: HomeRoomCardSizes.small),
      ]);
      pendingHalf = null;
    }
    flushPending();
    if (rows.isEmpty) {
      return <List<HomeRoomSlot>>[
        const <HomeRoomSlot>[HomeRoomSlot.allRooms(fullWidth: true)],
      ];
    }
    return rows;
  }
}

String _choice(Object? raw, List<String> allowed, String fallback) {
  final String value = raw?.toString().trim() ?? '';
  return allowed.contains(value) ? value : fallback;
}

int _columns(Object? raw) {
  if (raw is num && raw.toInt() == 1) {
    return 1;
  }
  if (raw?.toString().trim() == '1') {
    return 1;
  }
  return 2;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) {
    return <String>[];
  }
  final List<String> values = <String>[];
  for (final Object? item in raw) {
    final String id = item?.toString().trim() ?? '';
    if (id.isEmpty || values.contains(id)) {
      continue;
    }
    values.add(id);
  }
  return values;
}

Map<String, String> _itemSizes(Object? raw) {
  if (raw is! Map) {
    return <String, String>{};
  }
  final Map<String, String> sizes = <String, String>{};
  raw.forEach((dynamic key, dynamic value) {
    final String id = key.toString().trim();
    final String size = value?.toString().trim() ?? '';
    if (id.isEmpty || size.isEmpty) {
      return;
    }
    sizes[id] = HomeRoomCardSizes.migrate(size);
  });
  return sizes;
}

String _clip(Object? raw, int maxCharacters) {
  final String value = raw?.toString().trim() ?? '';
  if (value.characters.length <= maxCharacters) {
    return value;
  }
  return value.characters.take(maxCharacters).toString();
}

String _fontFamily(Object? raw) {
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
