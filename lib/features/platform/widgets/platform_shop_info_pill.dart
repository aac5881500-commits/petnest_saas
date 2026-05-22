// lib/features/platform/widgets/platform_shop_info_pill.dart
// 🏷️ 平台店家資訊膠囊
// 功能：顯示店家卡片的小資訊，例如公開狀態、方案、到期日、建立時間

import 'package:flutter/material.dart';

class PlatformShopInfoPill extends StatelessWidget {
  const PlatformShopInfoPill({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
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
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}