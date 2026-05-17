// lib/features/shop/pages/permissions/basic_info_permission_page.dart
// 🔐 基本資訊權限設定頁
//
// 用途：
// - 管理基本資訊分頁相關權限
// - 避免所有權限全部擠在同一頁
// - 店家基本資料固定只有老闆可改，不放入員工權限開關

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class BasicInfoPermissionPage extends StatelessWidget {
  const BasicInfoPermissionPage({
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
        title: const Text('基本資訊權限'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '營業資訊',
            subtitle: '可修改營業時間與服務項目',
            value: permissions[ShopPermissionKeys.editBusinessInfo] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.editBusinessInfo, value);
            },
          ),
          PermissionSwitchTile(
            title: '店家封面',
            subtitle: '可修改 Logo 與封面圖片',
            value: permissions[ShopPermissionKeys.editMedia] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.editMedia, value);
            },
          ),
          PermissionSwitchTile(
            title: '環境介紹',
            subtitle: '可修改環境照片、介紹文案與展示內容',
            value: permissions[ShopPermissionKeys.manageEnvironment] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.manageEnvironment, value);
            },
          ),
          PermissionSwitchTile(
            title: '關於我們',
            subtitle: '可修改品牌故事、理念與介紹內容',
            value: permissions[ShopPermissionKeys.manageAbout] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.manageAbout, value);
            },
          ),
          PermissionSwitchTile(
            title: '模組設定',
            subtitle: '可控制後台顯示哪些功能模組',
            value: permissions[ShopPermissionKeys.manageModules] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.manageModules, value);
            },
          ),
          PermissionSwitchTile(
            title: '會員管理',
            subtitle: '可查看會員資料與訂單紀錄',
            value: permissions[ShopPermissionKeys.manageMembers] ?? false,
            enabled: isOwner,
            onChanged: (value) {
              onChanged(ShopPermissionKeys.manageMembers, value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            '店家基本資料固定只有老闆可以修改，不開放給主管或員工。',
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
