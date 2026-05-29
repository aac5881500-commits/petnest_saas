// lib/features/shop/pages/permissions/cat_hotel_permission_page.dart
// 🐱 貓咪旅店權限設定頁
//
// 用途：
// - 管理貓咪旅店相關功能權限
// - 開關切換後立即刷新 UI
// - 條款同意紀錄固定可查看，不列入權限開關

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class CatHotelPermissionPage extends StatefulWidget {
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
  State<CatHotelPermissionPage> createState() =>
      _CatHotelPermissionPageState();
}

class _CatHotelPermissionPageState
    extends State<CatHotelPermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });

    widget.onChanged(key, value);
  }

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
            value:
                widget.permissions[ShopPermissionKeys.manageBookings] ??
                    false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.manageBookings,
                value,
              );
            },
          ),

          PermissionSwitchTile(
  title: '預約管理',
  subtitle: '可開關前台預約、管理可預約日期',
  value:
      widget.permissions[
          ShopPermissionKeys.manageBookingSettings] ??
      false,
  enabled: widget.isOwner,
  onChanged: (value) {
    _updatePermission(
      ShopPermissionKeys.manageBookingSettings,
      value,
    );
  },
),

          PermissionSwitchTile(
            title: '房務管理',
            subtitle: '可操作入住、退房、房間狀態',
            value:
                widget.permissions[
                    ShopPermissionKeys.manageRoomDashboard] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.manageRoomDashboard,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '房型管理',
            subtitle: '可新增與修改房型',
            value:
                widget.permissions[
                    ShopPermissionKeys.manageRoomTypes] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.manageRoomTypes,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '房間管理',
            subtitle: '可新增與修改實際房間',
            value:
                widget.permissions[ShopPermissionKeys.manageRooms] ??
                    false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.manageRooms,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '付款 / 訂金設定',
            subtitle: '可修改付款方式、訂金與加購設定',
            value:
                widget.permissions[
                    ShopPermissionKeys.managePaymentSettings] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.managePaymentSettings,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '入住規則',
            subtitle: '可修改入住條款與規則',
            value:
                widget.permissions[ShopPermissionKeys.managePolicy] ??
                    false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.managePolicy,
                value,
              );
            },
          ),

          const SizedBox(height: 12),

          Text(
            '條款同意紀錄固定可查看，不列入權限控制。',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}