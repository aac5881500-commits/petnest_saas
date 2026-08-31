// lib/features/shop/widgets/store/store_status_chip.dart
// 🛒 商城後台狀態 Chip

import 'package:flutter/material.dart';

class StoreStatusChip extends StatelessWidget {
  const StoreStatusChip({
    super.key,
    required this.label,
    this.tone = StoreStatusTone.neutral,
  });

  final String label;
  final StoreStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      StoreStatusTone.success => const Color(0xFF2E7D32),
      StoreStatusTone.warning => const Color(0xFFC45C26),
      StoreStatusTone.danger => const Color(0xFFB3261E),
      StoreStatusTone.info => Theme.of(context).colorScheme.primary,
      StoreStatusTone.neutral => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

enum StoreStatusTone { success, warning, danger, info, neutral }
