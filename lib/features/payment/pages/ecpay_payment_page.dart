// lib/features/payment/pages/ecpay_payment_page.dart
// 🌐 綠界付款頁
// 功能：依執行平台自動使用 Android／iOS WebView 或 Web iframe，
// 載入 Cloud Function 回傳的綠界付款 HTML。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/payment/widgets/ecpay_payment_view.dart';

class EcpayPaymentPage extends StatelessWidget {
  const EcpayPaymentPage({super.key, required this.paymentHtml});

  /// Cloud Function 回傳的綠界付款表單 HTML
  final String paymentHtml;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('綠界線上付款')),
      body: EcpayPaymentView(paymentHtml: paymentHtml),
    );
  }
}
