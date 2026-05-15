// lib/features/shop/widgets/environment/environment_bottom_note.dart
// 🐾 環境介紹底部提醒卡
// 顯示住宿安排提醒文字

import 'package:flutter/material.dart';

class EnvironmentBottomNote extends StatelessWidget {
  const EnvironmentBottomNote({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD7A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFB87535),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6F5A43),
              ),
            ),
          ),
        ],
      ),
    );
  }
}