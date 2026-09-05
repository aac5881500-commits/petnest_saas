// 檔案名稱：lib/core/widgets/shop_task_center_button.dart
// 功能說明：後台共用待辦中心入口
// 放到各店家後台 AppBar actions，不要每頁複製查詢邏輯。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/shop_permission_keys.dart';
import '../models/shop_task_item.dart';
import '../services/shop_service.dart';
import '../services/shop_task_center_service.dart';
import 'shop_task_center_panel.dart';
import '../../features/shop/pages/shop_task_center_page.dart';

class ShopTaskCenterButton extends StatefulWidget {
  const ShopTaskCenterButton({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopTaskCenterButton> createState() => _ShopTaskCenterButtonState();
}

class _ShopTaskCenterButtonState extends State<ShopTaskCenterButton> {
  Map<String, dynamic>? _memberData;
  int _panelKey = 0;

  bool get _canViewBookings {
    return ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageBookings,
    );
  }

  bool get _canFillDailyCare {
    return ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageRoomDashboard,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final Map<String, dynamic>? member = await ShopService.instance
        .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _memberData = member;
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

    Widget panel() {
      return ShopTaskCenterPanel(
        key: ValueKey<int>(_panelKey),
        shopId: widget.shopId,
        canViewBookings: _canViewBookings,
        canFillDailyCare: _canFillDailyCare,
        onViewAll: openAll,
        onRetry: () {
          setState(() {
            _panelKey++;
          });
          Navigator.of(context).pop();
          _openPanel();
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
    return StreamBuilder<ShopTaskCenterSnapshot>(
      stream: ShopTaskCenterService.instance.streamSnapshot(
        shopId: widget.shopId,
        canViewBookings: _canViewBookings,
        canFillDailyCare: _canFillDailyCare,
      ),
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
