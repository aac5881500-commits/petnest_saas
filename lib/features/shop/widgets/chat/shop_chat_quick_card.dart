// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_quick_card.dart
// 功能說明：右側快捷對話小卡，顯示摘要與未讀，不監聽完整訊息。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';

class ShopChatQuickCard extends StatelessWidget {
  const ShopChatQuickCard({
    super.key,
    required this.thread,
    required this.onOpen,
    required this.onRemove,
    this.selected = false,
  });

  final ShopChatThreadModel thread;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final String name = thread.customerName.trim().isEmpty
        ? '會員'
        : thread.customerName.trim();
    final String badge = ShopChatService.badgeLabel(thread.shopUnreadCount);
    final bool unread = thread.shopUnreadCount > 0;
    final String preview = _previewText(thread);
    return Material(
      color: unread ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : unread
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE6EAF0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
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
                        style: TextStyle(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '移除快捷對話',
                      onPressed: onRemove,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _timeLabel(thread.lastMessageAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    if (badge.isNotEmpty)
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _previewText(ShopChatThreadModel thread) {
    if (thread.lastMessageType == 'image') {
      return '圖片';
    }
    final String text = thread.lastMessage.trim();
    if (text.isEmpty) {
      return '尚無訊息';
    }
    return text;
  }

  static String _timeLabel(DateTime? time) {
    if (time == null) {
      return '';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(time.year, time.month, time.day);
    if (day == today) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('M/d HH:mm').format(time);
  }
}
