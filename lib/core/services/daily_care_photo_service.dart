// lib/core/services/daily_care_photo_service.dart
// 📷 每日照護照片 Service
// 功能：管理每日照護照片資料、每日照片數量限制，
// 並負責刪除 Firestore 紀錄與 Firebase Storage 圖片。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_care_photo_model.dart';

class DailyCarePhotoService {
  DailyCarePhotoService._();

  static final DailyCarePhotoService instance = DailyCarePhotoService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 📷 平台固定：
  /// 每房每天最多上傳 6 張照護照片。
  static const int maxPhotosPerRoomPerDay = 6;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('daily_care_photos');
  }

  /// 取得某個房間、某一天目前所有照片。
  Stream<List<DailyCarePhotoModel>> streamRoomDayPhotos({
    required String shopId,
    required String bookingId,
    required String roomId,
    required DateTime recordDate,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();
    final String normalizedRoomId = roomId.trim();

    if (normalizedShopId.isEmpty ||
        normalizedBookingId.isEmpty ||
        normalizedRoomId.isEmpty) {
      return Stream<List<DailyCarePhotoModel>>.value(<DailyCarePhotoModel>[]);
    }

    final DateTime dayStart = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    final DateTime nextDay = dayStart.add(const Duration(days: 1));

    return _collection
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .where('roomId', isEqualTo: normalizedRoomId)
        .where(
          'recordDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('recordDate', isLessThan: Timestamp.fromDate(nextDay))
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<DailyCarePhotoModel> photos = snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            return DailyCarePhotoModel.fromMap(id: doc.id, map: doc.data());
          }).toList();

          photos.sort((DailyCarePhotoModel a, DailyCarePhotoModel b) {
            final DateTime aTime = a.createdAt ?? DateTime(1970);

            final DateTime bTime = b.createdAt ?? DateTime(1970);

            return aTime.compareTo(bTime);
          });

          return photos;
        });
  }

  /// 取得某一個照護場次的照片。
  Stream<List<DailyCarePhotoModel>> streamSessionPhotos({
    required String shopId,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty || normalizedBookingId.isEmpty) {
      return Stream<List<DailyCarePhotoModel>>.value(<DailyCarePhotoModel>[]);
    }

    final DateTime dayStart = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    return _collection
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .where('recordDate', isEqualTo: Timestamp.fromDate(dayStart))
        .where('sessionIndex', isEqualTo: sessionIndex)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<DailyCarePhotoModel> photos = snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            return DailyCarePhotoModel.fromMap(id: doc.id, map: doc.data());
          }).toList();

          photos.sort((DailyCarePhotoModel a, DailyCarePhotoModel b) {
            final DateTime aTime = a.createdAt ?? DateTime(1970);

            final DateTime bTime = b.createdAt ?? DateTime(1970);

            return aTime.compareTo(bTime);
          });

          return photos;
        });
  }

  /// 取得某次住宿全部照護照片。
  ///
  /// 客戶端照護照片頁會使用這個 Stream，
  /// 再由畫面依日期與場次整理。
  Stream<List<DailyCarePhotoModel>> streamBookingPhotos({
    required String bookingId,
  }) {
    final String normalizedBookingId = bookingId.trim();

    if (normalizedBookingId.isEmpty) {
      return Stream<List<DailyCarePhotoModel>>.value(<DailyCarePhotoModel>[]);
    }

    return _collection
        .where('bookingId', isEqualTo: normalizedBookingId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<DailyCarePhotoModel> photos = snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            return DailyCarePhotoModel.fromMap(id: doc.id, map: doc.data());
          }).toList();

          photos.sort((DailyCarePhotoModel a, DailyCarePhotoModel b) {
            final int dateCompare = a.recordDate.compareTo(b.recordDate);

            if (dateCompare != 0) {
              return dateCompare;
            }

            final int sessionCompare = a.sessionIndex.compareTo(b.sessionIndex);

            if (sessionCompare != 0) {
              return sessionCompare;
            }

            final DateTime aTime = a.createdAt ?? DateTime(1970);

            final DateTime bTime = b.createdAt ?? DateTime(1970);

            return aTime.compareTo(bTime);
          });

          return photos;
        });
  }

  /// 查詢某房某日目前已有幾張照片。
  Future<int> getRoomDayPhotoCount({
    required String shopId,
    required String bookingId,
    required String roomId,
    required DateTime recordDate,
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

    final DateTime dayStart = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    final DateTime nextDay = dayStart.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .where('roomId', isEqualTo: normalizedRoomId)
        .where(
          'recordDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('recordDate', isLessThan: Timestamp.fromDate(nextDay))
        .get();

    return snapshot.docs.length;
  }

  /// 還能不能繼續上傳照片。
  Future<bool> canUploadPhoto({
    required String shopId,
    required String bookingId,
    required String roomId,
    required DateTime recordDate,
  }) async {
    final int currentCount = await getRoomDayPhotoCount(
      shopId: shopId,
      bookingId: bookingId,
      roomId: roomId,
      recordDate: recordDate,
    );

    return currentCount < maxPhotosPerRoomPerDay;
  }

  /// 目前還能再上傳幾張。
  Future<int> remainingPhotoCount({
    required String shopId,
    required String bookingId,
    required String roomId,
    required DateTime recordDate,
  }) async {
    final int currentCount = await getRoomDayPhotoCount(
      shopId: shopId,
      bookingId: bookingId,
      roomId: roomId,
      recordDate: recordDate,
    );

    final int remaining = maxPhotosPerRoomPerDay - currentCount;

    return remaining < 0 ? 0 : remaining;
  }

  /// 建立照片 Firestore 紀錄。
  ///
  /// Preview：
  /// 保存於 daily_care_photos，
  /// 提供入住期間 App 顯示。
  ///
  /// 高清 Download：
  /// 保存於 daily_care_photo_downloads，
  /// 不保存永久 downloadUrl，
  /// 之後透過 Storage Path 搭配 Storage Rules 控制下載權限。
  Future<String> createPhotoRecord({
    required String shopId,
    required String bookingId,
    required String photoId,
    required String roomId,
    required String roomName,
    required DateTime recordDate,
    required int sessionIndex,
    required String sessionName,
    required String previewUrl,
    required String previewStoragePath,
    required String downloadStoragePath,
    required int previewBytes,
    required int downloadBytes,
    required String? uploadedByUid,
    required String? uploadedByName,
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

    debugPrint(
      '🔎 準備檢查每日照片數量：'
      'shopId=$normalizedShopId, '
      'bookingId=$normalizedBookingId, '
      'roomId=$normalizedRoomId',
    );

    final bool allowed = await canUploadPhoto(
      shopId: normalizedShopId,
      bookingId: normalizedBookingId,
      roomId: normalizedRoomId,
      recordDate: recordDate,
    );

    debugPrint('✅ 每日照片數量檢查成功，allowed=$allowed');

    if (!allowed) {
      throw StateError(
        '此房今日照片已達上限 '
        '$maxPhotosPerRoomPerDay 張',
      );
    }

    final String normalizedPhotoId = photoId.trim();

    if (normalizedPhotoId.isEmpty) {
      throw ArgumentError('缺少照片 ID');
    }

    final DocumentReference<Map<String, dynamic>> ref = _collection.doc(
      normalizedPhotoId,
    );

    final DocumentReference<Map<String, dynamic>> downloadRef = _firestore
        .collection('daily_care_photo_downloads')
        .doc(ref.id);

    final DateTime normalizedDate = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    // ============================================================
    // 📷 一般 Preview metadata
    // ============================================================

    debugPrint(
      '📷 準備建立 daily_care_photos：'
      'photoId=${ref.id}, '
      'shopId=$normalizedShopId, '
      'bookingId=$normalizedBookingId',
    );

    await ref.set(<String, dynamic>{
      'shopId': normalizedShopId,
      'bookingId': normalizedBookingId,
      'roomId': normalizedRoomId,
      'roomName': roomName.trim(),
      'recordDate': Timestamp.fromDate(normalizedDate),
      'sessionIndex': sessionIndex,
      'sessionName': sessionName.trim(),

      'previewUrl': previewUrl.trim(),
      'previewStoragePath': previewStoragePath.trim(),
      'previewBytes': previewBytes,

      'uploadedByUid': uploadedByUid?.trim(),
      'uploadedByName': uploadedByName?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ daily_care_photos 建立成功：${ref.id}');

    // ============================================================
    // 📥 高清 Download metadata
    // ============================================================

    debugPrint(
      '📥 準備建立 daily_care_photo_downloads：'
      '${downloadRef.id}',
    );

    await downloadRef.set(<String, dynamic>{
      'shopId': normalizedShopId,
      'bookingId': normalizedBookingId,
      'photoId': ref.id,

      'downloadStoragePath': downloadStoragePath.trim(),
      'downloadBytes': downloadBytes,

      // 真正退房後才會補上：
      // checkOutAt + downloadHoursAfterCheckout
      'expiresAt': null,

      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ daily_care_photo_downloads 建立成功：'
      '${downloadRef.id}',
    );

    return ref.id;
  }

  /// 刪除單張照片。
  ///
  /// 1. 刪 Preview
  /// 2. 刪 Download
  /// 3. 刪 Firestore 一般照片 metadata
  /// 4. 刪 Firestore 高清下載 metadata
  Future<void> deletePhoto(DailyCarePhotoModel photo) async {
    final DocumentReference<Map<String, dynamic>> downloadRef = _firestore
        .collection('daily_care_photo_downloads')
        .doc(photo.id);

    final DocumentSnapshot<Map<String, dynamic>> downloadSnapshot =
        await downloadRef.get();

    final Map<String, dynamic>? downloadData = downloadSnapshot.data();

    final String downloadStoragePath =
        (downloadData?['downloadStoragePath'] ?? '').toString().trim();

    // 1. 刪除 Preview 圖片
    await _deleteStorageFile(photo.previewStoragePath);

    // 2. 刪除高清 Download 圖片
    await _deleteStorageFile(downloadStoragePath);

    // 3. 刪除一般照片 metadata
    await _collection.doc(photo.id).delete();

    // 4. 刪除高清下載 metadata
    if (downloadSnapshot.exists) {
      await downloadRef.delete();
    }
  }

  /// 刪除某次住宿的所有照護照片。
  ///
  /// 之後退房到期自動清除會直接使用這個方法的邏輯。
  Future<void> deleteBookingPhotos({required String bookingId}) async {
    final String normalizedBookingId = bookingId.trim();

    if (normalizedBookingId.isEmpty) {
      throw ArgumentError('缺少訂單 ID');
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .where('bookingId', isEqualTo: normalizedBookingId)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final DailyCarePhotoModel photo = DailyCarePhotoModel.fromMap(
        id: doc.id,
        map: doc.data(),
      );

      await deletePhoto(photo);
    }
  }

  /// 刪除 Firebase Storage 檔案。
  Future<void> _deleteStorageFile(String storagePath) async {
    final String normalizedPath = storagePath.trim();

    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await _storage.ref(normalizedPath).delete();
    } on FirebaseException catch (e) {
      // 圖片已經不存在時，
      // 不需要阻擋後續 Firestore 清除。
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
