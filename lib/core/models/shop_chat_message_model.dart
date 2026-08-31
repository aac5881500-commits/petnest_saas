// lib/core/models/shop_chat_message_model.dart
// 💬 店家聊天訊息

import 'package:cloud_firestore/cloud_firestore.dart';

class ShopChatMessageTypes {
  static const String text = 'text';
  static const String image = 'image';
  static const String system = 'system';
}

class ShopChatSenderTypes {
  static const String customer = 'customer';
  static const String shop = 'shop';
}

class ShopChatMessageModel {
  const ShopChatMessageModel({
    required this.id,
    required this.shopId,
    required this.threadId,
    required this.senderUid,
    required this.senderType,
    this.senderDisplayName = '',
    this.type = ShopChatMessageTypes.text,
    this.text = '',
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String threadId;
  final String senderUid;
  final String senderType;
  final String senderDisplayName;
  final String type;
  final String text;
  final String imageUrl;
  final String imageStoragePath;
  final DateTime? createdAt;

  bool get isImage => type == ShopChatMessageTypes.image;

  bool get isFromShop => senderType == ShopChatSenderTypes.shop;

  factory ShopChatMessageModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const {};
    return ShopChatMessageModel(
      id: doc.id,
      shopId: (data['shopId'] ?? '').toString(),
      threadId: (data['threadId'] ?? '').toString(),
      senderUid: (data['senderUid'] ?? '').toString(),
      senderType: (data['senderType'] ?? '').toString(),
      senderDisplayName: (data['senderDisplayName'] ?? '').toString(),
      type: (data['type'] ?? ShopChatMessageTypes.text).toString(),
      text: (data['text'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageStoragePath: (data['imageStoragePath'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
