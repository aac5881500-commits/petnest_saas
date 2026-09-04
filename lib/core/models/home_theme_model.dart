// lib/core/models/home_theme_model.dart
// 🎨 首頁共用主題 Model
// 功能：統一管理 Classic、Modern 首頁的背景、卡片、外框、主色與文字顏色

import 'package:flutter/material.dart';
import 'package:petnest_saas/models/home/modern_drawer_setting_model.dart';

class HomeThemeModel {
  /// 新版首頁預設主題
  static const HomeThemeModel modernDefault = HomeThemeModel(
    backgroundColorValue: 0xFFFFFBF7,
    cardColorValue: 0xFFFFFFFF,
    cardBorderColorValue: 0xFFFFD9B3,
    primaryColorValue: 0xFFFF8A00,
    textColorValue: 0xFF3A2A20,
  );

  /// 舊版首頁預設主題
  static const HomeThemeModel classicDefault = HomeThemeModel(
    backgroundColorValue: 0xFFFFFCF7,
    cardColorValue: 0xFFFFFFFF,
    cardBorderColorValue: 0xFFF0E0CC,
    primaryColorValue: 0xFFB86B18,
    textColorValue: 0xFF3A2A1A,
  );

  /// 將舊版首頁的字串設定轉換成共用主題物件
  ///
  /// 舊版目前儲存：
  /// theme：warmOrange、milkTea、rosePink、forestGreen
  /// background：warmWhite、cream、lightPink、lightGray
  factory HomeThemeModel.fromClassicSettings({dynamic rawData}) {
    final Map<String, dynamic> settings = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    final String theme = (settings['theme'] ?? 'warmOrange').toString();
    final String background = (settings['background'] ?? 'warmWhite')
        .toString();

    final int primaryColorValue = switch (theme) {
      'milkTea' => 0xFF9B7653,
      'rosePink' => 0xFFD77887,
      'forestGreen' => 0xFF4F7D61,
      _ => 0xFFC96E18,
    };

    final int backgroundColorValue = switch (background) {
      'cream' => 0xFFFFF5E8,
      'lightPink' => 0xFFFFF4F5,
      'lightGray' => 0xFFF5F5F5,
      _ => 0xFFFFFCF7,
    };

    return HomeThemeModel(
      backgroundColorValue: backgroundColorValue,
      cardColorValue: 0xFFFFFFFF,
      cardBorderColorValue: _withOpacityValue(primaryColorValue, 0.24),
      primaryColorValue: primaryColorValue,
      textColorValue: 0xFF3A2A1A,
    );
  }
  const HomeThemeModel({
    required this.backgroundColorValue,
    required this.cardColorValue,
    required this.cardBorderColorValue,
    required this.primaryColorValue,
    required this.textColorValue,
    this.drawerSetting = const ModernDrawerSettingModel(),
  });

  final int backgroundColorValue;
  final int cardColorValue;
  final int cardBorderColorValue;
  final int primaryColorValue;
  final int textColorValue;
  final ModernDrawerSettingModel drawerSetting;

  Color get backgroundColor => Color(backgroundColorValue);

  Color get cardColor => Color(cardColorValue);

  Color get cardBorderColor => Color(cardBorderColorValue);

  Color get primaryColor => Color(primaryColorValue);

  Color get textColor => Color(textColorValue);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'backgroundColor': backgroundColorValue,
      'cardColor': cardColorValue,
      'cardBorderColor': cardBorderColorValue,
      'primaryColor': primaryColorValue,
      'textColor': textColorValue,
      'drawerSetting': drawerSetting.toMap(),
    };
  }

  factory HomeThemeModel.fromMap(
    dynamic rawData, {
    required HomeThemeModel fallback,
  }) {
    if (rawData is! Map) {
      return fallback;
    }

    final map = Map<String, dynamic>.from(rawData);

    return HomeThemeModel(
      backgroundColorValue: _readColorValue(
        map['backgroundColor'],
        fallback.backgroundColorValue,
      ),
      cardColorValue: _readColorValue(
        map['cardColor'],
        fallback.cardColorValue,
      ),
      cardBorderColorValue: _readColorValue(
        map['cardBorderColor'],
        fallback.cardBorderColorValue,
      ),
      primaryColorValue: _readColorValue(
        map['primaryColor'],
        fallback.primaryColorValue,
      ),
      textColorValue: _readColorValue(
        map['textColor'],
        fallback.textColorValue,
      ),
      drawerSetting: ModernDrawerSettingModel.fromMap(
        map['drawerSetting'] is Map
            ? Map<String, dynamic>.from(map['drawerSetting'])
            : fallback.drawerSetting.toMap(),
      ),
    );
  }

  HomeThemeModel copyWith({
    int? backgroundColorValue,
    int? cardColorValue,
    int? cardBorderColorValue,
    int? primaryColorValue,
    int? textColorValue,
    ModernDrawerSettingModel? drawerSetting,
  }) {
    return HomeThemeModel(
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      cardBorderColorValue: cardBorderColorValue ?? this.cardBorderColorValue,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      drawerSetting: drawerSetting ?? this.drawerSetting,
    );
  }

  static int _readColorValue(dynamic value, int fallback) {
    return parseColorValue(value, fallback);
  }

  /// 相容 int、24-bit、hex 字串（含 #／0x、RRGGBB／AARRGGBB）。
  static int parseColorValue(dynamic value, int fallback) {
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return _normalizeColorInt(value);
    }
    if (value is num) {
      return _normalizeColorInt(value.toInt());
    }
    String text = value.toString().trim();
    if (text.isEmpty) {
      return fallback;
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    } else if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.length == 3) {
      text =
          '${text[0]}${text[0]}${text[1]}${text[1]}${text[2]}${text[2]}';
    }
    if (text.length == 6) {
      text = 'FF$text';
    }
    if (text.length != 8) {
      return int.tryParse(value.toString()) ?? fallback;
    }
    final int? parsed = int.tryParse(text, radix: 16);
    if (parsed == null) {
      return fallback;
    }
    return parsed;
  }

  static int _normalizeColorInt(int value) {
    if (value >= 0 && value <= 0xFFFFFF) {
      return 0xFF000000 | value;
    }
    return value;
  }

  static int _withOpacityValue(int colorValue, double opacity) {
    final int alpha = (opacity.clamp(0.0, 1.0) * 255).round();

    return (alpha << 24) | (colorValue & 0x00FFFFFF);
  }
}
