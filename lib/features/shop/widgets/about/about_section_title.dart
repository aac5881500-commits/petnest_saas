// lib/features/shop/widgets/about/about_section_title.dart
// 🐾 關於我們頁 共用區塊標題

import 'package:flutter/material.dart';

class AboutSectionTitle extends StatelessWidget {
  const AboutSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: const Color(0xFFC47A2C),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A2A1A),
          ),
        ),
      ],
    );
  }
}