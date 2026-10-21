// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_desktop_workspace.dart
// 功能說明：占位聊天側欄；清單與單一對話切換，展開時共用同一個對話實例。
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_inbox_list.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatDesktopWorkspace extends StatefulWidget {
  const ShopChatDesktopWorkspace({
    super.key,
    required this.shopId,
    required this.controller,
    this.expanded = false,
    this.forcedExpanded = false,
  });
  static const Key overlayKey = ValueKey<String>('shop-chat-desktop-workspace');
  final String shopId;
  final ShopChatMultiDockController controller;
  final bool expanded;
  final bool forcedExpanded;
  @override
  State<ShopChatDesktopWorkspace> createState() =>
      _ShopChatDesktopWorkspaceState();
}

class _ShopChatDesktopWorkspaceState extends State<ShopChatDesktopWorkspace> {
  final GlobalKey _inboxKey = GlobalKey();
  final ScrollController _inboxScroll = ScrollController();
  final Map<String, GlobalKey> _paneKeys = {};
  @override
  void dispose() {
    _inboxScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ShopAdminWorkspaceScope.maybeOf(context);
    final controller = widget.controller;
    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFE6EAF0))),
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final focused = controller.focusedThreadId;
              final ids = controller.slotIds.toList()
                ..sort(
                  (a, b) =>
                      (controller.lastActiveAt[b] ??
                              DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(
                            controller.lastActiveAt[a] ??
                                DateTime.fromMillisecondsSinceEpoch(0),
                          ),
                );
              _paneKeys.removeWhere((id, _) => !ids.contains(id));
              // 選取優先留在可見分頁，其餘仍依穩定 threadId 放入更多選單。
              final ordered = [
                if (focused != null && ids.contains(focused)) focused,
                ...ids.where((id) => id != focused),
              ];
              final visibleCount = (constraints.maxWidth / 112).floor().clamp(
                1,
                4,
              );
              final visible = ordered.take(visibleCount).toList();
              final more = ordered.skip(visibleCount).toList();
              final split = widget.expanded && constraints.maxWidth >= 720;
              String name(String id) {
                final value =
                    controller.snapshots[id]?.customerName.trim() ?? '';
                return value.isEmpty ? '會員' : value;
              }

              void openId(String id) {
                final thread = controller.snapshots[id];
                if (thread != null) controller.openDesktopSlot(thread);
              }

              final inbox = ShopChatInboxList(
                key: _inboxKey,
                shopId: widget.shopId,
                compact: true,
                scrollController: _inboxScroll,
                selectedThreadId: focused,
                openedThreadIds: ids.toSet(),
                filter: workspace?.inboxFilter ?? 'inbox',
                query: workspace?.inboxQuery ?? '',
                onFilterChanged: workspace?.setInboxFilter,
                onQueryChanged: workspace?.setInboxQuery,
                onOpenThread: controller.openDesktopSlot,
              );
              return Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '店家聊天',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: widget.forcedExpanded
                              ? '返回後台'
                              : widget.expanded
                              ? '收回側欄'
                              : '展開聊天',
                          onPressed: widget.forcedExpanded
                              ? workspace?.closeInbox
                              : () => controller.setWorkspaceExpanded(
                                  !widget.expanded,
                                ),
                          icon: Icon(
                            widget.expanded
                                ? Icons.close_fullscreen
                                : Icons.open_in_full,
                          ),
                        ),
                        IconButton(
                          tooltip: '關閉聊天',
                          onPressed: workspace?.closeInbox,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  if (widget.forcedExpanded)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '目前空間不足以並排，關閉聊天即可返回原後台頁面。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (ids.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          for (final id in visible)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Material(
                                  color: focused == id
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => openId(id),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 7,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name(id),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: focused == id
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if ((controller
                                                      .snapshots[id]
                                                      ?.shopUnreadCount ??
                                                  0) >
                                              0)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(
                                                Icons.circle,
                                                color: Colors.red,
                                                size: 7,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (more.isNotEmpty)
                            PopupMenuButton<String>(
                              tooltip: '更多對話',
                              icon: const Icon(Icons.more_horiz),
                              onSelected: openId,
                              itemBuilder: (_) => [
                                for (final id in more)
                                  PopupMenuItem(
                                    value: id,
                                    child: Text(
                                      '${name(id)}${(controller.snapshots[id]?.shopUnreadCount ?? 0) > 0 ? ' ・未讀' : ''}',
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (split) SizedBox(width: 300, child: inbox),
                        if (split) const VerticalDivider(width: 1),
                        Expanded(
                          child: focused == null
                              ? (split
                                    ? const Center(child: Text('請選擇會員開始對話'))
                                    : inbox)
                              : ShopChatThreadPane(
                                  key: _paneKeys.putIfAbsent(
                                    focused,
                                    () => GlobalKey(),
                                  ),
                                  shopId: widget.shopId,
                                  threadId: focused,
                                  initialCustomerName: name(focused),
                                  active: true,
                                  compact: true,
                                  onBack: split
                                      ? null
                                      : controller.clearFocusedThread,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
