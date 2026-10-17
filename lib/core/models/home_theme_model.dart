// 檔案名稱：lib/core/models/home_theme_model.dart
// 功能說明：統一管理 Classic、Modern 首頁的背景、卡片、外框、主色與文字顏色
// 🎨 首頁共用主題 Model

import 'package:flutter/material.dart';
import 'package:petnest_saas/models/home/modern_drawer_setting_model.dart';

/// 顧客端整頁背景。只存圖庫引用與顯示參數，不另存圖片。
abstract final class ShopAppBackground {
  static const String modeColor = 'color';
  static const String modeImage = 'image';
  static const String fitCover = 'cover';
  static const String fitContain = 'contain';
  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';
  static const double defaultScrim = 0.28;

  static const List<({String label, double opacity})> scrims =
      <({String label, double opacity})>[
        (label: '無遮罩', opacity: 0),
        (label: '淡遮罩', opacity: 0.12),
        (label: '標準遮罩', opacity: defaultScrim),
        (label: '深遮罩', opacity: 0.48),
      ];
}

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
    this.secondaryTextColorValue,
    this.buttonBackgroundColorValue,
    this.buttonTextMode = 'auto',
    this.buttonTextColorValue,
    this.drawerSetting = const ModernDrawerSettingModel(),
    this.appBackgroundMode = ShopAppBackground.modeColor,
    this.appBackgroundAssetId = '',
    this.appBackgroundFit = ShopAppBackground.fitCover,
    this.appBackgroundAlign = ShopAppBackground.alignCenter,
    this.appBackgroundScrim = ShopAppBackground.defaultScrim,
  });

  static const Object _keep = Object();

  final int backgroundColorValue;
  final int cardColorValue;
  final int cardBorderColorValue;
  final int primaryColorValue;
  final int textColorValue;

  /// 未設定時由主要文字色推算，不寫回舊資料。
  final int? secondaryTextColorValue;

  /// 未設定時按鈕背景跟隨主題重點色。
  final int? buttonBackgroundColorValue;

  /// auto、light、dark、custom。
  final String buttonTextMode;
  final int? buttonTextColorValue;
  final ModernDrawerSettingModel drawerSetting;

  /// color 或 image。缺欄位時維持純色。
  final String appBackgroundMode;

  /// 平台圖庫素材 ID。切回純色時保留，不刪除引用。
  final String appBackgroundAssetId;
  final String appBackgroundFit;
  final String appBackgroundAlign;

  /// 0～0.72。預設為標準遮罩。
  final double appBackgroundScrim;

  bool get usesAppBackgroundImage =>
      appBackgroundMode == ShopAppBackground.modeImage &&
      appBackgroundAssetId.trim().isNotEmpty;

  Color get backgroundColor => Color(backgroundColorValue);

  Color get cardColor => Color(cardColorValue);

  Color get cardBorderColor => Color(cardBorderColorValue);

  Color get primaryColor => Color(primaryColorValue);

  Color get textColor => Color(textColorValue);

  Color get secondaryTextColor {
    final int? value = secondaryTextColorValue;
    if (value == null) {
      return textColor.withValues(alpha: 0.65);
    }
    return Color(value);
  }

  bool get buttonFollowsPrimary => buttonBackgroundColorValue == null;

  Color get buttonBackgroundColor {
    final int? value = buttonBackgroundColorValue;
    if (value == null) {
      return primaryColor;
    }
    return Color(value);
  }

  Color get buttonForegroundColor {
    switch (buttonTextMode) {
      case 'light':
        return const Color(0xFFFFFFFF);
      case 'dark':
        return const Color(0xFF3A2A20);
      case 'custom':
        return Color(buttonTextColorValue ?? 0xFFFFFFFF);
      default:
        return ThemeData.estimateBrightnessForColor(buttonBackgroundColor) ==
                Brightness.dark
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF3A2A20);
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'backgroundColor': backgroundColorValue,
      'cardColor': cardColorValue,
      'cardBorderColor': cardBorderColorValue,
      'primaryColor': primaryColorValue,
      'textColor': textColorValue,
      if (secondaryTextColorValue != null)
        'secondaryTextColor': secondaryTextColorValue,
      if (buttonBackgroundColorValue != null)
        'buttonBackgroundColor': buttonBackgroundColorValue,
      if (buttonTextMode != 'auto') 'buttonTextMode': buttonTextMode,
      if (buttonTextMode == 'custom' && buttonTextColorValue != null)
        'buttonTextColor': buttonTextColorValue,
      'drawerSetting': drawerSetting.toMap(),
      if (appBackgroundMode != ShopAppBackground.modeColor)
        'appBackgroundMode': appBackgroundMode,
      if (appBackgroundAssetId.trim().isNotEmpty)
        'appBackgroundAssetId': appBackgroundAssetId.trim(),
      if (appBackgroundFit != ShopAppBackground.fitCover)
        'appBackgroundFit': appBackgroundFit,
      if (appBackgroundAlign != ShopAppBackground.alignCenter)
        'appBackgroundAlign': appBackgroundAlign,
      if ((appBackgroundScrim - ShopAppBackground.defaultScrim).abs() > 0.001)
        'appBackgroundScrim': appBackgroundScrim,
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
      secondaryTextColorValue: map.containsKey('secondaryTextColor')
          ? _readColorValue(map['secondaryTextColor'], fallback.textColorValue)
          : null,
      buttonBackgroundColorValue: map.containsKey('buttonBackgroundColor')
          ? _readColorValue(
              map['buttonBackgroundColor'],
              fallback.primaryColorValue,
            )
          : null,
      buttonTextMode: _readButtonTextMode(map['buttonTextMode']),
      buttonTextColorValue: map.containsKey('buttonTextColor')
          ? _readColorValue(map['buttonTextColor'], 0xFFFFFFFF)
          : null,
      drawerSetting: ModernDrawerSettingModel.fromMap(
        map['drawerSetting'] is Map
            ? Map<String, dynamic>.from(map['drawerSetting'])
            : fallback.drawerSetting.toMap(),
      ),
      appBackgroundMode: _readAppBackgroundMode(map['appBackgroundMode']),
      appBackgroundAssetId: (map['appBackgroundAssetId'] ?? '')
          .toString()
          .trim(),
      appBackgroundFit: _readAppBackgroundFit(map['appBackgroundFit']),
      appBackgroundAlign: _readAppBackgroundAlign(map['appBackgroundAlign']),
      appBackgroundScrim: _readAppBackgroundScrim(map['appBackgroundScrim']),
    );
  }

  HomeThemeModel copyWith({
    int? backgroundColorValue,
    int? cardColorValue,
    int? cardBorderColorValue,
    int? primaryColorValue,
    int? textColorValue,
    Object? secondaryTextColorValue = _keep,
    Object? buttonBackgroundColorValue = _keep,
    String? buttonTextMode,
    Object? buttonTextColorValue = _keep,
    ModernDrawerSettingModel? drawerSetting,
    String? appBackgroundMode,
    String? appBackgroundAssetId,
    String? appBackgroundFit,
    String? appBackgroundAlign,
    double? appBackgroundScrim,
  }) {
    return HomeThemeModel(
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      cardColorValue: cardColorValue ?? this.cardColorValue,
      cardBorderColorValue: cardBorderColorValue ?? this.cardBorderColorValue,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      secondaryTextColorValue: identical(secondaryTextColorValue, _keep)
          ? this.secondaryTextColorValue
          : secondaryTextColorValue as int?,
      buttonBackgroundColorValue: identical(buttonBackgroundColorValue, _keep)
          ? this.buttonBackgroundColorValue
          : buttonBackgroundColorValue as int?,
      buttonTextMode: buttonTextMode ?? this.buttonTextMode,
      buttonTextColorValue: identical(buttonTextColorValue, _keep)
          ? this.buttonTextColorValue
          : buttonTextColorValue as int?,
      drawerSetting: drawerSetting ?? this.drawerSetting,
      appBackgroundMode: _readAppBackgroundMode(
        appBackgroundMode ?? this.appBackgroundMode,
      ),
      appBackgroundAssetId: (appBackgroundAssetId ?? this.appBackgroundAssetId)
          .trim(),
      appBackgroundFit: _readAppBackgroundFit(
        appBackgroundFit ?? this.appBackgroundFit,
      ),
      appBackgroundAlign: _readAppBackgroundAlign(
        appBackgroundAlign ?? this.appBackgroundAlign,
      ),
      appBackgroundScrim: _readAppBackgroundScrim(
        appBackgroundScrim ?? this.appBackgroundScrim,
      ),
    );
  }

  /// 套用另一份色彩時，保留目前的整頁背景圖片設定。
  HomeThemeModel withBackdropFrom(HomeThemeModel source) {
    return copyWith(
      appBackgroundMode: source.appBackgroundMode,
      appBackgroundAssetId: source.appBackgroundAssetId,
      appBackgroundFit: source.appBackgroundFit,
      appBackgroundAlign: source.appBackgroundAlign,
      appBackgroundScrim: source.appBackgroundScrim,
    );
  }

  static String _readAppBackgroundMode(dynamic value) {
    return value?.toString() == ShopAppBackground.modeImage
        ? ShopAppBackground.modeImage
        : ShopAppBackground.modeColor;
  }

  static String _readAppBackgroundFit(dynamic value) {
    return value?.toString() == ShopAppBackground.fitContain
        ? ShopAppBackground.fitContain
        : ShopAppBackground.fitCover;
  }

  static String _readAppBackgroundAlign(dynamic value) {
    switch (value?.toString()) {
      case ShopAppBackground.alignTop:
        return ShopAppBackground.alignTop;
      case ShopAppBackground.alignBottom:
        return ShopAppBackground.alignBottom;
      default:
        return ShopAppBackground.alignCenter;
    }
  }

  static double _readAppBackgroundScrim(dynamic value) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ??
              ShopAppBackground.defaultScrim;
    if (parsed < 0) {
      return 0;
    }
    if (parsed > 0.72) {
      return 0.72;
    }
    return parsed;
  }

  static String _readButtonTextMode(dynamic value) {
    final String mode = (value ?? 'auto').toString();
    switch (mode) {
      case 'light':
      case 'dark':
      case 'custom':
      case 'auto':
        return mode;
      default:
        return 'auto';
    }
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
      text = '${text[0]}${text[0]}${text[1]}${text[1]}${text[2]}${text[2]}';
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
