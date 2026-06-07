// lib/features/shop/pages/shop_code_redirect_page.dart
// 🔗 店家短網址轉址頁
// 功能：SHOP0001 → ShopPublicPage

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';

class ShopCodeRedirectPage extends StatelessWidget {
  const ShopCodeRedirectPage({super.key, required this.shopCode});

  final String shopCode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ShopService.instance.getShopByCode(shopCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final shop = snapshot.data;

        if (shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('找不到店家')),
            body: const Center(child: Text('此店家不存在或已關閉')),
          );
        }

        final shopId = shop['shopId']?.toString() ?? shopCode;

        return ShopPublicPage(shopId: shopId);
      },
    );
  }
}
