// lib/features/auth/widgets/my_shop_badges.dart
// 🏷️ 我的店家標籤列
// 功能：顯示店家角色、平台公開狀態等膠囊標籤

import 'package:flutter/material.dart';

class MyShopBadges extends StatelessWidget {
  const MyShopBadges({
    super.key,
    required this.role,
    required this.isPublic,
  });

  final String role;
  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(
          text: role,
          icon: Icons.admin_panel_settings,
        ),
        _Badge(
          text: isPublic ? '平台顯示' : '未公開',
          icon: Icons.visibility,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}