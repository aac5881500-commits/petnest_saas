// lib/features/shop/widgets/shop_section_title.dart
// 🏷️ 店家首頁區塊標題
// 用於前台首頁分區，例如：住宿服務、了解我們

import 'package:flutter/material.dart';

class ShopSectionTitle extends StatelessWidget {
  const ShopSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.actionText = '',
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String actionText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFFF8A2A),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3A2A1A),
          ),
        ),
        const Spacer(),
        if (actionText.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9A7B55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}