// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_entry.dart
// 功能說明：後台聊天入口：窄螢幕 Navigator.push 全頁收件匣，寬螢幕才開桌機 Dock。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_inbox_page.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatEntry {
  ShopChatEntry._();

  static const String inboxRouteName = 'shop-chat-inbox-fullscreen';

  @visibleForTesting
  static Widget Function(String shopId)? debugFullScreenInboxBuilder;

  static ShopChatSurface surfaceOf(BuildContext context) {
    return ShopChatLayout.surfaceForWidth(MediaQuery.sizeOf(context).width);
  }

  static Future<void> open(
    BuildContext context, {
    required String shopId,
    bool toggleDesktop = true,
  }) {
    if (surfaceOf(context) == ShopChatSurface.fullScreenInbox) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: inboxRouteName),
          builder: (_) =>
              debugFullScreenInboxBuilder?.call(shopId) ??
              ShopChatInboxPage(shopId: shopId, fullScreenFlow: true),
        ),
      );
    }
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    if (toggleDesktop) {
      workspace?.toggleInbox();
    } else {
      workspace?.openInbox();
    }
    return Future<void>.value();
  }
}
