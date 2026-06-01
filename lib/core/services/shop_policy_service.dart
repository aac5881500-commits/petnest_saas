// lib/core/services/shop_policy_service.dart
// 📜 店家入住條款 Service
// 功能：管理入住條款版本、會員同意紀錄、條款歷史版本

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShopPolicyService {
  ShopPolicyService._();

  static final instance = ShopPolicyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> getCheckinPolicy(String shopId) async {
    final doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc('checkin_policy')
        .get();

    if (!doc.exists) return null;

    return doc.data();
  }

  Future<void> updateCheckinPolicy({
    required String shopId,
    required Map<String, dynamic> sections,
    required Map<String, bool> enabled,
    required List<String> customPoliciesPage1,
    required List<String> customPoliciesPage2,
  }) async {
    final user = _currentUser;

    final docRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc('checkin_policy');

    final doc = await docRef.get();

    int newVersion = 1;

    if (doc.exists) {
      final oldVersion = doc.data()?['version'] ?? 1;
      newVersion = oldVersion + 1;
    }

    final policyData = {
      'version': newVersion,
      'sections': sections,
      'enabled': enabled,
      'customPoliciesPage1': customPoliciesPage1,
      'customPoliciesPage2': customPoliciesPage2,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user?.uid ?? '',
      'updatedByEmail': user?.email ?? '',
    };

    await docRef.set(policyData);

    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policy_versions')
        .doc('v$newVersion')
        .set(policyData);
  }

  Future<bool> hasAcceptedPolicy({
    required String shopId,
    required String userId,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return true;

    final currentVersion = policy['version'] ?? 1;

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId)
        .get();

    if (!doc.exists) return false;

    final acceptedVersion = doc.data()?['acceptedVersion'] ?? 0;

    return acceptedVersion == currentVersion;
  }

  Future<void> acceptPolicy({
    required String shopId,
    required String userId,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return;

    final version = policy['version'] ?? 1;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId)
        .set({
          'acceptedVersion': version,
          'acceptedAt': FieldValue.serverTimestamp(),
          'email': _currentUser?.email ?? '',
        });
  }

  Future<List<Map<String, dynamic>>> getPolicyAcceptances(String shopId) async {
    final usersSnapshot = await _firestore.collection('users').get();

    final result = <Map<String, dynamic>>[];

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('policy_acceptances')
          .doc(shopId)
          .get();

      if (!doc.exists) continue;

      result.add({'userId': userId, ...doc.data()!});
    }

    return result;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();

    if (!doc.exists) return null;

    return doc.data();
  }
}
