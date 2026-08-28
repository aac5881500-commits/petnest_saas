// lib/features/shop/widgets/inventory/inventory_status_chip.dart
// 📦 庫存狀態標籤
// 功能：用醒目顏色顯示正常、低庫存、缺貨、停用與即將到期。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';

class InventoryStatusChip extends StatelessWidget {
  const InventoryStatusChip({
    super.key,
    required this.item,
    this.showExpiry = true,
  });

  final InventoryItemModel item;
  final bool showExpiry;

  @override
  Widget build(BuildContext context) {
    final InventoryStockStatus status = item.stockStatus;
    final Color background;
    final Color foreground;

    switch (status) {
      case InventoryStockStatus.outOfStock:
        background = Colors.red.shade50;
        foreground = Colors.red.shade700;
        break;
      case InventoryStockStatus.low:
        background = Colors.orange.shade50;
        foreground = Colors.orange.shade800;
        break;
      case InventoryStockStatus.disabled:
        background = Colors.grey.shade200;
        foreground = Colors.grey.shade700;
        break;
      case InventoryStockStatus.normal:
        background = Colors.green.shade50;
        foreground = Colors.green.shade800;
        break;
    }

    final Widget statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        InventoryConstants.stockStatusLabel(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!showExpiry || !item.isExpiringSoon) {
      return statusChip;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        statusChip,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '即將到期',
            style: TextStyle(
              color: Colors.deepOrange.shade800,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
