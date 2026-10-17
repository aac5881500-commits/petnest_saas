// 檔案名稱：lib/core/models/store_banner_text_element.dart
// 功能說明：商城海報自由文字元件。位置用 0~1，不存 pixel。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const double minPx = 18;
  static const double maxPx = 220;

  /// 1600×900 完成海報上的字級。預覽用 fontSize × 畫布高度 / 900。
  static const double designHeight = 900;
  static const double designTitle = 104;
  static const double designSubtitle = 46;
  static const double designBody = 52;
  static const double designCta = 28;

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
      final double delta = (designPx(preset) - px).abs();
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

  /// 100px 以下每 2px，超過 100px 每 4px。
  static double snapPosterPx(double value) {
    final double clamped = clampPx(value);
    if (clamped <= 100) {
      return (clamped / 2).roundToDouble() * 2;
    }
    return (clamped / 4).roundToDouble() * 4;
  }

  static double designPx(String value) {
    switch (value) {
      case small:
        return 28;
      case body:
        return designSubtitle;
      case subhead:
        return designBody;
      case display:
        return 140;
      default:
        return designTitle;
    }
  }

  /// 把 1600×900 的字級換到目前畫布，比例與完成圖一致。
  static double scaleDesign(double designPx, double bannerHeight) {
    if (bannerHeight <= 0) {
      return designPx;
    }
    return designPx * bannerHeight / designHeight;
  }

  /// 編輯器預覽最大寬 420、16:9 時的高度。內距、圓角、陰影依這個高度等比換算。
  static const double editorReferenceWidth = 420;
  static const double editorReferenceHeight = editorReferenceWidth * 9 / 16;

  /// 編輯器上調過的像素換到目前畫布。420 寬預覽維持原值，1600×900 用同一比例放大。
  static double scaleEditorPx(double editorPx, double bannerHeight) {
    if (bannerHeight <= 0 || !bannerHeight.isFinite) {
      return editorPx;
    }
    return editorPx * bannerHeight / editorReferenceHeight;
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
    this.fontFamily = '',
    this.letterSpacing = 0,
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

  /// 空字串代表沿用系統預設字體。只接受已安裝的字型代號。
  final String fontFamily;

  /// 1600×900 畫布上的字距。預覽依畫布高度等比縮小。
  final double letterSpacing;
  final int sortOrder;

  String? get appliedFontFamily => StoreBannerFonts.applied(fontFamily);

  bool get hasText => text.trim().isNotEmpty;

  /// 完成海報 px。舊資料沒有 fontSize 時，才用 preset 換算。
  double get posterFontPx {
    return StoreBannerFontSizes.clampPx(
      fontSize ?? StoreBannerFontSizes.designPx(fontSizePreset),
    );
  }

  /// 預覽字級 = 完成海報 px × 畫布高度 / 900。輸出 900 高時等於原始 px。
  double previewFontSize(double bannerHeight) {
    return StoreBannerFontSizes.scaleDesign(posterFontPx, bannerHeight);
  }

  /// 編輯器顯示的是完成海報 px，不是預覽畫面的顯示 px。
  double get sliderFontSize => posterFontPx;

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
      fontFamily: StoreBannerFonts.normalize(data['fontFamily']),
      letterSpacing: _letterSpacingOf(data['letterSpacing']),
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
      'fontFamily': fontFamily,
      if (letterSpacing != 0) 'letterSpacing': letterSpacing,
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
    String? fontFamily,
    double? letterSpacing,
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
      fontFamily: fontFamily ?? this.fontFamily,
      letterSpacing: letterSpacing ?? this.letterSpacing,
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

  static double _letterSpacingOf(dynamic raw) {
    final double parsed = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    if (!parsed.isFinite) {
      return 0;
    }
    return parsed.clamp(-8.0, 24.0);
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
    String fontFamily = '',
    double letterSpacing = 0,
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
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      sortOrder: sortOrder,
    );
  }
}

class StoreBannerFonts {
  static const String sans = 'NotoSansTC';
  static const String serif = 'NotoSerifTC';
  static const String rounded = 'jfOpenHuninn';
  static const String handwritten = 'KleeOne';
  static const String modernSerif = 'ChironSungHK';

  static const List<({String family, String label})> options =
      <({String family, String label})>[
        (family: '', label: '系統預設'),
        (family: sans, label: '思源黑體'),
        (family: serif, label: '思源宋體'),
        (family: rounded, label: '粉圓・圓體'),
        (family: handwritten, label: 'Klee One・手寫'),
        (family: modernSerif, label: '昭源宋體・現代簡約'),
      ];

  static const Map<String, List<String>> _assets = <String, List<String>>{
    rounded: <String>['assets/fonts/jf-openhuninn-2.1.ttf'],
    sans: <String>['assets/fonts/NotoSansTC-VariableFont_wght.ttf'],
    serif: <String>['assets/fonts/NotoSerifTC-VariableFont_wght.ttf'],
    handwritten: <String>[
      'assets/fonts/KleeOne-Regular.ttf',
      'assets/fonts/KleeOne-SemiBold.ttf',
    ],
    modernSerif: <String>['assets/fonts/ChironSungHKVF.ttf'],
  };

  static List<String> get families => _assets.keys.toList();

  static final Map<String, Future<void>> _pending = <String, Future<void>>{};

  static String normalize(dynamic raw) {
    final String value = (raw ?? '').toString().trim();
    if (_assets.containsKey(value)) {
      return value;
    }
    return '';
  }

  static String? applied(String family) {
    if (_assets.containsKey(family)) {
      return family;
    }
    return null;
  }

  /// 等到字型進入引擎後才返回。已載入的字型不會重複讀檔。
  static Future<void> ensureLoaded(Iterable<String> families) {
    final List<Future<void>> jobs = <Future<void>>[];
    for (final String family in families) {
      final List<String>? assets = _assets[family];
      if (assets == null) {
        continue;
      }
      jobs.add(_pending.putIfAbsent(family, () => _load(family, assets)));
    }
    return Future.wait(jobs);
  }

  static Future<void> _load(String family, List<String> assets) async {
    final FontLoader loader = FontLoader(family);
    for (final String asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

class StoreBannerTextStylePreset {
  const StoreBannerTextStylePreset({
    required this.id,
    required this.label,
    required this.sample,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeightPreset,
    required this.letterSpacing,
  });

  final String id;
  final String label;
  final String sample;
  final String fontFamily;
  final double fontSize;
  final String fontWeightPreset;
  final double letterSpacing;

  static const List<StoreBannerTextStylePreset> all =
      <StoreBannerTextStylePreset>[
        StoreBannerTextStylePreset(
          id: 'classic',
          label: '經典標題',
          sample: '經典',
          fontFamily: StoreBannerFonts.sans,
          fontSize: 104,
          fontWeightPreset: StoreBannerFontWeights.extraBold,
          letterSpacing: 0,
        ),
        StoreBannerTextStylePreset(
          id: 'minimal',
          label: '極簡細字',
          sample: '簡約',
          fontFamily: StoreBannerFonts.sans,
          fontSize: 40,
          fontWeightPreset: StoreBannerFontWeights.regular,
          letterSpacing: 6,
        ),
        StoreBannerTextStylePreset(
          id: 'elegant',
          label: '優雅質感',
          sample: '質感',
          fontFamily: StoreBannerFonts.serif,
          fontSize: 72,
          fontWeightPreset: StoreBannerFontWeights.regular,
          letterSpacing: 2,
        ),
        StoreBannerTextStylePreset(
          id: 'promo',
          label: '活動強調',
          sample: '優惠',
          fontFamily: StoreBannerFonts.sans,
          fontSize: 128,
          fontWeightPreset: StoreBannerFontWeights.extraBold,
          letterSpacing: 0,
        ),
        StoreBannerTextStylePreset(
          id: 'soft',
          label: '柔和日系',
          sample: '日系',
          fontFamily: StoreBannerFonts.rounded,
          fontSize: 64,
          fontWeightPreset: StoreBannerFontWeights.regular,
          letterSpacing: 1,
        ),
      ];

  bool matches(StoreBannerTextElement element) {
    return element.fontFamily == fontFamily &&
        element.posterFontPx.round() == fontSize.round() &&
        element.fontWeightPreset == fontWeightPreset &&
        (element.letterSpacing - letterSpacing).abs() < 0.05;
  }

  StoreBannerTextElement apply(StoreBannerTextElement element) {
    return element.copyWith(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontSizePreset: StoreBannerFontSizes.nearestPreset(fontSize),
      fontWeightPreset: fontWeightPreset,
      letterSpacing: letterSpacing,
    );
  }
}
