// lib/features/admin/widgets/admin_member_detail_badges.dart
// 👤 後台會員詳細頁小元件
// 功能：顯示會員標籤與統計小卡

import 'package:flutter/material.dart';

Widget adminMemberSmallBadge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

Widget adminMemberStatBox({
  required IconData icon,
  required Color color,
  required String value,
  required String label,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: value.length > 3 ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
