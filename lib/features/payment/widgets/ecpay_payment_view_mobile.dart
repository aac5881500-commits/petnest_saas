// 檔案名稱：lib/features/payment/widgets/ecpay_payment_view_mobile.dart
// 功能說明：使用原生 WebView 載入綠界付款 HTML。
// 📱 綠界付款內容（Android / iOS）

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EcpayPaymentView extends StatefulWidget {
  const EcpayPaymentView({super.key, required this.paymentHtml});

  final String paymentHtml;

  @override
  State<EcpayPaymentView> createState() => _EcpayPaymentViewState();
}

class _EcpayPaymentViewState extends State<EcpayPaymentView> {
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
            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame != true) return;

            setState(() {
              _isLoading = false;
              _errorMessage = error.description;
            });
          },
        ),
      );

    _loadPaymentHtml();
  }

  Future<void> _loadPaymentHtml() async {
    final String paymentHtml = widget.paymentHtml.trim();

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
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '付款頁載入失敗：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}
