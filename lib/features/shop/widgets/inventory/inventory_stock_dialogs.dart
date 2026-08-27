// lib/features/shop/widgets/inventory/inventory_stock_dialogs.dart
// 📦 進貨、手動出庫與盤點確認對話框
// 功能：高風險庫存操作需確認後才寫入，並同時建立批次或異動流水。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/inventory_stock_service.dart';

Future<void> showInventoryReceiveDialog({
  required BuildContext context,
  required InventoryItemModel item,
  required bool canViewCost,
}) async {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitCostController = TextEditingController();
  final TextEditingController batchNoController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  DateTime receivedAt = DateTime.now();
  DateTime? expiryDate;
  bool submitting = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          final num quantity = num.tryParse(quantityController.text.trim()) ?? 0;
          final num unitCost = num.tryParse(unitCostController.text.trim()) ?? 0;
          final num totalCost = quantity * unitCost;

          return AlertDialog(
            title: Text('進貨「${item.name}」'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '進貨數量',
                      suffixText: item.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (canViewCost) ...<Widget>[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: unitCostController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '本批進貨單價',
                        prefixText: '\$ ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '本批總成本：\$${InventoryConstants.formatMoney(totalCost)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: batchNoController,
                    decoration: const InputDecoration(labelText: '批次號（可選）'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('進貨日期'),
                    subtitle: Text(_formatDate(receivedAt)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? selected = await showDatePicker(
                        context: context,
                        initialDate: receivedAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (selected != null) {
                        setState(() => receivedAt = selected);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('有效期限（可選）'),
                    subtitle: Text(
                      expiryDate == null ? '未設定' : _formatDate(expiryDate!),
                    ),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final DateTime? selected = await showDatePicker(
                        context: context,
                        initialDate: expiryDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (selected != null) {
                        setState(() => expiryDate = selected);
                      }
                    },
                  ),
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(labelText: '供應商（可選）'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: '備註'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (quantity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入進貨數量')),
                          );
                          return;
                        }

                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext confirmContext) {
                            return AlertDialog(
                              title: const Text('確認進貨'),
                              content: Text(
                                '確定進貨 ${InventoryConstants.formatQuantity(quantity)} ${item.unit}？',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: const Text('返回'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: const Text('確認'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed != true) {
                          return;
                        }

                        setState(() => submitting = true);

                        try {
                          await InventoryStockService.instance.receiveStock(
                            shopId: item.shopId,
                            itemId: item.id,
                            quantity: quantity,
                            unitCost: canViewCost ? unitCost : 0,
                            receivedAt: receivedAt,
                            batchNo: batchNoController.text,
                            expiryDate: expiryDate,
                            supplier: supplierController.text,
                            note: noteController.text,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('進貨完成')),
                            );
                          }
                        } catch (error) {
                          setState(() => submitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(InventoryException.userMessage(error)),
                              ),
                            );
                          }
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('確認進貨'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showInventoryOutboundDialog({
  required BuildContext context,
  required InventoryItemModel item,
}) async {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  InventoryOutboundReason reason = InventoryOutboundReason.inStoreUse;
  bool submitting = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          return AlertDialog(
            title: Text('手動出庫「${item.name}」'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '目前庫存：${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '出庫數量',
                      suffixText: item.unit,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<InventoryOutboundReason>(
                    initialValue: reason,
                    decoration: const InputDecoration(labelText: '原因'),
                    items: InventoryOutboundReason.values.map((
                      InventoryOutboundReason itemReason,
                    ) {
                      return DropdownMenuItem<InventoryOutboundReason>(
                        value: itemReason,
                        child: Text(
                          InventoryConstants.outboundReasonLabel(itemReason),
                        ),
                      );
                    }).toList(),
                    onChanged: (InventoryOutboundReason? value) {
                      if (value != null) {
                        setState(() => reason = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: '備註'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final num quantity =
                            num.tryParse(quantityController.text.trim()) ?? 0;

                        if (quantity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入出庫數量')),
                          );
                          return;
                        }

                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext confirmContext) {
                            return AlertDialog(
                              title: const Text('確認出庫'),
                              content: Text(
                                '確定出庫 ${InventoryConstants.formatQuantity(quantity)} ${item.unit}？\n此操作會減少庫存並留下流水。',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: const Text('返回'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: const Text('確認'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed != true) {
                          return;
                        }

                        setState(() => submitting = true);

                        try {
                          await InventoryStockService.instance.manualOutbound(
                            shopId: item.shopId,
                            itemId: item.id,
                            quantity: quantity,
                            reason: reason,
                            note: noteController.text,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('出庫完成')),
                            );
                          }
                        } catch (error) {
                          setState(() => submitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(InventoryException.userMessage(error)),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('確認出庫'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showInventoryAdjustDialog({
  required BuildContext context,
  required InventoryItemModel item,
}) async {
  final TextEditingController countedController = TextEditingController(
    text: InventoryConstants.formatQuantity(item.currentStock),
  );
  final TextEditingController noteController = TextEditingController();
  bool submitting = false;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          final num counted =
              num.tryParse(countedController.text.trim()) ?? item.currentStock;
          final num difference = InventoryConstants.roundQuantity(
            counted - item.currentStock,
          );

          return AlertDialog(
            title: Text('盤點「${item.name}」'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '系統庫存：${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit}',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: countedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '實際盤點',
                      suffixText: item.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '差異：${difference > 0 ? '+' : ''}${InventoryConstants.formatQuantity(difference)} ${item.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: difference < 0
                          ? Colors.red
                          : difference > 0
                          ? Colors.green.shade700
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: '備註'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final num countedStock =
                            num.tryParse(countedController.text.trim()) ?? -1;

                        if (countedStock < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入實際盤點數量')),
                          );
                          return;
                        }

                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext confirmContext) {
                            return AlertDialog(
                              title: const Text('確認盤點調整'),
                              content: Text(
                                '系統庫存 ${InventoryConstants.formatQuantity(item.currentStock)} ${item.unit} 將調整為 ${InventoryConstants.formatQuantity(countedStock)} ${item.unit}。',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: const Text('返回'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: const Text('確認'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed != true) {
                          return;
                        }

                        setState(() => submitting = true);

                        try {
                          await InventoryStockService.instance.adjustStock(
                            shopId: item.shopId,
                            itemId: item.id,
                            countedStock: countedStock,
                            note: noteController.text,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('盤點調整完成')),
                            );
                          }
                        } catch (error) {
                          setState(() => submitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(InventoryException.userMessage(error)),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('確認調整'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatDate(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
