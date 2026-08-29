// lib/core/models/modern_banner_frame_setting.dart
// 新版 Beta 首頁封面高度、圖片填滿方式與位置。
// 掛在 homeAppearance.modern，舊資料沒有欄位時使用標準／填滿／置中。

import 'package:flutter/material.dart';

class ModernBannerFrameSetting {
  static const String heightUltraCompact = 'ultraCompact';
  static const String heightCompact = 'compact';
  static const String heightStandard = 'standard';
  static const String heightLarge = 'large';

  static const String fitFill = 'cover';
  static const String fitContain = 'contain';

  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';

  const ModernBannerFrameSetting({
    this.heightPreset = heightStandard,
    this.imageFit = fitFill,
    this.imageAlignment = alignCenter,
  });

  final String heightPreset;
  final String imageFit;
  final String imageAlignment;

  factory ModernBannerFrameSetting.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ModernBannerFrameSetting();
    }

    return ModernBannerFrameSetting(
      heightPreset: _readHeightPreset(map['bannerHeightPreset']),
      imageFit: _readImageFit(map['bannerImageFit']),
      imageAlignment: _readImageAlignment(map['bannerImageAlignment']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bannerHeightPreset': heightPreset,
      'bannerImageFit': imageFit,
      'bannerImageAlignment': imageAlignment,
    };
  }

  bool get isUltraCompact => heightPreset == heightUltraCompact;

  bool get isCompact => heightPreset == heightCompact;

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

  /// 以約 390px 手機寬為基準：極簡 140、精簡 180、標準 220、大型 270。
  /// 較寬版面略為放大，並設上限避免桌面變成整屏大海報。
  double heightForWidth(double width) {
    final double base;
    switch (heightPreset) {
      case heightUltraCompact:
        base = 140;
      case heightCompact:
        base = 180;
      case heightLarge:
        base = 270;
      default:
        base = 220;
    }

    if (width <= 430) {
      return base;
    }

    final double scale = (width / 390).clamp(1.0, 1.35);
    return base * scale;
  }

  static String _readHeightPreset(dynamic value) {
    final String text = (value ?? '').toString().trim();
    if (text == heightUltraCompact ||
        text == heightCompact ||
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
