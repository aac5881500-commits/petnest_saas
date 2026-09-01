// lib/core/models/store_banner_model.dart
// 🛒 商城活動海報：存在 store_settings/main.banners[]
// 效果欄位都是前台 render 設定，不改原始圖片。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/petnest_banner_scope.dart';
import 'package:petnest_saas/core/models/store_banner_text_element.dart';

export 'package:petnest_saas/core/models/petnest_banner_scope.dart';
export 'package:petnest_saas/core/models/store_banner_placement.dart';
export 'package:petnest_saas/core/models/store_banner_text_element.dart';

class StoreBannerActionTypes {
  static const String none = 'none';
  static const String product = 'product';
  static const String category = 'category';
  static const String promotion = 'promotion';
  static const String bundle = 'bundle';

  static const List<String> all = <String>[
    none,
    product,
    category,
    promotion,
    bundle,
  ];

  static String label(String type) {
    switch (type) {
      case product:
        return '商品';
      case category:
        return '分類';
      case promotion:
        return '活動';
      case bundle:
        return '套裝優惠';
      default:
        return '無';
    }
  }
}

class StoreBannerSizePresets {
  static const String small = 'small';
  static const String standard = 'standard';
  static const String large = 'large';
  static const List<String> all = <String>[small, standard, large];

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      default:
        return '標準';
    }
  }

  static double heightForWidth(
    String preset,
    double width, {
    PetNestBannerScope scope = PetNestBannerScope.store,
  }) {
    final bool wide = width >= 500;
    if (scope == PetNestBannerScope.home) {
      if (width <= 0) {
        return 0;
      }
      return width / homeAspectRatio(preset);
    }
    switch (preset) {
      case small:
        return (width / 2.5).clamp(140.0, wide ? 180.0 : 155.0);
      case large:
        return (width / (16 / 9)).clamp(210.0, wide ? 260.0 : 230.0);
      default:
        return (width / 2.0).clamp(170.0, wide ? 220.0 : 190.0);
    }
  }

  /// 與 [ModernBannerFrameSetting.aspectRatio] 對齊，僅供 Home canvas 參考。
  static double homeAspectRatio(String preset) {
    switch (preset) {
      case small:
        return 2.4;
      case large:
        return 3 / 2;
      default:
        return 16 / 9;
    }
  }
}

class StoreBannerOverlayModes {
  static const String none = 'none';
  static const String left = 'left';
  static const String right = 'right';
  static const String top = 'top';
  static const String bottom = 'bottom';
  static const String custom = 'custom';
  static const List<String> all = <String>[
    none,
    left,
    right,
    top,
    bottom,
    custom,
  ];
  static const List<String> editorModes = <String>[
    none,
    left,
    right,
    top,
    bottom,
  ];

  static String label(String value) {
    switch (value) {
      case left:
        return '左 → 右';
      case right:
        return '右 → 左';
      case top:
        return '上 → 下';
      case bottom:
        return '下 → 上';
      case custom:
        return '左 → 右';
      default:
        return '無漸層';
    }
  }
}

class StoreBannerOverlayExtents {
  static const String small = 'small';
  static const String standard = 'standard';
  static const String large = 'large';
  static const List<String> all = <String>[small, standard, large];

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      default:
        return '標準';
    }
  }

  static double factor(String value) {
    switch (value) {
      case small:
        return 0.45;
      case large:
        return 0.80;
      default:
        return 0.65;
    }
  }
}

class StoreBannerOverlayStrengths {
  static const String light = 'light';
  static const String standard = 'standard';
  static const String strong = 'strong';
  static const String extraStrong = 'extraStrong';
  static const String deeper = 'deeper';
  static const List<String> all = <String>[
    light,
    standard,
    strong,
    extraStrong,
    deeper,
  ];

  static String label(String value) {
    switch (value) {
      case light:
        return '淡';
      case strong:
        return '強';
      case extraStrong:
        return '很強';
      case deeper:
        return '更深';
      default:
        return '標準';
    }
  }

  static double opacity(String value) {
    switch (value) {
      case light:
        return 0.35;
      case strong:
        return 0.75;
      case extraStrong:
        return 0.95;
      case deeper:
        return 1.0;
      default:
        return 0.55;
    }
  }
}

class StoreBannerOverlayColors {
  static const String dark = 'dark';
  static const String light = 'light';
  static const String softWhite = 'softWhite';
  static const String warmCream = 'warmCream';
  static const String brand = 'brand';
  static const String custom = 'custom';
  static const List<String> all = <String>[
    dark,
    light,
    softWhite,
    warmCream,
    brand,
    custom,
  ];
  static const List<String> editorModes = <String>[
    softWhite,
    warmCream,
    dark,
    brand,
    custom,
  ];

  static String label(String value) {
    switch (value) {
      case warmCream:
        return '暖米白';
      case dark:
        return '深色';
      case brand:
        return '品牌色';
      case custom:
        return '自訂色';
      default:
        return '柔和白';
    }
  }

  static Color colorOf(
    String value,
    Color brandColor, {
    int customArgb = 0xFFFFFFFF,
  }) {
    switch (value) {
      case warmCream:
        return const Color(0xFFF6EFE6);
      case dark:
        return const Color(0xFF1A1410);
      case brand:
        return brandColor;
      case custom:
        return Color(customArgb);
      default:
        return const Color(0xFFFFFFFF);
    }
  }
}

class StoreBannerGradientSpec {
  static const List<double> _relativeStops = <double>[
    0.0,
    0.31,
    0.56,
    0.81,
    1.0,
  ];
  static const List<double> _relativeAlphas = <double>[
    1.0,
    0.84,
    0.58,
    0.21,
    0.0,
  ];
  static const List<double> _deeperAlphas = <double>[
    1.0,
    0.92,
    0.72,
    0.38,
    0.0,
  ];

  static List<double> stops(String extent) {
    final double end = StoreBannerOverlayExtents.factor(extent);
    return <double>[
      ..._relativeStops.map((double stop) => (stop * end).clamp(0.0, 1.0)),
      1.0,
    ];
  }

  static List<double> alphas(String strength) {
    final double peak = StoreBannerOverlayStrengths.opacity(strength);
    final List<double> relative = strength == StoreBannerOverlayStrengths.deeper
        ? _deeperAlphas
        : _relativeAlphas;
    return <double>[
      ...relative.map((double factor) => (peak * factor).clamp(0.0, 1.0)),
      0.0,
    ];
  }

  static LinearGradient gradient({
    required String mode,
    required String extent,
    required String strength,
    required Color color,
  }) {
    final List<double> stopList = stops(extent);
    final List<double> alphaList = alphas(strength);
    return LinearGradient(
      begin: beginOf(mode),
      end: endOf(mode),
      colors: <Color>[
        for (int i = 0; i < alphaList.length; i++)
          color.withValues(alpha: alphaList[i]),
      ],
      stops: stopList,
    );
  }

  static Alignment beginOf(String mode) {
    switch (mode) {
      case StoreBannerOverlayModes.right:
        return Alignment.centerRight;
      case StoreBannerOverlayModes.top:
        return Alignment.topCenter;
      case StoreBannerOverlayModes.bottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.centerLeft;
    }
  }

  static Alignment endOf(String mode) {
    switch (mode) {
      case StoreBannerOverlayModes.right:
        return Alignment.centerLeft;
      case StoreBannerOverlayModes.top:
        return Alignment.bottomCenter;
      case StoreBannerOverlayModes.bottom:
        return Alignment.topCenter;
      default:
        return Alignment.centerRight;
    }
  }
}

class StoreBannerBlurModes {
  static const String none = 'none';
  static const String left = 'left';
  static const String right = 'right';
  static const String top = 'top';
  static const String bottom = 'bottom';
  static const List<String> all = <String>[none, left, right, top, bottom];

  static String label(String value) {
    switch (value) {
      case left:
        return '左側模糊';
      case right:
        return '右側模糊';
      case top:
        return '上方模糊';
      case bottom:
        return '下方模糊';
      default:
        return '無';
    }
  }
}

class StoreBannerBlurStrengths {
  static const String light = 'light';
  static const String standard = 'standard';
  static const String strong = 'strong';
  static const List<String> all = <String>[light, standard, strong];

  static String label(String value) {
    switch (value) {
      case light:
        return '淡';
      case strong:
        return '強';
      default:
        return '標準';
    }
  }

  static List<double> sigmas(String value) {
    switch (value) {
      case light:
        return const <double>[5, 3, 1.5];
      case strong:
        return const <double>[10, 7, 4, 2];
      default:
        return const <double>[8, 5, 3, 1.5];
    }
  }
}

class StoreBannerTextStyles {
  static const String dark = 'dark';
  static const String light = 'light';
  static const String brand = 'brand';
  static const List<String> all = <String>[dark, light, brand];

  static String label(String value) {
    switch (value) {
      case light:
        return '白色';
      case brand:
        return '品牌色';
      default:
        return '深色';
    }
  }
}

class StoreBannerTitleSizes {
  static const String small = 'small';
  static const String standard = 'standard';
  static const String large = 'large';
  static const List<String> all = <String>[small, standard, large];

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      default:
        return '標準';
    }
  }

  static double fontSize(String value) {
    switch (value) {
      case small:
        return 16;
      case large:
        return 24;
      default:
        return 20;
    }
  }
}

class StoreBannerCtaStyles {
  static const String primary = 'primary';
  static const String white = 'white';
  static const String dark = 'dark';
  static const List<String> all = <String>[primary, white, dark];

  static String label(String value) {
    switch (value) {
      case white:
        return '白底';
      case dark:
        return '深色';
      default:
        return '主要色';
    }
  }
}

class StoreBannerCtaSizes {
  static const String small = 'small';
  static const String standard = 'standard';
  static const String large = 'large';
  static const List<String> all = <String>[small, standard, large];

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      default:
        return '標準';
    }
  }
}

class StoreBannerCtaRadii {
  static const String standard = 'standard';
  static const String pill = 'pill';
  static const List<String> all = <String>[standard, pill];

  static String label(String value) {
    switch (value) {
      case pill:
        return '膠囊';
      default:
        return '標準';
    }
  }

  static double radius(String value) {
    return value == pill ? 999 : 10;
  }
}

class StoreBannerTextAligns {
  static const String left = 'left';
  static const String center = 'center';
  static const String right = 'right';
  static const List<String> all = <String>[left, center, right];

  static String label(String value) {
    switch (value) {
      case center:
        return '置中';
      case right:
        return '靠右';
      default:
        return '靠左';
    }
  }

  static TextAlign textAlign(String value) {
    switch (value) {
      case center:
        return TextAlign.center;
      case right:
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  static CrossAxisAlignment cross(String value) {
    switch (value) {
      case center:
        return CrossAxisAlignment.center;
      case right:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }
}

class StoreBannerContrast {
  static double ratio(Color a, Color b) {
    final double light = a.computeLuminance();
    final double dark = b.computeLuminance();
    final double hi = light > dark ? light : dark;
    final double lo = light > dark ? dark : light;
    return (hi + 0.05) / (lo + 0.05);
  }

  static bool mayBeLow(Color foreground, Color background) {
    return ratio(foreground, background) < 3.0;
  }
}

class StoreBannerModel {
  const StoreBannerModel({
    required this.id,
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.enabled = true,
    this.sortOrder = 0,
    this.sizePreset = StoreBannerSizePresets.standard,
    this.imageAlignmentX = 0.5,
    this.imageAlignmentY = 0.5,
    this.imageScale = 1,
    this.overlayMode = StoreBannerOverlayModes.none,
    this.overlayStrength = StoreBannerOverlayStrengths.standard,
    this.overlayExtent = StoreBannerOverlayExtents.standard,
    this.overlayColorMode = StoreBannerOverlayColors.softWhite,
    this.overlayCustomColor = 0xFFFFFFFF,
    this.blurMode = StoreBannerBlurModes.none,
    this.blurStrength = StoreBannerBlurStrengths.standard,
    this.textElements = const <StoreBannerTextElement>[],
    this.eyebrow = '',
    this.title = '',
    this.subtitle = '',
    this.promotionText = '',
    this.ctaEnabled = false,
    this.ctaText = '',
    this.ctaPositionX = 0.08,
    this.ctaPositionY = 0.78,
    this.ctaShowArrow = false,
    this.ctaSize = StoreBannerCtaSizes.standard,
    this.ctaRadius = StoreBannerCtaRadii.pill,
    this.ctaBackgroundColor,
    this.ctaTextColor,
    this.textPositionX = 0.08,
    this.textPositionY = 0.42,
    this.textAlign = StoreBannerTextAligns.left,
    this.textStylePreset = StoreBannerTextStyles.dark,
    this.titleSize = StoreBannerTitleSizes.standard,
    this.ctaStyle = StoreBannerCtaStyles.primary,
    this.actionType = StoreBannerActionTypes.none,
    this.actionTargetId = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String imageUrl;
  final String imageStoragePath;
  final bool enabled;
  final int sortOrder;
  final String sizePreset;
  final double imageAlignmentX;
  final double imageAlignmentY;
  final double imageScale;
  final String overlayMode;
  final String overlayStrength;
  final String overlayExtent;
  final String overlayColorMode;
  final int overlayCustomColor;
  final String blurMode;
  final String blurStrength;
  final List<StoreBannerTextElement> textElements;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String promotionText;
  final bool ctaEnabled;
  final String ctaText;
  final double ctaPositionX;
  final double ctaPositionY;
  final bool ctaShowArrow;
  final String ctaSize;
  final String ctaRadius;
  final int? ctaBackgroundColor;
  final int? ctaTextColor;
  final double textPositionX;
  final double textPositionY;
  final String textAlign;
  final String textStylePreset;
  final String titleSize;
  final String ctaStyle;
  final String actionType;
  final String actionTargetId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  bool get hasLegacyCopy =>
      eyebrow.trim().isNotEmpty ||
      title.trim().isNotEmpty ||
      subtitle.trim().isNotEmpty ||
      promotionText.trim().isNotEmpty;

  bool get showsCta => ctaEnabled && ctaText.trim().isNotEmpty;

  bool get hasCopy =>
      resolvedTextElements.any((StoreBannerTextElement item) => item.hasText) ||
      showsCta;

  /// 已有文字、按鈕或漸層時，套用快速版型前需確認。
  bool get hasLayoutToPreserve =>
      hasCopy || overlayMode != StoreBannerOverlayModes.none;

  bool get hasNavigableAction {
    if (actionType.isEmpty || actionType == StoreBannerActionTypes.none) {
      return false;
    }
    if (actionType == HomeBannerActionTypes.url) {
      return false;
    }
    return true;
  }

  /// 有自己的漸層 / 文字 / CTA 時，前台不再疊首頁全域標題與預約按鈕。
  bool get usesOwnOverlay =>
      overlayMode != StoreBannerOverlayModes.none || hasCopy;

  String get listTitle {
    for (final StoreBannerTextElement item in resolvedTextElements) {
      if (item.hasText) {
        return item.text.trim();
      }
    }
    if (ctaText.trim().isNotEmpty) {
      return ctaText.trim();
    }
    return '';
  }

  Alignment get imageAlignment => Alignment(
    (imageAlignmentX.clamp(0.0, 1.0) * 2) - 1,
    (imageAlignmentY.clamp(0.0, 1.0) * 2) - 1,
  );

  List<StoreBannerTextElement> get resolvedTextElements {
    if (textElements.isNotEmpty) {
      final List<StoreBannerTextElement> items =
          List<StoreBannerTextElement>.from(textElements)..sort(
            (StoreBannerTextElement a, StoreBannerTextElement b) =>
                a.sortOrder.compareTo(b.sortOrder),
          );
      return items;
    }
    return legacyTextElements;
  }

  List<StoreBannerTextElement> get legacyTextElements {
    final int legacyColor = switch (textStylePreset) {
      StoreBannerTextStyles.light => StoreBannerCommonColors.white,
      StoreBannerTextStyles.brand => 0xFFFF8A00,
      _ => StoreBannerCommonColors.darkBrown,
    };
    final String size = switch (titleSize) {
      StoreBannerTitleSizes.small => StoreBannerFontSizes.subhead,
      StoreBannerTitleSizes.large => StoreBannerFontSizes.display,
      _ => StoreBannerFontSizes.title,
    };
    final List<StoreBannerTextElement> items = <StoreBannerTextElement>[];
    void addLine({
      required String id,
      required String text,
      required double y,
      required String fontSize,
      required String weight,
    }) {
      if (text.trim().isEmpty) {
        return;
      }
      items.add(
        StoreBannerTextElement.create(
          id: id,
          text: text,
          positionX: textPositionX,
          positionY: y.clamp(0.0, 1.0),
          fontSizePreset: fontSize,
          fontWeightPreset: weight,
          textColor: legacyColor,
          textAlign: textAlign,
          maxWidthPreset: StoreBannerTextWidthPresets.standard,
          sortOrder: items.length,
        ),
      );
    }

    addLine(
      id: 'legacy_eyebrow',
      text: eyebrow,
      y: (textPositionY - 0.16).clamp(0.04, 0.9),
      fontSize: StoreBannerFontSizes.small,
      weight: StoreBannerFontWeights.bold,
    );
    addLine(
      id: 'legacy_title',
      text: title,
      y: textPositionY,
      fontSize: size,
      weight: StoreBannerFontWeights.extraBold,
    );
    addLine(
      id: 'legacy_subtitle',
      text: subtitle,
      y: (textPositionY + 0.18).clamp(0.04, 0.92),
      fontSize: StoreBannerFontSizes.body,
      weight: StoreBannerFontWeights.regular,
    );
    addLine(
      id: 'legacy_promo',
      text: promotionText,
      y: (textPositionY + 0.32).clamp(0.08, 0.94),
      fontSize: StoreBannerFontSizes.subhead,
      weight: StoreBannerFontWeights.bold,
    );
    return items;
  }

  factory StoreBannerModel.fromMap(Map<String, dynamic> data) {
    String pick(List<String> allowed, dynamic raw, String fallback) {
      final String value = (raw ?? fallback).toString();
      return allowed.contains(value) ? value : fallback;
    }

    final List<StoreBannerTextElement> elements = <StoreBannerTextElement>[];
    final dynamic rawElements = data['textElements'];
    if (rawElements is List) {
      for (final dynamic item in rawElements) {
        if (item is Map) {
          final StoreBannerTextElement element = StoreBannerTextElement.fromMap(
            Map<String, dynamic>.from(item),
          );
          if (element.id.isNotEmpty) {
            elements.add(element);
          }
        }
      }
    }

    final String ctaText = (data['ctaText'] ?? '').toString();
    // 有 ctaEnabled 就照存檔；舊資料沒有此欄才用「有按鈕文案」推斷，不要預設 true。
    final bool ctaEnabled = data['ctaEnabled'] is bool
        ? data['ctaEnabled'] as bool
        : ctaText.trim().isNotEmpty;

    String colorMode = pick(
      StoreBannerOverlayColors.all,
      data['overlayColorMode'],
      StoreBannerOverlayColors.dark,
    );
    if (colorMode == StoreBannerOverlayColors.light) {
      colorMode = StoreBannerOverlayColors.softWhite;
    }

    return StoreBannerModel(
      id: (data['id'] ?? '').toString().trim(),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      imageStoragePath: (data['imageStoragePath'] ?? '').toString().trim(),
      enabled: data['enabled'] is bool
          ? data['enabled'] as bool
          : data['isActive'] != false,
      sortOrder: _intOf(data['sortOrder']),
      sizePreset: pick(
        StoreBannerSizePresets.all,
        data['sizePreset'],
        StoreBannerSizePresets.standard,
      ),
      imageAlignmentX: _ratioOf(data['imageAlignmentX'], 0.5),
      imageAlignmentY: _ratioOf(data['imageAlignmentY'], 0.5),
      imageScale: _scaleOf(data['imageScale']),
      overlayMode: pick(
        StoreBannerOverlayModes.all,
        data['overlayMode'],
        StoreBannerOverlayModes.none,
      ),
      overlayStrength: pick(
        StoreBannerOverlayStrengths.all,
        data['overlayStrength'],
        StoreBannerOverlayStrengths.standard,
      ),
      overlayExtent: pick(
        StoreBannerOverlayExtents.all,
        data['overlayExtent'],
        StoreBannerOverlayExtents.standard,
      ),
      overlayColorMode: colorMode,
      overlayCustomColor: StoreBannerColorCodec.parse(
        data['overlayCustomColor'],
        0xFFFFFFFF,
      ),
      blurMode: pick(
        StoreBannerBlurModes.all,
        data['blurMode'],
        StoreBannerBlurModes.none,
      ),
      blurStrength: pick(
        StoreBannerBlurStrengths.all,
        data['blurStrength'],
        StoreBannerBlurStrengths.standard,
      ),
      textElements: elements,
      eyebrow: (data['eyebrow'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      subtitle: (data['subtitle'] ?? '').toString(),
      promotionText: (data['promotionText'] ?? '').toString(),
      ctaEnabled: ctaEnabled,
      ctaText: ctaText,
      ctaPositionX: _ratioOf(
        data['ctaPositionX'],
        _ratioOf(data['textPositionX'], 0.08),
      ),
      ctaPositionY: _ratioOf(data['ctaPositionY'], 0.78),
      ctaShowArrow: data['ctaShowArrow'] == true,
      ctaSize: pick(
        StoreBannerCtaSizes.all,
        data['ctaSize'],
        StoreBannerCtaSizes.standard,
      ),
      ctaRadius: pick(
        StoreBannerCtaRadii.all,
        data['ctaRadius'],
        StoreBannerCtaRadii.pill,
      ),
      ctaBackgroundColor: data['ctaBackgroundColor'] == null
          ? null
          : StoreBannerColorCodec.parse(data['ctaBackgroundColor'], 0xFF2E7D4F),
      ctaTextColor: data['ctaTextColor'] == null
          ? null
          : StoreBannerColorCodec.parse(data['ctaTextColor'], 0xFFFFFFFF),
      textPositionX: _ratioOf(data['textPositionX'], 0.08),
      textPositionY: _ratioOf(data['textPositionY'], 0.42),
      textAlign: pick(
        StoreBannerTextAligns.all,
        data['textAlign'],
        StoreBannerTextAligns.left,
      ),
      textStylePreset: pick(
        StoreBannerTextStyles.all,
        data['textStylePreset'],
        StoreBannerTextStyles.dark,
      ),
      titleSize: pick(
        StoreBannerTitleSizes.all,
        data['titleSize'],
        StoreBannerTitleSizes.standard,
      ),
      ctaStyle: pick(
        StoreBannerCtaStyles.all,
        data['ctaStyle'],
        StoreBannerCtaStyles.primary,
      ),
      actionType: pick(
        <String>{
          ...StoreBannerActionTypes.all,
          ...HomeBannerActionTypes.all,
        }.toList(),
        _actionTypeOf(data),
        StoreBannerActionTypes.none,
      ),
      actionTargetId: (data['actionTargetId'] ?? '').toString().trim(),
      createdAt: _dateOf(data['createdAt']),
      updatedAt: _dateOf(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'imageUrl': imageUrl.trim(),
      'imageStoragePath': imageStoragePath.trim(),
      'enabled': enabled,
      'isActive': enabled,
      'sortOrder': sortOrder,
      'sizePreset': sizePreset,
      'imageAlignmentX': imageAlignmentX.clamp(0.0, 1.0),
      'imageAlignmentY': imageAlignmentY.clamp(0.0, 1.0),
      'imageScale': imageScale.clamp(1.0, 2.5),
      'overlayMode': overlayMode,
      'overlayStrength': overlayStrength,
      'overlayExtent': overlayExtent,
      'overlayColorMode': overlayColorMode,
      'overlayCustomColor': overlayCustomColor,
      'blurMode': blurMode,
      'blurStrength': blurStrength,
      'textElements': textElements
          .map((StoreBannerTextElement item) => item.toMap())
          .toList(),
      'eyebrow': eyebrow.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'promotionText': promotionText.trim(),
      'ctaEnabled': ctaEnabled,
      'ctaText': ctaText.trim(),
      'ctaPositionX': ctaPositionX.clamp(0.0, 1.0),
      'ctaPositionY': ctaPositionY.clamp(0.0, 1.0),
      'ctaShowArrow': ctaShowArrow,
      'ctaSize': ctaSize,
      'ctaRadius': ctaRadius,
      'ctaBackgroundColor': ctaBackgroundColor,
      'ctaTextColor': ctaTextColor,
      'textPositionX': textPositionX.clamp(0.0, 1.0),
      'textPositionY': textPositionY.clamp(0.0, 1.0),
      'textAlign': textAlign,
      'textStylePreset': textStylePreset,
      'titleSize': titleSize,
      'ctaStyle': ctaStyle,
      'actionType': actionType,
      'actionTargetId': actionTargetId.trim(),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  StoreBannerModel copyWith({
    String? imageUrl,
    String? imageStoragePath,
    bool? enabled,
    int? sortOrder,
    String? sizePreset,
    double? imageAlignmentX,
    double? imageAlignmentY,
    double? imageScale,
    String? overlayMode,
    String? overlayStrength,
    String? overlayExtent,
    String? overlayColorMode,
    int? overlayCustomColor,
    String? blurMode,
    String? blurStrength,
    List<StoreBannerTextElement>? textElements,
    String? eyebrow,
    String? title,
    String? subtitle,
    String? promotionText,
    bool? ctaEnabled,
    String? ctaText,
    double? ctaPositionX,
    double? ctaPositionY,
    bool? ctaShowArrow,
    String? ctaSize,
    String? ctaRadius,
    int? ctaBackgroundColor,
    int? ctaTextColor,
    bool clearCtaBackgroundColor = false,
    bool clearCtaTextColor = false,
    double? textPositionX,
    double? textPositionY,
    String? textAlign,
    String? textStylePreset,
    String? titleSize,
    String? ctaStyle,
    String? actionType,
    String? actionTargetId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreBannerModel(
      id: id,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      sizePreset: sizePreset ?? this.sizePreset,
      imageAlignmentX: imageAlignmentX ?? this.imageAlignmentX,
      imageAlignmentY: imageAlignmentY ?? this.imageAlignmentY,
      imageScale: imageScale ?? this.imageScale,
      overlayMode: overlayMode ?? this.overlayMode,
      overlayStrength: overlayStrength ?? this.overlayStrength,
      overlayExtent: overlayExtent ?? this.overlayExtent,
      overlayColorMode: overlayColorMode ?? this.overlayColorMode,
      overlayCustomColor: overlayCustomColor ?? this.overlayCustomColor,
      blurMode: blurMode ?? this.blurMode,
      blurStrength: blurStrength ?? this.blurStrength,
      textElements: textElements ?? this.textElements,
      eyebrow: eyebrow ?? this.eyebrow,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      promotionText: promotionText ?? this.promotionText,
      ctaEnabled: ctaEnabled ?? this.ctaEnabled,
      ctaText: ctaText ?? this.ctaText,
      ctaPositionX: ctaPositionX ?? this.ctaPositionX,
      ctaPositionY: ctaPositionY ?? this.ctaPositionY,
      ctaShowArrow: ctaShowArrow ?? this.ctaShowArrow,
      ctaSize: ctaSize ?? this.ctaSize,
      ctaRadius: ctaRadius ?? this.ctaRadius,
      ctaBackgroundColor: clearCtaBackgroundColor
          ? null
          : (ctaBackgroundColor ?? this.ctaBackgroundColor),
      ctaTextColor: clearCtaTextColor
          ? null
          : (ctaTextColor ?? this.ctaTextColor),
      textPositionX: textPositionX ?? this.textPositionX,
      textPositionY: textPositionY ?? this.textPositionY,
      textAlign: textAlign ?? this.textAlign,
      textStylePreset: textStylePreset ?? this.textStylePreset,
      titleSize: titleSize ?? this.titleSize,
      ctaStyle: ctaStyle ?? this.ctaStyle,
      actionType: actionType ?? this.actionType,
      actionTargetId: actionTargetId ?? this.actionTargetId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Color copyColor(HomeThemeModel theme) {
    switch (textStylePreset) {
      case StoreBannerTextStyles.brand:
        return theme.primaryColor;
      case StoreBannerTextStyles.dark:
        return const Color(0xFF2A221C);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color overlayColor(HomeThemeModel theme) {
    return StoreBannerOverlayColors.colorOf(
      overlayColorMode,
      theme.primaryColor,
      customArgb: overlayCustomColor,
    );
  }

  Color resolvedCtaBackground(HomeThemeModel theme) {
    if (ctaBackgroundColor != null) {
      return Color(ctaBackgroundColor!);
    }
    switch (ctaStyle) {
      case StoreBannerCtaStyles.white:
        return const Color(0xFFFFFFFF);
      case StoreBannerCtaStyles.dark:
        return const Color(0xFF2A221C);
      default:
        return theme.primaryColor;
    }
  }

  Color resolvedCtaForeground(HomeThemeModel theme) {
    if (ctaTextColor != null) {
      return Color(ctaTextColor!);
    }
    final Color background = resolvedCtaBackground(theme);
    if (ctaStyle == StoreBannerCtaStyles.white) {
      return const Color(0xFF2A221C);
    }
    if (ctaStyle == StoreBannerCtaStyles.dark) {
      return const Color(0xFFFFFFFF);
    }
    return background.computeLuminance() > 0.55
        ? const Color(0xFF2A221C)
        : const Color(0xFFFFFFFF);
  }

  StoreBannerModel hydrateLegacyForEditor() {
    if (textElements.isNotEmpty) {
      return this;
    }
    if (!hasLegacyCopy) {
      return this;
    }
    return copyWith(textElements: legacyTextElements);
  }

  static String _actionTypeOf(Map<String, dynamic> data) {
    final String raw = (data['actionType'] ?? data['linkType'] ?? '')
        .toString()
        .trim();
    if (raw == 'externalUrl' || raw == 'external_url') {
      return HomeBannerActionTypes.url;
    }
    return raw;
  }

  static int _intOf(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _ratioOf(dynamic value, double fallback) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? fallback;
    return parsed.clamp(0.0, 1.0);
  }

  static double _scaleOf(dynamic value) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 1;
    return parsed.clamp(1.0, 2.5);
  }

  static DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String imageUserMessage(Object error) {
    final String message = error.toString();
    if (message.contains('5MB') || message.contains('5 MB')) {
      return '圖片不可超過 5 MB';
    }
    return message;
  }

  static const int maxTextElements = 12;
}
