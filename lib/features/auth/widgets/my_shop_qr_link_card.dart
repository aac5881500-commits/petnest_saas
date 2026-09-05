// 檔案名稱：lib/features/auth/widgets/my_shop_qr_link_card.dart
// 功能說明：首頁顯示小按鈕，點擊後進入獨立 QR 分享頁
// 🔗 店家前台 QR / 分享店家按鈕

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_qr_page.dart';

class MyShopQrLinkCard extends StatelessWidget {
  const MyShopQrLinkCard({super.key, required this.shopCode});

  final String shopCode;

  @override
  Widget build(BuildContext context) {
    final hasShopCode = shopCode.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: hasShopCode
            ? () {
                _showQrPage(context);
              }
            : null,
        icon: const Icon(Icons.qr_code, size: 18),
        label: Text(hasShopCode ? '前台 QR / 分享店家網址' : '尚未產生店家代碼'),
      ),
    );
  }

  void _showQrPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyShopQrPage(shopCode: shopCode)),
    );
  }
}
