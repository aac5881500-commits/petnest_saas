// lib/core/services/fcm_message_service.dart
// 🔔 FCM 訊息接收服務
// 功能：監聽前景通知、背景通知點擊、App 關閉後通知點擊，
// 並依照通知類型導向訂單詳細頁或我的評價頁

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/navigation/app_navigator.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/booking/pages/my_reviews_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_thread_page.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_customer_chat_page.dart';

class FcmMessageService {
  FcmMessageService._();

  static final FcmMessageService instance = FcmMessageService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  bool _initialized = false;

  /// 初始化手機端 FCM 訊息監聽
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('FCM 訊息：Web 版暫不啟用');
      return;
    }

    if (_initialized) {
      return;
    }

    _initialized = true;

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM 前景訊息監聽失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM 點擊訊息監聽失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      await _handleOpenedMessage(initialMessage);
    }

    debugPrint('FCM 訊息監聽已初始化');
  }

  /// App 正在前景時收到通知
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('========== FCM 前景通知 ==========');
    _printMessageData(message);

    _showForegroundNotification(message);
  }

  /// App 前景時，以 SnackBar 顯示通知
  void _showForegroundNotification(RemoteMessage message) {
    final BuildContext? context = AppNavigator.context;

    if (context == null) {
      debugPrint('FCM 前景提示失敗：目前沒有可用的 BuildContext');
      return;
    }

    final Map<String, dynamic> data = message.data;

    final String type = (data['type'] ?? '').toString();
    final String bookingId = (data['bookingId'] ?? '').toString();

    final String title = message.notification?.title?.trim().isNotEmpty == true
        ? message.notification!.title!.trim()
        : '新通知';

    final String body = message.notification?.body?.trim().isNotEmpty == true
        ? message.notification!.body!.trim()
        : '您有一則新通知';

    final bool canOpenBooking =
        bookingId.isNotEmpty &&
        (type == 'booking_status' ||
            type == 'booking_message' ||
            type == 'check_in');

    final String shopId = (data['shopId'] ?? '').toString();
    final String threadId = (data['threadId'] ?? '').toString();
    final bool canOpenReview = type == 'review';
    final bool canOpenChat =
        type == 'shop_chat' && shopId.isNotEmpty && threadId.isNotEmpty;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        action: canOpenBooking || canOpenReview || canOpenChat
            ? SnackBarAction(
                label: '查看',
                onPressed: () {
                  if (canOpenReview) {
                    _openMyReviews();
                    return;
                  }

                  if (canOpenChat) {
                    openShopChat(
                      shopId: shopId,
                      threadId: threadId,
                    );
                    return;
                  }

                  openBookingDetail(bookingId);
                },
              )
            : null,
      ),
    );
  }

  /// 從背景或完全關閉狀態點擊通知
  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    debugPrint('========== FCM 點擊通知 ==========');

    _printMessageData(message);

    await _routeNotification(message);
  }

  /// 依通知類型決定導頁
  Future<void> _routeNotification(RemoteMessage message) async {
    final Map<String, dynamic> data = message.data;

    final String type = (data['type'] ?? '').toString();
    final String bookingId = (data['bookingId'] ?? '').toString();
    final String shopId = (data['shopId'] ?? '').toString();
    final String threadId = (data['threadId'] ?? '').toString();

    switch (type) {
      case 'booking_status':
      case 'booking_message':
      case 'check_in':
        await openBookingDetail(bookingId);
        return;

      case 'review':
        await _openMyReviews();
        return;

      case 'shop_chat':
        await openShopChat(shopId: shopId, threadId: threadId);
        return;

      default:
        debugPrint('➡ 未知通知類型：$type');
    }
  }

  /// 開啟店家聊天室
  Future<void> openShopChat({
    required String shopId,
    required String threadId,
  }) async {
    if (shopId.trim().isEmpty || threadId.trim().isEmpty) {
      debugPrint('FCM 導頁失敗：店家聊天通知缺少 shopId 或 threadId');
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('FCM 導頁失敗：使用者尚未登入');
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
          await _firestore
              .collection('shop_members')
              .doc('${shopId}_${user.uid}')
              .get();
      final bool isShopMember = memberSnapshot.exists;

      final NavigatorState? navigator = await _waitForNavigator();
      if (navigator == null) {
        debugPrint('FCM 導頁失敗：Navigator 尚未準備完成');
        return;
      }

      if (isShopMember) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ShopChatThreadPage(
              shopId: shopId,
              threadId: threadId,
            ),
          ),
        );
        return;
      }

      if (user.uid == threadId) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ShopCustomerChatPage(shopId: shopId),
          ),
        );
        return;
      }

      debugPrint('FCM 導頁失敗：目前帳號無權查看此聊天室');
    } catch (error, stackTrace) {
      debugPrint('FCM 開啟店家聊天失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 開啟指定訂單詳細頁
  Future<void> openBookingDetail(String bookingId) async {
    if (bookingId.trim().isEmpty) {
      debugPrint('FCM 導頁失敗：通知沒有 bookingId');
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM 導頁失敗：使用者尚未登入');
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingSnapshot.exists) {
        debugPrint('FCM 導頁失敗：找不到訂單 $bookingId');
        return;
      }

      final Map<String, dynamic> bookingData =
          bookingSnapshot.data() ?? <String, dynamic>{};

      final String shopId = (bookingData['shopId'] ?? '').toString();
      final String bookingUserId = (bookingData['userId'] ?? '').toString();

      final bool isBookingCustomer = bookingUserId == user.uid;

      bool isShopMember = false;

      if (shopId.isNotEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
            await _firestore
                .collection('shop_members')
                .doc('${shopId}_${user.uid}')
                .get();

        isShopMember = memberSnapshot.exists;
      }

      final NavigatorState? navigator = await _waitForNavigator();

      if (navigator == null) {
        debugPrint('FCM 導頁失敗：Navigator 尚未準備完成');
        return;
      }

      if (isShopMember) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) {
              return AdminBookingDetailPage(bookingId: bookingId);
            },
          ),
        );

        return;
      }

      if (isBookingCustomer) {
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) {
              return BookingDetailPage(data: bookingData, docId: bookingId);
            },
          ),
        );

        return;
      }

      debugPrint('FCM 導頁失敗：目前帳號無權查看訂單 $bookingId');
    } catch (error, stackTrace) {
      debugPrint('FCM 開啟訂單失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 開啟會員的「我的評價」頁面
  Future<void> _openMyReviews() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM 評價導頁失敗：使用者尚未登入');
      return;
    }

    final NavigatorState? navigator = await _waitForNavigator();

    if (navigator == null) {
      debugPrint('FCM 評價導頁失敗：Navigator 尚未準備完成');
      return;
    }

    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const MyReviewsPage()),
    );
  }

  /// App 完全關閉後點通知時，
  /// MaterialApp 可能尚未完成建立，因此短暫等待 Navigator。
  Future<NavigatorState?> _waitForNavigator() async {
    const int maxAttempts = 20;
    const Duration waitDuration = Duration(milliseconds: 250);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final NavigatorState? navigator = AppNavigator.state;

      if (navigator != null) {
        return navigator;
      }

      await Future<void>.delayed(waitDuration);
    }

    return null;
  }

  /// 輸出 FCM 通知資料，方便除錯
  void _printMessageData(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;

    debugPrint('messageId = ${message.messageId}');
    debugPrint('title = ${message.notification?.title ?? ''}');
    debugPrint('body = ${message.notification?.body ?? ''}');
    debugPrint('type = ${data['type'] ?? ''}');
    debugPrint('bookingId = ${data['bookingId'] ?? ''}');
    debugPrint('shopId = ${data['shopId'] ?? ''}');
    debugPrint('status = ${data['status'] ?? ''}');
    debugPrint('senderType = ${data['senderType'] ?? ''}');
  }

  /// 預留：之後需要重建服務或測試時可呼叫
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();

    _foregroundSubscription = null;
    _openedAppSubscription = null;
    _initialized = false;
  }
}
