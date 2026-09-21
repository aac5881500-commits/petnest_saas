// 檔案名稱：lib/core/models/daily_care_report_center_room_group.dart
// 功能說明：將同一訂單／房間的多個回報場次組成一張房間看板卡，可供測試。

import 'daily_care_report_center_item.dart';
import 'daily_care_report_center_snapshot.dart';

class DailyCareReportCenterRoomGroup {
  const DailyCareReportCenterRoomGroup({required this.sessions});

  final List<DailyCareReportCenterItem> sessions;

  DailyCareReportCenterItem get primary => sessions.first;

  String get bookingId => primary.bookingId;

  int get pendingCount => sessions
      .where((DailyCareReportCenterItem item) => !item.isCompleted)
      .length;

  int get completedCount => sessions
      .where((DailyCareReportCenterItem item) => item.isCompleted)
      .length;

  int get totalCount => sessions.length;

  bool get hasPending => pendingCount > 0;

  bool get allCompleted => totalCount > 0 && pendingCount == 0;

  DailyCareReportCenterItem? get nextPending {
    for (final DailyCareReportCenterItem item in sessions) {
      if (!item.isCompleted) {
        return item;
      }
    }
    return null;
  }

  DateTime? get lastCompletedAt {
    DateTime? latest;
    for (final DailyCareReportCenterItem item in sessions) {
      if (!item.isCompleted || item.updatedAt == null) {
        continue;
      }
      if (latest == null || item.updatedAt!.isAfter(latest)) {
        latest = item.updatedAt;
      }
    }
    return latest;
  }

  String get primaryActionLabel {
    if (!hasPending) {
      return '查看／修改';
    }
    return pendingCount == 1 ? '立即填寫' : '填寫下一場';
  }

  DailyCareReportCenterItem get primaryActionSession {
    return nextPending ?? sessions.last;
  }
}

class DailyCareReportCenterGrouping {
  DailyCareReportCenterGrouping._();

  static List<DailyCareReportCenterRoomGroup> groupByBooking(
    List<DailyCareReportCenterItem> items,
  ) {
    final Map<String, List<DailyCareReportCenterItem>> buckets =
        <String, List<DailyCareReportCenterItem>>{};
    for (final DailyCareReportCenterItem item in items) {
      buckets
          .putIfAbsent(item.bookingId, () => <DailyCareReportCenterItem>[])
          .add(item);
    }
    final List<DailyCareReportCenterRoomGroup> groups =
        <DailyCareReportCenterRoomGroup>[];
    for (final List<DailyCareReportCenterItem> sessions in buckets.values) {
      sessions.sort(
        (DailyCareReportCenterItem a, DailyCareReportCenterItem b) =>
            a.sessionIndex.compareTo(b.sessionIndex),
      );
      groups.add(DailyCareReportCenterRoomGroup(sessions: sessions));
    }
    return groups;
  }

  static List<DailyCareReportCenterRoomGroup> visible({
    required List<DailyCareReportCenterItem> items,
    DailyCareReportCenterStatusFilter status =
        DailyCareReportCenterStatusFilter.pending,
    DailyCareReportCenterTypeFilter type = DailyCareReportCenterTypeFilter.all,
  }) {
    final List<DailyCareReportCenterItem> typed = items.where((
      DailyCareReportCenterItem item,
    ) {
      return switch (type) {
        DailyCareReportCenterTypeFilter.all => true,
        DailyCareReportCenterTypeFilter.accommodation => !item.isDaycare,
        DailyCareReportCenterTypeFilter.daycare => item.isDaycare,
      };
    }).toList();
    final List<DailyCareReportCenterRoomGroup> groups = groupByBooking(typed)
      ..sort(compareGroups);
    return groups.where((DailyCareReportCenterRoomGroup group) {
      return switch (status) {
        DailyCareReportCenterStatusFilter.all => true,
        DailyCareReportCenterStatusFilter.pending => group.hasPending,
        DailyCareReportCenterStatusFilter.completed => group.allCompleted,
      };
    }).toList();
  }

  static int compareGroups(
    DailyCareReportCenterRoomGroup a,
    DailyCareReportCenterRoomGroup b,
  ) {
    final int pendingRank = (a.hasPending ? 0 : 1).compareTo(
      b.hasPending ? 0 : 1,
    );
    if (pendingRank != 0) {
      return pendingRank;
    }
    if (a.hasPending && b.hasPending) {
      final int morePending = b.pendingCount.compareTo(a.pendingCount);
      if (morePending != 0) {
        return morePending;
      }
    }
    final int type = (a.primary.isDaycare ? 1 : 0).compareTo(
      b.primary.isDaycare ? 1 : 0,
    );
    if (type != 0) {
      return type;
    }
    if (!a.primary.isDaycare) {
      final int room = naturalCompare(a.primary.roomName, b.primary.roomName);
      if (room != 0) {
        return room;
      }
    } else {
      final DateTime aStart =
          a.primary.daycareStartAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bStart =
          b.primary.daycareStartAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final int time = aStart.compareTo(bStart);
      if (time != 0) {
        return time;
      }
      final int customer = a.primary.customerName.compareTo(
        b.primary.customerName,
      );
      if (customer != 0) {
        return customer;
      }
    }
    return a.bookingId.compareTo(b.bookingId);
  }

  static int naturalCompare(String left, String right) {
    final List<String> a = _chunks(left);
    final List<String> b = _chunks(right);
    final int n = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      final String ca = a[i];
      final String cb = b[i];
      final int? na = int.tryParse(ca);
      final int? nb = int.tryParse(cb);
      if (na != null && nb != null) {
        final int compared = na.compareTo(nb);
        if (compared != 0) {
          return compared;
        }
      } else {
        final int compared = ca.toLowerCase().compareTo(cb.toLowerCase());
        if (compared != 0) {
          return compared;
        }
      }
    }
    return a.length.compareTo(b.length);
  }

  static List<String> _chunks(String value) {
    final List<String> out = <String>[];
    final StringBuffer buffer = StringBuffer();
    bool? digit;
    for (final int code in value.runes) {
      final bool isDigit = code >= 48 && code <= 57;
      if (digit != null && digit != isDigit) {
        out.add(buffer.toString());
        buffer.clear();
      }
      digit = isDigit;
      buffer.writeCharCode(code);
    }
    if (buffer.isNotEmpty) {
      out.add(buffer.toString());
    }
    return out;
  }
}
