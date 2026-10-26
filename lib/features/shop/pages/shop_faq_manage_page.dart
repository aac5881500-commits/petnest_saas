import 'package:flutter/material.dart';
import '../widgets/content/shop_content_management_page.dart';

class ShopFaqManagePage extends StatelessWidget {
  const ShopFaqManagePage({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context) =>
      ShopContentManagementPage(shopId: shopId, kind: ShopContentKind.faq);
}
