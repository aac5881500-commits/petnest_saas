// 檔案名稱：lib/core/models/daily_care_record_model.dart
// 功能說明：保存入住期間「一房 × 一天 × 一場」的照護紀錄。
// 🐾 每日照護紀錄 Model
// 共用照護項目整房只填一次；個別寵物概況則依 petId 分開保存。

import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCareServiceTypes {
  DailyCareServiceTypes._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';

  static String parse(Object? raw) {
    return raw?.toString().trim() == daycare ? daycare : accommodation;
  }
}

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
    this.serviceType = DailyCareServiceTypes.accommodation,
    this.petIds = const <String>[],
    this.serviceDate = '',
    this.recordIndex,
    this.photosLocked = false,
    this.reportStatus = '',
    this.completedAt,
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

  /// 與 sessionIndex 相同，安親以 bookingId + recordIndex 辨識
  final int? recordIndex;

  /// accommodation | daycare；舊資料缺欄視為住宿
  final String serviceType;

  /// 本次共同回報涵蓋的寵物（安親多寵仍一筆）
  final List<String> petIds;

  /// YYYY-MM-DD 相容欄位，讀取仍以 recordDate 為準
  final String serviceDate;

  /// 確認送出後鎖定該場照片，文字修改不可解鎖。
  final bool photosLocked;

  /// draft：內容已暫存但尚未確認完成。completed：正式完成。
  /// 舊資料沒有這個欄位，只要有回報內容就仍視為已完成。
  final String reportStatus;

  /// 確認完成並寫入完整內容後的時間。舊資料可能只有 updatedAt。
  final DateTime? completedAt;

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

  /// 既有文件有寫入時間或內容即視為已有文件，不代表回報已完成。
  bool get isPersisted {
    if (updatedAt != null || createdAt != null || completedAt != null) {
      return true;
    }
    if (photoCount > 0) {
      return true;
    }
    if (hasReportContent) {
      return true;
    }
    return false;
  }

  /// 環境、分類答案或文字至少有一項，才算這場真的有回報內容。
  bool get hasReportContent {
    for (final dynamic value in values.values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return true;
      }
    }
    return petNotes.values.any((String note) => note.trim().isNotEmpty);
  }

  /// 只有照片計數或 updatedAt、沒有內容的文件不是完成。
  /// draft 即使已寫入內容，也要等確認完成後才離開待填。
  bool get countsAsCompleted {
    if (!hasReportContent) {
      return false;
    }
    return reportStatus != 'draft';
  }

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
      recordDate:
          _dateFromRecordId(id) ??
          _readDateTime(map['recordDate']) ??
          _readServiceDate(map['serviceDate']) ??
          DateTime.now(),
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
      serviceType: DailyCareServiceTypes.parse(map['serviceType']),
      petIds: _readStringList(map['petIds']),
      serviceDate: _readString(map['serviceDate']),
      recordIndex: map.containsKey('recordIndex')
          ? _readInt(map['recordIndex'])
          : null,
      photosLocked: map['photosLocked'] == true,
      reportStatus: _readString(map['reportStatus']),
      completedAt: _readDateTime(map['completedAt']),
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
      'recordIndex': recordIndex ?? sessionIndex,
      'sessionName': sessionName,
      'serviceType': serviceType,
      'petIds': petIds,
      'serviceDate': serviceDate,
      'values': values,
      'petNotes': petNotes,
      'photoCount': photoCount,
      'reportStatus': reportStatus,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList();
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

    if (value is String) {
      return _readServiceDate(value);
    }

    if (value is Map) {
      final Object? seconds = value['_seconds'] ?? value['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000,
          isUtc: true,
        );
      }
    }

    return null;
  }

  /// `YYYY-MM-DD` 或 `YYYY/MM/DD` 或 `YYYYMMDD`，取日曆日，不把 UTC 午夜再減一天。
  static DateTime? _readServiceDate(Object? value) {
    final String text = _readString(
      value,
    ).replaceAll('/', '').replaceAll('-', '');
    if (text.length < 8) {
      return null;
    }
    final int? year = int.tryParse(text.substring(0, 4));
    final int? month = int.tryParse(text.substring(4, 6));
    final int? day = int.tryParse(text.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  /// `{bookingId}_{yyyyMMdd}_{sessionIndex}` 的日期段。
  static DateTime? _dateFromRecordId(String id) {
    final RegExpMatch? match = RegExp(r'_(\d{8})_(\d+)$').firstMatch(id.trim());
    if (match == null) {
      return null;
    }
    return _readServiceDate(match.group(1));
  }
}
