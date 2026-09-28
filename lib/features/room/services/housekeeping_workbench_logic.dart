// 檔案名稱：lib/features/room/services/housekeeping_workbench_logic.dart
// 功能說明：現場巡房工作台的篩選、排序與下一筆選取。不寫入 Firestore。

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/services/daycare_occupancy_service.dart';
import '../../../core/utils/natural_sort.dart';
import '../models/housekeeping_workbench_task.dart';

class HousekeepingWorkbenchLogic {
  const HousekeepingWorkbenchLogic._();

  static const double desktopMinWidth = 1100;

  static bool showsDesktopWorkbench({
    required double width,
    required bool reportsEnabled,
    required bool splitSelected,
  }) {
    return reportsEnabled && splitSelected && width >= desktopMinWidth;
  }

  static HousekeepingWorkbenchBoard build({
    required List<HousekeepingRoomInput> rooms,
    required List<HousekeepingBookingMark> bookings,
    required List<DailyCareReportCenterItem> items,
    required HousekeepingWorkbenchFilter filter,
    required DateTime today,
    required DateTime selectedDate,
  }) {
    final DateTime todayOnly = DailyCareDateHelper.dateOnly(today);
    final DateTime selectedOnly = DailyCareDateHelper.dateOnly(selectedDate);
    final List<HousekeepingWorkbenchTask> tasks = <HousekeepingWorkbenchTask>[
      ..._reportTasks(items, todayOnly),
      ..._roomTasks(
        rooms: rooms,
        bookings: bookings,
        items: items,
        today: todayOnly,
        selectedDate: selectedOnly,
      ),
    ]..sort(_compareTasks);

    final List<HousekeepingWorkbenchTask> visible = tasks
        .where((HousekeepingWorkbenchTask task) => _visible(task, filter))
        .toList();
    HousekeepingWorkbenchTask? next;
    for (final HousekeepingWorkbenchTask task in tasks) {
      if (_visible(task, HousekeepingWorkbenchFilter.todo)) {
        next = task;
        break;
      }
    }
    return HousekeepingWorkbenchBoard(
      tasks: tasks,
      visible: visible,
      pendingReportCount: tasks
          .where(
            (HousekeepingWorkbenchTask task) =>
                task.rank == HousekeepingWorkbenchRank.overdueReport ||
                task.rank == HousekeepingWorkbenchRank.todayReport,
          )
          .length,
      pendingHousekeepingCount: tasks
          .where(
            (HousekeepingWorkbenchTask task) =>
                task.rank == HousekeepingWorkbenchRank.housekeeping ||
                task.rank == HousekeepingWorkbenchRank.arrivalDeparture,
          )
          .length,
      checkedInCount: tasks
          .where(
            (HousekeepingWorkbenchTask task) =>
                task.kind == HousekeepingWorkbenchTaskKind.stay,
          )
          .length,
      nextPriority: next,
    );
  }

  static HousekeepingWorkbenchSelection selectionFor(
    HousekeepingWorkbenchTask task,
  ) {
    return HousekeepingWorkbenchSelection(
      taskId: task.id,
      kind: task.kind,
      bookingId: task.bookingId,
      roomId: task.roomId,
      recordDate: task.recordDate,
      sessionIndex: task.sessionIndex,
    );
  }

  /// 入住中列優先選今天第一個還能填的場次，沒有才回到過往可填。
  static HousekeepingWorkbenchSelection selectionForStay({
    required HousekeepingRoomInput room,
    required List<DailyCareReportCenterItem> items,
    required DateTime today,
  }) {
    final DateTime todayOnly = DailyCareDateHelper.dateOnly(today);
    final List<DailyCareReportCenterItem> mine = items
        .where(
          (DailyCareReportCenterItem item) => item.bookingId == room.bookingId,
        )
        .toList();
    final List<DailyCareReportCenterItem> todayFillable =
        mine
            .where(
              (DailyCareReportCenterItem item) =>
                  item.isPendingFill && _sameDay(item.recordDate, todayOnly),
            )
            .toList()
          ..sort(_bySession);
    if (todayFillable.isNotEmpty) {
      return _selectionForItem(todayFillable.first, roomId: room.id);
    }
    final List<DailyCareReportCenterItem> overdue =
        mine
            .where(
              (DailyCareReportCenterItem item) =>
                  item.isPendingFill &&
                  DailyCareDateHelper.dateOnly(
                    item.recordDate,
                  ).isBefore(todayOnly),
            )
            .toList()
          ..sort(_byDateThenSession);
    if (overdue.isNotEmpty) {
      return _selectionForItem(overdue.first, roomId: room.id);
    }
    final List<DailyCareReportCenterItem> todayAny =
        mine
            .where(
              (DailyCareReportCenterItem item) =>
                  _sameDay(item.recordDate, todayOnly),
            )
            .toList()
          ..sort(_bySession);
    if (todayAny.isNotEmpty) {
      return _selectionForItem(todayAny.first, roomId: room.id);
    }
    return HousekeepingWorkbenchSelection(
      taskId: 'stay-${room.id}',
      kind: HousekeepingWorkbenchTaskKind.stay,
      bookingId: room.bookingId,
      roomId: room.id,
    );
  }

  /// 儲存後先選同一訂單的下一個可填場次，沒有再選下一筆待回報。
  static HousekeepingWorkbenchSelection? nextAfterSave({
    required List<DailyCareReportCenterItem> items,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
    required DateTime today,
    Set<String> savedSessionKeys = const <String>{},
  }) {
    final DateTime todayOnly = DailyCareDateHelper.dateOnly(today);
    final DateTime savedDay = DailyCareDateHelper.dateOnly(recordDate);
    bool pending(DailyCareReportCenterItem item) {
      if (!item.isPendingFill) {
        return false;
      }
      final String key =
          '${item.bookingId}|${DailyCareDateHelper.dateKey(item.recordDate)}|${item.sessionIndex}';
      if (savedSessionKeys.contains(key)) {
        return false;
      }
      return !(item.bookingId == bookingId &&
          _sameDay(item.recordDate, savedDay) &&
          item.sessionIndex == sessionIndex);
    }

    final List<DailyCareReportCenterItem> same =
        items
            .where(
              (DailyCareReportCenterItem item) =>
                  item.bookingId == bookingId && pending(item),
            )
            .toList()
          ..sort(_byDateThenSession);
    DailyCareReportCenterItem? later;
    DailyCareReportCenterItem? earlier;
    for (final DailyCareReportCenterItem item in same) {
      final bool after =
          DailyCareDateHelper.dateOnly(item.recordDate).isAfter(savedDay) ||
          (_sameDay(item.recordDate, savedDay) &&
              item.sessionIndex > sessionIndex);
      if (after) {
        later ??= item;
      } else {
        earlier ??= item;
      }
    }
    final DailyCareReportCenterItem? sameNext = later ?? earlier;
    if (sameNext != null) {
      return _selectionForItem(sameNext);
    }

    final List<DailyCareReportCenterItem> others =
        items.where((DailyCareReportCenterItem item) {
            if (!pending(item) || item.bookingId == bookingId) {
              return false;
            }
            return !DailyCareDateHelper.dateOnly(
              item.recordDate,
            ).isAfter(todayOnly);
          }).toList()
          ..sort((DailyCareReportCenterItem a, DailyCareReportCenterItem b) {
            final int rank = _reportRank(
              a,
              todayOnly,
            ).index.compareTo(_reportRank(b, todayOnly).index);
            if (rank != 0) {
              return rank;
            }
            return _byDateThenSession(a, b);
          });
    if (others.isEmpty) {
      return null;
    }
    return _selectionForItem(others.first);
  }

  static List<HousekeepingWorkbenchTask> _reportTasks(
    List<DailyCareReportCenterItem> items,
    DateTime today,
  ) {
    final List<HousekeepingWorkbenchTask> tasks = <HousekeepingWorkbenchTask>[];
    for (final DailyCareReportCenterItem item in items) {
      if (item.isPendingFill) {
        tasks.add(_reportTask(item, items, _reportRank(item, today)));
      } else if (item.isHistoryIncomplete) {
        tasks.add(
          _reportTask(item, items, HousekeepingWorkbenchRank.lockedHistory),
        );
      }
    }
    return tasks;
  }

  static HousekeepingWorkbenchRank _reportRank(
    DailyCareReportCenterItem item,
    DateTime today,
  ) {
    final DateTime day = DailyCareDateHelper.dateOnly(item.recordDate);
    if (day.isBefore(today)) {
      return HousekeepingWorkbenchRank.overdueReport;
    }
    if (day.isAfter(today)) {
      return HousekeepingWorkbenchRank.laterReport;
    }
    return HousekeepingWorkbenchRank.todayReport;
  }

  static HousekeepingWorkbenchTask _reportTask(
    DailyCareReportCenterItem item,
    List<DailyCareReportCenterItem> items,
    HousekeepingWorkbenchRank rank,
  ) {
    final DateTime day = DailyCareDateHelper.dateOnly(item.recordDate);
    final List<DailyCareReportCenterItem> dayItems = items
        .where(
          (DailyCareReportCenterItem other) =>
              other.bookingId == item.bookingId &&
              _sameDay(other.recordDate, day),
        )
        .toList();
    final bool daycare = item.isDaycare && item.roomId.trim().isEmpty;
    final String place = daycare ? '安親' : item.placeLabel;
    final String session = item.sessionName.trim().isEmpty
        ? '第 ${item.sessionIndex + 1} 場'
        : item.sessionName.trim();
    final String who = _who(item.customerName, item.petNamesText);
    final String status = item.isHistoryIncomplete
        ? '已鎖定'
        : (item.isCompleted ? '已完成' : '待填');
    final int total = dayItems.length;
    final int filled = dayItems
        .where((DailyCareReportCenterItem other) => other.isCompleted)
        .length;
    final String progress = total <= 0 ? '' : '已填 $filled/$total';
    final String time = item.isDaycare ? item.daycareTimeLabel.trim() : '';
    return HousekeepingWorkbenchTask(
      id: 'report-${item.bookingId}-${_dayKey(day)}-${item.sessionIndex}',
      kind: HousekeepingWorkbenchTaskKind.report,
      rank: rank,
      roomId: item.roomId,
      roomName: place,
      bookingId: item.bookingId,
      customerName: item.customerName,
      petNames: item.petNamesText,
      sessionName: session,
      recordDate: day,
      sessionIndex: item.sessionIndex,
      filledCount: filled,
      totalCount: total,
      title: place,
      subtitle: <String>[
        if (who.isNotEmpty) who,
        if (time.isNotEmpty) time,
        session,
        if (progress.isNotEmpty) progress,
      ].join('・'),
      statusLabel: status,
      taskName: session,
      muted: rank == HousekeepingWorkbenchRank.lockedHistory,
    );
  }

  static List<HousekeepingWorkbenchTask> _roomTasks({
    required List<HousekeepingRoomInput> rooms,
    required List<HousekeepingBookingMark> bookings,
    required List<DailyCareReportCenterItem> items,
    required DateTime today,
    required DateTime selectedDate,
  }) {
    final List<HousekeepingWorkbenchTask> tasks = <HousekeepingWorkbenchTask>[];
    for (final HousekeepingRoomInput room in rooms) {
      tasks.add(_roomDirectoryTask(room));
      if (room.statusLabel == '入住中') {
        tasks.add(_stayTask(room, items, today));
      }
      final HousekeepingWorkbenchTask? action = _housekeepingTask(
        room: room,
        bookings: bookings,
        selectedDate: selectedDate,
      );
      if (action != null) {
        tasks.add(action);
      }
    }
    return tasks;
  }

  static HousekeepingWorkbenchTask _roomDirectoryTask(
    HousekeepingRoomInput room,
  ) {
    final String who = _who(room.customerName, room.petNames);
    return HousekeepingWorkbenchTask(
      id: 'room-${room.id}',
      kind: HousekeepingWorkbenchTaskKind.room,
      rank: HousekeepingWorkbenchRank.room,
      roomId: room.id,
      roomName: room.name,
      bookingId: room.bookingId,
      customerName: room.customerName,
      petNames: room.petNames,
      title: room.name,
      subtitle: <String>[
        if (room.typeName.isNotEmpty) room.typeName,
        if (who.isNotEmpty) who,
        if (room.stayRange.isNotEmpty) room.stayRange,
      ].join('・'),
      statusLabel: room.statusLabel,
      taskName: room.statusLabel,
    );
  }

  static HousekeepingWorkbenchTask _stayTask(
    HousekeepingRoomInput room,
    List<DailyCareReportCenterItem> items,
    DateTime today,
  ) {
    final List<DailyCareReportCenterItem> todayItems = items
        .where(
          (DailyCareReportCenterItem item) =>
              item.bookingId == room.bookingId &&
              _sameDay(item.recordDate, today),
        )
        .toList();
    final int total = todayItems.length;
    final int filled = todayItems
        .where((DailyCareReportCenterItem item) => item.isCompleted)
        .length;
    final String progress = total <= 0 ? '今日無需回報' : '今日 $filled/$total';
    final String night = _stayNight(room, items);
    return HousekeepingWorkbenchTask(
      id: 'stay-${room.id}',
      kind: HousekeepingWorkbenchTaskKind.stay,
      rank: HousekeepingWorkbenchRank.stay,
      roomId: room.id,
      roomName: room.name,
      bookingId: room.bookingId,
      customerName: room.customerName,
      petNames: room.petNames,
      title: room.name,
      subtitle: <String>[
        if (_who(room.customerName, room.petNames).isNotEmpty)
          _who(room.customerName, room.petNames),
        if (night.isNotEmpty) night,
        progress,
      ].join('・'),
      statusLabel: '入住中',
      taskName: night,
      filledCount: filled,
      totalCount: total,
    );
  }

  static HousekeepingWorkbenchTask? _housekeepingTask({
    required HousekeepingRoomInput room,
    required List<HousekeepingBookingMark> bookings,
    required DateTime selectedDate,
  }) {
    if (_isVacant(room.statusLabel)) {
      return null;
    }
    final _StayFlag flag = _stayFlag(room, bookings, selectedDate);
    final bool floor =
        room.statusLabel == DaycareOccupancyService.cleaningLabel ||
        room.statusLabel == DaycareOccupancyService.maintenanceLabel ||
        room.statusLabel == DaycareOccupancyService.closedLabel;
    if (floor) {
      return _actionTask(
        room: room,
        rank: HousekeepingWorkbenchRank.housekeeping,
        taskName: _floorTaskName(room.statusLabel),
        checkoutLabel: flag.departs ? flag.checkoutLabel : '',
      );
    }
    if (flag.departs && room.statusLabel == '入住中') {
      return _actionTask(
        room: room,
        rank: HousekeepingWorkbenchRank.arrivalDeparture,
        taskName: '今日退房',
        checkoutLabel: flag.checkoutLabel,
      );
    }
    if (flag.arrives &&
        (room.statusLabel == '已訂' || room.statusLabel == '入住中')) {
      return _actionTask(
        room: room,
        rank: HousekeepingWorkbenchRank.arrivalDeparture,
        taskName: '今日入住',
        checkoutLabel: '',
      );
    }
    return null;
  }

  static HousekeepingWorkbenchTask _actionTask({
    required HousekeepingRoomInput room,
    required HousekeepingWorkbenchRank rank,
    required String taskName,
    required String checkoutLabel,
  }) {
    final String who = _who(room.customerName, room.petNames);
    return HousekeepingWorkbenchTask(
      id: 'house-${room.id}',
      kind: HousekeepingWorkbenchTaskKind.housekeeping,
      rank: rank,
      roomId: room.id,
      roomName: room.name,
      bookingId: room.bookingId,
      customerName: room.customerName,
      petNames: room.petNames,
      title: room.name,
      subtitle: <String>[
        room.statusLabel,
        taskName,
        if (who.isNotEmpty) who,
        if (checkoutLabel.isNotEmpty) checkoutLabel,
      ].join('・'),
      statusLabel: room.statusLabel,
      taskName: taskName,
      checkoutLabel: checkoutLabel,
    );
  }

  static String _floorTaskName(String status) {
    if (status == DaycareOccupancyService.cleaningLabel) {
      return '待清潔';
    }
    if (status == DaycareOccupancyService.maintenanceLabel) {
      return '待處理';
    }
    return status;
  }

  static bool _visible(
    HousekeepingWorkbenchTask task,
    HousekeepingWorkbenchFilter filter,
  ) {
    switch (filter) {
      case HousekeepingWorkbenchFilter.todo:
        return task.rank == HousekeepingWorkbenchRank.overdueReport ||
            task.rank == HousekeepingWorkbenchRank.todayReport ||
            task.rank == HousekeepingWorkbenchRank.housekeeping ||
            task.rank == HousekeepingWorkbenchRank.arrivalDeparture;
      case HousekeepingWorkbenchFilter.reports:
        return task.kind == HousekeepingWorkbenchTaskKind.report;
      case HousekeepingWorkbenchFilter.checkedIn:
        return task.kind == HousekeepingWorkbenchTaskKind.stay;
      case HousekeepingWorkbenchFilter.allRooms:
        if (task.kind == HousekeepingWorkbenchTaskKind.room) {
          return true;
        }
        return task.kind == HousekeepingWorkbenchTaskKind.report &&
            task.roomId.trim().isEmpty &&
            task.isFillableReport;
    }
  }

  static int _compareTasks(
    HousekeepingWorkbenchTask a,
    HousekeepingWorkbenchTask b,
  ) {
    final int rank = a.rank.index.compareTo(b.rank.index);
    if (rank != 0) {
      return rank;
    }
    if (a.rank == HousekeepingWorkbenchRank.overdueReport &&
        a.recordDate != null &&
        b.recordDate != null) {
      final int date = a.recordDate!.compareTo(b.recordDate!);
      if (date != 0) {
        return date;
      }
      final int session = (a.sessionIndex ?? 0).compareTo(b.sessionIndex ?? 0);
      if (session != 0) {
        return session;
      }
    }
    final int name = naturalCompare(a.roomName, b.roomName);
    if (name != 0) {
      return name;
    }
    final int session = (a.sessionIndex ?? 0).compareTo(b.sessionIndex ?? 0);
    if (session != 0) {
      return session;
    }
    return a.bookingId.compareTo(b.bookingId);
  }

  static _StayFlag _stayFlag(
    HousekeepingRoomInput room,
    List<HousekeepingBookingMark> bookings,
    DateTime selectedDate,
  ) {
    bool arrives = false;
    bool departs = false;
    String checkout = '';
    for (final HousekeepingBookingMark mark in bookings) {
      if (mark.roomId != room.id) {
        continue;
      }
      final String status = mark.status.trim();
      if (status == 'cancelled' || status == 'no_show') {
        continue;
      }
      if (mark.start != null &&
          _sameDay(mark.start!, selectedDate) &&
          (status == 'pending' ||
              status == 'confirmed' ||
              status == 'checked_in')) {
        arrives = true;
      }
      if (mark.end != null &&
          _sameDay(mark.end!, selectedDate) &&
          (status == 'checked_in' || status == 'completed')) {
        departs = true;
        checkout = _clockLabel(mark.end!);
      }
    }
    return _StayFlag(
      arrives: arrives,
      departs: departs,
      checkoutLabel: checkout,
    );
  }

  static String _clockLabel(DateTime value) {
    if (value.hour == 0 && value.minute == 0) {
      return '';
    }
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '退房 $hour:$minute';
  }

  static String _stayNight(
    HousekeepingRoomInput room,
    List<DailyCareReportCenterItem> items,
  ) {
    if (room.stayProgress.trim().isNotEmpty) {
      return room.stayProgress.trim();
    }
    for (final DailyCareReportCenterItem item in items) {
      if (item.bookingId == room.bookingId &&
          item.stayProgressText.isNotEmpty) {
        return item.stayProgressText;
      }
    }
    return '';
  }

  static String _who(String customer, String pets) {
    return <String>[
      if (customer.trim().isNotEmpty) customer.trim(),
      if (pets.trim().isNotEmpty) pets.trim(),
    ].join('／');
  }

  static bool _isVacant(String label) {
    return label == DaycareOccupancyService.vacantLabel;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return DailyCareDateHelper.dateOnly(a) == DailyCareDateHelper.dateOnly(b);
  }

  static String _dayKey(DateTime day) {
    final DateTime only = DailyCareDateHelper.dateOnly(day);
    return '${only.year}${only.month.toString().padLeft(2, '0')}${only.day.toString().padLeft(2, '0')}';
  }

  static int _bySession(
    DailyCareReportCenterItem a,
    DailyCareReportCenterItem b,
  ) {
    return a.sessionIndex.compareTo(b.sessionIndex);
  }

  static int _byDateThenSession(
    DailyCareReportCenterItem a,
    DailyCareReportCenterItem b,
  ) {
    final int date = DailyCareDateHelper.dateOnly(
      a.recordDate,
    ).compareTo(DailyCareDateHelper.dateOnly(b.recordDate));
    if (date != 0) {
      return date;
    }
    return a.sessionIndex.compareTo(b.sessionIndex);
  }

  static HousekeepingWorkbenchSelection _selectionForItem(
    DailyCareReportCenterItem item, {
    String roomId = '',
  }) {
    final DateTime day = DailyCareDateHelper.dateOnly(item.recordDate);
    final String resolvedRoom = roomId.trim().isNotEmpty ? roomId : item.roomId;
    return HousekeepingWorkbenchSelection(
      taskId: 'report-${item.bookingId}-${_dayKey(day)}-${item.sessionIndex}',
      kind: HousekeepingWorkbenchTaskKind.report,
      bookingId: item.bookingId,
      roomId: resolvedRoom,
      recordDate: day,
      sessionIndex: item.sessionIndex,
    );
  }
}

class _StayFlag {
  const _StayFlag({
    required this.arrives,
    required this.departs,
    required this.checkoutLabel,
  });

  final bool arrives;
  final bool departs;
  final String checkoutLabel;
}
