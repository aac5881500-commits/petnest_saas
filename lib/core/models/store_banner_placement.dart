// lib/core/models/store_banner_placement.dart
// 🛒 海報文字 / CTA 共用位置換算。Preview 與前台必須走同一套。

import 'package:flutter/material.dart';

class StoreBannerPlacement {
  static const double padX = 16;
  static const double padY = 12;

  static Offset offsetOf({
    required double positionX,
    required double positionY,
    required Size bannerSize,
    required Size elementSize,
  }) {
    final double availableX = _available(
      bannerSize.width,
      elementSize.width,
      padX,
    );
    final double availableY = _available(
      bannerSize.height,
      elementSize.height,
      padY,
    );
    return Offset(
      padX + positionX.clamp(0.0, 1.0) * availableX,
      padY + positionY.clamp(0.0, 1.0) * availableY,
    );
  }

  static Offset normalize({
    required Offset actual,
    required Size bannerSize,
    required Size elementSize,
  }) {
    final double availableX = _available(
      bannerSize.width,
      elementSize.width,
      padX,
    );
    final double availableY = _available(
      bannerSize.height,
      elementSize.height,
      padY,
    );
    return Offset(
      availableX <= 0 ? 0 : ((actual.dx - padX) / availableX).clamp(0.0, 1.0),
      availableY <= 0 ? 0 : ((actual.dy - padY) / availableY).clamp(0.0, 1.0),
    );
  }

  static Offset clampActual({
    required Offset actual,
    required Size bannerSize,
    required Size elementSize,
  }) {
    final double maxX = (bannerSize.width - padX - elementSize.width).clamp(
      padX,
      bannerSize.width,
    );
    final double maxY = (bannerSize.height - padY - elementSize.height).clamp(
      padY,
      bannerSize.height,
    );
    return Offset(actual.dx.clamp(padX, maxX), actual.dy.clamp(padY, maxY));
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

  static double _available(double banner, double element, double pad) {
    return (banner - element - pad * 2).clamp(0.0, banner);
  }
}
