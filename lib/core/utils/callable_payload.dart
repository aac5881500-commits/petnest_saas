// 檔案名稱：lib/core/utils/callable_payload.dart
// 功能說明：Cloud Functions callable 只允許純 JSON 資料，送出前遞迴檢查型別。

import 'package:flutter/foundation.dart';

class CallablePayloadException implements Exception {
  const CallablePayloadException({required this.path, required this.typeName});

  final String path;
  final String typeName;

  String get debugMessage => 'Invalid callable value:\n$path = $typeName';

  @override
  String toString() => debugMessage;
}

class CallablePayload {
  CallablePayload._();

  static const String userMessage = '預約資料格式錯誤，請稍後再試。';

  static bool isAllowedValue(Object? value) {
    if (value == null ||
        value is String ||
        value is bool ||
        value is int ||
        value is double) {
      return true;
    }
    if (value is List) {
      for (final Object? item in value) {
        if (!isAllowedValue(item)) {
          return false;
        }
      }
      return true;
    }
    if (value is Map) {
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        if (entry.key is! String || !isAllowedValue(entry.value)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static String? firstInvalidPath(Object? value, [String path = 'data']) {
    if (value == null ||
        value is String ||
        value is bool ||
        value is int ||
        value is double) {
      return null;
    }
    if (value is List) {
      for (int i = 0; i < value.length; i++) {
        final String? nested = firstInvalidPath(value[i], '$path[$i]');
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }
    if (value is Map) {
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        if (entry.key is! String) {
          return path;
        }
        final String? nested = firstInvalidPath(
          entry.value,
          '$path.${entry.key}',
        );
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }
    return path;
  }

  static String typeNameOf(Object? value) {
    if (value == null) {
      return 'null';
    }
    return value.runtimeType.toString();
  }

  static void assertValid(Map<String, dynamic> data) {
    final String? path = firstInvalidPath(data);
    if (path == null) {
      return;
    }
    Object? cursor = data;
    final String relative = path.startsWith('data.')
        ? path.substring(5)
        : path == 'data'
        ? ''
        : path;
    if (relative.isNotEmpty) {
      cursor = _valueAt(data, relative);
    }
    final CallablePayloadException error = CallablePayloadException(
      path: path,
      typeName: typeNameOf(cursor),
    );
    debugPrint(error.debugMessage);
    throw error;
  }

  static Object? _valueAt(Object? root, String path) {
    Object? current = root;
    final List<String> parts = path.split('.');
    for (final String part in parts) {
      if (current is Map) {
        final int bracket = part.indexOf('[');
        if (bracket < 0) {
          current = current[part];
          continue;
        }
        final String key = part.substring(0, bracket);
        current = current[key];
        final Iterable<RegExpMatch> indexes = RegExp(
          r'\[(\d+)\]',
        ).allMatches(part);
        for (final RegExpMatch match in indexes) {
          final int index = int.parse(match.group(1)!);
          if (current is List && index >= 0 && index < current.length) {
            current = current[index];
          } else {
            return current;
          }
        }
      }
    }
    return current;
  }
}
