// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_side_panel.dart
// 功能說明：後台右側同時顯示最多六個可回覆聊天小視窗。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_multi_dock.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatSidePanel extends StatelessWidget {
  const ShopChatSidePanel({
    super.key,
    required this.shopId,
    this.overlay = false,
    this.showRecentTabs = false,
    this.twoColumns = true,
  });

  final String shopId;
  final bool overlay;
  final bool showRecentTabs;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final ShopAdminWorkspaceController workspace = ShopAdminWorkspaceScope.of(
      context,
    );
    return ShopChatMultiDock(
      shopId: shopId,
      controller: workspace.chat,
      overlay: overlay,
    );
  }
}
