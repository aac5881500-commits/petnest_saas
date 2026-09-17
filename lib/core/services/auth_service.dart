// 檔案名稱：lib/core/services/auth_service.dart
// 功能說明：登入認證服務：Email／Google 登入與使用者資料建立
// 功能：
// - Email 註冊 / 登入
// - Google 登入
// - 建立 users / user_profiles
// - 自動補齊 email（🔥重點）
// - 預留平台會員 & 店家會員架構

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 取得目前使用者
  User? get currentUser => _auth.currentUser;

  /// 監聽登入狀態
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 將 Firebase Auth 的原始錯誤轉為前台可讀的中文訊息。
  static String authErrorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return '系統暫時無法處理，請稍後再試';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'Email 格式不正確，請重新輸入';
      case 'email-already-in-use':
        return '此 Email 已被註冊，請直接登入或使用其他 Email';
      case 'weak-password':
        return '密碼強度不足，請至少輸入 6 個字元';
      case 'user-not-found':
        return '找不到此帳號，請確認 Email 或先註冊';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email 或密碼不正確，請重新輸入';
      case 'user-disabled':
        return '此帳號目前已被停用，請聯絡客服';
      case 'too-many-requests':
        return '嘗試次數過多，請稍後再試';
      case 'network-request-failed':
        return '網路連線異常，請確認網路後再試';
      case 'operation-not-allowed':
        return '此登入方式目前尚未開放';
      default:
        return '帳號操作失敗，請稍後再試';
    }
  }

  // =========================================
  // 🔥 Google 登入
  // =========================================
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        await _ensureUserBaseData(user);

        // 🔥 同步店家邀請
        await ShopService.instance.syncPendingInvitesForCurrentUser();
        await ShopService.instance.syncOwnerMembershipForCurrentUser();
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google 登入錯誤: $e');
      rethrow;
    }
  }

  // =========================================
  // 🧩 確保會員資料存在（🔥核心）
  // =========================================
  Future<void> _ensureUserBaseData(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final profileRef = _firestore.collection('user_profiles').doc(user.uid);

    final userDoc = await userRef.get();
    final profileDoc = await profileRef.get();

    /// ================================
    /// 🟦 users（平台帳號）
    /// ================================
    final now = FieldValue.serverTimestamp();

    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'role': 'user',
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
        'lastLoginAt': now,
      });
    } else {
      await userRef.set({
        'email': user.email,
        'displayName': user.displayName ?? '',
        'updatedAt': now,
        'lastLoginAt': now,
      }, SetOptions(merge: true));
    }

    /// ================================
    /// 🟩 user_profiles（會員資料）
    /// ================================
    if (!profileDoc.exists) {
      await profileRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? '',
        'phone': '',
        'address': '',
        'emergencyName': '',
        'emergencyPhone': '',

        /// 🔥 平台用（預留）
        'globalNote': '',
        'globalTags': [],

        'petsCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      /// 🔥 關鍵：每次登入都更新
      await profileRef.update({
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // =========================================
  // 🟢 註冊
  // =========================================
  Future<UserCredential> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('註冊成功但 user 為 null');
    }

    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }

    await _ensureUserBaseData(user);

    // 🔥 同步店家邀請與店主成員文件
    await ShopService.instance.syncPendingInvitesForCurrentUser();
    await ShopService.instance.syncOwnerMembershipForCurrentUser();

    return credential;
  }

  // =========================================
  // 🔵 登入
  // =========================================
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user != null) {
      await _ensureUserBaseData(user);
    }

    // 🔥 同步店家邀請與店主成員文件
    await ShopService.instance.syncPendingInvitesForCurrentUser();
    await ShopService.instance.syncOwnerMembershipForCurrentUser();

    return credential;
  }

  // =========================================
  // 🔴 登出
  // =========================================
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
