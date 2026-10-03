// 檔案名稱：lib/features/shop/pages/shop_task_center_page.dart
// 功能說明：全部待辦頁（由待辦中心「查看全部待辦」進入）

import 'package:flutter/material.dart';

import '../../../core/models/shop_task_item.dart';
import '../../../core/services/shop_task_center_service.dart';
import '../../../core/widgets/shop_task_center_panel.dart';
import 'shop_camera_access_page.dart';

class ShopTaskCenterPage extends StatefulWidget {
  const ShopTaskCenterPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopTaskCenterPage> createState() => _ShopTaskCenterPageState();
}

class _ShopTaskCenterPageState extends State<ShopTaskCenterPage> {
  ShopTaskAccess? _access;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void didUpdateWidget(ShopTaskCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _access = null;
      _loadAccess();
    }
  }

  Future<void> _loadAccess() async {
    final int generation = ++_generation;
    final ShopTaskAccess access = await ShopTaskCenterService.instance
        .loadAccess(widget.shopId);
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      _access = access;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ShopTaskAccess? access = _access;
    return Scaffold(
      appBar: AppBar(title: const Text('全部待辦')),
      body: access == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: ShopTaskCenterPanel(
                shopId: widget.shopId,
                canViewBookings: access.canViewBookings,
                canFillDailyCare: access.canFillDailyCare,
                canManageDevices: access.canManageDevices,
                showViewAll: false,
                closeBeforeOpen: false,
                onOpenCamera: (ShopTaskItem item) {
                  openShopCameraAccessRequest(context, item);
                },
              ),
            ),
    );
  }
}
