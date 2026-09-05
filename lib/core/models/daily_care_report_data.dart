// 檔案名稱：lib/core/models/daily_care_report_data.dart
// 功能說明：每日照護報告產圖用資料
// 只給報告排版與統計，不寫回 Firestore。

import 'package:flutter/material.dart';

enum DailyCareReportBadgeKind { none, good, yes, no, normal, warn }

enum DailyCareReportExportKind { summary, fullStay, singleDay }

class DailyCareReportField {
  const DailyCareReportField({
    required this.label,
    required this.value,
    required this.badge,
    this.emoji = '',
  });

  final String label;
  final String value;
  final DailyCareReportBadgeKind badge;
  final String emoji;
}

class DailyCareReportGroup {
  const DailyCareReportGroup({required this.title, required this.fields});

  final String title;
  final List<DailyCareReportField> fields;
}

class DailyCareReportSession {
  const DailyCareReportSession({
    required this.sessionName,
    required this.updatedAtText,
    required this.groups,
    this.generalNote = '',
  });

  final String sessionName;
  final String updatedAtText;
  final List<DailyCareReportGroup> groups;
  final String generalNote;
}

class DailyCareReportDay {
  const DailyCareReportDay({
    required this.dateKey,
    required this.dateTitle,
    required this.sessions,
  });

  final String dateKey;
  final String dateTitle;
  final List<DailyCareReportSession> sessions;
}

class DailyCareReportStatOption {
  const DailyCareReportStatOption({
    required this.label,
    required this.count,
    required this.isPrimary,
  });

  final String label;
  final int count;
  final bool isPrimary;
}

class DailyCareReportStatField {
  const DailyCareReportStatField({
    required this.key,
    required this.label,
    required this.inputType,
    required this.options,
    required this.observedCount,
  });

  final String key;
  final String label;
  final String inputType;
  final List<DailyCareReportStatOption> options;
  final int observedCount;

  bool get isYesNo => inputType == 'yesNo';
}

class DailyCareReportStatGroup {
  const DailyCareReportStatGroup({required this.title, required this.fields});

  final String title;
  final List<DailyCareReportStatField> fields;
}

class DailyCareReportOverviewLine {
  const DailyCareReportOverviewLine({
    required this.dateText,
    required this.text,
  });

  final String dateText;
  final String text;
}

class DailyCareReportStats {
  const DailyCareReportStats({
    required this.stayNights,
    required this.expectedSessions,
    required this.completedSessions,
    this.avgTemperature,
    this.minTemperature,
    this.maxTemperature,
    this.avgHumidity,
    this.minHumidity,
    this.maxHumidity,
    this.groups = const <DailyCareReportStatGroup>[],
    this.activityStatus,
    this.overviewLines = const <DailyCareReportOverviewLine>[],
    this.overviewNoteDays = 0,
  });

  final int stayNights;
  final int expectedSessions;
  final int completedSessions;
  final double? avgTemperature;
  final double? minTemperature;
  final double? maxTemperature;
  final double? avgHumidity;
  final double? minHumidity;
  final double? maxHumidity;
  final List<DailyCareReportStatGroup> groups;
  final DailyCareReportStatField? activityStatus;
  final List<DailyCareReportOverviewLine> overviewLines;
  final int overviewNoteDays;

  int get missingSessions {
    if (expectedSessions <= completedSessions) {
      return 0;
    }
    return expectedSessions - completedSessions;
  }

  int get completionPercent {
    if (expectedSessions <= 0) {
      return completedSessions > 0 ? 100 : 0;
    }
    final int raw = ((completedSessions / expectedSessions) * 100).round();
    if (raw > 100) {
      return 100;
    }
    return raw;
  }

  bool get hasEnvironment => avgTemperature != null || avgHumidity != null;
}

class DailyCareReportData {
  const DailyCareReportData({
    required this.shopName,
    required this.shopLogoUrl,
    required this.brandColor,
    required this.title,
    required this.headerDateText,
    required this.roomName,
    required this.roomTypeName,
    required this.petNames,
    required this.checkInText,
    required this.checkOutText,
    required this.nightsText,
    required this.bookingCode,
    required this.days,
    required this.generatedAtText,
    required this.isFullStay,
    this.kind = DailyCareReportExportKind.fullStay,
    this.stats,
  });

  final String shopName;
  final String shopLogoUrl;
  final Color brandColor;
  final String title;
  final String headerDateText;
  final String roomName;
  final String roomTypeName;
  final String petNames;
  final String checkInText;
  final String checkOutText;
  final String nightsText;
  final String bookingCode;
  final List<DailyCareReportDay> days;
  final DailyCareReportStats? stats;
  final String generatedAtText;
  final bool isFullStay;
  final DailyCareReportExportKind kind;
}
