// 檔案名稱：lib/features/admin/pages/admin_member_review_list_page.dart
// 功能說明：查看單一會員在本店留下的所有評價
// ⭐ 後台會員評價列表頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/booking/widgets/review_card.dart';

class AdminMemberReviewListPage extends StatelessWidget {
  const AdminMemberReviewListPage({
    super.key,
    required this.shopId,
    required this.userId,
    required this.memberName,
  });

  final String shopId;
  final String userId;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$memberName 的評價')),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('shopId', isEqualTo: shopId)
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('評價讀取失敗：${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews = snapshot.data!.docs;

          if (reviews.isEmpty) {
            return const Center(child: Text('尚無評價'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final doc = reviews[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ReviewCard(review: ReviewModel.fromDoc(doc)),
              );
            },
          );
        },
      ),
    );
  }
}
