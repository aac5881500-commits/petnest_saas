// lib/features/shop/pages/permissions/reports_permission_page.dart
// 📊 表格統計權限設定頁
//
// 用途：
// - 管理報表與動作紀錄相關權限
// - 之後營收、入住率、客戶分析都可以放這類

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class ReportsPermissionPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('表格統計權限'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '查看表格統計',
            subtitle: '可查看營運報表、訂單統計與未來營收分析',
            value: permissions[ShopPermissionKeys.viewReports] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.viewReports,
                value,
              );
            },
          ),
          PermissionSwitchTile(
            title: '查看動作記錄',
            subtitle: '可查看店內成員操作紀錄',
            value: permissions[ShopPermissionKeys.viewActionLogs] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(
                ShopPermissionKeys.viewActionLogs,
                value,
              );
            },
          ),
        ],
      ),
    );
  }
}