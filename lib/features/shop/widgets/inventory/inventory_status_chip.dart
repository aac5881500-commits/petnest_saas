// lib/features/shop/widgets/inventory/inventory_status_chip.dart
// 📦 庫存狀態標籤
// 功能：用醒目顏色顯示正常、低庫存、缺貨、停用與即將到期。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';

class InventoryStatusChip extends StatelessWidget {
  const InventoryStatusChip({super.key, required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final InventoryStockStatus status = item.stockStatus;
    final Color background;
    final Color foreground;

    switch (status) {
      case InventoryStockStatus.outOfStock:
        background = Colors.red.shade100;
        foreground = Colors.red.shade800;
        break;
      case InventoryStockStatus.low:
        background = Colors.orange.shade100;
        foreground = Colors.orange.shade800;
        break;
      case InventoryStockStatus.disabled:
        background = Colors.grey.shade300;
        foreground = Colors.grey.shade800;
        break;
      case InventoryStockStatus.normal:
        background = Colors.green.shade100;
        foreground = Colors.green.shade800;
        break;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        Chip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          label: Text(
            InventoryConstants.stockStatusLabel(status),
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: background,
          padding: EdgeInsets.zero,
        ),
        if (item.isExpiringSoon)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(
              '即將到期',
              style: TextStyle(
                color: Colors.deepOrange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.deepOrange.shade50,
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }
}
