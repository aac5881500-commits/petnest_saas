// 檔案名稱：lib/features/shop/pages/chat/shop_chat_thread_page.dart
// 功能說明：全螢幕單一店家聊天頁，返回收件匣而非後台。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';

class ShopChatThreadPage extends StatelessWidget {
  const ShopChatThreadPage({
    super.key,
    required this.shopId,
    required this.threadId,
  });

  final String shopId;
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final bool compact =
        MediaQuery.sizeOf(context).width < ShopChatLayout.desktopMin;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ShopChatThreadPane(
          shopId: shopId,
          threadId: threadId,
          compact: compact,
          onBack: () => Navigator.of(context).maybePop(),
          onOpenFull: null,
          onMinimize: null,
        ),
      ),
    );
  }
}
