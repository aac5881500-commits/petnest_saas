// lib/core/models/review_model.dart
// ⭐ 評價資料模型
// 功能：統一 reviews 文件資料格式，供前台、店家後台、平台後台共用

import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  const ReviewModel({
    required this.reviewId,
    required this.shopId,
    required this.bookingId,
    required this.userId,
    required this.customerName,
    required this.petNames,
    required this.roomTypeName,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.rating,
    required this.environmentRating,
    required this.serviceRating,
    required this.priceRating,
    required this.content,
    required this.imageUrls,
    required this.reply,
    required this.replyAt,
    required this.replyBy,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reviewId;
  final String shopId;
  final String bookingId;
  final String userId;

  final String customerName;
  final List<String> petNames;

  final String roomTypeName;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final int nights;

  final int rating;
  final int environmentRating;
  final int serviceRating;
  final int priceRating;

  final String content;
  final List<String> imageUrls;

  final String reply;
  final Timestamp? replyAt;
  final String replyBy;

  final String status;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ReviewModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ReviewModel(
      reviewId: (data['reviewId'] ?? doc.id).toString(),
      shopId: (data['shopId'] ?? '').toString(),
      bookingId: (data['bookingId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      customerName: (data['customerName'] ?? '').toString(),
      petNames: (data['petNames'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      roomTypeName: (data['roomTypeName'] ?? '').toString(),
      startDate: data['startDate'] is Timestamp ? data['startDate'] : null,
      endDate: data['endDate'] is Timestamp ? data['endDate'] : null,
      nights: ((data['nights'] ?? 0) as num).toInt(),
      rating: ((data['rating'] ?? 0) as num).toInt(),
      environmentRating: ((data['environmentRating'] ?? 0) as num).toInt(),
      serviceRating: ((data['serviceRating'] ?? 0) as num).toInt(),
      priceRating: ((data['priceRating'] ?? 0) as num).toInt(),
      content: (data['content'] ?? '').toString(),
      imageUrls: (data['imageUrls'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      reply: (data['reply'] ?? '').toString(),
      replyAt: data['replyAt'] is Timestamp ? data['replyAt'] : null,
      replyBy: (data['replyBy'] ?? '').toString(),
      status: (data['status'] ?? 'visible').toString(),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : null,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : null,
    );
  }

  bool get isVisible => status == 'visible';

  bool get hasReply => reply.trim().isNotEmpty;
}
