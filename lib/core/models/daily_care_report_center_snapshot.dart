// 檔案名稱：lib/core/models/daily_care_report_center_snapshot.dart
// 功能說明：每日回報中心即時快照與統計。

import 'daily_care_date_helper.dart';
import 'daily_care_report_center_item.dart';

enum DailyCareReportCenterStatusFilter { all, pending, completed }

enum DailyCareReportCenterTypeFilter { all, stay, daycare }

class DailyCareReportCenterSnapshot {
  const DailyCareReportCenterSnapshot({
    this.items = const <DailyCareReportCenterItem>[],
    this.settingEnabled = false,
    this.hasError = false,
    this.errorMessage = '',
  });

  final List<DailyCareReportCenterItem> items;
  final bool settingEnabled;
  final bool hasError;
  final String errorMessage;

  int get pendingCount =>
      items.where((DailyCareReportCenterItem item) => !item.isCompleted).length;

  int get completedCount =>
      items.where((DailyCareReportCenterItem item) => item.isCompleted).length;

  int get totalCount => items.length;

  int get stayCount =>
      items.where((DailyCareReportCenterItem item) => !item.isDaycare).length;

  int get daycareCount =>
      items.where((DailyCareReportCenterItem item) => item.isDaycare).length;

  List<DailyCareReportCenterItem> filtered({
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
    DailyCareReportCenterTypeFilter type = DailyCareReportCenterTypeFilter.all,
    String query = '',
  }) {
    final String needle = query.trim().toLowerCase();
    return items.where((DailyCareReportCenterItem item) {
      final bool typeOk = switch (type) {
        DailyCareReportCenterTypeFilter.all => true,
        DailyCareReportCenterTypeFilter.stay => !item.isDaycare,
        DailyCareReportCenterTypeFilter.daycare => item.isDaycare,
      };
      if (!typeOk) {
        return false;
      }
      final bool statusOk = switch (status) {
        DailyCareReportCenterStatusFilter.all => true,
        DailyCareReportCenterStatusFilter.pending => !item.isCompleted,
        DailyCareReportCenterStatusFilter.completed => item.isCompleted,
      };
      if (!statusOk) {
        return false;
      }
      return needle.isEmpty || item.matchesQuery(needle);
    }).toList();
  }

  static const DailyCareReportCenterSnapshot empty =
      DailyCareReportCenterSnapshot();

  static const DailyCareReportCenterSnapshot error =
      DailyCareReportCenterSnapshot(
        hasError: true,
        errorMessage: '目前無法取得每日回報，請稍後再試',
      );

  static DailyCareReportCenterSnapshot fromItems(
    List<DailyCareReportCenterItem> raw, {
    bool settingEnabled = true,
  }) {
    final List<DailyCareReportCenterItem> items =
        List<DailyCareReportCenterItem>.from(raw)..sort(_compare);
    return DailyCareReportCenterSnapshot(
      items: items,
      settingEnabled: settingEnabled,
    );
  }

  static int _compare(
    DailyCareReportCenterItem a,
    DailyCareReportCenterItem b,
  ) {
    final int completed = (a.isCompleted ? 1 : 0).compareTo(
      b.isCompleted ? 1 : 0,
    );
    if (completed != 0) {
      return completed;
    }
    final int date = DailyCareDateHelper.dateOnly(
      a.recordDate,
    ).compareTo(DailyCareDateHelper.dateOnly(b.recordDate));
    if (date != 0) {
      return date;
    }
    final int booking = a.bookingId.compareTo(b.bookingId);
    if (booking != 0) {
      return booking;
    }
    return a.sessionIndex.compareTo(b.sessionIndex);
  }
}
