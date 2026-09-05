// 檔案名稱：lib/core/services/platform_policy_service.dart
// 功能說明：處理平台會員條款同意紀錄與 Firestore 版本檢查
// 📜 平台條款服務

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/platform/pages/platform_user_policy_page.dart';

class PlatformPolicyService {
  PlatformPolicyService._();
  static final instance = PlatformPolicyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<int> getCurrentUserPolicyVersion() async {
    final doc = await _firestore
        .collection('platform_policies')
        .doc(PlatformUserPolicyPage.policyKey)
        .get();

    final data = doc.data();

    if (data == null) return 1;

    return data['version'] is int ? data['version'] : 1;
  }

  Future<bool> hasAcceptedCurrentUserPolicy() async {
    final user = _auth.currentUser;

    if (user == null) return false;

    final currentVersion = await getCurrentUserPolicyVersion();

    final doc = await _firestore.collection('users').doc(user.uid).get();

    final acceptedVersion = doc.data()?['acceptedPlatformPolicyVersion'] ?? 0;

    return acceptedVersion == currentVersion;
  }

  Future<void> acceptCurrentUserPolicy() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('尚未登入');
    }

    final currentVersion = await getCurrentUserPolicyVersion();

    await _firestore.collection('users').doc(user.uid).set({
      'acceptedPlatformPolicyVersion': currentVersion,
      'acceptedPlatformPolicyAt': FieldValue.serverTimestamp(),
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('policy_acceptances')
        .doc('platform_user_policy_v$currentVersion')
        .set({
          'type': 'platform_user_policy',
          'version': currentVersion,
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedByUid': user.uid,
          'acceptedByEmail': user.email ?? '',
        });
  }
}
