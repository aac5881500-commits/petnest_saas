// 檔案名稱：lib/core/services/store_banner_render_service.dart
// 功能說明：海報確認發布時合成成品 JPEG，首頁與商城共用。

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';

class StoreBannerRenderService {
  StoreBannerRenderService._();
  static final StoreBannerRenderService instance = StoreBannerRenderService._();

  static const int targetWidth = 1600;
  static const int targetHeight = 900;
  static const int jpegQuality = 86;

  /// 發布用畫布。同比例來源縮成 1600×900；比例不同時置中，不拉伸變形。
  static img.Image fitHomeCanvas(img.Image source) {
    if (source.width == targetWidth && source.height == targetHeight) {
      return source;
    }
    if (source.width <= 0 || source.height <= 0) {
      return img.Image(width: targetWidth, height: targetHeight);
    }
    final double sourceAspect = source.width / source.height;
    final double targetAspect = targetWidth / targetHeight;
    if ((sourceAspect - targetAspect).abs() <= 0.02) {
      return img.copyResize(
        source,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.average,
      );
    }
    final double scale = math.min(
      targetWidth / source.width,
      targetHeight / source.height,
    );
    final int fittedWidth = math.max(1, (source.width * scale).round());
    final int fittedHeight = math.max(1, (source.height * scale).round());
    final img.Image fitted = img.copyResize(
      source,
      width: fittedWidth,
      height: fittedHeight,
      interpolation: img.Interpolation.average,
    );
    final img.Image canvas = img.Image(
      width: targetWidth,
      height: targetHeight,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      fitted,
      dstX: ((targetWidth - fittedWidth) / 2).round(),
      dstY: ((targetHeight - fittedHeight) / 2).round(),
    );
    return canvas;
  }

  static void validateHomeJpeg(Uint8List jpeg) {
    if (jpeg.length < 800 ||
        jpeg.length < 2 ||
        jpeg[0] != 0xFF ||
        jpeg[1] != 0xD8) {
      throw const InventoryException('海報合成失敗，成品圖片無效');
    }
    final img.Image? decoded = img.decodeImage(jpeg);
    if (decoded == null ||
        decoded.width != targetWidth ||
        decoded.height != targetHeight) {
      throw const InventoryException('海報合成失敗，成品尺寸不是 1600×900');
    }
  }

  /// 等到圖片解碼完成。失敗就丟出錯誤，不用固定延遲假裝已經畫好。
  static Future<void> waitForEncodedImage(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  static Future<void> waitForImageProvider(ImageProvider provider) {
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    final Completer<void> done = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        stream.removeListener(listener);
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!done.isCompleted) {
          done.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    return done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        stream.removeListener(listener);
        throw const InventoryException('海報圖片載入逾時，請確認網路後再試');
      },
    );
  }

  Future<Uint8List> captureJpeg(
    GlobalKey key, {
    bool fixedHomeCanvas = false,
  }) async {
    final BuildContext? context = key.currentContext;
    final RenderObject? renderObject = context?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const InventoryException('海報預覽尚未準備好，請稍候再發布');
    }
    final ui.Image image = await renderObject.toImage(
      pixelRatio: fixedHomeCanvas ? 1 : 2,
    );
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (data == null) {
      throw const InventoryException('海報合成失敗，請重試');
    }
    final img.Image? decoded = img.decodeImage(data.buffer.asUint8List());
    if (decoded == null) {
      throw const InventoryException('海報合成失敗，請重試');
    }
    final img.Image resized = fixedHomeCanvas
        ? fitHomeCanvas(decoded)
        : (decoded.width > targetWidth
              ? img.copyResize(decoded, width: targetWidth)
              : decoded);
    int quality = jpegQuality;
    Uint8List jpeg = Uint8List.fromList(
      img.encodeJpg(resized, quality: quality),
    );
    while (jpeg.length > 700 * 1024 && quality > 70) {
      quality -= 4;
      jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    return jpeg;
  }

  Future<InventoryImageUploadResult> uploadRendered({
    required String shopId,
    required String bannerId,
    required Uint8List bytes,
    required int version,
    required PetNestBannerScope scope,
  }) {
    final String folder = scope == PetNestBannerScope.home
        ? 'home/banners'
        : 'store/banners';
    final String path =
        'shops/${shopId.trim()}/$folder/${bannerId.trim()}/rendered_v$version.jpg';
    return InventoryImageService.instance.uploadBytes(
      shopId: shopId,
      itemId: bannerId,
      bytes: bytes,
      folder: folder,
      imageType: 'banner_rendered',
      idMetadataKey: 'bannerId',
      storagePathOverride: path,
    );
  }
}

/// 讓合成畫布維持 1600×900，不被外層螢幕寬度壓扁後再拉伸。
class HomePosterCaptureFrame extends StatelessWidget {
  const HomePosterCaptureFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 1,
        height: 1,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: StoreBannerRenderService.targetWidth.toDouble(),
          maxWidth: StoreBannerRenderService.targetWidth.toDouble(),
          minHeight: StoreBannerRenderService.targetHeight.toDouble(),
          maxHeight: StoreBannerRenderService.targetHeight.toDouble(),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(1600, 900),
              textScaler: TextScaler.noScaling,
            ),
            child: SizedBox(
              width: StoreBannerRenderService.targetWidth.toDouble(),
              height: StoreBannerRenderService.targetHeight.toDouble(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
