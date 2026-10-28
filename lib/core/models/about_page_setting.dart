import 'shop_service_showcase.dart';
// 功能：完整關於我們頁的內容與外觀；首頁小卡保持獨立，舊欄位仍為介紹單一來源。
import 'package:flutter/material.dart';
import 'environment_page_appearance.dart';
import 'home_theme_model.dart';
import 'about_cover_frame_setting.dart';

class AboutMedia {
  const AboutMedia({this.source = 'none', this.url = '', this.assetId = ''});
  final String source, url, assetId;
  AboutMedia copyWith({String? source, String? url, String? assetId}) =>
      AboutMedia(
        source: source ?? this.source,
        url: url ?? this.url,
        assetId: assetId ?? this.assetId,
      );
  Map<String, dynamic> toMap() => {
    'source': source,
    'url': url,
    'assetId': assetId,
  };
  static AboutMedia fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    final source = '${m['source'] ?? 'none'}';
    final id = '${m['assetId'] ?? ''}'.trim();
    return AboutMedia(
      source:
          const [
            'none',
            'legacy',
            'shop',
            'firstGallery',
            'platform',
          ].contains(source)
          ? source
          : 'none',
      url: '${m['url'] ?? ''}'.trim(),
      assetId: id.length <= 128 && !id.contains('/') ? id : '',
    );
  }

  String resolveShop(Map<String, dynamic> shop) {
    if (source == 'legacy') return '${shop['aboutImageUrl'] ?? ''}'.trim();
    if (source == 'shop') return url;
    if (source == 'firstGallery') {
      return aboutShopPhotos(shop).firstOrNull ?? '';
    }
    return '';
  }
}

List<String> aboutShopPhotos(Map<String, dynamic> shop) {
  final intro = shop['environmentIntro'];
  final gallery = intro is Map ? intro['galleryImages'] : null;
  final result = <String>[];
  if (gallery is List) {
    for (final raw in gallery) {
      final item = raw is Map ? raw['imageUrl'] ?? raw['url'] : raw;
      if (item is String && item.trim().isNotEmpty) result.add(item.trim());
    }
  }
  return result.toSet().toList();
}

class AboutContentItem {
  const AboutContentItem({
    required this.id,
    this.title = '',
    this.text = '',
    this.role = '',
    this.icon = 'pets',
    this.visible = true,
    this.image = const AboutMedia(),
  });
  final String id, title, text, role, icon;
  final bool visible;
  final AboutMedia image;
  bool get hasContent =>
      title.trim().isNotEmpty ||
      text.trim().isNotEmpty ||
      role.trim().isNotEmpty ||
      image.source != 'none';
  AboutContentItem copyWith({
    String? title,
    String? text,
    String? role,
    String? icon,
    bool? visible,
    AboutMedia? image,
  }) => AboutContentItem(
    id: id,
    title: title ?? this.title,
    text: text ?? this.text,
    role: role ?? this.role,
    icon: icon ?? this.icon,
    visible: visible ?? this.visible,
    image: image ?? this.image,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'text': text,
    'role': role,
    'icon': icon,
    'visible': visible,
    'image': image.toMap(),
  };
  static AboutContentItem fromMap(Map raw, int index) => AboutContentItem(
    id: '${raw['id'] ?? 'legacy-$index'}',
    title: '${raw['title'] ?? ''}',
    text: '${raw['text'] ?? ''}',
    role: '${raw['role'] ?? ''}',
    icon: '${raw['icon'] ?? 'pets'}',
    visible: raw['visible'] != false,
    image: AboutMedia.fromMap(raw['image']),
  );
}

class AboutPageSetting {
  AboutPageSetting({Map<String, dynamic>? raw}) : _raw = Map.of(raw ?? {});
  final Map<String, dynamic> _raw;
  static const path = 'homeAppearance.aboutPage';
  static const layouts = {
    'classic': '原有排版',
    'brief': '簡介版',
    'story': '故事版',
    'alternating': '圖文交錯版',
    'principles': '理念卡片版',
    'team': '團隊版',
    'boutique': '品牌名片版',
    'highlights': '特色導覽版',
    'editorial': '雜誌專欄版',
  };
  static const contactLayouts = {
    'list': '經典清單',
    'tiles': '資訊方格',
    'brand': '品牌名片',
    'visit': '到店指南',
  };
  static const highlightLayouts = {
    'cards': '圖示卡片',
    'ribbon': '橫向亮點',
    'numbered': '編號專欄',
  };
  String get contactLayout => choice(
    'contactLayout',
    contactLayouts.keys.toList(),
    layout == 'boutique'
        ? 'brand'
        : layout == 'editorial'
        ? 'visit'
        : layout == 'highlights'
        ? 'tiles'
        : 'list',
  );
  String get highlightLayout => choice(
    'highlightLayout',
    highlightLayouts.keys.toList(),
    layout == 'editorial'
        ? 'numbered'
        : layout == 'highlights'
        ? 'ribbon'
        : 'cards',
  );
  static const sectionNames = {
    'services': '服務項目',
    'highlights': '店家特色',
    'stories': '品牌故事',
    'principles': '照護理念',
    'team': '團隊介紹',
    'credentials': '專業與經歷',
    'message': '給毛孩爸媽的話',
    'contact': '店家資訊',
  };
  ShopServiceShowcase get serviceShowcase =>
      ShopServiceShowcase.fromMap(_raw['moduleShowcase']);
  String get layout =>
      layouts.containsKey(_raw['layout']) ? '${_raw['layout']}' : 'classic';
  bool get expandable => _raw['expandable'] == true;
  AboutMedia get cover => _raw.containsKey('cover')
      ? AboutMedia.fromMap(_raw['cover'])
      : const AboutMedia(source: 'legacy');
  AboutCoverFrameSetting coverFrame(Map<String, dynamic> shop) =>
      AboutCoverFrameSetting.fromMap({
        ...shop,
        if (_raw['coverFrame'] is Map)
          ...Map<String, dynamic>.from(_raw['coverFrame']),
      });
  List<AboutContentItem> items(String section) {
    final raw = _raw[section];
    if (raw is! List) return const [];
    return [
      for (var i = 0; i < raw.length; i++)
        if (raw[i] is Map) AboutContentItem.fromMap(raw[i], i),
    ];
  }

  bool visible(String section) =>
      section == 'contact' ||
      _raw['visibility'] is! Map ||
      (_raw['visibility'] as Map)[section] != false;
  List<String> get sectionOrder {
    final raw = _raw['sectionOrder'];
    final defaults = layout == 'boutique'
        ? ['contact', 'highlights']
        : layout == 'highlights'
        ? ['highlights', 'principles']
        : layout == 'team'
        ? ['team', 'principles']
        : ['brief', 'principles'].contains(layout)
        ? ['principles']
        : ['stories'];
    return {
      ...(raw is List
          ? raw.whereType<String>().where(sectionNames.containsKey)
          : defaults),
      ...sectionNames.keys,
    }.toList();
  }

  Map<String, dynamic> get appearance => _raw['appearance'] is Map
      ? Map<String, dynamic>.from(_raw['appearance'])
      : {};
  AboutPageSetting copyWith(Map<String, dynamic> changes) =>
      AboutPageSetting(raw: {..._raw, ...changes});
  Map<String, dynamic> toMap() => Map.of(_raw);
  static AboutPageSetting fromMap(Object? raw) =>
      AboutPageSetting(raw: raw is Map ? Map<String, dynamic>.from(raw) : null);
  static AboutPageSetting fromShop(Map<String, dynamic> shop) {
    final home = shop['homeAppearance'];
    final setting = fromMap(home is Map ? home['aboutPage'] : null);
    // Carry over the short-lived environment-page preference until the next
    // About save stores it at its final destination. Never overwrite About data.
    if (!setting._raw.containsKey('moduleShowcase')) {
      final intro = shop['environmentIntro'];
      final presentation = intro is Map
          ? intro['environmentPresentation']
          : null;
      final previous = presentation is Map
          ? presentation['moduleShowcase']
          : null;
      if (previous is Map) {
        return setting.copyWith({
          'moduleShowcase': Map<String, dynamic>.from(previous),
        });
      }
    }
    return setting;
  }

  AboutPageSetting withItems(String key, List<AboutContentItem> value) =>
      copyWith({key: value.map((e) => e.toMap()).toList()});
  AboutPageSetting withAppearance(Map<String, dynamic> changes) => copyWith({
    'appearance': {...appearance, ...changes},
  });
  AboutPageSetting setVisible(String key, bool value) => copyWith({
    'visibility': {
      if (_raw['visibility'] is Map)
        ...Map<String, dynamic>.from(_raw['visibility']),
      key: key == 'contact' ? true : value,
    },
  });
  double number(
    String key,
    double fallback, {
    double min = 0,
    double max = 100,
  }) {
    final value = appearance[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  String choice(String key, List<String> values, String fallback) =>
      values.contains(appearance[key]) ? '${appearance[key]}' : fallback;
  Color color(String key, Color fallback) =>
      EnvironmentPageAppearance(raw: appearance).color(key) ?? fallback;
  double get textScale => number('textScale', 1, min: .85, max: 1.4);
  double get gap => appearance['cardsSource'] == 'custom'
      ? number('gap', 24, min: 8, max: 48)
      : 24;
  HomeThemeModel resolve(HomeThemeModel base) {
    if (appearance['colorsSource'] != 'custom') return base;
    return base.copyWith(
      primaryColorValue: color('accentColor', base.primaryColor).toARGB32(),
      textColorValue: color('bodyColor', base.textColor).toARGB32(),
      secondaryTextColorValue: color(
        'secondaryTextColor',
        base.secondaryTextColor,
      ).toARGB32(),
    );
  }

  String? get font => appearance['fontSource'] == 'custom'
      ? EnvironmentPageAppearance.fonts.containsKey(appearance['fontFamily'])
            ? '${appearance['fontFamily']}'
            : appearance['fontFamily'] == 'KleeOne'
            ? 'KleeOne'
            : null
      : null;
  static HomeThemeModel shopTheme(
    Map<String, dynamic> shop,
    HomeThemeModel fallback,
  ) {
    final home = shop['homeAppearance'];
    if (home is! Map) return fallback;
    final modern = home['modern'];
    return home['layout'] == 'modern'
        ? HomeThemeModel.fromMap(
            modern is Map ? modern['themeColors'] : null,
            fallback: HomeThemeModel.modernDefault,
          )
        : HomeThemeModel.fromClassicSettings(rawData: home['classic'] ?? home);
  }
}

// 只寫入改動的葉欄位，避免更新整份 homeAppearance 或另一個視窗的外觀欄位。
Map<String, dynamic> aboutPageUpdates(
  AboutPageSetting previous,
  AboutPageSetting next,
) {
  final updates = <String, dynamic>{};
  void diff(Map before, Map after, String path) {
    for (final key in after.keys) {
      final value = after[key], old = before[key];
      if (value is Map) {
        diff(old is Map ? old : const {}, value, '$path.$key');
      } else if (!_same(old, value)) {
        updates['$path.$key'] = value;
      }
    }
  }

  diff(previous.toMap(), next.toMap(), AboutPageSetting.path);
  return updates;
}

bool _same(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => _same(a[i], b[i])).every((same) => same);
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  return a == b;
}
