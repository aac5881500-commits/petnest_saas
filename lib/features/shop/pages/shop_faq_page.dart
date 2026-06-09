// lib/features/shop/pages/shop_faq_page.dart
// ❓ 前台常見問題頁
// 功能：顯示店家已上架的常見問題，並依 showFaqSection 控制是否開放

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShopFaqPage extends StatelessWidget {
  const ShopFaqPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('常見問題'),
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .snapshots(),
        builder: (context, shopSnapshot) {
          if (!shopSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final shopData = shopSnapshot.data!.data() as Map<String, dynamic>?;

          final showFaqSection = shopData?['showFaqSection'] != false;

          if (!showFaqSection) {
            return const Center(child: Text('此功能尚未開放'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .collection('faqs')
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

                final aSort = aData['sortOrder'] ?? 999;
                final bSort = bData['sortOrder'] ?? 999;

                return aSort.compareTo(bSort);
              });

              if (docs.isEmpty) {
                return const Center(child: Text('目前尚無常見問題'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  final question = data['question']?.toString() ?? '未命名問題';
                  final answer = data['answer']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF0E0CC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.help_outline,
                              color: Color(0xFFB86B18),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                question,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3A2A1A),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        const Divider(height: 1, color: Color(0xFFF0E0CC)),

                        const SizedBox(height: 12),

                        Text(
                          answer.isEmpty ? '尚未填寫回答' : answer,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: Color(0xFF5C4A3A),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
