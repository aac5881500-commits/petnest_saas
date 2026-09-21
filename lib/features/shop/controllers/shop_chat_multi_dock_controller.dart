// 檔案名稱：lib/features/shop/controllers/shop_chat_multi_dock_controller.dart
// 功能說明：右側最多六個可同時操作的聊天小視窗；LRU 替換與本機草稿，不寫入聊天文件。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShopChatOpenKind { added, focusedExisting, replaced, rejectedFull }

class ShopChatOpenResult {
  const ShopChatOpenResult({
    required this.kind,
    required this.threadId,
    this.replacedId,
  });

  final ShopChatOpenKind kind;
  final String threadId;
  final String? replacedId;
}

class ShopChatMultiDockPlacement {
  ShopChatMultiDockPlacement._();

  static const double overlayMinWidth = 1100;
  static const double inlineMinWidth = 1600;
  static const double inboxWidth = 360;
  static const double dockWidth = 720;
  static const double twoColumnMinWidth = 520;

  static bool useInlineDock({
    required double pageWidth,
    required bool frontendEmbedded,
  }) {
    return pageWidth >= inlineMinWidth && !frontendEmbedded;
  }

  static bool useOverlayDock({
    required double pageWidth,
    required bool frontendEmbedded,
  }) {
    if (pageWidth < overlayMinWidth) {
      return true;
    }
    if (frontendEmbedded) {
      return true;
    }
    return pageWidth < inlineMinWidth;
  }
}

class ShopChatMultiDockController extends ChangeNotifier {
  ShopChatMultiDockController({this.maxSlots = 6});

  static const int defaultMaxSlots = 6;
  final int maxSlots;

  /// 顯示順序：index 0 為左上（最近使用）。
  final List<String> openIds = <String>[];

  /// 桌機右側最多三格，由上到下為開啟順序。
  final List<String> slotIds = <String>[];
  final Map<String, DateTime> lastActiveAt = <String, DateTime>{};
  final Map<String, ShopChatThreadModel> snapshots =
      <String, ShopChatThreadModel>{};
  final Map<String, String> drafts = <String, String>{};
  final Map<String, TextEditingController> _inputs =
      <String, TextEditingController>{};
  final Set<String> liveMessageListeners = <String>{};
  final Map<String, GlobalKey> windowKeys = <String, GlobalKey>{};

  bool inboxOpen = false;
  bool dockOpen = false;
  bool dockMinimized = false;
  String? highlightId;
  String? lastReplacedId;
  String? focusedThreadId;

  StreamSubscription<List<ShopChatThreadModel>>? _inboxSub;
  String _shopId = '';
  String _uid = '';
  Timer? _highlightTimer;

  static String prefsKey(String uid, String shopId) {
    return 'shop_chat_multi_dock_${uid}_$shopId';
  }

  List<ShopChatThreadModel> get windows {
    return openIds.map((String id) {
      return snapshots[id] ??
          ShopChatThreadModel(id: id, shopId: _shopId, customerUid: id);
    }).toList();
  }

  TextEditingController inputOf(String threadId) {
    return _inputs.putIfAbsent(threadId, () {
      return TextEditingController(text: drafts[threadId] ?? '');
    });
  }

  void registerMessageListener(String threadId) {
    liveMessageListeners.add(threadId);
  }

  void unregisterMessageListener(String threadId) {
    liveMessageListeners.remove(threadId);
  }

  GlobalKey? windowKeyFor(String threadId) {
    return windowKeys.putIfAbsent(threadId, GlobalKey.new);
  }

  Future<void> attach({
    required String shopId,
    required String uid,
    bool listenInbox = true,
  }) async {
    if (_shopId != shopId || _uid != uid) {
      _clearMemory();
    }
    _shopId = shopId;
    _uid = uid;
    await restore();
    if (listenInbox) {
      _inboxSub?.cancel();
      _inboxSub = ShopChatService.instance
          .watchShopInbox(shopId)
          .listen(ingestInbox);
    }
  }

  Future<void> restore() async {
    if (_uid.isEmpty || _shopId.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(prefsKey(_uid, _shopId)) ?? '';
      if (raw.isEmpty) {
        notifyListeners();
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        notifyListeners();
        return;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      openIds
        ..clear()
        ..addAll(
          ((map['ids'] as List?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .where((String id) => id.isNotEmpty)
              .take(maxSlots),
        );
      slotIds
        ..clear()
        ..addAll(
          ((map['slotIds'] as List?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .where((String id) => id.isNotEmpty)
              .take(ShopChatLayout.desktopSlotMax),
        );
      lastActiveAt
        ..clear()
        ..addAll(_readTimes(map['active']));
      drafts
        ..clear()
        ..addAll(_readDrafts(map['drafts']));
      inboxOpen = map['inboxOpen'] == true;
      dockOpen = map['dockOpen'] == true;
      dockMinimized = map['dockMinimized'] == true;
      for (final String id in <String>{...openIds, ...slotIds}) {
        _inputs[id] = TextEditingController(text: drafts[id] ?? '');
      }
    } catch (_) {
      openIds.clear();
    }
    notifyListeners();
  }

  Future<void> persist() async {
    _captureAllDrafts();
    if (_uid.isEmpty || _shopId.isEmpty) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey(_uid, _shopId),
      jsonEncode(<String, dynamic>{
        'ids': openIds,
        'slotIds': slotIds,
        'active': <String, int>{
          for (final MapEntry<String, DateTime> entry in lastActiveAt.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        },
        'drafts': drafts,
        'inboxOpen': inboxOpen,
        'dockOpen': dockOpen,
        'dockMinimized': dockMinimized,
      }),
    );
  }

  /// 只同步摘要與未讀，絕不因新訊息加入或替換視窗。
  void ingestInbox(List<ShopChatThreadModel> threads) {
    final Map<String, ShopChatThreadModel> byId = <String, ShopChatThreadModel>{
      for (final ShopChatThreadModel thread in threads) thread.id: thread,
    };
    final List<String> staleInputs = <String>[];
    for (final String id in List<String>.from(openIds)) {
      final ShopChatThreadModel? thread = byId[id];
      if (thread != null) {
        snapshots[id] = thread;
      } else if (threads.isNotEmpty) {
        _detachWindow(id, keepDraft: true);
        staleInputs.add(id);
      }
    }
    for (final String id in List<String>.from(slotIds)) {
      final ShopChatThreadModel? thread = byId[id];
      if (thread != null) {
        snapshots[id] = thread;
      }
    }
    notifyListeners();
    for (final String id in staleInputs) {
      _disposeInput(id);
    }
  }

  ShopChatOpenResult openFromInbox(ShopChatThreadModel thread) {
    if (thread.id.isEmpty) {
      return const ShopChatOpenResult(
        kind: ShopChatOpenKind.added,
        threadId: '',
      );
    }
    snapshots[thread.id] = thread;
    dockOpen = true;
    dockMinimized = false;
    if (openIds.contains(thread.id)) {
      _moveToFront(thread.id);
      _flash(thread.id);
      persist();
      notifyListeners();
      return ShopChatOpenResult(
        kind: ShopChatOpenKind.focusedExisting,
        threadId: thread.id,
      );
    }
    if (openIds.length < maxSlots) {
      openIds.insert(0, thread.id);
      lastActiveAt[thread.id] = DateTime.now();
      inputOf(thread.id);
      persist();
      notifyListeners();
      return ShopChatOpenResult(
        kind: ShopChatOpenKind.added,
        threadId: thread.id,
      );
    }
    final String replacedId = lruId();
    _detachWindow(replacedId, keepDraft: true);
    lastReplacedId = replacedId;
    openIds.insert(0, thread.id);
    lastActiveAt[thread.id] = DateTime.now();
    inputOf(thread.id);
    persist();
    notifyListeners();
    _disposeInput(replacedId);
    return ShopChatOpenResult(
      kind: ShopChatOpenKind.replaced,
      threadId: thread.id,
      replacedId: replacedId,
    );
  }

  String lruId() {
    if (openIds.isEmpty) {
      return '';
    }
    String oldest = openIds.last;
    DateTime oldestAt =
        lastActiveAt[oldest] ?? DateTime.fromMillisecondsSinceEpoch(0);
    for (final String id in openIds) {
      final DateTime at =
          lastActiveAt[id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (at.isBefore(oldestAt)) {
        oldest = id;
        oldestAt = at;
      }
    }
    return oldest;
  }

  void touch(String threadId) {
    if (!openIds.contains(threadId)) {
      return;
    }
    final bool alreadyFront = openIds.first == threadId;
    _moveToFront(threadId);
    persist();
    if (!alreadyFront) {
      notifyListeners();
    }
  }

  void closeWindow(String threadId) {
    _detachWindow(threadId, keepDraft: true);
    notifyListeners();
    _disposeInput(threadId);
    persist();
  }

  void toggleInbox() {
    inboxOpen = !inboxOpen;
    persist();
    notifyListeners();
  }

  void openInbox() {
    inboxOpen = true;
    persist();
    notifyListeners();
  }

  void closeInbox() {
    inboxOpen = false;
    persist();
    notifyListeners();
  }

  ShopChatOpenResult openDesktopSlot(ShopChatThreadModel thread) {
    if (thread.id.isEmpty) {
      return const ShopChatOpenResult(
        kind: ShopChatOpenKind.added,
        threadId: '',
      );
    }
    snapshots[thread.id] = thread;
    inboxOpen = true;
    if (slotIds.contains(thread.id)) {
      focusedThreadId = thread.id;
      _flash(thread.id);
      persist();
      notifyListeners();
      return ShopChatOpenResult(
        kind: ShopChatOpenKind.focusedExisting,
        threadId: thread.id,
      );
    }
    if (slotIds.length >= ShopChatLayout.desktopSlotMax) {
      return ShopChatOpenResult(
        kind: ShopChatOpenKind.rejectedFull,
        threadId: thread.id,
      );
    }
    slotIds.add(thread.id);
    focusedThreadId = thread.id;
    inputOf(thread.id);
    persist();
    notifyListeners();
    return ShopChatOpenResult(
      kind: ShopChatOpenKind.added,
      threadId: thread.id,
    );
  }

  void closeDesktopSlot(String threadId) {
    if (!slotIds.contains(threadId)) {
      return;
    }
    _captureDraft(threadId);
    slotIds.remove(threadId);
    if (focusedThreadId == threadId) {
      focusedThreadId = slotIds.isEmpty ? null : slotIds.last;
    }
    if (highlightId == threadId) {
      highlightId = null;
    }
    persist();
    notifyListeners();
  }

  void selectDesktopThread(ShopChatThreadModel thread) {
    openDesktopSlot(thread);
  }

  void clearFocusedThread() {
    if (focusedThreadId == null) {
      return;
    }
    focusedThreadId = null;
    notifyListeners();
  }

  void toggleDock() {
    if (!dockOpen) {
      dockOpen = true;
      dockMinimized = false;
    } else if (dockMinimized) {
      dockMinimized = false;
    } else {
      dockOpen = false;
    }
    persist();
    notifyListeners();
  }

  void minimizeDock() {
    dockMinimized = true;
    dockOpen = true;
    persist();
    notifyListeners();
  }

  void expandDock() {
    dockOpen = true;
    dockMinimized = false;
    persist();
    notifyListeners();
  }

  void closeDock() {
    dockOpen = false;
    dockMinimized = false;
    persist();
    notifyListeners();
  }

  bool get showDockWindows => dockOpen && !dockMinimized;

  void _moveToFront(String threadId) {
    openIds.remove(threadId);
    openIds.insert(0, threadId);
    lastActiveAt[threadId] = DateTime.now();
  }

  void _flash(String threadId) {
    highlightId = threadId;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (highlightId == threadId) {
        highlightId = null;
        notifyListeners();
      }
    });
  }

  void _captureDraft(String threadId) {
    final TextEditingController? input = _inputs[threadId];
    if (input != null) {
      drafts[threadId] = input.text;
    }
  }

  void _captureAllDrafts() {
    for (final String id in <String>{...openIds, ...slotIds}) {
      _captureDraft(id);
    }
  }

  void _detachWindow(String threadId, {required bool keepDraft}) {
    _captureDraft(threadId);
    if (!keepDraft) {
      drafts.remove(threadId);
    }
    openIds.remove(threadId);
    lastActiveAt.remove(threadId);
    liveMessageListeners.remove(threadId);
    windowKeys.remove(threadId);
  }

  void _disposeInput(String threadId) {
    _inputs.remove(threadId)?.dispose();
  }

  void _clearMemory() {
    _inboxSub?.cancel();
    _inboxSub = null;
    for (final TextEditingController input in _inputs.values) {
      input.dispose();
    }
    _inputs.clear();
    openIds.clear();
    slotIds.clear();
    lastActiveAt.clear();
    snapshots.clear();
    drafts.clear();
    liveMessageListeners.clear();
    windowKeys.clear();
    inboxOpen = false;
    dockOpen = false;
    dockMinimized = false;
    highlightId = null;
    lastReplacedId = null;
    focusedThreadId = null;
  }

  static Map<String, DateTime> _readTimes(Object? raw) {
    if (raw is! Map) {
      return <String, DateTime>{};
    }
    final Map<String, DateTime> out = <String, DateTime>{};
    raw.forEach((Object? key, Object? value) {
      final int millis = value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
      if (millis > 0) {
        out[key.toString()] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    });
    return out;
  }

  static Map<String, String> _readDrafts(Object? raw) {
    if (raw is! Map) {
      return <String, String>{};
    }
    return raw.map(
      (Object? key, Object? value) =>
          MapEntry<String, String>(key.toString(), value?.toString() ?? ''),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _inboxSub?.cancel();
    for (final TextEditingController input in _inputs.values) {
      input.dispose();
    }
    _inputs.clear();
    super.dispose();
  }
}
