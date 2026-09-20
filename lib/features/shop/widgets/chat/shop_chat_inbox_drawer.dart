// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_inbox_drawer.dart
// 功能說明：後台左側全部聊天清單浮層，可獨立關閉，選取後不離開 Dashboard。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_inbox_list.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatInboxDrawer extends StatelessWidget {
  const ShopChatInboxDrawer({
    super.key,
    required this.shopId,
    required this.controller,
    this.onReplaced,
  });

  final String shopId;
  final ShopChatMultiDockController controller;
  final ValueChanged<ShopChatOpenResult>? onReplaced;

  @override
  Widget build(BuildContext context) {
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFE6EAF0))),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '全部聊天',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉聊天清單',
                    onPressed: controller.closeInbox,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ShopChatInboxList(
                shopId: shopId,
                compact: true,
                filter: workspace?.inboxFilter ?? 'inbox',
                query: workspace?.inboxQuery ?? '',
                onFilterChanged: workspace?.setInboxFilter,
                onQueryChanged: workspace?.setInboxQuery,
                onOpenThread: (ShopChatThreadModel thread) {
                  final ShopChatOpenResult result = controller.openFromInbox(
                    thread,
                  );
                  if (result.kind == ShopChatOpenKind.replaced) {
                    onReplaced?.call(result);
                  }
                  if (result.kind == ShopChatOpenKind.focusedExisting) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final BuildContext? target = controller
                          .windowKeyFor(thread.id)
                          ?.currentContext;
                      if (target != null) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          alignment: 0.1,
                        );
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
