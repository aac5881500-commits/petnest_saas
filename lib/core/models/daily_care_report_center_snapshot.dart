// 檔案名稱：lib/core/models/daily_care_report_center_snapshot.dart
// 功能說明：每日回報中心即時快照與統計。

import 'daily_care_record_model.dart';
import 'daily_care_report_center_item.dart';

enum DailyCareReportCenterStatusFilter { all, pending, completed }

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

  List<DailyCareReportCenterItem> filtered({
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
  }) {
    return items.where((DailyCareReportCenterItem item) {
      return switch (status) {
        DailyCareReportCenterStatusFilter.all => true,
        DailyCareReportCenterStatusFilter.pending => !item.isCompleted,
        DailyCareReportCenterStatusFilter.completed => item.isCompleted,
      };
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
    final int type = _typeRank(
      a.serviceType,
    ).compareTo(_typeRank(b.serviceType));
    if (type != 0) {
      return type;
    }
    final int booking = a.bookingId.compareTo(b.bookingId);
    if (booking != 0) {
      return booking;
    }
    return a.sessionIndex.compareTo(b.sessionIndex);
  }

  static int _typeRank(String serviceType) {
    return serviceType == DailyCareServiceTypes.daycare ? 1 : 0;
  }
}
