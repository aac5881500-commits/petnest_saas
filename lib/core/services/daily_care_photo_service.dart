// 檔案名稱：lib/core/services/daily_care_photo_service.dart
// 功能說明：管理每日照護照片資料、每日照片數量限制
// 📷 每日照護照片 Service
// 並負責刪除 Firestore 紀錄與 Firebase Storage 圖片。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_care_photo_model.dart';
import '../models/daily_care_date_helper.dart';
import 'daily_care_photo_function_service.dart';
import 'daily_care_report_write_access.dart';

class DailyCarePhotoService {
  DailyCarePhotoService._();

  static final DailyCarePhotoService instance = DailyCarePhotoService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 📷 平台固定：
  /// 每房每天最多上傳 6 張照護照片。
  static const int maxPhotosPerSession = 3;
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
  /// `shopId` 為空：只查 bookingId，給客戶端使用。
  /// `shopId` 非空：shopId + bookingId，符合店主端 Firestore 權限。
  Stream<List<DailyCarePhotoModel>> streamBookingPhotos({
    required String bookingId,
    String? shopId,
  }) {
    final String normalizedBookingId = bookingId.trim();
    final String normalizedShopId = shopId?.trim() ?? '';

    if (normalizedBookingId.isEmpty) {
      return Stream<List<DailyCarePhotoModel>>.value(<DailyCarePhotoModel>[]);
    }

    Query<Map<String, dynamic>> query = _collection.where(
      'bookingId',
      isEqualTo: normalizedBookingId,
    );
    if (normalizedShopId.isNotEmpty) {
      query = _collection
          .where('shopId', isEqualTo: normalizedShopId)
          .where('bookingId', isEqualTo: normalizedBookingId);
    }

    return query.snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
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

  /// 本場照護紀錄照片：新資料依 record ID，舊資料 fallback 台北日＋場次＋房間。
  Stream<List<DailyCarePhotoModel>> streamRecordPhotos({
    required String bookingId,
    required String dailyCareRecordId,
    DateTime? recordDate,
    int sessionIndex = 0,
    String roomId = '',
    String? shopId,
  }) {
    final String dateKey = recordDate == null
        ? ''
        : DailyCarePhotoMatch.canonicalDateKey(recordDate);
    return streamBookingPhotos(bookingId: bookingId, shopId: shopId).map((
      List<DailyCarePhotoModel> photos,
    ) {
      return DailyCarePhotoMatch.recordPhotos(
        photos: photos,
        dailyCareRecordId: dailyCareRecordId,
        dateKey: dateKey,
        sessionIndex: sessionIndex,
        roomId: roomId,
      );
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
    int sessionIndex = 0,
    bool perSession = true,
  }) async {
    if (perSession) {
      final List<DailyCarePhotoModel> photos = await streamBookingPhotos(
        bookingId: bookingId,
      ).first;
      final String dateKey = DailyCarePhotoMatch.canonicalDateKey(recordDate);
      final String roomFilter = roomId.trim();
      final String recordId =
          '${bookingId.trim()}_${DailyCareDateHelper.recordIdDateKey(recordDate)}_$sessionIndex';
      final int used = DailyCarePhotoMatch.recordPhotos(
        photos: photos,
        dailyCareRecordId: recordId,
        dateKey: dateKey,
        sessionIndex: sessionIndex,
        roomId: roomFilter,
      ).length;
      final int remaining = maxPhotosPerSession - used;
      return remaining < 0 ? 0 : remaining;
    }
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
    String dailyCareRecordId = '',
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

    await _assertBookingWritable(normalizedBookingId);

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

    final DateTime taipeiDay = DailyCareDateHelper.calendarDateInTaipei(
      recordDate,
    );
    final String compactDateKey = DailyCareDateHelper.recordIdDateKey(
      recordDate,
    );
    final String boundRecordId = dailyCareRecordId.trim().isNotEmpty
        ? dailyCareRecordId.trim()
        : '${normalizedBookingId}_${compactDateKey}_$sessionIndex';

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
      'dailyCareRecordId': boundRecordId,
      'dateKey': compactDateKey,
      'roomId': normalizedRoomId,
      'roomName': roomName.trim(),
      'recordDate': Timestamp.fromDate(taipeiDay),
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
    await DailyCarePhotoFunctionService.instance.deletePhoto(photo.id);
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

  Future<void> _assertBookingWritable(String bookingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!DailyCareReportWriteAccess.canWrite(snapshot.data())) {
      throw StateError(DailyCareReportWriteAccess.lockedMessage);
    }
  }
}
