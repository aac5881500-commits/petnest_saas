// 檔案名稱：lib/features/admin/pages/admin_review_list_page.dart
// 功能說明：查看本店所有客戶評價，之後可延伸店家回覆
// ⭐ 店家後台評價管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_card.dart';
import 'package:petnest_saas/core/services/review_service.dart';

class AdminReviewListPage extends StatelessWidget {
  const AdminReviewListPage({super.key, required this.shopId});

  final String shopId;

  Future<void> _showReplyDialog(
    BuildContext context,
    ReviewModel review,
  ) async {
    final controller = TextEditingController(text: review.reply);

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(review.hasReply ? '修改店家回覆' : '回覆評價'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '請輸入店家回覆內容',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('送出'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    try {
      await ReviewService.instance.replyReview(
        reviewId: review.reviewId,
        reply: result,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已送出店家回覆')));
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('評價管理')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('shopId', isEqualTo: shopId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取評價失敗：${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data!.docs
              .map(ReviewModel.fromDoc)
              .where((review) => review.isVisible)
              .toList();

          if (reviews.isEmpty) {
            return const Center(child: Text('目前尚無評價'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReviewCard(review: review),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showReplyDialog(context, review),
                      icon: Icon(review.hasReply ? Icons.edit : Icons.reply),
                      label: Text(review.hasReply ? '修改回覆' : '回覆評價'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
