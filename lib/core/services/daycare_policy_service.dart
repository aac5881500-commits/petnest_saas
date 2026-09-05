// 檔案名稱：lib/core/services/daycare_policy_service.dart
// 功能說明：臨托條款：shops/{shopId}/policies/daycare_policy 與版本紀錄

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DaycarePolicyService {
  DaycarePolicyService._();

  static final DaycarePolicyService instance = DaycarePolicyService._();

  static const String policyId = 'daycare_policy';

  DocumentReference<Map<String, dynamic>> _ref(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc(policyId);
  }

  Future<Map<String, dynamic>?> get(String shopId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _ref(
      shopId,
    ).get();
    return snap.data();
  }

  Stream<Map<String, dynamic>?> stream(String shopId) {
    return _ref(shopId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) => snap.data(),
    );
  }

  Future<void> save({
    required String shopId,
    required String title,
    required String content,
    required bool enabled,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final DocumentSnapshot<Map<String, dynamic>> current = await _ref(
      shopId,
    ).get();
    final int version =
        ((current.data()?['version'] as num?)?.toInt() ?? 0) + 1;
    final Map<String, dynamic> policy = <String, dynamic>{
      'title': title.trim().isEmpty ? '臨托條款' : title.trim(),
      'content': content.trim(),
      'enabled': enabled,
      'version': version,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user?.uid ?? '',
    };
    await _ref(shopId).set(policy);
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('daycare_policy_versions')
        .doc('v$version')
        .set(policy);
  }
}
