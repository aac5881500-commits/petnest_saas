// 檔案名稱：lib/features/shop/pages/chat/shop_chat_inbox_page.dart
// 功能說明：店家聊天收件匣

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_thread_page.dart';

class ShopChatInboxPage extends StatefulWidget {
  const ShopChatInboxPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopChatInboxPage> createState() => _ShopChatInboxPageState();
}

class _ShopChatInboxPageState extends State<ShopChatInboxPage> {
  final TextEditingController _search = TextEditingController();
  bool _showArchived = false;
  String _debugRole = '';

  @override
  void initState() {
    super.initState();
    _loadDebugRole();
  }

  Future<void> _loadDebugRole() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final Map<String, dynamic>? member = await ShopService.instance
          .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
      final String role = (member?['role'] ?? '').toString();
      if (mounted) {
        setState(() {
          _debugRole = role.isNotEmpty ? role : 'none';
        });
      }
      debugPrint(
        '[ShopChatInbox] shopId=${widget.shopId} uid=${user.uid} '
        'role=${role.isNotEmpty ? role : 'none'} '
        'path=shops/${widget.shopId}/chat_threads '
        'query=status==active orderBy lastMessageAt desc limit 80',
      );
    } catch (error, stack) {
      debugPrint(
        '[ShopChatInbox] shopId=${widget.shopId} uid=${user.uid} '
        'role=unknown path=shops/${widget.shopId}/chat_threads '
        'query=status==active orderBy lastMessageAt desc limit 80',
      );
      debugPrint('[ShopChatInbox] 失敗：code= memberLookup message=$error');
      debugPrint('[ShopChatInbox] stack=$stack');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ShopChatThreadModel> _filter(List<ShopChatThreadModel> threads) {
    final String keyword = _search.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return threads;
    }
    return threads.where((ShopChatThreadModel thread) {
      return thread.customerName.toLowerCase().contains(keyword) ||
          thread.customerPhone.contains(keyword);
    }).toList();
  }

  Future<void> _archive(ShopChatThreadModel thread) async {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> shopSnap) {
        final bool enabled = ShopChatService.isEnabled(shopSnap.data);
        return Scaffold(
          appBar: AppBar(title: const Text('店家聊天')),
          body: Column(
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜尋會員名稱或電話',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('收件匣')),
                    ButtonSegment<bool>(value: true, label: Text('已封存')),
                  ],
                  selected: <bool>{_showArchived},
                  onSelectionChanged: (Set<bool> value) {
                    setState(() {
                      _showArchived = value.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<ShopChatThreadModel>>(
                  stream: _showArchived
                      ? ShopChatService.instance.watchShopArchivedInbox(
                          widget.shopId,
                        )
                      : ShopChatService.instance.watchShopInbox(widget.shopId),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<ShopChatThreadModel>> snapshot,
                      ) {
                        if (snapshot.hasError) {
                          final Object error = snapshot.error!;
                          final String code = error is FirebaseException
                              ? error.code
                              : error.runtimeType.toString();
                          debugPrint(
                            '[ShopChatInbox] shopId=${widget.shopId} '
                            'uid=${FirebaseAuth.instance.currentUser?.uid} '
                            'role=$_debugRole '
                            'path=shops/${widget.shopId}/chat_threads '
                            'query=status==${_showArchived ? 'archived' : 'active'} '
                            'orderBy lastMessageAt desc limit 80',
                          );
                          debugPrint(
                            '[ShopChatInbox] 失敗：code=$code message=$error',
                          );
                          debugPrint(
                            '[ShopChatInbox] stack=${snapshot.stackTrace}',
                          );
                          return Center(child: Text('載入失敗：$error'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final List<ShopChatThreadModel> threads = _filter(
                          snapshot.data!,
                        );
                        if (threads.isEmpty) {
                          return Center(
                            child: Text(
                              _showArchived ? '沒有已封存的聊天' : '目前沒有聊天訊息',
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: threads.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final ShopChatThreadModel thread = threads[index];
                            final String badge = ShopChatService.badgeLabel(
                              thread.shopUnreadCount,
                            );
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    thread.customerPhotoUrl.isNotEmpty
                                    ? NetworkImage(thread.customerPhotoUrl)
                                    : null,
                                child: thread.customerPhotoUrl.isEmpty
                                    ? Text(
                                        thread.customerName.isNotEmpty
                                            ? thread
                                                  .customerName
                                                  .characters
                                                  .first
                                            : '會',
                                      )
                                    : null,
                              ),
                              title: Text(
                                thread.customerName.isNotEmpty
                                    ? thread.customerName
                                    : '會員',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                thread.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    _timeLabel(thread.lastMessageAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (badge.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 4),
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
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ShopChatThreadPage(
                                      shopId: widget.shopId,
                                      threadId: thread.id,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: _showArchived
                                  ? null
                                  : () async {
                                      final bool?
                                      confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('封存聊天'),
                                            content: const Text(
                                              '封存後會從收件匣隱藏，不會刪除紀錄。會員再傳訊息時會自動恢復。',
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('取消'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('封存'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (confirmed == true) {
                                        await _archive(thread);
                                      }
                                    },
                            );
                          },
                        );
                      },
                ),
              ),
            ],
          ),
        );
      },
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
    return DateFormat('M/d HH:mm').format(time);
  }
}
