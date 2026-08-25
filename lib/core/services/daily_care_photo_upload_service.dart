// lib/core/services/daily_care_photo_upload_service.dart
// 📷 每日照護照片上傳 Service
// 功能：將員工選擇的照片壓縮成預覽版與下載版，
// 上傳 Firebase Storage，並建立 Firestore 照片紀錄。
// 不保存手機原始超大照片。

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'daily_care_photo_service.dart';

class DailyCarePhotoUploadService {
  DailyCarePhotoUploadService._();

  static final DailyCarePhotoUploadService instance =
      DailyCarePhotoUploadService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 前台平常瀏覽使用。
  ///
  /// 目標：
  /// - 最長邊約 600 px
  /// - JPEG 70%
  /// - 優先省流量與載入速度
  static const int previewMaxSize = 600;
  static const int previewQuality = 70;

  /// 退房後下載使用。
  ///
  /// 不保存手機原始大圖，
  /// 最大約 2000 px，JPEG 82%。
  /// 手機看與一般分享已足夠清楚。
  static const int downloadMaxSize = 2000;
  static const int downloadQuality = 82;

  Future<void> uploadPhoto({
    required Uint8List originalBytes,
    required String shopId,
    required String bookingId,
    required String roomId,
    required String roomName,
    required DateTime recordDate,
    required int sessionIndex,
    required String sessionName,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();
    final String normalizedRoomId = roomId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedBookingId.isEmpty) {
      throw ArgumentError('缺少訂單 ID');
    }

    if (normalizedRoomId.isEmpty) {
      throw ArgumentError('缺少房間 ID');
    }

    if (originalBytes.isEmpty) {
      throw ArgumentError('照片資料為空');
    }

    debugPrint(
      '🔎 UploadService 準備檢查照片數量：'
      'shopId=$normalizedShopId, '
      'bookingId=$normalizedBookingId, '
      'roomId=$normalizedRoomId',
    );

    final bool allowed = await DailyCarePhotoService.instance.canUploadPhoto(
      shopId: normalizedShopId,
      bookingId: normalizedBookingId,
      roomId: normalizedRoomId,
      recordDate: recordDate,
    );

    debugPrint('✅ UploadService 照片數量檢查成功：allowed=$allowed');

    if (!allowed) {
      throw StateError(
        '此房今日照片已達上限 '
        '${DailyCarePhotoService.maxPhotosPerRoomPerDay} 張',
      );
    }

    final Uint8List previewBytes = await _compressImage(
      originalBytes: originalBytes,
      maxSize: previewMaxSize,
      quality: previewQuality,
    );

    final Uint8List downloadBytes = await _compressImage(
      originalBytes: originalBytes,
      maxSize: downloadMaxSize,
      quality: downloadQuality,
    );

    final String dateKey =
        '${recordDate.year.toString().padLeft(4, '0')}'
        '${recordDate.month.toString().padLeft(2, '0')}'
        '${recordDate.day.toString().padLeft(2, '0')}';

    final String photoId = '${DateTime.now().microsecondsSinceEpoch}';

    final String basePath =
        'daily_care_photos/'
        '$normalizedShopId/'
        '$normalizedBookingId/'
        '$normalizedRoomId/'
        '$dateKey/'
        '$sessionIndex/'
        '$photoId';

    final String previewStoragePath = '$basePath/preview.jpg';

    final String downloadStoragePath = '$basePath/download.jpg';

    String? uploadedPreviewPath;
    String? uploadedDownloadPath;

    try {
      debugPrint('📤 準備上傳 Preview：$previewStoragePath');

      final Reference previewRef = _storage.ref(previewStoragePath);

      await previewRef.putData(
        previewBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        ),
      );

      uploadedPreviewPath = previewStoragePath;

      debugPrint('✅ Preview 上傳成功：$previewStoragePath');

      // Preview 目前前台直接顯示，
      // 所以仍保留 previewUrl。
      final String previewUrl = await previewRef.getDownloadURL();

      debugPrint('📤 準備上傳 Download：$downloadStoragePath');

      final Reference downloadRef = _storage.ref(downloadStoragePath);

      await downloadRef.putData(
        downloadBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=31536000',
        ),
      );

      uploadedDownloadPath = downloadStoragePath;

      debugPrint('✅ Download 上傳成功：$downloadStoragePath');

      // 高清照片不取得永久 downloadUrl。
      // 退房下載時會使用 downloadStoragePath
      // 透過 Firebase Storage SDK 存取，
      // 讓 Storage Rules 即時驗證權限。

      final User? user = FirebaseAuth.instance.currentUser;

      final String? uploadedByName =
          user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : user?.email?.trim();

      debugPrint(
        '📝 準備建立 Firestore 照片紀錄：'
        'photoId=$photoId',
      );

      await DailyCarePhotoService.instance.createPhotoRecord(
        shopId: normalizedShopId,
        bookingId: normalizedBookingId,
        photoId: photoId,
        roomId: normalizedRoomId,
        roomName: roomName,
        recordDate: recordDate,
        sessionIndex: sessionIndex,
        sessionName: sessionName,
        previewUrl: previewUrl,
        previewStoragePath: previewStoragePath,
        downloadStoragePath: downloadStoragePath,
        previewBytes: previewBytes.length,
        downloadBytes: downloadBytes.length,
        uploadedByUid: user?.uid,
        uploadedByName: uploadedByName,
      );

      debugPrint(
        '✅ Firestore 照片紀錄建立完成：'
        'photoId=$photoId',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DailyCarePhotoUploadService 上傳失敗：$e');

      debugPrint('❌ 上傳失敗 StackTrace：$stackTrace');

      // 如果上傳到一半失敗，
      // 把已經成功放進 Storage 的檔案清掉，
      // 避免留下孤兒檔案。
      if (uploadedPreviewPath != null) {
        await _safeDelete(uploadedPreviewPath);
      }

      if (uploadedDownloadPath != null) {
        await _safeDelete(uploadedDownloadPath);
      }

      rethrow;
    }
  }

  Future<Uint8List> _compressImage({
    required Uint8List originalBytes,
    required int maxSize,
    required int quality,
  }) async {
    final Uint8List result = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: maxSize,
      minHeight: maxSize,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (result.isEmpty) {
      throw StateError('照片壓縮失敗');
    }

    return result;
  }

  Future<void> _safeDelete(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
