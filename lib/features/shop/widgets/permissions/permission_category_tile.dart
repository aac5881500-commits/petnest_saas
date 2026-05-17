// lib/features/shop/widgets/permissions/permission_category_tile.dart
// 🔐 權限設定分類入口卡片
//
// 用途：
// - 用在權限設定首頁
// - 將不同模組權限分成一頁一頁管理
// - 避免未來權限越來越多時全部擠在同一頁

import 'package:flutter/material.dart';

class PermissionCategoryTile extends StatelessWidget {
  const PermissionCategoryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}