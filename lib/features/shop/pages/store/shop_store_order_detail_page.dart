// lib/features/shop/pages/store/shop_store_order_detail_page.dart
// 🛒 後台商城訂單詳情

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/store_function_service.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';

class ShopStoreOrderDetailPage extends StatefulWidget {
  const ShopStoreOrderDetailPage({
    super.key,
    required this.shopId,
    required this.orderId,
    required this.canManage,
  });

  final String shopId;
  final String orderId;
  final bool canManage;

  @override
  State<ShopStoreOrderDetailPage> createState() =>
      _ShopStoreOrderDetailPageState();
}

class _ShopStoreOrderDetailPageState extends State<ShopStoreOrderDetailPage> {
  bool _touched = false;

  String get shopId => widget.shopId;
  String get orderId => widget.orderId;
  bool get canManage => widget.canManage;

  void _touchIfNeeded(StoreOrderModel order) {
    if (_touched) {
      return;
    }
    if (order.status != StoreConstants.statusPendingPayment) {
      return;
    }
    _touched = true;
    unawaited(
      StoreFunctionService.instance
          .updateStoreOrderStatus(
            shopId: shopId,
            orderId: orderId,
            action: 'touch',
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _run(BuildContext context, String action) async {
    try {
      await StoreFunctionService.instance.updateStoreOrderStatus(
        shopId: shopId,
        orderId: orderId,
        action: action,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商城訂單詳情')),
      body: StreamBuilder<StoreOrderModel?>(
        stream: StoreOrderService.instance.streamOrder(
          shopId: shopId,
          orderId: orderId,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<StoreOrderModel?> snapshot,
        ) {
          final StoreOrderModel? order = snapshot.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          _touchIfNeeded(order);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                order.orderCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${StoreConstants.statusLabel(order.status)} · '
                '${StoreConstants.paymentStatusLabel(order.paymentStatus)}',
              ),
              const SizedBox(height: 12),
              Text('會員：${order.customerName}'),
              Text('電話：${order.customerPhone}'),
              Text('履約：${StoreConstants.fulfillmentLabel(order.fulfillmentType)}'),
              if (order.shopAddressSnapshot.isNotEmpty)
                Text('自取地址：${order.shopAddressSnapshot}'),
              const Divider(height: 32),
              const Text('商品明細', style: TextStyle(fontWeight: FontWeight.w700)),
              ...order.items.map((StoreOrderItemModel item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(
                    'NT\$ ${item.unitPrice} × ${item.quantity}'
                    '${item.useInventory ? '\n庫存連動 ${item.inventoryItemName} ×${item.inventoryQuantityPerSale}' : ''}',
                  ),
                  trailing: Text('NT\$ ${item.subtotal}'),
                );
              }),
              const Divider(height: 32),
              Text('合計 NT\$ ${order.totalAmount}'),
              if (canManage) ...<Widget>[
                const SizedBox(height: 16),
                if (order.status == StoreConstants.statusPaid)
                  FilledButton(
                    onPressed: () => _run(context, 'start_preparing'),
                    child: const Text('開始備貨'),
                  ),
                if (order.status == StoreConstants.statusPreparing)
                  FilledButton(
                    onPressed: () => _run(context, 'mark_ready'),
                    child: const Text('標記可取貨'),
                  ),
                if (order.status == StoreConstants.statusReadyForPickup)
                  FilledButton(
                    onPressed: () => _run(context, 'complete'),
                    child: const Text('完成取貨'),
                  ),
                if (order.status != StoreConstants.statusCompleted &&
                    order.status != StoreConstants.statusCancelled)
                  TextButton(
                    onPressed: () => _run(context, 'cancel'),
                    child: Text(
                      '取消訂單',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
