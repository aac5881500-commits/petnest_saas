// lib/core/services/fcm_token_service.dart
// 🔔 FCM 推播 Token 服務
// 功能：取得手機推播 token 並存到 Firestore，供 Cloud Functions 發送通知使用

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmTokenService {
  FcmTokenService._();

  static final instance = FcmTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveCurrentUserToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('fcm_tokens')
        .doc(token)
        .set({
          'token': token,
          'platform': 'unknown',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      final user = _auth.currentUser;
      if (user == null || token.isEmpty) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
            'token': token,
            'platform': 'unknown',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    });
  }
}
