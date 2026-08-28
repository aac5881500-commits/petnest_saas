// lib/features/shop/pages/permissions/store_permission_page.dart
// 🛒 賣場權限設定頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class StorePermissionPage extends StatefulWidget {
  const StorePermissionPage({
    super.key,
    required this.permissions,
    required this.isOwner,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final bool isOwner;
  final void Function(String key, bool value) onChanged;

  @override
  State<StorePermissionPage> createState() => _StorePermissionPageState();
}

class _StorePermissionPageState extends State<StorePermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });
    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('賣場權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          PermissionSwitchTile(
            title: '查看商城訂單',
            subtitle: '可查看商城訂單列表與詳情',
            value:
                widget.permissions[ShopPermissionKeys.viewStoreOrders] ?? false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.viewStoreOrders, value);
            },
          ),
          PermissionSwitchTile(
            title: '管理商品與分類',
            subtitle: '可新增、編輯商品與分類',
            value:
                widget.permissions[ShopPermissionKeys.manageStoreProducts] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.manageStoreProducts, value);
            },
          ),
          PermissionSwitchTile(
            title: '管理商城訂單',
            subtitle: '可備貨、標記可取貨、完成與取消',
            value:
                widget.permissions[ShopPermissionKeys.manageStoreOrders] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.manageStoreOrders, value);
            },
          ),
          PermissionSwitchTile(
            title: '管理賣場設定',
            subtitle: '可修改自取說明與前台開關',
            value:
                widget.permissions[ShopPermissionKeys.manageStoreSettings] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) {
              _updatePermission(ShopPermissionKeys.manageStoreSettings, value);
            },
          ),
        ],
      ),
    );
  }
}
