// lib/core/services/member_service.dart
// 👤 會員服務（跨店會員系統）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberService {
  MemberService._();
  static final instance = MemberService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔥 確保會員存在（登入店家時呼叫）
  Future<void> ensureMember({
    required String shopId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final memberRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(user.uid);

    final doc = await memberRef.get();

    /// 已存在就不建立
    if (doc.exists) return;

    /// 建立會員
    await memberRef.set({
      'userId': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),

      /// 🔥 未來會用到
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isBlocked': false,
    });
  }

  /// 🔥 更新最後登入時間
  Future<void> updateLastLogin({
    required String shopId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('members')
        .doc(user.uid)
        .update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}