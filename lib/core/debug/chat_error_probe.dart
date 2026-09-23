// 檔案名稱：lib/core/debug/chat_error_probe.dart
// 功能說明：開發用錯誤紀錄。監聽與轉型必須防呆，probe 本身不可再拋例外。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ChatErrorProbe {
  ChatErrorProbe._();

  /// 二分：聊天頁是否綁 messages stream。
  static const bool bindMessages = true;

  /// 二分：聊天頁是否綁 thread stream。空室改走 watchThreadIfMessagesExist。
  static const bool bindThread = true;

  /// 二分：聊天頁是否 mark read。
  static const bool bindMarkRead = true;

  /// 二分：FloatingContactButton 未讀 stream。
  static const bool bindFloatingUnread = true;

  /// 二分：會員中心店家訊息未讀 stream。
  static const bool bindMemberUnread = true;

  /// 二分：未登入也可開聊天頁 header。正式路徑關閉。
  static const bool allowAnonymousHeader = false;

  /// 給使用者看的中文；完整 plugin／code 請用 [describe] 寫入 debugPrint。
  static String userFacing(Object? error) {
    try {
      if (error is FirebaseFunctionsException) {
        final String text = (error.message ?? '').trim();
        switch (error.code) {
          case 'failed-precondition':
            return text.isEmpty ? '目前無法完成此操作' : text;
          case 'invalid-argument':
            return text.isEmpty ? '資料格式錯誤' : text;
          case 'already-exists':
            return text.isEmpty ? '請勿重複送出' : text;
          case 'not-found':
            return text.isEmpty ? '找不到資料' : text;
          case 'permission-denied':
            return text.isEmpty ? '沒有權限執行此操作' : text;
          case 'unauthenticated':
            return '請先登入';
          case 'resource-exhausted':
            return text.isEmpty ? '點數不足或超過可折抵上限' : text;
          case 'internal':
            return text.isEmpty ? '系統忙碌，請稍後再試' : text;
          default:
            return text.isEmpty ? describe(error) : text;
        }
      }
      return describe(error);
    } catch (_) {
      return '系統忙碌，請稍後再試';
    }
  }

  /// 終端機與 SnackBar 共用的可讀錯誤（含 plugin／code／路徑）。
  static String describe(Object? error) {
    try {
      if (error == null) {
        return '未知錯誤';
      }
      if (error is FirebaseFunctionsException) {
        return _firebaseText(
          plugin: error.plugin,
          code: error.code,
          message: error.message,
          details: error.details,
        );
      }
      if (error is FirebaseException) {
        return _firebaseText(
          plugin: error.plugin,
          code: error.code,
          message: error.message,
        );
      }
      if (error is FlutterErrorDetails) {
        final String text = error.exceptionAsString().trim();
        return text.isEmpty ? describe(error.exception) : text;
      }
      if (error is String) {
        final String text = error.trim();
        return text.isEmpty ? '未知錯誤' : text;
      }
      final String text = error.toString().trim();
      if (text.isEmpty) {
        return error.runtimeType.toString();
      }
      return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
    } catch (_) {
      return error?.runtimeType.toString() ?? '未知錯誤';
    }
  }

  static void dump(
    String source,
    Object? error,
    StackTrace? stack, {
    String? operation,
  }) {
    try {
      _print('========== $source ==========');
      if (operation != null && operation.trim().isNotEmpty) {
        _print('operation=${operation.trim()}');
      }
      _print('runtimeType=${error == null ? 'null' : error.runtimeType}');
      _print(describe(error));
      _print(error);
      _print(stack ?? StackTrace.empty);
      _dumpTyped(error, 'original');
      final Object? inner = _innerException(error);
      if (inner != null && !identical(inner, error)) {
        _print('inner.runtimeType=${inner.runtimeType}');
        _print(describe(inner));
        _print(inner);
        _dumpTyped(inner, 'inner');
      }
      _print('========== /$source ==========');
    } catch (probeError, probeStack) {
      _print('$source probe failed while logging original error');
      _print(probeError);
      _print(probeStack);
    }
  }

  static void _dumpTyped(Object? error, String label) {
    try {
      if (error is FirebaseFunctionsException) {
        _print('$label.plugin=${error.plugin}');
        _print('$label.code=${error.code}');
        _print('$label.message=${error.message}');
        if (error.details != null) {
          _print('$label.details=${error.details}');
        }
        return;
      }
      if (error is FirebaseException) {
        _print('$label.plugin=${error.plugin}');
        _print('$label.code=${error.code}');
        _print('$label.message=${error.message}');
        return;
      }
      if (error is FlutterErrorDetails) {
        _print('$label.library=${error.library}');
        _print('$label.context=${error.context}');
        _print('$label.exception=${error.exception}');
        return;
      }
    } catch (_) {}
  }

  static Object? _innerException(Object? error) {
    try {
      if (error is FlutterErrorDetails) {
        return error.exception;
      }
      if (error is Error && error.stackTrace != null) {
        return null;
      }
    } catch (_) {}
    return null;
  }

  static String _firebaseText({
    required String plugin,
    required String code,
    String? message,
    Object? details,
  }) {
    final StringBuffer out = StringBuffer();
    out.write('[$plugin/$code]');
    final String text = (message ?? '').trim();
    if (text.isNotEmpty) {
      out.write(' $text');
    }
    if (details != null) {
      final String extra = details.toString().trim();
      if (extra.isNotEmpty && extra != text) {
        out.write(' details=$extra');
      }
    }
    return out.toString();
  }

  static void _print(Object? value) {
    try {
      print(value);
    } catch (_) {}
  }
}
