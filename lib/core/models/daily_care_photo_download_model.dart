// lib/core/models/daily_care_photo_download_model.dart
// 📥 每日照護高清照片下載 Model
// 功能：保存退房後才可使用的高清照護照片資料。
// 此資料不可在入住期間提供給一般會員讀取。

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCarePhotoDownloadModel {
  const DailyCarePhotoDownloadModel({
    required this.id,
    required this.shopId,
    required this.bookingId,
    required this.photoId,
    required this.downloadStoragePath,
    this.downloadBytes,
    this.expiresAt,
    this.createdAt,
  });

  /// 文件 ID
  ///
  /// 建議與 daily_care_photos/{photoId} 使用相同 ID。
  final String id;

  /// 店家 ID
  final String shopId;

  /// 訂單 ID
  final String bookingId;

  /// 對應 daily_care_photos 的照片 ID
  final String photoId;

  /// Firebase Storage 高清照片實際路徑
  ///
  /// 不保存永久 downloadUrl。
  /// 真正下載時透過 Firebase Storage SDK 使用此路徑取得檔案，
  /// 讓 Storage Rules 即時驗證會員是否仍有下載權限。
  final String downloadStoragePath;

  /// 高清照片檔案大小
  final int? downloadBytes;

  /// 高清照片到期時間
  ///
  /// 真正值會使用：
  /// checkOutAt + downloadHoursAfterCheckout
  final DateTime? expiresAt;

  /// 建立時間
  final DateTime? createdAt;

  factory DailyCarePhotoDownloadModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return DailyCarePhotoDownloadModel(
      id: id,
      shopId: _readString(map['shopId']),
      bookingId: _readString(map['bookingId']),
      photoId: _readString(map['photoId']),
      downloadStoragePath: _readString(map['downloadStoragePath']),
      downloadBytes: _readNullableInt(map['downloadBytes']),
      expiresAt: _readDateTime(map['expiresAt']),
      createdAt: _readDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'photoId': photoId,
      'downloadStoragePath': downloadStoragePath,
      'downloadBytes': downloadBytes,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int? _readNullableInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
