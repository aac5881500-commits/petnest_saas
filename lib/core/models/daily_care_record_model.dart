// lib/core/models/daily_care_record_model.dart
// 🐾 每日照護紀錄 Model
// 功能：保存入住期間「一房 × 一天 × 一場」的照護紀錄。
// 共用照護項目整房只填一次；個別寵物概況則依 petId 分開保存。

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCareRecordModel {
  const DailyCareRecordModel({
    required this.id,
    required this.shopId,
    required this.bookingId,
    required this.roomId,
    required this.roomName,
    required this.recordDate,
    required this.sessionIndex,
    required this.sessionName,
    required this.values,
    required this.petNotes,
    required this.photoCount,
    required this.createdAt,
    required this.updatedAt,
    this.createdByUid,
    this.createdByName,
  });

  /// 紀錄 ID
  final String id;

  /// 店家 ID
  final String shopId;

  /// 此次住宿訂單 ID
  final String bookingId;

  /// 實際房間 ID
  final String roomId;

  /// 房號快照，例如 A01
  final String roomName;

  /// 照護日期，只保存年月日
  final DateTime recordDate;

  /// 照護紀錄順序（sessionIndex），不用名稱當資料 key
  ///
  /// 0 = 第一場
  /// 1 = 第二場
  /// 2 = 第三場
  final int sessionIndex;

  /// 當時顯示名稱快照（僅顯示用，讀取仍靠 sessionIndex）
  final String sessionName;

  /// 整房共同照護資料
  ///
  /// key 使用 DailyCareSettingModel 的 enabledFields。
  /// 例如：
  /// water: general
  /// dryFood: much
  /// stool: normal
  /// wandToy: yes
  /// generalNote: 今天整體狀況良好
  final Map<String, dynamic> values;

  /// 個別寵物概況
  ///
  /// key = petId
  /// value = 該寵物的文字概況
  final Map<String, String> petNotes;

  /// 此場目前照片數量
  ///
  /// 照片本身之後會另外建立資料，不直接塞進這個文件。
  final int photoCount;

  /// 第一次建立紀錄的員工 UID
  final String? createdByUid;

  /// 第一次建立紀錄的員工名稱快照
  final String? createdByName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DailyCareRecordModel.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final Object? rawValues = map['values'];
    final Object? rawPetNotes = map['petNotes'];

    return DailyCareRecordModel(
      id: id,
      shopId: _readString(map['shopId']),
      bookingId: _readString(map['bookingId']),
      roomId: _readString(map['roomId']),
      roomName: _readString(map['roomName']),
      recordDate: _readDateTime(map['recordDate']) ?? DateTime.now(),
      sessionIndex: _readInt(map['sessionIndex']),
      sessionName: _readString(map['sessionName']),
      values: rawValues is Map
          ? Map<String, dynamic>.from(rawValues)
          : <String, dynamic>{},
      petNotes: rawPetNotes is Map
          ? rawPetNotes.map<String, String>(
              (dynamic key, dynamic value) =>
                  MapEntry(key.toString(), value?.toString() ?? ''),
            )
          : <String, String>{},
      photoCount: _readInt(map['photoCount']),
      createdByUid: _readNullableString(map['createdByUid']),
      createdByName: _readNullableString(map['createdByName']),
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
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
      'values': values,
      'petNotes': petNotes,
      'photoCount': photoCount,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
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
