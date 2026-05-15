// lib/features/shop/widgets/environment/environment_section_title.dart
// 🐾 環境介紹區塊標題
// 顯示 icon + 標題

import 'package:flutter/material.dart';

class EnvironmentSectionTitle extends StatelessWidget {
  const EnvironmentSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFFB87535),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3A2A1A),
            ),
          ),
        ],
      ),
    );
  }
}