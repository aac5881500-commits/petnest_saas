// lib/features/payment/pages/ecpay_payment_page.dart
// 🌐 綠界付款頁
// 功能：載入 Cloud Function 回傳的綠界付款 HTML，
// 讓會員在 App 或 Web 中完成信用卡、ATM、超商代碼付款。

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EcpayPaymentPage extends StatefulWidget {
  const EcpayPaymentPage({super.key, required this.paymentHtml});

  /// Cloud Function 回傳的綠界付款表單 HTML
  final String paymentHtml;

  @override
  State<EcpayPaymentPage> createState() => _EcpayPaymentPageState();
}

class _EcpayPaymentPageState extends State<EcpayPaymentPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) {
              return;
            }

            setState(() {
              _isLoading = false;
              _errorMessage = error.description;
            });
          },
        ),
      );

    _loadPaymentHtml();
  }

  /// 載入綠界付款表單
  Future<void> _loadPaymentHtml() async {
    final paymentHtml = widget.paymentHtml.trim();

    if (paymentHtml.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '找不到綠界付款資料。';
      });
      return;
    }

    try {
      await _controller.loadHtmlString(paymentHtml);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '付款頁載入失敗：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('綠界線上付款')),
      body: Stack(
        children: [
          if (_errorMessage == null) WebViewWidget(controller: _controller),

          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });

                        _loadPaymentHtml();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新載入'),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading && _errorMessage == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
