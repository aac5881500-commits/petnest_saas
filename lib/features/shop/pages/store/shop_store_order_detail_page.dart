// 檔案名稱：lib/features/shop/pages/store/shop_store_order_detail_page.dart
// 功能說明：後台商城訂單詳情

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/store_function_service.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_status_chip.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
        builder: (BuildContext context, AsyncSnapshot<StoreOrderModel?> snapshot) {
          final StoreOrderModel? order = snapshot.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          _touchIfNeeded(order);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _section('訂單資訊', <Widget>[
                Text(
                  order.orderCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    StoreStatusChip(
                      label: StoreConstants.statusLabel(order.status),
                      tone: StoreStatusTone.info,
                    ),
                    StoreStatusChip(
                      label: StoreConstants.paymentStatusLabel(
                        order.paymentStatus,
                      ),
                    ),
                  ],
                ),
                Text('會員：${order.customerName}'),
                Text('電話：${order.customerPhone}'),
              ]),
              _section('商品明細', <Widget>[
                ...order.items.map((StoreOrderItemModel item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('原價 NT\$ ${item.snapshotOriginalUnitPrice}'),
                        if (item.itemPromotionName.isNotEmpty)
                          Text('商品優惠 ${item.itemPromotionName}'),
                        if (item.hasPromotionSnapshot &&
                            item.promotionName.isNotEmpty)
                          Text(
                            '活動優惠 ${item.promotionName}'
                            ' -NT\$ ${item.snapshotOriginalUnitPrice - item.snapshotFinalUnitPrice}',
                          ),
                        Text('購買：${item.snapshotPurchaseQuantity} 件'),
                        if (item.snapshotFreeQuantity > 0)
                          Text('贈送：${item.snapshotFreeQuantity} 件'),
                        Text('需備貨：${item.snapshotFulfillmentQuantity} 件'),
                        if (item.useInventory)
                          Text(
                            '中央庫存：已扣 ${item.snapshotInventoryDeducted} '
                            '${item.inventoryUnit.trim().isEmpty ? '件' : item.inventoryUnit}',
                          ),
                        Text(
                          '成交價 NT\$ ${item.snapshotFinalUnitPrice} × ${item.snapshotPurchaseQuantity}',
                        ),
                        Text('小計 NT\$ ${item.subtotal}'),
                      ],
                    ),
                  );
                }),
              ]),
              _section('促銷優惠', <Widget>[
                Text('商品原價 NT\$ ${order.originalSubtotal ?? order.subtotal}'),
                if (order.itemPromotionDiscount > 0)
                  Text('商品優惠 -NT\$ ${order.itemPromotionDiscount}'),
                if (order.campaignDiscount > 0)
                  Text('活動優惠 -NT\$ ${order.campaignDiscount}'),
                if (order.quantityDiscount > 0)
                  Text('滿件優惠 -NT\$ ${order.quantityDiscount}'),
                if (order.amountDiscount > 0)
                  Text('滿額優惠 -NT\$ ${order.amountDiscount}'),
                if (order.itemPromotionDiscount == 0 &&
                    order.campaignDiscount == 0 &&
                    order.quantityDiscount == 0 &&
                    order.amountDiscount == 0 &&
                    order.promotionDiscount > 0)
                  Text('活動優惠 -NT\$ ${order.promotionDiscount}'),
                Text(
                  '應付 NT\$ ${order.totalAmount}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ]),
              _section('付款資訊', <Widget>[
                Text(StoreConstants.paymentStatusLabel(order.paymentStatus)),
                if (order.lastPaymentId.isNotEmpty)
                  Text('付款單：${order.lastPaymentId}'),
              ]),
              _section('取貨資訊', <Widget>[
                Text(StoreConstants.fulfillmentLabel(order.fulfillmentType)),
                if (order.shopAddressSnapshot.isNotEmpty)
                  Text(order.shopAddressSnapshot),
                if (order.pickupNote.isNotEmpty) Text(order.pickupNote),
              ]),
              _section('操作紀錄', <Widget>[
                Text('建立：${_time(order.createdAt)}'),
                if (order.paidAt != null) Text('付款：${_time(order.paidAt!)}'),
                if (order.preparingAt != null)
                  Text('備貨：${_time(order.preparingAt!)}'),
                if (order.readyForPickupAt != null)
                  Text('可取貨：${_time(order.readyForPickupAt!)}'),
                if (order.completedAt != null)
                  Text('完成：${_time(order.completedAt!)}'),
                if (order.cancelledAt != null)
                  Text('取消：${_time(order.cancelledAt!)}'),
              ]),
              if (canManage) ...<Widget>[
                const SizedBox(height: 8),
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

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  String _time(DateTime value) {
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
