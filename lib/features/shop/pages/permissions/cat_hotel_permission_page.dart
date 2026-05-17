// lib/features/shop/pages/permissions/cat_hotel_permission_page.dart
// 🐱 貓咪旅店權限設定頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class CatHotelPermissionPage extends StatelessWidget {
  const CatHotelPermissionPage({
    super.key,
    required this.permissions,
    required this.isOwner,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final bool isOwner;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('貓咪旅店權限'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '訂單管理',
            subtitle: '可查看與管理住宿訂單',
            value: permissions[ShopPermissionKeys.manageBookings] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.manageBookings,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '房務管理',
            subtitle: '可操作入住、退房、房間狀態',
            value: permissions[ShopPermissionKeys.manageRoomDashboard] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.manageRoomDashboard,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '房型管理',
            subtitle: '可新增與修改房型',
            value: permissions[ShopPermissionKeys.manageRoomTypes] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.manageRoomTypes,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '房間管理',
            subtitle: '可新增與修改實際房間',
            value: permissions[ShopPermissionKeys.manageRooms] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.manageRooms,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '付款 / 訂金設定',
            subtitle: '可修改付款方式與訂金規則',
            value: permissions[ShopPermissionKeys.managePaymentSettings] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.managePaymentSettings,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '入住規則',
            subtitle: '可修改入住條款與規則',
            value: permissions[ShopPermissionKeys.managePolicy] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.managePolicy,
                value,
              );
            },
          ),
        ],
      ),
    );
  }
}