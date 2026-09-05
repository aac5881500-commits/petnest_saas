// 檔案名稱：lib/features/shop/widgets/permissions/permission_switch_tile.dart
// 功能說明：權限開關共用卡片
// 用途：
// - 給各個權限分類頁共用
// - 統一權限開關樣式
// - 避免每個權限頁重複寫 Card + SwitchListTile

import 'package:flutter/material.dart';

class PermissionSwitchTile extends StatelessWidget {
  const PermissionSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
