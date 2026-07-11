// lib/features/booking/widgets/review_card.dart
// ⭐ 共用評價卡片
// 功能：顯示評價星等、留言、照片、店家回覆

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_rating_stars.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final ReviewModel review;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange() {
    if (review.startDate == null || review.endDate == null) {
      return '';
    }

    final start = review.startDate!.toDate();
    final end = review.endDate!.toDate();

    return '${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')}'
        ' ～ '
        '${end.month.toString().padLeft(2, '0')}/${end.day.toString().padLeft(2, '0')}';
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReviewRatingStars(value: review.rating, size: 20),
              const SizedBox(width: 8),
              Text(
                '${review.rating} 分',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(review.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (review.petNames.isNotEmpty)
                _infoChip(Icons.pets, review.petNames.join('、')),
              if (review.roomTypeName.isNotEmpty)
                _infoChip(Icons.meeting_room, review.roomTypeName),
              if (review.nights > 0)
                _infoChip(Icons.nights_stay, '${review.nights} 晚'),
              if (review.startDate != null && review.endDate != null)
                _infoChip(Icons.calendar_month, _formatDateRange()),
            ],
          ),
          const SizedBox(height: 10),

          if (review.content.trim().isNotEmpty)
            Text(review.content, style: const TextStyle(height: 1.5)),

          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.imageUrls.map((url) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (review.hasReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '店家回覆${review.replyAt == null ? '' : '｜${_formatTimestamp(review.replyAt)}'}：\n${review.reply}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
