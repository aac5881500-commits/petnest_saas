// 檔案名稱：lib/core/services/auth_service.dart
// 功能說明：Firebase Auth 登入、註冊、信箱驗證、密碼重設與 Apple／Google 登入。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petnest_saas/core/services/auth_access_policy.dart';
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

  /// 取消操作回傳 null。其他錯誤回傳繁體中文，不回傳 Firebase 原文。
  static String? authErrorMessage(Object error, {bool appleSignIn = false}) {
    return AuthAccessPolicy.messageFor(error, appleSignIn: appleSignIn);
  }

  bool mustVerifyEmail(User user) {
    return AuthAccessPolicy.mustVerifyEmail(
      emailVerified: user.emailVerified,
      providerIds: user.providerData.map((UserInfo info) => info.providerId),
    );
  }

  Future<User?> reloadCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    await user.reload();
    return _auth.currentUser;
  }

  Future<void> sendEmailVerification() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'no current user',
      );
    }
    try {
      await _auth.setLanguageCode('zh-TW');
    } catch (error) {
      debugPrint('驗證信語言設定略過');
    }
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.setLanguageCode('zh-TW');
    } catch (error) {
      debugPrint('重設信語言設定略過');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
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
        await ensureCurrentUserBaseData(user);

        // 🔥 同步店家邀請
        await ShopService.instance.syncPendingInvitesForCurrentUser();
        await ShopService.instance.syncOwnerMembershipForCurrentUser();
      }

      return userCredential;
    } on FirebaseAuthException catch (error) {
      if (AuthAccessPolicy.isCancelledCode(error.code)) {
        return null;
      }
      debugPrint('Google 登入錯誤碼: ${error.code}');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    final AppleAuthProvider provider = AppleAuthProvider();
    provider.addScope('email');
    provider.addScope('name');
    var stage = kIsWeb ? 'signInWithPopup' : 'signInWithProvider';
    try {
      final UserCredential credential =
          AuthAccessPolicy.useApplePopup(isWeb: kIsWeb)
          ? await _auth.signInWithPopup(provider)
          : await _auth.signInWithProvider(provider);
      final User? user = credential.user;
      if (user != null) {
        stage = 'member-profile';
        await ensureCurrentUserBaseData(user);
        await ShopService.instance.syncPendingInvitesForCurrentUser();
        await ShopService.instance.syncOwnerMembershipForCurrentUser();
      }
      return credential;
    } on FirebaseAuthException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Apple 登入失敗 階段=$stage 錯誤碼=${error.code} 訊息=${AuthAccessPolicy.redactedAuthMessage(error.message)}',
        );
      }
      if (AuthAccessPolicy.isCancelledCode(error.code)) {
        return null;
      }
      rethrow;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Apple 登入失敗 階段=$stage 類型=${error.runtimeType}');
      }
      rethrow;
    }
  }

  // =========================================
  // 🧩 確保會員資料存在（🔥核心）
  // =========================================
  Future<void> ensureCurrentUserBaseData([User? targetUser]) async {
    final user = targetUser ?? _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final profileRef = _firestore.collection('user_profiles').doc(user.uid);

    final userDoc = await userRef.get();
    final profileDoc = await profileRef.get();

    /// ================================
    /// 🟦 users（平台帳號）
    /// ================================
    final now = FieldValue.serverTimestamp();

    final Map<String, String> identity = AuthAccessPolicy.identityPatch(
      email: user.email,
      displayName: user.displayName,
    );
    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': identity['email'] ?? '',
        'displayName': identity['displayName'] ?? '',
        'role': 'user',
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
        'lastLoginAt': now,
      });
    } else {
      final Map<String, dynamic> patch = <String, dynamic>{
        'updatedAt': now,
        'lastLoginAt': now,
      };
      patch.addAll(identity);
      await userRef.set(patch, SetOptions(merge: true));
    }

    /// ================================
    /// 🟩 user_profiles（會員資料）
    /// ================================
    if (!AuthAccessPolicy.shouldCreateMemberRecord(profileDoc.exists)) {
      final Map<String, dynamic> patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (identity.containsKey('email')) {
        patch['email'] = identity['email'];
      }
      if (identity.containsKey('displayName')) {
        patch['name'] = identity['displayName'];
      }
      await profileRef.update(patch);
      return;
    }
    await profileRef.set({
      'uid': user.uid,
      'email': identity['email'] ?? '',
      'name': identity['displayName'] ?? '',
      'phone': '',
      'address': '',
      'emergencyName': '',
      'emergencyPhone': '',
      'globalNote': '',
      'globalTags': <String>[],
      'petsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      await user.reload();
    }

    final User current = _auth.currentUser ?? user;
    await ensureCurrentUserBaseData(current);
    try {
      await sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      debugPrint('驗證信寄送失敗: ${error.code}');
    }

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
      await ensureCurrentUserBaseData(user);
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
