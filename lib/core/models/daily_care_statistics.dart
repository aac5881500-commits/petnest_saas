// 檔案名稱：lib/core/models/daily_care_statistics.dart
// 功能說明：整筆訂單已完成每日回報的前端聚合結果。不寫回 Firestore。

import 'daily_care_setting_model.dart';

class CareCountRatio {
  const CareCountRatio({required this.count, required this.total});

  final int count;
  final int total;

  double get ratio => total <= 0 ? 0 : count / total;

  int get percent {
    if (total <= 0) {
      return 0;
    }
    return (count / total * 100).round();
  }
}

class CareStatusCount {
  const CareStatusCount({required this.label, required this.ratio});

  final String label;
  final CareCountRatio ratio;
}

class CarePetRef {
  const CarePetRef({required this.id, required this.name});

  final String id;
  final String name;

  static List<CarePetRef> fromBooking(Map<String, dynamic> data) {
    final List<CarePetRef> pets = <CarePetRef>[];
    final Object? raw =
        data['pets'] ?? data['petNameSnapshots'] ?? data['petSummaries'];
    if (raw is List) {
      for (final Object? item in raw) {
        final CarePetRef? pet = _one(item);
        if (pet != null) {
          pets.add(pet);
        }
      }
    }
    if (pets.isEmpty) {
      final Object? names = data['petNames'];
      if (names is List) {
        for (final Object? item in names) {
          final CarePetRef? pet = _one(item);
          if (pet != null) {
            pets.add(pet);
          }
        }
      }
    }
    if (pets.isEmpty) {
      final String name = (data['petName'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        pets.add(CarePetRef(id: '', name: name));
      }
    }
    return pets;
  }

  static CarePetRef? _one(Object? raw) {
    if (raw is String) {
      final String name = raw.trim();
      if (name.isEmpty) {
        return null;
      }
      return CarePetRef(id: '', name: name);
    }
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> pet = Map<String, dynamic>.from(raw);
    final String id = (pet['petId'] ?? pet['id'] ?? '').toString().trim();
    final String name = (pet['name'] ?? pet['petName'] ?? '').toString().trim();
    if (id.isEmpty && name.isEmpty) {
      return null;
    }
    return CarePetRef(id: id, name: name.isEmpty ? '毛孩' : name);
  }
}

class CareTimelineSlot {
  const CareTimelineSlot({
    required this.dateKey,
    required this.sessionIndex,
    required this.sessionLabel,
    required this.axisLabel,
    required this.recordId,
  });

  /// yyyy/MM/dd，Asia/Taipei 日曆日。
  final String dateKey;
  final int sessionIndex;
  final String sessionLabel;
  final String axisLabel;
  final String recordId;
}

class CareNoteEntry {
  const CareNoteEntry({
    required this.dateKey,
    required this.sessionLabel,
    required this.heading,
    required this.text,
  });

  final String dateKey;
  final String sessionLabel;
  final String heading;
  final String text;
}

class CareNumericSeries {
  const CareNumericSeries({
    required this.key,
    required this.label,
    required this.unit,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.averageText,
    required this.minimumText,
    required this.maximumText,
    required this.sampleCount,
    required this.points,
  });

  final String key;
  final String label;
  final String unit;
  final double average;
  final double minimum;
  final double maximum;
  final String averageText;
  final String minimumText;
  final String maximumText;
  final int sampleCount;
  final List<double?> points;

  bool get singleSample => sampleCount == 1;
}

class CareEnvironmentStatistics {
  const CareEnvironmentStatistics({
    this.temperature,
    this.humidity,
    required this.footerText,
  });

  final CareNumericSeries? temperature;
  final CareNumericSeries? humidity;
  final String footerText;
}

class CareFieldStatistics {
  const CareFieldStatistics({
    required this.key,
    required this.label,
    required this.inputType,
    required this.total,
    required this.dominant,
    required this.presence,
    required this.distribution,
    required this.timeline,
  });

  final String key;
  final String label;

  /// condition / amount / yesNo。自由文字不進這一層。
  final String inputType;
  final int total;
  final CareStatusCount dominant;

  /// yesNo 為「有」的比例；其餘為主要狀態比例。
  final CareCountRatio presence;
  final List<CareStatusCount> distribution;

  /// 與 [BookingCareStatistics.timeline] 對齊。null 表示該場沒有這個欄位。
  final List<String?> timeline;

  bool get singleSample => total == 1;
  bool get isPresence => inputType == 'yesNo';
}

/// 一整區的平均，不是單一欄位的出現比例。
class CareZoneScore {
  const CareZoneScore({
    required this.percent,
    required this.observationCount,
    required this.sessionCount,
    required this.caption,
    required this.footerText,
    required this.breakdown,
  });

  const CareZoneScore.empty({required this.caption})
    : percent = null,
      observationCount = 0,
      sessionCount = 0,
      footerText = '',
      breakdown = const <CareStatusCount>[];

  /// 四捨五入後的整區百分比。沒有有效資料時為 null，畫面不顯示 0%。
  final int? percent;
  final int observationCount;
  final int sessionCount;
  final String caption;
  final String footerText;
  final List<CareStatusCount> breakdown;

  bool get hasData => percent != null && observationCount > 0;
}

class CareCategoryStatistics {
  const CareCategoryStatistics({
    required this.key,
    required this.title,
    required this.fields,
    required this.footerText,
    required this.zone,
  });

  final String key;
  final String title;
  final List<CareFieldStatistics> fields;
  final String footerText;
  final CareZoneScore zone;
}

class BookingCareStatistics {
  const BookingCareStatistics({
    required this.bookingId,
    required this.petId,
    required this.petName,
    required this.petChoices,
    required this.completedReportCount,
    required this.expectedReportCount,
    required this.periodText,
    required this.progressText,
    required this.progressHint,
    required this.sampleNotice,
    required this.isEmpty,
    required this.environment,
    required this.toilet,
    required this.life,
    required this.activity,
    required this.relax,
    required this.other,
    required this.notes,
    required this.timeline,
  });

  final String bookingId;
  final String? petId;
  final String petName;

  /// 有兩隻以上、且回報能依 petId 分開時才有選項。不含「全部」。
  final List<CarePetRef> petChoices;
  final int completedReportCount;
  final int? expectedReportCount;
  final String periodText;
  final String progressText;
  final String progressHint;
  final String sampleNotice;
  final bool isEmpty;
  final CareEnvironmentStatistics? environment;
  final CareCategoryStatistics? toilet;
  final CareCategoryStatistics? life;
  final CareCategoryStatistics? activity;
  final CareCategoryStatistics? relax;
  final CareCategoryStatistics? other;
  final List<CareNoteEntry> notes;
  final List<CareTimelineSlot> timeline;
}

class DailyCareStatisticsRequest {
  const DailyCareStatisticsRequest({
    required this.bookingId,
    required this.setting,
    required this.pets,
    required this.isDaycare,
    this.entitlementSessionLabels = const <String>[],
    this.sessionsPerDay,
    this.careDayCount,
    this.periodStart,
    this.periodEnd,
  });

  final String bookingId;
  final DailyCareSettingModel setting;
  final List<CarePetRef> pets;
  final bool isDaycare;
  final List<String> entitlementSessionLabels;
  final int? sessionsPerDay;
  final int? careDayCount;
  final DateTime? periodStart;
  final DateTime? periodEnd;
}
