// lib/core/services/daily_care_report_export_service.dart
// 🐾 每日照護報告 PNG 產圖與下載
// 使用獨立 Report Widget + RepaintBoundary，不截 App 畫面。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../models/daily_care_date_helper.dart';
import '../models/daily_care_record_model.dart';
import '../models/daily_care_report_data.dart';
import '../models/daily_care_setting_model.dart';
import '../models/daily_care_stay_info.dart';
import '../models/home_theme_model.dart';
import '../widgets/daily_care_report_view.dart';
import '../widgets/daily_care_summary_report_view.dart';

class DailyCareReportExportService {
  DailyCareReportExportService._();

  static final DailyCareReportExportService instance =
      DailyCareReportExportService._();

  static const double logicalWidth = 540;
  static const double pixelRatio = 2;
  static const Color fallbackBrand = Color(0xFF3D6F9F);

  static const Map<String, String> _builtInLabels = <String, String>{
    'temperature': '室內溫度',
    'humidity': '室內濕度',
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
    'generalNote': '今日概況',
  };

  static const Map<String, String> _emojis = <String, String>{
    'temperature': '🌡',
    'humidity': '💧',
    'water': '💧',
    'dryFood': '🍚',
    'wetFood': '🥫',
    'snack': '🍪',
    'stool': '💩',
    'urine': '💧',
    'wandToy': '🎣',
    'scratchBoard': '🪵',
    'jumpPlatform': '🪜',
    'toyBall': '⚽',
    'catHouse': '🏠',
    'catnip': '🌿',
    'silverVine': '🌿',
    'catGrass': '🌱',
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

  DailyCareReportData buildReport({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> shop,
    required DailyCareStayInfo stay,
    required DailyCareSettingModel setting,
    required List<DailyCareRecordModel> records,
    DateTime? onlyDate,
    DailyCareReportExportKind kind = DailyCareReportExportKind.fullStay,
  }) {
    final DateTime? checkIn = stay.startDate;
    final DateTime? checkOut = stay.endDate;
    final List<String> careKeys = DailyCareDateHelper.careDateKeys(
      checkIn: checkIn,
      checkOut: checkOut,
    );
    final Map<String, List<DailyCareRecordModel>> grouped =
        <String, List<DailyCareRecordModel>>{};
    for (final DailyCareRecordModel record in records) {
      final String key = DailyCareDateHelper.dateKey(
        DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
      );
      if (careKeys.isNotEmpty && !careKeys.contains(key)) {
        continue;
      }
      grouped.putIfAbsent(key, () => <DailyCareRecordModel>[]).add(record);
    }

    List<String> dayKeys = grouped.keys.toList()..sort();
    if (onlyDate != null) {
      final String onlyKey = DailyCareDateHelper.dateKey(onlyDate);
      dayKeys = dayKeys.where((String key) => key == onlyKey).toList();
    }

    final List<DailyCareReportDay> days = <DailyCareReportDay>[];
    for (final String key in dayKeys) {
      final List<DailyCareRecordModel> dayRecords = List<DailyCareRecordModel>.from(
        grouped[key] ?? <DailyCareRecordModel>[],
      )..sort((DailyCareRecordModel a, DailyCareRecordModel b) {
        return a.sessionIndex.compareTo(b.sessionIndex);
      });
      days.add(
        DailyCareReportDay(
          dateKey: key,
          dateTitle: _prettyDateTitle(key),
          sessions: dayRecords
              .map(
                (DailyCareRecordModel record) => _buildSession(record, setting),
              )
              .toList(),
        ),
      );
    }

    final bool isFullStay = onlyDate == null;
    final DailyCareReportExportKind resolvedKind = onlyDate != null
        ? DailyCareReportExportKind.singleDay
        : kind;
    final String shopName = (shop['name'] ?? 'PetNest 店家').toString().trim();
    final Color brand = _brandColor(shop);
    final DateTime now = DailyCareDateHelper.todayInTaipei();
    final DateTime nowLocal = DateTime.now();
    final int stayNights = _stayNights(booking, careKeys);
    final int expectedSessions = (careKeys.isEmpty ? stayNights : careKeys.length) *
        (setting.sessionCount < 1 ? 1 : setting.sessionCount);

    return DailyCareReportData(
      shopName: shopName.isEmpty ? 'PetNest 店家' : shopName,
      shopLogoUrl: (shop['logoUrl'] ?? '').toString().trim(),
      brandColor: brand,
      title: switch (resolvedKind) {
        DailyCareReportExportKind.summary => '住宿照護統計報告',
        DailyCareReportExportKind.fullStay => '完整照護紀錄',
        DailyCareReportExportKind.singleDay => '每日住宿照護報告',
      },
      headerDateText: isFullStay
          ? _stayRangeText(checkIn, checkOut)
          : _prettyDateTitle(DailyCareDateHelper.dateKey(onlyDate)),
      roomName: stay.roomName.isEmpty ? '尚未分房' : stay.roomName,
      roomTypeName: (booking['roomTypeName'] ?? '').toString().trim(),
      petNames: stay.petNamesText,
      checkInText: checkIn == null
          ? ''
          : DailyCareDateHelper.dateKey(
              DailyCareDateHelper.calendarDateInTaipei(checkIn),
            ),
      checkOutText: checkOut == null
          ? ''
          : DailyCareDateHelper.dateKey(
              DailyCareDateHelper.calendarDateInTaipei(checkOut),
            ),
      nightsText: '$stayNights 晚',
      bookingCode: _bookingCode(booking),
      days: days,
      stats: isFullStay
          ? _buildStats(
              records: records.where((DailyCareRecordModel record) {
                if (careKeys.isEmpty) {
                  return true;
                }
                return careKeys.contains(
                  DailyCareDateHelper.dateKey(
                    DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
                  ),
                );
              }).toList(),
              setting: setting,
              stayNights: stayNights,
              expectedSessions: expectedSessions,
            )
          : null,
      generatedAtText:
          '${DailyCareDateHelper.dateKey(now)} '
          '${nowLocal.hour.toString().padLeft(2, '0')}:'
          '${nowLocal.minute.toString().padLeft(2, '0')}',
      isFullStay: isFullStay,
      kind: resolvedKind,
    );
  }

  List<DateTime> recordCareDates({
    required DailyCareStayInfo stay,
    required List<DailyCareRecordModel> records,
  }) {
    final List<String> careKeys = DailyCareDateHelper.careDateKeys(
      checkIn: stay.startDate,
      checkOut: stay.endDate,
    );
    final Set<String> present = <String>{};
    for (final DailyCareRecordModel record in records) {
      present.add(
        DailyCareDateHelper.dateKey(
          DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
        ),
      );
    }
    final Iterable<String> keys = careKeys.isEmpty
        ? (present.toList()..sort())
        : careKeys.where(present.contains);
    return keys.map((String key) {
      final List<String> parts = key.split('/');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList();
  }

  Future<ImageProvider?> preloadLogo(
    BuildContext context,
    String logoUrl,
  ) async {
    final String url = logoUrl.trim();
    if (url.isEmpty) {
      return null;
    }
    try {
      final NetworkImage image = NetworkImage(url);
      await precacheImage(image, context).timeout(const Duration(seconds: 8));
      return image;
    } catch (_) {
      return null;
    }
  }

  Future<void> exportPng({
    required BuildContext context,
    required DailyCareReportData data,
    required ImageProvider? logoProvider,
    required String fileName,
  }) async {
    final Uint8List bytes = await capturePng(
      context: context,
      data: data,
      logoProvider: logoProvider,
    );
    await savePng(bytes: bytes, fileName: fileName);
  }

  Future<Uint8List> capturePng({
    required BuildContext context,
    required DailyCareReportData data,
    required ImageProvider? logoProvider,
  }) async {
    if (data.kind == DailyCareReportExportKind.summary) {
      if (!context.mounted) {
        throw StateError('頁面已關閉');
      }
      final ui.Image image = await _captureSection(
        context: context,
        child: DailyCareSummaryReportView(
          data: data,
          logoProvider: logoProvider,
        ),
      );
      try {
        final ByteData? png = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return png!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }

    final List<ui.Image> slices = <ui.Image>[];
    try {
      if (!context.mounted) {
        throw StateError('頁面已關閉');
      }
      slices.add(
        await _captureSection(
          context: context,
          child: DailyCareReportView(
            data: data,
            logoProvider: logoProvider,
            showFooter: false,
            days: const <DailyCareReportDay>[],
          ),
        ),
      );
      for (final DailyCareReportDay day in data.days) {
        if (!context.mounted) {
          throw StateError('頁面已關閉');
        }
        slices.add(
          await _captureSection(
            context: context,
            child: DailyCareReportView(
              data: data,
              logoProvider: logoProvider,
              showHeader: false,
              showStayInfo: false,
              showFooter: false,
              days: <DailyCareReportDay>[day],
            ),
          ),
        );
      }
      if (!context.mounted) {
        throw StateError('頁面已關閉');
      }
      slices.add(
        await _captureSection(
          context: context,
          child: DailyCareReportView(
            data: data,
            logoProvider: logoProvider,
            showHeader: false,
            showStayInfo: false,
            days: const <DailyCareReportDay>[],
          ),
        ),
      );
      return _stitchPng(slices);
    } finally {
      for (final ui.Image image in slices) {
        image.dispose();
      }
    }
  }

  Future<void> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      final html.Blob blob = html.Blob(<dynamic>[bytes], 'image/png');
      final String objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final html.AnchorElement anchor = html.AnchorElement(href: objectUrl)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(objectUrl);
      return;
    }

    await Share.shareXFiles(
      <XFile>[
        XFile.fromData(bytes, mimeType: 'image/png', name: fileName),
      ],
      text: 'PetNest 照護報告',
    );
  }

  String fileName({
    required DailyCareReportData data,
  }) {
    final String room = _safeName(data.roomName);
    final String pets = _safeName(
      data.petNames == '尚未指定寵物' ? '' : data.petNames,
    );
    if (data.kind == DailyCareReportExportKind.singleDay) {
      final String day = data.headerDateText
          .replaceAll(' ', '')
          .replaceAll('/', '');
      return 'PetNest_每日照護_${room}_${pets}_$day.png';
    }
    final String start = data.checkInText.replaceAll('/', '');
    final String end = data.checkOutText.replaceAll('/', '');
    if (data.kind == DailyCareReportExportKind.summary) {
      return 'PetNest_住宿照護統計_${room}_${pets}_$start-$end.png';
    }
    return 'PetNest_完整照護紀錄_${room}_${pets}_$start-$end.png';
  }

  DailyCareReportSession _buildSession(
    DailyCareRecordModel record,
    DailyCareSettingModel setting,
  ) {
    final Map<String, String> customLabels = <String, String>{
      for (final DailyCareCustomField field in setting.customFields)
        field.id: field.label,
    };
    final Set<String> enabled = setting.enabledFields.toSet();
    final List<DailyCareReportGroup> groups = <DailyCareReportGroup>[];
    final List<DailyCareReportField> env = _fieldsFor(
      record,
      <String>['temperature', 'humidity'],
      enabled,
      customLabels,
      alwaysShowIfFilled: true,
    );
    if (env.isNotEmpty) {
      groups.add(DailyCareReportGroup(title: '環境狀況', fields: env));
    }
    final List<DailyCareReportField> food = _fieldsFor(
      record,
      _foodKeys,
      enabled,
      customLabels,
    );
    if (food.isNotEmpty) {
      groups.add(DailyCareReportGroup(title: '生活狀況', fields: food));
    }
    final List<DailyCareReportField> toilet = _fieldsFor(
      record,
      _toiletKeys,
      enabled,
      customLabels,
    );
    if (toilet.isNotEmpty) {
      groups.add(DailyCareReportGroup(title: '大小便狀況', fields: toilet));
    }
    final List<DailyCareReportField> activity = _fieldsFor(
      record,
      _activityKeys,
      enabled,
      customLabels,
    );
    if (activity.isNotEmpty) {
      groups.add(DailyCareReportGroup(title: '活動與玩樂', fields: activity));
    }
    final List<DailyCareReportField> relax = _fieldsFor(
      record,
      _relaxKeys,
      enabled,
      customLabels,
    );
    if (relax.isNotEmpty) {
      groups.add(DailyCareReportGroup(title: '放鬆與用品', fields: relax));
    }

    final Map<String, List<DailyCareReportField>> customByCategory =
        <String, List<DailyCareReportField>>{};
    for (final DailyCareCustomField field in setting.customFields) {
      final String value = _stringValue(record.values[field.id]);
      if (value.isEmpty || field.label.trim().isEmpty) {
        continue;
      }
      if (field.inputType == 'text') {
        continue;
      }
      customByCategory
          .putIfAbsent(field.category, () => <DailyCareReportField>[])
          .add(
            DailyCareReportField(
              label: field.label.trim(),
              value: value,
              badge: _badgeFor(value, field.inputType),
            ),
          );
    }
    const Map<String, String> categoryTitles = <String, String>{
      'food': '生活狀況',
      'toilet': '大小便狀況',
      'activity': '活動與玩樂',
      'relax': '放鬆與用品',
      'other': '其他紀錄',
    };
    customByCategory.forEach((String category, List<DailyCareReportField> fields) {
      groups.add(
        DailyCareReportGroup(
          title: categoryTitles[category] ?? '其他紀錄',
          fields: fields,
        ),
      );
    });

    String note = _stringValue(record.values['generalNote']);
    for (final DailyCareCustomField field in setting.customFields) {
      if (field.inputType != 'text') {
        continue;
      }
      final String text = _stringValue(record.values[field.id]);
      if (text.isEmpty) {
        continue;
      }
      if (note.isNotEmpty) {
        note = '$note\n${field.label}：$text';
      } else {
        note = text;
      }
    }

    final String sessionName = record.sessionName.trim().isNotEmpty
        ? record.sessionName.trim()
        : setting.sessionLabel(record.sessionIndex);

    return DailyCareReportSession(
      sessionName: sessionName,
      updatedAtText: record.updatedAt == null
          ? ''
          : '${record.updatedAt!.hour.toString().padLeft(2, '0')}:'
                '${record.updatedAt!.minute.toString().padLeft(2, '0')} 更新',
      groups: groups,
      generalNote: note,
    );
  }

  List<DailyCareReportField> _fieldsFor(
    DailyCareRecordModel record,
    List<String> keys,
    Set<String> enabled,
    Map<String, String> customLabels, {
    bool alwaysShowIfFilled = false,
  }) {
    final List<DailyCareReportField> fields = <DailyCareReportField>[];
    for (final String key in keys) {
      if (!alwaysShowIfFilled &&
          !enabled.contains(key) &&
          !customLabels.containsKey(key)) {
        continue;
      }
      final String value = _displayValue(key, record.values[key]);
      if (value.isEmpty) {
        continue;
      }
      final String label = _builtInLabels[key] ?? customLabels[key] ?? '';
      if (label.isEmpty || label.startsWith('custom_')) {
        continue;
      }
      fields.add(
        DailyCareReportField(
          label: label,
          value: value,
          badge: _badgeFor(value, _builtInType(key)),
          emoji: _emojis[key] ?? '',
        ),
      );
    }
    return fields;
  }

  DailyCareReportStats _buildStats({
    required List<DailyCareRecordModel> records,
    required DailyCareSettingModel setting,
    required int stayNights,
    required int expectedSessions,
  }) {
    final List<double> temps = <double>[];
    final List<double> humidities = <double>[];
    final Map<String, Map<String, int>> counts = <String, Map<String, int>>{};
    final Map<String, String> labels = <String, String>{..._builtInLabels};
    final Map<String, String> types = <String, String>{
      for (final String key in <String>[
        ..._foodKeys,
        ..._toiletKeys,
        ..._activityKeys,
        ..._relaxKeys,
      ])
        key: _builtInType(key),
    };
    final Map<String, String> categories = <String, String>{
      for (final String key in _foodKeys) key: 'food',
      for (final String key in _toiletKeys) key: 'toilet',
      for (final String key in _activityKeys) key: 'activity',
      for (final String key in _relaxKeys) key: 'relax',
    };

    for (final DailyCareCustomField field in setting.customFields) {
      if (field.id.trim().isEmpty || field.inputType == 'text') {
        continue;
      }
      labels[field.id] = field.label.trim();
      types[field.id] = field.inputType;
      categories[field.id] = field.category;
    }

    for (final DailyCareRecordModel record in records) {
      final double? temp = _asNumber(record.values['temperature']);
      if (temp != null) {
        temps.add(temp);
      }
      final double? humidity = _asNumber(record.values['humidity']);
      if (humidity != null) {
        humidities.add(humidity);
      }
      record.values.forEach((String key, dynamic raw) {
        if (key == 'temperature' ||
            key == 'humidity' ||
            key == 'generalNote' ||
            key == 'petNotes') {
          return;
        }
        final String type = types[key] ?? _builtInType(key);
        if (type != 'yesNo' && type != 'amount' && type != 'condition') {
          return;
        }
        final String value = _normalizeStatValue(_stringValue(raw), type);
        if (!_isDisplayableStatValue(value)) {
          return;
        }
        counts.putIfAbsent(key, () => <String, int>{});
        counts[key]![value] = (counts[key]![value] ?? 0) + 1;
      });
    }

    DailyCareReportStatField? activityStatus;
    final List<DailyCareReportStatField> food = <DailyCareReportStatField>[];
    final List<DailyCareReportStatField> toilet = <DailyCareReportStatField>[];
    final List<DailyCareReportStatField> activity = <DailyCareReportStatField>[];
    final List<DailyCareReportStatField> relax = <DailyCareReportStatField>[];
    final List<DailyCareReportStatField> other = <DailyCareReportStatField>[];

    final List<String> order = <String>[
      ..._foodKeys,
      ..._toiletKeys,
      ..._activityKeys,
      ..._relaxKeys,
      ...setting.customFields.map((DailyCareCustomField field) => field.id),
    ];
    final Set<String> seen = <String>{};
    for (final String key in order) {
      if (seen.contains(key) || !counts.containsKey(key)) {
        continue;
      }
      seen.add(key);
      final String label = labels[key] ?? '';
      if (!_isDisplayableStatLabel(label)) {
        continue;
      }
      final String type = types[key] ?? _builtInType(key);
      final DailyCareReportStatField field = _statFieldFromCounts(
        key: key,
        label: label,
        inputType: type,
        rawCounts: counts[key]!,
      );
      if (_isActivityStatusField(key, label)) {
        activityStatus = field;
        continue;
      }
      switch (categories[key]) {
        case 'food':
          food.add(field);
        case 'toilet':
          toilet.add(field);
        case 'activity':
          activity.add(field);
        case 'relax':
          relax.add(field);
        default:
          other.add(field);
      }
    }

    final List<DailyCareReportStatGroup> groups = <DailyCareReportStatGroup>[];
    void addGroup(String title, List<DailyCareReportStatField> fields) {
      if (fields.isNotEmpty) {
        groups.add(DailyCareReportStatGroup(title: title, fields: fields));
      }
    }

    addGroup('生活狀況', food);
    addGroup('大小便', toilet);
    addGroup('活動與玩樂', activity);
    addGroup('放鬆與用品', relax);
    addGroup('其他紀錄', other);

    return DailyCareReportStats(
      stayNights: stayNights < 1 ? 1 : stayNights,
      expectedSessions: expectedSessions < 1 ? records.length : expectedSessions,
      completedSessions: records.length,
      avgTemperature: _average(temps),
      minTemperature: _min(temps),
      maxTemperature: _max(temps),
      avgHumidity: _average(humidities),
      minHumidity: _min(humidities),
      maxHumidity: _max(humidities),
      groups: groups,
      activityStatus: activityStatus,
      overviewLines: _shortOverviewLines(records),
      overviewNoteDays: _overviewNoteDays(records),
    );
  }

  DailyCareReportStatField _statFieldFromCounts({
    required String key,
    required String label,
    required String inputType,
    required Map<String, int> rawCounts,
  }) {
    final List<String> scale = _scaleFor(inputType);
    final Set<String> seen = <String>{};
    final List<DailyCareReportStatOption> options = <DailyCareReportStatOption>[];
    int observed = 0;
    int maxCount = 0;

    for (final String option in scale) {
      final int count = rawCounts[option] ?? 0;
      observed += count;
      if (count > maxCount) {
        maxCount = count;
      }
      seen.add(option);
      options.add(
        DailyCareReportStatOption(
          label: option,
          count: count,
          isPrimary: false,
        ),
      );
    }
    rawCounts.forEach((String value, int count) {
      if (seen.contains(value) || !_isDisplayableStatValue(value)) {
        return;
      }
      observed += count;
      if (count > maxCount) {
        maxCount = count;
      }
      options.add(
        DailyCareReportStatOption(
          label: value,
          count: count,
          isPrimary: false,
        ),
      );
    });

    return DailyCareReportStatField(
      key: key,
      label: label,
      inputType: inputType,
      observedCount: observed,
      options: options
          .map(
            (DailyCareReportStatOption option) => DailyCareReportStatOption(
              label: option.label,
              count: option.count,
              isPrimary: maxCount > 0 && option.count == maxCount,
            ),
          )
          .toList(),
    );
  }

  List<String> _scaleFor(String inputType) {
    switch (inputType) {
      case 'yesNo':
        return const <String>['無', '有'];
      case 'amount':
        return const <String>['無', '少', '一般', '多'];
      case 'condition':
        return const <String>['無', '正常', '偏少', '偏多', '異常'];
      default:
        return const <String>[];
    }
  }

  String _normalizeStatValue(String raw, String inputType) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    final String lower = value.toLowerCase();
    if (lower == 'null' || lower == 'unknown' || lower.startsWith('custom_')) {
      return '';
    }

    const Map<String, String> shared = <String, String>{
      'none': '無',
      'no': '無',
      'yes': '有',
      'little': '少',
      'few': '少',
      'less': '少',
      'general': '一般',
      'normal': '正常',
      'much': '多',
      'many': '多',
      'more': '多',
      'abnormal': '異常',
    };
    if (shared.containsKey(lower)) {
      final String mapped = shared[lower]!;
      if (inputType == 'amount' && mapped == '正常') {
        return '一般';
      }
      if (inputType == 'yesNo' && (mapped == '少' || mapped == '一般' || mapped == '多')) {
        return mapped == '無' ? '無' : '有';
      }
      return mapped;
    }
    return value;
  }

  bool _isDisplayableStatValue(String value) {
    final String text = value.trim();
    if (text.isEmpty) {
      return false;
    }
    final String lower = text.toLowerCase();
    if (lower == 'null' || lower == 'unknown') {
      return false;
    }
    if (lower.startsWith('custom_')) {
      return false;
    }
    return true;
  }

  bool _isDisplayableStatLabel(String label) {
    final String text = label.trim();
    if (text.isEmpty) {
      return false;
    }
    return !text.toLowerCase().startsWith('custom_');
  }

  bool _isActivityStatusField(String key, String label) {
    final String normalizedKey = key.trim().toLowerCase();
    final String normalizedLabel = label.trim();
    return normalizedKey == 'activitystatus' ||
        normalizedKey == 'activity_status' ||
        normalizedLabel == '活動力' ||
        normalizedLabel == '活動狀態';
  }

  List<DailyCareReportOverviewLine> _shortOverviewLines(
    List<DailyCareRecordModel> records,
  ) {
    final Map<String, String> firstNotes = <String, String>{};
    final List<DailyCareRecordModel> sorted = List<DailyCareRecordModel>.from(
      records,
    )..sort((DailyCareRecordModel a, DailyCareRecordModel b) {
      final int byDate = a.recordDate.compareTo(b.recordDate);
      if (byDate != 0) {
        return byDate;
      }
      return a.sessionIndex.compareTo(b.sessionIndex);
    });

    for (final DailyCareRecordModel record in sorted) {
      final String note = _stringValue(record.values['generalNote']);
      if (note.isEmpty) {
        continue;
      }
      final String key = DailyCareDateHelper.dateKey(
        DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
      );
      firstNotes.putIfAbsent(key, () => note);
    }
    if (firstNotes.isEmpty) {
      return const <DailyCareReportOverviewLine>[];
    }

    const int maxChars = 18;
    for (final String note in firstNotes.values) {
      if (note.contains('\n') || note.trim().length > maxChars) {
        return const <DailyCareReportOverviewLine>[];
      }
    }

    final List<String> keys = firstNotes.keys.toList()..sort();
    return keys
        .map(
          (String key) => DailyCareReportOverviewLine(
            dateText: _shortMonthDay(key),
            text: firstNotes[key]!.trim(),
          ),
        )
        .toList();
  }

  int _overviewNoteDays(List<DailyCareRecordModel> records) {
    final Set<String> days = <String>{};
    for (final DailyCareRecordModel record in records) {
      if (_stringValue(record.values['generalNote']).isEmpty) {
        continue;
      }
      days.add(
        DailyCareDateHelper.dateKey(
          DailyCareDateHelper.calendarDateInTaipei(record.recordDate),
        ),
      );
    }
    return days.length;
  }

  String _shortMonthDay(String dateKey) {
    final DateTime? date = DailyCareDateHelper.parseDateKey(dateKey);
    if (date == null) {
      return dateKey;
    }
    return '${date.month}/${date.day}';
  }

  double? _average(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  double? _min(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a < b ? a : b);
  }

  double? _max(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a > b ? a : b);
  }

  Future<ui.Image> _captureSection({
    required BuildContext context,
    required Widget child,
  }) async {
    final GlobalKey key = GlobalKey();
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Positioned(
          left: -12000,
          top: 0,
          child: Material(
            color: Colors.transparent,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Theme(
              data: Theme.of(context),
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(logicalWidth, 20000),
                  textScaler: TextScaler.linear(1),
                ),
                child: SizedBox(
                  width: logicalWidth,
                  child: RepaintBoundary(key: key, child: child),
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    entry.remove();
    return image;
  }

  Future<Uint8List> _stitchPng(List<ui.Image> slices) async {
    if (slices.isEmpty) {
      throw StateError('沒有可輸出的報告內容');
    }
    if (slices.length == 1) {
      final ByteData? data = await slices.first.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data!.buffer.asUint8List();
    }

    int width = 0;
    int height = 0;
    for (final ui.Image image in slices) {
      if (image.width > width) {
        width = image.width;
      }
      height += image.height;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    double y = 0;
    for (final ui.Image image in slices) {
      canvas.drawImage(image, Offset(0, y), Paint());
      y += image.height;
    }
    final ui.Image combined = await recorder.endRecording().toImage(
      width,
      height,
    );
    try {
      final ByteData? data = await combined.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data!.buffer.asUint8List();
    } finally {
      combined.dispose();
    }
  }

  Color _brandColor(Map<String, dynamic> shop) {
    try {
      final Object? rawHome = shop['homeAppearance'];
      if (rawHome is Map) {
        final Object? modern = rawHome['modern'];
        if (modern is Map) {
          final HomeThemeModel theme = HomeThemeModel.fromMap(
            modern['themeColors'],
            fallback: HomeThemeModel.modernDefault,
          );
          return theme.primaryColor;
        }
      }
    } catch (_) {}
    return fallbackBrand;
  }

  String _bookingCode(Map<String, dynamic> booking) {
    final String code = (booking['bookingCode'] ?? '').toString().trim();
    if (code.contains('-')) {
      return code.split('-').last;
    }
    return code;
  }

  int _stayNights(Map<String, dynamic> booking, List<String> careKeys) {
    final Object? nights = booking['nights'];
    if (nights is num && nights.toInt() > 0) {
      return nights.toInt();
    }
    if (careKeys.isNotEmpty) {
      return careKeys.length;
    }
    return 1;
  }

  String _stayRangeText(DateTime? checkIn, DateTime? checkOut) {
    if (checkIn == null || checkOut == null) {
      return '';
    }
    return '${DailyCareDateHelper.dateKey(DailyCareDateHelper.calendarDateInTaipei(checkIn))}  ～  '
        '${DailyCareDateHelper.dateKey(DailyCareDateHelper.calendarDateInTaipei(checkOut))}';
  }

  String _prettyDateTitle(String dateKey) {
    return dateKey.replaceAll('/', ' / ');
  }

  String _displayValue(String key, Object? value) {
    if (key == 'temperature') {
      final double? number = _asNumber(value);
      return number == null ? '' : '${_cleanNumber(number)}°C';
    }
    if (key == 'humidity') {
      final double? number = _asNumber(value);
      return number == null ? '' : '${_cleanNumber(number)}%';
    }
    return _stringValue(value);
  }

  String _stringValue(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  double? _asNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  String _cleanNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _builtInType(String key) {
    if (key == 'water' || key == 'dryFood' || key == 'wetFood') {
      return 'amount';
    }
    if (_toiletKeys.contains(key)) {
      return 'condition';
    }
    if (key == 'snack' ||
        _activityKeys.contains(key) ||
        _relaxKeys.contains(key)) {
      return 'yesNo';
    }
    return '';
  }

  DailyCareReportBadgeKind _badgeFor(String value, String inputType) {
    if (value.contains('異常') ||
        value.contains('注意') ||
        value.contains('偏少') ||
        value.contains('偏多')) {
      return DailyCareReportBadgeKind.warn;
    }
    if (value == '有' || value == '多') {
      return DailyCareReportBadgeKind.yes;
    }
    if (value == '無') {
      return DailyCareReportBadgeKind.no;
    }
    if (value == '正常') {
      return DailyCareReportBadgeKind.good;
    }
    if (value == '一般' || value == '少') {
      return DailyCareReportBadgeKind.normal;
    }
    if (inputType == 'text') {
      return DailyCareReportBadgeKind.none;
    }
    return DailyCareReportBadgeKind.normal;
  }

  String _safeName(String value) {
    final String cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll('、', '')
        .replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return '照護';
    }
    return cleaned;
  }
}
