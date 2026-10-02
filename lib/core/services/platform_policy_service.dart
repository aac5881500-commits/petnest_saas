// 檔案名稱：lib/core/services/platform_policy_service.dart
// 功能說明：平台條款同意紀錄。與店家 users/{uid}/policy_acceptances/{shopId} 分開。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/policy_confirmation_status.dart';
import 'package:petnest_saas/core/services/platform_policy_manage_service.dart';

class PlatformPolicyAcceptance {
  const PlatformPolicyAcceptance({
    required this.publishedVersion,
    required this.acceptedVersion,
    required this.state,
    this.acceptedAt,
    this.publishedAt,
    this.title = '',
    this.content = '',
  });

  final int publishedVersion;
  final int acceptedVersion;
  final PolicyConfirmationState state;
  final DateTime? acceptedAt;
  final DateTime? publishedAt;
  final String title;
  final String content;

  bool get acceptedCurrent => state == PolicyConfirmationState.current;

  bool get mustConfirm =>
      state == PolicyConfirmationState.notAccepted ||
      state == PolicyConfirmationState.needsUpdate;
}

class PlatformPolicyService {
  PlatformPolicyService._();
  static final instance = PlatformPolicyService._();

  static const String platformUserPolicyId = 'platform_user_policy';
  static const String acceptanceCollection = 'platform_policy_acceptances';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String acceptancePath(String uid) {
    return 'users/$uid/$acceptanceCollection/$platformUserPolicyId';
  }

  Future<int> getCurrentUserPolicyVersion() async {
    final Map<String, dynamic>? data = await PlatformPolicyManageService
        .instance
        .getPolicy(platformUserPolicyId);
    return publishedVersionOf(data);
  }

  Future<PlatformPolicyAcceptance> loadAcceptance({
    required String uid,
    Map<String, dynamic>? userData,
  }) async {
    final Map<String, dynamic>? policy = await PlatformPolicyManageService
        .instance
        .getPolicy(platformUserPolicyId);
    final int published = publishedVersionOf(policy);
    final DocumentSnapshot<Map<String, dynamic>> acceptance = await _firestore
        .doc(acceptancePath(uid))
        .get();
    Map<String, dynamic>? legacy = userData;
    int accepted = _acceptedVersion(
      acceptance: acceptance.data(),
      userData: legacy,
    );
    if (accepted <= 0 && legacy == null) {
      final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      legacy = userDoc.data();
      accepted = _acceptedVersion(
        acceptance: acceptance.data(),
        userData: legacy,
      );
    }
    return PlatformPolicyAcceptance(
      publishedVersion: published,
      acceptedVersion: accepted,
      state: resolvePolicyConfirmation(
        publishedVersion: published,
        acceptedVersion: accepted,
      ),
      acceptedAt: _date(
        acceptance.data()?['acceptedAt'] ?? legacy?['acceptedPlatformPolicyAt'],
      ),
      publishedAt: _date(policy?['publishedAt'] ?? policy?['updatedAt']),
      title: (policy?['title'] ?? '').toString(),
      content: (policy?['content'] ?? '').toString(),
    );
  }

  Future<bool> hasAcceptedCurrentUserPolicy() async {
    final User? user = _auth.currentUser;
    if (user == null) return false;
    final PlatformPolicyAcceptance acceptance = await loadAcceptance(
      uid: user.uid,
    );
    return !acceptance.mustConfirm;
  }

  Future<void> acceptCurrentUserPolicy() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('尚未登入');
    }
    final int currentVersion = await getCurrentUserPolicyVersion();
    if (currentVersion <= 0) {
      throw Exception('目前沒有已發布的平台條款');
    }
    final WriteBatch batch = _firestore.batch();
    batch.set(_firestore.doc(acceptancePath(user.uid)), <String, dynamic>{
      'uid': user.uid,
      'policyId': platformUserPolicyId,
      'type': platformUserPolicyId,
      'acceptedVersion': currentVersion,
      'acceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(user.uid), <String, dynamic>{
      'acceptedPlatformPolicyVersion': currentVersion,
      'acceptedPlatformPolicyAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<Map<String, dynamic>?> loadPublishedVersion(int version) async {
    if (version <= 0) return null;
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('platform_policies')
        .doc(platformUserPolicyId)
        .collection('versions')
        .doc(platformPolicyVersionDocId(version))
        .get();
    return doc.data();
  }

  int _acceptedVersion({
    required Map<String, dynamic>? acceptance,
    required Map<String, dynamic>? userData,
  }) {
    final int fromRecord = parsePolicyConfirmationVersion(
      acceptance?['acceptedVersion'],
    );
    if (fromRecord > 0) return fromRecord;
    return parsePolicyConfirmationVersion(
      userData?['acceptedPlatformPolicyVersion'],
    );
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
