// 檔案名稱：lib/core/widgets/shop_task_center_button.dart
// 功能說明：後台共用待辦中心入口
// 放到各店家後台 AppBar actions，不要每頁複製查詢邏輯。

import 'package:flutter/material.dart';

import '../models/shop_task_item.dart';
import '../services/shop_task_center_service.dart';
import '../../features/shop/pages/shop_task_center_page.dart';

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

  Future<void> _openPanel() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ShopTaskCenterPage(shopId: widget.shopId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ShopTaskCenterBinding? binding = _binding;
    if (binding == null) {
      return IconButton(
        tooltip: '今日待辦',
        onPressed: _access == null ? null : _openPanel,
        icon: const Icon(Icons.checklist_rounded),
      );
    }
    return StreamBuilder<ShopTaskCenterSnapshot>(
      stream: binding.snapshots,
      builder: (context, snapshot) {
        final int count = snapshot.data?.totalCount ?? 0;
        final medication =
            snapshot.data?.items
                .where(
                  (item) => {
                    ShopTaskType.medication,
                    ShopTaskType.timedService,
                  }.contains(item.type),
                )
                .toList() ??
            [];
        final due = medication.any((item) => item.metadata['urgency'] == 'due');
        final soon = medication.any(
          (item) => item.metadata['urgency'] == 'soon',
        );
        final colors = Theme.of(context).colorScheme;
        return IconButton(
          tooltip: due
              ? '今日待辦・照護已到點'
              : soon
              ? '今日待辦・照護即將到點'
              : '今日待辦',
          onPressed: _openPanel,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            backgroundColor: due
                ? colors.error
                : soon
                ? Colors.orange.shade900
                : colors.primary,
            textColor: due
                ? colors.onError
                : soon
                ? Colors.white
                : colors.onPrimary,
            child: Icon(
              due || soon
                  ? Icons.notifications_active_outlined
                  : Icons.checklist_rounded,
            ),
          ),
        );
      },
    );
  }
}
