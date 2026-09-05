// 檔案名稱：lib/core/models/environment_intro_style.dart
// 功能說明：環境介紹全域顯示：尺寸、字體、特色卡版型與高度。
// 掛在 shops/{shopId}.environmentIntro；舊資料沒有欄位時全部用標準／橫向圖卡。

class EnvironmentIntroStyle {
  static const String sizeCompact = 'compact';
  static const String sizeStandard = 'standard';
  static const String sizeLarge = 'large';

  static const String fontSmall = 'small';
  static const String fontStandard = 'standard';
  static const String fontLarge = 'large';

  static const String layoutHorizontal = 'horizontal';
  static const String layoutVertical = 'vertical';
  static const String layoutText = 'text';

  static const String densityCompact = 'compact';
  static const String densityStandard = 'standard';
  static const String densityComfortable = 'comfortable';

  const EnvironmentIntroStyle({
    this.displaySize = sizeStandard,
    this.fontSize = fontStandard,
    this.cardLayout = layoutHorizontal,
    this.cardDensity = densityStandard,
  });

  final String displaySize;
  final String fontSize;
  final String cardLayout;
  final String cardDensity;

  factory EnvironmentIntroStyle.fromMap(Map<String, dynamic>? map) {
    return EnvironmentIntroStyle(
      displaySize: _oneOf(map?['environmentDisplaySize'], const <String>[
        sizeCompact,
        sizeStandard,
        sizeLarge,
      ], sizeStandard),
      fontSize: _oneOf(map?['environmentFontSize'], const <String>[
        fontSmall,
        fontStandard,
        fontLarge,
      ], fontStandard),
      cardLayout: _oneOf(map?['environmentFeatureCardLayout'], const <String>[
        layoutHorizontal,
        layoutVertical,
        layoutText,
      ], layoutHorizontal),
      cardDensity: _oneOf(map?['environmentFeatureCardDensity'], const <String>[
        densityCompact,
        densityStandard,
        densityComfortable,
      ], densityStandard),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'environmentDisplaySize': displaySize,
      'environmentFontSize': fontSize,
      'environmentFeatureCardLayout': cardLayout,
      'environmentFeatureCardDensity': cardDensity,
    };
  }

  EnvironmentIntroStyle copyWith({
    String? displaySize,
    String? fontSize,
    String? cardLayout,
    String? cardDensity,
  }) {
    return EnvironmentIntroStyle(
      displaySize: displaySize ?? this.displaySize,
      fontSize: fontSize ?? this.fontSize,
      cardLayout: cardLayout ?? this.cardLayout,
      cardDensity: cardDensity ?? this.cardDensity,
    );
  }

  bool get isHorizontalCard => cardLayout == layoutHorizontal;
  bool get isVerticalCard => cardLayout == layoutVertical;
  bool get isTextCard => cardLayout == layoutText;

  double get pageTitleSize => _font(17, 20, 23);
  double get sectionTitleSize => _font(16, 18, 21);
  double get heroTitleSize => _font(20, 25, 28);
  double get heroSubtitleSize => _font(12, 14, 16);
  double get bannerTitleSize => _font(15, 20, 23);
  double get cardTitleSize => _font(14, 16, 18);
  double get cardDescriptionSize => _font(12, 12.5, 14.5);
  double get careTitleSize => _font(11.5, 13, 14.5);
  double get careDescriptionSize => _font(10, 11, 12.5);
  double get bottomNoteSize => _font(12.5, 14, 16);
  double get sectionIconSize => _font(18, 21, 24);
  double get featureIconSize => _font(18, 20, 22);
  double get careIconSize => _font(20, 23, 26);

  double get pagePadding => _size(12, 16, 20);
  double get sectionGap => _size(16, 22, 28);
  double get itemGap => _size(8, 12, 16);
  double get gallerySpacing => _size(6, 9, 12);
  double get careSpacing => _size(8, 10, 12);
  double get heroHeightScale => _size(0.92, 1.0, 1.08);
  double get bannerHeightScale => _size(0.92, 1.0, 1.08);
  double get heroRadius => _size(20, 24, 26);
  double get cardRadius => _size(16, 20, 22);

  double get featurePadding => _density(6, 8, 12);
  double get featurePaddingVertical => _density(6, 8, 12);
  double get featureMinHeight => _density(72, 92, 118);
  double get featureImageRadius => _density(10, 12, 14);
  double get featureTextGap => _density(3, 4, 6);
  double get featureImageMaxHeight => _density(68, 84, 104);
  double get horizontalFeatureIconSize => _density(15, 16, 18);
  double get verticalImageAspect => 16 / 10;
  double get horizontalImageFlex => 35;

  double get carePadding => _size(8, 10, 12);
  double get careAvatarRadius => _size(18, 21, 24);
  double get bottomNotePadding => _size(14, 18, 22);

  int galleryColumns(double width) {
    if (width >= 720) {
      return 3;
    }
    return 2;
  }

  int careColumns(double width) {
    final bool needRoom = displaySize == sizeLarge || fontSize == fontLarge;
    if (needRoom && width < 420) {
      return 2;
    }
    if (width < 330) {
      return 2;
    }
    return 3;
  }

  double _font(double small, double standard, double large) {
    switch (fontSize) {
      case fontSmall:
        return small;
      case fontLarge:
        return large;
      default:
        return standard;
    }
  }

  double _size(double compact, double standard, double large) {
    switch (displaySize) {
      case sizeCompact:
        return compact;
      case sizeLarge:
        return large;
      default:
        return standard;
    }
  }

  double _density(double compact, double standard, double comfortable) {
    switch (cardDensity) {
      case densityCompact:
        return compact;
      case densityComfortable:
        return comfortable;
      default:
        return standard;
    }
  }

  static String _oneOf(dynamic raw, List<String> allowed, String fallback) {
    final String text = (raw ?? '').toString().trim();
    if (allowed.contains(text)) {
      return text;
    }
    return fallback;
  }
}
