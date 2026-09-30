// 檔案名稱：lib/core/models/store_banner_placement.dart
// 功能說明：海報文字 / CTA 位置。以 16:9 畫布寬高的比例儲存，預覽與輸出同一套。

import 'dart:math' as math;

import 'package:flutter/material.dart';

class StoreBannerPlacement {
  /// 文字與按鈕離海報邊緣的安全比例。不用固定像素。
  static const double safeFraction = 0.05;

  static Offset offsetOf({
    required double positionX,
    required double positionY,
    required Size bannerSize,
    required Size elementSize,
  }) {
    return clampTopLeft(
      topLeft: Offset(
        positionX * bannerSize.width,
        positionY * bannerSize.height,
      ),
      bannerSize: bannerSize,
      elementSize: elementSize,
    );
  }

  static Offset normalize({
    required Offset actual,
    required Size bannerSize,
    required Size elementSize,
  }) {
    final Offset clamped = clampTopLeft(
      topLeft: actual,
      bannerSize: bannerSize,
      elementSize: elementSize,
    );
    if (bannerSize.width <= 0 || bannerSize.height <= 0) {
      return Offset.zero;
    }
    return Offset(
      clamped.dx / bannerSize.width,
      clamped.dy / bannerSize.height,
    );
  }

  /// [topLeft] 是元素左上角在畫布內的座標。會依整個元素的寬高停在安全區內。
  static Offset clampTopLeft({
    required Offset topLeft,
    required Size bannerSize,
    required Size elementSize,
  }) {
    final double marginX = bannerSize.width * safeFraction;
    final double marginY = bannerSize.height * safeFraction;
    final double maxX = math.max(
      marginX,
      bannerSize.width - marginX - math.max(0, elementSize.width),
    );
    final double maxY = math.max(
      marginY,
      bannerSize.height - marginY - math.max(0, elementSize.height),
    );
    return Offset(
      topLeft.dx.clamp(marginX, maxX),
      topLeft.dy.clamp(marginY, maxY),
    );
  }

  static Offset? fromLegacyPreset(dynamic raw) {
    final String value = (raw ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    switch (value) {
      case 'leftTop':
      case 'topLeft':
        return const Offset(0.08, 0.12);
      case 'centerTop':
      case 'topCenter':
        return const Offset(0.50, 0.12);
      case 'rightTop':
      case 'topRight':
        return const Offset(0.92, 0.12);
      case 'leftCenter':
      case 'centerLeft':
        return const Offset(0.08, 0.50);
      case 'center':
        return const Offset(0.50, 0.50);
      case 'rightCenter':
      case 'centerRight':
        return const Offset(0.92, 0.50);
      case 'leftBottom':
      case 'bottomLeft':
        return const Offset(0.08, 0.88);
      case 'centerBottom':
      case 'bottomCenter':
        return const Offset(0.50, 0.88);
      case 'rightBottom':
      case 'bottomRight':
        return const Offset(0.92, 0.88);
      default:
        return null;
    }
  }
}
