// 檔案名稱：lib/features/shop/pages/permissions/cat_hotel_permission_page.dart
// 功能說明：貓咪旅店權限設定頁
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
  State<CatHotelPermissionPage> createState() => _CatHotelPermissionPageState();
}

class _CatHotelPermissionPageState extends State<CatHotelPermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });

    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('貓咪旅店權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '訂單管理',
            subtitle: '可查看與管理住宿訂單',
            value:
                widget.permissions[ShopPermissionKeys.manageBookings] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageBookings, value);
            },
          ),

          PermissionSwitchTile(
            title: '店家聊天',
            subtitle: '可查看收件匣並回覆會員訊息',
            value: widget.permissions[ShopPermissionKeys.manageChat] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageChat, value);
            },
          ),

          PermissionSwitchTile(
            title: '預約管理',
            subtitle: '可開關前台預約、管理可預約日期',
            value:
                widget.permissions[ShopPermissionKeys.manageBookingSettings] ??
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
                widget.permissions[ShopPermissionKeys.manageRoomDashboard] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageRoomDashboard, value);
            },
          ),

          PermissionSwitchTile(
            title: '房型管理',
            subtitle: '可新增與修改房型',
            value:
                widget.permissions[ShopPermissionKeys.manageRoomTypes] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageRoomTypes, value);
            },
          ),

          PermissionSwitchTile(
            title: '房間管理',
            subtitle: '可新增與修改實際房間',
            value: widget.permissions[ShopPermissionKeys.manageRooms] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageRooms, value);
            },
          ),

          PermissionSwitchTile(
            title: '攝影機 / 設備管理',
            subtitle: '可新增、修改、關閉攝影機與設備',
            value:
                widget.permissions[ShopPermissionKeys.manageDevices] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageDevices, value);
            },
          ),

          PermissionSwitchTile(
            title: '營運設定',
            subtitle: '設定訂金、優惠與點數制度',
            value:
                widget.permissions[ShopPermissionKeys.managePaymentSettings] ??
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
            title: '實體商品核銷中心',
            subtitle: '可查看待領取商品、搜尋領取碼、完成交付及取消退點',
            value:
                widget.permissions[ShopPermissionKeys.managePointRedemptions] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.managePointRedemptions,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '住宿與加購',
            subtitle: '可新增、修改住宿加購與附加服務',
            value: widget.permissions[ShopPermissionKeys.manageAddons] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageAddons, value);
            },
          ),

          PermissionSwitchTile(
            title: '入住規則',
            subtitle: '可修改入住條款與規則',
            value: widget.permissions[ShopPermissionKeys.managePolicy] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.managePolicy, value);
            },
          ),

          const SizedBox(height: 12),

          Text(
            '條款同意紀錄固定可查看，不列入權限控制。',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
