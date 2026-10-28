import 'package:petnest_saas/core/services/shop_sharing_service.dart';
// 檔案名稱：lib/features/shop/pages/shop_qr_scan_page.dart
// 功能說明：掃描店家搜尋碼或手動輸入店家搜尋碼後，直接進入店家前台
// 📷 掃描店家 QRCode

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:petnest_saas/features/shop/pages/shop_code_redirect_page.dart';

class ShopQrScanPage extends StatefulWidget {
  const ShopQrScanPage({super.key});

  @override
  State<ShopQrScanPage> createState() => _ShopQrScanPageState();
}

class _ShopQrScanPageState extends State<ShopQrScanPage> {
  bool _handled = false;

  String? _parseShopCode(String value) => ShopSharingService.parse(value);

  void _goShop(String shopCode) {
    if (_handled) return;

    _handled = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ShopCodeRedirectPage(shopCode: shopCode),
      ),
    );
  }

  Future<void> _showManualInputDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('輸入店家搜尋碼'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '店家搜尋碼',
              hintText: '例如：CATSTAY_2026',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('前往店家'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    final shopCode = _parseShopCode(result);

    if (shopCode == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店家搜尋碼格式不正確')));
      return;
    }

    _goShop(shopCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('掃描店家 QRCode')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_handled) return;

                final barcode = capture.barcodes.firstOrNull;
                final value = barcode?.rawValue;

                if (value == null || value.isEmpty) return;

                final shopCode = _parseShopCode(value);

                if (shopCode == null) return;

                _goShop(shopCode);
              },
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            color: Colors.white,
            child: Column(
              children: [
                const Text(
                  '掃不到 QRCode 嗎？',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('手動輸入店家搜尋碼'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
