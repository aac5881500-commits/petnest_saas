// lib/features/shop/widgets/about/about_hero_section.dart
// 🐾 關於我們頁 Hero 大圖區塊
// 功能：從 Firestore 讀取關於我們主標題、介紹文字與圖片，
// 並依照首頁版本套用共用主題顏色

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class AboutHeroSection extends StatelessWidget {
  const AboutHeroSection({
    super.key,
    required this.shopId,
    required this.theme,
  });

  final String shopId;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(shopId),
      builder: (context, snapshot) {
        final shop = snapshot.data ?? {};

        final title = (shop['aboutTitle'] ?? '用心照顧每一隻貓咪，讓牠們在這裡安心生活。')
            .toString();

        final description =
            (shop['aboutDescription'] ??
                    '我們相信，每一隻貓咪都是家人。當您需要暫時離開時，'
                        '我們會像您一樣，用心陪伴與照顧。')
                .toString();

        final aboutImageUrl = (shop['aboutImageUrl'] ?? '').toString();

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

                Icon(Icons.pets, color: theme.primaryColor, size: 34),
              ],
            ),
          ),
        );
      },
    );
  }
}
