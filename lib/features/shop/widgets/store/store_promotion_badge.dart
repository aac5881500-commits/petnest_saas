// 檔案名稱：lib/features/shop/widgets/store/store_promotion_badge.dart
// 功能說明：商城促銷 Badge 共用元件

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/store_promotion_model.dart';
import 'package:petnest_saas/core/services/store_pricing_service.dart';

class StorePromotionBadge extends StatelessWidget {
  const StorePromotionBadge({
    super.key,
    required this.line,
    this.color,
    this.compact = true,
  });

  final StorePricedLine line;
  final Color? color;
  final bool compact;

  static String labelOf(StorePricedLine line) {
    if (line.offerBadge.trim().isNotEmpty) {
      return line.offerBadge.trim();
    }
    if (line.promotion?.type == StorePromotionTypes.flash) {
      return '限時';
    }
    if (line.promotion != null) {
      return '優惠';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String label = labelOf(line);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final Color tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class StoreMoney {
  static String ntd(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int remaining = digits.length - i;
      grouped.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        grouped.write(',');
      }
    }
    return 'NT\$${negative ? '-' : ''}$grouped';
  }
}
