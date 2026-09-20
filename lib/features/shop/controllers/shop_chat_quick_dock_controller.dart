// 檔案名稱：lib/features/shop/controllers/shop_chat_quick_dock_controller.dart
// 功能說明：右側最多六格快捷對話的去重、替換與展開規則（本機狀態，不寫入聊天文件）。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShopChatQuickPinResult { expandedExisting, added, replaced, blocked }

class ShopChatDockPlacement {
  ShopChatDockPlacement._();

  static const double overlayMinWidth = 1100;
  static const double inlineMinWidth = 1500;
  static const double dockWidth = 400;
  static const double twoColumnMinWidth = 360;

  static bool isMobile(double pageWidth) => pageWidth < overlayMinWidth;

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
      return false;
    }
    if (pageWidth >= inlineMinWidth && frontendEmbedded) {
      return true;
    }
    return pageWidth >= overlayMinWidth && pageWidth < inlineMinWidth;
  }
}

class ShopChatQuickDockController extends ChangeNotifier {
  ShopChatQuickDockController({this.maxSlots = 6});

  static const int defaultMaxSlots = 6;
  final int maxSlots;

  final List<String> slotIds = <String>[];
  final Map<String, DateTime> lastUsedAt = <String, DateTime>{};
  final Map<String, DateTime> lastOpenedAt = <String, DateTime>{};
  final Map<String, ShopChatThreadModel> snapshots =
      <String, ShopChatThreadModel>{};
  final Map<String, DateTime> _seenLastMessageAt = <String, DateTime>{};

  String? expandedThreadId;
  int overflowUnread = 0;
  bool _hydrated = false;

  StreamSubscription<List<ShopChatThreadModel>>? _inboxSub;
  String _shopId = '';
  String _uid = '';
  Future<void> Function()? onPersist;

  static String prefsKey(String uid, String shopId) {
    return 'shop_chat_quick_threads_${uid}_$shopId';
  }

  bool get hasExpanded =>
      expandedThreadId != null && slotIds.contains(expandedThreadId);

  int get extraUnreadConversationCount => overflowUnread;

  List<ShopChatThreadModel> get cards {
    return slotIds.map((String id) {
      return snapshots[id] ??
          ShopChatThreadModel(id: id, shopId: _shopId, customerUid: id);
    }).toList();
  }

  Future<void> attach({
    required String shopId,
    required String uid,
    bool listenInbox = true,
  }) async {
    if (_shopId != shopId || _uid != uid) {
      slotIds.clear();
      lastUsedAt.clear();
      lastOpenedAt.clear();
      snapshots.clear();
      _seenLastMessageAt.clear();
      expandedThreadId = null;
      overflowUnread = 0;
      _hydrated = false;
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
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(prefsKey(_uid, _shopId)) ?? '';
      if (raw.isEmpty) {
        _hydrated = true;
        notifyListeners();
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _hydrated = true;
        return;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      slotIds
        ..clear()
        ..addAll(
          ((map['ids'] as List?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .where((String id) => id.isNotEmpty)
              .take(maxSlots),
        );
      lastUsedAt
        ..clear()
        ..addAll(_readTimes(map['used']));
      lastOpenedAt
        ..clear()
        ..addAll(_readTimes(map['opened']));
      expandedThreadId = null;
    } catch (_) {
      slotIds.clear();
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<void> persist() async {
    if (_uid.isEmpty || _shopId.isEmpty) {
      await onPersist?.call();
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey(_uid, _shopId),
      jsonEncode(<String, dynamic>{
        'ids': slotIds,
        'used': <String, int>{
          for (final MapEntry<String, DateTime> entry in lastUsedAt.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        },
        'opened': <String, int>{
          for (final MapEntry<String, DateTime> entry in lastOpenedAt.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        },
      }),
    );
    await onPersist?.call();
  }

  void ingestInbox(List<ShopChatThreadModel> threads) {
    final Map<String, ShopChatThreadModel> byId = <String, ShopChatThreadModel>{
      for (final ShopChatThreadModel thread in threads) thread.id: thread,
    };
    bool changed = false;
    for (final String id in List<String>.from(slotIds)) {
      final ShopChatThreadModel? thread = byId[id];
      if (thread != null) {
        snapshots[id] = thread;
        changed = true;
      } else if (threads.isNotEmpty) {
        _removeId(id, notify: false);
        changed = true;
      }
    }
    for (final ShopChatThreadModel thread in threads) {
      final DateTime? previous = _seenLastMessageAt[thread.id];
      final DateTime? next = thread.lastMessageAt;
      if (next != null) {
        _seenLastMessageAt[thread.id] = next;
      }
      if (slotIds.contains(thread.id)) {
        continue;
      }
      final bool isNew = previous == null
          ? thread.shopUnreadCount > 0 && _hydrated
          : next != null && next.isAfter(previous);
      if (isNew) {
        final ShopChatQuickPinResult result = pin(
          thread,
          expand: false,
          allowReplaceUnread: false,
        );
        if (result != ShopChatQuickPinResult.blocked) {
          changed = true;
        }
      }
    }
    overflowUnread = threads
        .where(
          (ShopChatThreadModel thread) =>
              thread.shopUnreadCount > 0 && !slotIds.contains(thread.id),
        )
        .length;
    if (changed) {
      notifyListeners();
      persist();
    } else {
      notifyListeners();
    }
  }

  ShopChatQuickPinResult pin(
    ShopChatThreadModel thread, {
    bool expand = false,
    bool allowReplaceUnread = false,
  }) {
    if (thread.id.isEmpty) {
      return ShopChatQuickPinResult.blocked;
    }
    snapshots[thread.id] = thread;
    final DateTime now = DateTime.now();
    if (slotIds.contains(thread.id)) {
      lastUsedAt[thread.id] = now;
      if (expand) {
        expandedThreadId = thread.id;
        lastOpenedAt[thread.id] = now;
      }
      notifyListeners();
      persist();
      return ShopChatQuickPinResult.expandedExisting;
    }
    if (slotIds.length < maxSlots) {
      slotIds.add(thread.id);
      lastUsedAt[thread.id] = now;
      if (expand) {
        expandedThreadId = thread.id;
        lastOpenedAt[thread.id] = now;
      }
      notifyListeners();
      persist();
      return ShopChatQuickPinResult.added;
    }
    final String? replaceId = findReplaceableId(
      allowUnread: allowReplaceUnread,
    );
    if (replaceId == null) {
      notifyListeners();
      return ShopChatQuickPinResult.blocked;
    }
    _removeId(replaceId, notify: false);
    slotIds.add(thread.id);
    lastUsedAt[thread.id] = now;
    if (expand) {
      expandedThreadId = thread.id;
      lastOpenedAt[thread.id] = now;
    }
    notifyListeners();
    persist();
    return ShopChatQuickPinResult.replaced;
  }

  String? findReplaceableId({bool allowUnread = false}) {
    final List<String> candidates = slotIds.where((String id) {
      final int unread = snapshots[id]?.shopUnreadCount ?? 0;
      return allowUnread || unread <= 0;
    }).toList();
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((String a, String b) {
      final DateTime usedA =
          lastUsedAt[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime usedB =
          lastUsedAt[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final int byUsed = usedA.compareTo(usedB);
      if (byUsed != 0) {
        return byUsed;
      }
      final DateTime openedA =
          lastOpenedAt[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime openedB =
          lastOpenedAt[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return openedA.compareTo(openedB);
    });
    return candidates.first;
  }

  void expand(String threadId) {
    if (!slotIds.contains(threadId)) {
      return;
    }
    expandedThreadId = threadId;
    lastOpenedAt[threadId] = DateTime.now();
    lastUsedAt[threadId] = DateTime.now();
    notifyListeners();
    persist();
  }

  void minimizeExpanded() {
    expandedThreadId = null;
    notifyListeners();
  }

  void closeExpanded() {
    expandedThreadId = null;
    notifyListeners();
  }

  void removeSlot(String threadId) {
    _removeId(threadId, notify: true);
    persist();
  }

  void _removeId(String threadId, {required bool notify}) {
    slotIds.remove(threadId);
    lastUsedAt.remove(threadId);
    lastOpenedAt.remove(threadId);
    snapshots.remove(threadId);
    if (expandedThreadId == threadId) {
      expandedThreadId = null;
    }
    if (notify) {
      notifyListeners();
    }
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

  @override
  void dispose() {
    _inboxSub?.cancel();
    super.dispose();
  }
}
