// 檔案名稱：lib/features/shop/pages/shop_faq_page.dart
// 功能說明：顯示店家已上架的常見問題，並依 showFaqSection 控制是否開放
// ❓ 前台常見問題頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class ShopFaqPage extends StatelessWidget {
  const ShopFaqPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.classicDefault,
  });

  final String shopId;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          '常見問題',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
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
            return Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            );
          }

          final shopData = shopSnapshot.data!.data() as Map<String, dynamic>?;

          final showFaqSection = shopData?['showFaqSection'] != false;

          if (!showFaqSection) {
            return Center(
              child: Text(
                '此功能尚未開放',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.65),
                ),
              ),
            );
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
                return Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                );
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
                return Center(
                  child: Text(
                    '目前尚無常見問題',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.65),
                    ),
                  ),
                );
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
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                            Icon(
                              Icons.help_outline,
                              color: theme.primaryColor,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                question,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Divider(height: 1, color: theme.cardBorderColor),

                        const SizedBox(height: 12),

                        Text(
                          answer.isEmpty ? '尚未填寫回答' : answer,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: theme.textColor.withValues(alpha: 0.75),
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
