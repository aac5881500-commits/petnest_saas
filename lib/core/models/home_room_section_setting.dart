// 新版首頁房型展示設定。存在 shops/{shopId}.homeAppearance.modern.roomSection。

import 'package:flutter/widgets.dart';

class HomeRoomSectionLayouts {
  static const String horizontalScroll = 'horizontalScroll';
  static const String cardGrid = 'cardGrid';
  static const String simpleEntry = 'simpleEntry';
  static const List<String> all = <String>[
    horizontalScroll,
    cardGrid,
    simpleEntry,
  ];

  static String label(String value) {
    switch (value) {
      case cardGrid:
        return '卡片拼排';
      case simpleEntry:
        return '簡約入口';
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
}

class HomeRoomAllRoomsPlacements {
  static const String titleRight = 'titleRight';
  static const String endCard = 'endCard';
  static const List<String> all = <String>[titleRight, endCard];
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
  static const String full = 'full';
  static const String half = 'half';
  static const List<String> all = <String>[full, half];
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

class HomeRoomSimpleSetting {
  const HomeRoomSimpleSetting({
    this.subtitle = '查看住宿空間與價格',
    this.showSubtitle = true,
    this.icon = HomeRoomSimpleIcons.bed,
    this.surface = HomeRoomSimpleSurfaces.filled,
  });

  final String subtitle;
  final bool showSubtitle;
  final String icon;
  final String surface;

  HomeRoomSimpleSetting copyWith({
    String? subtitle,
    bool? showSubtitle,
    String? icon,
    String? surface,
  }) {
    return HomeRoomSimpleSetting(
      subtitle: subtitle ?? this.subtitle,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      icon: icon ?? this.icon,
      surface: surface ?? this.surface,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'subtitle': subtitle,
      'showSubtitle': showSubtitle,
      'icon': icon,
      'surface': surface,
    };
  }

  static HomeRoomSimpleSetting fromMap(Object? raw) {
    if (raw is! Map) {
      return const HomeRoomSimpleSetting();
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String subtitle = _clip(map['subtitle'], 40);
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
    );
  }
}

class HomeRoomMixedSetting {
  const HomeRoomMixedSetting({
    this.textPlacement = HomeRoomMixedTextPlacements.below,
    this.largeImageHeight = HomeRoomImageHeights.standard,
    this.smallImageHeight = HomeRoomImageHeights.standard,
    this.defaultCardSize = HomeRoomCardSizes.half,
    this.itemSizes = const <String, String>{},
  });

  final String textPlacement;
  final String largeImageHeight;
  final String smallImageHeight;

  /// 沒有個別尺寸的房型用這個尺寸。一排一張的舊資料會讀成 full。
  final String defaultCardSize;
  final Map<String, String> itemSizes;

  String sizeOf(String roomTypeId) {
    final String? chosen = itemSizes[roomTypeId];
    if (chosen == HomeRoomCardSizes.full || chosen == HomeRoomCardSizes.half) {
      return chosen!;
    }
    return defaultCardSize == HomeRoomCardSizes.full
        ? HomeRoomCardSizes.full
        : HomeRoomCardSizes.half;
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
      'defaultCardSize': defaultCardSize,
      'itemSizes': itemSizes,
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
      defaultCardSize: _choice(
        map['defaultCardSize'],
        HomeRoomCardSizes.all,
        HomeRoomCardSizes.half,
      ),
      itemSizes: _itemSizes(map['itemSizes']),
    );
  }
}

/// 一列裡的房型卡或「查看全部房型」補位。
class HomeRoomSlot {
  const HomeRoomSlot.room(this.roomTypeId, {required this.fullWidth})
    : allRooms = false;

  const HomeRoomSlot.allRooms({required this.fullWidth})
    : roomTypeId = null,
      allRooms = true;

  final String? roomTypeId;
  final bool allRooms;
  final bool fullWidth;
}

class HomeRoomSectionSetting {
  const HomeRoomSectionSetting({
    this.schemaVersion = 1,
    this.layout = HomeRoomSectionLayouts.horizontalScroll,
    this.title = '房型介紹',
    this.showPrice = true,
    this.roomTypeOrder = const <String>[],
    this.hiddenRoomTypeIds = const <String>[],
    this.compact = const HomeRoomCompactSetting(),
    this.simple = const HomeRoomSimpleSetting(),
    this.mixed = const HomeRoomMixedSetting(),
  });

  final int schemaVersion;
  final String layout;
  final String title;
  final bool showPrice;
  final List<String> roomTypeOrder;
  final List<String> hiddenRoomTypeIds;
  final HomeRoomCompactSetting compact;
  final HomeRoomSimpleSetting simple;
  final HomeRoomMixedSetting mixed;

  static const Object _keep = Object();

  HomeRoomSectionSetting copyWith({
    Object? schemaVersion = _keep,
    Object? layout = _keep,
    Object? title = _keep,
    Object? showPrice = _keep,
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
            ? HomeRoomCardSizes.full
            : HomeRoomCardSizes.half,
      );
    }
    if (legacyFullRow) {
      return mixed.copyWith(defaultCardSize: HomeRoomCardSizes.full);
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

  /// 大卡自己一排。小卡兩張一排。落單小卡只在啟用全部房型卡時補一次右側入口。
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
          HomeRoomSlot.room(pending, fullWidth: false),
          const HomeRoomSlot.allRooms(fullWidth: false),
        ]);
        return;
      }
      rows.add(<HomeRoomSlot>[HomeRoomSlot.room(pending, fullWidth: false)]);
    }

    for (final String id in roomIds) {
      if (sizeOf(id) == HomeRoomCardSizes.full) {
        flushPending();
        rows.add(<HomeRoomSlot>[HomeRoomSlot.room(id, fullWidth: true)]);
        continue;
      }
      if (pendingHalf == null) {
        pendingHalf = id;
        continue;
      }
      rows.add(<HomeRoomSlot>[
        HomeRoomSlot.room(pendingHalf, fullWidth: false),
        HomeRoomSlot.room(id, fullWidth: false),
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
    if (id.isEmpty || !HomeRoomCardSizes.all.contains(size)) {
      return;
    }
    sizes[id] = size;
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
