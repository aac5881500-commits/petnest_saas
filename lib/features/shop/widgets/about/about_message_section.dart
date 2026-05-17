// lib/features/shop/widgets/about/about_message_section.dart
// 🐾 關於我們頁 給毛爸媽的話區塊
// 從 Firestore 讀取店家自訂介紹文字

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_section_title.dart';

class AboutMessageSection extends StatelessWidget {
  const AboutMessageSection({
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

        final message = (shop['aboutMessage'] ??
                '出門在外，最放心不下的就是毛孩。\n\n'
                    '我們知道每一隻貓咪都有自己的個性，有些需要安靜、有些需要陪伴，'
                    '有些只是需要一個可以安心躲起來的小角落。\n\n'
                    '所以我們會用耐心觀察、溫柔陪伴，讓牠們在這裡慢慢放鬆，'
                    '也讓您每一次出門都能更放心。')
            .toString();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF4),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFF1D7B7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AboutSectionTitle(
                  icon: Icons.favorite_border,
                  title: '給毛爸媽的話',
                ),

                const SizedBox(height: 18),

                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.85,
                    color: Color(0xFF5C4A3A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}