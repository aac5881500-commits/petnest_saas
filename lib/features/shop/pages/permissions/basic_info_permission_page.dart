// 檔案名稱：lib/features/shop/pages/permissions/basic_info_permission_page.dart
// 功能說明：基本資訊權限設定頁
// 用途：
// - 管理基本資訊分頁相關權限
// - 避免所有權限全部擠在同一頁
// - 店家基本資料固定只有老闆可改，不放入員工權限開關
// - 模組設定 / 權限設定固定只有老闆可操作，不放入員工權限開關

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/widgets/permissions/permission_switch_tile.dart';

class BasicInfoPermissionPage extends StatefulWidget {
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
  State<BasicInfoPermissionPage> createState() =>
      _BasicInfoPermissionPageState();
}

class _BasicInfoPermissionPageState extends State<BasicInfoPermissionPage> {
  void _updatePermission(String key, bool value) {
    setState(() {
      widget.permissions[key] = value;
    });

    widget.onChanged(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('基本資訊權限')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PermissionSwitchTile(
            title: '營業資訊',
            subtitle: '可修改營業時間與服務項目',
            value:
                widget.permissions[ShopPermissionKeys.editBusinessInfo] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.editBusinessInfo, value);
            },
          ),

          PermissionSwitchTile(
            title: '店家封面',
            subtitle: '可修改 Logo 與封面圖片',
            value: widget.permissions[ShopPermissionKeys.editMedia] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.editMedia, value);
            },
          ),

          PermissionSwitchTile(
            title: '前台內容',
            subtitle: '可管理環境介紹、關於我們、公告管理、常見問題',
            value:
                widget.permissions[ShopPermissionKeys.manageFrontendContent] ??
                false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(
                ShopPermissionKeys.manageFrontendContent,
                value,
              );
            },
          ),

          PermissionSwitchTile(
            title: '評價管理',
            subtitle: '可查看、回覆、隱藏店家評價',
            value:
                widget.permissions[ShopPermissionKeys.manageReviews] ?? false,
            enabled: widget.isOwner,
            onChanged: (value) {
              _updatePermission(ShopPermissionKeys.manageReviews, value);
            },
          ),

          const SizedBox(height: 12),

          Text(
            '店家基本資料固定只有老闆可以修改，不開放給員工。\n'
            '模組設定與權限設定也固定只有老闆可以操作。',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
