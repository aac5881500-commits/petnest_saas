// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_app_bar_button.dart
// 功能說明：店家後台頂層聊天入口，開啟左側聊天清單浮層。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_entry.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatAppBarButton extends StatelessWidget {
  const ShopChatAppBarButton({
    super.key,
    required this.shopId,
    this.useSidePanel = true,
  });

  final String shopId;
  final bool useSidePanel;

  @override
  Widget build(BuildContext context) {
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    final ValueNotifier<int>? unread = workspace?.unreadCount;
    Widget button(int count) {
      final String badge = ShopChatService.badgeLabel(count);
      return IconButton(
        tooltip: count > 0 ? '$count 則未讀訊息' : '店家聊天',
        onPressed: () {
          ShopChatEntry.open(context, shopId: shopId);
        },
        icon: Badge(
          isLabelVisible: badge.isNotEmpty,
          label: Text(badge),
          child: const Icon(Icons.chat_bubble_outline),
        ),
      );
    }

    if (unread == null) {
      return StreamBuilder<int>(
        stream: ShopChatService.instance.watchShopUnreadTotal(shopId),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          return button(snapshot.data ?? 0);
        },
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: unread,
      builder: (BuildContext context, int count, Widget? child) {
        return button(count);
      },
    );
  }
}
