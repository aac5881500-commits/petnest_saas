// lib/features/platform/widgets/platform_shop_status_pill.dart
// 🟢 平台店家狀態膠囊
// 功能：顯示店家目前狀態（正常 / 停權 / 待審核）

import 'package:flutter/material.dart';

class PlatformShopStatusPill extends StatelessWidget {
  const PlatformShopStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
