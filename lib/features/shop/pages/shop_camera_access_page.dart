// 檔案名稱：lib/features/shop/pages/shop_camera_access_page.dart
// 功能說明：店家攝影機分享申請頁。營運入口、設備分頁與待辦都開啟這一頁。

import 'package:flutter/material.dart';

import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/features/shop/widgets/camera/shop_camera_access_panel.dart';

class ShopCameraAccessPage extends StatelessWidget {
  const ShopCameraAccessPage({
    super.key,
    required this.shopId,
    this.focusRequestId,
    this.initialFilter,
  });

  final String shopId;
  final String? focusRequestId;
  final String? initialFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('攝影機分享申請')),
      body: ShopCameraAccessPanel(
        shopId: shopId,
        focusRequestId: focusRequestId,
        initialFilter: initialFilter,
      ),
    );
  }
}

void openShopCameraAccessRequest(BuildContext context, ShopTaskItem item) {
  final String status = (item.metadata['status'] ?? '').toString();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ShopCameraAccessPage(
        shopId: item.shopId,
        focusRequestId: item.targetId,
        initialFilter: status.isEmpty ? null : status,
      ),
    ),
  );
}
