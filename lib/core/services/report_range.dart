// lib/core/services/report_range.dart
// 📅 報表期間工具
// 功能：提供今天、本週、本月、今年、自訂期間的日期範圍

enum ReportRangeType { today, thisWeek, thisMonth, thisYear, custom }

class ReportRange {
  const ReportRange({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  final ReportRangeType type;
  final DateTime startDate;
  final DateTime endDate;

  String get label {
    switch (type) {
      case ReportRangeType.today:
        return '今天';
      case ReportRangeType.thisWeek:
        return '本週';
      case ReportRangeType.thisMonth:
        return '本月';
      case ReportRangeType.thisYear:
        return '今年';
      case ReportRangeType.custom:
        return '自訂';
    }
  }

  static ReportRange today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return ReportRange(
      type: ReportRangeType.today,
      startDate: start,
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static ReportRange thisWeek() {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return ReportRange(
      type: ReportRangeType.thisWeek,
      startDate: start,
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static ReportRange thisMonth() {
    final now = DateTime.now();

    return ReportRange(
      type: ReportRangeType.thisMonth,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static ReportRange thisYear() {
    final now = DateTime.now();

    return ReportRange(
      type: ReportRangeType.thisYear,
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  static ReportRange custom({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return ReportRange(
      type: ReportRangeType.custom,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
    );
  }
}
