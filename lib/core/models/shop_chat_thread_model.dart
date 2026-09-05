// 檔案名稱：lib/core/models/shop_chat_thread_model.dart
// 功能說明：店家聊天室：一個會員 × 一間店家 = 一個 thread

import 'package:cloud_firestore/cloud_firestore.dart';

class ShopChatThreadStatuses {
  static const String active = 'active';
  static const String archived = 'archived';
}

class ShopChatThreadModel {
  const ShopChatThreadModel({
    required this.id,
    required this.shopId,
    required this.customerUid,
    this.customerName = '',
    this.customerPhotoUrl = '',
    this.customerPhone = '',
    this.lastMessage = '',
    this.lastMessageType = 'text',
    this.lastMessageAt,
    this.customerUnreadCount = 0,
    this.shopUnreadCount = 0,
    this.lastSenderType = '',
    this.status = ShopChatThreadStatuses.active,
    this.createdAt,
    this.updatedAt,
    this.lastReadByCustomerAt,
    this.lastReadByShopAt,
  });

  final String id;
  final String shopId;
  final String customerUid;
  final String customerName;
  final String customerPhotoUrl;
  final String customerPhone;
  final String lastMessage;
  final String lastMessageType;
  final DateTime? lastMessageAt;
  final int customerUnreadCount;
  final int shopUnreadCount;
  final String lastSenderType;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReadByCustomerAt;
  final DateTime? lastReadByShopAt;

  bool get isArchived => status == ShopChatThreadStatuses.archived;

  bool get shopHasReadLastCustomerMessage {
    if (lastSenderType != 'customer' || lastMessageAt == null) {
      return false;
    }
    if (lastReadByShopAt == null) {
      return false;
    }
    return !lastReadByShopAt!.isBefore(lastMessageAt!);
  }

  factory ShopChatThreadModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ShopChatThreadModel.fromMap(doc.id, doc.data() ?? const {});
  }

  factory ShopChatThreadModel.fromMap(String id, Map<String, dynamic> data) {
    return ShopChatThreadModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      customerUid: (data['customerUid'] ?? id).toString(),
      customerName: (data['customerName'] ?? '').toString(),
      customerPhotoUrl: (data['customerPhotoUrl'] ?? '').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastMessageType: (data['lastMessageType'] ?? 'text').toString(),
      lastMessageAt: _dateOf(data['lastMessageAt']),
      customerUnreadCount: _intOf(data['customerUnreadCount']),
      shopUnreadCount: _intOf(data['shopUnreadCount']),
      lastSenderType: (data['lastSenderType'] ?? '').toString(),
      status: (data['status'] ?? ShopChatThreadStatuses.active).toString(),
      createdAt: _dateOf(data['createdAt']),
      updatedAt: _dateOf(data['updatedAt']),
      lastReadByCustomerAt: _dateOf(data['lastReadByCustomerAt']),
      lastReadByShopAt: _dateOf(data['lastReadByShopAt']),
    );
  }

  static int _intOf(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
