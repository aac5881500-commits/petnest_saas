// 檔案名稱：lib/core/services/report_range.dart
// 功能說明：報表期間：今天 / 昨天 / 週 / 月 / 近 7、30 天 / 自訂

enum ReportRangeType {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last7,
  last30,
  custom,
}

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
      case ReportRangeType.yesterday:
        return '昨天';
      case ReportRangeType.thisWeek:
        return '本週';
      case ReportRangeType.lastWeek:
        return '上週';
      case ReportRangeType.thisMonth:
        return '本月';
      case ReportRangeType.lastMonth:
        return '上月';
      case ReportRangeType.last7:
        return '近 7 天';
      case ReportRangeType.last30:
        return '近 30 天';
      case ReportRangeType.custom:
        return '自訂日期';
    }
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static ReportRange today() {
    final DateTime now = DateTime.now();
    return ReportRange(
      type: ReportRangeType.today,
      startDate: _dayStart(now),
      endDate: _dayEnd(now),
    );
  }

  static ReportRange yesterday() {
    final DateTime y = _dayStart(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    return ReportRange(
      type: ReportRangeType.yesterday,
      startDate: y,
      endDate: _dayEnd(y),
    );
  }

  static ReportRange thisWeek() {
    final DateTime now = DateTime.now();
    final DateTime start = _dayStart(
      now,
    ).subtract(Duration(days: now.weekday - 1));
    return ReportRange(
      type: ReportRangeType.thisWeek,
      startDate: start,
      endDate: _dayEnd(now),
    );
  }

  static ReportRange lastWeek() {
    final DateTime now = DateTime.now();
    final DateTime thisMonday = _dayStart(
      now,
    ).subtract(Duration(days: now.weekday - 1));
    final DateTime start = thisMonday.subtract(const Duration(days: 7));
    final DateTime end = thisMonday.subtract(const Duration(milliseconds: 1));
    return ReportRange(
      type: ReportRangeType.lastWeek,
      startDate: start,
      endDate: _dayEnd(end),
    );
  }

  static ReportRange thisMonth() {
    final DateTime now = DateTime.now();
    return ReportRange(
      type: ReportRangeType.thisMonth,
      startDate: DateTime(now.year, now.month, 1),
      endDate: _dayEnd(now),
    );
  }

  static ReportRange lastMonth() {
    final DateTime now = DateTime.now();
    final DateTime firstThis = DateTime(now.year, now.month, 1);
    final DateTime lastEnd = firstThis.subtract(
      const Duration(milliseconds: 1),
    );
    return ReportRange(
      type: ReportRangeType.lastMonth,
      startDate: DateTime(lastEnd.year, lastEnd.month, 1),
      endDate: _dayEnd(lastEnd),
    );
  }

  static ReportRange last7() {
    final DateTime now = DateTime.now();
    return ReportRange(
      type: ReportRangeType.last7,
      startDate: _dayStart(now).subtract(const Duration(days: 6)),
      endDate: _dayEnd(now),
    );
  }

  static ReportRange last30() {
    final DateTime now = DateTime.now();
    return ReportRange(
      type: ReportRangeType.last30,
      startDate: _dayStart(now).subtract(const Duration(days: 29)),
      endDate: _dayEnd(now),
    );
  }

  static ReportRange custom({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return ReportRange(
      type: ReportRangeType.custom,
      startDate: _dayStart(startDate),
      endDate: _dayEnd(endDate),
    );
  }
}
