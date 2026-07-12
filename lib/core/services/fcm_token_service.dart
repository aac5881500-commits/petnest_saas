// lib/core/services/fcm_token_service.dart
// 🔔 FCM 推播 Token 服務
// 功能：取得推播權限與 FCM Token，寫入 Firestore，供 Cloud Functions 發送通知使用

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenService {
  FcmTokenService._();

  static final FcmTokenService instance = FcmTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _webVapidKey =
      'BCmwv1rQ9DVSrIUz72Jqaxh9ctFDK60YInGhSV8HK0euWKHnMuxVB8fOII8R9RtCLOgxXgjINoGL5oGOUaIZ1Pg';

  Future<void> saveCurrentUserToken() async {
    debugPrint('========== FCM saveCurrentUserToken ==========');

    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM：目前沒有登入使用者');
      return;
    }

    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'FCM：要求權限後 authorizationStatus = '
        '${permission.authorizationStatus}',
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM：使用者拒絕通知權限');
        return;
      }

      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint('FCM：通知權限尚未決定');
        return;
      }

      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );

      debugPrint('FCM Token = $token');

      if (token == null || token.isEmpty) {
        debugPrint('FCM：無法取得 Token');
        return;
      }

      debugPrint('FCM：成功取得 Token');
      debugPrint('開始寫入 Firestore...');

      await _saveToken(userId: user.uid, token: token);

      debugPrint('Firestore 寫入完成');
      debugPrint('FCM：Token 已成功寫入 Firestore');
    } catch (error, stackTrace) {
      debugPrint('FCM：取得或儲存 Token 失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void listenTokenRefresh() {
    _messaging.onTokenRefresh.listen(
      (token) async {
        final user = _auth.currentUser;

        if (user == null || token.isEmpty) {
          return;
        }

        try {
          await _saveToken(userId: user.uid, token: token);

          debugPrint('FCM：更新後的 Token 已寫入 Firestore');
        } catch (error, stackTrace) {
          debugPrint('FCM：更新 Token 寫入失敗：$error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM：監聽 Token 更新失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(token)
        .set({
          'token': token,
          'platform': _platformName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    return defaultTargetPlatform.name;
  }
}
