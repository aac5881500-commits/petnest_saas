// 檔案名稱：lib/core/models/daily_care_report_center_date_group.dart
// 功能說明：每日回報中心依日期再依訂單分組。

import 'daily_care_date_helper.dart';
import 'daily_care_report_center_item.dart';
import 'daily_care_report_center_snapshot.dart';

class DailyCareReportCenterBookingDayGroup {
  const DailyCareReportCenterBookingDayGroup({required this.sessions});

  final List<DailyCareReportCenterItem> sessions;

  DailyCareReportCenterItem get primary => sessions.first;

  String get bookingId => primary.bookingId;

  String get expandKey =>
      '${DailyCareDateHelper.dateKey(primary.recordDate)}#$bookingId';

  int get pendingCount => sessions
      .where((DailyCareReportCenterItem item) => !item.isCompleted)
      .length;

  int get completedCount => sessions
      .where((DailyCareReportCenterItem item) => item.isCompleted)
      .length;

  int get totalCount => sessions.length;

  bool get hasPending => pendingCount > 0;

  bool get allCompleted => totalCount > 0 && pendingCount == 0;
}

class DailyCareReportCenterDateGroup {
  const DailyCareReportCenterDateGroup({
    required this.date,
    required this.bookings,
  });

  final DateTime date;
  final List<DailyCareReportCenterBookingDayGroup> bookings;

  String get heading => DailyCareReportCenterItem.dateHeadingOf(date);

  int get pendingCount => bookings.fold<int>(
    0,
    (int sum, DailyCareReportCenterBookingDayGroup group) =>
        sum + group.pendingCount,
  );

  int get completedCount => bookings.fold<int>(
    0,
    (int sum, DailyCareReportCenterBookingDayGroup group) =>
        sum + group.completedCount,
  );

  int get totalCount => bookings.fold<int>(
    0,
    (int sum, DailyCareReportCenterBookingDayGroup group) =>
        sum + group.totalCount,
  );

  String get title {
    if (pendingCount > 0 && completedCount > 0) {
      return '$heading  待填 $pendingCount 場・已完成 $completedCount 場';
    }
    if (pendingCount > 0) {
      return '$heading  待填 $pendingCount 場';
    }
    return '$heading  已完成 $completedCount 場';
  }

  List<DailyCareReportCenterItem> get sessions => bookings
      .expand((DailyCareReportCenterBookingDayGroup group) => group.sessions)
      .toList();
}

class DailyCareReportCenterDateGrouping {
  DailyCareReportCenterDateGrouping._();

  static List<DailyCareReportCenterDateGroup> visible({
    required List<DailyCareReportCenterItem> items,
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
    DailyCareReportCenterTypeFilter type = DailyCareReportCenterTypeFilter.all,
    String query = '',
  }) {
    final String needle = query.trim().toLowerCase();
    final List<DailyCareReportCenterItem> typed = items.where((
      DailyCareReportCenterItem item,
    ) {
      final bool typeOk = switch (type) {
        DailyCareReportCenterTypeFilter.all => true,
        DailyCareReportCenterTypeFilter.stay => !item.isDaycare,
        DailyCareReportCenterTypeFilter.daycare => item.isDaycare,
      };
      return typeOk && item.matchesQuery(needle);
    }).toList();

    final Map<String, List<DailyCareReportCenterItem>> byDate =
        <String, List<DailyCareReportCenterItem>>{};
    for (final DailyCareReportCenterItem item in typed) {
      byDate
          .putIfAbsent(
            DailyCareDateHelper.dateKey(item.recordDate),
            () => <DailyCareReportCenterItem>[],
          )
          .add(item);
    }
    final List<String> dateKeys = byDate.keys.toList()..sort();
    final List<DailyCareReportCenterDateGroup> groups =
        <DailyCareReportCenterDateGroup>[];
    for (final String dateKey in dateKeys) {
      final DateTime date =
          DailyCareDateHelper.parseDateKey(dateKey) ?? DateTime(1970);
      final Map<String, List<DailyCareReportCenterItem>> byBooking =
          <String, List<DailyCareReportCenterItem>>{};
      for (final DailyCareReportCenterItem item in byDate[dateKey]!) {
        byBooking
            .putIfAbsent(item.bookingId, () => <DailyCareReportCenterItem>[])
            .add(item);
      }
      final List<DailyCareReportCenterBookingDayGroup> bookings =
          <DailyCareReportCenterBookingDayGroup>[];
      for (final List<DailyCareReportCenterItem> sessions in byBooking.values) {
        sessions.sort(
          (DailyCareReportCenterItem a, DailyCareReportCenterItem b) =>
              a.sessionIndex.compareTo(b.sessionIndex),
        );
        final DailyCareReportCenterBookingDayGroup group =
            DailyCareReportCenterBookingDayGroup(sessions: sessions);
        final bool keep = switch (status) {
          DailyCareReportCenterStatusFilter.pending => group.hasPending,
          DailyCareReportCenterStatusFilter.completed =>
            group.completedCount > 0,
          DailyCareReportCenterStatusFilter.all => true,
        };
        if (keep) {
          bookings.add(group);
        }
      }
      bookings.sort((
        DailyCareReportCenterBookingDayGroup a,
        DailyCareReportCenterBookingDayGroup b,
      ) {
        final int pending = (a.hasPending ? 0 : 1).compareTo(
          b.hasPending ? 0 : 1,
        );
        if (pending != 0) {
          return pending;
        }
        final int code = a.primary.bookingCode.compareTo(b.primary.bookingCode);
        if (code != 0) {
          return code;
        }
        return a.bookingId.compareTo(b.bookingId);
      });
      if (bookings.isNotEmpty) {
        groups.add(
          DailyCareReportCenterDateGroup(date: date, bookings: bookings),
        );
      }
    }
    if (status == DailyCareReportCenterStatusFilter.all) {
      final List<DailyCareReportCenterDateGroup> pendingDates = groups
          .where(
            (DailyCareReportCenterDateGroup group) => group.pendingCount > 0,
          )
          .toList();
      final List<DailyCareReportCenterDateGroup> doneDates = groups
          .where(
            (DailyCareReportCenterDateGroup group) => group.pendingCount == 0,
          )
          .toList();
      return <DailyCareReportCenterDateGroup>[...pendingDates, ...doneDates];
    }
    return groups;
  }
}
