// lib/features/shop/pages/storefront/store_checkout_page.dart
// 🛒 結帳：店內自取 + 共用綠界付款

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/store_product_model.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/core/services/payment_service.dart';
import 'package:petnest_saas/core/services/store_cart_service.dart';
import 'package:petnest_saas/core/services/store_function_service.dart';
import 'package:petnest_saas/core/services/store_product_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'package:petnest_saas/features/shop/pages/storefront/my_store_order_detail_page.dart';

class StoreCheckoutPage extends StatefulWidget {
  const StoreCheckoutPage({
    super.key,
    required this.shopId,
    required this.shop,
    this.theme = HomeThemeModel.modernDefault,
    this.buyNowProductId = '',
    this.buyNowQuantity = 0,
  });

  final String shopId;
  final Map<String, dynamic> shop;
  final HomeThemeModel theme;
  final String buyNowProductId;
  final int buyNowQuantity;

  @override
  State<StoreCheckoutPage> createState() => _StoreCheckoutPageState();
}

class _StoreCheckoutPageState extends State<StoreCheckoutPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  String _paymentMethod = '';
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _shopAddress() {
    return <String>[
      (widget.shop['city'] ?? '').toString(),
      (widget.shop['district'] ?? '').toString(),
      (widget.shop['address'] ?? '').toString(),
    ].where((String value) => value.trim().isNotEmpty).join('');
  }

  String _methodLabel(String method) {
    switch (method) {
      case PaymentMethodType.creditCard:
        return '信用卡';
      case PaymentMethodType.atm:
        return 'ATM 虛擬帳號';
      case PaymentMethodType.convenienceStoreCode:
        return '超商代碼';
      default:
        return method;
    }
  }

  Future<void> _submit(List<Map<String, dynamic>> items) async {
    if (_paymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有可用的線上付款方式')),
      );
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可結帳的商品')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final Map<String, dynamic> created =
          await StoreFunctionService.instance.createStoreOrder(
        shopId: widget.shopId,
        items: items,
        fulfillmentType: StoreConstants.fulfillmentPickup,
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
      );

      final String orderId = (created['orderId'] ?? '').toString();
      final int totalAmount = created['totalAmount'] is int
          ? created['totalAmount'] as int
          : int.tryParse(created['totalAmount']?.toString() ?? '') ?? 0;

      if (widget.buyNowProductId.isEmpty) {
        await StoreCartService.instance.clearCart(widget.shopId);
      }

      final String requestId =
          FirebaseFirestore.instance.collection('payments').doc().id;
      final paymentResult = await PaymentFunctionService.instance.createPayment(
        request: CreatePaymentRequestModel(
          shopId: widget.shopId,
          sourceType: PaymentSourceType.storeOrder,
          sourceId: orderId,
          paymentMethod: _paymentMethod,
          amountType: PaymentAmountType.full,
          paymentPurpose: PaymentPurpose.full,
          amount: totalAmount,
          requestId: requestId,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!paymentResult.hasPaymentHtml) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MyStoreOrderDetailPage(
              shopId: widget.shopId,
              orderId: orderId,
              theme: widget.theme,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EcpayPaymentPage(
            paymentHtml: paymentResult.paymentHtml,
            paymentId: paymentResult.paymentId,
            shopId: widget.shopId,
            storeOrderId: orderId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final HomeThemeModel theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textColor,
        title: const Text('結帳'),
      ),
      body: StreamBuilder<List<StoreProductModel>>(
        stream: StoreProductService.instance.streamEnabledProducts(
          widget.shopId,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StoreProductModel>> productSnapshot,
        ) {
          final Map<String, StoreProductModel> productsById =
              <String, StoreProductModel>{
            for (final StoreProductModel product
                in productSnapshot.data ?? const <StoreProductModel>[])
              product.id: product,
          };

          return StreamBuilder<List<StoreCartItem>>(
            stream: StoreCartService.instance.streamCart(widget.shopId),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<StoreCartItem>> cartSnapshot,
            ) {
              final List<StoreCartItem> sourceItems;
              if (widget.buyNowProductId.isNotEmpty) {
                sourceItems = <StoreCartItem>[
                  StoreCartItem(
                    productId: widget.buyNowProductId,
                    quantity: widget.buyNowQuantity,
                  ),
                ];
              } else {
                sourceItems = cartSnapshot.data ?? const <StoreCartItem>[];
              }

              final List<Map<String, dynamic>> orderItems = <Map<String, dynamic>>[];
              int subtotal = 0;
              for (final StoreCartItem item in sourceItems) {
                final StoreProductModel? product = productsById[item.productId];
                if (product == null) {
                  continue;
                }
                subtotal += product.price * item.quantity;
                orderItems.add(<String, dynamic>{
                  'productId': product.id,
                  'quantity': item.quantity,
                });
              }

              return StreamBuilder<List<String>>(
                stream: PaymentService.instance.streamAvailableMethods(
                  shopId: widget.shopId,
                  amountType: PaymentAmountType.full,
                ),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<String>> methodsSnapshot,
                ) {
                  final List<String> methods =
                      (methodsSnapshot.data ?? const <String>[])
                          .where(PaymentMethodType.isOnlinePayment)
                          .toList();
                  final String selectedMethod =
                      methods.contains(_paymentMethod)
                      ? _paymentMethod
                      : (methods.isNotEmpty ? methods.first : '');

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      const Text(
                        '履約方式',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.storefront_outlined),
                          title: const Text('店內自取'),
                          subtitle: Text(
                            _shopAddress().isEmpty ? '請至店家櫃台取貨' : _shopAddress(),
                          ),
                        ),
                      ),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: StoreSettingsService.instance.streamSettings(
                          widget.shopId,
                        ),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<Map<String, dynamic>> settingsSnapshot,
                        ) {
                          final String note =
                              (settingsSnapshot.data?['pickupNote'] ?? '')
                                  .toString();
                          if (note.trim().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(note),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: '取貨人姓名'),
                      ),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '聯絡電話'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '付款方式',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (methods.isEmpty)
                        const Text('店家尚未開放線上付款（信用卡 / ATM / 超商代碼）')
                      else
                        ...methods.map((String method) {
                          return RadioListTile<String>(
                            title: Text(_methodLabel(method)),
                            value: method,
                            groupValue: selectedMethod,
                            onChanged: (String? value) {
                              setState(() => _paymentMethod = value ?? '');
                            },
                          );
                        }),
                      const SizedBox(height: 16),
                      Text(
                        '合計 NT\$ $subtotal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submitting ||
                                methods.isEmpty ||
                                orderItems.isEmpty
                            ? null
                            : () {
                                _paymentMethod = selectedMethod;
                                _submit(orderItems);
                              },
                        child: Text(_submitting ? '處理中...' : '建立訂單並付款'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
