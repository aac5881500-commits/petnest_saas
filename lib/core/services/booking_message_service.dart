// 檔案名稱：lib/core/services/booking_message_service.dart
// 功能說明：讀取訂單留言、送出訂單留言
// 💬 訂單留言服務

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingMessageService {
  BookingMessageService._();

  static final BookingMessageService instance = BookingMessageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('messages');
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String bookingId) {
    return _messagesRef(
      bookingId,
    ).orderBy('createdAt', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    });
  }

  Future<void> sendMessage({
    required String bookingId,
    required String text,
    required String senderType, // customer / shop
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('請先登入');
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw Exception('請輸入留言內容');
    }

    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();

    if (!bookingDoc.exists) {
      throw Exception('訂單不存在');
    }

    final bookingData = bookingDoc.data() ?? {};

    final status = (bookingData['status'] ?? '').toString();

    if (status == 'cancelled') {
      throw Exception('已取消訂單無法留言');
    }

    if (status == 'completed') {
      throw Exception('已完成訂單無法留言');
    }

    final messageCount = await _messagesRef(bookingId).count().get();

    final totalMessages = messageCount.count ?? 0;

    if (totalMessages >= 100) {
      throw Exception('此訂單留言已達上限');
    }

    await _messagesRef(bookingId).add({
      'bookingId': bookingId,
      'text': cleanText,
      'senderId': user.uid,
      'senderEmail': user.email ?? '',
      'senderType': senderType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final Map<String, dynamic> updateData = {
      'lastMessageText': cleanText,
      'lastMessageSenderType': senderType,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (senderType == 'customer') {
      updateData['shopUnreadMessageCount'] = FieldValue.increment(1);
    }

    if (senderType == 'shop') {
      updateData['customerUnreadMessageCount'] = FieldValue.increment(1);
    }

    await _firestore.collection('bookings').doc(bookingId).update(updateData);
  }

  Future<void> markAsRead({
    required String bookingId,
    required String readerType, // customer / shop
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('請先登入');
    }

    final Map<String, dynamic> updateData = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (readerType == 'customer') {
      updateData['customerUnreadMessageCount'] = 0;
    }

    if (readerType == 'shop') {
      updateData['shopUnreadMessageCount'] = 0;
    }

    await _firestore.collection('bookings').doc(bookingId).update(updateData);
  }
}
