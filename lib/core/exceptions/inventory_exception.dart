// lib/core/exceptions/inventory_exception.dart
// 📦 中央庫存錯誤
// 功能：把庫存不足、停用、重複執行等狀況轉成可直接顯示的中文訊息，
// 避免把 Firebase exception stack 丟給使用者。

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryException implements Exception {
  const InventoryException(this.message);

  final String message;

  @override
  String toString() => message;

  static String userMessage(Object error) {
    if (error is InventoryException) {
      return error.message;
    }

    if (error is StateError) {
      final String message = error.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    if (error is ArgumentError) {
      final String message = (error.message ?? '').toString().trim();
      if (message.isNotEmpty) {
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

    return '庫存操作失敗，請稍後再試';
  }
}
