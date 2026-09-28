// 檔案名稱：lib/features/room/models/housekeeping_workbench_task.dart
// 功能說明：現場巡房工作台的任務、篩選與選取內容。只描述畫面需要的資料。

enum HousekeepingWorkbenchFilter { todo, reports, checkedIn, allRooms }

enum HousekeepingWorkbenchTaskKind { report, housekeeping, stay, room }

/// 待處理排序：過往可填、今天待填、房務、今日入住退房，其後才是篩選用列。
enum HousekeepingWorkbenchRank {
  overdueReport,
  todayReport,
  laterReport,
  housekeeping,
  arrivalDeparture,
  lockedHistory,
  stay,
  room,
}

class HousekeepingRoomInput {
  const HousekeepingRoomInput({
    required this.id,
    required this.name,
    required this.statusLabel,
    this.typeName = '',
    this.bookingId = '',
    this.customerName = '',
    this.petNames = '',
    this.stayRange = '',
    this.stayProgress = '',
    this.stayStart,
    this.stayEnd,
  });

  final String id;
  final String name;
  final String typeName;
  final String statusLabel;
  final String bookingId;
  final String customerName;
  final String petNames;
  final String stayRange;
  final String stayProgress;
  final DateTime? stayStart;
  final DateTime? stayEnd;
}

class HousekeepingBookingMark {
  const HousekeepingBookingMark({
    required this.roomId,
    required this.bookingId,
    this.customerName = '',
    this.petNames = '',
    this.start,
    this.end,
    this.status = '',
  });

  final String roomId;
  final String bookingId;
  final String customerName;
  final String petNames;
  final DateTime? start;
  final DateTime? end;
  final String status;
}

class HousekeepingWorkbenchTask {
  const HousekeepingWorkbenchTask({
    required this.id,
    required this.kind,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    this.roomId = '',
    this.roomName = '',
    this.bookingId = '',
    this.customerName = '',
    this.petNames = '',
    this.sessionName = '',
    this.recordDate,
    this.sessionIndex,
    this.filledCount = 0,
    this.totalCount = 0,
    this.taskName = '',
    this.checkoutLabel = '',
    this.muted = false,
  });

  final String id;
  final HousekeepingWorkbenchTaskKind kind;
  final HousekeepingWorkbenchRank rank;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String roomId;
  final String roomName;
  final String bookingId;
  final String customerName;
  final String petNames;
  final String sessionName;
  final DateTime? recordDate;
  final int? sessionIndex;
  final int filledCount;
  final int totalCount;
  final String taskName;
  final String checkoutLabel;
  final bool muted;

  bool get isFillableReport =>
      kind == HousekeepingWorkbenchTaskKind.report &&
      (rank == HousekeepingWorkbenchRank.overdueReport ||
          rank == HousekeepingWorkbenchRank.todayReport ||
          rank == HousekeepingWorkbenchRank.laterReport);
}

class HousekeepingWorkbenchSelection {
  const HousekeepingWorkbenchSelection({
    required this.taskId,
    required this.kind,
    this.bookingId = '',
    this.roomId = '',
    this.recordDate,
    this.sessionIndex,
  });

  final String taskId;
  final HousekeepingWorkbenchTaskKind kind;
  final String bookingId;
  final String roomId;
  final DateTime? recordDate;
  final int? sessionIndex;

  HousekeepingWorkbenchSelection copyWith({
    String? taskId,
    HousekeepingWorkbenchTaskKind? kind,
    String? bookingId,
    String? roomId,
    DateTime? recordDate,
    int? sessionIndex,
  }) {
    return HousekeepingWorkbenchSelection(
      taskId: taskId ?? this.taskId,
      kind: kind ?? this.kind,
      bookingId: bookingId ?? this.bookingId,
      roomId: roomId ?? this.roomId,
      recordDate: recordDate ?? this.recordDate,
      sessionIndex: sessionIndex ?? this.sessionIndex,
    );
  }
}

class HousekeepingWorkbenchAction {
  const HousekeepingWorkbenchAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final void Function()? onPressed;
  final bool busy;
}

class HousekeepingWorkbenchBoard {
  const HousekeepingWorkbenchBoard({
    required this.tasks,
    required this.visible,
    required this.pendingReportCount,
    required this.pendingHousekeepingCount,
    required this.checkedInCount,
    this.nextPriority,
  });

  final List<HousekeepingWorkbenchTask> tasks;
  final List<HousekeepingWorkbenchTask> visible;
  final int pendingReportCount;
  final int pendingHousekeepingCount;
  final int checkedInCount;
  final HousekeepingWorkbenchTask? nextPriority;
}
