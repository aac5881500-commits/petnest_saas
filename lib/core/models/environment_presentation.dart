import 'package:flutter/material.dart';
// 檔案：lib/core/models/environment_presentation.dart
// 功能：環境介紹範本、設備與服務草稿序列化；保留未知欄位。
import 'environment_page_appearance.dart';

class EnvironmentServiceCard {
  EnvironmentServiceCard(Map<String, dynamic> data) : data = Map.of(data);
  final Map<String, dynamic> data;
  String get id => (data['id'] ?? '').toString();
  String get title => (data['title'] ?? '').toString().trim().isEmpty
      ? '未命名服務'
      : data['title'].toString();
  String get description => (data['description'] ?? '').toString();
  String get icon => (data['icon'] ?? 'pets').toString();
  String get category =>
      EnvironmentPresentation.categories.containsKey(data['category'])
      ? data['category'] as String
      : 'service';
  bool get visible => data['visible'] != false;
  String get tag => const ['included', 'contact', 'paid'].contains(data['tag'])
      ? data['tag'] as String
      : '';
  String get imageUrl => (data['imageUrl'] ?? '').toString().trim();
  String get imagePath => (data['imageStoragePath'] ?? '').toString().trim();
  Map<String, dynamic> toMap() => Map.of(data);
  EnvironmentServiceCard copyWith(Map<String, dynamic> changes) =>
      EnvironmentServiceCard({...data, ...changes});
}

class EnvironmentPresentation {
  Map<String, dynamic> get photoSettings => _raw['photoSettings'] is Map
      ? Map<String, dynamic>.from(_raw['photoSettings'])
      : {};
  Map<String, dynamic> photoSetting(String id, bool desktop) {
    final value = photoSettings['${desktop ? 'desktop' : 'phone'}_$id'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  double photoHeight(String id, double width, double fallback) {
    final settings = photoSetting(id, width >= 800);
    final aspect = const {
      '4:3': 4 / 3,
      '16:9': 16 / 9,
      '12:5': 12 / 5,
    }[settings['aspect']];
    final value = settings['height'];
    return aspect != null
        ? (width / aspect).clamp(100, 600)
        : value is num && value.isFinite
        ? value.toDouble().clamp(100, 600)
        : fallback;
  }

  BoxFit photoFit(String id, double width, BoxFit fallback) =>
      switch (photoSetting(id, width >= 800)['fit']) {
        'cover' => BoxFit.cover,
        'contain' => BoxFit.contain,
        _ => fallback,
      };
  Alignment photoAlignment(String id, double width, Alignment fallback) =>
      switch (photoSetting(id, width >= 800)['alignment']) {
        'top' => Alignment.topCenter,
        'center' => Alignment.center,
        'bottom' => Alignment.bottomCenter,
        _ => fallback,
      };
  String get galleryLayout =>
      const ['single', 'mosaic'].contains(_raw['galleryLayout'])
      ? _raw['galleryLayout'] as String
      : 'grid';
  Map<String, dynamic> get sectionGaps => _raw['sectionGaps'] is Map
      ? Map<String, dynamic>.from(_raw['sectionGaps'])
      : {};
  double sectionGap(String id, double fallback) {
    final value = sectionGaps[id];
    return value is num && value.isFinite
        ? value.toDouble().clamp(0, 64)
        : fallback;
  }

  static const sectionLabels = {
    'hero': '封面',
    'features': '環境特色',
    'banner': '中間橫幅',
    'care': '設備與服務',
    'gallery': '環境照片',
    'note': '提醒',
  };
  List<String> get sectionOrder {
    final defaults = switch (preset) {
      'care' => ['hero', 'care', 'features', 'banner', 'gallery', 'note'],
      'photo' => ['hero', 'gallery', 'features', 'banner', 'care', 'note'],
      'warm' ||
      'minimal' => ['hero', 'features', 'banner', 'care', 'gallery', 'note'],
      _ => ['hero', 'features', 'banner', 'care', 'note', 'gallery'],
    };
    final custom = _strings(
      'sectionOrder',
    ).where(sectionLabels.containsKey).toList();
    return [...custom, ...defaults.where((id) => !custom.contains(id))];
  }

  List<String> get hiddenSections =>
      _strings('hiddenSections').where(sectionLabels.containsKey).toList();
  String sectionTitle(String id, String fallback) {
    final titles = _raw['sectionTitles'];
    final value = titles is Map ? titles[id]?.toString().trim() ?? '' : '';
    return value.isEmpty ? fallback : value;
  }

  Map<String, dynamic> get sectionTitles => _raw['sectionTitles'] is Map
      ? Map<String, dynamic>.from(_raw['sectionTitles'])
      : {};
  static const categories = {
    'environment': '環境設備',
    'safety': '清潔安全',
    'care': '日常照護',
    'service': '貼心服務',
  };
  static const presets = {
    'warm': '溫暖旅宿',
    'minimal': '清爽簡約',
    'photo': '照片導覽',
    'care': '安心照護',
  };
  static const layouts = {
    'legacy': '原有樣式',
    'icon': '精簡圖示',
    'square': '說明方卡',
    'list': '橫向清單',
    'photo': '圖片服務卡',
  };
  EnvironmentPresentation({Map<String, dynamic>? raw})
    : _raw = Map.of(raw ?? {});
  final Map<String, dynamic> _raw;
  factory EnvironmentPresentation.fromMap(dynamic raw) =>
      EnvironmentPresentation(
        raw: raw is Map ? Map<String, dynamic>.from(raw) : null,
      );
  String get preset =>
      presets.containsKey(_raw['preset']) ? _raw['preset'] as String : '';
  double _number(String key, double fallback, double min, double max) {
    final value = _raw[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  double get contentMaxWidth => _number('contentMaxWidth', 1200, 800, 1400);
  double get featureImageMaxHeight =>
      _number('featureImageMaxHeight', 280, 160, 400);
  String get desktopColumns =>
      const ['auto', 'single', 'double'].contains(_raw['desktopColumns'])
      ? _raw['desktopColumns'] as String
      : 'auto';
  String get desktopCardLayout =>
      const [
        'horizontal',
        'vertical',
        'text',
      ].contains(_raw['desktopCardLayout'])
      ? _raw['desktopCardLayout'] as String
      : 'inherit';
  bool get customized => _raw['customized'] == true;
  bool get groupedFacilities => _raw['groupFacilities'] == true;
  EnvironmentPageAppearance get appearance =>
      EnvironmentPageAppearance.fromMap(_raw['appearance']);
  String get equipmentLayout => layouts.containsKey(_raw['equipmentLayout'])
      ? _raw['equipmentLayout'] as String
      : 'legacy';
  String get serviceLayout => layouts.containsKey(_raw['serviceLayout'])
      ? _raw['serviceLayout'] as String
      : 'legacy';
  List<String> _strings(String key) => _raw[key] is List
      ? (_raw[key] as List).whereType<String>().toSet().toList()
      : [];
  List<String> get facilityOrder => _strings('facilityOrder');
  List<String> get hiddenFacilityKeys => _strings('hiddenFacilityKeys');
  List<EnvironmentServiceCard> get services {
    final seen = <String>{};
    return (_raw['customServices'] is List
            ? _raw['customServices'] as List
            : [])
        .whereType<Map>()
        .map((m) {
          final data = Map<String, dynamic>.from(m);
          if ((data['id'] ?? '').toString().isEmpty) {
            var hash = 2166136261;
            for (final unit
                in '${data['title']}|${data['description']}|${data['imageUrl']}|${data['category']}'
                    .codeUnits) {
              hash = ((hash ^ unit) * 16777619) & 0xffffffff;
            }
            data['id'] = 'legacy_${hash.toRadixString(16)}';
          }
          return EnvironmentServiceCard(data);
        })
        .where((s) => seen.add(s.id))
        .toList();
  }

  Map<String, dynamic> toMap() => Map.of(_raw);
  EnvironmentPresentation copyWith(Map<String, dynamic> changes) =>
      EnvironmentPresentation(raw: {..._raw, ...changes});
  EnvironmentPresentation applyPreset(String value) => copyWith({
    'preset': value,
    'customized': false,
    'equipmentLayout': value == 'minimal' || value == 'photo'
        ? 'list'
        : 'square',
    'serviceLayout': value == 'minimal' || value == 'photo' ? 'list' : 'square',
  });
}
