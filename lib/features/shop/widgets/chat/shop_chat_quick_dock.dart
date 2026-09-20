// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_quick_dock.dart
// 功能說明：右側快捷六格與單一展開聊天室；卡片只用 inbox 摘要，完整訊息只聽展開的那一間。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_quick_dock_controller.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_inbox_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_thread_page.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_quick_card.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';

class ShopChatQuickDock extends StatelessWidget {
  const ShopChatQuickDock({
    super.key,
    required this.shopId,
    required this.controller,
    required this.onCloseDock,
    this.overlay = false,
    this.twoColumns = true,
    this.expandedActive = true,
    this.threadBuilder,
  });

  final String shopId;
  final ShopChatQuickDockController controller;
  final VoidCallback onCloseDock;
  final bool overlay;
  final bool twoColumns;
  final bool expandedActive;
  final Widget Function(BuildContext context, String threadId)? threadBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final String? expandedId = controller.hasExpanded
            ? controller.expandedThreadId
            : null;
        return Material(
          color: Colors.white,
          elevation: overlay ? 12 : 2,
          shadowColor: Colors.black26,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE6EAF0))),
            ),
            child: Column(
              children: <Widget>[
                _DockHeader(
                  shopId: shopId,
                  controller: controller,
                  overlay: overlay,
                  onCloseDock: onCloseDock,
                  showingThread: expandedId != null,
                ),
                Expanded(
                  child: expandedId == null
                      ? _QuickGrid(
                          shopId: shopId,
                          controller: controller,
                          twoColumns: twoColumns,
                        )
                      : KeyedSubtree(
                          key: ValueKey<String>('quick-thread-$expandedId'),
                          child:
                              threadBuilder?.call(context, expandedId) ??
                              ShopChatThreadPane(
                                shopId: shopId,
                                threadId: expandedId,
                                active: expandedActive,
                                compact: true,
                                onBack: controller.minimizeExpanded,
                                onClose: controller.closeExpanded,
                                onMinimize: controller.minimizeExpanded,
                                onOpenFull: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ShopChatThreadPage(
                                        shopId: shopId,
                                        threadId: expandedId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DockHeader extends StatelessWidget {
  const _DockHeader({
    required this.shopId,
    required this.controller,
    required this.overlay,
    required this.onCloseDock,
    required this.showingThread,
  });

  final String shopId;
  final ShopChatQuickDockController controller;
  final bool overlay;
  final VoidCallback onCloseDock;
  final bool showingThread;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                showingThread
                    ? '店家聊天'
                    : '快捷對話 ${controller.slotIds.length}／${controller.maxSlots}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: '開啟完整收件匣',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ShopChatInboxPage(
                      shopId: shopId,
                      onConversationSelected: (ShopChatThreadModel thread) {
                        controller.pin(thread, expand: true);
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_full),
            ),
            IconButton(
              tooltip: '全部縮小',
              onPressed: controller.minimizeExpanded,
              icon: const Icon(Icons.grid_view_outlined),
            ),
            IconButton(
              tooltip: overlay ? '最小化快捷區' : '關閉快捷區',
              onPressed: onCloseDock,
              icon: Icon(overlay ? Icons.remove : Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.shopId,
    required this.controller,
    required this.twoColumns,
  });

  final String shopId;
  final ShopChatQuickDockController controller;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final List<ShopChatThreadModel> cards = controller.cards;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (controller.overflowUnread > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '另有 ${ShopChatService.badgeLabel(controller.overflowUnread)} 個未讀對話',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ShopChatInboxPage(
                                shopId: shopId,
                                onConversationSelected:
                                    (ShopChatThreadModel thread) {
                                      controller.pin(thread, expand: true);
                                    },
                              ),
                            ),
                          );
                        },
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: cards.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '尚無快捷對話，新訊息會自動顯示在這裡',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool useTwo =
                              twoColumns &&
                              constraints.maxWidth >=
                                  ShopChatDockPlacement.twoColumnMinWidth;
                          final int columns = useTwo ? 2 : 1;
                          return GridView.builder(
                            itemCount: cards.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: useTwo ? 1.15 : 2.4,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final ShopChatThreadModel thread = cards[index];
                              return ShopChatQuickCard(
                                thread: thread,
                                selected:
                                    controller.expandedThreadId == thread.id,
                                onOpen: () => controller.expand(thread.id),
                                onRemove: () =>
                                    controller.removeSlot(thread.id),
                              );
                            },
                          );
                        },
                  ),
          ),
        ],
      ),
    );
  }
}
