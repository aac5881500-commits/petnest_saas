// 檔案名稱：lib/features/shop/widgets/inventory/inventory_movement_tile.dart
// 功能說明：以顏色區分進貨／出庫／盤點，不顯示 Firebase technical ID。
// 📦 庫存異動列

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_movement_model.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_ui_format.dart';

class InventoryMovementTile extends StatelessWidget {
  const InventoryMovementTile({
    super.key,
    required this.movement,
    required this.unit,
  });

  final InventoryMovementModel movement;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentColor(movement.type);
    final bool increase = movement.quantityChange > 0;
    final String typeLabel = InventoryConstants.movementTypeLabel(
      movement.type,
    );
    final String sourceLabel = InventoryConstants.sourceTypeLabel(
      movement.sourceType,
    );
    final bool showSource = sourceLabel.isNotEmpty && sourceLabel != typeLabel;
    final String changeText =
        '${increase ? '+' : ''}${InventoryConstants.formatQuantity(movement.quantityChange)} $unit';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 42,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        typeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      changeText,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${InventoryConstants.formatQuantity(movement.stockBefore)} → ${InventoryConstants.formatQuantity(movement.stockAfter)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (movement.reason.isNotEmpty)
                  Text(
                    movement.reason,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (movement.note.isNotEmpty)
                  Text(
                    movement.note,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (showSource)
                  Text(
                    sourceLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                Text(
                  InventoryUiFormat.dateTime(movement.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.purchase:
      case InventoryMovementType.returnStock:
        return Colors.green.shade700;
      case InventoryMovementType.adjustment:
        return Colors.blue.shade700;
      case InventoryMovementType.manualOutbound:
      case InventoryMovementType.addon:
      case InventoryMovementType.pointRedemption:
      case InventoryMovementType.bookingSupply:
      case InventoryMovementType.futureStore:
        return Colors.orange.shade800;
    }
  }
}
