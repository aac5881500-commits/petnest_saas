// 檔案名稱：lib/features/shop/pages/shop_announcement_page.dart
// 功能說明：顯示店家已上架公告列表，並依 showAnnouncementSection 控制是否開放
// 📢 前台店家公告頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/announcement/shop_announcement_card.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_detail_page.dart';

class ShopAnnouncementPage extends StatelessWidget {
  const ShopAnnouncementPage({
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
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '最新公告',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
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

          final showAnnouncementSection =
              shopData?['showAnnouncementSection'] != false;

          if (!showAnnouncementSection) {
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
                .collection('announcements')
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

                final aTime = aData['createdAt'];
                final bTime = bData['createdAt'];

                if (aTime is! Timestamp || bTime is! Timestamp) return 0;

                return bTime.compareTo(aTime);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    '目前尚無公告',
                    style: TextStyle(
                      fontSize: 16,
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

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopAnnouncementDetailPage(
                            data: data,
                            theme: theme,
                          ),
                        ),
                      );
                    },
                    child: ShopAnnouncementCard(data: data, theme: theme),
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
