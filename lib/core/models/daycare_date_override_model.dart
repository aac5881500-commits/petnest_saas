// lib/core/models/daycare_date_override_model.dart
// 🐾 臨托單日例外：shops/{shopId}/daycare_date_overrides/{yyyyMMdd}

import 'package:petnest_saas/core/models/daycare_settings_model.dart';

class DaycareDateOverrideModel {
  const DaycareDateOverrideModel({
    required this.id,
    required this.date,
    required this.isOpen,
    this.maxPets = 0,
    this.openTime = '',
    this.closeTime = '',
    this.latestDropoffTime = '',
    this.latestPickupTime = '',
    this.note = '',
  });

  /// 文件 ID，固定 yyyyMMdd
  final String id;

  /// 顯示與查詢用日期，yyyy-MM-dd
  final String date;
  final bool isOpen;

  /// 0 表示沿用臨托設定的每日最大接待數
  final int maxPets;

  /// 留空表示沿用平日開放／結束時間
  final String openTime;
  final String closeTime;

  /// 留空表示沿用平日最晚送達／接回
  final String latestDropoffTime;
  final String latestPickupTime;

  /// 店主內部備註，客戶端不可顯示
  final String note;

  factory DaycareDateOverrideModel.fromMap(
    Map<String, dynamic>? map, {
    required String id,
  }) {
    final Map<String, dynamic> data = map ?? <String, dynamic>{};
    final String compactId = id.trim().replaceAll('-', '');
    return DaycareDateOverrideModel(
      id: compactId,
      date: _date(data['date'], compactId),
      isOpen: _parseIsOpen(data),
      maxPets: _int(data['maxPets'], 0).clamp(0, 200),
      openTime: _optionalTime(data['openTime']),
      closeTime: _optionalTime(data['closeTime']),
      latestDropoffTime: _optionalTime(data['latestDropoffTime']),
      latestPickupTime: _optionalTime(data['latestPickupTime']),
      note: (data['note'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date,
      'isOpen': isOpen,
      'maxPets': maxPets,
      'openTime': openTime,
      'closeTime': closeTime,
      'latestDropoffTime': latestDropoffTime,
      'latestPickupTime': latestPickupTime,
      'note': note,
    };
  }

  DaycareDateOverrideModel copyWith({
    bool? isOpen,
    int? maxPets,
    String? openTime,
    String? closeTime,
    String? latestDropoffTime,
    String? latestPickupTime,
    String? note,
  }) {
    return DaycareDateOverrideModel(
      id: id,
      date: date,
      isOpen: isOpen ?? this.isOpen,
      maxPets: maxPets ?? this.maxPets,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      latestDropoffTime: latestDropoffTime ?? this.latestDropoffTime,
      latestPickupTime: latestPickupTime ?? this.latestPickupTime,
      note: note ?? this.note,
    );
  }

  /// 沒有 isOpen 時預設可預約；舊 closed／isClosed 仍視為關閉。
  static bool _parseIsOpen(Map<String, dynamic> data) {
    if (data.containsKey('isOpen')) {
      return DaycareBool.parse(data['isOpen'], fallback: true);
    }
    if (DaycareBool.parse(data['closed']) ||
        DaycareBool.parse(data['isClosed'])) {
      return false;
    }
    return true;
  }

  static String _date(dynamic raw, String compactId) {
    final String text = (raw ?? '').toString().trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return text;
    }
    if (RegExp(r'^\d{8}$').hasMatch(compactId)) {
      return '${compactId.substring(0, 4)}-${compactId.substring(4, 6)}-${compactId.substring(6, 8)}';
    }
    return text;
  }

  static String _optionalTime(dynamic raw) {
    final String text = (raw ?? '').toString().trim();
    return RegExp(r'^\d{2}:\d{2}$').hasMatch(text) ? text : '';
  }

  static int _int(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
