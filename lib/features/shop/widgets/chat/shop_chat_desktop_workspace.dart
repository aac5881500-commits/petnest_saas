// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_desktop_workspace.dart
// 功能說明：桌機右側窄 Dock：左收件匣約 160px、右最多三格獨立對話。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_inbox_list.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatDesktopWorkspace extends StatelessWidget {
  const ShopChatDesktopWorkspace({
    super.key,
    required this.shopId,
    required this.controller,
  });

  static const Key overlayKey = ValueKey<String>('shop-chat-desktop-workspace');

  final String shopId;
  final ShopChatMultiDockController controller;

  @override
  Widget build(BuildContext context) {
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    return Material(
      key: overlayKey,
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black26,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFE6EAF0))),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[controller, ?workspace]),
          builder: (BuildContext context, Widget? child) {
            final List<String> slots = controller.slotIds;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: ShopChatLayout.inboxColumnWidth,
                  child: Column(
                    children: <Widget>[
                      Material(
                        color: Colors.white,
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                            child: Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Text(
                                    '全部聊天',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '關閉聊天',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: workspace?.closeInbox,
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ShopChatInboxList(
                          shopId: shopId,
                          compact: true,
                          selectedThreadId: controller.highlightId,
                          openedThreadIds: slots.toSet(),
                          filter: workspace?.inboxFilter ?? 'inbox',
                          query: workspace?.inboxQuery ?? '',
                          onFilterChanged: workspace?.setInboxFilter,
                          onQueryChanged: workspace?.setInboxQuery,
                          onOpenThread: (ShopChatThreadModel thread) {
                            final ShopChatOpenResult result = controller
                                .openDesktopSlot(thread);
                            if (result.kind == ShopChatOpenKind.rejectedFull &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(ShopChatLayout.slotFullMessage),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: slots.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFF8FAFC),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '從左側選擇會員開始對話',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool showBanner =
                                    constraints.maxHeight / slots.length >= 240;
                                return Column(
                                  children: <Widget>[
                                    for (
                                      int i = 0;
                                      i < slots.length;
                                      i++
                                    ) ...<Widget>[
                                      if (i > 0) const Divider(height: 1),
                                      Expanded(
                                        child: ShopChatThreadPane(
                                          key: ValueKey<String>(
                                            'desktop-slot-${slots[i]}',
                                          ),
                                          shopId: shopId,
                                          threadId: slots[i],
                                          compact: true,
                                          slotMode: true,
                                          showBookingBanner: showBanner,
                                          highlighted:
                                              controller.highlightId ==
                                              slots[i],
                                          onBack: null,
                                          onMinimize: null,
                                          onOpenFull: null,
                                          onClose: () => controller
                                              .closeDesktopSlot(slots[i]),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
