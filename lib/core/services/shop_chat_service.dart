// 檔案名稱：lib/core/services/shop_chat_service.dart
// 功能說明：店家聊天：一個會員 × 一間店家一個 thread。文字與圖片都走這裡。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/shop_chat_message_model.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';

class ShopChatException implements Exception {
  const ShopChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ShopChatService {
  ShopChatService._();

  static final ShopChatService instance = ShopChatService._();

  static const int pageSize = 40;
  static const int imageMaxEdge = 1600;
  static const int imageQuality = 82;
  static const String floatingTypePetnestChat = 'petnest_chat';
  static const String floatingTypePhone = 'phone';
  static const String floatingTypeLine = 'line';
  static const String floatingTypeFacebook = 'facebook';
  static const String floatingTypeInstagram = 'instagram';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get _user => _auth.currentUser;

  static Map<String, dynamic> floatingSetting(Map<String, dynamic>? shop) {
    final dynamic raw = shop?['floatingContactButton'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  static bool isFloatingEnabled(Map<String, dynamic>? shop) {
    return floatingSetting(shop)['enabled'] == true;
  }

  static String savedFloatingType(Map<String, dynamic>? shop) {
    return (floatingSetting(shop)['type'] ?? '').toString().trim();
  }

  /// 前台浮動按鈕實際功能。舊資料若曾開 storeChatEnabled，只在 runtime / UI fallback。
  static String resolvedFloatingType(Map<String, dynamic>? shop) {
    final String saved = savedFloatingType(shop);
    if (saved == floatingTypePetnestChat) {
      return floatingTypePetnestChat;
    }
    if (shop != null &&
        shop['storeChatEnabled'] == true &&
        isFloatingEnabled(shop) &&
        saved != floatingTypePetnestChat) {
      return floatingTypePetnestChat;
    }
    return saved;
  }

  /// 店家聊天功能是否啟用：由快速聯絡「按鈕功能」判定，不再用獨立開關。
  static bool isEnabled(Map<String, dynamic>? shop) {
    return resolvedFloatingType(shop) == floatingTypePetnestChat;
  }

  static String defaultLabelForType(String type) {
    switch (type) {
      case floatingTypePetnestChat:
        return '聯絡店家';
      case floatingTypePhone:
        return '撥打電話';
      case floatingTypeFacebook:
        return 'Facebook';
      case floatingTypeLine:
        return 'LINE';
      case floatingTypeInstagram:
        return 'Instagram';
      default:
        return '聯絡店家';
    }
  }

  static String badgeLabel(int count) {
    if (count <= 0) {
      return '';
    }
    if (count > 99) {
      return '99+';
    }
    return '$count';
  }

  CollectionReference<Map<String, dynamic>> _threads(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('chat_threads');
  }

  DocumentReference<Map<String, dynamic>> _threadRef(
    String shopId,
    String threadId,
  ) {
    return _threads(shopId).doc(threadId);
  }

  CollectionReference<Map<String, dynamic>> _messages(
    String shopId,
    String threadId,
  ) {
    return _threadRef(shopId, threadId).collection('messages');
  }

  Stream<ShopChatThreadModel?> watchThread({
    required String shopId,
    required String threadId,
  }) {
    if (shopId.isEmpty || threadId.isEmpty) {
      return Stream<ShopChatThreadModel?>.value(null);
    }
    final String path = 'shops/$shopId/chat_threads/$threadId';
    print(
      '[ShopChatService] STEP watchThread start '
      'uid=${_user?.uid} shopId=$shopId path=$path',
    );
    return _threadRef(shopId, threadId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          print(
            '[ShopChatService] STEP watchThread success '
            'exists=${snapshot.exists} path=$path',
          );
          if (!snapshot.exists) {
            return null;
          }
          return ShopChatThreadModel.fromDoc(snapshot);
        })
        .transform(
          _chatErrorTransformer<ShopChatThreadModel?>(
            source: 'ShopChatService.watchThread',
            path: path,
          ),
        );
  }

  Stream<List<ShopChatThreadModel>> watchShopInbox(String shopId) {
    return _watchInboxByStatus(shopId, ShopChatThreadStatuses.active);
  }

  Stream<List<ShopChatThreadModel>> watchShopArchivedInbox(String shopId) {
    return _watchInboxByStatus(shopId, ShopChatThreadStatuses.archived);
  }

  Stream<List<ShopChatThreadModel>> _watchInboxByStatus(
    String shopId,
    String status,
  ) {
    if (shopId.isEmpty) {
      return Stream<List<ShopChatThreadModel>>.value(const []);
    }
    final String path = 'shops/$shopId/chat_threads';
    final String query = 'status==$status orderBy lastMessageAt desc limit 80';
    debugPrint(
      '[ShopChatInbox] shopId=$shopId uid=${_user?.uid} '
      'path=$path query=$query',
    );
    return _threads(shopId)
        .where('status', isEqualTo: status)
        .orderBy('lastMessageAt', descending: true)
        .limit(80)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ShopChatThreadModel.fromDoc).toList(),
        )
        .handleError((Object error, StackTrace stack) {
          _debugInboxFailure(
            shopId: shopId,
            path: path,
            query: query,
            error: error,
            stack: stack,
          );
          Error.throwWithStackTrace(error, stack);
        });
  }

  void _debugInboxFailure({
    required String shopId,
    required String path,
    required String query,
    required Object error,
    required StackTrace stack,
  }) {
    final String code = error is FirebaseException
        ? error.code
        : error.runtimeType.toString();
    debugPrint(
      '[ShopChatInbox] shopId=$shopId uid=${_user?.uid} '
      'path=$path query=$query',
    );
    debugPrint('[ShopChatInbox] 失敗：code=$code message=$error');
    debugPrint('[ShopChatInbox] stack=$stack');
  }

  Stream<int> watchShopUnreadTotal(String shopId) {
    if (shopId.isEmpty) {
      return Stream<int>.value(0);
    }
    return _threads(shopId)
        .where('shopUnreadCount', isGreaterThan: 0)
        .snapshots()
        .handleError((Object error, StackTrace stack) {
          _debugInboxFailure(
            shopId: shopId,
            path: 'shops/$shopId/chat_threads',
            query: 'shopUnreadCount>0',
            error: error,
            stack: stack,
          );
          Error.throwWithStackTrace(error, stack);
        })
        .map((snapshot) {
          int total = 0;
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.docs) {
            total += (doc.data()['shopUnreadCount'] is int)
                ? doc.data()['shopUnreadCount'] as int
                : int.tryParse(
                        doc.data()['shopUnreadCount']?.toString() ?? '',
                      ) ??
                      0;
          }
          return total;
        });
  }

  Stream<int> watchCustomerUnread({
    required String shopId,
    required String customerUid,
    String source = 'ShopChatService',
  }) {
    if (shopId.isEmpty || customerUid.isEmpty) {
      return Stream<int>.value(0);
    }
    print(
      '[$source] watchCustomerUnread start '
      'shopId=$shopId customerUid=$customerUid '
      'path=shops/$shopId/chat_threads/$customerUid',
    );
    return watchThreadIfMessagesExist(
      shopId: shopId,
      threadId: customerUid,
      source: source,
    ).map((ShopChatThreadModel? thread) => thread?.customerUnreadCount ?? 0);
  }

  /// 空聊天室（尚無 messages）不要去 listen 不存在的 thread document。
  /// messages 集合 read 不依賴 parent thread；thread doc 在線上 Rules
  /// 未允許 resource==null 時會變成 Web converted Future。
  Stream<ShopChatThreadModel?> watchThreadIfMessagesExist({
    required String shopId,
    required String threadId,
    String source = 'ShopChatService',
  }) {
    if (shopId.isEmpty || threadId.isEmpty) {
      return Stream<ShopChatThreadModel?>.value(null);
    }
    return Stream<ShopChatThreadModel?>.multi((
      MultiStreamController<ShopChatThreadModel?> controller,
    ) {
      StreamSubscription<List<ShopChatMessageModel>>? messagesSub;
      StreamSubscription<ShopChatThreadModel?>? threadSub;
      var listeningThread = false;

      Future<void> stopThread() async {
        final StreamSubscription<ShopChatThreadModel?>? sub = threadSub;
        threadSub = null;
        listeningThread = false;
        if (sub == null) {
          return;
        }
        try {
          await sub.cancel();
        } catch (e, st) {
          print('[$source] thread subscription cancel failed');
          ChatErrorProbe.dump('$source.thread.cancel', e, st);
        }
      }

      messagesSub = watchLatestMessages(shopId: shopId, threadId: threadId)
          .listen(
            (List<ShopChatMessageModel> messages) {
              if (messages.isEmpty) {
                stopThread();
                if (!controller.isClosed) {
                  controller.add(null);
                }
                return;
              }
              if (listeningThread) {
                return;
              }
              listeningThread = true;
              print(
                '[$source] start watchThread after messages exist '
                'path=shops/$shopId/chat_threads/$threadId',
              );
              threadSub = watchThread(shopId: shopId, threadId: threadId)
                  .listen(
                    (ShopChatThreadModel? thread) {
                      if (!controller.isClosed) {
                        controller.add(thread);
                      }
                    },
                    onError: (Object e, StackTrace st) {
                      print('[$source] watchThread error');
                      ChatErrorProbe.dump('$source.watchThread', e, st);
                      if (!controller.isClosed) {
                        controller.addError(e, st);
                      }
                    },
                  );
            },
            onError: (Object e, StackTrace st) {
              print('[$source] watchLatestMessages error');
              ChatErrorProbe.dump('$source.watchLatestMessages', e, st);
              if (!controller.isClosed) {
                controller.addError(e, st);
              }
            },
          );

      controller.onCancel = () async {
        try {
          await messagesSub?.cancel();
        } catch (e, st) {
          print('[$source] messages subscription cancel failed');
          ChatErrorProbe.dump('$source.messages.cancel', e, st);
        }
        await stopThread();
      };
    });
  }

  Stream<List<ShopChatMessageModel>> watchLatestMessages({
    required String shopId,
    required String threadId,
  }) {
    if (shopId.isEmpty || threadId.isEmpty) {
      return Stream<List<ShopChatMessageModel>>.value(const []);
    }
    final String path = 'shops/$shopId/chat_threads/$threadId/messages';
    print(
      '[ShopChatService] STEP watchLatestMessages start '
      'uid=${_user?.uid} shopId=$shopId path=$path',
    );
    return _messages(shopId, threadId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<ShopChatMessageModel> items = snapshot.docs
              .map(ShopChatMessageModel.fromDoc)
              .toList();
          final List<ShopChatMessageModel> ordered = items.reversed.toList();
          print(
            '[ShopChatService] STEP watchLatestMessages success '
            'count=${ordered.length} empty=${ordered.isEmpty} path=$path',
          );
          return ordered;
        })
        .transform(
          _chatErrorTransformer<List<ShopChatMessageModel>>(
            source: 'ShopChatService.watchLatestMessages',
            path: path,
          ),
        );
  }

  Future<List<ShopChatMessageModel>> loadOlderMessages({
    required String shopId,
    required String threadId,
    required DateTime before,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _messages(shopId, threadId)
            .orderBy('createdAt', descending: true)
            .where('createdAt', isLessThan: Timestamp.fromDate(before))
            .limit(pageSize)
            .get();
    final List<ShopChatMessageModel> items = snapshot.docs
        .map(ShopChatMessageModel.fromDoc)
        .toList();
    return items.reversed.toList();
  }

  Future<void> sendTextMessage({
    required String shopId,
    required String senderType,
    required String text,
    String? threadId,
    String senderDisplayName = '',
    Map<String, String> customerSnapshot = const <String, String>{},
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ShopChatException('請輸入訊息');
    }
    await _sendMessage(
      shopId: shopId,
      threadId: threadId,
      senderType: senderType,
      senderDisplayName: senderDisplayName,
      type: ShopChatMessageTypes.text,
      text: trimmed,
      customerSnapshot: customerSnapshot,
    );
  }

  Future<void> sendImageMessage({
    required String shopId,
    required String senderType,
    required XFile image,
    String? threadId,
    String senderDisplayName = '',
    Map<String, String> customerSnapshot = const <String, String>{},
  }) async {
    try {
      await InventoryImageService.instance.validateOriginalImage(image);
    } on InventoryException catch (error) {
      throw ShopChatException(error.message);
    }
    final User user = _requireUser();
    final String resolvedThreadId = _resolveThreadId(
      senderType: senderType,
      threadId: threadId,
      uid: user.uid,
    );
    final String messageId = _messages(shopId, resolvedThreadId).doc().id;
    final String path =
        'shop_chat/$shopId/$resolvedThreadId/$messageId/image.jpg';
    String imageUrl = '';
    try {
      final Uint8List original = await image.readAsBytes();
      final Uint8List compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: imageMaxEdge,
        minHeight: imageMaxEdge,
        quality: imageQuality,
        format: CompressFormat.jpeg,
      );
      if (compressed.isEmpty) {
        throw const ShopChatException('圖片壓縮失敗，請重新選擇');
      }
      if (compressed.length > 5 * 1024 * 1024) {
        throw const ShopChatException('圖片大小不可超過 5MB');
      }
      await _storage
          .ref(path)
          .putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
      imageUrl = await _storage.ref(path).getDownloadURL();
      await _sendMessage(
        shopId: shopId,
        threadId: resolvedThreadId,
        senderType: senderType,
        senderDisplayName: senderDisplayName,
        type: ShopChatMessageTypes.image,
        text: '圖片',
        imageUrl: imageUrl,
        imageStoragePath: path,
        messageId: messageId,
        customerSnapshot: customerSnapshot,
      );
    } catch (error) {
      if (imageUrl.isNotEmpty || path.isNotEmpty) {
        try {
          await _storage.ref(path).delete();
        } catch (_) {}
      }
      if (error is ShopChatException) {
        rethrow;
      }
      throw const ShopChatException('圖片傳送失敗，請重新嘗試');
    }
  }

  Future<void> markCustomerRead({
    required String shopId,
    required String threadId,
  }) async {
    final String path = 'shops/$shopId/chat_threads/$threadId';
    print(
      '[ShopChatService] STEP markCustomerRead start '
      'uid=${_user?.uid} shopId=$shopId path=$path',
    );
    if (shopId.isEmpty || threadId.isEmpty || _user == null) {
      print('[ShopChatService] STEP markCustomerRead skip empty uid/shopId');
      return;
    }
    try {
      final DocumentReference<Map<String, dynamic>> ref = _threadRef(
        shopId,
        threadId,
      );
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        if (!snap.exists) {
          print(
            '[ShopChatService] STEP markCustomerRead skip thread missing '
            'path=$path',
          );
          return;
        }
        tx.update(ref, <String, dynamic>{
          'customerUnreadCount': 0,
          'lastReadByCustomerAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      print('[ShopChatService] STEP markCustomerRead success path=$path');
    } catch (e, st) {
      ChatErrorProbe.dump('ShopChatService.markCustomerRead path=$path', e, st);
      rethrow;
    }
  }

  Future<void> markShopRead({
    required String shopId,
    required String threadId,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _threadRef(
      shopId,
      threadId,
    );
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
      if (!snap.exists) {
        return;
      }
      tx.update(ref, <String, dynamic>{
        'shopUnreadCount': 0,
        'lastReadByShopAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> archiveThread({
    required String shopId,
    required String threadId,
  }) async {
    await _threadRef(shopId, threadId).update(<String, dynamic>{
      'status': ShopChatThreadStatuses.archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> findActiveBooking({
    required String shopId,
    required String customerUid,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('userId', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    const Set<String> active = <String>{
      'pending',
      'confirmed',
      'checked_in',
      'unpaid',
      'payment_uploaded',
    };
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (active.contains((data['status'] ?? '').toString())) {
        return <String, dynamic>{'id': doc.id, ...data};
      }
    }
    return null;
  }

  Future<Map<String, String>> loadCustomerSnapshot() async {
    final User user = _requireUser();
    String name = (user.displayName ?? '').trim();
    String phone = (user.phoneNumber ?? '').trim();
    String photo = (user.photoURL ?? '').trim();
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final Map<String, dynamic> data = userDoc.data() ?? const {};
      if (name.isEmpty) {
        name = (data['name'] ?? data['displayName'] ?? '').toString().trim();
      }
      if (phone.isEmpty) {
        phone = (data['phone'] ?? '').toString().trim();
      }
      if (photo.isEmpty) {
        photo = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString().trim();
      }
    } catch (_) {}
    if (name.isEmpty) {
      name = '會員';
    }
    return <String, String>{
      'customerName': name,
      'customerPhone': phone,
      'customerPhotoUrl': photo,
    };
  }

  User _requireUser() {
    final User? user = _user;
    if (user == null) {
      throw const ShopChatException('請先登入會員');
    }
    return user;
  }

  String _resolveThreadId({
    required String senderType,
    required String uid,
    String? threadId,
  }) {
    if (senderType == ShopChatSenderTypes.customer) {
      return uid;
    }
    final String id = (threadId ?? '').trim();
    if (id.isEmpty) {
      throw const ShopChatException('找不到聊天室');
    }
    return id;
  }

  Future<void> _sendMessage({
    required String shopId,
    required String senderType,
    required String type,
    required String text,
    String? threadId,
    String senderDisplayName = '',
    String imageUrl = '',
    String imageStoragePath = '',
    String? messageId,
    Map<String, String> customerSnapshot = const <String, String>{},
  }) async {
    final User user = _requireUser();
    final String resolvedThreadId = _resolveThreadId(
      senderType: senderType,
      threadId: threadId,
      uid: user.uid,
    );
    final DocumentReference<Map<String, dynamic>> threadRef = _threadRef(
      shopId,
      resolvedThreadId,
    );
    final DocumentReference<Map<String, dynamic>> messageRef = messageId == null
        ? _messages(shopId, resolvedThreadId).doc()
        : _messages(shopId, resolvedThreadId).doc(messageId);

    final bool fromCustomer = senderType == ShopChatSenderTypes.customer;
    final String preview = type == ShopChatMessageTypes.image ? '圖片' : text;

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> threadSnap = await tx.get(
        threadRef,
      );
      final bool exists = threadSnap.exists;
      tx.set(messageRef, <String, dynamic>{
        'shopId': shopId,
        'threadId': resolvedThreadId,
        'senderUid': user.uid,
        'senderType': senderType,
        'senderDisplayName': senderDisplayName.trim(),
        'type': type,
        'text': text,
        'imageUrl': imageUrl,
        'imageStoragePath': imageStoragePath,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final Map<String, dynamic> threadData = <String, dynamic>{
        'shopId': shopId,
        'customerUid': resolvedThreadId,
        if (fromCustomer) ...<String, dynamic>{
          'customerName': customerSnapshot['customerName'] ?? '',
          'customerPhotoUrl': customerSnapshot['customerPhotoUrl'] ?? '',
          'customerPhone': customerSnapshot['customerPhone'] ?? '',
        },
        'lastMessage': preview,
        'lastMessageType': type,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderType': senderType,
        'status': ShopChatThreadStatuses.active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (fromCustomer) 'shopUnreadCount': FieldValue.increment(1),
        if (!fromCustomer) 'customerUnreadCount': FieldValue.increment(1),
        if (fromCustomer) 'customerUnreadCount': 0,
        if (!fromCustomer) 'shopUnreadCount': 0,
      };
      if (!exists) {
        threadData['createdAt'] = FieldValue.serverTimestamp();
        if (fromCustomer) {
          threadData['shopUnreadCount'] = 1;
          threadData['customerUnreadCount'] = 0;
        } else {
          threadData['customerUnreadCount'] = 1;
          threadData['shopUnreadCount'] = 0;
        }
      }
      tx.set(threadRef, threadData, SetOptions(merge: true));
    });
  }

  StreamTransformer<T, T> _chatErrorTransformer<T>({
    required String source,
    required String path,
  }) {
    return StreamTransformer<T, T>.fromHandlers(
      handleError: (Object error, StackTrace stack, EventSink<T> sink) {
        print('[$source] stream error path=$path uid=${_user?.uid}');
        ChatErrorProbe.dump(source, error, stack);
        sink.addError(error, stack);
      },
    );
  }
}
