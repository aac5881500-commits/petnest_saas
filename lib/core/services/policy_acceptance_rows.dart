// 檔案名稱：lib/core/services/policy_acceptance_rows.dart
// 功能說明：將 per-service 條款同意文件展開成住宿／安親列，不回寫資料

import 'package:petnest_saas/core/models/policy_applicable_service.dart';

class PolicyAcceptanceRow {
  const PolicyAcceptanceRow({
    required this.userId,
    required this.serviceType,
    required this.acceptedVersion,
    required this.acceptedAt,
    required this.docEmail,
  });

  final String userId;
  final String serviceType;
  final int acceptedVersion;
  final dynamic acceptedAt;
  final String docEmail;
}

class PolicyAcceptanceRows {
  PolicyAcceptanceRows._();

  static List<PolicyAcceptanceRow> expand(Map<String, dynamic> data) {
    final String userId = (data['userId'] ?? '').toString().trim();
    final String docEmail = (data['email'] ?? '').toString().trim();
    final Map<String, dynamic> versions = Map<String, dynamic>.from(
      data['acceptedVersions'] is Map
          ? data['acceptedVersions'] as Map
          : const <String, dynamic>{},
    );
    final Map<String, dynamic> acceptedAtByService = Map<String, dynamic>.from(
      data['acceptedAtByService'] is Map
          ? data['acceptedAtByService'] as Map
          : const <String, dynamic>{},
    );
    final String lastService = (data['lastAcceptedServiceType'] ?? '')
        .toString()
        .trim();
    final int legacyVersion = (data['acceptedVersion'] as num?)?.toInt() ?? 0;
    final dynamic legacyAt = data['acceptedAt'];

    final List<PolicyAcceptanceRow> rows = <PolicyAcceptanceRow>[];

    final int stayVersion =
        (versions[PolicyApplicableService.accommodation] as num?)?.toInt() ?? 0;
    if (stayVersion > 0) {
      rows.add(
        PolicyAcceptanceRow(
          userId: userId,
          serviceType: PolicyApplicableService.accommodation,
          acceptedVersion: stayVersion,
          acceptedAt:
              acceptedAtByService[PolicyApplicableService.accommodation] ??
              (lastService == PolicyApplicableService.daycare
                  ? null
                  : legacyAt),
          docEmail: docEmail,
        ),
      );
    } else if (legacyVersion > 0 &&
        lastService != PolicyApplicableService.daycare &&
        versions[PolicyApplicableService.daycare] == null) {
      rows.add(
        PolicyAcceptanceRow(
          userId: userId,
          serviceType: PolicyApplicableService.accommodation,
          acceptedVersion: legacyVersion,
          acceptedAt: legacyAt,
          docEmail: docEmail,
        ),
      );
    }

    final int daycareVersion =
        (versions[PolicyApplicableService.daycare] as num?)?.toInt() ?? 0;
    if (daycareVersion > 0) {
      rows.add(
        PolicyAcceptanceRow(
          userId: userId,
          serviceType: PolicyApplicableService.daycare,
          acceptedVersion: daycareVersion,
          acceptedAt:
              acceptedAtByService[PolicyApplicableService.daycare] ??
              (lastService == PolicyApplicableService.daycare
                  ? legacyAt
                  : null),
          docEmail: docEmail,
        ),
      );
    } else if (legacyVersion > 0 &&
        lastService == PolicyApplicableService.daycare &&
        versions[PolicyApplicableService.accommodation] == null) {
      rows.add(
        PolicyAcceptanceRow(
          userId: userId,
          serviceType: PolicyApplicableService.daycare,
          acceptedVersion: legacyVersion,
          acceptedAt: legacyAt,
          docEmail: docEmail,
        ),
      );
    }

    return rows.where((PolicyAcceptanceRow row) {
      return row.userId.isNotEmpty && row.acceptedVersion > 0;
    }).toList();
  }
}
