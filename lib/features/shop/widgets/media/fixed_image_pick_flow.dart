// 檔案名稱：lib/features/shop/widgets/media/fixed_image_pick_flow.dart
// 功能說明：選圖 → 驗證 → 固定比例裁切。取消裁切時回傳 null，不上傳。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/features/shop/widgets/media/fixed_aspect_image_crop_page.dart';

class FixedImagePickFlow {
  FixedImagePickFlow._();

  static Future<Uint8List?> pickAndCrop({
    required BuildContext context,
    required FixedImageSpec spec,
    bool keepTransparency = false,
    String title = '選擇顯示範圍',
  }) async {
    final XFile? image = await InventoryImageService.instance
        .pickAndValidateImage();
    if (image == null) {
      return null;
    }
    final Uint8List originalBytes = await image.readAsBytes();
    if (originalBytes.isEmpty) {
      throw const InventoryException('讀取圖片失敗，請重新選擇圖片');
    }
    if (!context.mounted) {
      return null;
    }
    final bool png = image.name.toLowerCase().endsWith('.png');
    return FixedAspectImageCropPage.open(
      context: context,
      imageBytes: originalBytes,
      spec: spec,
      title: title,
      keepTransparency: keepTransparency && png,
    );
  }

  static Future<InventoryImageUploadResult?> pickCropAndUpload({
    required BuildContext context,
    required FixedImageSpec spec,
    required String shopId,
    required String itemId,
    required String folder,
    required String imageType,
    String idMetadataKey = 'bannerId',
    String title = '選擇顯示範圍',
  }) async {
    final Uint8List? bytes = await pickAndCrop(
      context: context,
      spec: spec,
      title: title,
    );
    if (bytes == null) {
      return null;
    }
    return InventoryImageService.instance.uploadBytes(
      shopId: shopId,
      itemId: itemId,
      bytes: bytes,
      folder: folder,
      imageType: imageType,
      idMetadataKey: idMetadataKey,
    );
  }
}
