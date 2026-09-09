// 檔案名稱：lib/core/services/shop_policy_service.dart
// 功能說明：管理入住條款版本、會員同意紀錄、條款歷史版本
// 📜 店家入住條款 Service

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/policy_acceptance_rows.dart';

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

  static const String daycareTermsUpdatedMessage = '安親條款已更新，請重新閱讀並同意。';
  static const String stayTermsUpdatedMessage = '住宿條款已更新，請重新閱讀並同意。';

  static bool isTermsUpdatedError(Object error) {
    final String text = error.toString();
    return text.contains('條款已更新');
  }

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
    final int currentVersion = servicePolicyVersion(
      policy: policy,
      serviceType: serviceType,
    );
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
            : (data['lastAcceptedServiceType']?.toString() == serviceType
                  ? data['acceptedVersion']
                  : null));
    final int acceptedVersion = parsePolicyVersion(rawAccepted);
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
    final Map<String, dynamic> textsByService = Map<String, dynamic>.from(
      policy['sectionTextsByService'] ?? {},
    );
    final Map<String, dynamic> serviceTexts = Map<String, dynamic>.from(
      textsByService[serviceType] ?? {},
    );
    if (serviceTexts.isNotEmpty) {
      final Map<String, dynamic> enabledByService = Map<String, dynamic>.from(
        policy['enabledByService'] ?? {},
      );
      final Map<String, dynamic> serviceEnabled = Map<String, dynamic>.from(
        enabledByService[serviceType] ?? {},
      );
      final Map<String, dynamic> mappedSections = <String, dynamic>{};
      final Map<String, bool> mappedEnabled = <String, bool>{};
      serviceTexts.forEach((String key, dynamic value) {
        mappedSections[key] = value;
        mappedEnabled[key] = serviceEnabled[key] != false;
      });
      final Map<String, dynamic> customByService = Map<String, dynamic>.from(
        policy['customPoliciesByService'] ?? {},
      );
      final Map<String, dynamic> serviceCustom = Map<String, dynamic>.from(
        customByService[serviceType] ?? {},
      );
      return <String, dynamic>{
        'version': servicePolicyVersion(
          policy: policy,
          serviceType: serviceType,
        ),
        'sections': mappedSections,
        'enabled': mappedEnabled,
        'customPoliciesPage1': List<dynamic>.from(
          serviceCustom['page1'] ?? const <dynamic>[],
        ),
        'customPoliciesPage2': List<dynamic>.from(
          serviceCustom['page2'] ?? const <dynamic>[],
        ),
      };
    }
    return <String, dynamic>{
      'version': servicePolicyVersion(policy: policy, serviceType: serviceType),
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

    final currentVersion = servicePolicyVersion(
      policy: policy,
      serviceType: serviceType,
    );

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
    final int serviceVersion = parsePolicyVersion(byService[serviceType]);
    if (serviceVersion > 0) {
      return serviceVersion == currentVersion;
    }
    if (serviceType != PolicyApplicableService.accommodation) {
      if (data['lastAcceptedServiceType']?.toString() == serviceType) {
        return parsePolicyVersion(data['acceptedVersion']) == currentVersion;
      }
      return false;
    }
    return parsePolicyVersion(data['acceptedVersion']) == currentVersion;
  }

  Future<void> acceptPolicy({
    required String shopId,
    required String userId,
    String serviceType = PolicyApplicableService.accommodation,
  }) async {
    final policy = await getCheckinPolicy(shopId);
    if (policy == null) return;

    final version = servicePolicyVersion(
      policy: policy,
      serviceType: serviceType,
    );
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

  Future<Map<String, dynamic>> loadPolicyVersionSnapshot({
    required String shopId,
    required String serviceType,
    required int version,
  }) async {
    final String historyId = serviceType == PolicyApplicableService.daycare
        ? 'daycare_v$version'
        : 'v$version';
    DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policy_versions')
        .doc(historyId)
        .get();
    if (!doc.exists && serviceType == PolicyApplicableService.daycare) {
      doc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('policy_versions')
          .doc('v$version')
          .get();
    }
    return doc.data() ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getPolicyAcceptances(String shopId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collectionGroup('policy_acceptances')
        .where('shopId', isEqualTo: shopId)
        .get();

    final List<PolicyAcceptanceRow> rows = <PolicyAcceptanceRow>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if ((data['userId'] ?? '').toString().trim().isEmpty) {
        data['userId'] = doc.reference.parent.parent?.id ?? '';
      }
      rows.addAll(PolicyAcceptanceRows.expand(data));
    }

    final Set<String> userIds = rows
        .map((PolicyAcceptanceRow row) => row.userId)
        .where((String id) => id.isNotEmpty)
        .toSet();
    final Map<String, Map<String, dynamic>> members =
        await _loadShopMembersByIds(shopId: shopId, userIds: userIds);

    return rows.map((PolicyAcceptanceRow row) {
      final Map<String, dynamic>? member = members[row.userId];
      final String name = (member?['name'] ?? member?['displayName'] ?? '')
          .toString()
          .trim();
      final String email = row.docEmail.isNotEmpty
          ? row.docEmail
          : (member?['email'] ?? '').toString().trim();
      final String phone = (member?['phone'] ?? member?['mobile'] ?? '')
          .toString()
          .trim();
      return <String, dynamic>{
        'userId': row.userId,
        'serviceType': row.serviceType,
        'acceptedVersion': row.acceptedVersion,
        'acceptedAt': row.acceptedAt,
        'memberExists': member != null,
        'customerName': name,
        'email': email,
        'customerPhone': phone,
      };
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _loadShopMembersByIds({
    required String shopId,
    required Set<String> userIds,
  }) async {
    final Map<String, Map<String, dynamic>> out =
        <String, Map<String, dynamic>>{};
    if (userIds.isEmpty) {
      return out;
    }
    final List<String> ids = userIds.toList();
    for (int i = 0; i < ids.length; i += 20) {
      final List<String> chunk = ids.sublist(
        i,
        i + 20 > ids.length ? ids.length : i + 20,
      );
      final List<DocumentSnapshot<Map<String, dynamic>>> snaps =
          await Future.wait(
            chunk.map((String id) {
              return _firestore
                  .collection('shops')
                  .doc(shopId)
                  .collection('members')
                  .doc(id)
                  .get();
            }),
          );
      for (final DocumentSnapshot<Map<String, dynamic>> snap in snaps) {
        if (snap.exists) {
          out[snap.id] = snap.data() ?? <String, dynamic>{};
        }
      }
    }
    return out;
  }

  static int parsePolicyVersion(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    final Match? match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static int servicePolicyVersion({
    required Map<String, dynamic> policy,
    required String serviceType,
  }) {
    final Map<String, dynamic> serviceVersions = Map<String, dynamic>.from(
      policy['serviceVersions'] is Map
          ? policy['serviceVersions'] as Map
          : const <String, dynamic>{},
    );
    final int mapped = parsePolicyVersion(serviceVersions[serviceType]);
    if (mapped > 0) {
      return mapped;
    }
    if (serviceType == PolicyApplicableService.daycare) {
      final int daycareVersion = parsePolicyVersion(policy['daycareVersion']);
      if (daycareVersion > 0) {
        return daycareVersion;
      }
      final Map<String, dynamic> textsByService = Map<String, dynamic>.from(
        policy['sectionTextsByService'] is Map
            ? policy['sectionTextsByService'] as Map
            : const <String, dynamic>{},
      );
      final Map<String, dynamic> daycareTexts = Map<String, dynamic>.from(
        textsByService[PolicyApplicableService.daycare] is Map
            ? textsByService[PolicyApplicableService.daycare] as Map
            : const <String, dynamic>{},
      );
      if (daycareTexts.isNotEmpty) {
        return 1;
      }
      return parsePolicyVersion(policy['version']);
    }
    return parsePolicyVersion(policy['accommodationVersion']) > 0
        ? parsePolicyVersion(policy['accommodationVersion'])
        : parsePolicyVersion(policy['version']);
  }

  static String policyContentFingerprint(Map<String, dynamic> filteredPolicy) {
    return jsonEncode(<String, dynamic>{
      'sections': filteredPolicy['sections'] ?? <String, dynamic>{},
      'enabled': filteredPolicy['enabled'] ?? <String, dynamic>{},
      'customPoliciesPage1':
          filteredPolicy['customPoliciesPage1'] ?? const <dynamic>[],
      'customPoliciesPage2':
          filteredPolicy['customPoliciesPage2'] ?? const <dynamic>[],
    });
  }

  static String refundTemplate() {
    return '''
一、退款申請
客人可於訂單詳細閱讀本條款後，透過訂單留言或聯絡店家提出退款申請。實際是否退款、退款比例與作業時間，由店家依訂單狀況與本條款人工審核。

二、訂金與已付款項
已確認之訂金或已付款項，不保證全額退還。店家得依取消時間、是否已保留房間／名額、是否已開始服務，決定退款、部分退款或不退款。

三、不可抗力
若因天災、政府公告停班停課或其他不可抗力因素無法提供服務，店家得與客人協議延期或退款，細節以店家公告與雙方溝通為準。

四、作業方式
退款作業為人工處理，不會由系統自動執行金流退款。完成審核後，店家會另行通知退款方式與金額。

五、聯絡
請優先使用訂單留言說明需求，或依店家提供的聯絡方式聯繫，以便核對訂單編號與付款資料。
''';
  }

  Future<Map<String, dynamic>?> getRefundPolicy(String shopId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc('refund_policy')
        .get();
    if (!doc.exists) {
      return null;
    }
    return doc.data();
  }

  Future<void> updateRefundPolicy({
    required String shopId,
    required String title,
    required String description,
    required String body,
    required bool enabled,
  }) async {
    final User? user = _currentUser;
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc('refund_policy');
    final DocumentSnapshot<Map<String, dynamic>> doc = await docRef.get();
    int newVersion = 1;
    if (doc.exists) {
      newVersion =
          ((doc.data()?['refundPolicyVersion'] ?? doc.data()?['version'] ?? 0)
                  as num)
              .toInt() +
          1;
    }
    final Map<String, dynamic> policyData = <String, dynamic>{
      'title': title.trim().isEmpty ? '退款條款' : title.trim(),
      'description': description.trim(),
      'body': body.trim(),
      'enabled': enabled,
      'refundPolicyVersion': newVersion,
      'version': newVersion,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user?.uid ?? '',
      'updatedByEmail': user?.email ?? '',
    };
    await docRef.set(policyData);
    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('refund_policy_versions')
        .doc('v$newVersion')
        .set(policyData);
  }

  Future<void> updateServicePolicy({
    required String shopId,
    required String serviceType,
    required Map<String, dynamic> sections,
    required Map<String, bool> enabled,
    required List<String> customPoliciesPage1,
    required List<String> customPoliciesPage2,
  }) async {
    final User? user = _currentUser;
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('policies')
        .doc('checkin_policy');
    final DocumentSnapshot<Map<String, dynamic>> doc = await docRef.get();
    final Map<String, dynamic> existing = doc.data() ?? <String, dynamic>{};
    if (existing['sectionTextsByService'] == null) {
      existing['sectionTextsByService'] = <String, dynamic>{
        PolicyApplicableService.accommodation: Map<String, dynamic>.from(
          existing['sections'] ?? {},
        ),
      };
      existing['enabledByService'] = <String, dynamic>{
        PolicyApplicableService.accommodation: Map<String, dynamic>.from(
          existing['enabled'] ?? {},
        ),
      };
      existing['customPoliciesByService'] = <String, dynamic>{
        PolicyApplicableService.accommodation: <String, dynamic>{
          'page1': PolicyApplicableService.textsForService(
            items: PolicyApplicableService.normalizeCustomPolicies(
              existing['customPoliciesPage1'],
            ),
            serviceType: PolicyApplicableService.accommodation,
          ),
          'page2': PolicyApplicableService.textsForService(
            items: PolicyApplicableService.normalizeCustomPolicies(
              existing['customPoliciesPage2'],
            ),
            serviceType: PolicyApplicableService.accommodation,
          ),
        },
      };
    }

    final Map<String, dynamic> textsByService = Map<String, dynamic>.from(
      existing['sectionTextsByService'] ?? {},
    );
    final Map<String, dynamic> enabledByService = Map<String, dynamic>.from(
      existing['enabledByService'] ?? {},
    );
    final Map<String, dynamic> customByService = Map<String, dynamic>.from(
      existing['customPoliciesByService'] ?? {},
    );
    if (Map<String, dynamic>.from(
      textsByService[PolicyApplicableService.daycare] ?? {},
    ).isEmpty) {
      final Map<String, dynamic> seeded = filterPolicyForService(
        policy: existing,
        serviceType: PolicyApplicableService.daycare,
      );
      textsByService[PolicyApplicableService.daycare] =
          Map<String, dynamic>.from(seeded['sections'] ?? {});
      enabledByService[PolicyApplicableService.daycare] =
          Map<String, dynamic>.from(seeded['enabled'] ?? {});
      customByService[PolicyApplicableService.daycare] = <String, dynamic>{
        'page1': seeded['customPoliciesPage1'] ?? const <dynamic>[],
        'page2': seeded['customPoliciesPage2'] ?? const <dynamic>[],
      };
    }

    final Map<String, dynamic> beforeSave = <String, dynamic>{
      ...existing,
      'sectionTextsByService': textsByService,
      'enabledByService': enabledByService,
      'customPoliciesByService': customByService,
    };
    final String oldFingerprint = policyContentFingerprint(
      filterPolicyForService(policy: beforeSave, serviceType: serviceType),
    );

    textsByService[serviceType] = sections;
    enabledByService[serviceType] = enabled;
    final bool keepExistingCustom =
        customPoliciesPage1.every((String e) => e.trim().isEmpty) &&
        customPoliciesPage2.every((String e) => e.trim().isEmpty) &&
        customByService[serviceType] is Map;
    if (!keepExistingCustom) {
      customByService[serviceType] = <String, dynamic>{
        'page1': customPoliciesPage1
            .where((String e) => e.trim().isNotEmpty)
            .toList(),
        'page2': customPoliciesPage2
            .where((String e) => e.trim().isNotEmpty)
            .toList(),
      };
    }

    final Map<String, List<String>> sectionApplicableServices =
        <String, List<String>>{};
    final Set<String> keys = <String>{
      ...Map<String, dynamic>.from(
        textsByService[PolicyApplicableService.accommodation] ?? {},
      ).keys,
      ...Map<String, dynamic>.from(
        textsByService[PolicyApplicableService.daycare] ?? {},
      ).keys,
    };
    for (final String key in keys) {
      final String stayText =
          (Map<String, dynamic>.from(
                    textsByService[PolicyApplicableService.accommodation] ?? {},
                  )[key] ??
                  '')
              .toString()
              .trim();
      final String daycareText =
          (Map<String, dynamic>.from(
                    textsByService[PolicyApplicableService.daycare] ?? {},
                  )[key] ??
                  '')
              .toString()
              .trim();
      if (stayText.isNotEmpty && daycareText.isNotEmpty) {
        sectionApplicableServices[key] = PolicyApplicableService.shared;
      } else if (daycareText.isNotEmpty) {
        sectionApplicableServices[key] = PolicyApplicableService.daycareOnly;
      } else {
        sectionApplicableServices[key] =
            PolicyApplicableService.accommodationOnly;
      }
    }

    final Map<String, dynamic> staySections = Map<String, dynamic>.from(
      textsByService[PolicyApplicableService.accommodation] ?? sections,
    );
    if (serviceType == PolicyApplicableService.accommodation) {
      staySections.addAll(sections);
    }

    int accommodationVersion =
        (existing['accommodationVersion'] as num?)?.toInt() ??
        (existing['version'] as num?)?.toInt() ??
        0;
    int daycareVersion = (existing['daycareVersion'] as num?)?.toInt() ?? 0;
    if (daycareVersion <= 0) {
      daycareVersion = (existing['version'] as num?)?.toInt() ?? 0;
    }

    List<Map<String, dynamic>> packCustom(
      List<String> texts,
      List<String> services,
    ) {
      return texts
          .where((String e) => e.trim().isNotEmpty)
          .map(
            (String text) => <String, dynamic>{
              'text': text.trim(),
              'applicableServices': services,
            },
          )
          .toList();
    }

    final List<String> stayCustom1 = List<String>.from(
      (customByService[PolicyApplicableService.accommodation]
              as Map?)?['page1'] ??
          const <dynamic>[],
    );
    final List<String> stayCustom2 = List<String>.from(
      (customByService[PolicyApplicableService.accommodation]
              as Map?)?['page2'] ??
          const <dynamic>[],
    );

    final Map<String, dynamic> policyData = <String, dynamic>{
      ...existing,
      'accommodationVersion': accommodationVersion,
      'daycareVersion': daycareVersion,
      'sections': staySections,
      'enabled': Map<String, dynamic>.from(
        enabledByService[PolicyApplicableService.accommodation] ?? enabled,
      ),
      'sectionApplicableServices': sectionApplicableServices,
      'sectionTextsByService': textsByService,
      'enabledByService': enabledByService,
      'customPoliciesByService': customByService,
      'customPoliciesPage1': packCustom(
        stayCustom1,
        PolicyApplicableService.accommodationOnly,
      ),
      'customPoliciesPage2': packCustom(
        stayCustom2,
        PolicyApplicableService.accommodationOnly,
      ),
    };
    final String newFingerprint = policyContentFingerprint(
      filterPolicyForService(policy: policyData, serviceType: serviceType),
    );
    final bool contentChanged = oldFingerprint != newFingerprint;
    if (contentChanged) {
      if (serviceType == PolicyApplicableService.daycare) {
        daycareVersion += 1;
      } else {
        accommodationVersion += 1;
      }
    }
    policyData['accommodationVersion'] = accommodationVersion;
    policyData['daycareVersion'] = daycareVersion;
    policyData['serviceVersions'] = <String, dynamic>{
      PolicyApplicableService.accommodation: accommodationVersion,
      PolicyApplicableService.daycare: daycareVersion,
    };
    policyData['version'] = accommodationVersion;
    policyData['updatedAt'] = FieldValue.serverTimestamp();
    policyData['updatedByUid'] = user?.uid ?? '';
    policyData['updatedByEmail'] = user?.email ?? '';
    await docRef.set(policyData);
    if (contentChanged) {
      final String historyId = serviceType == PolicyApplicableService.daycare
          ? 'daycare_v$daycareVersion'
          : 'v$accommodationVersion';
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('policy_versions')
          .doc(historyId)
          .set(<String, dynamic>{...policyData, 'serviceType': serviceType});
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();

    if (!doc.exists) return null;

    return doc.data();
  }
}
