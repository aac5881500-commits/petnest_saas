// 功能：整間店共用的房型介紹列表與詳細頁外觀，與首頁房型展示分開。
import 'room_intro_look.dart';
export 'room_intro_look.dart';

class RoomListAppearance {
  const RoomListAppearance({
    this.layout = 'vertical',
    this.title = '房間介紹',
    this.description = '每個房型都會顯示可入住數量、價格與特色，方便快速了解。',
    this.showDescription = true,
    this.imageAspect = 'landscape',
    this.imageFit = 'cover',
    this.showCapacity = true,
    this.showFeatures = true,
    this.spacing = 'standard',
    this.buttonStyle = 'tonal',
    this.roomOrder = const [],
    this.look = const RoomIntroLook(),
  });
  final String layout,
      title,
      description,
      imageAspect,
      imageFit,
      spacing,
      buttonStyle;
  final bool showDescription, showCapacity, showFeatures;
  final List<String> roomOrder;
  final RoomIntroLook look;
  RoomListAppearance copyWith({
    String? layout,
    String? title,
    String? description,
    bool? showDescription,
    String? imageAspect,
    String? imageFit,
    bool? showCapacity,
    bool? showFeatures,
    String? spacing,
    String? buttonStyle,
    List<String>? roomOrder,
    RoomIntroLook? look,
  }) => RoomListAppearance(
    layout: layout ?? this.layout,
    title: title ?? this.title,
    description: description ?? this.description,
    showDescription: showDescription ?? this.showDescription,
    imageAspect: imageAspect ?? this.imageAspect,
    imageFit: imageFit ?? this.imageFit,
    showCapacity: showCapacity ?? this.showCapacity,
    showFeatures: showFeatures ?? this.showFeatures,
    spacing: spacing ?? this.spacing,
    buttonStyle: buttonStyle ?? this.buttonStyle,
    roomOrder: roomOrder ?? this.roomOrder,
    look: look ?? this.look,
  );
  Map<String, dynamic> toMap() => {
    'layout': _choice(layout, [
      'vertical',
      'horizontal',
      'columns',
      'carousel',
      'switcher',
      'comparison',
      'lodging',
    ], 'vertical'),
    'title': title,
    'description': description,
    'showDescription': showDescription,
    'imageAspect': imageAspect,
    'imageFit': imageFit,
    'showCapacity': showCapacity,
    'showFeatures': showFeatures,
    'spacing': spacing,
    'buttonStyle': buttonStyle,
    'roomOrder': roomOrder,
    'look': look.toMap(),
  };
  static RoomListAppearance fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    return RoomListAppearance(
      look: RoomIntroLook.fromMap(m['look']),
      layout: _choice(m['layout'], [
        'vertical',
        'horizontal',
        'columns',
        'carousel',
        'switcher',
        'comparison',
        'lodging',
      ], 'vertical'),
      title: m['title'] is String ? m['title'] : '房間介紹',
      description: m['description'] is String
          ? m['description']
          : const RoomListAppearance().description,
      showDescription: m['showDescription'] != false,
      imageAspect: _aspect(m['imageAspect']),
      imageFit: _fit(m['imageFit']),
      showCapacity: m['showCapacity'] != false,
      showFeatures: m['showFeatures'] != false,
      spacing: _space(m['spacing']),
      buttonStyle: _choice(m['buttonStyle'], [
        'tonal',
        'filled',
        'text',
      ], 'tonal'),
      roomOrder: m['roomOrder'] is List
          ? (m['roomOrder'] as List)
                .whereType<String>()
                .where((id) => id.trim().isNotEmpty)
                .toSet()
                .toList()
          : const [],
    );
  }

  List<Map<String, dynamic>> ordered(List<Map<String, dynamic>> rooms) {
    final byId = {for (final room in rooms) room['id']?.toString(): room};
    final used = <String>{};
    return [
      for (final id in roomOrder)
        if (byId.containsKey(id) && used.add(id)) byId[id]!,
      for (final room in rooms)
        if (!used.contains(room['id']?.toString())) room,
    ];
  }
}

class RoomDetailAppearance {
  const RoomDetailAppearance({
    this.layout = 'classic',
    this.photoLayout = 'bottom',
    this.imageAspect = 'landscape',
    this.imageFit = 'cover',
    this.showThumbnails = true,
    this.dimensionsStyle = 'tiles',
    this.contentOrder = 'descriptionFirst',
    this.surface = 'theme',
    this.radius = 'standard',
    this.spacing = 'standard',
    this.look = const RoomIntroLook(),
  });
  final String photoLayout,
      layout,
      imageAspect,
      imageFit,
      dimensionsStyle,
      contentOrder,
      surface,
      radius,
      spacing;
  final bool showThumbnails;
  final RoomIntroLook look;
  RoomDetailAppearance copyWith({
    String? photoLayout,
    String? layout,
    String? imageAspect,
    String? imageFit,
    bool? showThumbnails,
    String? dimensionsStyle,
    String? contentOrder,
    String? surface,
    String? radius,
    String? spacing,
    RoomIntroLook? look,
  }) => RoomDetailAppearance(
    photoLayout: photoLayout ?? this.photoLayout,
    layout: layout ?? this.layout,
    imageAspect: imageAspect ?? this.imageAspect,
    imageFit: imageFit ?? this.imageFit,
    showThumbnails: showThumbnails ?? this.showThumbnails,
    dimensionsStyle: dimensionsStyle ?? this.dimensionsStyle,
    contentOrder: contentOrder ?? this.contentOrder,
    surface: surface ?? this.surface,
    radius: radius ?? this.radius,
    spacing: spacing ?? this.spacing,
    look: look ?? this.look,
  );
  Map<String, dynamic> toMap() => {
    'photoLayout': photoLayout,
    'layout': layout,
    'imageAspect': imageAspect,
    'imageFit': imageFit,
    'showThumbnails': showThumbnails,
    'dimensionsStyle': dimensionsStyle,
    'contentOrder': contentOrder,
    'surface': surface,
    'radius': radius,
    'spacing': spacing,
    'look': look.toMap(),
  };
  static RoomDetailAppearance fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    return RoomDetailAppearance(
      photoLayout: _choice(m['photoLayout'], [
        'bottom',
        'left',
        'right',
        'overlay',
        'collage',
        'grid',
      ], 'bottom'),
      look: RoomIntroLook.fromMap(m['look']),
      layout: _choice(m['layout'], [
        'classic',
        'compact',
        'sideBySide',
        'tabs',
        'panel',
        'anchors',
        'lodging',
      ], 'classic'),
      imageAspect: _aspect(m['imageAspect']),
      imageFit: _fit(m['imageFit']),
      showThumbnails: m['showThumbnails'] != false,
      dimensionsStyle: _choice(m['dimensionsStyle'], [
        'tiles',
        'line',
      ], 'tiles'),
      contentOrder: _choice(m['contentOrder'], [
        'descriptionFirst',
        'featuresFirst',
      ], 'descriptionFirst'),
      surface: _choice(m['surface'], ['theme', 'pale', 'transparent'], 'theme'),
      radius: _choice(m['radius'], ['small', 'standard', 'large'], 'standard'),
      spacing: _space(m['spacing']),
    );
  }

  double get cornerRadius => radius == 'small'
      ? 10
      : radius == 'large'
      ? 24
      : 18;
}

class RoomIntroAppearance {
  const RoomIntroAppearance({
    this.showComparison = true,
    this.list = const RoomListAppearance(),
    this.detail = const RoomDetailAppearance(),
  });
  final RoomListAppearance list;
  final bool showComparison;
  final RoomDetailAppearance detail;
  static const path = 'homeAppearance.roomIntro';
  RoomIntroAppearance copyWith({
    bool? showComparison,
    RoomListAppearance? list,
    RoomDetailAppearance? detail,
  }) => RoomIntroAppearance(
    showComparison: showComparison ?? this.showComparison,
    list: list ?? this.list,
    detail: detail ?? this.detail,
  );
  Map<String, dynamic> toMap() => {
    'list': list.toMap(),
    'showComparison': showComparison,
    'detail': detail.toMap(),
  };
  static RoomIntroAppearance fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    return RoomIntroAppearance(
      showComparison: m['showComparison'] != false,
      list: RoomListAppearance.fromMap(m['list']),
      detail: RoomDetailAppearance.fromMap(m['detail']),
    );
  }

  static RoomIntroAppearance fromShop(Map<String, dynamic>? shop) {
    final home = shop?['homeAppearance'];
    return fromMap(home is Map ? home['roomIntro'] : null);
  }
}

double roomImageRatio(String aspect) => aspect == 'square'
    ? 1
    : aspect == 'wide'
    ? 16 / 9
    : 4 / 3;
double roomSectionGap(String spacing) => spacing == 'compact'
    ? 8
    : spacing == 'wide'
    ? 22
    : 14;
List<String> roomPhotoUrls(Object? raw) => raw is List
    ? raw
          .map((item) => item is Map ? item['imageUrl'] ?? item['url'] : item)
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList()
    : const [];
String _choice(Object? raw, List<String> values, String fallback) =>
    values.contains(raw) ? raw as String : fallback;
String _aspect(Object? raw) =>
    _choice(raw, ['square', 'landscape', 'wide'], 'landscape');
String _fit(Object? raw) => _choice(raw, ['cover', 'contain'], 'cover');
String _space(Object? raw) =>
    _choice(raw, ['compact', 'standard', 'wide'], 'standard');
