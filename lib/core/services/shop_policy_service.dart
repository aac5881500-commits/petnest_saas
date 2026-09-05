// 檔案名稱：lib/core/services/shop_policy_service.dart
// 功能說明：管理入住條款版本、會員同意紀錄、條款歷史版本
// 📜 店家入住條款 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';

/// 前台條款確認狀態（userId + shopId + termsType + termsVersion）
class TermsStatus {
  const TermsStatus({
    required this.required,
    required this.accepted,
    required this.versionUpdated,
    required this.version,
    required this.title,
    this.acceptedAt,
  });

  final bool required;
  final bool accepted;
  final bool versionUpdated;
  final int version;
  final String title;
  final DateTime? acceptedAt;

  bool get canSubmit => !required || accepted;
}

class ShopPolicyService {
  ShopPolicyService._();

  static final instance = ShopPolicyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  String termsTitleForService(String serviceType) {
    return serviceType == PolicyApplicableService.daycare ? '安親須知' : '入住須知';
  }

  String consentRecordPath({required String userId, required String shopId}) {
    return 'users/$userId/policy_acceptances/$shopId';
  }

  Future<TermsStatus> getTermsStatus({
    required String shopId,
    required String userId,
    String serviceType = PolicyApplicableService.accommodation,
  }) async {
    final Map<String, dynamic>? policy = await getCheckinPolicy(shopId);
    final String title = termsTitleForService(serviceType);
    if (policy == null) {
      return TermsStatus(
        required: false,
        accepted: true,
        versionUpdated: false,
        version: 0,
        title: title,
      );
    }
    final Map<String, dynamic> filtered = filterPolicyForService(
      policy: policy,
      serviceType: serviceType,
    );
    if (!policyRequiresSignature(filteredPolicy: filtered)) {
      return TermsStatus(
        required: false,
        accepted: true,
        versionUpdated: false,
        version: (filtered['version'] as num?)?.toInt() ?? 0,
        title: title,
      );
    }
    final int currentVersion = (policy['version'] as num?)?.toInt() ?? 1;
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId)
        .get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> byService = Map<String, dynamic>.from(
      data['acceptedAtByService'] ?? <String, dynamic>{},
    );
    final Map<String, dynamic> versions = Map<String, dynamic>.from(
      data['acceptedVersions'] ?? <String, dynamic>{},
    );
    final dynamic rawAccepted =
        versions[serviceType] ??
        (serviceType == PolicyApplicableService.accommodation
            ? data['acceptedVersion']
            : null);
    final int acceptedVersion = rawAccepted is int
        ? rawAccepted
        : int.tryParse(rawAccepted?.toString() ?? '') ?? 0;
    DateTime? acceptedAt;
    final dynamic rawAt = byService[serviceType] ?? data['acceptedAt'];
    if (rawAt is Timestamp) {
      acceptedAt = rawAt.toDate();
    }
    final bool accepted = acceptedVersion == currentVersion;
    final bool versionUpdated =
        !accepted && acceptedVersion > 0 && acceptedVersion != currentVersion;
    return TermsStatus(
      required: true,
      accepted: accepted,
      versionUpdated: versionUpdated,
      version: currentVersion,
      title: title,
      acceptedAt: acceptedAt,
    );
  }

  Future<TermsConsentSnapshot> confirmTerms({
    required String shopId,
    required String userId,
    String serviceType = PolicyApplicableService.accommodation,
  }) async {
    await acceptPolicy(
      shopId: shopId,
      userId: userId,
      serviceType: serviceType,
    );
    final TermsStatus status = await getTermsStatus(
      shopId: shopId,
      userId: userId,
      serviceType: serviceType,
    );
    return TermsConsentSnapshot(
      termsType: serviceType,
      termsVersion: status.version,
      termsTitle: status.title,
      termsAcceptedAt: status.acceptedAt ?? DateTime.now(),
      consentRecordId: consentRecordPath(userId: userId, shopId: shopId),
      termsVersionDocumentId: status.version > 0 ? 'v${status.version}' : '',
    );
  }

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
    Map<String, List<String>> sectionApplicableServices =
        const <String, List<String>>{},
    List<List<String>> customPolicyServicesPage1 = const <List<String>>[],
    List<List<String>> customPolicyServicesPage2 = const <List<String>>[],
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

    List<Map<String, dynamic>> _packCustom(
      List<String> texts,
      List<List<String>> services,
    ) {
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      for (int i = 0; i < texts.length; i++) {
        final String text = texts[i].trim();
        if (text.isEmpty) {
          continue;
        }
        items.add(<String, dynamic>{
          'text': text,
          'applicableServices': PolicyApplicableService.parse(
            i < services.length
                ? services[i]
                : PolicyApplicableService.accommodationOnly,
          ),
        });
      }
      return items;
    }

    final policyData = {
      'version': newVersion,
      'sections': sections,
      'enabled': enabled,
      'sectionApplicableServices': sectionApplicableServices.map(
        (String key, List<String> value) =>
            MapEntry(key, PolicyApplicableService.parse(value)),
      ),
      'customPoliciesPage1': _packCustom(
        customPoliciesPage1,
        customPolicyServicesPage1,
      ),
      'customPoliciesPage2': _packCustom(
        customPoliciesPage2,
        customPolicyServicesPage2,
      ),
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

  Map<String, dynamic> filterPolicyForService({
    required Map<String, dynamic> policy,
    required String serviceType,
  }) {
    final Map<String, dynamic> sections = Map<String, dynamic>.from(
      policy['sections'] ?? {},
    );
    final Map<String, bool> enabled = Map<String, bool>.from(
      policy['enabled'] ?? {},
    );
    final Map<String, dynamic> sectionServices = Map<String, dynamic>.from(
      policy['sectionApplicableServices'] ?? {},
    );
    final Map<String, dynamic> filteredSections = <String, dynamic>{};
    final Map<String, bool> filteredEnabled = <String, bool>{};
    for (final String key in sections.keys) {
      final List<String> services = PolicyApplicableService.parse(
        sectionServices[key],
      );
      if (!PolicyApplicableService.appliesTo(services, serviceType)) {
        continue;
      }
      filteredSections[key] = sections[key];
      filteredEnabled[key] = enabled[key] != false;
    }
    final List<Map<String, dynamic>> custom1 =
        PolicyApplicableService.normalizeCustomPolicies(
          policy['customPoliciesPage1'],
        );
    final List<Map<String, dynamic>> custom2 =
        PolicyApplicableService.normalizeCustomPolicies(
          policy['customPoliciesPage2'],
        );
    return <String, dynamic>{
      'version': policy['version'] ?? 1,
      'sections': filteredSections,
      'enabled': filteredEnabled,
      'customPoliciesPage1': PolicyApplicableService.textsForService(
        items: custom1,
        serviceType: serviceType,
      ),
      'customPoliciesPage2': PolicyApplicableService.textsForService(
        items: custom2,
        serviceType: serviceType,
      ),
    };
  }

  bool policyRequiresSignature({required Map<String, dynamic> filteredPolicy}) {
    final Map<String, bool> enabled = Map<String, bool>.from(
      filteredPolicy['enabled'] ?? {},
    );
    final Map<String, dynamic> sections = Map<String, dynamic>.from(
      filteredPolicy['sections'] ?? {},
    );
    final bool hasSection = enabled.entries.any((MapEntry<String, bool> e) {
      if (!e.value) {
        return false;
      }
      return (sections[e.key] ?? '').toString().trim().isNotEmpty;
    });
    final List<dynamic> c1 = filteredPolicy['customPoliciesPage1'] is List
        ? filteredPolicy['customPoliciesPage1'] as List<dynamic>
        : const <dynamic>[];
    final List<dynamic> c2 = filteredPolicy['customPoliciesPage2'] is List
        ? filteredPolicy['customPoliciesPage2'] as List<dynamic>
        : const <dynamic>[];
    return hasSection ||
        c1.any((dynamic e) => e.toString().trim().isNotEmpty) ||
        c2.any((dynamic e) => e.toString().trim().isNotEmpty);
  }

  Future<bool> hasAcceptedPolicy({
    required String shopId,
    required String userId,
    String serviceType = PolicyApplicableService.accommodation,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return true;

    final filtered = filterPolicyForService(
      policy: policy,
      serviceType: serviceType,
    );
    if (!policyRequiresSignature(filteredPolicy: filtered)) {
      return true;
    }

    final currentVersion = policy['version'] ?? 1;

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId)
        .get();

    if (!doc.exists) return false;

    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> byService = Map<String, dynamic>.from(
      data['acceptedVersions'] ?? {},
    );
    final dynamic serviceVersion = byService[serviceType];
    if (serviceVersion != null) {
      return serviceVersion == currentVersion;
    }
    if (serviceType != PolicyApplicableService.accommodation) {
      return false;
    }
    final acceptedVersion = data['acceptedVersion'] ?? 0;
    return acceptedVersion == currentVersion;
  }

  Future<void> acceptPolicy({
    required String shopId,
    required String userId,
    String serviceType = PolicyApplicableService.accommodation,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return;

    final version = policy['version'] ?? 1;
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('policy_acceptances')
        .doc(shopId);

    await _firestore.runTransaction((Transaction transaction) async {
      final snap = await transaction.get(ref);
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final Map<String, dynamic> byService = Map<String, dynamic>.from(
        data['acceptedVersions'] ?? {},
      );
      byService[serviceType] = version;
      final Map<String, dynamic> acceptedAtByService =
          Map<String, dynamic>.from(
            data['acceptedAtByService'] ?? <String, dynamic>{},
          );
      acceptedAtByService[serviceType] = FieldValue.serverTimestamp();
      transaction.set(ref, {
        'shopId': shopId,
        'userId': userId,
        'acceptedVersion': serviceType == PolicyApplicableService.accommodation
            ? version
            : (data['acceptedVersion'] ?? version),
        'acceptedVersions': byService,
        'acceptedAtByService': acceptedAtByService,
        'acceptedAt': FieldValue.serverTimestamp(),
        'lastAcceptedServiceType': serviceType,
        'email': _currentUser?.email ?? '',
      }, SetOptions(merge: true));
    });
  }

  Future<List<Map<String, dynamic>>> getPolicyAcceptances(String shopId) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    final latestMap = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final policyVersion = data['policyVersion'] ?? 0;
      final policyAcceptedAt = data['policyAcceptedAt'];

      if (policyVersion == 0 || policyAcceptedAt == null) continue;

      final userId = data['userId'] ?? '';
      final key = '${userId}_v$policyVersion';

      final item = {
        'bookingId': doc.id,
        'userId': userId,
        'email': data['customerEmail'] ?? '',
        'customerName': data['customerName'] ?? '',
        'customerPhone': data['customerPhone'] ?? '',
        'acceptedVersion': policyVersion,
        'acceptedAt': policyAcceptedAt,
        'policyTitle': data['policyTitle'] ?? '入住須知',
      };

      final old = latestMap[key];
      if (old == null) {
        latestMap[key] = item;
        continue;
      }

      final oldTime = old['acceptedAt'];
      if (oldTime is Timestamp &&
          policyAcceptedAt is Timestamp &&
          policyAcceptedAt.compareTo(oldTime) > 0) {
        latestMap[key] = item;
      }
    }

    return latestMap.values.toList();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();

    if (!doc.exists) return null;

    return doc.data();
  }
}
