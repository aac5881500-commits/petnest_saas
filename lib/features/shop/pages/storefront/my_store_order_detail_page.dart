// lib/features/shop/pages/storefront/my_store_order_detail_page.dart
// 🛒 會員商城訂單詳情

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/payment_service.dart';
import 'package:petnest_saas/core/services/store_function_service.dart';
import 'package:petnest_saas/core/services/store_order_service.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/storefront_theme.dart';

class MyStoreOrderDetailPage extends StatefulWidget {
  const MyStoreOrderDetailPage({
    super.key,
    required this.shopId,
    required this.orderId,
    this.theme = HomeThemeModel.modernDefault,
  });

  final String shopId;
  final String orderId;
  final HomeThemeModel theme;

  @override
  State<MyStoreOrderDetailPage> createState() => _MyStoreOrderDetailPageState();
}

class _MyStoreOrderDetailPageState extends State<MyStoreOrderDetailPage> {
  bool _touched = false;

  String get shopId => widget.shopId;
  String get orderId => widget.orderId;
  HomeThemeModel get theme => widget.theme;

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

  Future<void> _pay(BuildContext context, StoreOrderModel order) async {
    try {
      final List<String> methods = await PaymentService.instance
          .resolveAvailableMethods(
            shopId: shopId,
            amountType: PaymentAmountType.full,
          );
      final List<String> online = methods
          .where(PaymentMethodType.isOnlinePayment)
          .toList();
      if (online.isEmpty) {
        throw Exception('店家目前沒有可用的線上付款方式');
      }

      final String requestId = FirebaseFirestore.instance
          .collection('payments')
          .doc()
          .id;
      final paymentResult = await PaymentFunctionService.instance.createPayment(
        request: CreatePaymentRequestModel(
          shopId: shopId,
          sourceType: PaymentSourceType.storeOrder,
          sourceId: order.id,
          paymentMethod: online.first,
          amountType: PaymentAmountType.full,
          paymentPurpose: PaymentPurpose.full,
          amount: order.totalAmount,
          requestId: requestId,
        ),
      );

      if (!context.mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EcpayPaymentPage(
            paymentHtml: paymentResult.paymentHtml,
            paymentId: paymentResult.paymentId,
            shopId: shopId,
            storeOrderId: order.id,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _cancel(BuildContext context) async {
    try {
      await StoreFunctionService.instance.updateStoreOrderStatus(
        shopId: shopId,
        orderId: orderId,
        action: 'cancel',
        reason: '會員取消',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontTheme(
      shopId: shopId,
      shopTheme: widget.theme,
      builder: (BuildContext context, HomeThemeModel theme, _) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textColor,
            title: const Text('商城訂單'),
          ),
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
                  Text(
                    order.orderCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(StoreConstants.statusLabel(order.status)),
                  const SizedBox(height: 12),
                  Text(
                    StoreConstants.fulfillmentLabel(order.fulfillmentType),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (order.status ==
                      StoreConstants.statusReadyForPickup) ...<Widget>[
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFFFFF7ED),
                      child: ListTile(
                        leading: const Icon(Icons.storefront),
                        title: const Text('可取貨 · 店內自取'),
                        subtitle: Text(
                          order.shopAddressSnapshot.isEmpty
                              ? '請至店家櫃台取貨'
                              : order.shopAddressSnapshot,
                        ),
                      ),
                    ),
                  ],
                  if (order.status == StoreConstants.statusPreparing ||
                      order.status == StoreConstants.statusPaid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('店家備貨中，可取貨時會顯示自取資訊。'),
                    ),
                  if (order.pickupNote.isNotEmpty) Text(order.pickupNote),
                  const Divider(height: 32),
                  const Text(
                    '商品明細',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...order.items.map((StoreOrderItemModel item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName),
                      subtitle: Text(
                        item.hasPromotionSnapshot
                            ? '原價 NT\$ ${item.snapshotOriginalUnitPrice} → '
                                  'NT\$ ${item.snapshotFinalUnitPrice} × ${item.snapshotPurchaseQuantity}'
                                  '${item.snapshotFreeQuantity > 0 ? '\n購買 ${item.snapshotPurchaseQuantity} 件　贈送 ${item.snapshotFreeQuantity} 件　共收到 ${item.snapshotFulfillmentQuantity} 件' : ''}'
                                  '${item.itemPromotionName.isEmpty ? '' : '\n${item.itemPromotionName}'}'
                                  '${item.promotionName.isEmpty ? '' : '\n${item.promotionName}'}'
                            : 'NT\$ ${item.unitPrice} × ${item.quantity}',
                      ),
                      trailing: Text('NT\$ ${item.subtotal}'),
                    );
                  }),
                  const SizedBox(height: 8),
                  if ((order.originalSubtotal ?? order.subtotal) >
                      order.totalAmount) ...<Widget>[
                    Text(
                      '商品原價 NT\$ ${order.originalSubtotal ?? order.subtotal}',
                    ),
                    Text('活動優惠 -NT\$ ${order.promotionDiscount}'),
                  ],
                  Text(
                    '合計 NT\$ ${order.totalAmount}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (order.status ==
                      StoreConstants.statusPendingPayment) ...<Widget>[
                    FilledButton(
                      onPressed: () => _pay(context, order),
                      child: const Text('前往付款'),
                    ),
                    TextButton(
                      onPressed: () => _cancel(context),
                      child: const Text('取消訂單'),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
