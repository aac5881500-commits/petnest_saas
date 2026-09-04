// lib/core/utils/safe_parse.dart
// 共用安全解析：相容 Firestore Map／List／Timestamp／金額／bool。

import 'package:cloud_firestore/cloud_firestore.dart';

class SafeParse {
  SafeParse._();

  static bool parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized.isEmpty) {
        return false;
      }
    }
    return fallback;
  }

  static int parseMoney(dynamic value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final String trimmed = value.trim().replaceAll(',', '');
      if (trimmed.isEmpty) {
        return fallback;
      }
      final int? asInt = int.tryParse(trimmed);
      if (asInt != null) {
        return asInt;
      }
      final double? asDouble = double.tryParse(trimmed);
      if (asDouble != null) {
        return asDouble.round();
      }
    }
    return fallback;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return null;
  }

  static String parseString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static Map<String, dynamic> parseMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<dynamic> parseList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  static List<Map<String, dynamic>> parseMapList(dynamic value) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final dynamic item in parseList(value)) {
      final Map<String, dynamic> map = parseMap(item);
      if (map.isNotEmpty) {
        result.add(map);
      }
    }
    return result;
  }
}
