import 'package:flutter/material.dart';
import 'shop_report_page.dart';

/// Compatibility entry: all report views share one query and table engine.
class ShopAddonReportPage extends StatelessWidget {
  const ShopAddonReportPage({super.key, required this.shopId});
  final String shopId;
  @override
  Widget build(BuildContext context) => ShopReportPage(shopId: shopId, initialTemplate: 'addons');
}
