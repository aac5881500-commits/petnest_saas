// 檔案名稱：lib/features/auth/widgets/my_shop_qr_link_card.dart
// 功能說明：首頁顯示小按鈕，點擊後進入獨立 QR 分享頁
// 🔗 店家前台 QR / 分享店家按鈕

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/auth/pages/my_shop_qr_page.dart';

class MyShopQrLinkCard extends StatelessWidget {
  const MyShopQrLinkCard({
    super.key,
    required this.shopCode,
    this.quiet = false,
  });

  final String shopCode;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final hasShopCode = shopCode.trim().isNotEmpty;

    final ColorScheme colors = Theme.of(context).colorScheme;
    if (quiet) {
      return TextButton.icon(
        onPressed: hasShopCode ? () => _showQrPage(context) : null,
        icon: const Icon(Icons.qr_code_2_outlined, size: 18),
        label: Text(
          hasShopCode ? '分享我的店' : '尚未產生店家代碼',
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: hasShopCode
            ? () {
                _showQrPage(context);
              }
            : null,
        icon: const Icon(Icons.qr_code_2_outlined, size: 18),
        label: Text(
          hasShopCode ? '分享我的店' : '尚未產生店家代碼',
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
