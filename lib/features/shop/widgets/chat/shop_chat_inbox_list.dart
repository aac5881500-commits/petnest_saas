// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_inbox_list.dart
// 功能說明：店家聊天對話列表，完整頁與右側面板共用。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class ShopChatInboxList extends StatefulWidget {
  const ShopChatInboxList({
    super.key,
    required this.shopId,
    required this.onOpenThread,
    this.filter = 'inbox',
    this.query = '',
    this.compact = false,
    this.selectedThreadId,
    this.openedThreadIds = const <String>{},
    this.onFilterChanged,
    this.onQueryChanged,
  });

  final String shopId;
  final ValueChanged<ShopChatThreadModel> onOpenThread;
  final String filter;
  final String query;
  final bool compact;
  final String? selectedThreadId;
  final Set<String> openedThreadIds;
  final ValueChanged<String>? onFilterChanged;
  final ValueChanged<String>? onQueryChanged;

  @override
  State<ShopChatInboxList> createState() => _ShopChatInboxListState();
}

class _ShopChatInboxListState extends State<ShopChatInboxList> {
  late final TextEditingController _search;
  int _retry = 0;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant ShopChatInboxList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _search.text != widget.query) {
      _search.text = widget.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ShopChatThreadModel> _apply(
    List<ShopChatThreadModel> threads, {
    required String filter,
    required String keyword,
  }) {
    Iterable<ShopChatThreadModel> result = threads;
    if (filter == 'unread') {
      result = result.where(
        (ShopChatThreadModel item) => item.shopUnreadCount > 0,
      );
    }
    final String needle = keyword.trim().toLowerCase();
    if (needle.isNotEmpty) {
      result = result.where((ShopChatThreadModel thread) {
        return thread.customerName.toLowerCase().contains(needle) ||
            thread.customerPhone.toLowerCase().contains(needle);
      });
    }
    final List<ShopChatThreadModel> list = result.toList();
    list.sort((ShopChatThreadModel a, ShopChatThreadModel b) {
      final int unread = (b.shopUnreadCount > 0 ? 1 : 0).compareTo(
        a.shopUnreadCount > 0 ? 1 : 0,
      );
      if (unread != 0) {
        return unread;
      }
      final DateTime at =
          a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bt =
          b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return list;
  }

  Future<void> _archive(ShopChatThreadModel thread) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('封存聊天'),
          content: const Text('封存後會從收件匣隱藏，不會刪除紀錄。會員再傳訊息時會自動恢復。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('封存'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ShopChatService.instance.archiveThread(
        shopId: widget.shopId,
        threadId: thread.id,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  String _emptyLabel(String filter, String keyword) {
    if (keyword.trim().isNotEmpty) {
      return '找不到符合的會員';
    }
    if (filter == 'unread') {
      return '目前沒有未讀訊息';
    }
    if (filter == 'archived') {
      return '目前沒有對話';
    }
    return '目前沒有對話';
  }

  @override
  Widget build(BuildContext context) {
    final String filter = widget.filter;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            final bool enabled = ShopChatService.isEnabled(shopSnap.data);
            return Column(
              children: <Widget>[
                if (!enabled)
                  Material(
                    color: Colors.orange.shade50,
                    child: const SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('店家聊天目前已關閉'),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.compact ? 6 : 12,
                    8,
                    widget.compact ? 6 : 12,
                    8,
                  ),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: widget.compact ? 18 : 24,
                      ),
                      prefixIconConstraints: widget.compact
                          ? const BoxConstraints(minWidth: 32, minHeight: 32)
                          : null,
                      hintText: widget.compact ? '搜尋會員' : '搜尋會員名稱或電話',
                      hintMaxLines: 1,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      widget.onQueryChanged?.call(value);
                      setState(() {});
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 6 : 12,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'inbox',
                          label: Text('收件匣'),
                        ),
                        ButtonSegment<String>(
                          value: 'unread',
                          label: Text('未讀'),
                        ),
                        ButtonSegment<String>(
                          value: 'archived',
                          label: Text('已封存'),
                        ),
                      ],
                      selected: <String>{filter},
                      onSelectionChanged: (Set<String> value) {
                        widget.onFilterChanged?.call(value.first);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<ShopChatThreadModel>>(
                    key: ValueKey<String>('inbox-$filter-$_retry'),
                    stream: filter == 'archived'
                        ? ShopChatService.instance.watchShopArchivedInbox(
                            widget.shopId,
                          )
                        : ShopChatService.instance.watchShopInbox(
                            widget.shopId,
                          ),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<ShopChatThreadModel>> snapshot,
                        ) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Text('載入失敗'),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: () {
                                      setState(() {
                                        _retry += 1;
                                      });
                                    },
                                    child: const Text('重試'),
                                  ),
                                ],
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final List<ShopChatThreadModel> threads = _apply(
                            snapshot.data!,
                            filter: filter,
                            keyword: _search.text,
                          );
                          if (threads.isEmpty) {
                            return Center(
                              child: Text(_emptyLabel(filter, _search.text)),
                            );
                          }
                          return ListView.separated(
                            itemCount: threads.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final ShopChatThreadModel thread = threads[index];
                              return _ThreadTile(
                                thread: thread,
                                selected: widget.selectedThreadId == thread.id,
                                opened: widget.openedThreadIds.contains(
                                  thread.id,
                                ),
                                compact: widget.compact,
                                minHeight: widget.compact ? 52 : 64,
                                onTap: () => widget.onOpenThread(thread),
                                onArchive: filter == 'archived'
                                    ? null
                                    : () => _archive(thread),
                              );
                            },
                          );
                        },
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.onTap,
    required this.minHeight,
    this.compact = false,
    this.selected = false,
    this.opened = false,
    this.onArchive,
  });

  final ShopChatThreadModel thread;
  final VoidCallback onTap;
  final double minHeight;
  final bool compact;
  final bool selected;
  final bool opened;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final String badge = ShopChatService.badgeLabel(thread.shopUnreadCount);
    final String name = thread.customerName.trim().isEmpty
        ? '會員'
        : thread.customerName;
    return InkWell(
      onTap: onTap,
      onLongPress: onArchive,
      child: ColoredBox(
        color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 12,
              vertical: 8,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: compact ? 14 : 20,
                  backgroundImage: thread.customerPhotoUrl.isNotEmpty
                      ? NetworkImage(thread.customerPhotoUrl)
                      : null,
                  child: thread.customerPhotoUrl.isEmpty
                      ? Text(
                          name.characters.first,
                          style: TextStyle(fontSize: compact ? 12 : 14),
                        )
                      : null,
                ),
                SizedBox(width: compact ? 6 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                fontWeight: thread.shopUnreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _timeLabel(thread.lastMessageAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              thread.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 12 : 14,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          if (opened)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                '已開啟',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ),
                          if (thread.isArchived)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text(
                                '已封存',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          if (badge.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 6),
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime? time) {
    if (time == null) {
      return '';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(time.year, time.month, time.day);
    if (day == today) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat(compact ? 'M/d' : 'M/d HH:mm').format(time);
  }
}
