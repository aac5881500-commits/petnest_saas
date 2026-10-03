// 檔案名稱：lib/features/support/widgets/contact_case_chat.dart
// 功能說明：店主與平台共用的聯絡案件聊天室。結案後停止輸入，較舊訊息分批載入。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:petnest_saas/features/support/contact_case_labels.dart';

enum ContactCaseViewer { shopOwner, platform }

class ContactCaseChat extends StatefulWidget {
  const ContactCaseChat({
    super.key,
    required this.requestId,
    required this.viewer,
    this.embedded = false,
    this.onCreateNewCase,
  });

  final String requestId;
  final ContactCaseViewer viewer;
  final bool embedded;
  final void Function(String shopId)? onCreateNewCase;

  @override
  State<ContactCaseChat> createState() => _ContactCaseChatState();
}

class _ContactCaseChatState extends State<ContactCaseChat> {
  final TextEditingController _input = TextEditingController();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _request;
  bool _sending = false;
  String? _sendError;

  bool get _platform => widget.viewer == ContactCaseViewer.platform;

  @override
  void initState() {
    super.initState();
    _request = _openRequest();
    _input.addListener(_onInput);
  }

  @override
  void dispose() {
    _input.removeListener(_onInput);
    _input.dispose();
    super.dispose();
  }

  void _onInput() {
    if (mounted) {
      setState(() {});
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _openRequest() {
    return FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .doc(widget.requestId)
        .snapshots();
  }

  Future<void> _send(String status) async {
    final String message = _input.text.trim();
    if (message.isEmpty || _sending || status == 'closed') {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _sendError = '請先登入後再送出');
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final DocumentReference<Map<String, dynamic>> requestRef = FirebaseFirestore
        .instance
        .collection('platform_contact_requests')
        .doc(widget.requestId);
    final DocumentReference<Map<String, dynamic>> messageRef = requestRef
        .collection('messages')
        .doc();
    final FieldValue now = FieldValue.serverTimestamp();
    final String senderType = _platform ? 'platform' : 'shop_owner';
    try {
      if (_platform) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.set(messageRef, <String, dynamic>{
            'senderType': senderType,
            'senderUid': user.uid,
            'senderEmail': user.email ?? '',
            'message': message,
            'imageUrls': <String>[],
            'createdAt': now,
          });
          transaction.update(requestRef, <String, dynamic>{
            'status': 'processing',
            'lastMessage': message,
            'lastMessageAt': now,
            'lastSenderType': senderType,
            'updatedAt': now,
          });
        });
      } else {
        await messageRef.set(<String, dynamic>{
          'senderType': senderType,
          'senderUid': user.uid,
          'senderEmail': user.email ?? '',
          'message': message,
          'imageUrls': <String>[],
          'createdAt': now,
        });
        try {
          await requestRef.update(<String, dynamic>{
            'lastMessage': message,
            'lastMessageAt': now,
            'lastSenderType': senderType,
            'updatedAt': now,
          });
        } catch (error) {
          debugPrint('更新案件摘要失敗：$error');
        }
      }
      if (!mounted) {
        return;
      }
      _input.clear();
      setState(() {
        _sending = false;
        _sendError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _sendError = '訊息沒有送出，內容已保留';
      });
      debugPrint('送出聯絡案件訊息失敗：$error');
    }
  }

  Future<void> _setStatus(String status) async {
    if (status == 'closed') {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('結案'),
            content: const Text('結案後雙方都不能再回覆，對話紀錄會保留。確定要結案嗎？'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('結案'),
              ),
            ],
          );
        },
      );
      if (ok != true || !mounted) {
        return;
      }
    }
    try {
      await FirebaseFirestore.instance
          .collection('platform_contact_requests')
          .doc(widget.requestId)
          .update(<String, dynamic>{
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('狀態更新失敗：$error')));
    }
  }

  void _showInfo(Map<String, dynamic> data) {
    final String created = _timeText(data['createdAt']);
    final String updated = _timeText(data['updatedAt']);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            children: <Widget>[
              const Text(
                '案件資訊',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _InfoLine(
                label: '店名',
                value: (data['shopName'] ?? '').toString(),
              ),
              _InfoLine(
                label: '分類',
                value: (data['category'] ?? '').toString(),
              ),
              _InfoLine(label: '建立時間', value: created),
              _InfoLine(label: '更新時間', value: updated),
              _InfoLine(
                label: '來源',
                value: (data['source'] ?? '').toString() == 'member'
                    ? '會員'
                    : '店主',
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('技術資訊'),
                children: <Widget>[
                  _InfoLine(label: '案件 ID', value: widget.requestId),
                  _InfoLine(
                    label: '店家 ID',
                    value: (data['shopId'] ?? '').toString(),
                  ),
                  _InfoLine(
                    label: '店編',
                    value: (data['shopCode'] ?? '').toString(),
                  ),
                  _InfoLine(
                    label: '使用者 ID',
                    value: (data['userId'] ?? '').toString(),
                  ),
                  _InfoLine(
                    label: '帳號',
                    value: (data['userEmail'] ?? '').toString(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _request,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return _StateBlock(
                icon: Icons.error_outline,
                title: '案件讀取失敗',
                message: '請確認你有查看這筆案件的權限後再試。',
                action: '重試',
                onPressed: () => setState(() => _request = _openRequest()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const _StateBlock(
                icon: Icons.forum_outlined,
                title: '找不到案件',
                message: '這筆案件可能已不存在。',
              );
            }
            final Map<String, dynamic> data = snapshot.data!.data() ?? {};
            final String status = (data['status'] ?? 'open').toString();
            final String title = (data['title'] ?? '未填標題').toString();
            final String category = (data['category'] ?? '未分類').toString();
            final bool closed = status == 'closed';
            return Column(
              children: <Widget>[
                _Header(
                  embedded: widget.embedded,
                  title: title,
                  category: category,
                  status: status,
                  platform: _platform,
                  onInfo: () => _showInfo(data),
                  onStatus: _setStatus,
                ),
                Expanded(
                  child: _Transcript(
                    requestId: widget.requestId,
                    platformViewer: _platform,
                    request: data,
                  ),
                ),
                if (closed)
                  _ClosedBar(
                    shopId: (data['shopId'] ?? '').toString(),
                    onCreateNewCase: widget.onCreateNewCase,
                  )
                else
                  _Composer(
                    controller: _input,
                    sending: _sending,
                    error: _sendError,
                    platform: _platform,
                    onSend: () => _send(status),
                  ),
              ],
            );
          },
    );
    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF6F7FB), child: body);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      resizeToAvoidBottomInset: true,
      body: body,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.embedded,
    required this.title,
    required this.category,
    required this.status,
    required this.platform,
    required this.onInfo,
    required this.onStatus,
  });

  final bool embedded;
  final String title;
  final String category;
  final String status;
  final bool platform;
  final VoidCallback onInfo;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        top: !embedded,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: <Widget>[
              if (!embedded) const BackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _TinyChip(text: category),
                        _StatusChip(status: status),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '案件資訊',
                onPressed: onInfo,
                icon: const Icon(Icons.info_outline),
              ),
              if (platform && status != 'closed')
                PopupMenuButton<String>(
                  tooltip: '案件操作',
                  onSelected: onStatus,
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<String>>[
                      if (status != 'processing')
                        const PopupMenuItem<String>(
                          value: 'processing',
                          child: Text('標記處理中'),
                        ),
                      const PopupMenuItem<String>(
                        value: 'closed',
                        child: Text('結案'),
                      ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.error,
    required this.platform,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final String? error;
  final bool platform;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bool canSend = !sending && controller.text.trim().isNotEmpty;
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ),
                      TextButton(onPressed: onSend, child: const Text('重試')),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (platform)
                    PopupMenuButton<String>(
                      tooltip: '快捷回覆',
                      icon: const Icon(Icons.quickreply_outlined),
                      onSelected: (String value) {
                        controller.text = value;
                        controller.selection = TextSelection.collapsed(
                          offset: value.length,
                        );
                      },
                      itemBuilder: (BuildContext context) {
                        return contactPlatformQuickReplies
                            .map(
                              (String text) => PopupMenuItem<String>(
                                value: text,
                                child: SizedBox(width: 280, child: Text(text)),
                              ),
                            )
                            .toList();
                      },
                    ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !sending,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '輸入訊息',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: '送出',
                    onPressed: canSend ? onSend : null,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.shopId, required this.onCreateNewCase});

  final String shopId;
  final void Function(String shopId)? onCreateNewCase;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '此案件已結案，對話紀錄已保留，不能再回覆。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569)),
              ),
              if (onCreateNewCase != null && shopId.isNotEmpty)
                TextButton(
                  onPressed: () => onCreateNewCase!(shopId),
                  child: const Text('建立新案件'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Transcript extends StatefulWidget {
  const _Transcript({
    required this.requestId,
    required this.platformViewer,
    required this.request,
  });

  final String requestId;
  final bool platformViewer;
  final Map<String, dynamic> request;

  @override
  State<_Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<_Transcript> {
  final ScrollController _scroll = ScrollController();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _live;
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _seen =
      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  bool _hasMore = false;
  bool _moreReady = false;
  bool _loadingOlder = false;
  bool _stickToBottom = true;
  bool _showNew = false;
  bool _jumped = false;
  String? _newestId;

  @override
  void initState() {
    super.initState();
    _live = _openLive();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _base() {
    return FirebaseFirestore.instance
        .collection('platform_contact_requests')
        .doc(widget.requestId)
        .collection('messages')
        .orderBy('createdAt', descending: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _openLive() {
    return _base().limit(contactMessagePageSize).snapshots();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final double gap =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    final bool stick = gap < 72;
    if (stick == _stickToBottom && !(stick && _showNew)) {
      _stickToBottom = stick;
      return;
    }
    setState(() {
      _stickToBottom = stick;
      if (stick) {
        _showNew = false;
      }
    });
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      if (_jumped && !_stickToBottom) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _jumped = true;
    });
  }

  void _noteNewest(String? newest) {
    final bool changed = newest != _newestId;
    if (!changed && _jumped) {
      return;
    }
    final String? previous = _newestId;
    if (changed) {
      _newestId = newest;
    }
    if (changed && previous != null && !_stickToBottom) {
      if (!_showNew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _showNew = true);
          }
        });
      }
      return;
    }
    if (!_jumped || _stickToBottom) {
      _jumpToLatest();
    }
  }

  Future<void> _loadOlder(
    QueryDocumentSnapshot<Map<String, dynamic>> oldest,
  ) async {
    if (_loadingOlder) {
      return;
    }
    final double beforeExtent = _scroll.hasClients
        ? _scroll.position.maxScrollExtent
        : 0;
    final double beforePixels = _scroll.hasClients
        ? _scroll.position.pixels
        : 0;
    setState(() => _loadingOlder = true);
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _base()
          .startAfterDocument(oldest)
          .limit(contactMessagePageSize)
          .get();
      if (!mounted) {
        return;
      }
      setState(() {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          _seen[doc.id] = doc;
        }
        _hasMore = snap.docs.length >= contactMessagePageSize;
        _loadingOlder = false;
        _stickToBottom = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) {
          return;
        }
        final double delta = _scroll.position.maxScrollExtent - beforeExtent;
        _scroll.jumpTo(beforePixels + delta);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingOlder = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('較早的訊息載入失敗，請再試一次')));
      debugPrint('載入較早聯絡訊息失敗：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _live,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return _StateBlock(
                icon: Icons.error_outline,
                title: '訊息讀取失敗',
                message: '請確認權限後再試。',
                action: '重試',
                onPressed: () {
                  setState(() {
                    _seen.clear();
                    _moreReady = false;
                    _jumped = false;
                    _newestId = null;
                    _live = _openLive();
                  });
                },
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> live =
                snapshot.data!.docs;
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in live) {
              _seen[doc.id] = doc;
            }
            if (!_moreReady) {
              _moreReady = true;
              _hasMore = live.length >= contactMessagePageSize;
            }
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages =
                _seen.values.toList()..sort((
                  QueryDocumentSnapshot<Map<String, dynamic>> a,
                  QueryDocumentSnapshot<Map<String, dynamic>> b,
                ) {
                  return _millis(
                    a.data()['createdAt'],
                  ).compareTo(_millis(b.data()['createdAt']));
                });
            _noteNewest(live.isEmpty ? null : live.first.id);
            final DateTime? openingTime = _date(widget.request['createdAt']);
            String? previousDay = openingTime == null
                ? null
                : contactDayLabel(openingTime);
            return Stack(
              children: <Widget>[
                ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  children: <Widget>[
                    if (openingTime != null)
                      _DayDivider(label: contactDayLabel(openingTime)),
                    _Bubble(
                      mine: contactBubbleIsMine(
                        platformViewer: widget.platformViewer,
                        senderType: contactOpeningSenderType(
                          (widget.request['source'] ?? '').toString(),
                        ),
                      ),
                      sender: contactSenderLabel(
                        contactOpeningSenderType(
                          (widget.request['source'] ?? '').toString(),
                        ),
                      ),
                      time: openingTime == null
                          ? ''
                          : contactClockLabel(openingTime),
                      text: (widget.request['content'] ?? '').toString(),
                      imageUrls: _urls(widget.request['imageUrls']),
                    ),
                    if (_hasMore)
                      Align(
                        child: TextButton(
                          onPressed: _loadingOlder || messages.isEmpty
                              ? null
                              : () => _loadOlder(messages.first),
                          child: Text(_loadingOlder ? '載入中' : '載入較早訊息'),
                        ),
                      ),
                    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                        in messages) ...<Widget>[
                      ..._dateAndBubble(doc, previousDay, (String day) {
                        previousDay = day;
                      }),
                    ],
                  ],
                ),
                if (_showNew)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showNew = false;
                            _stickToBottom = true;
                          });
                          _jumpToLatest();
                        },
                        child: const Text('有新訊息'),
                      ),
                    ),
                  ),
              ],
            );
          },
    );
  }

  List<Widget> _dateAndBubble(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String? previousDay,
    void Function(String day) remember,
  ) {
    final Map<String, dynamic> data = doc.data();
    final DateTime? time = _date(data['createdAt']);
    final String senderType = (data['senderType'] ?? '').toString();
    final List<Widget> items = <Widget>[];
    if (time != null) {
      final String day = contactDayLabel(time);
      if (day != previousDay) {
        items.add(_DayDivider(label: day));
      }
      remember(day);
    }
    items.add(
      _Bubble(
        mine: contactBubbleIsMine(
          platformViewer: widget.platformViewer,
          senderType: senderType,
        ),
        sender: contactSenderLabel(senderType),
        time: time == null ? '' : contactClockLabel(time),
        text: (data['message'] ?? '').toString(),
        imageUrls: _urls(data['imageUrls']),
      ),
    );
    return items;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.sender,
    required this.time,
    required this.text,
    required this.imageUrls,
  });

  final bool mine;
  final String sender;
  final String time;
  final String text;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final String body = text.trim().isEmpty && imageUrls.isEmpty
        ? '（沒有文字內容）'
        : text.trim();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(220, 520)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                time.isEmpty ? sender : '$sender  $time',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: mine ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  border: mine
                      ? null
                      : Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (body.isNotEmpty)
                        Text(
                          body,
                          style: TextStyle(
                            height: 1.4,
                            color: mine
                                ? Colors.white
                                : const Color(0xFF172238),
                          ),
                        ),
                      if (imageUrls.isNotEmpty) ...<Widget>[
                        if (body.isNotEmpty) const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: imageUrls.map((String url) {
                            return _Thumb(url: url);
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
                return const _ImageFallback(compact: true);
              },
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 96 : double.infinity,
      height: compact ? 96 : 180,
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: Color(0xFF64748B)),
          SizedBox(height: 4),
          Text('圖片無法載入', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      'processing' => (const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
      'closed' => (const Color(0xFF475569), const Color(0xFFF1F5F9)),
      _ => (const Color(0xFFB45309), const Color(0xFFFFF7ED)),
    };
    return _TinyChip(text: contactCaseStatusLabel(status), fg: fg, bg: bg);
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.text, this.fg, this.bg});

  final String text;
  final Color? fg;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg ?? const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(child: SelectableText(value.trim().isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onPressed, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

void _openImage(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return const _ImageFallback(compact: false);
                },
          ),
        ),
      );
    },
  );
}

List<String> _urls(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((Object? item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

DateTime? _date(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toLocal();
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  return null;
}

String _timeText(Object? value) {
  final DateTime? time = _date(value);
  if (time == null) {
    return '-';
  }
  return '${contactDayLabel(time)} ${contactClockLabel(time)}';
}

int _millis(Object? value) {
  final DateTime? time = _date(value);
  return time?.millisecondsSinceEpoch ?? 0;
}
