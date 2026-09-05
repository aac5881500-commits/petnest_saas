// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_app_bar_button.dart
// 功能說明：店家後台頂層聊天入口

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_inbox_page.dart';

class ShopChatAppBarButton extends StatelessWidget {
  const ShopChatAppBarButton({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ShopChatService.instance.watchShopUnreadTotal(shopId),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        final int count = snapshot.data ?? 0;
        final String badge = ShopChatService.badgeLabel(count);
        return IconButton(
          tooltip: count > 0 ? '$count 則未讀訊息' : '店家聊天',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShopChatInboxPage(shopId: shopId),
              ),
            );
          },
          icon: Badge(
            isLabelVisible: badge.isNotEmpty,
            label: Text(badge),
            child: const Icon(Icons.chat_bubble_outline),
          ),
        );
      },
    );
  }
}
