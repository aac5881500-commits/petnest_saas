import 'package:flutter/material.dart';
import '../widgets/content/shop_content_management_page.dart';

class ShopAnnouncementManagePage extends StatelessWidget {
  const ShopAnnouncementManagePage({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context) => ShopContentManagementPage(
    shopId: shopId,
    kind: ShopContentKind.announcement,
  );
}
