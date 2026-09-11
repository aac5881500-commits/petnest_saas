// 檔案名稱：lib/core/models/daily_care_paid_plan.dart
// 功能說明：住宿／安親各自一份付費回報方案（不再共用加購清單）。

import 'daily_care_report_mode.dart';

class DailyCarePaidPlan {
  const DailyCarePaidPlan({
    this.name = '寵物寫真與照護回報',
    this.description = '',
    this.chargeUnit = DailyCareReportMode.chargePerServiceDay,
    this.price = 0,
    this.reports = 1,
    this.sessionLabels = const <String>[],
  });

  final String name;
  final String description;
  final String chargeUnit;
  final int price;
  final int reports;
  final List<String> sessionLabels;

  factory DailyCarePaidPlan.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCarePaidPlan();
    }
    return DailyCarePaidPlan(
      name: _name(map['name']),
      description: (map['description'] ?? '').toString(),
      chargeUnit: DailyCareReportMode.normalizeChargeUnit(
        map['chargeUnit']?.toString(),
      ),
      price: _money(map['price']),
      reports: DailyCareReportMode.clampReports(map['reports'], 1),
      sessionLabels: DailyCareReportMode.readLabels(map['sessionLabels']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'chargeUnit': chargeUnit,
      'price': price,
      'reports': reports,
      'sessionLabels': DailyCareReportMode.padLabels(sessionLabels, reports),
    };
  }

  List<String> resolvedLabels() {
    return DailyCareReportMode.padLabels(sessionLabels, reports);
  }

  DailyCarePaidPlan copyWith({
    String? name,
    String? description,
    String? chargeUnit,
    int? price,
    int? reports,
    List<String>? sessionLabels,
  }) {
    return DailyCarePaidPlan(
      name: name ?? this.name,
      description: description ?? this.description,
      chargeUnit: chargeUnit ?? this.chargeUnit,
      price: price ?? this.price,
      reports: reports ?? this.reports,
      sessionLabels: sessionLabels ?? this.sessionLabels,
    );
  }

  static String _name(Object? raw) {
    final String text = (raw ?? '').toString().trim();
    return text.isEmpty ? '寵物寫真與照護回報' : text;
  }

  static int _money(Object? raw) {
    final int parsed = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}
