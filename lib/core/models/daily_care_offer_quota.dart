// 檔案名稱：lib/core/models/daily_care_offer_quota.dart
// 功能說明：房型或安親方案的回報場次與名稱（不含照片張數）。

import 'daily_care_report_mode.dart';

class DailyCareOfferQuota {
  const DailyCareOfferQuota({
    this.configured = true,
    this.reports = 1,
    this.sessionLabels = const <String>[],
  });

  final bool configured;
  final int reports;
  final List<String> sessionLabels;

  List<String> resolvedLabels() {
    return DailyCareReportMode.padLabels(sessionLabels, reports);
  }

  factory DailyCareOfferQuota.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCareOfferQuota(configured: false, reports: 0);
    }
    return DailyCareOfferQuota(
      configured: map['configured'] != false,
      reports: DailyCareReportMode.clampReports(map['reports'], 1),
      sessionLabels: DailyCareReportMode.readLabels(
        map['sessionLabels'] ?? map['labels'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'configured': configured,
      'reports': reports,
      'sessionLabels': DailyCareReportMode.padLabels(sessionLabels, reports),
    };
  }

  static Map<String, DailyCareOfferQuota> mapFrom(Object? raw) {
    if (raw is! Map) {
      return <String, DailyCareOfferQuota>{};
    }
    final Map<String, DailyCareOfferQuota> out =
        <String, DailyCareOfferQuota>{};
    raw.forEach((Object? key, Object? value) {
      final String id = key.toString().trim();
      if (id.isEmpty) {
        return;
      }
      if (value is Map) {
        out[id] = DailyCareOfferQuota.fromMap(Map<String, dynamic>.from(value));
      }
    });
    return out;
  }

  static Map<String, Map<String, dynamic>> mapToFirestore(
    Map<String, DailyCareOfferQuota> value,
  ) {
    return value.map(
      (String key, DailyCareOfferQuota quota) =>
          MapEntry<String, Map<String, dynamic>>(key, quota.toMap()),
    );
  }
}
