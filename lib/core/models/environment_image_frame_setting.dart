// lib/core/models/environment_image_frame_setting.dart
// 環境介紹首頁大圖 / 中間橫幅的高度、填滿方式與位置。
// 掛在 shops/{shopId}.environmentIntro，舊資料沒有欄位時使用標準／填滿／置中。

import 'package:flutter/material.dart';

enum EnvironmentImageSlot { hero, middleBanner }

class EnvironmentImageFrameSetting {
  static const String heightCompact = 'compact';
  static const String heightStandard = 'standard';
  static const String heightLarge = 'large';

  static const String fitFill = 'cover';
  static const String fitContain = 'contain';

  static const String alignTop = 'top';
  static const String alignCenter = 'center';
  static const String alignBottom = 'bottom';

  /// 約 390px 手機、扣除左右 16px 後卡片寬約 358px。
  /// 首頁大圖標準 260px → 358:260 ≈ 11:8。
  static const double heroCropAspectRatio = 11 / 8;
  static const int heroOutputWidth = 1760;
  static const int heroOutputHeight = 1280;

  /// 中間橫幅標準 150px → 358:150 ≈ 12:5。
  static const double bannerCropAspectRatio = 12 / 5;
  static const int bannerOutputWidth = 1680;
  static const int bannerOutputHeight = 700;

  const EnvironmentImageFrameSetting({
    required this.slot,
    this.heightPreset = heightStandard,
    this.imageFit = fitFill,
    this.imageAlignment = alignCenter,
  });

  final EnvironmentImageSlot slot;
  final String heightPreset;
  final String imageFit;
  final String imageAlignment;

  factory EnvironmentImageFrameSetting.heroFromMap(Map<String, dynamic>? map) {
    return EnvironmentImageFrameSetting(
      slot: EnvironmentImageSlot.hero,
      heightPreset: _readHeightPreset(map?['environmentHeroHeightPreset']),
      imageFit: _readImageFit(map?['environmentHeroImageFit']),
      imageAlignment: _readImageAlignment(map?['environmentHeroImageAlignment']),
    );
  }

  factory EnvironmentImageFrameSetting.bannerFromMap(
    Map<String, dynamic>? map,
  ) {
    return EnvironmentImageFrameSetting(
      slot: EnvironmentImageSlot.middleBanner,
      heightPreset: _readHeightPreset(
        map?['environmentMiddleBannerHeightPreset'],
      ),
      imageFit: _readImageFit(map?['environmentMiddleBannerImageFit']),
      imageAlignment: _readImageAlignment(
        map?['environmentMiddleBannerImageAlignment'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    if (slot == EnvironmentImageSlot.hero) {
      return <String, dynamic>{
        'environmentHeroHeightPreset': heightPreset,
        'environmentHeroImageFit': imageFit,
        'environmentHeroImageAlignment': imageAlignment,
      };
    }

    return <String, dynamic>{
      'environmentMiddleBannerHeightPreset': heightPreset,
      'environmentMiddleBannerImageFit': imageFit,
      'environmentMiddleBannerImageAlignment': imageAlignment,
    };
  }

  EnvironmentImageFrameSetting copyWith({
    String? heightPreset,
    String? imageFit,
    String? imageAlignment,
  }) {
    return EnvironmentImageFrameSetting(
      slot: slot,
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

  double get cropAspectRatio {
    return slot == EnvironmentImageSlot.hero
        ? heroCropAspectRatio
        : bannerCropAspectRatio;
  }

  int get outputWidth {
    return slot == EnvironmentImageSlot.hero
        ? heroOutputWidth
        : bannerOutputWidth;
  }

  int get outputHeight {
    return slot == EnvironmentImageSlot.hero
        ? heroOutputHeight
        : bannerOutputHeight;
  }

  /// 以約 390px 手機為基準。較寬版面略為放大，並設上限。
  double heightForWidth(double width) {
    final double base;
    if (slot == EnvironmentImageSlot.hero) {
      switch (heightPreset) {
        case heightCompact:
          base = 210;
        case heightLarge:
          base = 320;
        default:
          base = 260;
      }
    } else {
      switch (heightPreset) {
        case heightCompact:
          base = 120;
        case heightLarge:
          base = 190;
        default:
          base = 150;
      }
    }

    if (width <= 430) {
      return base;
    }

    final double scale = (width / 390).clamp(1.0, 1.35);
    return base * scale;
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
