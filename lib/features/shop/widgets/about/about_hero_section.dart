// lib/features/shop/widgets/about/about_hero_section.dart
// 🐾 關於我們頁 Hero 大圖區塊
// 從 Firestore 讀取關於我們主標題與介紹文字

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class AboutHeroSection extends StatelessWidget {
  const AboutHeroSection({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder: (context, snapshot) {
        final shop = snapshot.data ?? {};

        final title = (shop['aboutTitle'] ??
                '用心照顧每一隻貓咪，讓牠們在這裡安心生活。')
            .toString();

        final description = (shop['aboutDescription'] ??
                '我們相信，每一隻貓咪都是家人。當您需要暫時離開時，我們會像您一樣，用心陪伴與照顧。')
            .toString();

            final aboutImageUrl =
    (shop['aboutImageUrl'] ?? '').toString();

        return Container(
          height: 390,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
  aboutImageUrl.isNotEmpty
      ? aboutImageUrl
      : 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?q=80&w=1200',
),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
  const Color(0xFF2A1B12).withValues(alpha: 0.72),
  const Color(0xFF2A1B12).withValues(alpha: 0.34),
  Colors.transparent,
],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.45,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                const Icon(
                  Icons.pets,
                  color: Color(0xFFC47A2C),
                  size: 34,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}