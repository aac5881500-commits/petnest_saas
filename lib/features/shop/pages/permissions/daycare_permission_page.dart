// lib/features/shop/pages/permissions/daycare_permission_page.dart
// 🐾 臨托權限設定

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class DaycarePermissionPage extends StatefulWidget {
  const DaycarePermissionPage({
    super.key,
    required this.permissions,
    required this.isOwner,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final bool isOwner;
  final void Function(String key, bool value) onChanged;

  @override
  State<DaycarePermissionPage> createState() => _DaycarePermissionPageState();
}

class _DaycarePermissionPageState extends State<DaycarePermissionPage> {
  void _update(String key, bool value) {
    setState(() => widget.permissions[key] = value);
    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('臨托權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          PermissionSwitchTile(
            title: '查看臨托訂單',
            subtitle: '可查看臨托列表與今日看板',
            value:
                widget.permissions[ShopPermissionKeys.viewDaycareBookings] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) =>
                _update(ShopPermissionKeys.viewDaycareBookings, value),
          ),
          PermissionSwitchTile(
            title: '管理臨托訂單',
            subtitle: '確認、開始、完成、取消、分房',
            value:
                widget.permissions[ShopPermissionKeys.manageDaycareBookings] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) =>
                _update(ShopPermissionKeys.manageDaycareBookings, value),
          ),
          PermissionSwitchTile(
            title: '臨托設定',
            subtitle: '可修改臨托基本設定、時間與條款',
            value:
                widget.permissions[ShopPermissionKeys.manageDaycareSettings] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) =>
                _update(ShopPermissionKeys.manageDaycareSettings, value),
          ),
          PermissionSwitchTile(
            title: '臨托方案與價格',
            subtitle: '可新增與修改臨托方案',
            value:
                widget.permissions[ShopPermissionKeys.manageDaycarePricing] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) =>
                _update(ShopPermissionKeys.manageDaycarePricing, value),
          ),
          PermissionSwitchTile(
            title: '臨托轉住宿',
            subtitle: '可將臨托訂單轉為住宿',
            value:
                widget.permissions[ShopPermissionKeys
                    .convertDaycareToAccommodation] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) => _update(
              ShopPermissionKeys.convertDaycareToAccommodation,
              value,
            ),
          ),
          PermissionSwitchTile(
            title: '調整臨托價格',
            subtitle: '可改價與新增超時費',
            value:
                widget.permissions[ShopPermissionKeys.adjustDaycarePrice] ??
                false,
            enabled: widget.isOwner,
            onChanged: (bool value) =>
                _update(ShopPermissionKeys.adjustDaycarePrice, value),
          ),
        ],
      ),
    );
  }
}
