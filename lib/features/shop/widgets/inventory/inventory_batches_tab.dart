// 檔案名稱：lib/features/shop/widgets/inventory/inventory_batches_tab.dart
// 功能說明：顯示進貨歷史。批次是進貨紀錄，不追蹤 FIFO 剩餘量。
// 📦 庫存詳情「進貨紀錄」分頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/models/inventory_batch_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';
import 'package:petnest_saas/features/shop/widgets/inventory/inventory_ui_format.dart';

class InventoryBatchesTab extends StatelessWidget {
  const InventoryBatchesTab({
    super.key,
    required this.shopId,
    required this.item,
    required this.canViewCost,
  });

  final String shopId;
  final InventoryItemModel item;
  final bool canViewCost;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryBatchModel>>(
      stream: InventoryService.instance.streamBatches(
        shopId: shopId,
        itemId: item.id,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<InventoryBatchModel>> snapshot,
          ) {
            final List<InventoryBatchModel> batches =
                snapshot.data ?? const <InventoryBatchModel>[];

            if (snapshot.connectionState == ConnectionState.waiting &&
                batches.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (batches.isEmpty) {
              return const Center(child: Text('尚無進貨紀錄'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: batches.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      '進貨紀錄',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }

                return _BatchCard(
                  batch: batches[index - 1],
                  unit: item.unit,
                  canViewCost: canViewCost,
                );
              },
            );
          },
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.unit,
    required this.canViewCost,
  });

  final InventoryBatchModel batch;
  final String unit;
  final bool canViewCost;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '本批進貨 ${InventoryConstants.formatQuantity(batch.quantityReceived)} $unit',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (canViewCost) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '\$${InventoryConstants.formatMoney(batch.unitCost)} / $unit',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            Text(
              '總成本 \$${InventoryConstants.formatMoney(batch.totalCost)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          if (batch.batchNo.isNotEmpty)
            _Line(label: '批次號', value: batch.batchNo),
          _Line(label: '進貨日期', value: InventoryUiFormat.date(batch.receivedAt)),
          if (batch.expiryDate != null)
            _Line(
              label: '有效期限',
              value: InventoryUiFormat.date(batch.expiryDate!),
            ),
          if (batch.supplier.isNotEmpty)
            _Line(label: '供應商', value: batch.supplier),
          if (batch.note.isNotEmpty) _Line(label: '備註', value: batch.note),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }
}
