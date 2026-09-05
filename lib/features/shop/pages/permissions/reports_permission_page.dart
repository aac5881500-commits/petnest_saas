// 檔案名稱：lib/features/shop/pages/permissions/reports_permission_page.dart
// 功能說明：表格統計權限設定頁
// 用途：
// - 管理報表與動作紀錄相關權限
// - 開關切換後立即刷新 UI
// - 之後營收、入住率、客戶分析都可以放這類

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class ReportsPermissionPage extends StatefulWidget {
  const ReportsPermissionPage({
    super.key,
    required this.permissions,
    required this.isOwner,
    required this.onChanged,
  });

  final Map<String, bool> permissions;
  final bool isOwner;
  final void Function(String key, bool value) onChanged;

  @override
  State<ReportsPermissionPage> createState() => _ReportsPermissionPageState();
}

class _ReportsPermissionPageState extends State<ReportsPermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });

    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表格統計權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '查看表格統計',
            subtitle: '可查看營運報表、訂單統計與未來營收分析',
            value: widget.permissions[ShopPermissionKeys.viewReports] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.viewReports, value);
            },
          ),

          PermissionSwitchTile(
            title: '查看動作記錄',
            subtitle: '可查看店內成員操作紀錄',
            value:
                widget.permissions[ShopPermissionKeys.viewActionLogs] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.viewActionLogs, value);
            },
          ),
        ],
      ),
    );
  }
}
