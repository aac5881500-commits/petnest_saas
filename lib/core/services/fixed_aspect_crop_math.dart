// 檔案名稱：lib/core/services/fixed_aspect_crop_math.dart
// 功能說明：固定比例裁切：cover 縮放、拖曳夾限與輸出裁切框。不含 UI。

import 'dart:math' as math;
import 'dart:ui';

class ClampedCropTransform {
  const ClampedCropTransform({
    required this.scale,
    required this.tx,
    required this.ty,
  });

  final double scale;
  final double tx;
  final double ty;
}

class FixedAspectCropMath {
  FixedAspectCropMath._();

  static const double maxZoomMultiplier = 4;

  static double coverScale({required Size image, required Size viewport}) {
    if (image.width <= 0 ||
        image.height <= 0 ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return 1;
    }
    return math.max(
      viewport.width / image.width,
      viewport.height / image.height,
    );
  }

  static ClampedCropTransform initialCover({
    required Size image,
    required Size viewport,
  }) {
    final double scale = coverScale(image: image, viewport: viewport);
    final double dx = (viewport.width - image.width * scale) / 2;
    final double dy = (viewport.height - image.height * scale) / 2;
    return clampTransform(
      image: image,
      viewport: viewport,
      scale: scale,
      tx: dx,
      ty: dy,
    );
  }

  static ClampedCropTransform clampTransform({
    required Size image,
    required Size viewport,
    required double scale,
    required double tx,
    required double ty,
  }) {
    final double cover = coverScale(image: image, viewport: viewport);
    final double maxScale = cover * maxZoomMultiplier;
    final double nextScale = scale.clamp(cover, maxScale);
    double nextTx = tx;
    double nextTy = ty;
    if ((scale - nextScale).abs() > 0.0001 && scale != 0) {
      final double ratio = nextScale / scale;
      final Offset center = Offset(viewport.width / 2, viewport.height / 2);
      nextTx = center.dx - (center.dx - tx) * ratio;
      nextTy = center.dy - (center.dy - ty) * ratio;
    }
    final double scaledWidth = image.width * nextScale;
    final double scaledHeight = image.height * nextScale;
    final double minTx = math.min(0, viewport.width - scaledWidth);
    final double minTy = math.min(0, viewport.height - scaledHeight);
    nextTx = nextTx.clamp(minTx, 0);
    nextTy = nextTy.clamp(minTy, 0);
    return ClampedCropTransform(scale: nextScale, tx: nextTx, ty: nextTy);
  }

  static Rect cropRectInImage({
    required Size image,
    required Size viewport,
    required double scale,
    required double tx,
    required double ty,
  }) {
    final ClampedCropTransform clamped = clampTransform(
      image: image,
      viewport: viewport,
      scale: scale,
      tx: tx,
      ty: ty,
    );
    final double left = (-clamped.tx) / clamped.scale;
    final double top = (-clamped.ty) / clamped.scale;
    final double width = viewport.width / clamped.scale;
    final double height = viewport.height / clamped.scale;
    return Rect.fromLTWH(
      left.clamp(0, math.max(0, image.width - 1)),
      top.clamp(0, math.max(0, image.height - 1)),
      width.clamp(1, image.width),
      height.clamp(1, image.height),
    );
  }

  static bool imageCoversViewport({
    required Size image,
    required Size viewport,
    required double scale,
    required double tx,
    required double ty,
  }) {
    final ClampedCropTransform clamped = clampTransform(
      image: image,
      viewport: viewport,
      scale: scale,
      tx: tx,
      ty: ty,
    );
    const double epsilon = 0.5;
    return clamped.tx <= epsilon &&
        clamped.ty <= epsilon &&
        clamped.tx + image.width * clamped.scale >= viewport.width - epsilon &&
        clamped.ty + image.height * clamped.scale >= viewport.height - epsilon;
  }
}
