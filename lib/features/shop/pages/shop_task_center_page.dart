// 檔案名稱：lib/features/shop/pages/shop_task_center_page.dart
// 功能說明：全部待辦頁（由待辦中心「查看全部待辦」進入）

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/shop_permission_keys.dart';
import '../../../core/services/shop_service.dart';
import '../../../core/widgets/shop_task_center_panel.dart';

class ShopTaskCenterPage extends StatefulWidget {
  const ShopTaskCenterPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopTaskCenterPage> createState() => _ShopTaskCenterPageState();
}

class _ShopTaskCenterPageState extends State<ShopTaskCenterPage> {
  Map<String, dynamic>? _memberData;
  int _reloadKey = 0;

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

  @override
  Widget build(BuildContext context) {
    final bool canViewBookings = ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageBookings,
    );
    final bool canFillDailyCare = ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageRoomDashboard,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('全部待辦')),
      body: SingleChildScrollView(
        child: ShopTaskCenterPanel(
          key: ValueKey<int>(_reloadKey),
          shopId: widget.shopId,
          canViewBookings: canViewBookings,
          canFillDailyCare: canFillDailyCare,
          showViewAll: false,
          closeBeforeOpen: false,
          onRetry: () {
            setState(() {
              _reloadKey++;
            });
          },
        ),
      ),
    );
  }
}
