// 檔案名稱：lib/core/models/about_cover_frame_setting.dart
// 功能說明：關於我們封面圖的高度、填滿方式與位置。
// 掛在 shops/{shopId} 根欄位；舊資料沒有欄位時使用標準／填滿／置中。

import 'package:flutter/material.dart';

class AboutCoverFrameSetting {
  static const String fitFill = 'cover';
  static const String fitContain = 'contain';

  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';

  static const String heightCompact = 'compact';
  static const String heightStandard = 'standard';
  static const String heightLarge = 'large';

  /// 系統預設封面。只做 UI fallback，不寫入店家 Firestore / Storage。
  static const String defaultAssetPath =
      'assets/images/about_default_cover.jpg';

  /// 選擇顯示範圍仍以接近正方形輸出，高度切換靠容器 + 填滿／完整顯示。
  static const double cropAspectRatio = 1;
  static const int outputWidth = 1600;
  static const int outputHeight = 1600;

  const AboutCoverFrameSetting({
    this.heightPreset = heightStandard,
    this.imageFit = fitFill,
    this.imageAlignment = alignCenter,
  });

  final String heightPreset;
  final String imageFit;
  final String imageAlignment;

  factory AboutCoverFrameSetting.fromMap(Map<String, dynamic>? map) {
    return AboutCoverFrameSetting(
      heightPreset: _readHeightPreset(map?['aboutCoverHeightPreset']),
      imageFit: _readImageFit(map?['aboutImageFit']),
      imageAlignment: _readImageAlignment(map?['aboutImageAlignment']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'aboutCoverHeightPreset': heightPreset,
      'aboutImageFit': imageFit,
      'aboutImageAlignment': imageAlignment,
    };
  }

  AboutCoverFrameSetting copyWith({
    String? heightPreset,
    String? imageFit,
    String? imageAlignment,
  }) {
    return AboutCoverFrameSetting(
      heightPreset: heightPreset ?? this.heightPreset,
      imageFit: imageFit ?? this.imageFit,
      imageAlignment: imageAlignment ?? this.imageAlignment,
    );
  }

  bool get usesCoverFit => imageFit != fitContain;

  BoxFit get boxFit {
    return usesCoverFit ? BoxFit.cover : BoxFit.contain;
  }

  Alignment get alignment {
    if (!usesCoverFit) {
      return Alignment.center;
    }

    switch (imageAlignment) {
      case alignTop:
        return Alignment.topCenter;
      case alignBottom:
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }

  /// 手機 360–430：精簡 220／標準 300／大型 380。
  /// 較寬桌面略放大，並設 maxHeight，避免超高。
  double heightForWidth(double width) {
    final double base;
    final double maxHeight;
    switch (heightPreset) {
      case heightCompact:
        base = 220;
        maxHeight = 260;
      case heightLarge:
        base = 380;
        maxHeight = 440;
      default:
        base = 300;
        maxHeight = 360;
    }

    if (width <= 430) {
      return base;
    }

    final double scale = (width / 390).clamp(1.0, 1.2);
    return (base * scale).clamp(base, maxHeight);
  }

  static String _readHeightPreset(dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text == heightCompact ||
        text == heightLarge ||
        text == heightStandard) {
      return text;
    }
    return heightStandard;
  }

  static String _readImageFit(dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text == fitContain || text == fitFill) {
      return text;
    }
    return fitFill;
  }

  static String _readImageAlignment(dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text == alignTop || text == alignBottom || text == alignCenter) {
      return text;
    }
    return alignCenter;
  }
}
