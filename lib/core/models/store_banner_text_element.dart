// lib/core/models/store_banner_text_element.dart
// 🛒 商城海報自由文字元件。位置用 0~1，不存 pixel。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_banner_placement.dart';

class StoreBannerFontSizes {
  static const String small = 'small';
  static const String body = 'body';
  static const String subhead = 'subhead';
  static const String title = 'title';
  static const String display = 'display';
  static const List<String> all = <String>[
    small,
    body,
    subhead,
    title,
    display,
  ];

  static const double minPx = 12;
  static const double maxPx = 64;
  static const int sliderDivisions = 52;

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case body:
        return '內文';
      case subhead:
        return '小標題';
      case display:
        return '大標題';
      default:
        return '標題';
    }
  }

  /// 舊 preset 對應的基準 px（高度 190 時的實際字級）。
  static double basePx(String value) {
    switch (value) {
      case small:
        return 13;
      case body:
        return 15;
      case subhead:
        return 20;
      case display:
        return 38;
      default:
        return 28;
    }
  }

  static String nearestPreset(double px) {
    const List<String> presets = all;
    String best = title;
    double bestDelta = double.infinity;
    for (final String preset in presets) {
      final double delta = (basePx(preset) - px).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = preset;
      }
    }
    return best;
  }

  static double clampPx(double value) {
    return value.clamp(minPx, maxPx);
  }

  static double fontSize(String value, double bannerHeight) {
    final double scale = (bannerHeight / 190).clamp(0.82, 1.35);
    return (basePx(value) * scale).clamp(11.0, 48.0);
  }

  static int maxLines(String value) {
    switch (value) {
      case display:
      case title:
      case subhead:
        return 2;
      default:
        return 3;
    }
  }
}

class StoreBannerFontWeights {
  static const String regular = 'regular';
  static const String medium = 'medium';
  static const String bold = 'bold';
  static const String extraBold = 'extraBold';
  static const List<String> all = <String>[regular, medium, bold, extraBold];

  static String label(String value) {
    switch (value) {
      case regular:
        return '一般';
      case medium:
        return '中粗';
      case extraBold:
        return '特粗';
      default:
        return '粗體';
    }
  }

  static FontWeight weight(String value) {
    switch (value) {
      case regular:
        return FontWeight.w400;
      case medium:
        return FontWeight.w600;
      case extraBold:
        return FontWeight.w900;
      default:
        return FontWeight.w700;
    }
  }
}

class StoreBannerTextWidthPresets {
  static const String narrow = 'narrow';
  static const String standard = 'standard';
  static const String wide = 'wide';
  static const List<String> all = <String>[narrow, standard, wide];

  static String label(String value) {
    switch (value) {
      case narrow:
        return '窄';
      case wide:
        return '寬';
      default:
        return '標準';
    }
  }

  static double ratio(String value) {
    switch (value) {
      case narrow:
        return 0.38;
      case wide:
        return 0.62;
      default:
        return 0.48;
    }
  }
}

class StoreBannerTextBgStyles {
  static const String none = 'none';
  static const String capsule = 'capsule';
  static const String rounded = 'rounded';
  static const String square = 'square';
  static const String translucent = 'translucent';
  static const List<String> all = <String>[
    none,
    capsule,
    rounded,
    square,
    translucent,
  ];

  static String label(String value) {
    switch (value) {
      case capsule:
        return '膠囊';
      case rounded:
        return '圓角標籤';
      case square:
        return '方形底';
      case translucent:
        return '半透明底';
      default:
        return '無背景';
    }
  }

  static double radius(String value) {
    switch (value) {
      case capsule:
        return 999;
      case rounded:
        return 10;
      case square:
        return 2;
      case translucent:
        return 12;
      default:
        return 0;
    }
  }
}

class StoreBannerTextPaddings {
  static const String tight = 'tight';
  static const String standard = 'standard';
  static const String roomy = 'roomy';
  static const List<String> all = <String>[tight, standard, roomy];

  static String label(String value) {
    switch (value) {
      case tight:
        return '緊';
      case roomy:
        return '寬鬆';
      default:
        return '標準';
    }
  }

  static EdgeInsets insets(String value) {
    switch (value) {
      case tight:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case roomy:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
      default:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    }
  }
}

class StoreBannerBgOpacities {
  static const String full = 'full';
  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';
  static const List<String> all = <String>[full, high, medium, low];

  static String label(String value) {
    switch (value) {
      case high:
        return '80%';
      case medium:
        return '60%';
      case low:
        return '40%';
      default:
        return '100%';
    }
  }

  static double opacity(String value) {
    switch (value) {
      case high:
        return 0.80;
      case medium:
        return 0.60;
      case low:
        return 0.40;
      default:
        return 1;
    }
  }

  static String fromOpacity(double value) {
    if (value <= 0.50) {
      return low;
    }
    if (value <= 0.70) {
      return medium;
    }
    if (value <= 0.90) {
      return high;
    }
    return full;
  }
}

class StoreBannerCommonColors {
  static const int black = 0xFF111111;
  static const int white = 0xFFFFFFFF;
  static const int darkBrown = 0xFF3A2A20;
  static const int warmBrown = 0xFF8B5A2B;
  static const int orange = 0xFFFF8A00;
  static const int red = 0xFFE53935;
  static const int pink = 0xFFE91E8C;
  static const int green = 0xFF2E7D4F;
  static const int blue = 0xFF1E6BB8;

  static const List<({String id, String label, int argb})> swatches =
      <({String id, String label, int argb})>[
        (id: 'black', label: '黑', argb: black),
        (id: 'white', label: '白', argb: white),
        (id: 'darkBrown', label: '深棕', argb: darkBrown),
        (id: 'warmBrown', label: '暖棕', argb: warmBrown),
        (id: 'orange', label: '橘', argb: orange),
        (id: 'red', label: '紅', argb: red),
        (id: 'pink', label: '粉', argb: pink),
        (id: 'green', label: '綠', argb: green),
        (id: 'blue', label: '藍', argb: blue),
      ];
}

class StoreBannerColorCodec {
  static int parse(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final String text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return fallback;
    }
    String hex = text.startsWith('#') ? text.substring(1) : text;
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return int.tryParse(hex, radix: 16) ?? fallback;
  }

  static String hexOf(int argb) {
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color colorOf(int argb) => Color(argb);
}

class StoreBannerTextElement {
  const StoreBannerTextElement({
    required this.id,
    this.text = '',
    this.positionX = 0.08,
    this.positionY = 0.22,
    this.fontSizePreset = StoreBannerFontSizes.title,
    this.fontSize,
    this.fontWeightPreset = StoreBannerFontWeights.bold,
    this.textColor = StoreBannerCommonColors.darkBrown,
    this.textAlign = 'left',
    this.backgroundEnabled = false,
    this.backgroundColor = StoreBannerCommonColors.orange,
    this.backgroundOpacityPreset = StoreBannerBgOpacities.full,
    this.backgroundStyle = StoreBannerTextBgStyles.none,
    this.paddingPreset = StoreBannerTextPaddings.standard,
    this.maxWidthPreset = StoreBannerTextWidthPresets.standard,
    this.sortOrder = 0,
  });

  final String id;
  final String text;
  final double positionX;
  final double positionY;
  final String fontSizePreset;
  final double? fontSize;
  final String fontWeightPreset;
  final int textColor;
  final String textAlign;
  final bool backgroundEnabled;
  final int backgroundColor;
  final String backgroundOpacityPreset;
  final String backgroundStyle;
  final String paddingPreset;
  final String maxWidthPreset;
  final int sortOrder;

  bool get hasText => text.trim().isNotEmpty;

  /// 有保存 fontSize 時用數值；舊海報只剩 preset 時維持原本依高度縮放。
  double resolvedFontSize(double bannerHeight) {
    if (fontSize != null) {
      return StoreBannerFontSizes.clampPx(fontSize!);
    }
    return StoreBannerFontSizes.fontSize(fontSizePreset, bannerHeight);
  }

  /// 編輯器 Slider 顯示值：新資料用保存的 px，舊資料用 preset 基準 px。
  double get sliderFontSize {
    return StoreBannerFontSizes.clampPx(
      fontSize ?? StoreBannerFontSizes.basePx(fontSizePreset),
    );
  }

  int get maxLines {
    if (fontSize != null) {
      return fontSize! >= 20 ? 2 : 3;
    }
    return StoreBannerFontSizes.maxLines(fontSizePreset);
  }

  bool get showsBackground =>
      backgroundEnabled && backgroundStyle != StoreBannerTextBgStyles.none;

  factory StoreBannerTextElement.fromMap(Map<String, dynamic> data) {
    String pick(List<String> allowed, dynamic raw, String fallback) {
      final String value = (raw ?? fallback).toString();
      return allowed.contains(value) ? value : fallback;
    }

    final bool enabled = data['backgroundEnabled'] == true;
    String style = pick(
      StoreBannerTextBgStyles.all,
      data['backgroundStyle'],
      enabled ? StoreBannerTextBgStyles.rounded : StoreBannerTextBgStyles.none,
    );
    if (enabled && style == StoreBannerTextBgStyles.none) {
      style = StoreBannerTextBgStyles.rounded;
    }

    final Offset? preset = StoreBannerPlacement.fromLegacyPreset(
      data['positionPreset'] ?? data['alignment'],
    );
    final double fallbackX = preset?.dx ?? 0.08;
    final double fallbackY = preset?.dy ?? 0.22;

    return StoreBannerTextElement(
      id: (data['id'] ?? '').toString().trim(),
      text: (data['text'] ?? '').toString(),
      positionX: data.containsKey('positionX')
          ? _ratioOf(data['positionX'], fallbackX)
          : fallbackX,
      positionY: data.containsKey('positionY')
          ? _ratioOf(data['positionY'], fallbackY)
          : fallbackY,
      fontSizePreset: pick(
        StoreBannerFontSizes.all,
        data['fontSizePreset'],
        StoreBannerFontSizes.title,
      ),
      fontSize: _fontSizeOf(data['fontSize']),
      fontWeightPreset: pick(
        StoreBannerFontWeights.all,
        data['fontWeightPreset'],
        StoreBannerFontWeights.bold,
      ),
      textColor: StoreBannerColorCodec.parse(
        data['textColor'],
        StoreBannerCommonColors.darkBrown,
      ),
      textAlign: pick(
        const <String>['left', 'center', 'right'],
        data['textAlign'],
        'left',
      ),
      backgroundEnabled: enabled,
      backgroundColor: StoreBannerColorCodec.parse(
        data['backgroundColor'],
        StoreBannerCommonColors.orange,
      ),
      backgroundOpacityPreset: pick(
        StoreBannerBgOpacities.all,
        data['backgroundOpacityPreset'],
        StoreBannerBgOpacities.fromOpacity(
          data['backgroundOpacity'] is num
              ? (data['backgroundOpacity'] as num).toDouble()
              : 1,
        ),
      ),
      backgroundStyle: style,
      paddingPreset: pick(
        StoreBannerTextPaddings.all,
        data['paddingPreset'],
        StoreBannerTextPaddings.standard,
      ),
      maxWidthPreset: pick(
        StoreBannerTextWidthPresets.all,
        data['maxWidthPreset'],
        StoreBannerTextWidthPresets.standard,
      ),
      sortOrder: data['sortOrder'] is int
          ? data['sortOrder'] as int
          : int.tryParse(data['sortOrder']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'text': text.trim(),
      'positionX': positionX.clamp(0.0, 1.0),
      'positionY': positionY.clamp(0.0, 1.0),
      'fontSizePreset': fontSizePreset,
      if (fontSize != null) 'fontSize': StoreBannerFontSizes.clampPx(fontSize!),
      'fontWeightPreset': fontWeightPreset,
      'textColor': textColor,
      'textAlign': textAlign,
      'backgroundEnabled': backgroundEnabled,
      'backgroundColor': backgroundColor,
      'backgroundOpacity': StoreBannerBgOpacities.opacity(
        backgroundOpacityPreset,
      ),
      'backgroundOpacityPreset': backgroundOpacityPreset,
      'backgroundStyle': backgroundStyle,
      'paddingPreset': paddingPreset,
      'maxWidthPreset': maxWidthPreset,
      'sortOrder': sortOrder,
    };
  }

  StoreBannerTextElement copyWith({
    String? text,
    double? positionX,
    double? positionY,
    String? fontSizePreset,
    double? fontSize,
    String? fontWeightPreset,
    int? textColor,
    String? textAlign,
    bool? backgroundEnabled,
    int? backgroundColor,
    String? backgroundOpacityPreset,
    String? backgroundStyle,
    String? paddingPreset,
    String? maxWidthPreset,
    int? sortOrder,
  }) {
    return StoreBannerTextElement(
      id: id,
      text: text ?? this.text,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      fontSizePreset: fontSizePreset ?? this.fontSizePreset,
      fontSize: fontSize ?? this.fontSize,
      fontWeightPreset: fontWeightPreset ?? this.fontWeightPreset,
      textColor: textColor ?? this.textColor,
      textAlign: textAlign ?? this.textAlign,
      backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacityPreset:
          backgroundOpacityPreset ?? this.backgroundOpacityPreset,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      paddingPreset: paddingPreset ?? this.paddingPreset,
      maxWidthPreset: maxWidthPreset ?? this.maxWidthPreset,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static double _ratioOf(dynamic value, double fallback) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? fallback;
    return parsed.clamp(0.0, 1.0);
  }

  static double? _fontSizeOf(dynamic raw) {
    if (raw is num) {
      return StoreBannerFontSizes.clampPx(raw.toDouble());
    }
    final double? parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed == null) {
      return null;
    }
    return StoreBannerFontSizes.clampPx(parsed);
  }

  static StoreBannerTextElement create({
    required String id,
    required String text,
    required double positionX,
    required double positionY,
    String fontSizePreset = StoreBannerFontSizes.title,
    double? fontSize,
    String fontWeightPreset = StoreBannerFontWeights.bold,
    int textColor = StoreBannerCommonColors.darkBrown,
    String textAlign = 'left',
    bool backgroundEnabled = false,
    int backgroundColor = StoreBannerCommonColors.orange,
    String backgroundOpacityPreset = StoreBannerBgOpacities.full,
    String backgroundStyle = StoreBannerTextBgStyles.none,
    String maxWidthPreset = StoreBannerTextWidthPresets.standard,
    int sortOrder = 0,
  }) {
    return StoreBannerTextElement(
      id: id,
      text: text,
      positionX: positionX,
      positionY: positionY,
      fontSizePreset: fontSizePreset,
      fontSize: fontSize,
      fontWeightPreset: fontWeightPreset,
      textColor: textColor,
      textAlign: textAlign,
      backgroundEnabled: backgroundEnabled,
      backgroundColor: backgroundColor,
      backgroundOpacityPreset: backgroundOpacityPreset,
      backgroundStyle: backgroundStyle,
      maxWidthPreset: maxWidthPreset,
      sortOrder: sortOrder,
    );
  }
}
