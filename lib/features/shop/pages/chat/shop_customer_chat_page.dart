// lib/features/shop/pages/chat/shop_customer_chat_page.dart
// 💬 會員端店家聊天室

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/models/shop_chat_message_model.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/auth/pages/login_page.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_composer.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_message_list.dart';

class ShopCustomerChatPage extends StatefulWidget {
  const ShopCustomerChatPage({
    super.key,
    required this.shopId,
    this.shopName = '',
    this.shopLogoUrl = '',
  });

  final String shopId;
  final String shopName;
  final String shopLogoUrl;

  @override
  State<ShopCustomerChatPage> createState() => _ShopCustomerChatPageState();
}

class _ShopCustomerChatPageState extends State<ShopCustomerChatPage> {
  final TextEditingController _input = TextEditingController();
  final List<ShopChatMessageModel> _older = <ShopChatMessageModel>[];
  bool _sending = false;
  bool _loadingOlder = false;
  bool _olderExhausted = false;
  Stream<Map<String, dynamic>?>? _shopStream;
  Stream<List<ShopChatMessageModel>>? _messagesStream;
  Stream<ShopChatThreadModel?>? _threadStream;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  void _bindStreams() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String shopId = widget.shopId.trim();
    print('[CustomerChatPage] STEP 0 start uid=$uid shopId=$shopId');
    if (shopId.isEmpty) {
      print('[CustomerChatPage] STEP 0 failed type=StateError');
      print('error=shopId is empty');
      print(StackTrace.current);
      return;
    }
    if (uid.isEmpty) {
      print('[CustomerChatPage] STEP 0 failed type=StateError');
      print('error=FirebaseAuth.instance.currentUser is null');
      print(StackTrace.current);
      return;
    }
    final String threadPath = 'shops/$shopId/chat_threads/$uid';
    final String messagesPath = '$threadPath/messages';
    print('[CustomerChatPage] STEP 1 start');
    print('[CustomerChatPage] thread path=$threadPath');
    print('[CustomerChatPage] messages path=$messagesPath');
    try {
      _shopStream = ShopService.instance.streamShop(shopId);
      _messagesStream = ShopChatService.instance.watchLatestMessages(
        shopId: shopId,
        threadId: uid,
      );
      _threadStream = ShopChatService.instance.watchThreadIfMessagesExist(
        shopId: shopId,
        threadId: uid,
        source: 'CustomerChatPage',
      );
      print('[CustomerChatPage] STEP 1 success');
    } catch (e, st) {
      print('[CustomerChatPage] STEP 1 failed');
      ChatErrorProbe.dump('CustomerChatPage STEP 1', e, st);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    print('[CustomerChatPage] STEP 5 markRead start uid=$_uid shopId=${widget.shopId}');
    if (_uid.isEmpty) {
      print('[CustomerChatPage] STEP 5 skip null uid');
      return;
    }
    try {
      await ShopChatService.instance.markCustomerRead(
        shopId: widget.shopId,
        threadId: _uid,
      );
      print('[CustomerChatPage] STEP 5 success');
    } catch (e, st) {
      print('[CustomerChatPage] STEP 5 failed');
      ChatErrorProbe.dump('CustomerChatPage markRead', e, st);
    }
  }

  Future<void> _sendText() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final Map<String, String> snapshot =
          await ShopChatService.instance.loadCustomerSnapshot();
      await ShopChatService.instance.sendTextMessage(
        shopId: widget.shopId,
        senderType: ShopChatSenderTypes.customer,
        text: text,
        customerSnapshot: snapshot,
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
      final Map<String, String> snapshot =
          await ShopChatService.instance.loadCustomerSnapshot();
      await ShopChatService.instance.sendImageMessage(
        shopId: widget.shopId,
        senderType: ShopChatSenderTypes.customer,
        image: image,
        customerSnapshot: snapshot,
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
        threadId: _uid,
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

  Color _primaryOf(Map<String, dynamic> shop) {
    try {
      final dynamic appearance = shop['homeAppearance'];
      if (appearance is Map) {
        final dynamic modern = appearance['modern'];
        if (modern is Map) {
          final dynamic colors = modern['themeColors'];
          if (colors is Map && colors['primaryColorValue'] is int) {
            return Color(colors['primaryColorValue'] as int);
          }
        }
      }
    } catch (_) {}
    return const Color(0xFFFF8A00);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('店家訊息')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('登入會員後即可與店家聊天'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            LoginPage(redirectShopId: widget.shopId),
                      ),
                    );
                  },
                  child: const Text('登入'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _shopStream ?? Stream<Map<String, dynamic>?>.value(null),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>?> shopSnap,
      ) {
        final Map<String, dynamic> shop =
            shopSnap.data ?? const <String, dynamic>{};
        final String shopName = widget.shopName.trim().isNotEmpty
            ? widget.shopName
            : (shop['name'] ?? '店家').toString();
        final String logo = widget.shopLogoUrl.trim().isNotEmpty
            ? widget.shopLogoUrl
            : (shop['logoUrl'] ?? '').toString();
        final bool enabled = ShopChatService.isEnabled(shop);
        final Color buttonColor = _primaryOf(shop);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      logo.isNotEmpty ? NetworkImage(logo) : null,
                  child: logo.isEmpty
                      ? const Icon(Icons.storefront_outlined, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Text(
                        '通常會盡快回覆',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
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
              Expanded(
                child: StreamBuilder<List<ShopChatMessageModel>>(
                  stream: _messagesStream ??
                      Stream<List<ShopChatMessageModel>>.value(
                        const <ShopChatMessageModel>[],
                      ),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<ShopChatMessageModel>> snapshot,
                  ) {
                    final List<ShopChatMessageModel> latest =
                        snapshot.data ?? const <ShopChatMessageModel>[];
                    final List<ShopChatMessageModel> all = _merge(latest);
                    if (all.isEmpty) {
                      return const Center(child: Text('開始與店家聊天吧'));
                    }
                    return StreamBuilder<ShopChatThreadModel?>(
                      stream: _threadStream ??
                          Stream<ShopChatThreadModel?>.value(null),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<ShopChatThreadModel?> threadSnap,
                      ) {
                        final ShopChatThreadModel? thread = threadSnap.data;
                        if (thread != null && thread.customerUnreadCount > 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _markRead();
                          });
                        }
                        return ShopChatMessageList(
                          messages: all,
                          shopName: shopName,
                          primaryColor: buttonColor,
                          showShopReadReceipt: true,
                          shopHasReadLast:
                              threadSnap.data?.shopHasReadLastCustomerMessage ??
                                  false,
                          loadingOlder: _loadingOlder,
                          onLoadOlder: () => _loadOlder(latest),
                        );
                      },
                    );
                  },
                ),
              ),
              ShopChatComposer(
                controller: _input,
                enabled: enabled,
                sending: _sending,
                onSendText: _sendText,
                onPickImage: _sendImage,
              ),
            ],
          ),
        );
      },
    );
  }
}
