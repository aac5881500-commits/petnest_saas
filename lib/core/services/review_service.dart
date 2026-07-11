// lib/core/services/review_service.dart
// ⭐ 評價服務
// 功能：建立訂單評價、防止重複評論、回寫訂單 reviewed 狀態、更新店家評分統計

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _reviewsRef =>
      _firestore.collection('reviews');

  CollectionReference<Map<String, dynamic>> get _bookingsRef =>
      _firestore.collection('bookings');

  /// 建立評價
  Future<void> createReview({
    required String bookingId,
    required int rating,
    required int environmentRating,
    required int serviceRating,
    required int priceRating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('請先登入後再評論');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('整體評分必須是 1 到 5 分');
    }

    if (environmentRating < 1 || environmentRating > 5) {
      throw Exception('環境評分必須是 1 到 5 分');
    }

    if (serviceRating < 1 || serviceRating > 5) {
      throw Exception('服務評分必須是 1 到 5 分');
    }

    if (priceRating < 1 || priceRating > 5) {
      throw Exception('價格評分必須是 1 到 5 分');
    }

    if (imageUrls.length > 5) {
      throw Exception('評價照片最多 5 張');
    }

    final bookingRef = _bookingsRef.doc(bookingId);
    final reviewRef = _reviewsRef.doc();

    await _firestore.runTransaction((transaction) async {
      final bookingSnap = await transaction.get(bookingRef);

      if (!bookingSnap.exists) {
        throw Exception('找不到訂單');
      }

      final bookingData = bookingSnap.data() ?? {};

      final shopId = bookingData['shopId']?.toString() ?? '';
      final bookingUserId = bookingData['userId']?.toString() ?? '';
      final status = bookingData['status']?.toString() ?? '';
      final reviewed = bookingData['reviewed'] == true;

      if (shopId.isEmpty) {
        throw Exception('訂單缺少店家資料');
      }

      if (bookingUserId != user.uid) {
        throw Exception('只能評論自己的訂單');
      }

      if (status != 'completed') {
        throw Exception('只有已完成的訂單可以評論');
      }

      if (reviewed) {
        throw Exception('這筆訂單已經評論過');
      }

      final now = FieldValue.serverTimestamp();

      final petNames = bookingData['petNames'];
      final roomTypeName = bookingData['roomTypeName']?.toString();

      transaction.set(reviewRef, {
        'reviewId': reviewRef.id,
        'shopId': shopId,
        'bookingId': bookingId,
        'userId': user.uid,

        'customerName': bookingData['customerName'] ?? '',
        'petNames': petNames is List ? petNames : [],

        'roomTypeName': roomTypeName ?? '',
        'startDate': bookingData['startDate'],
        'endDate': bookingData['endDate'],
        'nights': bookingData['nights'] ?? 0,

        'rating': rating,
        'environmentRating': environmentRating,
        'serviceRating': serviceRating,
        'priceRating': priceRating,

        'content': content.trim(),
        'imageUrls': imageUrls,

        'reply': '',
        'replyAt': null,
        'replyBy': '',

        'status': 'visible',

        'createdAt': now,
        'updatedAt': now,
      });

      transaction.update(bookingRef, {
        'reviewed': true,
        'reviewId': reviewRef.id,
        'updatedAt': now,
      });
    });
  }

  /// 修改自己的評價內容與照片
  Future<void> updateMyReview({
    required String reviewId,
    required String content,
    required List<String> imageUrls,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('請先登入');
    }

    final text = content.trim();

    if (text.isEmpty) {
      throw Exception('請輸入評價內容');
    }

    if (text.length > 500) {
      throw Exception('評價內容最多 500 字');
    }

    if (imageUrls.length > 5) {
      throw Exception('評價照片最多 5 張');
    }

    final reviewRef = _reviewsRef.doc(reviewId);
    final reviewSnap = await reviewRef.get();

    if (!reviewSnap.exists) {
      throw Exception('找不到評價');
    }

    final data = reviewSnap.data() ?? {};
    final reviewUserId = data['userId']?.toString() ?? '';

    if (reviewUserId != user.uid) {
      throw Exception('只能修改自己的評價');
    }

    await reviewRef.update({
      'content': text,
      'imageUrls': imageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 店家回覆評價
  Future<void> replyReview({
    required String reviewId,
    required String reply,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('請先登入');
    }

    final text = reply.trim();

    if (text.isEmpty) {
      throw Exception('請輸入回覆內容');
    }

    if (text.length > 500) {
      throw Exception('回覆內容最多 500 字');
    }

    await _reviewsRef.doc(reviewId).update({
      'reply': text,
      'replyAt': FieldValue.serverTimestamp(),
      'replyBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
