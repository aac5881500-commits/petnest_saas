// 檔案名稱：lib/features/room/widgets/housekeeping_workbench.dart
// 功能說明：桌機分割工作台。左側今日待辦，右側只處理目前這一筆。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../models/housekeeping_workbench_task.dart';
import '../services/housekeeping_workbench_logic.dart';
import 'daily_care_record_editor.dart';

typedef HousekeepingReportEditorBuilder =
    Widget Function({
      required HousekeepingWorkbenchTask task,
      required DailyCareReportCenterItem item,
      required DailyCareSettingModel setting,
      required VoidCallback onSaved,
    });

class HousekeepingWorkbench extends StatefulWidget {
  const HousekeepingWorkbench({
    super.key,
    required this.shopId,
    required this.rooms,
    required this.bookings,
    required this.items,
    required this.today,
    required this.selectedDate,
    required this.filter,
    required this.selection,
    required this.setting,
    required this.onFilter,
    required this.onSelection,
    required this.onShiftDate,
    required this.onToday,
    required this.actionsFor,
    required this.onOpenRoom,
    this.editorBuilder,
  });

  final String shopId;
  final List<HousekeepingRoomInput> rooms;
  final List<HousekeepingBookingMark> bookings;
  final List<DailyCareReportCenterItem> items;
  final DateTime today;
  final DateTime selectedDate;
  final HousekeepingWorkbenchFilter filter;
  final HousekeepingWorkbenchSelection? selection;
  final DailyCareSettingModel setting;
  final ValueChanged<HousekeepingWorkbenchFilter> onFilter;
  final ValueChanged<HousekeepingWorkbenchSelection?> onSelection;
  final ValueChanged<int> onShiftDate;
  final VoidCallback onToday;
  final List<HousekeepingWorkbenchAction> Function(String roomId) actionsFor;
  final ValueChanged<String> onOpenRoom;
  final HousekeepingReportEditorBuilder? editorBuilder;

  @override
  State<HousekeepingWorkbench> createState() => _HousekeepingWorkbenchState();
}

class _HousekeepingWorkbenchState extends State<HousekeepingWorkbench> {
  final Set<String> _savedSessions = <String>{};

  @override
  Widget build(BuildContext context) {
    _pruneSaved();
    final List<DailyCareReportCenterItem> items = _itemsForBoard();
    final HousekeepingWorkbenchBoard board = HousekeepingWorkbenchLogic.build(
      rooms: widget.rooms,
      bookings: widget.bookings,
      items: items,
      filter: widget.filter,
      today: widget.today,
      selectedDate: widget.selectedDate,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double left = (constraints.maxWidth * 0.34).clamp(340, 430);
        return Row(
          key: const ValueKey<String>('housekeeping-workbench'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: left,
              child: _TaskNav(
                board: board,
                selectedDate: widget.selectedDate,
                filter: widget.filter,
                selection: widget.selection,
                onFilter: widget.onFilter,
                onShiftDate: widget.onShiftDate,
                onToday: widget.onToday,
                onTap: (HousekeepingWorkbenchTask task) => _select(task, items),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WorkPanel(
                shopId: widget.shopId,
                board: board,
                tasks: board.tasks,
                rooms: widget.rooms,
                items: items,
                selection: widget.selection,
                setting: widget.setting,
                actionsFor: widget.actionsFor,
                onOpenRoom: widget.onOpenRoom,
                onSelection: widget.onSelection,
                editorBuilder: widget.editorBuilder,
                onSaved: _saved,
              ),
            ),
          ],
        );
      },
    );
  }

  List<DailyCareReportCenterItem> _itemsForBoard() {
    return widget.items.map((DailyCareReportCenterItem item) {
      if (item.isPendingFill && _savedSessions.contains(_sessionKey(item))) {
        return item.copyWith(isCompleted: true);
      }
      return item;
    }).toList();
  }

  void _pruneSaved() {
    _savedSessions.removeWhere((String key) {
      for (final DailyCareReportCenterItem item in widget.items) {
        if (_sessionKey(item) == key && item.isPendingFill) {
          return false;
        }
      }
      return true;
    });
  }

  void _select(
    HousekeepingWorkbenchTask task,
    List<DailyCareReportCenterItem> items,
  ) {
    if (task.kind == HousekeepingWorkbenchTaskKind.stay) {
      HousekeepingRoomInput? room;
      for (final HousekeepingRoomInput row in widget.rooms) {
        if (row.id == task.roomId) {
          room = row;
          break;
        }
      }
      if (room == null) {
        widget.onSelection(HousekeepingWorkbenchLogic.selectionFor(task));
        return;
      }
      widget.onSelection(
        HousekeepingWorkbenchLogic.selectionForStay(
          room: room,
          items: items,
          today: widget.today,
        ),
      );
      return;
    }
    widget.onSelection(HousekeepingWorkbenchLogic.selectionFor(task));
  }

  void _saved(HousekeepingWorkbenchTask task) {
    if (task.recordDate == null || task.sessionIndex == null) {
      widget.onSelection(null);
      return;
    }
    _savedSessions.add(
      '${task.bookingId}|${DailyCareDateHelper.dateKey(task.recordDate!)}|${task.sessionIndex}',
    );
    widget.onSelection(
      HousekeepingWorkbenchLogic.nextAfterSave(
        items: _itemsForBoard(),
        bookingId: task.bookingId,
        recordDate: task.recordDate!,
        sessionIndex: task.sessionIndex!,
        today: widget.today,
        savedSessionKeys: _savedSessions,
      ),
    );
  }
}

String _sessionKey(DailyCareReportCenterItem item) {
  return '${item.bookingId}|${DailyCareDateHelper.dateKey(item.recordDate)}|${item.sessionIndex}';
}

class _TaskNav extends StatelessWidget {
  const _TaskNav({
    required this.board,
    required this.selectedDate,
    required this.filter,
    required this.selection,
    required this.onFilter,
    required this.onShiftDate,
    required this.onToday,
    required this.onTap,
  });

  final HousekeepingWorkbenchBoard board;
  final DateTime selectedDate;
  final HousekeepingWorkbenchFilter filter;
  final HousekeepingWorkbenchSelection? selection;
  final ValueChanged<HousekeepingWorkbenchFilter> onFilter;
  final ValueChanged<int> onShiftDate;
  final VoidCallback onToday;
  final ValueChanged<HousekeepingWorkbenchTask> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '今日待辦',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '前一天',
                      onPressed: () => onShiftDate(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('M/d').format(selectedDate),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '後一天',
                      onPressed: () => onShiftDate(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    TextButton(
                      onPressed: isToday ? null : onToday,
                      child: const Text('今天'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _CountChip('待回報 ${board.pendingReportCount}'),
                    _CountChip('待房務 ${board.pendingHousekeepingCount}'),
                    _CountChip('入住中 ${board.checkedInCount}'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _filterChip('待處理', HousekeepingWorkbenchFilter.todo),
                    _filterChip('待回報', HousekeepingWorkbenchFilter.reports),
                    _filterChip('入住中', HousekeepingWorkbenchFilter.checkedIn),
                    _filterChip('全部房間', HousekeepingWorkbenchFilter.allRooms),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: board.visible.isEmpty
                ? const Center(
                    child: Text(
                      '這個篩選目前沒有任務',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: board.visible.length,
                    itemBuilder: (BuildContext context, int index) {
                      final HousekeepingWorkbenchTask task =
                          board.visible[index];
                      return _TaskTile(
                        task: task,
                        selected: _taskSelected(task, selection),
                        onTap: () => onTap(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, HousekeepingWorkbenchFilter value) {
    return ChoiceChip(
      key: ValueKey<String>('workbench-filter-${value.name}'),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      selected: filter == value,
      onSelected: (_) => onFilter(value),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final HousekeepingWorkbenchTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = _tone(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFF3F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey<String>('workbench-task-${task.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: task.muted ? Colors.black45 : Colors.black87,
                        ),
                      ),
                      Text(
                        task.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: task.muted ? Colors.black38 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkPanel extends StatelessWidget {
  const _WorkPanel({
    required this.shopId,
    required this.board,
    required this.tasks,
    required this.rooms,
    required this.items,
    required this.selection,
    required this.setting,
    required this.actionsFor,
    required this.onOpenRoom,
    required this.onSelection,
    required this.onSaved,
    this.editorBuilder,
  });

  final String shopId;
  final HousekeepingWorkbenchBoard board;
  final List<HousekeepingWorkbenchTask> tasks;
  final List<HousekeepingRoomInput> rooms;
  final List<DailyCareReportCenterItem> items;
  final HousekeepingWorkbenchSelection? selection;
  final DailyCareSettingModel setting;
  final List<HousekeepingWorkbenchAction> Function(String roomId) actionsFor;
  final ValueChanged<String> onOpenRoom;
  final ValueChanged<HousekeepingWorkbenchSelection?> onSelection;
  final ValueChanged<HousekeepingWorkbenchTask> onSaved;
  final HousekeepingReportEditorBuilder? editorBuilder;

  @override
  Widget build(BuildContext context) {
    final HousekeepingWorkbenchTask? task = _selectedTask();
    final DailyCareReportCenterItem? item = task == null
        ? null
        : _itemFor(task);
    final Widget body;
    if (task == null || selection == null) {
      body = _Summary(board: board, onNext: onSelection);
    } else if (task.kind == HousekeepingWorkbenchTaskKind.report &&
        item != null) {
      body = _ReportPanel(
        shopId: shopId,
        task: task,
        item: item,
        items: items,
        setting: setting,
        onSession: onSelection,
        onSaved: () => onSaved(task),
        editorBuilder: editorBuilder,
      );
    } else {
      body = _RoomPanel(
        task: task,
        room: _roomFor(task.roomId),
        actions: task.roomId.isEmpty
            ? const <HousekeepingWorkbenchAction>[]
            : actionsFor(task.roomId),
        onOpenRoom: task.roomId.isEmpty ? null : () => onOpenRoom(task.roomId),
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

  HousekeepingWorkbenchTask? _selectedTask() {
    final HousekeepingWorkbenchSelection? current = selection;
    if (current == null) {
      return null;
    }
    for (final HousekeepingWorkbenchTask task in tasks) {
      if (task.id == current.taskId) {
        return task;
      }
    }
    for (final HousekeepingWorkbenchTask task in board.visible) {
      if (task.id == current.taskId) {
        return task;
      }
    }
    return null;
  }

  DailyCareReportCenterItem? _itemFor(HousekeepingWorkbenchTask task) {
    if (task.sessionIndex == null || task.recordDate == null) {
      return null;
    }
    for (final DailyCareReportCenterItem item in items) {
      if (item.bookingId == task.bookingId &&
          item.sessionIndex == task.sessionIndex &&
          DailyCareDateHelper.dateOnly(item.recordDate) == task.recordDate) {
        return item;
      }
    }
    return null;
  }

  HousekeepingRoomInput? _roomFor(String roomId) {
    for (final HousekeepingRoomInput room in rooms) {
      if (room.id == roomId) {
        return room;
      }
    }
    return null;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.board, required this.onNext});

  final HousekeepingWorkbenchBoard board;
  final ValueChanged<HousekeepingWorkbenchSelection?> onNext;

  @override
  Widget build(BuildContext context) {
    final HousekeepingWorkbenchTask? next = board.nextPriority;
    return Padding(
      key: const ValueKey<String>('workbench-summary'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '今日工作摘要',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text('待回報 ${board.pendingReportCount}'),
          Text('待房務 ${board.pendingHousekeepingCount}'),
          Text('入住中 ${board.checkedInCount}'),
          const SizedBox(height: 16),
          if (next == null)
            const Text(
              '目前沒有需要處理的現場任務',
              key: ValueKey<String>('workbench-empty'),
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else
            FilledButton(
              key: const ValueKey<String>('workbench-next'),
              onPressed: () =>
                  onNext(HousekeepingWorkbenchLogic.selectionFor(next)),
              child: Text('處理下一筆：${next.title} ${next.taskName}'),
            ),
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.shopId,
    required this.task,
    required this.item,
    required this.items,
    required this.setting,
    required this.onSession,
    required this.onSaved,
    this.editorBuilder,
  });

  final String shopId;
  final HousekeepingWorkbenchTask task;
  final DailyCareReportCenterItem item;
  final List<DailyCareReportCenterItem> items;
  final DailyCareSettingModel setting;
  final ValueChanged<HousekeepingWorkbenchSelection?> onSession;
  final VoidCallback onSaved;
  final HousekeepingReportEditorBuilder? editorBuilder;

  @override
  Widget build(BuildContext context) {
    final List<DailyCareReportCenterItem> sessions =
        items
            .where(
              (DailyCareReportCenterItem row) =>
                  row.bookingId == item.bookingId &&
                  DailyCareDateHelper.dateOnly(row.recordDate) ==
                      DailyCareDateHelper.dateOnly(item.recordDate),
            )
            .toList()
          ..sort(
            (DailyCareReportCenterItem a, DailyCareReportCenterItem b) =>
                a.sessionIndex.compareTo(b.sessionIndex),
          );
    final String schedule = item.isDaycare
        ? item.daycareTimeLabel
        : item.stayProgressText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                <String>[
                  task.roomName,
                  if (item.bookingCode.isNotEmpty) item.bookingCode,
                ].join('・'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                <String>[
                  if (item.customerName.isNotEmpty) item.customerName,
                  if (item.petNamesText.isNotEmpty) item.petNamesText,
                  DateFormat('M/d').format(item.recordDate),
                  if (schedule.isNotEmpty) schedule,
                ].join('・'),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final DailyCareReportCenterItem session in sessions)
                    ChoiceChip(
                      label: Text(
                        '${session.sessionName.trim().isEmpty ? '第 ${session.sessionIndex + 1} 場' : session.sessionName} ${_sessionStatus(session)}',
                      ),
                      visualDensity: VisualDensity.compact,
                      selected: session.sessionIndex == item.sessionIndex,
                      onSelected: (_) {
                        onSession(
                          HousekeepingWorkbenchLogic.selectionFor(
                            _sessionTask(session),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (item.isHistoryIncomplete)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '此場未完成，訂單已結束，無法再補填',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        Expanded(child: _editor()),
      ],
    );
  }

  Widget _editor() {
    final HousekeepingReportEditorBuilder? custom = editorBuilder;
    if (custom != null) {
      return custom(task: task, item: item, setting: setting, onSaved: onSaved);
    }
    final bool readOnly = item.reportsLocked || !item.canOperate;
    return DailyCareRecordEditor(
      key: ValueKey<String>(
        '${item.bookingId}-${item.sessionIndex}-${item.recordDate.toIso8601String()}',
      ),
      shopId: shopId,
      bookingId: item.bookingId,
      roomId: item.roomId,
      roomName: item.roomName,
      recordDate: item.recordDate,
      sessionIndex: item.sessionIndex,
      sessionName: task.sessionName,
      customFields: setting.customFields,
      enabledFields: setting.enabledFields,
      photoEnabled: setting.photoEnabled,
      serviceType: item.serviceType,
      petIds: item.petIds,
      entitlement: item.entitlement,
      readOnly: readOnly,
      showHeaderCard: false,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      onSaved: onSaved,
    );
  }

  HousekeepingWorkbenchTask _sessionTask(DailyCareReportCenterItem session) {
    final DateTime day = DailyCareDateHelper.dateOnly(session.recordDate);
    final String key =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    return HousekeepingWorkbenchTask(
      id: 'report-${session.bookingId}-$key-${session.sessionIndex}',
      kind: HousekeepingWorkbenchTaskKind.report,
      rank: task.rank,
      title: task.title,
      subtitle: task.subtitle,
      statusLabel: _sessionStatus(session),
      roomId: session.roomId,
      roomName: task.roomName,
      bookingId: session.bookingId,
      recordDate: day,
      sessionIndex: session.sessionIndex,
      sessionName: session.sessionName,
    );
  }
}

class _RoomPanel extends StatelessWidget {
  const _RoomPanel({
    required this.task,
    required this.room,
    required this.actions,
    required this.onOpenRoom,
  });

  final HousekeepingWorkbenchTask task;
  final HousekeepingRoomInput? room;
  final List<HousekeepingWorkbenchAction> actions;
  final VoidCallback? onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final HousekeepingRoomInput? current = room;
    final String who = <String>[
      if ((current?.customerName ?? task.customerName).trim().isNotEmpty)
        (current?.customerName ?? task.customerName).trim(),
      if ((current?.petNames ?? task.petNames).trim().isNotEmpty)
        (current?.petNames ?? task.petNames).trim(),
    ].join('／');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          task.roomName.isEmpty ? task.title : task.roomName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text('目前狀態：${current?.statusLabel ?? task.statusLabel}'),
        if (task.taskName.isNotEmpty && task.taskName != task.statusLabel)
          Text(task.taskName),
        if (who.isNotEmpty) Text(who),
        if ((current?.stayRange ?? '').isNotEmpty) Text(current!.stayRange),
        if ((current?.stayProgress ?? '').isNotEmpty)
          Text(current!.stayProgress),
        if (task.checkoutLabel.isNotEmpty) Text(task.checkoutLabel),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final HousekeepingWorkbenchAction action in actions)
              FilledButton(
                onPressed: action.busy ? null : action.onPressed,
                child: Text(action.label),
              ),
            if (onOpenRoom != null)
              OutlinedButton(
                onPressed: onOpenRoom,
                child: const Text('查看完整房務'),
              ),
          ],
        ),
      ],
    );
  }
}

bool _taskSelected(
  HousekeepingWorkbenchTask task,
  HousekeepingWorkbenchSelection? selection,
) {
  if (selection == null) {
    return false;
  }
  if (task.id == selection.taskId) {
    return true;
  }
  return task.kind == HousekeepingWorkbenchTaskKind.stay &&
      selection.kind == HousekeepingWorkbenchTaskKind.report &&
      task.roomId.isNotEmpty &&
      task.roomId == selection.roomId &&
      task.bookingId == selection.bookingId;
}

String _sessionStatus(DailyCareReportCenterItem item) {
  if (item.isHistoryIncomplete) {
    return '已鎖定';
  }
  if (item.isCompleted) {
    return '已完成';
  }
  return '待填';
}

Color _tone(HousekeepingWorkbenchTask task) {
  if (task.muted || task.statusLabel == '已鎖定') {
    return const Color(0xFF8D6E63);
  }
  if (task.kind == HousekeepingWorkbenchTaskKind.report) {
    return const Color(0xFFE65100);
  }
  if (task.kind == HousekeepingWorkbenchTaskKind.stay ||
      task.statusLabel == '入住中') {
    return const Color(0xFF1565C0);
  }
  if (task.statusLabel == '空房') {
    return const Color(0xFF9E9E9E);
  }
  return const Color(0xFF00838F);
}
