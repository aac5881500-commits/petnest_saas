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

  factory AppNotificationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? {};

    return AppNotificationModel(
      id: document.id,
      userId: (data['userId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      bookingId: (data['bookingId'] ?? '').toString(),
      shopId: (data['shopId'] ?? '').toString(),
      messageId: (data['messageId'] ?? '').toString(),
      status: (data['status'] ?? 'active').toString(),
      data: _readMap(data['data']),
      isRead: data['isRead'] == true,
      createdAt: _readDateTime(data['createdAt']),
      readAt: _readDateTime(data['readAt']),
    );
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

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
