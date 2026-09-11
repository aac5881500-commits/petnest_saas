// 檔案名稱：lib/core/models/daily_care_addon_plan.dart
// 功能說明：寵物寫真與照護回報專用加購方案，獨立於一般加值服務。

import 'daily_care_report_mode.dart';

class DailyCareAddonPlan {
  const DailyCareAddonPlan({
    required this.id,
    this.name = '寵物寫真與照護回報',
    this.description = '',
    this.enabled = true,
    this.applyStay = true,
    this.applyDaycare = true,
    this.extraReports = 1,
    this.extraPhotos = 3,
    this.stayPricePerNight = 0,
    this.daycarePricePerVisit = 0,
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final bool applyStay;
  final bool applyDaycare;
  final int extraReports;
  final int extraPhotos;
  final int stayPricePerNight;
  final int daycarePricePerVisit;

  bool appliesTo(String service) {
    if (service == 'daycare') {
      return applyDaycare;
    }
    return applyStay;
  }

  factory DailyCareAddonPlan.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return DailyCareAddonPlan(id: id);
    }
    final Object? rawServices = map['applicableServices'];
    bool stay = map['applyStay'] != false;
    bool daycare = map['applyDaycare'] != false;
    if (rawServices is List) {
      final List<String> values = rawServices
          .map((Object? item) => item.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList();
      if (values.isNotEmpty) {
        stay = values.contains('accommodation') || values.contains('stay');
        daycare = values.contains('daycare');
      }
    }
    return DailyCareAddonPlan(
      id: id,
      name: (map['name'] ?? '寵物寫真與照護回報').toString().trim().isEmpty
          ? '寵物寫真與照護回報'
          : (map['name'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString(),
      enabled: map['enabled'] != false,
      applyStay: stay,
      applyDaycare: daycare,
      extraReports: _clampReports(map['extraReports']),
      extraPhotos: _clampPhotos(map['extraPhotos']),
      stayPricePerNight: _money(map['stayPricePerNight'] ?? map['stayPrice']),
      daycarePricePerVisit: _money(
        map['daycarePricePerVisit'] ?? map['daycarePrice'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'enabled': enabled,
      'applyStay': applyStay,
      'applyDaycare': applyDaycare,
      'applicableServices': <String>[
        if (applyStay) 'accommodation',
        if (applyDaycare) 'daycare',
      ],
      'extraReports': extraReports,
      'extraPhotos': extraPhotos,
      'stayPricePerNight': stayPricePerNight,
      'daycarePricePerVisit': daycarePricePerVisit,
      'stayChargeUnit': DailyCareReportMode.chargePerNight,
      'daycareChargeUnit': DailyCareReportMode.chargePerVisit,
    };
  }

  static int _clampReports(Object? raw) {
    final int parsed = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
    if (parsed < 0) {
      return 0;
    }
    if (parsed > 3) {
      return 3;
    }
    return parsed;
  }

  static int _clampPhotos(Object? raw) {
    final int parsed = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
    if (parsed < 0) {
      return 0;
    }
    if (parsed > DailyCareReportMode.legacyMaxPhotosPerRoomPerDay) {
      return DailyCareReportMode.legacyMaxPhotosPerRoomPerDay;
    }
    return parsed;
  }

  static int _money(Object? raw) {
    final int parsed = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}
