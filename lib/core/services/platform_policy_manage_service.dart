// lib/core/services/platform_policy_manage_service.dart
// 📜 平台條款管理 Service
// 功能：管理平台條款內容、版本與更新時間

import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformPolicyManageService {
  PlatformPolicyManageService._();

  static final instance = PlatformPolicyManageService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _policyRef =>
          _firestore.collection('platform_policies');

  /// 讀取條款
  Future<Map<String, dynamic>?> getPolicy(
    String policyKey,
  ) async {
    final doc = await _policyRef.doc(policyKey).get();

    return doc.data();
  }

  /// 儲存條款
  Future<void> savePolicy({
  required String policyKey,
  required String title,
  required String content,
  required int version,
}) async {
  final policyDoc = _policyRef.doc(policyKey);
  final versionDoc = policyDoc.collection('versions').doc('v$version');

  final data = {
    'title': title,
    'content': content,
    'version': version,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  await policyDoc.set(data, SetOptions(merge: true));
  await versionDoc.set(data, SetOptions(merge: true));
}
}