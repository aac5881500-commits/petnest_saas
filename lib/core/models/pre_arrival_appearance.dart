import 'package:flutter/material.dart';

/// This page's overrides; absent values preserve the original skin.
class PreArrivalAppearance {
  const PreArrivalAppearance({
    this.colorMode = 'style',
    this.fontFamily = 'style',
    this.fontScale = 1,
    this.accentColor,
    this.textColor,
    this.backgroundColor,
    this.cardColor,
  });
  static const fonts = {
    'style': '版型原字體',
    'theme': '跟隨店家主題',
    'jfOpenHuninn': '粉圓體',
    'NotoSansTC': '思源黑體',
    'NotoSerifTC': '思源宋體',
    'KleeOne': '手寫楷體',
    'ChironSungHK': '昭源宋體',
  };
  final String colorMode, fontFamily;
  final double fontScale;
  final int? accentColor, textColor, backgroundColor, cardColor;
  bool get isDefault =>
      colorMode == 'style' &&
      fontFamily == 'style' &&
      fontScale == 1 &&
      accentColor == null &&
      textColor == null &&
      backgroundColor == null &&
      cardColor == null;
  static int? _color(Object? raw) =>
      raw is int && raw >= 0xff000000 && raw <= 0xffffffff ? raw : null;
  factory PreArrivalAppearance.fromMap(Object? value) {
    final m = value is Map ? value : const {};
    return PreArrivalAppearance(
      colorMode: ['style', 'theme', 'custom'].contains(m['colorMode'])
          ? m['colorMode'] as String
          : 'style',
      fontFamily: fonts.containsKey(m['fontFamily'])
          ? m['fontFamily'] as String
          : 'style',
      fontScale: m['fontScale'] is num && (m['fontScale'] as num).isFinite
          ? (m['fontScale'] as num).toDouble().clamp(.85, 1.4)
          : 1,
      accentColor: _color(m['accentColor']),
      textColor: _color(m['textColor']),
      backgroundColor: _color(m['backgroundColor']),
      cardColor: _color(m['cardColor']),
    );
  }
  Map<String, dynamic> toMap() => {
    'colorMode': colorMode,
    'fontFamily': fontFamily,
    'fontScale': fontScale,
    'accentColor': accentColor,
    'textColor': textColor,
    'backgroundColor': backgroundColor,
    'cardColor': cardColor,
  };
  PreArrivalAppearance copyWith(Map<String, dynamic> changes) =>
      PreArrivalAppearance.fromMap({...toMap(), ...changes});
  Color? color(String role) {
    final v = toMap()[role];
    return v is int ? Color(v) : null;
  }
}
