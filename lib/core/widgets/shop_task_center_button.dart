// 檔案名稱：lib/core/widgets/shop_task_center_button.dart
// 功能說明：後台共用待辦中心入口
// 放到各店家後台 AppBar actions，不要每頁複製查詢邏輯。

import 'package:flutter/material.dart';

import '../models/shop_task_item.dart';
import '../services/shop_task_center_service.dart';
import '../../features/shop/pages/shop_camera_access_page.dart';
import '../../features/shop/pages/shop_task_center_page.dart';
import 'shop_task_center_panel.dart';

class ShopTaskCenterButton extends StatefulWidget {
  const ShopTaskCenterButton({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopTaskCenterButton> createState() => _ShopTaskCenterButtonState();
}

class _ShopTaskCenterButtonState extends State<ShopTaskCenterButton> {
  ShopTaskAccess? _access;
  ShopTaskCenterBinding? _binding;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void didUpdateWidget(ShopTaskCenterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) {
      _binding?.close();
      _binding = null;
      _access = null;
      _loadAccess();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _binding?.close();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    final int generation = ++_loadGeneration;
    final ShopTaskAccess access = await ShopTaskCenterService.instance
        .loadAccess(widget.shopId);
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    _binding?.close();
    setState(() {
      _access = access;
      _binding = ShopTaskCenterService.instance.openBinding(
        shopId: widget.shopId,
        canViewBookings: access.canViewBookings,
        canFillDailyCare: access.canFillDailyCare,
        canManageDevices: access.canManageDevices,
      );
    });
  }

  Future<void> _openPanel() async {
    final bool isWide = MediaQuery.sizeOf(context).width >= 800;

    void openAll() {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShopTaskCenterPage(shopId: widget.shopId),
        ),
      );
    }

    final ShopTaskAccess access = _access ?? ShopTaskAccess.none;
    Widget panel() {
      return ShopTaskCenterPanel(
        shopId: widget.shopId,
        canViewBookings: access.canViewBookings,
        canFillDailyCare: access.canFillDailyCare,
        canManageDevices: access.canManageDevices,
        onViewAll: openAll,
        onOpenCamera: (ShopTaskItem item) {
          openShopCameraAccessRequest(context, item);
        },
      );
    }

    if (isWide) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black26,
        builder: (context) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.white,
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 420,
                  height: MediaQuery.sizeOf(context).height - 32,
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      Expanded(child: SingleChildScrollView(child: panel())),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(child: panel()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShopTaskCenterBinding? binding = _binding;
    if (binding == null) {
      return IconButton(
        tooltip: '今日待辦',
        onPressed: _access == null ? null : _openPanel,
        icon: const Icon(Icons.pets_outlined),
      );
    }
    return StreamBuilder<ShopTaskCenterSnapshot>(
      stream: binding.snapshots,
      builder: (context, snapshot) {
        final int count = snapshot.data?.totalCount ?? 0;
        return IconButton(
          tooltip: '今日待辦',
          onPressed: _openPanel,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.pets_outlined),
          ),
        );
      },
    );
  }
}
