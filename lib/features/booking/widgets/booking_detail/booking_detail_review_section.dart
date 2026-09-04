// lib/features/booking/widgets/booking_detail/booking_detail_review_section.dart
// ⭐ 客戶端訂單詳細頁：評價區塊
// 功能：完成訂單後顯示撰寫評價按鈕，已評論則顯示完成提示

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/pages/booking_review_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_card.dart';

class BookingDetailReviewSection extends StatelessWidget {
  const BookingDetailReviewSection({
    super.key,
    required this.bookingId,
    required this.data,
    required this.bookingStatus,
    this.titleOverride,
  });

  final String bookingId;
  final Map<String, dynamic> data;
  final String bookingStatus;
  final String? titleOverride;

  @override
  Widget build(BuildContext context) {
    final reviewed = data['reviewed'] == true;

    if (bookingStatus != 'completed') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reviewed ? Colors.green.shade100 : Colors.amber.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: reviewed ? _buildReviewCard() : _buildWriteReviewView(context),
    );
  }

  Widget _buildReviewCard() {
    final reviewId = (data['reviewId'] ?? '').toString();

    if (reviewId.isEmpty) {
      return _buildReviewedView();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return _buildReviewedView();
        }

        final review = ReviewModel.fromDoc(snapshot.data!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '我的評價',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ReviewCard(review: review),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingReviewPage(
                        bookingId: bookingId,
                        review: review,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('修改評價'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWriteReviewView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            Text(
              titleOverride ?? '住宿評價',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '分享這次${titleOverride ?? '住宿'}體驗，幫助其他飼主選擇適合的旅宿。',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingReviewPage(bookingId: bookingId),
                ),
              );
            },
            icon: const Icon(Icons.rate_review),
            label: const Text('撰寫評價'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewedView() {
    return Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade600),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '您已完成本次住宿評價，感謝您的分享。',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
