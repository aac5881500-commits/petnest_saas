// 檔案名稱：lib/core/services/fcm_token_service.dart
// 功能說明：取得推播權限與 FCM Token，寫入 Firestore，供 Cloud Functions 發送通知使用
// 🔔 FCM 推播 Token 服務

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

  bool _isListeningTokenRefresh = false;
  bool _isSyncingToken = false;

  /// 📱 同步目前登入使用者的手機 FCM Token
  ///
  /// Web 版不執行。
  /// 手機尚未決定通知權限時，才會顯示授權要求。
  Future<void> saveCurrentUserToken() async {
    if (kIsWeb) {
      debugPrint('FCM：Web 版不啟用推播 Token');
      return;
    }

    if (_isSyncingToken) {
      debugPrint('FCM：Token 正在同步，本次略過');
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint('FCM：目前沒有登入使用者');
      return;
    }

    _isSyncingToken = true;

    try {
      NotificationSettings settings = await _messaging
          .getNotificationSettings();

      debugPrint('FCM：目前通知權限 = ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        debugPrint('FCM：要求權限後 = ${settings.authorizationStatus}');
      }

      final bool permissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!permissionGranted) {
        debugPrint('FCM：通知權限未開啟，不取得 Token');
        return;
      }

      final String? token = await _messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM：無法取得 Token');
        return;
      }

      await _saveToken(userId: user.uid, token: token);

      debugPrint('FCM：Token 已成功同步');
    } catch (error, stackTrace) {
      debugPrint('FCM：取得或儲存 Token 失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isSyncingToken = false;
    }
  }

  /// 🔄 監聽 Firebase 自動更新 FCM Token
  ///
  /// 整個 App 只允許啟動一次監聽。
  void listenTokenRefresh() {
    if (kIsWeb) {
      debugPrint('FCM：Web 版不監聽 Token 更新');
      return;
    }

    if (_isListeningTokenRefresh) {
      return;
    }

    _isListeningTokenRefresh = true;

    _messaging.onTokenRefresh.listen(
      (String token) async {
        final User? user = _auth.currentUser;

        if (user == null || token.trim().isEmpty) {
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
    final DocumentReference<Map<String, dynamic>> tokenReference = _firestore
        .collection('users')
        .doc(userId)
        .collection('fcm_tokens')
        .doc(token);

    final DocumentSnapshot<Map<String, dynamic>> tokenSnapshot =
        await tokenReference.get();

    final Map<String, dynamic> tokenData = <String, dynamic>{
      'token': token,
      'platform': _platformName,
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    };

    if (!tokenSnapshot.exists) {
      tokenData['createdAt'] = FieldValue.serverTimestamp();
    }

    await tokenReference.set(tokenData, SetOptions(merge: true));
  }

  String get _platformName {
    return defaultTargetPlatform.name;
  }
}
