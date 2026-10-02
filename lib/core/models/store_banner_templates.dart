// 檔案名稱：lib/core/models/store_banner_templates.dart
// 功能說明：海報快速版型。以 1600×900 預留標題、副標題、CTA 三區，避免重疊。

import 'dart:math' as math;
import 'dart:ui';

import 'package:petnest_saas/core/models/store_banner_model.dart';

class StoreBannerTemplateMetrics {
  static const double designWidth = 1600;
  static const double designHeight = 900;
  static const double titleLineHeight = 1.15;
  static const double subtitleLineHeight = 1.3;
  static const double textGap = 20;
  static const double ctaGap = 32;
  static const double safeTop = 72;
  static const double safeBottom = 846;

  static double get safeSpan => safeBottom - safeTop;

  static double blockHeight({
    required double fontPx,
    required double lineHeight,
    required int lines,
  }) {
    return fontPx * lineHeight * lines.clamp(1, 2);
  }

  static double stackHeight({
    required double titlePx,
    required double subtitlePx,
    required int titleLines,
    required int subtitleLines,
    required double ctaHeight,
  }) {
    return blockHeight(
          fontPx: titlePx,
          lineHeight: titleLineHeight,
          lines: titleLines,
        ) +
        textGap +
        blockHeight(
          fontPx: subtitlePx,
          lineHeight: subtitleLineHeight,
          lines: subtitleLines,
        ) +
        ctaGap +
        ctaHeight;
  }

  static double y(double designTop) => designTop / designHeight;

  /// 由上往下排。區塊高度依這個模板的字級與行數計算。
  static ({double title, double subtitle, double cta}) fromTop({
    required double topDesign,
    required double titlePx,
    required double subtitlePx,
    int titleLines = 2,
    int subtitleLines = 2,
  }) {
    final double title = topDesign;
    final double subtitle =
        title +
        blockHeight(
          fontPx: titlePx,
          lineHeight: titleLineHeight,
          lines: titleLines,
        ) +
        textGap;
    final double cta =
        subtitle +
        blockHeight(
          fontPx: subtitlePx,
          lineHeight: subtitleLineHeight,
          lines: subtitleLines,
        ) +
        ctaGap;
    return (title: y(title), subtitle: y(subtitle), cta: y(cta));
  }

  /// 由下往上排，CTA 底邊停在 [bottomDesign]。
  static ({double title, double subtitle, double cta}) fromBottom({
    required double bottomDesign,
    required double titlePx,
    required double subtitlePx,
    int titleLines = 2,
    int subtitleLines = 2,
    required double ctaHeight,
  }) {
    final double ctaTop = bottomDesign - ctaHeight;
    final double subtitleTop =
        ctaTop -
        ctaGap -
        blockHeight(
          fontPx: subtitlePx,
          lineHeight: subtitleLineHeight,
          lines: subtitleLines,
        );
    final double titleTop =
        subtitleTop -
        textGap -
        blockHeight(
          fontPx: titlePx,
          lineHeight: titleLineHeight,
          lines: titleLines,
        );
    return (title: y(titleTop), subtitle: y(subtitleTop), cta: y(ctaTop));
  }

  static Rect block({
    required double x,
    required double yFraction,
    required double widthFraction,
    required double heightDesign,
  }) {
    return Rect.fromLTWH(
      x * designWidth,
      yFraction * designHeight,
      widthFraction * designWidth,
      heightDesign,
    );
  }
}

class StoreBannerTemplates {
  static const String leftCopy = 'leftCopy';
  static const String rightCopy = 'rightCopy';
  static const String centerCopy = 'centerCopy';
  static const String bottomCard = 'bottomCard';
  static const String bottomLeft = 'bottomLeft';
  static const String bottomRight = 'bottomRight';
  static const String topMinimal = 'topMinimal';
  static const String imageOnly = 'imageOnly';
  static const String promo = 'promo';

  static const List<String> all = <String>[
    leftCopy,
    rightCopy,
    centerCopy,
    imageOnly,
    promo,
  ];

  static const List<String> homeIds = <String>[
    leftCopy,
    rightCopy,
    centerCopy,
    bottomCard,
    bottomLeft,
    bottomRight,
    topMinimal,
    imageOnly,
    promo,
  ];

  static List<String> idsFor(PetNestBannerScope scope) {
    if (scope == PetNestBannerScope.home) {
      return homeIds;
    }
    return all;
  }

  static String label(String value) {
    switch (value) {
      case rightCopy:
        return '右文左圖';
      case centerCopy:
        return '中央文字';
      case bottomCard:
        return '底部資訊卡';
      case bottomLeft:
        return '左下活動標題';
      case bottomRight:
        return '右下活動標題';
      case topMinimal:
        return '上方簡約標題';
      case imageOnly:
        return '純圖片';
      case promo:
        return '商城促銷';
      default:
        return '左文右圖';
    }
  }

  static StoreBannerModel apply(StoreBannerModel source, String template) {
    return applyDetailed(source, template).banner;
  }

  static ({StoreBannerModel banner, bool copyTooLong}) applyDetailed(
    StoreBannerModel source,
    String template,
  ) {
    final String prefix = 'te_${source.id}';
    final String title = _keptText(
      source,
      suffix: '_title',
      field: source.title,
      fallback: _defaultTitle(template),
      elementIndex: 0,
    );
    final String subtitle = _keptText(
      source,
      suffix: '_sub',
      field: source.subtitle,
      fallback: _defaultSubtitle(template),
      elementIndex: 1,
    );
    final String ctaText = source.ctaText.trim().isEmpty
        ? _defaultCta(template)
        : source.ctaText.trim();
    if (template == imageOnly) {
      return (
        banner: source.copyWith(
          overlayMode: StoreBannerOverlayModes.none,
          textAlign: StoreBannerTextAligns.left,
          textElements: const <StoreBannerTextElement>[],
          ctaEnabled: false,
          ctaShowArrow: false,
        ),
        copyTooLong: false,
      );
    }
    final ({double title, double subtitle}) defaults = _defaultPx(template);
    final String ctaSize = _defaultCtaSize(template);
    final double ctaHeight = StoreBannerCtaSizes.box(
      ctaSize,
      scale: source.ctaScale,
    ).occupiedHeight;
    final _FontFit fit = _fitFonts(
      title: title,
      subtitle: subtitle,
      titlePx: defaults.title,
      subtitlePx: defaults.subtitle,
      widthPx:
          _widthFraction(template) * StoreBannerTemplateMetrics.designWidth,
      ctaHeight: ctaHeight,
    );
    final _TemplateSpec spec = _spec(
      template,
      ctaText,
      titlePx: fit.titlePx,
      subtitlePx: fit.subtitlePx,
      titleLines: fit.titleLines,
      subtitleLines: fit.subtitleLines,
      ctaSize: ctaSize,
      ctaHeight: ctaHeight,
      ctaScale: source.ctaScale,
    );
    return (
      banner: source.copyWith(
        overlayMode: spec.overlayMode,
        overlayColorMode: StoreBannerOverlayColors.dark,
        overlayExtent: spec.extent,
        overlayStrength: StoreBannerOverlayStrengths.standard,
        textAlign: spec.align,
        textElements: <StoreBannerTextElement>[
          _line(
            id: '${prefix}_title',
            text: title,
            x: spec.x,
            y: spec.slots.title,
            size: StoreBannerFontSizes.title,
            fontPx: spec.titlePx,
            weight: StoreBannerFontWeights.bold,
            color: StoreBannerCommonColors.white,
            align: spec.align,
            width: spec.width,
            order: 0,
          ),
          _line(
            id: '${prefix}_sub',
            text: subtitle,
            x: spec.x,
            y: spec.slots.subtitle,
            size: StoreBannerFontSizes.body,
            fontPx: spec.subtitlePx,
            weight: StoreBannerFontWeights.regular,
            color: StoreBannerCommonColors.white,
            align: spec.align,
            width: spec.width,
            order: 1,
          ),
        ],
        ctaEnabled: true,
        ctaText: ctaText,
        ctaShowArrow: true,
        ctaPositionX: spec.ctaX,
        ctaPositionY: spec.slots.cta,
        ctaSize: ctaSize,
        ctaRadius: StoreBannerCtaRadii.pill,
        ctaBackgroundColor: spec.ctaBackground,
        ctaTextColor: StoreBannerCommonColors.white,
      ),
      copyTooLong: fit.copyTooLong,
    );
  }

  static String _keptText(
    StoreBannerModel source, {
    required String suffix,
    required String field,
    required String fallback,
    required int elementIndex,
  }) {
    for (final StoreBannerTextElement item in source.textElements) {
      if (item.id.endsWith(suffix) && item.text.trim().isNotEmpty) {
        return item.text.trim();
      }
    }
    if (field.trim().isNotEmpty) {
      return field.trim();
    }
    if (elementIndex >= 0 &&
        elementIndex < source.textElements.length &&
        source.textElements[elementIndex].text.trim().isNotEmpty &&
        !source.textElements[elementIndex].id.endsWith('_title') &&
        !source.textElements[elementIndex].id.endsWith('_sub')) {
      return source.textElements[elementIndex].text.trim();
    }
    return fallback;
  }

  static String _defaultTitle(String template) {
    switch (template) {
      case promo:
        return '週末安親優惠';
      case topMinimal:
        return '安心寄宿';
      default:
        return '寵物生活選品';
    }
  }

  static String _defaultSubtitle(String template) {
    switch (template) {
      case promo:
        return '本週預約，贈送洗澡';
      case topMinimal:
        return '環境乾淨，即時回報';
      default:
        return '精選推薦，安心帶回家';
    }
  }

  static String _defaultCta(String template) {
    switch (template) {
      case promo:
        return '查看活動';
      default:
        return '了解更多';
    }
  }

  static String _defaultCtaSize(String template) {
    switch (template) {
      case centerCopy:
      case bottomCard:
      case promo:
        return StoreBannerCtaSizes.large;
      default:
        return StoreBannerCtaSizes.standard;
    }
  }

  static ({double title, double subtitle}) _defaultPx(String template) {
    switch (template) {
      case centerCopy:
        return (title: 112, subtitle: 48);
      case bottomCard:
        return (title: 96, subtitle: 42);
      case bottomLeft:
      case bottomRight:
        return (title: 100, subtitle: 44);
      case topMinimal:
        return (title: 92, subtitle: 40);
      case promo:
        return (title: 116, subtitle: 48);
      default:
        return (title: 104, subtitle: 46);
    }
  }

  static double _widthFraction(String template) {
    switch (template) {
      case centerCopy:
      case bottomCard:
      case topMinimal:
        return StoreBannerTextWidthPresets.ratio(
          StoreBannerTextWidthPresets.wide,
        );
      case promo:
        return StoreBannerTextWidthPresets.ratio(
          StoreBannerTextWidthPresets.standard,
        );
      default:
        return StoreBannerTextWidthPresets.ratio(
          StoreBannerTextWidthPresets.narrow,
        );
    }
  }

  static int _lineCount(String text, double fontPx, double widthPx) {
    final String value = text.trim();
    if (value.isEmpty) {
      return 1;
    }
    final int perLine = math.max(1, (widthPx / math.max(18, fontPx)).floor());
    return (value.runes.length / perLine).ceil();
  }

  static _FontFit _fitFonts({
    required String title,
    required String subtitle,
    required double titlePx,
    required double subtitlePx,
    required double widthPx,
    required double ctaHeight,
  }) {
    const double titleFloor = 72;
    const double subtitleFloor = 32;
    double titleSize = titlePx;
    double subtitleSize = subtitlePx;
    for (int step = 0; step < 48; step++) {
      final int titleNeeded = _lineCount(title, titleSize, widthPx);
      final int subtitleNeeded = _lineCount(subtitle, subtitleSize, widthPx);
      final int titleLines = titleNeeded.clamp(1, 2);
      final int subtitleLines = subtitleNeeded.clamp(1, 2);
      final double stack = StoreBannerTemplateMetrics.stackHeight(
        titlePx: titleSize,
        subtitlePx: subtitleSize,
        titleLines: titleLines,
        subtitleLines: subtitleLines,
        ctaHeight: ctaHeight,
      );
      final bool overflow =
          titleNeeded > 2 ||
          subtitleNeeded > 2 ||
          stack > StoreBannerTemplateMetrics.safeSpan;
      if (!overflow) {
        return _FontFit(
          titlePx: titleSize,
          subtitlePx: subtitleSize,
          titleLines: titleLines,
          subtitleLines: subtitleLines,
          copyTooLong: false,
        );
      }
      if (titleSize <= titleFloor && subtitleSize <= subtitleFloor) {
        return _FontFit(
          titlePx: titleFloor,
          subtitlePx: subtitleFloor,
          titleLines: 2,
          subtitleLines: 2,
          copyTooLong: true,
        );
      }
      if (titleSize > titleFloor) {
        titleSize = math.max(titleFloor, titleSize - 4);
      }
      if (subtitleSize > subtitleFloor) {
        subtitleSize = math.max(subtitleFloor, subtitleSize - 2);
      }
    }
    return _FontFit(
      titlePx: titleFloor,
      subtitlePx: subtitleFloor,
      titleLines: 2,
      subtitleLines: 2,
      copyTooLong: true,
    );
  }

  static _TemplateSpec _spec(
    String template,
    String ctaText, {
    required double titlePx,
    required double subtitlePx,
    required int titleLines,
    required int subtitleLines,
    required String ctaSize,
    required double ctaHeight,
    double ctaScale = 1,
  }) {
    final double sideWidth = StoreBannerTextWidthPresets.ratio(
      StoreBannerTextWidthPresets.narrow,
    );
    final double centerWidth = StoreBannerTextWidthPresets.ratio(
      StoreBannerTextWidthPresets.wide,
    );
    final double promoWidth = StoreBannerTextWidthPresets.ratio(
      StoreBannerTextWidthPresets.standard,
    );
    final double ctaWidth = _ctaWidthFraction(
      ctaText,
      size: ctaSize,
      scale: ctaScale,
    );
    final ({double title, double subtitle, double cta}) upper =
        StoreBannerTemplateMetrics.fromTop(
          topDesign: StoreBannerTemplateMetrics.safeTop,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
          titleLines: titleLines,
          subtitleLines: subtitleLines,
        );
    final ({double title, double subtitle, double cta}) lower =
        StoreBannerTemplateMetrics.fromBottom(
          bottomDesign: StoreBannerTemplateMetrics.safeBottom,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
          titleLines: titleLines,
          subtitleLines: subtitleLines,
          ctaHeight: ctaHeight,
        );
    final ({double title, double subtitle, double cta}) topSlots =
        StoreBannerTemplateMetrics.fromTop(
          topDesign: 64,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
          titleLines: titleLines,
          subtitleLines: subtitleLines,
        );
    switch (template) {
      case rightCopy:
        return _TemplateSpec(
          x: 1,
          ctaX: 1,
          width: StoreBannerTextWidthPresets.narrow,
          widthFraction: sideWidth,
          align: StoreBannerTextAligns.right,
          overlayMode: StoreBannerOverlayModes.right,
          extent: StoreBannerOverlayExtents.standard,
          slots: upper,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case centerCopy:
        return _TemplateSpec(
          x: (1 - centerWidth) / 2,
          ctaX: (1 - ctaWidth) / 2,
          width: StoreBannerTextWidthPresets.wide,
          widthFraction: centerWidth,
          align: StoreBannerTextAligns.center,
          overlayMode: StoreBannerOverlayModes.bottom,
          extent: StoreBannerOverlayExtents.standard,
          slots: upper,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case bottomCard:
        return _TemplateSpec(
          x: (1 - centerWidth) / 2,
          ctaX: (1 - ctaWidth) / 2,
          width: StoreBannerTextWidthPresets.wide,
          widthFraction: centerWidth,
          align: StoreBannerTextAligns.center,
          overlayMode: StoreBannerOverlayModes.bottom,
          extent: StoreBannerOverlayExtents.large,
          slots: lower,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case bottomLeft:
        return _TemplateSpec(
          x: 0.06,
          ctaX: 0.06,
          width: StoreBannerTextWidthPresets.narrow,
          widthFraction: sideWidth,
          align: StoreBannerTextAligns.left,
          overlayMode: StoreBannerOverlayModes.left,
          extent: StoreBannerOverlayExtents.standard,
          slots: lower,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case bottomRight:
        return _TemplateSpec(
          x: 1,
          ctaX: 1,
          width: StoreBannerTextWidthPresets.narrow,
          widthFraction: sideWidth,
          align: StoreBannerTextAligns.right,
          overlayMode: StoreBannerOverlayModes.right,
          extent: StoreBannerOverlayExtents.standard,
          slots: lower,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case topMinimal:
        return _TemplateSpec(
          x: (1 - centerWidth) / 2,
          ctaX: (1 - ctaWidth) / 2,
          width: StoreBannerTextWidthPresets.wide,
          widthFraction: centerWidth,
          align: StoreBannerTextAligns.center,
          overlayMode: StoreBannerOverlayModes.top,
          extent: StoreBannerOverlayExtents.standard,
          slots: topSlots,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
      case promo:
        return _TemplateSpec(
          x: (1 - promoWidth) / 2,
          ctaX: (1 - ctaWidth) / 2,
          width: StoreBannerTextWidthPresets.standard,
          widthFraction: promoWidth,
          align: StoreBannerTextAligns.center,
          overlayMode: StoreBannerOverlayModes.bottom,
          extent: StoreBannerOverlayExtents.large,
          slots: lower,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
          ctaBackground: StoreBannerCommonColors.darkBrown,
        );
      default:
        return _TemplateSpec(
          x: 0.06,
          ctaX: 0.06,
          width: StoreBannerTextWidthPresets.narrow,
          widthFraction: sideWidth,
          align: StoreBannerTextAligns.left,
          overlayMode: StoreBannerOverlayModes.left,
          extent: StoreBannerOverlayExtents.standard,
          slots: upper,
          titlePx: titlePx,
          subtitlePx: subtitlePx,
        );
    }
  }

  /// 以 1600×900 預留的三個區塊。右對齊時左緣依實際寬度回推。
  static List<Rect> reservedBlocks(String template, {String ctaText = '了解更多'}) {
    if (template == imageOnly) {
      return const <Rect>[];
    }
    final ({double title, double subtitle}) defaults = _defaultPx(template);
    final String ctaSize = _defaultCtaSize(template);
    final double ctaHeight = StoreBannerCtaSizes.box(ctaSize).occupiedHeight;
    final _TemplateSpec spec = _spec(
      template,
      ctaText,
      titlePx: defaults.title,
      subtitlePx: defaults.subtitle,
      titleLines: 2,
      subtitleLines: 2,
      ctaSize: ctaSize,
      ctaHeight: ctaHeight,
    );
    final double textLeft = spec.align == StoreBannerTextAligns.right
        ? (1 - StoreBannerPlacement.safeFraction - spec.widthFraction).clamp(
            0.0,
            1.0,
          )
        : spec.x;
    final double ctaWidth = _ctaWidthFraction(
      ctaText,
      size: ctaSize,
    ).clamp(0.12, 0.70);
    final double ctaLeft = spec.ctaX >= 0.99
        ? (1 - StoreBannerPlacement.safeFraction - ctaWidth).clamp(0.0, 1.0)
        : spec.ctaX;
    return <Rect>[
      StoreBannerTemplateMetrics.block(
        x: textLeft,
        yFraction: spec.slots.title,
        widthFraction: spec.widthFraction,
        heightDesign: StoreBannerTemplateMetrics.blockHeight(
          fontPx: spec.titlePx,
          lineHeight: StoreBannerTemplateMetrics.titleLineHeight,
          lines: 2,
        ),
      ),
      StoreBannerTemplateMetrics.block(
        x: textLeft,
        yFraction: spec.slots.subtitle,
        widthFraction: spec.widthFraction,
        heightDesign: StoreBannerTemplateMetrics.blockHeight(
          fontPx: spec.subtitlePx,
          lineHeight: StoreBannerTemplateMetrics.subtitleLineHeight,
          lines: 2,
        ),
      ),
      StoreBannerTemplateMetrics.block(
        x: ctaLeft,
        yFraction: spec.slots.cta,
        widthFraction: ctaWidth,
        heightDesign: ctaHeight,
      ),
    ];
  }

  static double _ctaWidthFraction(
    String text, {
    required String size,
    double scale = 1,
  }) {
    final StoreBannerCtaBox box = StoreBannerCtaSizes.box(size, scale: scale);
    final int length = text.trim().isEmpty ? 4 : text.trim().runes.length;
    final double width = length * box.fontPx + box.paddingH * 2;
    return (width / StoreBannerTemplateMetrics.designWidth).clamp(0.12, 0.70);
  }

  static StoreBannerTextElement _line({
    required String id,
    required String text,
    required double x,
    required double y,
    required String size,
    required double fontPx,
    required String weight,
    required int color,
    required String align,
    required String width,
    required int order,
  }) {
    return StoreBannerTextElement.create(
      id: id,
      text: text,
      positionX: x,
      positionY: y,
      fontSizePreset: size,
      fontSize: fontPx,
      fontWeightPreset: weight,
      textColor: color,
      textAlign: align,
      maxWidthPreset: width,
      sortOrder: order,
    );
  }
}

class _FontFit {
  const _FontFit({
    required this.titlePx,
    required this.subtitlePx,
    required this.titleLines,
    required this.subtitleLines,
    required this.copyTooLong,
  });

  final double titlePx;
  final double subtitlePx;
  final int titleLines;
  final int subtitleLines;
  final bool copyTooLong;
}

class _TemplateSpec {
  const _TemplateSpec({
    required this.x,
    required this.ctaX,
    required this.width,
    required this.widthFraction,
    required this.align,
    required this.overlayMode,
    required this.extent,
    required this.slots,
    this.titlePx = StoreBannerFontSizes.designTitle,
    this.subtitlePx = StoreBannerFontSizes.designSubtitle,
    this.ctaBackground = StoreBannerCommonColors.warmBrown,
  });

  final double x;
  final double ctaX;
  final String width;
  final double widthFraction;
  final String align;
  final String overlayMode;
  final String extent;
  final ({double title, double subtitle, double cta}) slots;
  final double titlePx;
  final double subtitlePx;
  final int ctaBackground;
}
