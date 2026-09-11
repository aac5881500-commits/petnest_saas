// 檔案名稱：lib/core/models/store_banner_content.dart
// 功能說明：海報內容來源與 16:9 安全套版比例（前後台同一套，不存 px）

class StoreBannerContentModes {
  static const String imageOnly = 'image_only';
  static const String templateOverlay = 'template_overlay';
  static const List<String> all = <String>[imageOnly, templateOverlay];

  static String label(String value) {
    switch (value) {
      case templateOverlay:
        return '後台套版渲染';
      default:
        return '自行上傳完成海報';
    }
  }

  static String infer({required String stored, required bool hasTextOrCta}) {
    if (stored == imageOnly || stored == templateOverlay) {
      return stored;
    }
    return hasTextOrCta ? templateOverlay : imageOnly;
  }
}

class StoreBannerAlignX {
  static const String left = 'left';
  static const String center = 'center';
  static const String right = 'right';
  static const List<String> all = <String>[left, center, right];

  static String label(String value) {
    switch (value) {
      case center:
        return '中';
      case right:
        return '右';
      default:
        return '左';
    }
  }

  static String overlayModeFor(String value) {
    switch (value) {
      case right:
        return 'right';
      case center:
        return 'bottom';
      default:
        return 'left';
    }
  }
}

class StoreBannerAlignY {
  static const String top = 'top';
  static const String center = 'center';
  static const String bottom = 'bottom';
  static const List<String> all = <String>[top, center, bottom];

  static String label(String value) {
    switch (value) {
      case center:
        return '中';
      case bottom:
        return '下';
      default:
        return '上';
    }
  }
}

class StoreBannerFontScale {
  static const String small = 'small';
  static const String medium = 'medium';
  static const String large = 'large';
  static const List<String> all = <String>[small, medium, large];

  static String label(String value) {
    switch (value) {
      case small:
        return '小';
      case large:
        return '大';
      default:
        return '中';
    }
  }
}

class StoreBannerSafeLayout {
  static const double aspectRatio = 16 / 9;
  static const double insetX = 0.11;
  static const double insetY = 0.10;
  static const int titleMaxLines = 2;
  static const int subtitleMaxLines = 2;
  static const int ctaMaxLines = 1;
  static const int titleMaxChars = 28;
  static const int subtitleMaxChars = 40;
  static const int ctaMaxChars = 12;

  static double titleHeightRatio(String scale) {
    switch (scale) {
      case StoreBannerFontScale.small:
        return 0.078;
      case StoreBannerFontScale.large:
        return 0.125;
      default:
        return 0.100;
    }
  }

  static double subtitleHeightRatio(String scale) {
    switch (scale) {
      case StoreBannerFontScale.small:
        return 0.042;
      case StoreBannerFontScale.large:
        return 0.062;
      default:
        return 0.052;
    }
  }

  static double ctaHeightRatio(String scale) {
    switch (scale) {
      case StoreBannerFontScale.small:
        return 0.036;
      case StoreBannerFontScale.large:
        return 0.052;
      default:
        return 0.044;
    }
  }
}
