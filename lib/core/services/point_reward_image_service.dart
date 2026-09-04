// lib/core/services/point_reward_image_service.dart
// 🖼️ 點數兌換商品圖片 Service
// 功能：驗證並上傳實體商品圖片至 Firebase Storage，
// 限制圖片格式與檔案大小，並提供舊圖片刪除功能。

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PointRewardImageService {
  PointRewardImageService._();

  static final PointRewardImageService instance = PointRewardImageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 單張商品圖片最大 5 MB
  static const int maximumImageBytes = 5 * 1024 * 1024;

  /// 允許上傳的副檔名
  static const Set<String> allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// 選擇並驗證商品圖片。
  ///
  /// 使用者取消選擇時回傳 null。
  Future<XFile?> pickAndValidateImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? selectedImage = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (selectedImage == null) {
      return null;
    }

    await validateImage(selectedImage);

    return selectedImage;
  }

  /// 驗證圖片格式及檔案大小。
  Future<void> validateImage(XFile image) async {
    final String extension = _extractExtension(image.name);

    if (!allowedExtensions.contains(extension)) {
      throw const PointRewardImageException(
        '圖片格式不支援，請選擇 JPG、JPEG、PNG 或 WEBP 圖片',
      );
    }

    final int fileSize = await image.length();

    if (fileSize <= 0) {
      throw const PointRewardImageException('讀取圖片失敗，請重新選擇圖片');
    }

    if (fileSize > maximumImageBytes) {
      throw const PointRewardImageException('圖片大小不可超過 5 MB');
    }
  }

  /// 上傳點數兌換商品圖片。
  ///
  /// 圖片會儲存在：
  /// shops/{shopId}/point_rewards/{rewardId}/product_image.{副檔名}
  Future<String> uploadImage({
    required String shopId,
    required String rewardId,
    required XFile image,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();

    if (normalizedShopId.isEmpty) {
      throw const PointRewardImageException('缺少店家資料');
    }

    if (normalizedRewardId.isEmpty) {
      throw const PointRewardImageException('缺少商品資料');
    }

    await validateImage(image);

    final String extension = _extractExtension(image.name);
    final String contentType = _contentTypeFromExtension(extension);
    final Uint8List bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      throw const PointRewardImageException('讀取圖片失敗，請重新選擇圖片');
    }

    if (bytes.length > maximumImageBytes) {
      throw const PointRewardImageException('圖片大小不可超過 5 MB');
    }

    final Reference imageReference = _storage.ref().child(
      'shops/$normalizedShopId/'
      'point_rewards/$normalizedRewardId/'
      'product_image.$extension',
    );

    await imageReference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'shopId': normalizedShopId,
          'rewardId': normalizedRewardId,
          'imageType': 'point_reward_product',
        },
      ),
    );

    return imageReference.getDownloadURL();
  }

  Future<String> uploadBytes({
    required String shopId,
    required String rewardId,
    required Uint8List bytes,
    String fileExtension = 'jpg',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();
    if (normalizedShopId.isEmpty) {
      throw const PointRewardImageException('缺少店家資料');
    }
    if (normalizedRewardId.isEmpty) {
      throw const PointRewardImageException('缺少商品資料');
    }
    if (bytes.isEmpty) {
      throw const PointRewardImageException('讀取圖片失敗，請重新選擇圖片');
    }
    if (bytes.length > maximumImageBytes) {
      throw const PointRewardImageException('圖片大小不可超過 5 MB');
    }
    final String extension = fileExtension.trim().toLowerCase().isEmpty
        ? 'jpg'
        : fileExtension.trim().toLowerCase();
    final String contentType = _contentTypeFromExtension(extension);
    final Reference imageReference = _storage.ref().child(
      'shops/$normalizedShopId/'
      'point_rewards/$normalizedRewardId/'
      'product_image.$extension',
    );
    await imageReference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'shopId': normalizedShopId,
          'rewardId': normalizedRewardId,
          'imageType': 'point_reward_product',
        },
      ),
    );
    return imageReference.getDownloadURL();
  }

  /// 依照 Firebase Storage 下載網址刪除圖片。
  ///
  /// 空網址會直接略過。
  ///
  /// 圖片已不存在時也會視為刪除完成，
  /// 避免舊資料或重複操作造成整個商品流程失敗。
  Future<void> deleteImageByUrl(String imageUrl) async {
    final String normalizedImageUrl = imageUrl.trim();

    if (normalizedImageUrl.isEmpty) {
      return;
    }

    try {
      final Reference imageReference = _storage.refFromURL(normalizedImageUrl);

      await imageReference.delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }

      rethrow;
    }
  }

  /// 嘗試刪除圖片。
  ///
  /// 適合用於建立失敗或清理孤兒圖片，
  /// 即使刪除失敗也不會再次丟出錯誤。
  Future<void> tryDeleteImageByUrl(String imageUrl) async {
    try {
      await deleteImageByUrl(imageUrl);
    } catch (_) {
      // 清理失敗時不阻止原本流程繼續。
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

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        throw const PointRewardImageException('不支援的圖片格式');
    }
  }
}

/// 商品圖片操作錯誤。
class PointRewardImageException implements Exception {
  const PointRewardImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
