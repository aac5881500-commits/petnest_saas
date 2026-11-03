import 'package:flutter/material.dart';

/// APP-first controls. Desktop placement is derived from the same values.
/// There is no template ID or shop-specific branch in the renderer.
class EnvironmentLayoutSettings {
  EnvironmentLayoutSettings([Map<String, dynamic>? data])
    : _data = Map.of(data ?? {});
  final Map<String, dynamic> _data;
  factory EnvironmentLayoutSettings.fromMap(dynamic value) =>
      EnvironmentLayoutSettings(
        value is Map ? Map<String, dynamic>.from(value) : null,
      );
  String _choice(String key, List<String> values, String fallback) =>
      values.contains(_data[key]) ? _data[key] as String : fallback;
  double number(String key, double fallback, double min, double max) {
    final value = _data[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  String get heroLayout =>
      _choice('heroLayout', ['overlay', 'split'], 'overlay');
  String get featureLayout =>
      _choice('featureLayout', ['standard', 'photoSide'], 'standard');
  String get bannerLayout =>
      _choice('bannerLayout', ['overlay', 'split'], 'overlay');
  String get equipmentLayout =>
      _choice('equipmentLayout', ['standard', 'mediaRow'], 'standard');
  bool get footerTogether => _data['footerTogether'] == true;
  bool get showFeatureHeading => _data['showFeatureHeading'] != false;
  bool get showEquipmentHeading => _data['showEquipmentHeading'] != false;
  bool get showGalleryHeading => _data['showGalleryHeading'] != false;
  bool get showFeatureIcon => _data['showFeatureIcon'] != false;
  bool get showDivider => _data['showDivider'] == true;
  bool get autoDesktop => _data.isNotEmpty;
  String text(String key) => (_data[key] ?? '').toString();
  double get photoFraction => number('photoFraction', .4, .25, .6);
  double get photoHeight => number('photoHeight', 122, 100, 240);
  double get cardRadius => number('cardRadius', 10, 0, 28);
  double get spacing => number('spacing', 14, 4, 36);
  double get titleSize => number('titleSize', 17, 13, 28);
  Color color(String key, Color fallback) {
    final raw = _data[key];
    if (raw is! num || !raw.isFinite) return fallback;
    final value = raw.toInt();
    if (value < 0 || value > 4294967295) return fallback;
    return Color(value < 16777216 ? value + 4278190080 : value);
  }

  Map<String, dynamic> toMap() => Map.of(_data);
  EnvironmentLayoutSettings copyWith(Map<String, dynamic> changes) =>
      EnvironmentLayoutSettings({..._data, ...changes});
}

class EnvironmentBuiltinPhotos {
  static const asset = 'assets/images/environment_warm_photos_v1.png';
  static const warmAsset = 'assets/images/home_warm_photo_atlas_v1.png';
  static String assetFor(String id) =>
      id.startsWith('warm-') ? warmAsset : asset;
  static const names = {
    'warm-hero': '暖陽熟睡貓咪',
    'warm-room': '日光木質貓房',
    'warm-climb': '森林貓跳台',
    'warm-about': '溫暖陪伴貓咪',
    'warm-shop': '暖木店面',
    'warm-store': '貓咪日常好物',
    'cover': '木質貓旅封面',
    'cover-backdrop': '木質散景背景',
    'rest': '窗邊貓窩',
    'climb': '垂直貓跳台',
    'water': '獨立飲水',
    'sun': '自然日照',
    'jump': '探索跳台',
    'banner': '貓咪休憩橫幅',
    'gallery-rest': '休憩相簿',
    'gallery-window': '窗邊相簿',
  };
  static const crops = <String, Rect>{
    'warm-hero': Rect.fromLTWH(0, 0, 512, 512),
    'warm-room': Rect.fromLTWH(512, 0, 512, 512),
    'warm-climb': Rect.fromLTWH(1024, 0, 512, 512),
    'warm-about': Rect.fromLTWH(0, 512, 512, 512),
    'warm-shop': Rect.fromLTWH(512, 512, 512, 512),
    'warm-store': Rect.fromLTWH(1024, 512, 512, 512),
    'cover': Rect.fromLTWH(610, 108, 538, 236),
    'cover-backdrop': Rect.fromLTWH(52, 108, 550, 52),
    'rest': Rect.fromLTWH(82, 368, 296, 188),
    'climb': Rect.fromLTWH(611, 368, 242, 188),
    'water': Rect.fromLTWH(144, 588, 45, 88),
    'sun': Rect.fromLTWH(502, 588, 97, 88),
    'jump': Rect.fromLTWH(855, 588, 91, 88),
    'banner': Rect.fromLTWH(726, 701, 396, 105),
    'gallery-rest': Rect.fromLTWH(82, 822, 296, 147),
    'gallery-window': Rect.fromLTWH(393, 822, 315, 147),
  };
  static String url(String id) => 'builtin-env:$id';
  static String? id(String url) =>
      url.startsWith('builtin-env:') && crops.containsKey(url.substring(12))
      ? url.substring(12)
      : null;
}
