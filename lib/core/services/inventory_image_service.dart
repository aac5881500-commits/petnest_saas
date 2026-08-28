// lib/core/services/inventory_image_service.dart
// 🖼️ 庫存品項代表圖 Service
// 功能：沿用專案既有 image_picker + flutter_image_compress + Firebase Storage。
// 原始檔超過 5MB 不上傳；上傳前壓縮為最長邊約 1400px 的 JPEG。

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';

class InventoryImageUploadResult {
  const InventoryImageUploadResult({
    required this.imageUrl,
    required this.imageStoragePath,
  });

  final String imageUrl;
  final String imageStoragePath;
}

class InventoryImageService {
  InventoryImageService._();

  static final InventoryImageService instance = InventoryImageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const Set<String> allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  Future<XFile?> pickAndValidateImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? selectedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (selectedImage == null) {
      return null;
    }

    await validateOriginalImage(selectedImage);
    return selectedImage;
  }

  Future<void> validateOriginalImage(XFile image) async {
    final String extension = _extractExtension(image.name);

    if (!allowedExtensions.contains(extension)) {
      throw const InventoryException('圖片格式不支援，請選擇 JPG、JPEG、PNG 或 WEBP 圖片');
    }

    final int fileSize = await image.length();

    if (fileSize <= 0) {
      throw const InventoryException('讀取圖片失敗，請重新選擇圖片');
    }

    if (fileSize > InventoryConstants.originalImageMaxBytes) {
      throw const InventoryException('圖片大小不可超過 5MB');
    }
  }

  String storagePath({
    required String shopId,
    required String itemId,
    String folder = InventoryConstants.imageFolder,
    String imageType = 'inventory_cover',
  }) {
    return 'shops/${shopId.trim()}/'
        '${folder.trim().isEmpty ? InventoryConstants.imageFolder : folder.trim()}/'
        '${itemId.trim()}/'
        '${InventoryConstants.coverFileName}';
  }

  Future<InventoryImageUploadResult> uploadImage({
    required String shopId,
    required String itemId,
    required XFile image,
    String folder = InventoryConstants.imageFolder,
    String imageType = 'inventory_cover',
    String idMetadataKey = 'inventoryItemId',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty) {
      throw const InventoryException('找不到店家資料');
    }

    if (normalizedItemId.isEmpty) {
      throw const InventoryException('找不到庫存品項');
    }

    await validateOriginalImage(image);

    final Uint8List originalBytes = await image.readAsBytes();

    if (originalBytes.isEmpty) {
      throw const InventoryException('讀取圖片失敗，請重新選擇圖片');
    }

    if (originalBytes.length > InventoryConstants.originalImageMaxBytes) {
      throw const InventoryException('圖片大小不可超過 5MB');
    }

    final Uint8List compressedBytes = await _compressCover(originalBytes);

    if (compressedBytes.length > InventoryConstants.originalImageMaxBytes) {
      throw const InventoryException('圖片大小不可超過 5MB');
    }

    final String path = storagePath(
      shopId: normalizedShopId,
      itemId: normalizedItemId,
      folder: folder,
    );
    final Reference imageReference = _storage.ref(path);

    await imageReference.putData(
      compressedBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'shopId': normalizedShopId,
          idMetadataKey: normalizedItemId,
          'imageType': imageType,
        },
      ),
    );

    return InventoryImageUploadResult(
      imageUrl: await imageReference.getDownloadURL(),
      imageStoragePath: path,
    );
  }

  Future<void> deleteImage({
    String imageUrl = '',
    String imageStoragePath = '',
  }) async {
    final String normalizedPath = imageStoragePath.trim();
    final String normalizedUrl = imageUrl.trim();

    try {
      if (normalizedPath.isNotEmpty) {
        await _storage.ref(normalizedPath).delete();
        return;
      }

      if (normalizedUrl.isEmpty) {
        return;
      }

      await _storage.refFromURL(normalizedUrl).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }

      throw InventoryException(InventoryException.userMessage(error));
    }
  }

  Future<void> tryDeleteImage({
    String imageUrl = '',
    String imageStoragePath = '',
  }) async {
    try {
      await deleteImage(
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
      );
    } catch (_) {
      // 清理舊圖失敗不影響主流程。
    }
  }

  Future<Uint8List> _compressCover(Uint8List originalBytes) async {
    try {
      final Uint8List result = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: InventoryConstants.coverMaxEdge,
        minHeight: InventoryConstants.coverMaxEdge,
        quality: InventoryConstants.coverJpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (result.isEmpty) {
        throw const InventoryException('圖片壓縮失敗，請改選其他圖片');
      }

      return result;
    } catch (error) {
      if (error is InventoryException) {
        rethrow;
      }

      throw const InventoryException('圖片壓縮失敗，請改選其他圖片');
    }
  }

  String _extractExtension(String fileName) {
    final String normalizedFileName = fileName.trim().toLowerCase();
    final int dotIndex = normalizedFileName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == normalizedFileName.length - 1) {
      return '';
    }

    return normalizedFileName.substring(dotIndex + 1);
  }
}
