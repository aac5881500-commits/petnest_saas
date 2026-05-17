// lib/features/shop/widgets/about/about_philosophy_section.dart
// 🐾 關於我們頁 品牌理念區塊

import 'package:flutter/material.dart';

import 'package:petnest_saas/features/shop/widgets/about/about_section_title.dart';

class AboutPhilosophySection extends StatelessWidget {
  const AboutPhilosophySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AboutSectionTitle(
            icon: Icons.pets,
            title: '我們的理念',
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: const [
                _PhilosophyItem(
                  icon: Icons.favorite,
                  title: '安心',
                  text: '提供安全、乾淨、舒適的住宿環境',
                ),

                SizedBox(height: 24),

                _PhilosophyItem(
                  icon: Icons.pets,
                  title: '陪伴',
                  text: '細心觀察每隻貓咪的情緒與需求',
                ),

                SizedBox(height: 24),

                _PhilosophyItem(
                  icon: Icons.home,
                  title: '像家一樣',
                  text: '希望每一次入住都能安心放鬆',
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
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFFFE7C8),
          child: Icon(
            icon,
            size: 24,
            color: const Color(0xFFC47A2C),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3A2A1A),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF6A5848),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}