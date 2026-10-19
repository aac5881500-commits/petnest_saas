import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

/// 首頁店家識別與側邊欄精簡店名是兩種顯示情境，不可共用位置或 GlobalKey。
enum StoreBrandDisplayContext { home, drawer }

/// 副標字數規則。只清理顯示與外觀草稿，不改店家基本資料裡的店名。
class StoreBrandTextPolicy {
  const StoreBrandTextPolicy._();

  static const int subtitleMaxCharacters = 24;

  static String sanitizeSubtitle(String value) {
    final String trimmed = value.trim();
    return trimmed.characters.take(subtitleMaxCharacters).toString();
  }
}

/// 店家識別區的排版。座標是首頁內容區內的 0～1，不是螢幕像素。
class StoreBrandStyle {
  const StoreBrandStyle({
    this.x = 0.5,
    this.y = 0,
    this.widthRatio = defaultWidthRatio,
    this.nameColorValue,
    this.subtitleColorValue,
    this.headerBackgroundColorValue,
    this.textShadowEnabled = false,
    this.textAlign = 'center',
    this.nameFontSize = 18,
    this.subtitleFontSize = 12,
    this.markType = 'builtinIcon',
    this.logoPlacement = 'leading',
    this.logoSize = 'medium',
    this.fallbackIcon = 'paw',
    this.nameFontFamily = defaultNameFontFamily,
  });

  static const double defaultWidthRatio = 0.72;
  static const double minWidthRatio = 0.3;
  static const double maxWidthRatio = 1;
  static const double minNameFont = 14;
  static const double maxNameFont = 20;
  static const double minSubtitleFont = 10;
  static const double maxSubtitleFont = 18;
  static const double logoGap = 10;

  /// 空字串代表原本字體。只接受目前已安裝的五款。
  static const String defaultNameFontFamily = '';
  static const List<String> nameFontFamilies = <String>[
    'jfOpenHuninn',
    'NotoSansTC',
    'NotoSerifTC',
    'KleeOne',
    'ChironSungHK',
  ];
  static const Object _keep = Object();

  final double x;
  final double y;
  final double widthRatio;
  final int? nameColorValue;
  final int? subtitleColorValue;

  /// 頂部整條背景。null 代表沿用首頁背景，不用透明零值代表沿用。
  final int? headerBackgroundColorValue;
  final bool textShadowEnabled;
  final String textAlign;
  final double nameFontSize;
  final double subtitleFontSize;

  /// logo、builtinIcon、none。與左右位置分開。
  final String markType;
  final String logoPlacement;
  final String logoSize;
  final String fallbackIcon;

  /// 店名字體。空字串沿用原本字體。
  final String nameFontFamily;

  /// 可套用的店名字體。未知代號回傳 null，畫面沿用原本字體。
  String? get appliedNameFontFamily {
    if (nameFontFamilies.contains(nameFontFamily)) {
      return nameFontFamily;
    }
    return null;
  }

  bool get showsMark => markType == 'logo' || markType == 'builtinIcon';

  double get logoExtent {
    switch (logoSize) {
      case 'small':
        return 24;
      case 'large':
        return 40;
      default:
        return 32;
    }
  }

  TextAlign get flutterTextAlign {
    switch (textAlign) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }

  CrossAxisAlignment get columnAlign {
    switch (textAlign) {
      case 'left':
        return CrossAxisAlignment.start;
      case 'right':
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.center;
    }
  }

  Color nameColor(Color themeText) {
    final int? value = nameColorValue;
    if (value == null) {
      return themeText;
    }
    return Color(value);
  }

  Color subtitleColor(Color themeText) {
    final int? value = subtitleColorValue;
    if (value == null) {
      return themeText.withValues(alpha: 0.68);
    }
    return Color(value);
  }

  /// 未設定時回傳頁面背景，讓正式前台與編輯預覽走同一條規則。
  Color resolveHeaderBackground(Color pageBackground) {
    final int? value = headerBackgroundColorValue;
    if (value == null) {
      return pageBackground;
    }
    return Color(value);
  }

  List<Shadow>? get textShadows {
    if (!textShadowEnabled) {
      return null;
    }
    return const <Shadow>[
      Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1)),
    ];
  }

  StoreBrandStyle copyWith({
    double? x,
    double? y,
    double? widthRatio,
    Object? nameColorValue = _keep,
    Object? subtitleColorValue = _keep,
    Object? headerBackgroundColorValue = _keep,
    bool? textShadowEnabled,
    String? textAlign,
    double? nameFontSize,
    double? subtitleFontSize,
    String? markType,
    String? logoPlacement,
    String? logoSize,
    String? fallbackIcon,
    String? nameFontFamily,
  }) {
    return StoreBrandStyle(
      x: (x ?? this.x).clamp(0, 1).toDouble(),
      y: y ?? this.y,
      widthRatio: widthRatio ?? this.widthRatio,
      nameColorValue: identical(nameColorValue, _keep)
          ? this.nameColorValue
          : nameColorValue as int?,
      subtitleColorValue: identical(subtitleColorValue, _keep)
          ? this.subtitleColorValue
          : subtitleColorValue as int?,
      headerBackgroundColorValue: identical(headerBackgroundColorValue, _keep)
          ? this.headerBackgroundColorValue
          : headerBackgroundColorValue as int?,
      textShadowEnabled: textShadowEnabled ?? this.textShadowEnabled,
      textAlign: textAlign ?? this.textAlign,
      nameFontSize: _font(
        nameFontSize ?? this.nameFontSize,
        18,
        minNameFont,
        maxNameFont,
      ),
      subtitleFontSize: _font(
        subtitleFontSize ?? this.subtitleFontSize,
        12,
        minSubtitleFont,
        maxSubtitleFont,
      ),
      markType: markType ?? this.markType,
      logoPlacement: logoPlacement ?? this.logoPlacement,
      logoSize: logoSize ?? this.logoSize,
      fallbackIcon: fallbackIcon ?? this.fallbackIcon,
      nameFontFamily: _nameFontFamily(nameFontFamily ?? this.nameFontFamily),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'homepageBrandX': x,
      'homepageBrandY': y,
      'homepageBrandWidthRatio': widthRatio,
      if (nameColorValue != null) 'homepageBrandNameColor': nameColorValue,
      if (subtitleColorValue != null)
        'homepageBrandSubtitleColor': subtitleColorValue,
      'homepageHeaderBackgroundColor': headerBackgroundColorValue,
      'homepageBrandTextShadowEnabled': textShadowEnabled,
      'homepageBrandTextAlign': textAlign,
      'homepageBrandNameFontSize': _font(
        nameFontSize,
        18,
        minNameFont,
        maxNameFont,
      ),
      'homepageBrandSubtitleFontSize': _font(
        subtitleFontSize,
        12,
        minSubtitleFont,
        maxSubtitleFont,
      ),
      'homepageBrandMarkType': markType,
      'homepageBrandLogoPlacement': logoPlacement,
      'homepageBrandLogoSize': logoSize,
      'showLeftHeaderIcon': showsMark && logoPlacement == 'leading',
      'showRightHeaderIcon': showsMark && logoPlacement == 'trailing',
      'leftHeaderIcon': fallbackIcon,
      'rightHeaderIcon': fallbackIcon,
      'homepageBrandNameFontFamily': nameFontFamily,
    };
  }

  static StoreBrandStyle fromMap(dynamic raw, {String logoUrl = ''}) {
    final Map<String, dynamic> map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return StoreBrandStyle(
      x: _unit(map['homepageBrandX'], 0.5),
      y: _unit(map['homepageBrandY'], 0),
      widthRatio: _width(map['homepageBrandWidthRatio']),
      nameColorValue: map.containsKey('homepageBrandNameColor')
          ? HomeThemeModel.parseColorValue(map['homepageBrandNameColor'], 0)
          : null,
      subtitleColorValue: map.containsKey('homepageBrandSubtitleColor')
          ? HomeThemeModel.parseColorValue(map['homepageBrandSubtitleColor'], 0)
          : null,
      headerBackgroundColorValue: _storedHeaderColor(map),
      textShadowEnabled: map['homepageBrandTextShadowEnabled'] == true,
      textAlign: _align(map['homepageBrandTextAlign']),
      nameFontSize: _font(
        map['homepageBrandNameFontSize'],
        18,
        minNameFont,
        maxNameFont,
      ),
      subtitleFontSize: _font(
        map['homepageBrandSubtitleFontSize'],
        12,
        minSubtitleFont,
        maxSubtitleFont,
      ),
      markType: _markType(map, logoUrl),
      logoPlacement: _placement(map),
      logoSize: _logoSize(map['homepageBrandLogoSize']),
      fallbackIcon: _icon(map),
      nameFontFamily: _nameFontFamily(map['homepageBrandNameFontFamily']),
    );
  }

  static StoreBrandStyle resetPlacement(StoreBrandStyle style) {
    return style.copyWith(x: 0.5);
  }

  static bool isPresetX(double x) {
    return (x - 0).abs() < 0.015 ||
        (x - 0.5).abs() < 0.015 ||
        (x - 1).abs() < 0.015;
  }

  static int? _storedHeaderColor(Map<String, dynamic> map) {
    const String key = 'homepageHeaderBackgroundColor';
    final dynamic raw = map[key];
    if (!map.containsKey(key) || raw == null || raw == 0) {
      return null;
    }
    final int parsed = HomeThemeModel.parseColorValue(raw, 0);
    if ((parsed & 0xFF000000) == 0) {
      return null;
    }
    return parsed;
  }

  static double _unit(dynamic value, double fallback) {
    if (value is! num) {
      return fallback;
    }
    return value.toDouble().clamp(0, 1).toDouble();
  }

  static double _width(dynamic value) {
    if (value is! num) {
      return defaultWidthRatio;
    }
    return value.toDouble().clamp(minWidthRatio, maxWidthRatio).toDouble();
  }

  static double _font(dynamic value, double fallback, double min, double max) {
    if (value is! num) {
      return fallback;
    }
    return value.toDouble().clamp(min, max).toDouble();
  }

  static String _align(dynamic value) {
    switch (value) {
      case 'left':
      case 'right':
      case 'center':
        return value as String;
      default:
        return 'center';
    }
  }

  static String _logoSize(dynamic value) {
    switch (value) {
      case 'small':
      case 'large':
        return value as String;
      default:
        return 'medium';
    }
  }

  static String _markType(Map<String, dynamic> map, String logoUrl) {
    final String raw = (map['homepageBrandMarkType'] ?? '').toString();
    if (raw == 'logo' || raw == 'builtinIcon' || raw == 'none') {
      return raw;
    }
    final String placement = (map['homepageBrandLogoPlacement'] ?? '')
        .toString();
    if (placement == 'none') {
      return 'none';
    }
    if (placement.isEmpty &&
        map['showLeftHeaderIcon'] == false &&
        map['showRightHeaderIcon'] == false) {
      return 'none';
    }
    if (logoUrl.trim().isNotEmpty) {
      return 'logo';
    }
    return 'builtinIcon';
  }

  static String _placement(Map<String, dynamic> map) {
    final String raw = (map['homepageBrandLogoPlacement'] ?? '').toString();
    if (raw == 'trailing') {
      return 'trailing';
    }
    if (raw == 'leading') {
      return 'leading';
    }
    if (map['showRightHeaderIcon'] == true &&
        map['showLeftHeaderIcon'] == false) {
      return 'trailing';
    }
    return 'leading';
  }

  static String _nameFontFamily(dynamic value) {
    final String raw = (value ?? '').toString().trim();
    if (nameFontFamilies.contains(raw)) {
      return raw;
    }
    return defaultNameFontFamily;
  }

  static String _icon(Map<String, dynamic> map) {
    final String placement = _placement(map);
    final String preferred = placement == 'trailing'
        ? (map['rightHeaderIcon'] ?? map['leftHeaderIcon'] ?? 'paw').toString()
        : (map['leftHeaderIcon'] ?? map['rightHeaderIcon'] ?? 'paw').toString();
    switch (preferred) {
      case 'heart':
      case 'star':
      case 'home':
      case 'crown':
      case 'paw':
        return preferred;
      default:
        return 'paw';
    }
  }

  static IconData iconData(String value) {
    switch (value) {
      case 'heart':
        return Icons.favorite_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'paw':
      default:
        return Icons.pets_rounded;
    }
  }
}

/// 頂部識別列內的水平位置。0 靠左、0.5 置中、1 靠右，並扣除內容寬度。
class StoreBrandGeometry {
  static double leftFor({
    required double laneWidth,
    required double contentWidth,
    required double x,
  }) {
    final double travel = math.max(0, laneWidth - contentWidth);
    return travel * x.clamp(0, 1);
  }

  static double normalizeX({
    required double left,
    required double laneWidth,
    required double contentWidth,
  }) {
    final double travel = laneWidth - contentWidth;
    if (travel <= 0.5) {
      return 0.5;
    }
    return (left / travel).clamp(0.0, 1.0);
  }
}
