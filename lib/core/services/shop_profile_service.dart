// 檔案名稱：lib/core/services/shop_profile_service.dart
// 功能說明：管理店家資料、營業資訊、Logo / Cover 圖片
// 🏪 店家基本資料 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ShopProfileService {
  ShopProfileService._();

  static final instance = ShopProfileService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  Future<void> deleteImageByUrl(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('刪除圖片失敗: $e');
    }
  }

  Future<void> updateShop({
    required String shopId,
    required Map<String, dynamic> data,
  }) async {
    await _shops.doc(shopId).update(data);
  }

  Future<Map<String, dynamic>?> getShop(String shopId) async {
    final doc = await _shops.doc(shopId).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};

    return {'shopId': doc.id, ...data};
  }

  Stream<Map<String, dynamic>?> streamShop(String shopId) {
    return _shops.doc(shopId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {'shopId': doc.id, ...doc.data()!};
    });
  }

  Future<void> updateShopBasicInfo({
    required String shopId,
    required String name,
    String businessType = 'cat',
    String phone = '',
    String address = '',
    String description = '',
    String city = '',
    String district = '',
    String lineUrl = '',
    String igUrl = '',
    String fbUrl = '',
    String businessHours = '',
    String licenseNumber = '',
    String taxId = '',
    bool showTaxId = true,
  }) async {
    await _shops.doc(shopId).update({
      'name': name.trim(),
      'businessType': businessType,
      'phone': phone.trim(),
      'address': address.trim(),
      'description': description.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'lineUrl': lineUrl.trim(),
      'igUrl': igUrl.trim(),
      'fbUrl': fbUrl.trim(),
      'businessHours': businessHours.trim(),
      'licenseNumber': licenseNumber.trim(),
      'taxId': taxId.trim(),
      'showTaxId': showTaxId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBusinessInfo({
    required String shopId,
    required bool isOpen,
    String businessHours = '',
    String openTime = '',
    String closeTime = '',
    List<String> closedDays = const [],
    List<String> serviceTypes = const [],
    bool isPublic = false,
  }) async {
    await _shops.doc(shopId).update({
      'isOpen': isOpen,
      'businessHours': businessHours,
      'openTime': openTime,
      'closeTime': closeTime,
      'closedDays': closedDays,
      'serviceTypes': serviceTypes,
      'isPublic': isPublic,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadShopLogo({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('shops/$shopId/logo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    final url = await ref.getDownloadURL();

    await _shops.doc(shopId).update({
      'logoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return url;
  }

  Future<String> uploadShopCover({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = _storage.ref().child('shops/$shopId/$fileName');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return await ref.getDownloadURL();
  }

  Future<ShopBannerImageUpload> uploadShopBannerImage({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String fileName =
        'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'shops/$normalizedShopId/$fileName';
    final Reference ref = _storage.ref().child(storagePath);

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return ShopBannerImageUpload(
      imageUrl: await ref.getDownloadURL(),
      imageStoragePath: storagePath,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentIntroImage({
    required String shopId,
    required String slot,
    required Uint8List bytes,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String prefix = slot == 'banner' ? 'banner' : 'hero';
    final String fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'shops/$normalizedShopId/environment/$fileName';
    final Reference ref = _storage.ref().child(storagePath);

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return ShopEnvironmentIntroImageUpload(
      imageUrl: await ref.getDownloadURL(),
      imageStoragePath: storagePath,
    );
  }

  /// 只刪除屬於該店家環境介紹首頁大圖 / 中間橫幅的 Storage 檔。
  /// 找不到檔案視為已清理成功。無法安全判斷時不刪。
  Future<bool> tryDeleteEnvironmentIntroImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String? path = _safeEnvironmentIntroStoragePath(
      shopId: normalizedShopId,
      storagePath: imageStoragePath,
      imageUrl: imageUrl,
    );

    if (path == null) {
      return true;
    }

    try {
      await _storage.ref(path).delete();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return true;
      }

      debugPrint(
        'Environment intro image cleanup failed: shopId=$normalizedShopId '
        'path=$path code=${error.code}',
      );
      return false;
    } catch (error) {
      debugPrint(
        'Environment intro image cleanup failed: shopId=$normalizedShopId '
        'path=$path error=$error',
      );
      return false;
    }
  }

  String? _safeEnvironmentIntroStoragePath({
    required String shopId,
    required String storagePath,
    required String imageUrl,
  }) {
    final String normalizedPath = storagePath.trim();
    if (_isOwnedEnvironmentIntroPath(shopId: shopId, path: normalizedPath)) {
      return normalizedPath;
    }

    final String normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'gs') {
      final String gsPath = uri.path.replaceFirst(RegExp(r'^/'), '');
      return _isOwnedEnvironmentIntroPath(shopId: shopId, path: gsPath)
          ? gsPath
          : null;
    }

    final bool isFirebaseHost =
        uri.host.contains('firebasestorage.googleapis.com') ||
        uri.host.contains('storage.googleapis.com');
    if (!isFirebaseHost) {
      return null;
    }

    final String rawPath = uri.path;
    final int objectMarker = rawPath.indexOf('/o/');
    if (objectMarker < 0) {
      return null;
    }

    final String encoded = rawPath.substring(objectMarker + 3);
    final String decoded = Uri.decodeComponent(encoded.split('?').first);
    return _isOwnedEnvironmentIntroPath(shopId: shopId, path: decoded)
        ? decoded
        : null;
  }

  bool _isOwnedEnvironmentIntroPath({
    required String shopId,
    required String path,
  }) {
    if (shopId.isEmpty || path.isEmpty) {
      return false;
    }

    if (path.contains('..') || path.contains('//')) {
      return false;
    }

    final String prefix = 'shops/$shopId/environment/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final String fileName = path.substring(prefix.length);
    if (fileName.contains('/')) {
      return false;
    }

    return fileName == 'hero.jpg' ||
        fileName == 'banner.jpg' ||
        RegExp(r'^hero_\d+\.jpg$').hasMatch(fileName) ||
        RegExp(r'^banner_\d+\.jpg$').hasMatch(fileName);
  }

  /// 只刪除屬於該店家活動海報的 Storage 檔。找不到檔案視為已清理成功。
  Future<bool> tryDeleteShopBannerImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String? path = _safeBannerStoragePath(
      shopId: normalizedShopId,
      storagePath: imageStoragePath,
      imageUrl: imageUrl,
    );

    if (path == null) {
      return true;
    }

    try {
      await _storage.ref(path).delete();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return true;
      }

      debugPrint(
        'Shop banner image cleanup failed: shopId=$normalizedShopId '
        'path=$path code=${error.code}',
      );
      return false;
    } catch (error) {
      debugPrint(
        'Shop banner image cleanup failed: shopId=$normalizedShopId '
        'path=$path error=$error',
      );
      return false;
    }
  }

  String? _safeBannerStoragePath({
    required String shopId,
    required String storagePath,
    required String imageUrl,
  }) {
    final String normalizedPath = storagePath.trim();
    if (_isOwnedBannerPath(shopId: shopId, path: normalizedPath)) {
      return normalizedPath;
    }

    final String normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    final Uri? uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'gs') {
      final String gsPath = uri.path.replaceFirst(RegExp(r'^/'), '');
      return _isOwnedBannerPath(shopId: shopId, path: gsPath) ? gsPath : null;
    }

    final bool isFirebaseHost =
        uri.host.contains('firebasestorage.googleapis.com') ||
        uri.host.contains('storage.googleapis.com');
    if (!isFirebaseHost) {
      return null;
    }

    final String rawPath = uri.path;
    final int objectMarker = rawPath.indexOf('/o/');
    if (objectMarker < 0) {
      return null;
    }

    final String encoded = rawPath.substring(objectMarker + 3);
    final String decoded = Uri.decodeComponent(encoded);
    return _isOwnedBannerPath(shopId: shopId, path: decoded) ? decoded : null;
  }

  bool _isOwnedBannerPath({required String shopId, required String path}) {
    if (shopId.isEmpty || path.isEmpty) {
      return false;
    }

    if (path.contains('..') || path.contains('//')) {
      return false;
    }

    final String prefix = 'shops/$shopId/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final String fileName = path.substring(prefix.length);
    if (fileName.startsWith('banner_') && !fileName.contains('/')) {
      return true;
    }
    return fileName.startsWith('home/banners/');
  }

  Uint8List? compressEnvironmentImageBytes({
    required Uint8List bytes,
    required int maxSide,
    int quality = 85,
  }) {
    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }

      decoded = img.bakeOrientation(decoded);
      if (decoded.width <= 0 || decoded.height <= 0) {
        return null;
      }

      if (decoded.width > maxSide || decoded.height > maxSide) {
        if (decoded.width >= decoded.height) {
          decoded = img.copyResize(decoded, width: maxSide);
        } else {
          decoded = img.copyResize(decoded, height: maxSide);
        }
      }

      return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    } catch (_) {
      return null;
    }
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentGalleryImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return _uploadEnvironmentNamedImage(
      shopId: shopId,
      folderAndPrefix: 'gallery/gallery',
      bytes: bytes,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> uploadEnvironmentFeatureImage({
    required String shopId,
    required Uint8List bytes,
  }) {
    return _uploadEnvironmentNamedImage(
      shopId: shopId,
      folderAndPrefix: 'features/feature',
      bytes: bytes,
    );
  }

  Future<ShopEnvironmentIntroImageUpload> _uploadEnvironmentNamedImage({
    required String shopId,
    required String folderAndPrefix,
    required Uint8List bytes,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String fileName =
        '${folderAndPrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'shops/$normalizedShopId/environment/$fileName';
    final Reference ref = _storage.ref().child(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ShopEnvironmentIntroImageUpload(
      imageUrl: await ref.getDownloadURL(),
      imageStoragePath: storagePath,
    );
  }

  Future<bool> tryDeleteEnvironmentGalleryImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return _tryDeleteOwnedEnvironmentImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
      isOwned: _isOwnedEnvironmentGalleryPath,
      label: 'gallery',
    );
  }

  Future<bool> tryDeleteEnvironmentFeatureImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) {
    return _tryDeleteOwnedEnvironmentImage(
      shopId: shopId,
      imageStoragePath: imageStoragePath,
      imageUrl: imageUrl,
      isOwned: _isOwnedEnvironmentFeaturePath,
      label: 'feature',
    );
  }

  Future<bool> _tryDeleteOwnedEnvironmentImage({
    required String shopId,
    required String imageStoragePath,
    required String imageUrl,
    required bool Function({required String shopId, required String path})
    isOwned,
    required String label,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String? path = _safeOwnedEnvironmentPath(
      shopId: normalizedShopId,
      storagePath: imageStoragePath,
      imageUrl: imageUrl,
      isOwned: isOwned,
    );

    if (path == null) {
      return true;
    }

    try {
      await _storage.ref(path).delete();
      return true;
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return true;
      }
      debugPrint(
        'Environment $label image cleanup failed: shopId=$normalizedShopId '
        'path=$path code=${error.code}',
      );
      return false;
    } catch (error) {
      debugPrint(
        'Environment $label image cleanup failed: shopId=$normalizedShopId '
        'path=$path error=$error',
      );
      return false;
    }
  }

  String? _safeOwnedEnvironmentPath({
    required String shopId,
    required String storagePath,
    required String imageUrl,
    required bool Function({required String shopId, required String path})
    isOwned,
  }) {
    final String normalizedPath = storagePath.trim();
    if (isOwned(shopId: shopId, path: normalizedPath)) {
      return normalizedPath;
    }

    final String decoded = _decodeFirebaseObjectPath(imageUrl.trim());
    if (decoded.isEmpty) {
      return null;
    }
    return isOwned(shopId: shopId, path: decoded) ? decoded : null;
  }

  String _decodeFirebaseObjectPath(String imageUrl) {
    if (imageUrl.isEmpty) {
      return '';
    }

    final Uri? uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return '';
    }

    if (uri.scheme == 'gs') {
      return uri.path.replaceFirst(RegExp(r'^/'), '');
    }

    final bool isFirebaseHost =
        uri.host.contains('firebasestorage.googleapis.com') ||
        uri.host.contains('storage.googleapis.com');
    if (!isFirebaseHost) {
      return '';
    }

    final String rawPath = uri.path;
    final int objectMarker = rawPath.indexOf('/o/');
    if (objectMarker < 0) {
      return '';
    }

    final String encoded = rawPath.substring(objectMarker + 3);
    return Uri.decodeComponent(encoded.split('?').first);
  }

  bool _isOwnedEnvironmentGalleryPath({
    required String shopId,
    required String path,
  }) {
    if (!_isSafeShopEnvironmentPath(shopId: shopId, path: path)) {
      return false;
    }

    final String relative = path.substring('shops/$shopId/environment/'.length);
    return RegExp(r'^gallery_\d+\.jpg$').hasMatch(relative) ||
        RegExp(r'^gallery/gallery_\d+\.jpg$').hasMatch(relative);
  }

  bool _isOwnedEnvironmentFeaturePath({
    required String shopId,
    required String path,
  }) {
    if (!_isSafeShopEnvironmentPath(shopId: shopId, path: path)) {
      return false;
    }

    final String relative = path.substring('shops/$shopId/environment/'.length);
    return RegExp(r'^features/feature_\d+\.jpg$').hasMatch(relative);
  }

  bool _isSafeShopEnvironmentPath({
    required String shopId,
    required String path,
  }) {
    if (shopId.isEmpty || path.isEmpty) {
      return false;
    }
    if (path.contains('..') || path.contains('//')) {
      return false;
    }
    return path.startsWith('shops/$shopId/environment/');
  }

  Future<ShopAboutCoverImageUpload> uploadAboutCoverImage({
    required String shopId,
    required Uint8List bytes,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String fileName =
        'about_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'shops/$normalizedShopId/about/$fileName';
    final Reference ref = _storage.ref().child(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ShopAboutCoverImageUpload(
      imageUrl: await ref.getDownloadURL(),
      imageStoragePath: storagePath,
    );
  }

  /// 只刪除屬於該店家「關於我們封面」的 Storage 檔。
  /// 找不到檔案視為已清理成功。無法安全判斷時不刪。
  Future<bool> tryDeleteAboutCoverImage({
    required String shopId,
    String imageStoragePath = '',
    String imageUrl = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String? path = _safeOwnedEnvironmentPath(
      shopId: normalizedShopId,
      storagePath: imageStoragePath,
      imageUrl: imageUrl,
      isOwned: _isOwnedAboutCoverPath,
    );

    if (path == null) {
      if (imageStoragePath.trim().isNotEmpty || imageUrl.trim().isNotEmpty) {
        debugPrint(
          '舊圖片缺少安全 Storage path，略過實體檔案刪除。 '
          'shopId=$normalizedShopId path=${imageStoragePath.trim()} '
          'url=${imageUrl.trim()}',
        );
      }
      return true;
    }

    return _tryDeleteOwnedEnvironmentImage(
      shopId: normalizedShopId,
      imageStoragePath: path,
      imageUrl: '',
      isOwned: _isOwnedAboutCoverPath,
      label: 'about-cover',
    );
  }

  bool _isOwnedAboutCoverPath({required String shopId, required String path}) {
    if (shopId.isEmpty || path.isEmpty) {
      return false;
    }
    if (path.contains('..') || path.contains('//')) {
      return false;
    }

    final String prefix = 'shops/$shopId/about/';
    if (!path.startsWith(prefix)) {
      return false;
    }

    final String relative = path.substring(prefix.length);
    return RegExp(r'^about_cover_\d+\.jpg$').hasMatch(relative);
  }
}

class ShopBannerImageUpload {
  const ShopBannerImageUpload({
    required this.imageUrl,
    required this.imageStoragePath,
  });

  final String imageUrl;
  final String imageStoragePath;
}

class ShopEnvironmentIntroImageUpload {
  const ShopEnvironmentIntroImageUpload({
    required this.imageUrl,
    required this.imageStoragePath,
  });

  final String imageUrl;
  final String imageStoragePath;
}

class ShopAboutCoverImageUpload {
  const ShopAboutCoverImageUpload({
    required this.imageUrl,
    required this.imageStoragePath,
  });

  final String imageUrl;
  final String imageStoragePath;
}
