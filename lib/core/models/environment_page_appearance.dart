// 檔案：lib/core/models/environment_page_appearance.dart
// 功能：環境介紹專用字體、配色與背景覆寫，不更動全站主題。
import 'package:flutter/material.dart';
import 'home_theme_model.dart';

class EnvironmentPageAppearance {
  EnvironmentPageAppearance({Map<String, dynamic>? raw})
    : _raw = Map.of(raw ?? {});
  final Map<String, dynamic> _raw;
  factory EnvironmentPageAppearance.fromMap(dynamic raw) =>
      EnvironmentPageAppearance(
        raw: raw is Map ? Map<String, dynamic>.from(raw) : null,
      );
  static const fonts = {
    '': '跟隨店家主題',
    'jfOpenHuninn': '粉圓體',
    'NotoSansTC': '思源黑體 TC',
    'NotoSerifTC': '思源宋體 TC',
    'ChironSungHK': '昭源宋體',
  };
  String? get fontFamily =>
      fonts.containsKey(_raw['fontFamily']) && _raw['fontFamily'] != ''
      ? _raw['fontFamily'] as String
      : null;
  Color? color(String key) {
    final raw = _raw[key];
    int? value;
    if (raw is int && raw >= 0 && raw <= 0xffffffff) value = raw;
    if (raw is String &&
        RegExp(r'^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(raw)) {
      value = int.tryParse(raw.replaceFirst('#', ''), radix: 16);
    }
    return value == null ? null : Color(value | 0xff000000);
  }

  bool get hasColors => [
    'textColor',
    'secondaryTextColor',
    'accentColor',
    'backgroundColor',
    'cardColor',
  ].any((key) => color(key) != null);
  String get backgroundMode =>
      const ['theme', 'solid', 'image'].contains(_raw['backgroundMode'])
      ? _raw['backgroundMode'] as String
      : 'theme';
  String get backgroundAssetId =>
      (_raw['backgroundAssetId'] ?? '').toString().trim();
  double _number(String key, double fallback) =>
      _raw[key] is num && (_raw[key] as num).isFinite
      ? (_raw[key] as num).toDouble().clamp(0, 1)
      : fallback;
  double get imageOpacity => _number('imageOpacity', .7);
  double get maskOpacity => _number('maskOpacity', .25);
  bool get darkMask => _raw['maskTone'] == 'dark';
  EnvironmentPageAppearance copyWith(Map<String, dynamic> changes) =>
      EnvironmentPageAppearance(raw: {..._raw, ...changes});
  Map<String, dynamic> toMap() => Map.of(_raw);
  EnvironmentPageAppearance reset() => copyWith({
    for (final key in [
      'fontFamily',
      'textColor',
      'secondaryTextColor',
      'accentColor',
      'backgroundColor',
      'cardColor',
      'backgroundMode',
      'backgroundAssetId',
      'imageOpacity',
      'maskOpacity',
      'maskTone',
    ])
      key: null,
  });

  static Color readable(Color ink, Color surface) {
    final a = ink.computeLuminance(), b = surface.computeLuminance();
    final contrast = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
    if (contrast >= 3) return ink;
    return surface.computeLuminance() > .179
        ? const Color(0xff202124)
        : Colors.white;
  }

  HomeThemeModel resolve(HomeThemeModel base, {bool card = false}) {
    if (!hasColors) return base;
    final background = color('backgroundColor') ?? base.backgroundColor;
    final fill = color('cardColor') ?? base.cardColor;
    final surface = card ? fill : background;
    return base.copyWith(
      backgroundColorValue: background.toARGB32(),
      cardColorValue: fill.toARGB32(),
      textColorValue: readable(
        color('textColor') ?? base.textColor,
        surface,
      ).toARGB32(),
      secondaryTextColorValue: readable(
        color('secondaryTextColor') ?? base.secondaryTextColor,
        surface,
      ).toARGB32(),
      primaryColorValue: readable(
        color('accentColor') ?? base.primaryColor,
        surface,
      ).toARGB32(),
    );
  }
}
