// 檔案名稱：lib/features/shop/widgets/inventory/inventory_linkage_badge.dart
// 功能說明：列表與總覽共用的連動摘要 chip。資料未齊時不顯示成未連動。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_linkage_service.dart';

class InventoryLinkageBadge extends StatelessWidget {
  const InventoryLinkageBadge({
    super.key,
    required this.snapshot,
    required this.item,
    this.onTap,
  });

  final InventoryLinkageSnapshot snapshot;
  final InventoryItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _BadgeStyle style = _style(colors);
    final int enabledCount = snapshot.canClassify
        ? snapshot.enabledCountOf(item.id)
        : 0;
    final bool risky =
        snapshot.canClassify &&
        enabledCount > 0 &&
        (item.stockStatus == InventoryStockStatus.low ||
            item.stockStatus == InventoryStockStatus.outOfStock);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _Chip(
          label: style.label,
          background: style.background,
          foreground: style.foreground,
          onTap: onTap,
        ),
        if (risky)
          _Chip(
            label: '影響 $enabledCount 項上架服務',
            background: item.stockStatus == InventoryStockStatus.outOfStock
                ? Colors.red.shade50
                : Colors.orange.shade50,
            foreground: item.stockStatus == InventoryStockStatus.outOfStock
                ? Colors.red.shade700
                : Colors.orange.shade900,
            onTap: onTap,
          ),
      ],
    );
  }

  _BadgeStyle _style(ColorScheme colors) {
    if (!snapshot.ready) {
      return const _BadgeStyle(
        label: '連動讀取中',
        background: Color(0xFFF1F3F6),
        foreground: Color(0xFF667085),
      );
    }
    if (snapshot.hasError) {
      return const _BadgeStyle(
        label: '連動暫不可用',
        background: Color(0xFFF1F3F6),
        foreground: Color(0xFF667085),
      );
    }
    final int count = snapshot.countOf(item.id);
    if (count == 0) {
      return const _BadgeStyle(
        label: '未連動',
        background: Color(0xFFF1F3F6),
        foreground: Color(0xFF667085),
      );
    }
    return _BadgeStyle(
      label: '已連動 $count 項',
      background: colors.primary.withValues(alpha: 0.1),
      foreground: colors.primary,
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
    if (onTap == null) {
      return chip;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
