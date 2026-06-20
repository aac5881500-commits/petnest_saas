// lib/features/shop/pages/shop_member_report_page.dart
// 👤 會員統計報表
// 功能：統計會員數、新增會員、黑名單會員與有訂單會員

import 'package:flutter/material.dart';

class ShopMemberReportPage extends StatelessWidget {
  const ShopMemberReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('會員統計報表')),
      body: const Center(child: Text('下一步接會員統計資料')),
    );
  }
}
