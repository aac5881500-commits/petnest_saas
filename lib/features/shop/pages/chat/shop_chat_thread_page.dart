// 檔案名稱：lib/features/shop/pages/chat/shop_chat_thread_page.dart
// 功能說明：店家後台與會員的完整對話頁

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

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
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: ShopChatThreadPane(
          shopId: shopId,
          threadId: threadId,
          compact: MediaQuery.sizeOf(context).width < 900,
          onBack: () => Navigator.of(context).maybePop(),
          onOpenFull: null,
          onMinimize: workspace?.minimizeChatPanel,
        ),
      ),
    );
  }
}
