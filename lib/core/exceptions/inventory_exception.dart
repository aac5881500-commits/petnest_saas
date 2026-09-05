// 檔案名稱：lib/core/exceptions/inventory_exception.dart
// 功能說明：把庫存不足、停用、重複執行等狀況轉成可直接顯示的中文訊息
// 📦 中央庫存錯誤
// 避免把 Firebase exception stack 丟給使用者。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class InventoryException implements Exception {
  const InventoryException(this.message);

  final String message;

  @override
  String toString() => message;

  static String userMessage(Object error) {
    if (error is InventoryException) {
      return error.message;
    }

    if (error is FirebaseFunctionsException) {
      return _functionsUserMessage(error);
    }

    if (error is StateError) {
      final String message = error.message.trim();
      if (message.isNotEmpty && !_isGenericEngineMessage(message)) {
        return message;
      }
    }

    if (error is ArgumentError) {
      final String message = (error.message ?? '').toString().trim();
      if (message.isNotEmpty && !_isGenericEngineMessage(message)) {
        return message;
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '沒有權限執行此庫存操作';
        case 'unavailable':
          return '目前無法連線，請稍後再試';
        case 'aborted':
          return '操作尚未完成，請勿重複執行';
        default:
          return '庫存操作失敗，請稍後再試';
      }
    }

    final String raw = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('InventoryException: ', '')
        .trim();
    if (raw.isNotEmpty && !_isGenericEngineMessage(raw)) {
      return raw;
    }

    return '建立預約失敗，請稍後再試。';
  }

  static String _functionsUserMessage(FirebaseFunctionsException error) {
    final String raw = (error.message ?? '').trim();
    final bool hasUsefulMessage =
        raw.isNotEmpty && !_isGenericEngineMessage(raw);

    switch (error.code) {
      case 'failed-precondition':
        return hasUsefulMessage ? raw : '部分加購服務庫存不足，請重新選擇。';
      case 'permission-denied':
        return '無法完成庫存處理，請重新登入後再試。';
      case 'unauthenticated':
        return '請重新登入後再試。';
      case 'not-found':
        return hasUsefulMessage ? raw : '訂單或加購設定不存在，請稍後再試。';
      case 'deadline-exceeded':
        return '處理逾時，請重新嘗試。';
      case 'unavailable':
        return '建立預約時連線失敗，請確認網路後再試。';
      case 'invalid-argument':
        return hasUsefulMessage ? raw : '預約資料不正確，請重新確認。';
      case 'internal':
        return hasUsefulMessage ? raw : '系統暫時無法完成預約，請稍後再試。';
      default:
        if (hasUsefulMessage) {
          return raw;
        }
        return '建立預約失敗，請稍後再試。';
    }
  }

  static bool _isGenericEngineMessage(String message) {
    final String lower = message.toLowerCase().trim();
    return lower.isEmpty ||
        lower == 'internal' ||
        lower == 'internal.' ||
        lower == 'not found' ||
        lower == 'not-found' ||
        lower == 'unavailable' ||
        lower == 'deadline-exceeded' ||
        lower == 'unknown' ||
        lower == 'ok' ||
        lower == 'error';
  }
}
