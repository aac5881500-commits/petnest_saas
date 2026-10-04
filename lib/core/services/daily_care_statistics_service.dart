// 檔案名稱：lib/core/services/daily_care_statistics_service.dart
// 功能說明：把一筆 booking 已完成的每日回報聚合成照護統計。只讀既有紀錄，不寫 Firestore。

import '../models/booking_kind.dart';
import '../models/daily_care_date_helper.dart';
import '../models/daily_care_entitlement.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_statistics.dart';
import '../models/daily_care_stay_info.dart';
import 'daily_care_daycare_access.dart';

class DailyCareStatisticsScope {
  const DailyCareStatisticsScope({
    required this.request,
    required this.careDates,
    required this.sessionCount,
  });

  final DailyCareStatisticsRequest request;
  final List<DateTime> careDates;
  final int sessionCount;

  static DailyCareStatisticsScope fromBooking({
    required String bookingId,
    required Map<String, dynamic> booking,
    required DailyCareSettingModel setting,
  }) {
    final bool daycare = BookingKind.isDaycare(booking);
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    final List<DateTime> careDates = <DateTime>[];
    if (daycare) {
      final DateTime? day = DailyCareDaycareAccess.serviceCalendarDate(booking);
      if (day != null) {
        careDates.add(DailyCareDateHelper.dateOnly(day));
      }
    } else {
      for (final String key in stay.careDateKeys()) {
        final DateTime? day = DailyCareDateHelper.parseDateKey(key);
        if (day != null) {
          careDates.add(day);
        }
      }
    }
    final bool hasSnapshot = booking['dailyCareEntitlement'] is Map;
    final DailyCareEntitlement entitlement = DailyCareEntitlement.fromMap(
      hasSnapshot
          ? Map<String, dynamic>.from(booking['dailyCareEntitlement'] as Map)
          : null,
    );
    final int sessionCount =
        DailyCareEntitlement.hasExplicitFinalReports(booking)
        ? entitlement.finalReports
        : (daycare ? setting.daycareSessionCount : setting.sessionCount);
    final DateTime? periodStart = daycare
        ? (careDates.isEmpty ? null : careDates.first)
        : stay.startDate;
    final DateTime? periodEnd = daycare
        ? (careDates.isEmpty ? null : careDates.first)
        : stay.endDate;
    return DailyCareStatisticsScope(
      careDates: careDates,
      sessionCount: sessionCount < 1 ? 1 : sessionCount,
      request: DailyCareStatisticsRequest(
        bookingId: bookingId,
        setting: setting,
        pets: CarePetRef.fromBooking(booking),
        isDaycare: daycare,
        entitlementSessionLabels: entitlement.sessionLabels,
        sessionsPerDay: sessionCount < 1 ? null : sessionCount,
        careDayCount: careDates.isEmpty ? null : careDates.length,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ),
    );
  }
}

/// 區塊分數。未填、空白、無法辨識的值回傳 null，不當成 0 分。
class DailyCareZoneScore {
  DailyCareZoneScore._();

  static int? pointsOf(String? value) {
    switch ((value ?? '').trim()) {
      case '正常':
      case '一般':
      case '有':
        return 100;
      case '偏少':
      case '偏多':
      case '少':
      case '多':
        return 70;
      case '異常':
      case '無':
        return 0;
      default:
        return null;
    }
  }

  /// 與整區平均相同：只加總有效分數，再四捨五入。空集合不是 0 分。
  static int? averagePercent(int sum, int count) {
    if (count <= 0) {
      return null;
    }
    return (sum / count).round();
  }

  static int? percentOfValues(Iterable<String?> values) {
    int sum = 0;
    int count = 0;
    for (final String? value in values) {
      final int? points = pointsOf(value);
      if (points == null) {
        continue;
      }
      sum += points;
      count += 1;
    }
    return averagePercent(sum, count);
  }

  /// 與上一場相比。差距未滿 5 分不標升降。沒有上一場或這一區沒分數則不標。
  static String? changeMark({required int? current, required int? previous}) {
    if (current == null || previous == null) {
      return null;
    }
    final int delta = current - previous;
    if (delta >= 5) {
      return '↑';
    }
    if (delta <= -5) {
      return '↓';
    }
    return '→';
  }

  static String captionFor(String categoryKey) {
    switch (categoryKey) {
      case 'activity':
        return '活動參與';
      case 'relax':
        return '使用比例';
      default:
        return '整體狀況';
    }
  }
}

class DailyCareStatisticsService {
  DailyCareStatisticsService._();

  static const List<String> _conditionOrder = <String>['正常', '偏少', '偏多', '異常'];
  static const List<String> _amountOrder = <String>['無', '少', '一般', '多'];
  static const List<String> _yesNoOrder = <String>['有', '無'];

  static const Map<String, String> _labels = <String, String>{
    'water': '飲水',
    'dryFood': '飼料',
    'wetFood': '罐頭',
    'snack': '零食',
    'stool': '大便',
    'urine': '尿尿',
    'wandToy': '逗貓棒',
    'scratchBoard': '貓抓板',
    'jumpPlatform': '貓跳台',
    'toyBall': '玩具球',
    'catHouse': '貓屋',
    'catnip': '貓薄荷',
    'silverVine': '木天蓼',
    'catGrass': '貓草',
    'temperature': '溫度',
    'humidity': '濕度',
  };

  static const List<String> _foodKeys = <String>[
    'water',
    'dryFood',
    'wetFood',
    'snack',
  ];
  static const List<String> _toiletKeys = <String>['stool', 'urine'];
  static const List<String> _activityKeys = <String>[
    'wandToy',
    'scratchBoard',
    'jumpPlatform',
    'toyBall',
    'catHouse',
  ];
  static const List<String> _relaxKeys = <String>[
    'catnip',
    'silverVine',
    'catGrass',
  ];

  static const Map<String, String> _aliases = <String, String>{
    'normal': '正常',
    'less': '偏少',
    'more': '偏多',
    'abnormal': '異常',
    'yes': '有',
    'no': '無',
    'general': '一般',
    'much': '多',
    'little': '少',
    'none': '無',
  };

  static BookingCareStatistics build({
    required DailyCareStatisticsRequest request,
    required List<DailyCareRecordModel> records,
    String? selectedPetId,
  }) {
    final List<DailyCareRecordModel> completed = _completedRecords(
      records,
      bookingId: request.bookingId,
    );
    final List<CarePetRef> choices = _petChoices(request.pets, completed);
    final String? petId = _selectedPet(choices, selectedPetId);
    final List<DailyCareRecordModel> scoped = petId == null
        ? completed
        : completed
              .where((DailyCareRecordModel record) => _applies(record, petId))
              .toList();
    final bool petPartial = petId != null && scoped.length != completed.length;
    final int? expected = petPartial ? null : _expected(request);
    final List<_Slot> slots = scoped.map(_slotFor(request)).toList();
    final CareEnvironmentStatistics? environment = _environment(slots);
    final Map<String, CareCategoryStatistics> categories = _categories(
      request: request,
      slots: slots,
    );
    final List<CareNoteEntry> notes = _notes(
      request: request,
      slots: slots,
      petId: petId,
    );
    final int count = scoped.length;
    return BookingCareStatistics(
      bookingId: request.bookingId,
      petId: petId,
      petName: _petName(request.pets, petId),
      petChoices: choices,
      completedReportCount: count,
      expectedReportCount: expected,
      periodText: _period(request, slots),
      progressText: _progressText(count, expected),
      progressHint: _progressHint(count, expected),
      sampleNotice: _sampleNotice(count),
      isEmpty: count == 0,
      environment: environment,
      toilet: categories['toilet'],
      life: categories['food'],
      activity: categories['activity'],
      relax: categories['relax'],
      other: categories['other'],
      notes: notes,
      timeline: slots
          .map(
            (_Slot slot) => CareTimelineSlot(
              dateKey: slot.dateKey,
              sessionIndex: slot.sessionIndex,
              sessionLabel: slot.sessionLabel,
              axisLabel: slot.axisLabel,
              recordId: slot.record.id,
            ),
          )
          .toList(),
    );
  }

  static List<DailyCareRecordModel> _completedRecords(
    List<DailyCareRecordModel> records, {
    required String bookingId,
  }) {
    final Map<String, DailyCareRecordModel> unique =
        <String, DailyCareRecordModel>{};
    for (final DailyCareRecordModel record in records) {
      if (record.bookingId.trim() != bookingId.trim()) {
        continue;
      }
      if (!_isCompletedReport(record)) {
        continue;
      }
      final String id = record.id.trim().isEmpty
          ? '${record.bookingId}#${_dateKeyOf(record)}#${record.sessionIndex}'
          : record.id.trim();
      final DailyCareRecordModel? previous = unique[id];
      if (previous == null || _newer(record, previous)) {
        unique[id] = record;
      }
    }
    final List<DailyCareRecordModel> list = unique.values.toList();
    list.sort((DailyCareRecordModel a, DailyCareRecordModel b) {
      final int dateCompare = _dateKeyOf(a).compareTo(_dateKeyOf(b));
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.sessionIndex.compareTo(b.sessionIndex);
    });
    return list;
  }

  static bool _isCompletedReport(DailyCareRecordModel record) {
    final String status = record.reportStatus.trim().toLowerCase();
    if (status == 'draft' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'void') {
      return false;
    }
    return record.countsAsCompleted;
  }

  static bool _newer(DailyCareRecordModel next, DailyCareRecordModel previous) {
    final DateTime? a = next.completedAt ?? next.updatedAt;
    final DateTime? b = previous.completedAt ?? previous.updatedAt;
    if (a == null) {
      return false;
    }
    if (b == null) {
      return true;
    }
    return a.isAfter(b);
  }

  static List<CarePetRef> _petChoices(
    List<CarePetRef> pets,
    List<DailyCareRecordModel> completed,
  ) {
    if (pets.length < 2) {
      return const <CarePetRef>[];
    }
    if (pets.any((CarePetRef pet) => pet.id.isEmpty)) {
      return const <CarePetRef>[];
    }
    final Set<String> ids = pets.map((CarePetRef pet) => pet.id).toSet();
    if (ids.length < pets.length) {
      return const <CarePetRef>[];
    }
    final bool distinguishable = completed.any((DailyCareRecordModel record) {
      if (record.petIds.isEmpty) {
        return false;
      }
      return !ids.every(record.petIds.contains);
    });
    if (!distinguishable) {
      return const <CarePetRef>[];
    }
    return pets;
  }

  static String? _selectedPet(List<CarePetRef> choices, String? selectedPetId) {
    if (choices.isEmpty) {
      return null;
    }
    final String wanted = (selectedPetId ?? '').trim();
    for (final CarePetRef pet in choices) {
      if (pet.id == wanted) {
        return pet.id;
      }
    }
    return choices.first.id;
  }

  static bool _applies(DailyCareRecordModel record, String petId) {
    if (record.petIds.isEmpty) {
      return true;
    }
    return record.petIds.contains(petId);
  }

  static int? _expected(DailyCareStatisticsRequest request) {
    final int? days = request.careDayCount;
    final int? sessions = request.sessionsPerDay;
    if (days == null || sessions == null || days < 1 || sessions < 1) {
      return null;
    }
    return days * sessions;
  }

  static String _petName(List<CarePetRef> pets, String? petId) {
    if (petId != null) {
      for (final CarePetRef pet in pets) {
        if (pet.id == petId) {
          return pet.name;
        }
      }
    }
    final List<String> names = pets
        .map((CarePetRef pet) => pet.name.trim())
        .where((String name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      return '尚未指定寵物';
    }
    return names.join('、');
  }

  static _Slot Function(DailyCareRecordModel) _slotFor(
    DailyCareStatisticsRequest request,
  ) {
    return (DailyCareRecordModel record) {
      final DateTime day = _careDay(record);
      final String sessionLabel = _sessionLabel(request, record);
      return _Slot(
        record: record,
        day: day,
        dateKey: DailyCareDateHelper.dateKey(day),
        sessionIndex: record.sessionIndex,
        sessionLabel: sessionLabel,
        axisLabel: _axisLabel(day, sessionLabel, record.sessionIndex),
      );
    };
  }

  static DateTime _careDay(DailyCareRecordModel record) {
    return DailyCareDateHelper.calendarDateInTaipei(record.recordDate);
  }

  static String _dateKeyOf(DailyCareRecordModel record) {
    return DailyCareDateHelper.dateKey(_careDay(record));
  }

  static String _sessionLabel(
    DailyCareStatisticsRequest request,
    DailyCareRecordModel record,
  ) {
    final String snapshot = record.sessionName.trim();
    if (snapshot.isNotEmpty) {
      return snapshot;
    }
    final List<String> labels = request.entitlementSessionLabels;
    if (record.sessionIndex >= 0 && record.sessionIndex < labels.length) {
      final String stored = labels[record.sessionIndex].trim();
      if (stored.isNotEmpty) {
        return stored;
      }
    }
    return request.isDaycare
        ? request.setting.daycareSessionLabelAt(record.sessionIndex)
        : request.setting.sessionLabelAt(record.sessionIndex);
  }

  static String _axisLabel(DateTime day, String sessionLabel, int index) {
    return '${day.month}/${day.day}${_shortSession(sessionLabel, index)}';
  }

  static String _shortSession(String label, int index) {
    if (label.contains('上午') || label.contains('早上') || label == '早') {
      return '早';
    }
    if (label.contains('中午') || label.contains('下午') || label == '中') {
      return '中';
    }
    if (label.contains('晚上') || label.contains('夜間') || label == '晚') {
      return '晚';
    }
    final String trimmed = label.trim();
    if (trimmed.isNotEmpty && trimmed.length <= 2) {
      return trimmed;
    }
    return '${index + 1}';
  }

  static String _period(DailyCareStatisticsRequest request, List<_Slot> slots) {
    if (request.periodStart != null || request.periodEnd != null) {
      final String start = request.periodStart == null
          ? ''
          : DailyCareDateHelper.dateKey(
              DailyCareDateHelper.calendarDateInTaipei(request.periodStart!),
            );
      final String end = request.periodEnd == null
          ? ''
          : DailyCareDateHelper.dateKey(
              DailyCareDateHelper.calendarDateInTaipei(request.periodEnd!),
            );
      if (start.isNotEmpty && end.isNotEmpty) {
        return start == end ? start : '$start ～ $end';
      }
      return start.isNotEmpty ? start : end;
    }
    if (slots.isEmpty) {
      return '';
    }
    final String first = slots.first.dateKey;
    final String last = slots.last.dateKey;
    return first == last ? first : '$first ～ $last';
  }

  static String _progressText(int count, int? expected) {
    if (expected == null) {
      return '目前已完成 $count 場回報';
    }
    return '回報進度：$count / $expected 場';
  }

  static String _progressHint(int count, int? expected) {
    if (count <= 0) {
      return '';
    }
    if (expected != null && count >= expected) {
      return '本次照護回報已完成';
    }
    if (expected != null) {
      return '統計會隨每日回報完成持續更新';
    }
    return '';
  }

  static String _sampleNotice(int count) {
    if (count == 1) {
      return '目前僅 1 場紀錄，統計會隨後續回報更新';
    }
    if (count == 2) {
      return '目前依 2 場已完成回報統計';
    }
    return '';
  }

  static CareEnvironmentStatistics? _environment(List<_Slot> slots) {
    final CareNumericSeries? temperature = _series(
      slots,
      key: 'temperature',
      label: '溫度',
      unit: '°C',
    );
    final CareNumericSeries? humidity = _series(
      slots,
      key: 'humidity',
      label: '濕度',
      unit: '%',
    );
    if (temperature == null && humidity == null) {
      return null;
    }
    final int tempCount = temperature?.sampleCount ?? 0;
    final int humidCount = humidity?.sampleCount ?? 0;
    final String footer;
    if (temperature != null && humidity != null && tempCount != humidCount) {
      footer = '溫度 $tempCount 場・濕度 $humidCount 場';
    } else {
      final int count = tempCount > humidCount ? tempCount : humidCount;
      footer = '統計 $count 場紀錄';
    }
    return CareEnvironmentStatistics(
      temperature: temperature,
      humidity: humidity,
      footerText: footer,
    );
  }

  static CareNumericSeries? _series(
    List<_Slot> slots, {
    required String key,
    required String label,
    required String unit,
  }) {
    final List<double?> points = <double?>[];
    final List<double> samples = <double>[];
    for (final _Slot slot in slots) {
      final double? value = _number(slot.record.values[key]);
      points.add(value);
      if (value != null) {
        samples.add(value);
      }
    }
    if (samples.isEmpty) {
      return null;
    }
    double sum = 0;
    double min = samples.first;
    double max = samples.first;
    for (final double value in samples) {
      sum += value;
      if (value < min) {
        min = value;
      }
      if (value > max) {
        max = value;
      }
    }
    final double average = sum / samples.length;
    return CareNumericSeries(
      key: key,
      label: label,
      unit: unit,
      average: average,
      minimum: min,
      maximum: max,
      averageText: _formatNumber(average),
      minimumText: _formatNumber(min),
      maximumText: _formatNumber(max),
      sampleCount: samples.length,
      points: points,
    );
  }

  static double? _number(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is Map || raw is Iterable) {
      return null;
    }
    final String text = raw.toString().trim().replaceAll(',', '');
    if (text.isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }

  static String _formatNumber(double value) {
    final double rounded = (value * 10).round() / 10;
    if ((rounded - rounded.roundToDouble()).abs() < 0.001) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  static Map<String, CareCategoryStatistics> _categories({
    required DailyCareStatisticsRequest request,
    required List<_Slot> slots,
  }) {
    final Map<String, DailyCareCustomField> custom =
        <String, DailyCareCustomField>{
          for (final DailyCareCustomField field in request.setting.customFields)
            if (field.id.trim().isNotEmpty) field.id: field,
        };
    final Map<String, List<String?>> samples = <String, List<String?>>{};
    for (final _Slot slot in slots) {
      final Set<String> keys = slot.record.values.keys
          .map((dynamic key) => key.toString())
          .toSet();
      for (final String key in keys) {
        if (_skippedKey(key)) {
          continue;
        }
        samples.putIfAbsent(
          key,
          () => List<String?>.filled(slots.length, null),
        );
      }
    }
    for (int index = 0; index < slots.length; index++) {
      final Map<String, dynamic> values = slots[index].record.values;
      for (final String key in samples.keys) {
        samples[key]![index] = _statusText(values[key]);
      }
    }
    final Map<String, List<String>> grouped = <String, List<String>>{
      'toilet': <String>[],
      'food': <String>[],
      'activity': <String>[],
      'relax': <String>[],
      'other': <String>[],
    };
    final List<String> ordered = samples.keys.toList()
      ..sort((String a, String b) => _fieldOrder(a).compareTo(_fieldOrder(b)));
    for (final String key in ordered) {
      final String type = _inputType(key, samples[key]!, custom[key]);
      if (type == 'text' ||
          type == 'number' ||
          type == 'temperature' ||
          type == 'humidity') {
        continue;
      }
      if (samples[key]!.every((String? value) => value == null)) {
        continue;
      }
      grouped[_categoryOf(key, custom[key])]!.add(key);
    }
    final Map<String, CareCategoryStatistics> result =
        <String, CareCategoryStatistics>{};
    const Map<String, String> titles = <String, String>{
      'toilet': '大小便狀況',
      'food': '生活狀況',
      'activity': '活動與玩樂',
      'relax': '放鬆與用品',
      'other': '其他紀錄',
    };
    for (final MapEntry<String, List<String>> entry in grouped.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final List<CareFieldStatistics> fields = entry.value
          .map(
            (String key) => _field(
              key: key,
              label: _labelOf(key, custom[key]),
              inputType: _inputType(key, samples[key]!, custom[key]),
              raw: samples[key]!,
            ),
          )
          .whereType<CareFieldStatistics>()
          .toList();
      if (fields.isEmpty) {
        continue;
      }
      final CareZoneScore zone = _zoneScore(entry.key, fields);
      result[entry.key] = CareCategoryStatistics(
        key: entry.key,
        title: titles[entry.key] ?? entry.key,
        fields: fields,
        footerText: zone.footerText,
        zone: zone,
      );
    }
    if (slots.isNotEmpty) {
      for (final String key in <String>[
        'toilet',
        'food',
        'activity',
        'relax',
      ]) {
        result.putIfAbsent(
          key,
          () => CareCategoryStatistics(
            key: key,
            title: titles[key] ?? key,
            fields: const <CareFieldStatistics>[],
            footerText: '',
            zone: CareZoneScore.empty(
              caption: DailyCareZoneScore.captionFor(key),
            ),
          ),
        );
      }
    }
    return result;
  }

  /// 同一區所有有效狀態直接相加再平均，不先算單場再平均。
  static CareZoneScore _zoneScore(
    String categoryKey,
    List<CareFieldStatistics> fields,
  ) {
    final String caption = DailyCareZoneScore.captionFor(categoryKey);
    int sum = 0;
    int observations = 0;
    int sessions = 0;
    final Map<String, int> counts = <String, int>{};
    final int slotCount = fields.fold<int>(0, (
      int maxLength,
      CareFieldStatistics field,
    ) {
      return field.timeline.length > maxLength
          ? field.timeline.length
          : maxLength;
    });
    for (int index = 0; index < slotCount; index++) {
      bool sessionHit = false;
      for (final CareFieldStatistics field in fields) {
        final String? raw = index < field.timeline.length
            ? field.timeline[index]
            : null;
        final int? points = DailyCareZoneScore.pointsOf(raw);
        if (points == null) {
          continue;
        }
        final String label = raw!;
        sum += points;
        observations += 1;
        counts[label] = (counts[label] ?? 0) + 1;
        sessionHit = true;
      }
      if (sessionHit) {
        sessions += 1;
      }
    }
    if (observations == 0) {
      return CareZoneScore.empty(caption: caption);
    }
    final int? percent = DailyCareZoneScore.averagePercent(sum, observations);
    if (percent == null) {
      return CareZoneScore.empty(caption: caption);
    }
    final bool presence = categoryKey == 'activity' || categoryKey == 'relax';
    final String unit = presence ? '有效紀錄' : '有效狀態';
    final List<String> order = presence
        ? <String>['有', '無']
        : <String>['正常', '偏少', '偏多', '異常'];
    for (final String label in counts.keys) {
      if (!order.contains(label)) {
        order.add(label);
      }
    }
    return CareZoneScore(
      percent: percent,
      observationCount: observations,
      sessionCount: sessions,
      caption: caption,
      footerText: '依 $sessions 場回報、$observations 筆$unit計算',
      breakdown: order
          .map(
            (String label) => CareStatusCount(
              label: label,
              ratio: CareCountRatio(
                count: counts[label] ?? 0,
                total: observations,
              ),
            ),
          )
          .toList(),
    );
  }

  static bool _skippedKey(String key) {
    return key == 'generalNote' || key == 'petNotes' || key == 'photos';
  }

  static int _fieldOrder(String key) {
    const List<String> order = <String>[
      'stool',
      'urine',
      'water',
      'dryFood',
      'wetFood',
      'snack',
      'wandToy',
      'scratchBoard',
      'jumpPlatform',
      'toyBall',
      'catHouse',
      'catnip',
      'silverVine',
      'catGrass',
    ];
    final int index = order.indexOf(key);
    return index < 0 ? 1000 : index;
  }

  static String _categoryOf(String key, DailyCareCustomField? custom) {
    if (custom != null) {
      switch (custom.category) {
        case 'toilet':
        case 'food':
        case 'activity':
        case 'relax':
          return custom.category;
        default:
          return 'other';
      }
    }
    if (_toiletKeys.contains(key) || DailyCareReportFormat.isAlwaysOn(key)) {
      return 'toilet';
    }
    if (_foodKeys.contains(key)) {
      return 'food';
    }
    if (_activityKeys.contains(key)) {
      return 'activity';
    }
    if (_relaxKeys.contains(key)) {
      return 'relax';
    }
    return 'other';
  }

  static String _labelOf(String key, DailyCareCustomField? custom) {
    final String customLabel = custom?.label.trim() ?? '';
    if (customLabel.isNotEmpty) {
      return customLabel;
    }
    return _labels[key] ?? key;
  }

  static String _inputType(
    String key,
    List<String?> samples,
    DailyCareCustomField? custom,
  ) {
    if (key == 'temperature' || key == 'humidity') {
      return key;
    }
    if (custom != null && custom.inputType.trim().isNotEmpty) {
      return custom.inputType.trim();
    }
    if (_knownBuiltIn(key)) {
      return DailyCareReportFormat.builtInInputType(key);
    }
    final List<String> present = samples.whereType<String>().toList();
    if (present.isEmpty) {
      return 'text';
    }
    if (present.every(_conditionOrder.contains)) {
      return DailyCareReportFormat.condition;
    }
    if (present.every(_amountOrder.contains)) {
      return DailyCareReportFormat.amount;
    }
    if (present.every(_yesNoOrder.contains)) {
      return DailyCareReportFormat.yesNo;
    }
    if (present.every(
      (String value) => _number(value) != null && !_looksLikeStatus(value),
    )) {
      return 'number';
    }
    return DailyCareReportFormat.text;
  }

  static bool _knownBuiltIn(String key) {
    return _labels.containsKey(key) ||
        key == 'generalNote' ||
        key == 'petNotes';
  }

  static bool _looksLikeStatus(String value) {
    return _conditionOrder.contains(value) ||
        _amountOrder.contains(value) ||
        _yesNoOrder.contains(value);
  }

  static String? _statusText(Object? raw) {
    if (raw == null || raw is Map || raw is Iterable) {
      return null;
    }
    final String text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return _aliases[text.toLowerCase()] ?? text;
  }

  static CareFieldStatistics? _field({
    required String key,
    required String label,
    required String inputType,
    required List<String?> raw,
  }) {
    final List<String> present = raw.whereType<String>().toList();
    if (present.isEmpty) {
      return null;
    }
    final Map<String, int> counts = <String, int>{};
    for (final String value in present) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final int total = present.length;
    final List<String> order = _orderOf(inputType, counts.keys);
    final List<CareStatusCount> distribution = order
        .map(
          (String status) => CareStatusCount(
            label: status,
            ratio: CareCountRatio(count: counts[status] ?? 0, total: total),
          ),
        )
        .toList();
    final List<CareStatusCount> ranked = distribution.toList()
      ..sort((CareStatusCount a, CareStatusCount b) {
        final int byCount = b.ratio.count.compareTo(a.ratio.count);
        if (byCount != 0) {
          return byCount;
        }
        return order.indexOf(a.label).compareTo(order.indexOf(b.label));
      });
    final CareStatusCount dominant = ranked.first;
    final int yesCount = counts['有'] ?? 0;
    final CareCountRatio presence = inputType == DailyCareReportFormat.yesNo
        ? CareCountRatio(count: yesCount, total: total)
        : dominant.ratio;
    return CareFieldStatistics(
      key: key,
      label: label,
      inputType: inputType,
      total: total,
      dominant: dominant,
      presence: presence,
      distribution: distribution,
      timeline: raw,
    );
  }

  static List<String> _orderOf(String inputType, Iterable<String> present) {
    final List<String> canonical;
    switch (inputType) {
      case DailyCareReportFormat.amount:
        canonical = _amountOrder;
      case DailyCareReportFormat.yesNo:
        canonical = _yesNoOrder;
      case DailyCareReportFormat.condition:
        canonical = _conditionOrder;
      default:
        canonical = present.toList()..sort();
    }
    final List<String> order = List<String>.from(canonical);
    final List<String> extras =
        present.where((String status) => !order.contains(status)).toList()
          ..sort();
    order.addAll(extras);
    return order;
  }

  static List<CareNoteEntry> _notes({
    required DailyCareStatisticsRequest request,
    required List<_Slot> slots,
    required String? petId,
  }) {
    final Map<String, String> petNames = <String, String>{
      for (final CarePetRef pet in request.pets)
        if (pet.id.isNotEmpty) pet.id: pet.name,
    };
    final List<CareNoteEntry> notes = <CareNoteEntry>[];
    for (final _Slot slot in slots) {
      final String general =
          _statusText(slot.record.values['generalNote']) ?? '';
      if (general.isNotEmpty) {
        notes.add(
          CareNoteEntry(
            dateKey: slot.dateKey,
            sessionLabel: slot.sessionLabel,
            heading: _noteHeading(slot),
            text: general,
          ),
        );
      }
      slot.record.petNotes.forEach((String id, String value) {
        final String text = value.trim();
        if (text.isEmpty) {
          return;
        }
        if (petId != null && id != petId) {
          return;
        }
        final String prefix = petId != null ? '' : (petNames[id] ?? '').trim();
        notes.add(
          CareNoteEntry(
            dateKey: slot.dateKey,
            sessionLabel: slot.sessionLabel,
            heading: _noteHeading(slot),
            text: prefix.isEmpty ? text : '$prefix：$text',
          ),
        );
      });
      for (final DailyCareCustomField field in request.setting.customFields) {
        if (field.inputType != DailyCareReportFormat.text) {
          continue;
        }
        final String text = _statusText(slot.record.values[field.id]) ?? '';
        if (text.isEmpty) {
          continue;
        }
        final String label = field.label.trim().isEmpty
            ? field.id
            : field.label.trim();
        notes.add(
          CareNoteEntry(
            dateKey: slot.dateKey,
            sessionLabel: slot.sessionLabel,
            heading: _noteHeading(slot),
            text: '$label：$text',
          ),
        );
      }
    }
    return notes;
  }

  static String _noteHeading(_Slot slot) {
    return '${slot.day.month}/${slot.day.day} ${slot.sessionLabel}';
  }
}

class _Slot {
  const _Slot({
    required this.record,
    required this.day,
    required this.dateKey,
    required this.sessionIndex,
    required this.sessionLabel,
    required this.axisLabel,
  });

  final DailyCareRecordModel record;
  final DateTime day;
  final String dateKey;
  final int sessionIndex;
  final String sessionLabel;
  final String axisLabel;
}
