// 檔案名稱：lib/features/shop/pages/shop_frontend_preview_page.dart
// 功能說明：手機／窄螢幕後台開啟的全螢幕前台預覽，重用既有前台 root。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_frontend_preview_frame.dart';

class ShopFrontendPreviewPage extends StatelessWidget {
  const ShopFrontendPreviewPage({
    super.key,
    required this.shopId,
    required this.shopCode,
  });

  final String shopId;
  final String shopCode;

  static Future<void> open(
    BuildContext context, {
    required String shopId,
    required String shopCode,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ShopFrontendPreviewPage(shopId: shopId, shopCode: shopCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F27),
      body: SafeArea(
        child: ShopFrontendPreviewFrame(
          shopId: shopId,
          shopCode: shopCode,
          showExpand: false,
          scaleToFit: false,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
