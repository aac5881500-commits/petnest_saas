// lib/features/shop/widgets/inventory/inventory_movements_tab.dart
// 📦 庫存詳情「異動流水」分頁
// 功能：顯示有上限的異動歷史，避免一次載入無限資料。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/inventory_movement_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_movement_tile.dart';

class InventoryMovementsTab extends StatelessWidget {
  const InventoryMovementsTab({
    super.key,
    required this.shopId,
    required this.item,
  });

  final String shopId;
  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryMovementModel>>(
      stream: InventoryService.instance.streamMovements(
        shopId: shopId,
        itemId: item.id,
        limit: InventoryConstants.movementPageLimit,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<InventoryMovementModel>> snapshot,
      ) {
        final List<InventoryMovementModel> movements =
            snapshot.data ?? const <InventoryMovementModel>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            movements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (movements.isEmpty) {
          return const Center(child: Text('尚無異動紀錄'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: movements.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  movements.length >= InventoryConstants.movementPageLimit
                      ? '最近 ${InventoryConstants.movementPageLimit} 筆異動'
                      : '異動流水',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return InventoryMovementTile(
              movement: movements[index - 1],
              unit: item.unit,
            );
          },
        );
      },
    );
  }
}
