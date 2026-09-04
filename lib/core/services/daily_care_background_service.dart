// lib/core/services/daily_care_background_service.dart
// 🖼️ 每日照護日誌背景圖片
// 功能：上傳／刪除店家日誌背景，路徑固定在
// shops/{shopId}/daily_care/settings/background/
// 新圖上傳並寫入 Firestore 成功後，才刪舊檔。

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class DailyCareBackgroundUpload {
  const DailyCareBackgroundUpload({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class DailyCareBackgroundService {
  DailyCareBackgroundService._();

  static final DailyCareBackgroundService instance =
      DailyCareBackgroundService._();

  static const int maxImageBytes = 5 * 1024 * 1024;
  static const String folderPath = 'daily_care/settings/background';
  static const String cardFolderPath = 'daily_care/settings/card_backgrounds';

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<DailyCareBackgroundUpload> uploadBytes({
    required String shopId,
    required Uint8List bytes,
    required String contentType,
    String folder = folderPath,
    String filePrefix = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      throw Exception('缺少店家 ID');
    }
    if (bytes.isEmpty) {
      throw Exception('圖片處理失敗，請重新選擇圖片。');
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      throw Exception('背景圖片不可超過 5 MB，請換一張較小的圖片。');
    }

    final String normalizedType = _normalizeContentType(contentType);
    final String extension = _extensionFor(normalizedType);
    final String prefix = filePrefix.trim();
    final String storagePath =
        'shops/$normalizedShopId/$folder/'
        '$prefix${DateTime.now().millisecondsSinceEpoch}.$extension';

    final Reference ref = _storage.ref().child(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: normalizedType));
    final String downloadUrl = await ref.getDownloadURL();

    return DailyCareBackgroundUpload(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
    );
  }

  Future<void> deleteStoredFile({
    String storagePath = '',
    String downloadUrl = '',
  }) async {
    final String path = storagePath.trim();
    final String url = downloadUrl.trim();

    try {
      if (path.isNotEmpty) {
        await _storage.ref().child(path).delete();
        return;
      }
      if (url.isNotEmpty) {
        await _storage.refFromURL(url).delete();
      }
    } catch (error, stackTrace) {
      debugPrint('刪除每日照護背景圖片失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static String _normalizeContentType(String contentType) {
    final String type = contentType.trim().toLowerCase();
    if (type == 'image/png' || type == 'image/webp' || type == 'image/jpeg') {
      return type;
    }
    if (type == 'image/jpg') {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  static String _extensionFor(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
