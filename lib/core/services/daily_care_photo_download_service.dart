// 檔案名稱：lib/core/services/daily_care_photo_download_service.dart
// 功能說明：讀取退房後可使用的高清照片下載資料
// 📥 每日照護高清照片下載 Service
// 並透過受保護的 downloadStoragePath 直接下載 Firebase Storage 高清照片。
// 一般入住期間的 Preview 頁不可使用此 Service。

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/daily_care_photo_download_model.dart';

class DailyCarePhotoDownloadService {
  DailyCarePhotoDownloadService._();

  static final DailyCarePhotoDownloadService instance =
      DailyCarePhotoDownloadService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('daily_care_photo_downloads');
  }

  /// 取得某次住宿全部高清下載照片資料。
  ///
  /// 一般會員實際能否讀取，
  /// 仍由 Firestore Rules 驗證：
  /// - 必須是自己的 Booking
  /// - Booking 必須 completed
  /// - expiresAt 必須存在
  /// - 尚未超過下載期限
  Stream<List<DailyCarePhotoDownloadModel>> streamBookingDownloads({
    required String bookingId,
  }) {
    final String normalizedBookingId = bookingId.trim();

    if (normalizedBookingId.isEmpty) {
      return Stream<List<DailyCarePhotoDownloadModel>>.value(
        <DailyCarePhotoDownloadModel>[],
      );
    }

    return _collection
        .where('bookingId', isEqualTo: normalizedBookingId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    DailyCarePhotoDownloadModel.fromMap(
                      id: doc.id,
                      map: doc.data(),
                    ),
              )
              .toList();
        });
  }

  /// 取得單張高清下載 metadata。
  Future<DailyCarePhotoDownloadModel?> getDownload({
    required String photoId,
  }) async {
    final String normalizedPhotoId = photoId.trim();

    if (normalizedPhotoId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _collection
        .doc(normalizedPhotoId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return DailyCarePhotoDownloadModel.fromMap(
      id: snapshot.id,
      map: snapshot.data() ?? <String, dynamic>{},
    );
  }

  /// 下載單張受保護的高清照片。
  ///
  /// 不使用永久 downloadUrl。
  ///
  /// 直接透過 downloadStoragePath 存取 Firebase Storage，
  /// 讓 Storage Rules 在實際下載當下重新驗證：
  /// - Booking 是否 completed
  /// - 是否為 Booking 本人
  /// - metadata 是否存在
  /// - expiresAt 是否尚未過期
  Future<Uint8List> downloadPhotoBytes({
    required String downloadStoragePath,
  }) async {
    final String normalizedPath = downloadStoragePath.trim();

    if (normalizedPath.isEmpty) {
      throw ArgumentError('缺少高清照片 Storage 路徑');
    }

    final Reference ref = _storage.ref(normalizedPath);

    // 目前每日照護高清圖上傳本身限制 <= 5MB。
    // 這裡保留 10MB 讀取上限，避免異常檔案造成大量記憶體使用。
    final Uint8List? bytes = await ref.getData(10 * 1024 * 1024);

    if (bytes == null || bytes.isEmpty) {
      throw StateError('高清照片下載失敗');
    }

    return bytes;
  }

  /// 更新某張高清照片的到期時間。
  ///
  /// 主要由退房完成流程使用。
  Future<void> updateExpiresAt({
    required String photoId,
    required DateTime expiresAt,
  }) async {
    final String normalizedPhotoId = photoId.trim();

    if (normalizedPhotoId.isEmpty) {
      throw ArgumentError('缺少照片 ID');
    }

    await _collection.doc(normalizedPhotoId).update(<String, dynamic>{
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
  }

  /// 刪除高清下載 metadata。
  ///
  /// 圖片本體由每日照護照片刪除流程另外處理。
  Future<void> deleteDownloadRecord({required String photoId}) async {
    final String normalizedPhotoId = photoId.trim();

    if (normalizedPhotoId.isEmpty) {
      return;
    }

    await _collection.doc(normalizedPhotoId).delete();
  }
}
