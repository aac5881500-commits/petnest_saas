// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_mini_window.dart
// 功能說明：右側可同時操作的聊天小視窗，含獨立輸入、焦點、捲動與訊息監聽。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_thread_pane.dart';

class ShopChatMiniWindow extends StatefulWidget {
  const ShopChatMiniWindow({
    super.key,
    required this.shopId,
    required this.thread,
    required this.controller,
    this.highlighted = false,
  });

  final String shopId;
  final ShopChatThreadModel thread;
  final ShopChatMultiDockController controller;
  final bool highlighted;

  @override
  State<ShopChatMiniWindow> createState() => _ShopChatMiniWindowState();
}

class _ShopChatMiniWindowState extends State<ShopChatMiniWindow> {
  late final FocusNode _focus;
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _input = widget.controller.inputOf(widget.thread.id);
    widget.controller.registerMessageListener(widget.thread.id);
    _focus.addListener(_onFocus);
    _input.addListener(_onInput);
  }

  @override
  void didUpdateWidget(covariant ShopChatMiniWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id) {
      oldWidget.controller.unregisterMessageListener(oldWidget.thread.id);
      widget.controller.registerMessageListener(widget.thread.id);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _input.removeListener(_onInput);
    _focus.dispose();
    widget.controller.unregisterMessageListener(widget.thread.id);
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.controller.touch(widget.thread.id);
    }
  }

  void _onInput() {
    widget.controller.touch(widget.thread.id);
  }

  @override
  Widget build(BuildContext context) {
    final ShopChatThreadModel thread = widget.thread;
    final String name = thread.customerName.trim().isEmpty
        ? '會員'
        : thread.customerName.trim();
    final String badge = ShopChatService.badgeLabel(thread.shopUnreadCount);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.highlighted
              ? const Color(0xFF2563EB)
              : const Color(0xFFE6EAF0),
          width: widget.highlighted ? 2 : 1,
        ),
        boxShadow: widget.highlighted
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x332563EB),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: thread.customerPhotoUrl.isNotEmpty
                        ? NetworkImage(thread.customerPhotoUrl)
                        : null,
                    child: thread.customerPhotoUrl.isEmpty
                        ? Text(name.characters.first)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (badge.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: '關閉聊天室',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        widget.controller.closeWindow(widget.thread.id),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => widget.controller.touch(widget.thread.id),
              child: ShopChatThreadPane(
                shopId: widget.shopId,
                threadId: widget.thread.id,
                active: true,
                showToolbar: false,
                compact: true,
                focusNode: _focus,
                onUserActivity: () => widget.controller.touch(widget.thread.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
