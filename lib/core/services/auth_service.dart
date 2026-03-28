// lib/core/services/auth_service.dart

// 🔐 AuthService
// 負責：
// - Firebase 註冊
// - Firebase 登入
// - 建立 Firestore 使用者資料
// - 登出
//
// 本次新增：
// - 登入 / 註冊後自動同步店家邀請（員工綁定）
//
// 這是整個 SaaS 的帳號系統核心。
// 未來會擴充：店家、權限、角色。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/shop_service.dart';

class AuthService {
  /// 單例：整個 App 共用同一個 AuthService
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 取得目前登入中的使用者
  User? get currentUser => _auth.currentUser;

  /// 監聽登入狀態變化
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 🟢 註冊帳號
  ///
  /// 註冊成功後：
  /// 1. 建立 Firebase Auth
  /// 2. 建立 Firestore users/{uid}
  /// 3. 自動同步店家邀請（如果有被老闆指定 Email）
  Future<UserCredential> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    // 建立 Firebase Auth 帳號
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final User? user = credential.user;
    if (user == null) {
      throw Exception('註冊成功，但抓不到使用者資料');
    }

    final String safeDisplayName = displayName?.trim() ?? '';

    // 更新 Firebase Auth 顯示名稱
    if (safeDisplayName.isNotEmpty) {
      await user.updateDisplayName(safeDisplayName);
    }

    // 建立 Firestore 使用者主檔
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? email.trim(),
      'displayName': safeDisplayName,
      'role': 'user', // 全域角色（未來用）
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 🔥 新增：同步店家邀請（關鍵）
    await ShopService.instance.syncPendingInvitesForCurrentUser();

    return credential;
  }

  /// 🔵 登入
  ///
  /// 登入後會：
  /// - 自動檢查是否有店家邀請
  /// - 如果有 → 直接綁定 shop_members
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // 🔥 新增：登入後同步邀請
    await ShopService.instance.syncPendingInvitesForCurrentUser();

    return credential;
  }

  /// 🔴 登出
  Future<void> logout() {
    return _auth.signOut();
  }
}