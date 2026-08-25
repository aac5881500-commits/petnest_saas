// lib/core/models/daily_care_photo_model.dart
// 📷 每日照護照片 Model
// 功能：保存每日照護照片的預覽圖與一般顯示資料。
// 前台入住期間主要使用 previewUrl 瀏覽。
// 高清下載資料另外存放於 daily_care_photo_downloads。
// 不保存手機原始超大照片。

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCarePhotoModel {
  const DailyCarePhotoModel({
    required this.id,
    required this.shopId,
    required this.bookingId,
    required this.roomId,
    required this.roomName,
    required this.recordDate,
    required this.sessionIndex,
    required this.sessionName,
    required this.previewUrl,
    required this.previewStoragePath,
    required this.createdAt,
    this.previewBytes,
    this.uploadedByUid,
    this.uploadedByName,
  });

  /// 照片文件 ID
  final String id;

  /// 店家 ID
  final String shopId;

  /// 此次住宿訂單 ID
  final String bookingId;

  /// 房間 ID
  final String roomId;

  /// 房號快照，例如 A01
  final String roomName;

  /// 照護日期
  final DateTime recordDate;

  /// 場次索引
  ///
  /// 0 = 第一場
  /// 1 = 第二場
  /// 2 = 第三場
  final int sessionIndex;

  /// 場次名稱快照，例如上午場、下午場、晚上場
  final String sessionName;

  /// 前台平常瀏覽使用的小圖網址
  final String previewUrl;

  /// Firebase Storage 預覽圖實際路徑
  final String previewStoragePath;

  /// 預覽圖檔案大小
  final int? previewBytes;

  /// 上傳人員 UID
  final String? uploadedByUid;

  /// 上傳人員名稱快照
  final String? uploadedByName;

  /// 建立時間
  final DateTime? createdAt;

  factory DailyCarePhotoModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return DailyCarePhotoModel(
      id: id,
      shopId: _readString(map['shopId']),
      bookingId: _readString(map['bookingId']),
      roomId: _readString(map['roomId']),
      roomName: _readString(map['roomName']),
      recordDate: _readDateTime(map['recordDate']) ?? DateTime.now(),
      sessionIndex: _readInt(map['sessionIndex']),
      sessionName: _readString(map['sessionName']),
      previewUrl: _readString(map['previewUrl']),
      previewStoragePath: _readString(map['previewStoragePath']),
      previewBytes: _readNullableInt(map['previewBytes']),
      uploadedByUid: _readNullableString(map['uploadedByUid']),
      uploadedByName: _readNullableString(map['uploadedByName']),
      createdAt: _readDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'bookingId': bookingId,
      'roomId': roomId,
      'roomName': roomName,
      'recordDate': Timestamp.fromDate(
        DateTime(recordDate.year, recordDate.month, recordDate.day),
      ),
      'sessionIndex': sessionIndex,
      'sessionName': sessionName,
      'previewUrl': previewUrl,
      'previewStoragePath': previewStoragePath,
      'previewBytes': previewBytes,
      'uploadedByUid': uploadedByUid,
      'uploadedByName': uploadedByName,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _readNullableString(Object? value) {
    final String result = _readString(value);
    return result.isEmpty ? null : result;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
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
