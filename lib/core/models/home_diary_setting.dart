/// C homepage layout. Only presentation and references to existing shop content.
class HomeDiarySetting {
  const HomeDiarySetting({
    this.reference = defaultReference,
    this.enabled = false,
    this.coverLayout = 'split',
    this.coverPhotoSource = 'cover',
    this.coverPhotoSide = 'right',
    this.coverTitle = '好好生活，安心住下',
    this.coverSubtitle = '讓貓咪放鬆、安心的小天地。\n像家一樣自在。',
    this.coverTag = '貓咪旅店',
    this.coverPhotoFraction = .55,
    this.coverPhotoAspect = 1.1,
    this.coverTitleSize = 25,
    this.fontFamily = 'KleeOne',
    this.showTimeline = true,
    this.lineColor = 0xFF9CCAE0,
    this.lineWidth = 1,
    this.gutter = 26,
    this.marker = 'paw',
    this.headingSize = 16,
    this.showPaper = true,
    this.showTape = true,
    this.decorationOpacity = .5,
    this.compactCare = true,
    this.groupPreparation = true,
    this.groupStore = true,
    this.alternatePhotos = true,
    this.environmentPhotoHeight = 118,
    this.environmentPhotoFraction = .52,
    this.timelineSections = const [
      'announcements',
      'facilities',
      'rooms',
      'about',
      'services',
      'policy',
      'faq',
      'reviews',
      'featured',
      'storeEntrance',
      'quickBooking',
      'shopInfo',
    ],
    this.titles = const {
      'announcements': '今天的旅店消息',
      'facilities': '在這裡，慢慢過日子',
      'rooms': '選一個喜歡的小窩',
      'about': '關於我們',
      'services': '照護小日常',
      'policy': '入住前的準備',
      'faq': '常見問題',
      'reviews': '旅客好評',
      'featured': '喜歡的好物',
      'storeEntrance': '逛逛商城',
      'quickBooking': '安排下一段小假期',
      'shopInfo': '聯絡我們',
    },
    this.surfaces = const {
      'policy': 'blue',
      'reviews': 'paper',
      'services': 'paper',
    },
  });

  // Every reference-only visual has an owner control; no business photos here.
  static const defaultReference = <String, dynamic>{
    'cards': true,
    'flowers': true,
    'photoTape': true,
    'headingTape': false,
    'coverBlend': true,
    'careAvatar': true,
    'careContinuous': true,
    'careInline': true,
    'careServices': true,
    'markerColor': 0xFFE7A03C,
    'coverBodySize': 10.5,
    'environmentTitleSize': 14.0,
    'environmentBodySize': 11.0,
    'roomPhotoHeight': 90.0,
    'roomFraction': .48,
    'aboutPhotoHeight': 100.0,
    'aboutFraction': .48,
    'productFraction': .52,
    'service1': '每日清潔',
    'service2': '專人照護',
    'service3': '照護回報',
  };
  final Map<String, dynamic> reference;
  bool refFlag(String key) => reference[key] is bool
      ? reference[key] as bool
      : defaultReference[key] == true;
  double refNumber(String key) =>
      (reference[key] as num? ?? defaultReference[key] as num).toDouble();
  String refText(String key) =>
      (reference[key] ?? defaultReference[key] ?? '').toString();
  bool get referenceCards => enabled && refFlag('cards');
  bool get flowers => refFlag('flowers');
  int get markerColor => (reference['markerColor'] as int?) ?? 0xFFE7A03C;
  static Map<String, dynamic> cleanReference(dynamic raw) {
    final input = raw is Map ? raw : const {};
    final out = <String, dynamic>{...defaultReference};
    for (final entry in defaultReference.entries) {
      final value = input[entry.key];
      if (entry.value is bool && value is bool) out[entry.key] = value;
      if (entry.value is String && value is String) out[entry.key] = value;
    }
    for (final key in ['roomFraction', 'aboutFraction', 'productFraction']) {
      final value = input[key];
      if (value is num && value.isFinite) {
        out[key] = value.toDouble().clamp(.35, .7);
      }
    }
    for (final key in ['roomPhotoHeight', 'aboutPhotoHeight']) {
      final value = input[key];
      if (value is num && value.isFinite) {
        out[key] = value.toDouble().clamp(70, 200);
      }
    }
    for (final key in ['environmentTitleSize', 'environmentBodySize']) {
      final value = input[key];
      if (value is num && value.isFinite) {
        out[key] = value.toDouble().clamp(9, 22);
      }
    }
    final body = input['coverBodySize'];
    if (body is num && body.isFinite) {
      out['coverBodySize'] = body.toDouble().clamp(9, 18);
    }
    final color = input['markerColor'];
    if (color is int && color >= 0 && color <= 0xFFFFFFFF) {
      out['markerColor'] = color;
    }
    return Map.unmodifiable(out);
  }

  static const paperAsset = 'assets/images/home_diary_paper_v1.png';
  static const tapeAsset = 'assets/images/home_diary_tape_v1.png';
  static const sectionLabels = {
    'announcements': '公告與消息',
    'facilities': '環境介紹',
    'rooms': '房型介紹',
    'about': '關於我們',
    'services': '照護服務',
    'policy': '入住須知',
    'faq': '常見問題',
    'reviews': '顧客評價',
    'featured': '精選商品',
    'storeEntrance': '商城入口',
    'quickBooking': '快速預約',
    'shopInfo': '旅店資訊',
  };
  final bool enabled,
      showTimeline,
      showPaper,
      showTape,
      compactCare,
      groupPreparation,
      groupStore,
      alternatePhotos;
  final String coverLayout,
      coverPhotoSource,
      coverPhotoSide,
      coverTitle,
      coverSubtitle,
      coverTag,
      fontFamily,
      marker;
  final double coverPhotoFraction,
      coverPhotoAspect,
      coverTitleSize,
      lineWidth,
      gutter,
      headingSize,
      decorationOpacity,
      environmentPhotoHeight,
      environmentPhotoFraction;
  final int lineColor;
  final List<String> timelineSections;
  final Map<String, String> titles, surfaces;

  HomeDiarySetting copyWith({
    Map<String, dynamic>? reference,
    bool? enabled,
    bool? showTimeline,
    bool? showPaper,
    bool? showTape,
    bool? compactCare,
    bool? groupPreparation,
    bool? groupStore,
    bool? alternatePhotos,
    String? coverLayout,
    String? coverPhotoSource,
    String? coverPhotoSide,
    String? coverTitle,
    String? coverSubtitle,
    String? coverTag,
    String? fontFamily,
    String? marker,
    double? coverPhotoFraction,
    double? coverPhotoAspect,
    double? coverTitleSize,
    double? lineWidth,
    double? gutter,
    double? headingSize,
    double? decorationOpacity,
    double? environmentPhotoHeight,
    double? environmentPhotoFraction,
    int? lineColor,
    List<String>? timelineSections,
    Map<String, String>? titles,
    Map<String, String>? surfaces,
  }) => HomeDiarySetting.fromMap({
    ...toMap(),
    'reference': ?reference,
    'enabled': ?enabled,
    'showTimeline': ?showTimeline,
    'showPaper': ?showPaper,
    'showTape': ?showTape,
    'compactCare': ?compactCare,
    'groupPreparation': ?groupPreparation,
    'groupStore': ?groupStore,
    'alternatePhotos': ?alternatePhotos,
    'coverLayout': ?coverLayout,
    'coverPhotoSource': ?coverPhotoSource,
    'coverPhotoSide': ?coverPhotoSide,
    'coverTitle': ?coverTitle,
    'coverSubtitle': ?coverSubtitle,
    'coverTag': ?coverTag,
    'fontFamily': ?fontFamily,
    'marker': ?marker,
    'coverPhotoFraction': ?coverPhotoFraction,
    'coverPhotoAspect': ?coverPhotoAspect,
    'coverTitleSize': ?coverTitleSize,
    'lineWidth': ?lineWidth,
    'gutter': ?gutter,
    'headingSize': ?headingSize,
    'decorationOpacity': ?decorationOpacity,
    'environmentPhotoHeight': ?environmentPhotoHeight,
    'environmentPhotoFraction': ?environmentPhotoFraction,
    'lineColor': ?lineColor,
    'timelineSections': ?timelineSections,
    'titles': ?titles,
    'surfaces': ?surfaces,
  });

  Map<String, dynamic> toMap() => {
    'reference': reference,
    'enabled': enabled,
    'showTimeline': showTimeline,
    'showPaper': showPaper,
    'showTape': showTape,
    'compactCare': compactCare,
    'groupPreparation': groupPreparation,
    'groupStore': groupStore,
    'alternatePhotos': alternatePhotos,
    'coverLayout': coverLayout,
    'coverPhotoSource': coverPhotoSource,
    'coverPhotoSide': coverPhotoSide,
    'coverTitle': coverTitle,
    'coverSubtitle': coverSubtitle,
    'coverTag': coverTag,
    'fontFamily': fontFamily,
    'marker': marker,
    'coverPhotoFraction': coverPhotoFraction,
    'coverPhotoAspect': coverPhotoAspect,
    'coverTitleSize': coverTitleSize,
    'lineWidth': lineWidth,
    'gutter': gutter,
    'headingSize': headingSize,
    'decorationOpacity': decorationOpacity,
    'environmentPhotoHeight': environmentPhotoHeight,
    'environmentPhotoFraction': environmentPhotoFraction,
    'lineColor': lineColor,
    'timelineSections': timelineSections,
    'titles': titles,
    'surfaces': surfaces,
  };

  factory HomeDiarySetting.fromMap(dynamic raw) {
    final map = raw is Map ? raw : const {};
    const fallback = HomeDiarySetting();
    double number(String key, double initial, double min, double max) {
      final value = map[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : initial;
    }

    String choice(String key, List<String> values, String initial) =>
        values.contains(map[key]) ? map[key] as String : initial;
    String text(String key, String initial) =>
        map[key] is String ? (map[key] as String) : initial;
    Map<String, String> strings(String key, Map<String, String> initial) {
      final value = map[key];
      if (value is! Map) return initial;
      return Map.unmodifiable({
        for (final entry in value.entries)
          if (entry.key is String &&
              entry.value is String &&
              sectionLabels.containsKey(entry.key))
            entry.key as String: entry.value as String,
      });
    }

    final color = map['lineColor'];
    return HomeDiarySetting(
      reference: cleanReference(map['reference']),
      enabled: map['enabled'] == true,
      showTimeline: map['showTimeline'] != false,
      showPaper: map['showPaper'] != false,
      showTape: map['showTape'] != false,
      compactCare: map['compactCare'] != false,
      groupPreparation: map['groupPreparation'] != false,
      groupStore: map['groupStore'] != false,
      alternatePhotos: map['alternatePhotos'] != false,
      coverLayout: choice('coverLayout', ['split', 'banner'], 'split'),
      coverPhotoSource: choice('coverPhotoSource', [
        'cover',
        'banner',
      ], 'cover'),
      coverPhotoSide: choice('coverPhotoSide', ['left', 'right'], 'right'),
      coverTitle: text('coverTitle', fallback.coverTitle),
      coverSubtitle: text('coverSubtitle', fallback.coverSubtitle),
      coverTag: text('coverTag', fallback.coverTag),
      fontFamily: choice('fontFamily', [
        'KleeOne',
        'NotoSansTC',
        'jfOpenHuninn',
      ], 'KleeOne'),
      marker: choice('marker', ['paw', 'dot'], 'paw'),
      coverPhotoFraction: number('coverPhotoFraction', .55, .35, .7),
      coverPhotoAspect: number('coverPhotoAspect', 1.1, .6, 2.4),
      coverTitleSize: number('coverTitleSize', 25, 18, 38),
      lineWidth: number('lineWidth', 1, .5, 4),
      gutter: number('gutter', 26, 20, 48),
      headingSize: number('headingSize', 16, 13, 26),
      decorationOpacity: number('decorationOpacity', .5, 0, 1),
      environmentPhotoHeight: number('environmentPhotoHeight', 118, 90, 220),
      environmentPhotoFraction: number(
        'environmentPhotoFraction',
        .52,
        .35,
        .65,
      ),
      lineColor: color is int && color >= 0 && color <= 0xFFFFFFFF
          ? color
          : fallback.lineColor,
      timelineSections: map['timelineSections'] is List
          ? List.unmodifiable(
              (map['timelineSections'] as List)
                  .whereType<String>()
                  .where(sectionLabels.containsKey)
                  .toSet(),
            )
          : fallback.timelineSections,
      titles: strings('titles', fallback.titles),
      surfaces: strings('surfaces', fallback.surfaces).map(
        (key, value) => MapEntry(
          key,
          const ['plain', 'paper', 'cream', 'blue'].contains(value)
              ? value
              : 'plain',
        ),
      ),
    );
  }
}
