// 檔案名稱：lib/core/services/store_banner_render_service.dart
// 功能說明：海報確認發布時合成成品 JPEG，首頁與商城共用。

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

  /// 發布用畫布。不論來源尺寸，成品都是 1600 × 900。
  static img.Image fitHomeCanvas(img.Image source) {
    if (source.width == targetWidth && source.height == targetHeight) {
      return source;
    }
    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
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
