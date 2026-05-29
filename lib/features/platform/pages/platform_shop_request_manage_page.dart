// lib/features/platform/pages/platform_shop_request_manage_page.dart
// 📨 店家申請中心
// 功能：平台審核店家資料修改、認證、前台公開等申請

import 'package:flutter/material.dart';

class PlatformShopRequestManagePage extends StatelessWidget {
  const PlatformShopRequestManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('店家申請中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '目前尚無待審核申請。\n\n'
                '之後這裡會顯示：\n'
                '・店家基本資料修改申請\n'
                '・特寵字號 / 統編修改申請\n'
                '・前台公開申請\n'
                '・店家認證申請',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
