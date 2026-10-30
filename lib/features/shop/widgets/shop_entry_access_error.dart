import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/shop/pages/shop_qr_scan_page.dart';

class ShopEntryAccessError extends StatelessWidget {
  const ShopEntryAccessError({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final denied =
        error is FirebaseException &&
        (error as FirebaseException).code == 'permission-denied';
    return Scaffold(
      appBar: AppBar(title: const Text('店家頁面')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                denied ? '目前無法開啟這間店家' : '暫時無法讀取店家',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                denied
                    ? '你可能已切換到另一間店，或登入身分已改變。可以重新讀取，或使用店家提供的 QR Code／搜尋碼進店。'
                    : '請確認網路連線後再試一次。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('重新讀取')),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ShopQrScanPage(),
                  ),
                ),
                child: const Text('掃碼／輸入搜尋碼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
