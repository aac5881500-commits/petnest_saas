// lib/core/services/auth_service.dart

// 🔐 AuthService
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

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 取得目前使用者
  User? get currentUser => _auth.currentUser;

  /// 監聽登入狀態
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // =========================================
  // 🔥 Google 登入
  // =========================================
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        await _ensureUserBaseData(user);

        // 🔥 同步店家邀請
        await ShopService.instance
            .syncPendingInvitesForCurrentUser();
      }

      return userCredential;
    } catch (e) {
      print('Google 登入錯誤: $e');
      return null;
    }
  }

  // =========================================
  // 🧩 確保會員資料存在（🔥核心）
  // =========================================
  Future<void> _ensureUserBaseData(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final profileRef =
        _firestore.collection('user_profiles').doc(user.uid);

    final userDoc = await userRef.get();
    final profileDoc = await profileRef.get();

    /// ================================
    /// 🟦 users（平台帳號）
    /// ================================
    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'role': 'user',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({
        'email': user.email, // 🔥 補email
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    final credential =
        await _auth.createUserWithEmailAndPassword(
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

    // 🔥 同步店家邀請
    await ShopService.instance
        .syncPendingInvitesForCurrentUser();

    return credential;
  }

  // =========================================
  // 🔵 登入
  // =========================================
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user != null) {
      await _ensureUserBaseData(user);
    }

    // 🔥 同步店家邀請
    await ShopService.instance
        .syncPendingInvitesForCurrentUser();

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