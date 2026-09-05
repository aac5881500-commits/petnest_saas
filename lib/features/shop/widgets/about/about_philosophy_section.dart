// 檔案名稱：lib/features/shop/widgets/about/about_philosophy_section.dart
// 功能說明：顯示店家的品牌理念，並依照首頁版本套用共用主題顏色
// 🐾 關於我們頁 品牌理念區塊

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/about/about_section_title.dart';

class AboutPhilosophySection extends StatelessWidget {
  const AboutPhilosophySection({super.key, required this.theme});

  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionTitle(icon: Icons.pets, title: '我們的理念', theme: theme),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: theme.cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _PhilosophyItem(
                  icon: Icons.favorite,
                  title: '安心',
                  text: '提供安全、乾淨、舒適的住宿環境',
                  theme: theme,
                ),

                const SizedBox(height: 24),

                _PhilosophyItem(
                  icon: Icons.pets,
                  title: '陪伴',
                  text: '細心觀察每隻貓咪的情緒與需求',
                  theme: theme,
                ),

                const SizedBox(height: 24),

                _PhilosophyItem(
                  icon: Icons.home,
                  title: '像家一樣',
                  text: '希望每一次入住都能安心放鬆',
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhilosophyItem extends StatelessWidget {
  const _PhilosophyItem({
    required this.icon,
    required this.title,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String text;
  final HomeThemeModel theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.primaryColor.withValues(alpha: 0.14),
          child: Icon(icon, size: 24, color: theme.primaryColor),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: theme.textColor.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
