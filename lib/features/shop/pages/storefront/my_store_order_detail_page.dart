// 檔案名稱：lib/features/shop/pages/storefront/my_store_order_detail_page.dart
// 功能說明：會員商城訂單詳情

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/store_order_model.dart';
import 'package:petnest_saas/core/models/payment_model.dart';
import 'package:petnest_saas/core/services/store_payment_recovery.dart';
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
    this.preferredPaymentMethod = '',
  });

  final String shopId;
  final String orderId;
  final HomeThemeModel theme;
  final String preferredPaymentMethod;

  @override
  State<MyStoreOrderDetailPage> createState() => _MyStoreOrderDetailPageState();
}

class _MyStoreOrderDetailPageState extends State<MyStoreOrderDetailPage> {
  bool _touched = false;
  bool _busy = false;
  String? _paymentRequestId;
  late Stream<StoreOrderModel?> _orderStream;

  String get shopId => widget.shopId;
  String get orderId => widget.orderId;
  HomeThemeModel get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  void _loadOrder() {
    _orderStream = StoreOrderService.instance.streamOrder(
      shopId: shopId,
      orderId: orderId,
    );
  }

  @override
  void didUpdateWidget(covariant MyStoreOrderDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != shopId || oldWidget.orderId != orderId) {
      _touched = false;
      _paymentRequestId = null;
      _loadOrder();
    }
  }

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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      PaymentModel? existingPayment;
      if (!order.isPaid && order.isPendingPayment && order.totalAmount > 0) {
        if (order.lastPaymentId.trim().isNotEmpty) {
          existingPayment = await PaymentService.instance.getPayment(
            order.lastPaymentId,
          );
          if (existingPayment == null) {
            throw StateError('找不到原付款資料，請重新載入訂單後再試。');
          }
        } else {
          final payments = await PaymentService.instance.getStoreOrderPayments(
            shopId: shopId,
            orderId: order.id,
            userId: order.userId,
          );
          existingPayment = StorePaymentRecovery.selectExisting(
            payments,
            order,
          );
        }
      }
      var plan = StorePaymentRecovery.resolve(
        order: order,
        payment: existingPayment,
      );
      if (plan.action == StorePaymentRecoveryAction.chooseMethod) {
        final methods = await PaymentService.instance.resolveAvailableMethods(
          shopId: shopId,
          amountType: PaymentAmountType.full,
        );
        plan = StorePaymentRecovery.resolve(
          order: order,
          payment: existingPayment,
          availableMethods: methods,
          preferredMethod: widget.preferredPaymentMethod,
        );
      }
      if (!context.mounted) return;
      switch (plan.action) {
        case StorePaymentRecoveryAction.confirmZeroTotal:
          await StoreFunctionService.instance.updateStoreOrderStatus(
            shopId: shopId,
            orderId: order.id,
            action: 'confirm_zero_total',
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('訂單已確認，請等待店家備貨。')));
          return;
        case StorePaymentRecoveryAction.alreadyPaid:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('訂單已完成付款，請稍後確認最新訂單狀態。')));
          return;
        case StorePaymentRecoveryAction.showPayment:
          final payment = plan.payment!;
          _openPayment(
            context,
            order: order,
            paymentId: payment.id,
            paymentHtml:
                payment.hasOfflinePaymentInfo ||
                    payment.status == PaymentTransactionStatus.processing
                ? ''
                : payment.paymentHtml,
            initialPayment: payment,
          );
          return;
        case StorePaymentRecoveryAction.unavailable:
          throw StateError(plan.message);
        case StorePaymentRecoveryAction.chooseMethod:
          throw StateError('請重新載入可用的付款方式。');
        case StorePaymentRecoveryAction.createPayment:
          break;
      }
      if (plan.resetRequest) _paymentRequestId = null;
      final String requestId = _paymentRequestId ??= FirebaseFirestore.instance
          .collection('payments')
          .doc()
          .id;
      final paymentResult = await PaymentFunctionService.instance.createPayment(
        request: CreatePaymentRequestModel(
          shopId: shopId,
          sourceType: PaymentSourceType.storeOrder,
          sourceId: order.id,
          paymentMethod: plan.method,
          amountType: PaymentAmountType.full,
          paymentPurpose: PaymentPurpose.full,
          amount: order.totalAmount,
          requestId: requestId,
        ),
      );

      if (!context.mounted) {
        return;
      }

      if (!paymentResult.success) {
        throw Exception(
          paymentResult.message.isEmpty
              ? '付款建立失敗，請稍後重試'
              : paymentResult.message,
        );
      }
      if (paymentResult.status == PaymentTransactionStatus.paid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('訂單已完成付款。')));
        return;
      }
      _openPayment(
        context,
        order: order,
        paymentId: paymentResult.paymentId,
        paymentHtml:
            paymentResult.hasAtmPaymentInfo || paymentResult.hasCvsPaymentInfo
            ? ''
            : paymentResult.paymentHtml,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPayment(
    BuildContext context, {
    required StoreOrderModel order,
    required String paymentId,
    required String paymentHtml,
    PaymentModel? initialPayment,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EcpayPaymentPage(
          paymentHtml: paymentHtml,
          paymentId: paymentId,
          shopId: shopId,
          storeOrderId: order.id,
          initialPayment: initialPayment,
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
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
    } finally {
      if (mounted) setState(() => _busy = false);
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
            stream: _orderStream,
            builder: (BuildContext context, AsyncSnapshot<StoreOrderModel?> snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('訂單讀取失敗，請稍後重試。'),
                      TextButton(
                        onPressed: () => setState(_loadOrder),
                        child: const Text('重新載入'),
                      ),
                    ],
                  ),
                );
              }
              final StoreOrderModel? order = snapshot.data;
              if (order == null) {
                return Center(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : const Text('找不到這筆訂單'),
                );
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
                      onPressed: _busy ? null : () => _pay(context, order),
                      child: Text(
                        _busy
                            ? '處理中...'
                            : order.totalAmount == 0
                            ? '確認訂單'
                            : '前往付款',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _cancel(context),
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
