// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_thread_pane.dart
// 功能說明：店家後台對話內容，完整頁與右側面板共用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_message_model.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_composer.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_member_snapshot.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_message_list.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatThreadPane extends StatefulWidget {
  const ShopChatThreadPane({
    super.key,
    required this.shopId,
    required this.threadId,
    this.active = true,
    this.showToolbar = true,
    this.compact = false,
    this.onBack,
    this.onClose,
    this.onMinimize,
    this.onOpenFull,
    this.focusNode,
    this.onUserActivity,
  });

  final String shopId;
  final String threadId;
  final bool active;
  final bool showToolbar;
  final bool compact;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onOpenFull;
  final FocusNode? focusNode;
  final VoidCallback? onUserActivity;

  @override
  State<ShopChatThreadPane> createState() => _ShopChatThreadPaneState();
}

class _ShopChatThreadPaneState extends State<ShopChatThreadPane> {
  final ScrollController _scroll = ScrollController();
  final List<ShopChatMessageModel> _older = <ShopChatMessageModel>[];
  late final TextEditingController _ownedInput;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _olderExhausted = false;
  bool _showNew = false;
  Map<String, dynamic>? _booking;
  String _senderDisplayName = '';
  String? _lastNewestId;

  TextEditingController get _input {
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    if (workspace != null) {
      return workspace.draftOf(widget.threadId);
    }
    return _ownedInput;
  }

  @override
  void initState() {
    super.initState();
    _ownedInput = TextEditingController();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ShopChatThreadPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId) {
      _older.clear();
      _olderExhausted = false;
      _showNew = false;
      _lastNewestId = null;
      _booking = null;
      _bootstrap();
    } else if (!oldWidget.active && widget.active) {
      _markRead();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ownedInput.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final bool atLatest = _scroll.offset <= 48;
    if (atLatest && _showNew && mounted) {
      setState(() {
        _showNew = false;
      });
    }
  }

  Future<void> _bootstrap() async {
    await Future.wait(<Future<void>>[
      if (widget.active) _markRead(),
      _loadBooking(),
      _loadSenderName(),
    ]);
  }

  Future<void> _markRead() async {
    if (!widget.active) {
      return;
    }
    try {
      await ShopChatService.instance.markShopRead(
        shopId: widget.shopId,
        threadId: widget.threadId,
      );
    } catch (_) {}
  }

  Future<void> _loadBooking() async {
    try {
      final Map<String, dynamic>? booking = await ShopChatService.instance
          .findActiveBooking(
            shopId: widget.shopId,
            customerUid: widget.threadId,
          );
      if (mounted) {
        setState(() {
          _booking = booking;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSenderName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    String name = (user.displayName ?? '').trim();
    try {
      final Map<String, dynamic>? member = await ShopService.instance
          .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
      final String memberName =
          (member?['name'] ?? member?['displayName'] ?? '').toString().trim();
      if (memberName.isNotEmpty) {
        name = memberName;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _senderDisplayName = name;
      });
    }
  }

  Future<void> _sendText() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    widget.onUserActivity?.call();
    setState(() => _sending = true);
    try {
      await ShopChatService.instance.sendTextMessage(
        shopId: widget.shopId,
        senderType: ShopChatSenderTypes.shop,
        threadId: widget.threadId,
        text: text,
        senderDisplayName: _senderDisplayName,
      );
      if (mounted) {
        _input.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'),
            action: SnackBarAction(label: '重試', onPressed: _sendText),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendImage() async {
    if (_sending) {
      return;
    }
    try {
      final XFile? image = await InventoryImageService.instance
          .pickAndValidateImage();
      if (image == null) {
        return;
      }
      widget.onUserActivity?.call();
      setState(() => _sending = true);
      await ShopChatService.instance.sendImageMessage(
        shopId: widget.shopId,
        senderType: ShopChatSenderTypes.shop,
        threadId: widget.threadId,
        image: image,
        senderDisplayName: _senderDisplayName,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _loadOlder(List<ShopChatMessageModel> latest) async {
    if (_loadingOlder || _olderExhausted) {
      return;
    }
    final List<ShopChatMessageModel> all = _merge(latest);
    if (all.isEmpty || all.first.createdAt == null) {
      return;
    }
    setState(() => _loadingOlder = true);
    try {
      final List<ShopChatMessageModel> older = await ShopChatService.instance
          .loadOlderMessages(
            shopId: widget.shopId,
            threadId: widget.threadId,
            before: all.first.createdAt!,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (older.isEmpty) {
          _olderExhausted = true;
        } else {
          _older.insertAll(0, older);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  List<ShopChatMessageModel> _merge(List<ShopChatMessageModel> latest) {
    final Set<String> ids = latest
        .map((ShopChatMessageModel item) => item.id)
        .toSet();
    return <ShopChatMessageModel>[
      ..._older.where((ShopChatMessageModel item) => !ids.contains(item.id)),
      ...latest,
    ];
  }

  void _noteIncoming(List<ShopChatMessageModel> all) {
    if (all.isEmpty) {
      return;
    }
    final String newest = all.last.id;
    if (_lastNewestId == null) {
      _lastNewestId = newest;
      return;
    }
    if (newest == _lastNewestId) {
      return;
    }
    _lastNewestId = newest;
    final bool away = _scroll.hasClients && _scroll.offset > 48;
    if (away && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showNew = true;
          });
        }
      });
    }
  }

  Future<void> _openMember(ShopChatThreadModel? thread) {
    return showShopChatMemberSnapshot(
      context: context,
      shopId: widget.shopId,
      userId: widget.threadId,
      fallbackName: thread?.customerName ?? '',
      fallbackPhone: thread?.customerPhone ?? '',
      asBottomSheet: widget.compact || MediaQuery.sizeOf(context).width < 900,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            final Map<String, dynamic> shop =
                shopSnap.data ?? const <String, dynamic>{};
            final String shopName = (shop['name'] ?? '店家').toString();
            final bool enabled = ShopChatService.isEnabled(shop);
            return StreamBuilder<ShopChatThreadModel?>(
              stream: ShopChatService.instance.watchThread(
                shopId: widget.shopId,
                threadId: widget.threadId,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<ShopChatThreadModel?> threadSnap,
                  ) {
                    final ShopChatThreadModel? thread = threadSnap.data;
                    final String customerName =
                        thread?.customerName.trim().isNotEmpty == true
                        ? thread!.customerName
                        : '會員';
                    final String photo = thread?.customerPhotoUrl ?? '';
                    if (widget.active &&
                        thread != null &&
                        thread.shopUnreadCount > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markRead();
                      });
                    }
                    return Column(
                      children: <Widget>[
                        if (widget.showToolbar)
                          _ThreadToolbar(
                            name: customerName,
                            phone: thread?.customerPhone ?? '',
                            photo: photo,
                            compact: widget.compact,
                            onBack: widget.onBack,
                            onMember: () => _openMember(thread),
                            onOpenFull: widget.onOpenFull,
                            onMinimize: widget.onMinimize,
                            onClose: widget.onClose,
                          ),
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
                        if (_booking != null)
                          _BookingBanner(booking: _booking!),
                        Expanded(
                          child: StreamBuilder<List<ShopChatMessageModel>>(
                            stream: ShopChatService.instance
                                .watchLatestMessages(
                                  shopId: widget.shopId,
                                  threadId: widget.threadId,
                                ),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<ShopChatMessageModel>>
                                  snapshot,
                                ) {
                                  final List<ShopChatMessageModel> latest =
                                      snapshot.data ??
                                      const <ShopChatMessageModel>[];
                                  final List<ShopChatMessageModel> all = _merge(
                                    latest,
                                  );
                                  _noteIncoming(all);
                                  if (all.isEmpty) {
                                    return const Center(child: Text('尚無訊息'));
                                  }
                                  return Stack(
                                    children: <Widget>[
                                      ShopChatMessageList(
                                        messages: all,
                                        shopName: shopName,
                                        primaryColor: primary,
                                        loadingOlder: _loadingOlder,
                                        controller: _scroll,
                                        onLoadOlder: () => _loadOlder(latest),
                                      ),
                                      if (_showNew)
                                        Positioned(
                                          bottom: 12,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: FilledButton.tonal(
                                              onPressed: () {
                                                _scroll.animateTo(
                                                  0,
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),
                                                  curve: Curves.easeOut,
                                                );
                                                setState(() {
                                                  _showNew = false;
                                                });
                                              },
                                              child: const Text('有新訊息'),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                          ),
                        ),
                        ShopChatComposer(
                          controller: _input,
                          focusNode: widget.focusNode,
                          enabled: true,
                          sending: _sending,
                          onSendText: _sendText,
                          onPickImage: _sendImage,
                        ),
                      ],
                    );
                  },
            );
          },
    );
  }
}

class _ThreadToolbar extends StatelessWidget {
  const _ThreadToolbar({
    required this.name,
    required this.phone,
    required this.photo,
    required this.compact,
    this.onBack,
    this.onMember,
    this.onOpenFull,
    this.onMinimize,
    this.onClose,
  });

  final String name;
  final String phone;
  final String photo;
  final bool compact;
  final VoidCallback? onBack;
  final VoidCallback? onMember;
  final VoidCallback? onOpenFull;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: compact ? 56 : 64,
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: '返回對話列表',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            CircleAvatar(
              radius: 16,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? Text(name.characters.first) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '會員資料',
              onPressed: onMember,
              icon: const Icon(Icons.person_outline),
            ),
            if (onOpenFull != null)
              IconButton(
                tooltip: '開啟完整聊天頁',
                onPressed: onOpenFull,
                icon: const Icon(Icons.open_in_full),
              ),
            if (onMinimize != null)
              IconButton(
                tooltip: '最小化',
                onPressed: onMinimize,
                icon: const Icon(Icons.remove),
              ),
            if (onClose != null)
              IconButton(
                tooltip: '關閉',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingBanner extends StatelessWidget {
  const _BookingBanner({required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final String status = (booking['status'] ?? '').toString();
    final String roomName = (booking['roomName'] ?? '').toString().trim();
    final String title = status == 'checked_in' ? '目前入住' : '目前訂單';
    final String stay = _stayLabel(booking);
    return Material(
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (roomName.isNotEmpty)
                    Text(roomName, style: const TextStyle(fontSize: 13)),
                  if (stay.isNotEmpty)
                    Text(stay, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                final String bookingId = (booking['id'] ?? '').toString();
                if (bookingId.isEmpty) {
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminBookingRoute.page(
                      bookingId: bookingId,
                      data: booking,
                    ),
                  ),
                );
              },
              child: const Text('查看訂單'),
            ),
          ],
        ),
      ),
    );
  }

  String _stayLabel(Map<String, dynamic> data) {
    final DateTime? start = _dateOf(data['startDate']);
    final DateTime? end = _dateOf(data['endDate']);
    if (start == null || end == null) {
      return '';
    }
    return '${DateFormat('M/d').format(start)}～${DateFormat('M/d').format(end)}';
  }

  DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
