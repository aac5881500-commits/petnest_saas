// lib/features/shop/pages/chat/shop_chat_thread_page.dart
// 💬 店家後台與會員的對話頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/shop_chat_message_model.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_composer.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_message_list.dart';

class ShopChatThreadPage extends StatefulWidget {
  const ShopChatThreadPage({
    super.key,
    required this.shopId,
    required this.threadId,
  });

  final String shopId;
  final String threadId;

  @override
  State<ShopChatThreadPage> createState() => _ShopChatThreadPageState();
}

class _ShopChatThreadPageState extends State<ShopChatThreadPage> {
  final TextEditingController _input = TextEditingController();
  final List<ShopChatMessageModel> _older = <ShopChatMessageModel>[];
  bool _sending = false;
  bool _loadingOlder = false;
  bool _olderExhausted = false;
  Map<String, dynamic>? _booking;
  String _senderDisplayName = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait(<Future<void>>[
      _markRead(),
      _loadBooking(),
      _loadSenderName(),
    ]);
  }

  Future<void> _markRead() async {
    try {
      await ShopChatService.instance.markShopRead(
        shopId: widget.shopId,
        threadId: widget.threadId,
      );
    } catch (_) {}
  }

  Future<void> _loadBooking() async {
    try {
      final Map<String, dynamic>? booking =
          await ShopChatService.instance.findActiveBooking(
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
      final Map<String, dynamic>? member =
          await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );
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
    setState(() => _sending = true);
    try {
      await ShopChatService.instance.sendTextMessage(
        shopId: widget.shopId,
        senderType: ShopChatSenderTypes.shop,
        threadId: widget.threadId,
        text: text,
        senderDisplayName: _senderDisplayName,
      );
      _input.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
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
      final XFile? image =
          await InventoryImageService.instance.pickAndValidateImage();
      if (image == null) {
        return;
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
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
      final List<ShopChatMessageModel> older =
          await ShopChatService.instance.loadOlderMessages(
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
    final Set<String> ids =
        latest.map((ShopChatMessageModel item) => item.id).toSet();
    return <ShopChatMessageModel>[
      ..._older.where((ShopChatMessageModel item) => !ids.contains(item.id)),
      ...latest,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder: (
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
          builder: (
            BuildContext context,
            AsyncSnapshot<ShopChatThreadModel?> threadSnap,
          ) {
            final ShopChatThreadModel? thread = threadSnap.data;
            final String customerName = thread?.customerName.trim().isNotEmpty ==
                    true
                ? thread!.customerName
                : '會員';
            final String photo = thread?.customerPhotoUrl ?? '';
            if (thread != null && thread.shopUnreadCount > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _markRead();
              });
            }
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? Text(
                              customerName.characters.first,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
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
                  if (_booking != null) _BookingBanner(booking: _booking!),
                  Expanded(
                    child: StreamBuilder<List<ShopChatMessageModel>>(
                      stream: ShopChatService.instance.watchLatestMessages(
                        shopId: widget.shopId,
                        threadId: widget.threadId,
                      ),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<List<ShopChatMessageModel>> snapshot,
                      ) {
                        final List<ShopChatMessageModel> latest =
                            snapshot.data ?? const <ShopChatMessageModel>[];
                        final List<ShopChatMessageModel> all = _merge(latest);
                        if (all.isEmpty) {
                          return const Center(child: Text('尚無訊息'));
                        }
                        return ShopChatMessageList(
                          messages: all,
                          shopName: shopName,
                          primaryColor: const Color(0xFFFF8A00),
                          loadingOlder: _loadingOlder,
                          onLoadOlder: () => _loadOlder(latest),
                        );
                      },
                    ),
                  ),
                  ShopChatComposer(
                    controller: _input,
                    enabled: true,
                    sending: _sending,
                    onSendText: _sendText,
                    onPickImage: _sendImage,
                  ),
                ],
              ),
            );
          },
        );
      },
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
      color: const Color(0xFFFFF4E8),
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
                    builder: (_) => AdminBookingDetailPage(bookingId: bookingId),
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
