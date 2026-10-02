// 檔案名稱：lib/core/models/app_notification_model.dart
// 功能說明：將 Firestore notifications 文件轉換成 Flutter 可使用的通知物件
// 🔔 App 通知資料模型

import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.bookingId,
    required this.shopId,
    required this.messageId,
    required this.status,
    required this.data,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
    this.source = '',
    this.category = '',
    this.isMandatory,
    this.shopName = '',
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String bookingId;
  final String shopId;
  final String messageId;
  final String status;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  /// system、shop、platform。舊通知沒有此欄位時為空字串。
  final String source;

  /// transactional、shop_marketing、shop_notice、platform_important、platform_marketing。
  final String category;

  /// 舊通知沒有此欄位時為 null，由分類規則視為主要通知。
  final bool? isMandatory;
  final String shopName;

  factory AppNotificationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final String id = _safeId(document);
    try {
      final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};
      final Map<String, dynamic> nested = _readMap(data['data']);

      return AppNotificationModel(
        id: id,
        userId: (data['userId'] ?? '').toString(),
        title: (data['title'] ?? '').toString(),
        body: (data['body'] ?? '').toString(),
        type: (data['type'] ?? '').toString(),
        bookingId: (data['bookingId'] ?? '').toString(),
        shopId: _firstText(data['shopId'], nested['shopId']),
        messageId: (data['messageId'] ?? '').toString(),
        status: (data['status'] ?? 'active').toString(),
        data: nested,
        isRead: data['isRead'] == true,
        createdAt: _readDateTime(data['createdAt']),
        readAt: _readDateTime(data['readAt']),
        source: _firstText(data['source'], nested['source']),
        category: _firstText(data['category'], nested['category']),
        isMandatory: _readBool(
          data.containsKey('isMandatory')
              ? data['isMandatory']
              : nested['isMandatory'],
        ),
        shopName: _firstText(data['shopName'], nested['shopName']),
      );
    } catch (_) {
      return AppNotificationModel(
        id: id,
        userId: '',
        title: '通知',
        body: '',
        type: '',
        bookingId: '',
        shopId: '',
        messageId: '',
        status: 'active',
        data: const <String, dynamic>{},
        isRead: false,
        createdAt: null,
        readAt: null,
      );
    }
  }

  static String _safeId(DocumentSnapshot<Map<String, dynamic>> document) {
    try {
      return document.id;
    } catch (_) {
      return '';
    }
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static String _firstText(dynamic primary, dynamic fallback) {
    final String first = (primary ?? '').toString().trim();
    if (first.isNotEmpty) return first;
    return (fallback ?? '').toString().trim();
  }

  static bool? _readBool(dynamic value) {
    if (value == null || value == '') return null;
    if (value is bool) return value;
    final String text = value.toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    try {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
