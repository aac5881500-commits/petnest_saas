// lib/features/shop/pages/shop_announcement_page.dart
// 📢 前台店家公告頁
// 功能：顯示店家已上架公告列表

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/announcement/shop_announcement_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_detail_page.dart';

class ShopAnnouncementPage extends StatelessWidget {
  const ShopAnnouncementPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('最新公告'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('announcements')
            .where('isPublished', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList();

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['createdAt'];
            final bTime = bData['createdAt'];

            if (aTime is! Timestamp || bTime is! Timestamp) return 0;

            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                '目前尚無公告',
                style: TextStyle(fontSize: 16, color: Color(0xFF9A7B55)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopAnnouncementDetailPage(data: data),
                    ),
                  );
                },
                child: ShopAnnouncementCard(data: data),
              );
            },
          );
        },
      ),
    );
  }
}
