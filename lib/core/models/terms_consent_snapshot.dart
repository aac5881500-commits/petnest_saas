// 檔案名稱：lib/core/models/terms_consent_snapshot.dart
// 功能說明：條款確認快照：送單時寫入訂單

import 'package:cloud_firestore/cloud_firestore.dart';

class TermsConsentSnapshot {
  const TermsConsentSnapshot({
    required this.termsType,
    required this.termsVersion,
    required this.termsTitle,
    this.termsAcceptedAt,
    this.consentRecordId = '',
    this.termsVersionDocumentId = '',
  });

  final String termsType;
  final int termsVersion;
  final String termsTitle;
  final DateTime? termsAcceptedAt;
  final String consentRecordId;
  final String termsVersionDocumentId;

  Map<String, dynamic> toBookingFields() {
    return <String, dynamic>{
      'termsType': termsType,
      'termsVersion': termsVersion,
      'termsTitle': termsTitle,
      if (termsAcceptedAt != null)
        'termsAcceptedAt': Timestamp.fromDate(termsAcceptedAt!),
      if (consentRecordId.isNotEmpty) 'consentRecordId': consentRecordId,
      if (termsVersionDocumentId.isNotEmpty)
        'termsVersionDocumentId': termsVersionDocumentId,
      'policyVersion': termsVersion,
      'policyTitle': termsTitle,
      if (termsAcceptedAt != null)
        'policyAcceptedAt': Timestamp.fromDate(termsAcceptedAt!),
      'policyAccepted': termsVersion > 0,
      'policyAcceptedFrom': 'customer',
    };
  }

  /// Cloud Functions Web callable 不可傳 Firestore Timestamp。
  Map<String, dynamic> toCallableFields() {
    final String? accepted = termsAcceptedAt?.toUtc().toIso8601String();
    return <String, dynamic>{
      'termsType': termsType,
      'termsVersion': termsVersion,
      'termsTitle': termsTitle,
      if (accepted != null) 'termsAcceptedAt': accepted,
      if (consentRecordId.isNotEmpty) 'consentRecordId': consentRecordId,
      if (termsVersionDocumentId.isNotEmpty)
        'termsVersionDocumentId': termsVersionDocumentId,
      'policyVersion': termsVersion,
      'policyTitle': termsTitle,
      if (accepted != null) 'policyAcceptedAt': accepted,
      'policyAccepted': termsVersion > 0,
      'policyAcceptedFrom': 'customer',
    };
  }
}
