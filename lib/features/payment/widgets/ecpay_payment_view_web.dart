// lib/features/payment/widgets/ecpay_payment_view_web.dart
// 🌐 綠界付款內容（Web）
// 功能：將 Cloud Function 回傳的綠界付款 HTML 轉成暫存網址，
// 並透過瀏覽器新分頁開啟，避免綠界阻擋 iframe 載入。

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';

class EcpayPaymentView extends StatelessWidget {
  const EcpayPaymentView({super.key, required this.paymentHtml});

  /// Cloud Function 回傳的綠界自動送出付款表單
  final String paymentHtml;

  void _openPaymentPage(BuildContext context) {
    final String htmlContent = paymentHtml.trim();

    if (htmlContent.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到綠界付款資料。')));
      return;
    }

    try {
      /// 將付款 HTML 建立成瀏覽器可開啟的暫存網址
      final html.Blob paymentBlob = html.Blob(<String>[
        htmlContent,
      ], 'text/html;charset=utf-8');

      final String paymentUrl = html.Url.createObjectUrlFromBlob(paymentBlob);

      /// 必須由使用者點擊觸發，避免被瀏覽器封鎖彈出視窗
      html.window.open(paymentUrl, '_blank');

      /// 等新分頁完成讀取後，釋放暫存網址
      Timer(const Duration(seconds: 30), () {
        html.Url.revokeObjectUrl(paymentUrl);
      });
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法開啟綠界付款頁：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPaymentHtml = paymentHtml.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 56),
                  const SizedBox(height: 20),
                  Text('前往綠界付款', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text(
                    '網頁版付款會在新的瀏覽器分頁開啟。'
                    '付款完成後，請返回 PetNest 查看訂單付款狀態。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasPaymentHtml
                          ? () => _openPaymentPage(context)
                          : null,
                      icon: const Icon(Icons.payment),
                      label: const Text('開啟綠界付款頁'),
                    ),
                  ),
                  if (!hasPaymentHtml) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '找不到綠界付款資料，請返回後重新建立付款。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
