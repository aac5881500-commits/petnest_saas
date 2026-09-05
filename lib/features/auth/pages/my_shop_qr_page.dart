// 檔案名稱：lib/features/auth/pages/my_shop_qr_page.dart
// 功能說明：顯示店家代碼 QRCode、複製店家代碼、分享 QRCode 圖片、下載 QRCode 預留
// 🔗 店家 QRCode / 分享頁

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class MyShopQrPage extends StatelessWidget {
  const MyShopQrPage({super.key, required this.shopCode});

  final String shopCode;

  Future<void> _shareQrCode(BuildContext context) async {
    final qrPainter = QrPainter(
      data: shopCode,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final imageData = await qrPainter.toImageData(
      800,
      format: ui.ImageByteFormat.png,
    );

    if (imageData == null) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QRCode 產生失敗')));
      return;
    }

    final Uint8List bytes = imageData.buffer.asUint8List();

    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'petnest_$shopCode.png',
      ),
    ], text: 'PetNest 店家代碼：$shopCode');
  }

  @override
  Widget build(BuildContext context) {
    final code = shopCode.trim().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('店家 QR / 分享')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            const Text(
              '店家 QRCode',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            Text(
              '請客人使用 PetNest APP 掃描',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: QrImageView(
                data: code,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              '店家代碼',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已複製店家代碼')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('複製店家代碼'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareQrCode(context),
                icon: const Icon(Icons.share),
                label: const Text('分享 QRCode'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.download),
                label: const Text('下載 QRCode（即將開放）'),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              '掃不到 QRCode 時，也可以請客人手動輸入店家代碼。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
