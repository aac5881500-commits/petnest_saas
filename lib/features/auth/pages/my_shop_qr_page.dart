import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_sharing_settings.dart';

class MyShopQrPage extends StatelessWidget {
  const MyShopQrPage({super.key, required this.shopCode});
  final String shopCode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('店家 QR / 分享')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ShopSharingSettings(shopId: shopCode),
    ),
  );
}
