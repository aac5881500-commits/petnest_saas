// lib/features/shop/pages/permissions/inventory_permission_page.dart
// 📦 庫存管理權限設定頁
// 功能：依現有店家成員權限架構開關庫存查看、管理、進貨、盤點與成本權限。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class InventoryPermissionPage extends StatefulWidget {
  const InventoryPermissionPage({
    super.key,
    required this.permissions,
    required this.isOwner,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final bool isOwner;
  final void Function(String key, bool value) onChanged;

  @override
  State<InventoryPermissionPage> createState() =>
      _InventoryPermissionPageState();
}

class _InventoryPermissionPageState extends State<InventoryPermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });

    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('庫存管理權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          PermissionSwitchTile(
            title: '查看庫存',
            subtitle: '可查看庫存品項、數量與異動流水',
            value:
                widget.permissions[ShopPermissionKeys.viewInventory] ?? false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.viewInventory, value);
            },
          ),
          PermissionSwitchTile(
            title: '管理庫存品項',
            subtitle: '可新增、編輯、停用庫存品項與住宿耗材設定',
            value:
                widget.permissions[ShopPermissionKeys.manageInventory] ?? false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.manageInventory, value);
            },
          ),
          PermissionSwitchTile(
            title: '進貨',
            subtitle: '可執行進貨並建立進貨批次',
            value:
                widget.permissions[ShopPermissionKeys.receiveInventory] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.receiveInventory, value);
            },
          ),
          PermissionSwitchTile(
            title: '出庫與盤點',
            subtitle: '可執行手動出庫與盤點調整',
            value:
                widget.permissions[ShopPermissionKeys.adjustInventory] ?? false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.adjustInventory, value);
            },
          ),
          PermissionSwitchTile(
            title: '查看成本',
            subtitle: '可查看進貨單價、加權平均成本與估計庫存成本',
            value:
                widget.permissions[ShopPermissionKeys.viewInventoryCost] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.viewInventoryCost, value);
            },
          ),
        ],
      ),
    );
  }
}
