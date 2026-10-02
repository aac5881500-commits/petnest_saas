// 檔案名稱：lib/core/services/platform_policy_manage_service.dart
// 功能說明：管理平台條款草稿與已發布版本；已發布版本不可覆寫

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/policy_confirmation_status.dart';

class PlatformPolicyManageService {
  PlatformPolicyManageService._();

  static final instance = PlatformPolicyManageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _policyRef =>
      _firestore.collection('platform_policies');

  /// 讀取條款主文件。已發布內容在 title／content／version，草稿在 draft* 欄位。
  Future<Map<String, dynamic>?> getPolicy(String policyKey) async {
    final doc = await _policyRef.doc(policyKey).get();
    return doc.data();
  }

  /// 只寫草稿欄位，不改已發布內容，也不建立版本文件。
  Future<void> saveDraft({
    required String policyKey,
    required String title,
    required String content,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    await _policyRef.doc(policyKey).set(<String, dynamic>{
      'policyId': policyKey,
      'draftTitle': title,
      'draftContent': content,
      'draftUpdatedAt': FieldValue.serverTimestamp(),
      'draftUpdatedByUid': user?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 建立新的已發布版本。既有 versions/v{n} 已存在時停止，不覆寫內容。
  Future<int> publishNewVersion({
    required String policyKey,
    required String title,
    required String content,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final DocumentReference<Map<String, dynamic>> policyDoc = _policyRef.doc(
      policyKey,
    );
    late int published;
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> current = await transaction
          .get(policyDoc);
      final int currentVersion = publishedVersionOf(current.data());
      published = nextPlatformPolicyVersion(currentVersion);
      final DocumentReference<Map<String, dynamic>> versionDoc = policyDoc
          .collection('versions')
          .doc(platformPolicyVersionDocId(published));
      final DocumentSnapshot<Map<String, dynamic>> existing = await transaction
          .get(versionDoc);
      if (existing.exists) {
        throw StateError('版本 v$published 已發布，不可覆寫舊版本內容');
      }
      final Map<String, dynamic> versionData = <String, dynamic>{
        'policyId': policyKey,
        'version': published,
        'title': title,
        'content': content,
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedByUid': user?.uid ?? '',
        'publishedByEmail': user?.email ?? '',
      };
      transaction.set(versionDoc, versionData);
      transaction.set(policyDoc, <String, dynamic>{
        'policyId': policyKey,
        'title': title,
        'content': content,
        'version': published,
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedByUid': user?.uid ?? '',
        'publishedByEmail': user?.email ?? '',
        if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
        'draftTitle': FieldValue.delete(),
        'draftContent': FieldValue.delete(),
        'draftUpdatedAt': FieldValue.delete(),
        'draftUpdatedByUid': FieldValue.delete(),
      }, SetOptions(merge: true));
    });
    return published;
  }
}

/// 主文件上的已發布版本。沒有 status 的舊資料，只要 version 大於 0 就視為已發布。
int publishedVersionOf(Map<String, dynamic>? data) {
  if (data == null) return 0;
  final String status = (data['status'] ?? '').toString().trim();
  if (status == 'draft') return 0;
  final int version = parsePolicyConfirmationVersion(data['version']);
  if (version <= 0) return 0;
  if (status.isEmpty || status == 'published') return version;
  return 0;
}

bool hasPlatformPolicyDraft(Map<String, dynamic>? data) {
  if (data == null) return false;
  final String title = (data['draftTitle'] ?? '').toString().trim();
  final String content = (data['draftContent'] ?? '').toString().trim();
  return title.isNotEmpty || content.isNotEmpty;
}
