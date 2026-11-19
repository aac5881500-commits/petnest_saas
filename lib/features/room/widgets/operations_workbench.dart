import 'package:petnest_saas/features/room/widgets/room_status_legend.dart';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';
import 'package:petnest_saas/features/room/widgets/workbench_views.dart';
import 'operations_workbench_data.dart';
import 'package:petnest_saas/core/models/booking_medication_task.dart';
import 'package:petnest_saas/core/models/booking_service_task.dart';
import 'package:petnest_saas/features/medication/medication_task_page.dart';
import 'package:petnest_saas/features/medication/care_task_dialog.dart';

const opsInk = Color(0xFF17213E);
const opsMuted = Color(0xFF778198);
const opsBlue = Color(0xFF2864E8);
const opsLine = Color(0xFFE5EAF3);
const opsBackground = Color(0xFFF5F7FB);

typedef _ShiftEntry = ({
  String time,
  String title,
  String context,
  String action,
  IconData icon,
  bool attention,
  bool complete,
  VoidCallback run,
});

class OperationsSurface extends StatelessWidget {
  const OperationsSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: opsLine),
    ),
    child: child,
  );
}

class OperationsEmpty extends StatelessWidget {
  const OperationsEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.event_available_outlined,
    this.compact = false,
  });
  final String title, message;
  final IconData icon;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final illustration = Container(
      padding: EdgeInsets.all(compact ? 11 : 17),
      decoration: const BoxDecoration(
        color: Color(0xFFEEF3FC),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFF829AC6),
        size: compact ? 23 : 34,
      ),
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: compact ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: opsInk,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: compact ? TextAlign.left : TextAlign.center,
          style: const TextStyle(color: opsMuted, height: 1.6, fontSize: 12),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 13 : 30,
        horizontal: 10,
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                illustration,
                const SizedBox(width: 13),
                Expanded(child: text),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [illustration, const SizedBox(height: 14), text],
            ),
    );
  }
}

class OperationsBadge extends StatelessWidget {
  const OperationsBadge(
    this.label, {
    super.key,
    this.color = opsBlue,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The production presentation. Visual tests instantiate this same widget;
/// there is no separate mockup implementation or fabricated live data.
class OperationsWorkbench extends StatefulWidget {
  const OperationsWorkbench({
    super.key,
    required this.view,
    required this.data,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onDateSelected,
    required this.onOrder,
    this.onOrderCare,
    required this.onRoomRecord,
    required this.onCare,
    required this.onRoomStatus,
    required this.onReports,
    this.onCamera,
    this.busy = false,
    this.shift = false,
    this.careTasks,
    this.shopId = '',
    this.canManageOrder,
    this.onOrderDeparture,
    this.onRoomView,
    this.onTaskPage,
  });
  final WorkbenchView view;
  final bool shift;
  final Widget? careTasks;
  final String shopId;
  final bool Function(Map<String, dynamic>)? canManageOrder;
  final ValueChanged<RoomDayBookingChoice>? onOrderDeparture;
  final VoidCallback? onRoomView;
  final ValueChanged<WidgetBuilder>? onTaskPage;
  final OperationsWorkbenchData data;
  final String selectedRoomId;
  final ValueChanged<String> onSelectRoom;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<RoomDayBookingChoice> onOrder;
  final ValueChanged<RoomDayBookingChoice>? onOrderCare;
  final ValueChanged<OperationsRoom> onRoomRecord;
  final ValueChanged<DailyCareReportCenterItem> onCare;
  final void Function(OperationsRoom, String) onRoomStatus;
  final VoidCallback onReports;
  final VoidCallback? onCamera;
  final bool busy;
  @override
  State<OperationsWorkbench> createState() => _OperationsWorkbenchState();
}

class _OperationsWorkbenchState extends State<OperationsWorkbench> {
  final _search = TextEditingController();
  String _query = '', _filter = '全部', _type = '全部';
  OperationsTaskState? _taskState = OperationsTaskState.pending;
  String? _selectedTask;
  bool _monthTimeline = false;
  DateTime? _calendarMonth;
  final Set<String> _collapsedTypes = {};
  OperationsWorkbenchData get data => widget.data;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OperationsWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.date.month != data.date.month ||
        oldWidget.data.date.year != data.date.year) {
      _calendarMonth = null;
    }
  }

  bool _matches(String value) => _query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .every((word) => value.toLowerCase().contains(word));
  List<OperationsRoom> get _rooms => data.rooms.where((room) {
    final facts = data.day(room, data.date);
    if (_type != '全部' && room.type != _type) return false;
    if (!_matches('${room.name} ${room.type} ${facts.pets}')) return false;
    return switch (_filter) {
      '需處理' => data.tasks.any(
        (task) =>
            task.roomId == room.id &&
            task.state != OperationsTaskState.completed,
      ),
      '入住中' => const [
        'checked_in',
        'daycare_checked_in',
      ].contains(facts.status.presentation.value),
      '空房' =>
        facts.status.presentation.value == 'available' &&
            !facts.status.isHistory,
      '清潔中' => facts.status.presentation.value == 'cleaning',
      _ => true,
    };
  }).toList();
  OperationsRoom? get _selected {
    final rooms = _rooms;
    if (rooms.isEmpty) return null;
    return rooms.firstWhere(
      (room) => room.id == widget.selectedRoomId,
      orElse: () => rooms.first,
    );
  }

  Widget _title(String text, IconData icon, {Widget? action}) => Row(
    children: [
      Icon(icon, color: opsBlue, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: opsInk,
          ),
        ),
      ),
      ?action,
    ],
  );
  Widget _action(
    String text,
    VoidCallback? onTap, {
    bool primary = false,
    IconData? icon,
  }) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
    if (primary) {
      return FilledButton.icon(
        onPressed: widget.busy ? null : onTap,
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(opsBlue),
        ),
        icon: Icon(icon ?? Icons.arrow_forward, size: 16),
        label: Text(text),
      );
    }
    return OutlinedButton.icon(
      onPressed: widget.busy ? null : onTap,
      style: style.copyWith(
        foregroundColor: const WidgetStatePropertyAll(opsBlue),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0xFFCFDAF0)),
        ),
      ),
      icon: Icon(icon ?? Icons.arrow_forward, size: 16),
      label: Text(text),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: data.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) widget.onDateSelected(date);
  }

  List<Widget> _stats() {
    final tasks = data.tasks;
    final checked = data.rooms
        .where(
          (room) => const [
            'checked_in',
            'daycare_checked_in',
          ].contains(data.day(room, data.date).status.presentation.value),
        )
        .length;
    final cleaning = data.rooms
        .where(
          (room) =>
              data.day(room, data.date).status.presentation.value == 'cleaning',
        )
        .length;
    final maintenance = data.rooms
        .where(
          (room) =>
              data.day(room, data.date).status.presentation.value ==
              'maintenance',
        )
        .length;
    final care = data.careItems.where((item) => item.isPendingFill).length;
    final taskMode = widget.view == WorkbenchView.tasks;
    final values = taskMode
        ? [
            (
              Icons.login_outlined,
              '今日抵達',
              tasks.where((task) => task.id.endsWith(':start')).length,
              '筆',
              opsBlue,
            ),
            (
              Icons.logout_outlined,
              '今日離店',
              tasks.where((task) => task.id.endsWith(':end')).length,
              '筆',
              const Color(0xFF9565D5),
            ),
            (
              Icons.cleaning_services_outlined,
              '待清潔',
              cleaning,
              '房',
              data.palette.color('cleaning'),
            ),
            (
              Icons.edit_note_outlined,
              '待填回報',
              care,
              '場',
              const Color(0xFFED8A20),
            ),
          ]
        : [
            (
              Icons.hotel_outlined,
              '入住中',
              checked,
              '房',
              data.palette.color('checked_in'),
            ),
            (
              Icons.cleaning_services_outlined,
              '待清潔',
              cleaning,
              '房',
              data.palette.color('cleaning'),
            ),
            (
              widget.view == WorkbenchView.timeline
                  ? Icons.build_outlined
                  : Icons.assignment_outlined,
              widget.view == WorkbenchView.timeline ? '維修中' : '房務待辦',
              widget.view == WorkbenchView.timeline
                  ? maintenance
                  : tasks
                        .where(
                          (task) =>
                              task.group == OperationsTaskGroup.housekeeping,
                        )
                        .length,
              '項',
              widget.view == WorkbenchView.timeline
                  ? data.palette.color('maintenance')
                  : const Color(0xFF9160CE),
            ),
            (
              Icons.edit_note_outlined,
              '待填回報',
              care,
              '場',
              const Color(0xFFED8A20),
            ),
          ];
    return [
      for (final stat in values)
        OperationsSurface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(stat.$1, color: stat.$5, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !data.isToday && stat.$2.startsWith('今日')
                          ? stat.$2.replaceFirst('今日', '當日')
                          : stat.$2,
                      style: const TextStyle(color: opsMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${stat.$3}',
                          style: TextStyle(
                            color: stat.$5,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stat.$4,
                          style: TextStyle(color: stat.$5, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _statsRow() => LayoutBuilder(
    builder: (context, box) {
      final stats = _stats();
      if (box.maxWidth < 600) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final stat in stats)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(width: 165, child: stat),
                ),
            ],
          ),
        );
      }
      const columns = 4;
      final width = (box.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          for (final stat in stats) SizedBox(width: width, child: stat),
        ],
      );
    },
  );

  Widget _searchBox({double? width}) => SizedBox(
    width: width,
    child: TextField(
      controller: _search,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: '搜尋房號、寵物或訂單',
        hintStyle: const TextStyle(color: opsMuted),
        prefixIcon: const Icon(Icons.search, size: 19),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: '清除搜尋',
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFBFE),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: opsLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: opsBlue),
        ),
      ),
      onChanged: (value) => setState(() => _query = value),
    ),
  );

  Widget _toolbar() => OperationsSurface(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _action(
            '${data.date.year}/${opsShortDate(data.date)}',
            _pickDate,
            icon: Icons.calendar_month_outlined,
          ),
          IconButton(
            tooltip: '上一週',
            onPressed: widget.busy
                ? null
                : () => widget.onDateSelected(
                    data.date.subtract(const Duration(days: 7)),
                  ),
            icon: const Icon(Icons.chevron_left),
          ),
          _action(
            '今天',
            () => widget.onDateSelected(data.today),
            icon: Icons.today_outlined,
          ),
          IconButton(
            tooltip: '下一週',
            onPressed: widget.busy
                ? null
                : () => widget.onDateSelected(
                    data.date.add(const Duration(days: 7)),
                  ),
            icon: const Icon(Icons.chevron_right),
          ),
          if (widget.view == WorkbenchView.timeline) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('週')),
                ButtonSegment(value: true, label: Text('月')),
              ],
              selected: {_monthTimeline},
              onSelectionChanged: (values) =>
                  setState(() => _monthTimeline = values.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
          if (box.maxWidth > 900) const SizedBox(width: 12),
          for (final filter in ['全部', '需處理', '入住中', '空房'])
            ChoiceChip(
              label: Text(filter, style: const TextStyle(fontSize: 12)),
              selected: _filter == filter,
              selectedColor: const Color(0xFFE9EAFD),
              side: BorderSide(
                color: _filter == filter ? const Color(0xFFDADAF7) : opsLine,
              ),
              backgroundColor: Colors.white,
              onSelected: (_) => setState(() => _filter = filter),
            ),
          PopupMenuButton<String>(
            tooltip: '更多篩選',
            initialValue: _type,
            onSelected: (value) => setState(() => _type = value),
            itemBuilder: (_) => [
              for (final type in [
                '全部',
                ...data.rooms.map((room) => room.type).toSet(),
              ])
                CheckedPopupMenuItem(
                  value: type,
                  checked: _type == type,
                  child: Text(type == '全部' ? '全部房型' : type),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _type == '全部' ? '房型篩選' : _type,
                    style: const TextStyle(color: opsMuted, fontSize: 12),
                  ),
                  const Icon(Icons.expand_more, size: 17),
                ],
              ),
            ),
          ),
          if (widget.onCamera != null)
            _action('攝影機分享申請', widget.onCamera, icon: Icons.videocam_outlined),
        ],
      ),
    ),
  );

  Widget _roomList({required bool narrow}) {
    final rooms = _rooms;
    return OperationsSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(
            '房間列表',
            Icons.meeting_room_outlined,
            action: Text(
              '${rooms.length} / ${data.rooms.length} 間',
              style: const TextStyle(color: opsMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          _searchBox(),
          const SizedBox(height: 12),
          Expanded(
            child: rooms.isEmpty
                ? OperationsEmpty(
                    title: data.rooms.isEmpty ? '先準備好第一間房' : '沒有符合條件的房間',
                    message: data.rooms.isEmpty
                        ? '建立房間後，就能在這裡查看房況與照護工作。'
                        : '試著調整搜尋條件或房型篩選。',
                    icon: Icons.meeting_room_outlined,
                  )
                : ListView(
                    children: [
                      for (final type
                          in rooms.map((room) => room.type).toSet()) ...[
                        InkWell(
                          onTap: () => setState(() {
                            if (!_collapsedTypes.add(type)) {
                              _collapsedTypes.remove(type);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  _collapsedTypes.contains(type)
                                      ? Icons.chevron_right
                                      : Icons.expand_more,
                                  size: 16,
                                  color: opsMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    type,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: opsInk,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${rooms.where((room) => room.type == type).length} 間',
                                  style: const TextStyle(
                                    color: opsMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_collapsedTypes.contains(type))
                          for (final room in rooms.where(
                            (room) => room.type == type,
                          ))
                            _roomTile(room, narrow),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _roomTile(OperationsRoom room, bool narrow) {
    final facts = data.day(room, data.date);
    final selected = _selected?.id == room.id;
    final pending = data.careItems
        .where((item) => item.roomId == room.id && item.isPendingFill)
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEEF3FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: selected ? opsBlue : opsLine),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            widget.onSelectRoom(room.id);
            if (narrow) _showRoom(room);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: opsInk,
                        ),
                      ),
                    ),
                    OperationsBadge(
                      facts.status.presentation.label,
                      color: facts.status.color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.pets_outlined,
                      size: 14,
                      color: facts.pets.isEmpty ? opsMuted : opsInk,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facts.pets.isEmpty ? '等待下一位小房客' : facts.pets,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: opsMuted),
                      ),
                    ),
                    if (pending > 0)
                      OperationsBadge(
                        '待填 $pending',
                        color: const Color(0xFF9365D2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DateTime> get _days {
    if (_monthTimeline) {
      final first = DateTime(data.date.year, data.date.month);
      return List.generate(
        DateTime(first.year, first.month + 1, 0).day,
        (index) => first.add(Duration(days: index)),
      );
    }
    final first = DateUtils.dateOnly(
      data.date,
    ).subtract(Duration(days: data.date.weekday - 1));
    return List.generate(7, (index) => first.add(Duration(days: index)));
  }

  Widget _monthCalendar(OperationsRoom? room) {
    final month = _calendarMonth ?? DateTime(data.date.year, data.date.month);
    final offset = month.weekday % 7;
    final length = DateTime(month.year, month.month + 1, 0).day;
    return OperationsSurface(
      child: ListView(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: opsBlue,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room == null ? '房間月曆' : room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        color: opsInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room == null ? '選擇房間，查看預訂與房況' : room.type,
                      style: const TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (room != null)
                OperationsBadge(
                  data.day(room, data.date).status.presentation.label,
                  color: data.day(room, data.date).status.color,
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: '上個月',
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${month.year} 年 ${month.month} 月',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: opsInk,
                ),
              ),
              IconButton(
                tooltip: '下個月',
                onPressed: () => setState(
                  () => _calendarMonth = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in ['日', '一', '二', '三', '四', '五', '六'])
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        label,
                        style: const TextStyle(color: opsMuted, fontSize: 11),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 4,
              runSpacing: 5,
              children: [
                for (var index = 0; index < offset + length; index++)
                  SizedBox(
                    width: (box.maxWidth - 24) / 7,
                    height: 54,
                    child: index < offset
                        ? null
                        : Builder(
                            builder: (_) {
                              final date = DateTime(
                                month.year,
                                month.month,
                                index - offset + 1,
                              );
                              final facts = room == null
                                  ? null
                                  : data.day(room, date);
                              final selected = DateUtils.isSameDay(
                                date,
                                data.date,
                              );
                              final color = facts?.status.color ?? opsMuted;
                              return Material(
                                color: selected
                                    ? const Color(0xFFEAF1FF)
                                    : color.withValues(alpha: .035),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  side: BorderSide(
                                    color: selected ? opsBlue : opsLine,
                                    width: selected ? 1.6 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: room == null || widget.busy
                                      ? null
                                      : () => widget.onDateSelected(date),
                                  child: Tooltip(
                                    message: facts?.status.label ?? '尚未選擇房間',
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            color: selected ? opsBlue : opsInk,
                                            fontWeight: selected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _legend(),
          const SizedBox(height: 20),
          const Divider(color: opsLine),
          const SizedBox(height: 14),
          _title('近期訂單', Icons.event_note_outlined),
          const SizedBox(height: 10),
          if (room == null)
            const OperationsEmpty(
              title: '選一間房，開始查看',
              message: '房間的預訂日期與近期訂單會一起顯示在這裡。',
              compact: true,
            )
          else
            ..._upcoming(room),
        ],
      ),
    );
  }

  List<Widget> _upcoming(OperationsRoom room) {
    final orders =
        data.bookings
            .where(
              (order) =>
                  order.data['roomId'] == room.id &&
                  workbenchBookingEnd(
                        order.data,
                      )?.isAfter(data.date.subtract(const Duration(days: 1))) ==
                      true,
            )
            .toList()
          ..sort(
            (a, b) => (workbenchBookingStart(a.data) ?? data.date).compareTo(
              workbenchBookingStart(b.data) ?? data.date,
            ),
          );
    if (orders.isEmpty) {
      return [
        const OperationsEmpty(
          title: '近期還沒有預訂',
          message: '下一筆有效訂單會自動出現在這裡。\n你仍可查看房況，或管理房間開放日期。',
          compact: true,
        ),
      ];
    }
    return [
      for (final order in orders.take(4))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: InkWell(
            onTap: () => widget.onOrder(order),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFE),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: opsBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${opsOrderRange(order.data)}  ${opsPets(order.data)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: opsInk),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: opsMuted),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  Widget _legend() => RoomStatusLegend(palette: data.palette, fontSize: 10);

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    Widget? action,
  }) => OperationsSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(title, icon, action: action),
        const SizedBox(height: 15),
        ...children,
      ],
    ),
  );

  Widget _roomDetails(OperationsRoom? room) {
    if (room == null) {
      return OperationsSurface(
        child: const Center(
          child: OperationsEmpty(
            title: '每一天，都照顧得剛剛好',
            message: '選擇房間後，在這裡查看訂單、\n照護回報與房務操作。',
            icon: Icons.pets_outlined,
          ),
        ),
      );
    }
    final facts = data.day(room, data.date);
    final care = data.careItems
        .where((item) => item.roomId == room.id)
        .toList();
    final status = facts.status.presentation;
    return ListView(
      children: [
        OperationsSurface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${room.name}・${opsShortDate(data.date)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: opsInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${room.type}　所選日期房況',
                      style: const TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OperationsBadge(status.label, color: facts.status.color),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section('訂單與入住資訊', Icons.description_outlined, [
          if (facts.orders.isEmpty)
            const OperationsEmpty(
              title: '今天還沒有小房客',
              message: '所選日期沒有有效訂單。\n有預訂後，入住資訊與寵物資料會在這裡顯示。',
              compact: true,
            )
          else
            for (final order in facts.orders) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pets, size: 18, color: opsBlue),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            opsPets(order.data).isEmpty
                                ? '寵物資料請見訂單'
                                : opsPets(order.data),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: opsInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _info(
                      '訂單編號',
                      (order.data['bookingCode'] ?? order.id).toString(),
                    ),
                    _info('服務期間', opsOrderRange(order.data)),
                    if ((order.data['customerName'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _info('聯絡人', order.data['customerName'].toString()),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _action('查看訂單', () => widget.onOrder(order),
                      primary: true, icon: Icons.receipt_long_outlined),
                  if (widget.onOrderCare != null)
                    _action('查看照護', () => widget.onOrderCare!(order),
                        icon: Icons.pets_outlined),
                ],
              ),
              if (order != facts.orders.last) const SizedBox(height: 12),
            ],
        ]),
        const SizedBox(height: 12),
        _section('今日照護回報', Icons.assignment_outlined, [
          if (care.isEmpty)
            OperationsEmpty(
              title: data.report?.hasError == true
                  ? '照護資料暫時讀取不到'
                  : data.report?.settingEnabled != true
                  ? '每日回報尚未啟用'
                  : !data.isToday
                  ? '歷史回報請至回報中心查詢'
                  : '目前沒有待填場次',
              message: data.report?.hasError == true
                  ? '請稍後重試，或至每日回報中心查看。'
                  : data.report?.settingEnabled != true
                  ? '啟用後，符合資格的入住訂單會顯示照護場次。'
                  : !data.isToday
                  ? '前往每日回報中心，查詢指定日期的照護紀錄。'
                  : '有符合資格的入住與照護場次時，\n會在這裡提醒你填寫。',
              icon: Icons.task_alt,
              compact: true,
            )
          else
            for (final item in care)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sessionName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: opsInk,
                            ),
                          ),
                          const SizedBox(height: 5),
                          OperationsBadge(
                            item.statusLabel,
                            color: item.isCompleted
                                ? Colors.green.shade700
                                : const Color(0xFFDC8D20),
                          ),
                        ],
                      ),
                    ),
                    _action(
                      item.canFill ? '填寫回報' : '查看回報',
                      () => widget.onCare(item),
                      primary: item.canFill,
                      icon: Icons.edit_note_outlined,
                    ),
                  ],
                ),
              ),
          if (care.isEmpty && data.report?.settingEnabled == true)
            _action('前往每日回報', widget.onReports, icon: Icons.arrow_forward),
        ]),
        const SizedBox(height: 12),
        _section('房務作業', Icons.cleaning_services_outlined, [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: facts.status.color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(status.icon, color: facts.status.color, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '房間狀態：${status.label}',
                    style: TextStyle(
                      color: facts.status.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!facts.status.canEditStatus)
            const Text(
              '歷史日期僅供查詢，無法變更房況。',
              style: TextStyle(color: opsMuted, fontSize: 12),
            )
          else if (facts.hasBooking ||
              const [
                'occupied',
                'checked_in',
                'daycare',
                'daycare_checked_in',
                'checkout_cleaning',
              ].contains(status.value))
            const Text(
              '此日有預訂、入住或退房清潔保留，請依原訂單與房務流程處理。',
              style: TextStyle(color: opsMuted, height: 1.6, fontSize: 12),
            )
          else if (status.value == 'cleaning')
            _action(
              '完成清潔',
              () => widget.onRoomStatus(room, 'cleaning_complete'),
              primary: true,
              icon: Icons.check,
            )
          else if (const ['closed', 'maintenance'].contains(status.value))
            _action(
              '管理房況與恢復開放',
              () => widget.onRoomRecord(room),
              icon: Icons.build_outlined,
            )
          else if (status.value == 'available')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _action(
                  '關閉此日',
                  () => widget.onRoomStatus(room, 'closed'),
                  icon: Icons.block,
                ),
                _action(
                  '設為維修中',
                  () => widget.onRoomStatus(room, 'maintenance'),
                  icon: Icons.build_outlined,
                ),
              ],
            )
          else
            _action(
              '查看房務操作',
              () => widget.onRoomRecord(room),
              icon: Icons.settings_outlined,
            ),
        ]),
        const SizedBox(height: 12),
        OperationsSurface(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.history, size: 20, color: opsBlue),
              title: const Text(
                '房務操作紀錄',
                style: TextStyle(
                  color: opsInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text(
                  '查看這個房間的完整操作紀錄與歷史日期。',
                  style: TextStyle(color: opsMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _action(
                  '查看房間紀錄',
                  () => widget.onRoomRecord(room),
                  icon: Icons.history,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: opsMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(color: opsInk, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );

  void _showRoom(OperationsRoom room) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: opsBackground,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .87,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _roomDetails(room),
        ),
      ),
    );
  }

  Widget _taskBoard(bool narrow) {
    final tasks = data.tasks
        .where(
          (task) =>
              (_taskState == null || task.state == _taskState) &&
              _matches(
                '${task.roomName} ${task.pets} ${task.title} ${task.booking?.id ?? ''}',
              ) &&
              (_type == '全部' ||
                  data.rooms.any(
                    (room) => room.id == task.roomId && room.type == _type,
                  )),
        )
        .toList();
    return OperationsSurface(
      child: ListView(
        children: [
          _title('今日待辦任務', Icons.checklist_outlined),
          const SizedBox(height: 6),
          Text(
            data.isToday
                ? '抵達與離店、房務清潔與照護回報，依工作類型集中處理。'
                : '正在查看 ${opsShortDate(data.date)} 的任務；照護歷史請至每日回報中心。',
            style: const TextStyle(color: opsMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                ('待處理', OperationsTaskState.pending),
                ('進行中', OperationsTaskState.active),
                ('已完成', OperationsTaskState.completed),
              ])
                ChoiceChip(
                  label: Text(
                    '${entry.$1}  ${data.tasks.where((task) => task.state == entry.$2).length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _taskState == entry.$2,
                  selectedColor: const Color(0xFFEAF0FF),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _taskState == entry.$2 ? opsBlue : opsLine,
                  ),
                  onSelected: (_) => setState(() => _taskState = entry.$2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _searchBox(),
          const SizedBox(height: 14),
          if (!narrow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 65,
                    child: Text(
                      '時間',
                      style: TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '房號／寵物',
                      style: TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '任務內容',
                      style: TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: Text(
                      '狀態／操作',
                      style: TextStyle(color: opsMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          for (final group in OperationsTaskGroup.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    [
                      Icons.login_outlined,
                      Icons.cleaning_services_outlined,
                      Icons.assignment_outlined,
                    ][group.index],
                    size: 18,
                    color: opsBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${['抵達與離店', '房務清潔', '照護回報'][group.index]}（${tasks.where((task) => task.group == group).length}）',
                      style: const TextStyle(
                        color: opsInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!tasks.any((task) => task.group == group))
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: opsLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: OperationsEmpty(
                  title: ['目前沒有抵達或離店任務', '目前沒有房務任務', '目前沒有照護任務'][group.index],
                  message: group == OperationsTaskGroup.care && !data.isToday
                      ? '歷史場次請由每日回報中心查詢。'
                      : '此分類沒有符合目前條件的任務。\n新的工作會自動顯示在這裡。',
                  compact: true,
                  icon: [
                    Icons.event_available_outlined,
                    Icons.cleaning_services_outlined,
                    Icons.task_alt,
                  ][group.index],
                ),
              )
            else
              for (final task in tasks.where((task) => task.group == group))
                _taskRow(task, narrow),
          ],
        ],
      ),
    );
  }

  void _runTask(OperationsTask task) {
    if (task.booking != null) {
      widget.onOrder(task.booking!);
    } else if (task.care != null) {
      widget.onCare(task.care!);
    } else {
      final rooms = data.rooms.where((room) => room.id == task.roomId);
      if (rooms.isNotEmpty) widget.onRoomRecord(rooms.first);
    }
  }

  Widget _taskRow(OperationsTask task, bool narrow) {
    final room = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.roomName,
          style: const TextStyle(
            color: opsInk,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          task.pets.isEmpty ? '—' : task.pets,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: opsMuted, fontSize: 12),
        ),
      ],
    );
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: const TextStyle(
            color: opsInk,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          task.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: opsMuted, height: 1.5, fontSize: 11),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: _selectedTask == task.id
            ? const Color(0xFFEFF4FF)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: _selectedTask == task.id ? opsBlue : opsLine),
        ),
        child: InkWell(
          onTap: () {
            setState(() => _selectedTask = task.id);
            if (task.roomId.isNotEmpty) widget.onSelectRoom(task.roomId);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: room),
                          OperationsBadge(task.time),
                        ],
                      ),
                      const SizedBox(height: 10),
                      contents,
                      const SizedBox(height: 10),
                      _action(task.action, () => _runTask(task)),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 65,
                        child: Text(
                          task.time,
                          style: const TextStyle(color: opsInk, fontSize: 13),
                        ),
                      ),
                      Expanded(flex: 3, child: room),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: contents),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 104,
                        child: _action(task.action, () => _runTask(task)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _roomGrid() => OperationsSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          '房況總覽',
          Icons.hotel_outlined,
          action: Text(
            '${data.rooms.length} 間',
            style: const TextStyle(color: opsMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),
        if (data.rooms.isEmpty)
          const OperationsEmpty(
            title: '房間準備中',
            message: '建立房間後，即可一眼掌握每間房況。',
            compact: true,
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, box) => Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final room in _rooms)
                      SizedBox(
                        width: (box.maxWidth - 14) / 3,
                        child: _gridRoom(room),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _gridRoom(OperationsRoom room) {
    final facts = data.day(room, data.date);
    return Material(
      color: facts.status.color.withValues(alpha: .065),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: _selected?.id == room.id
              ? opsBlue
              : facts.status.color.withValues(alpha: .2),
        ),
      ),
      child: InkWell(
        onTap: () {
          widget.onSelectRoom(room.id);
          setState(() => _selectedTask = null);
        },
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            children: [
              Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: opsInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                facts.status.presentation.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: facts.status.color, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskDetail() {
    final matching = data.tasks.where((task) => task.id == _selectedTask);
    if (matching.isEmpty) {
      return _section('選取任務詳情', Icons.touch_app_outlined, [
        const OperationsEmpty(
          title: '今天的工作，一件件完成',
          message: '點選左側任務，查看相關訂單與操作入口。\n沒有任務時，也可以從房況總覽選擇房間。',
          compact: true,
        ),
        if (_selected != null)
          _action(
            '查看 ${_selected!.name} 房務',
            () => _showRoom(_selected!),
            icon: Icons.meeting_room_outlined,
          ),
      ]);
    }
    final task = matching.first;
    return _section('選取任務詳情', Icons.touch_app_outlined, [
      Text(
        '${task.roomName}　${task.pets}',
        style: const TextStyle(
          color: opsInk,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      OperationsBadge(task.title),
      const SizedBox(height: 14),
      Text(
        task.subtitle,
        style: const TextStyle(color: opsMuted, height: 1.7, fontSize: 13),
      ),
      const SizedBox(height: 18),
      _action(task.action, () => _runTask(task), primary: true),
    ]);
  }

  Widget _timeline(bool narrow) {
    final rooms = _rooms;
    final days = _days;
    return OperationsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('房況時間表', Icons.calendar_view_week_outlined),
          const SizedBox(height: 6),
          const Text(
            '以日期對照各房預訂、清潔與維修；點選日期格查看當日房務。',
            style: TextStyle(color: opsMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          _searchBox(),
          const SizedBox(height: 14),
          _legend(),
          const SizedBox(height: 16),
          Expanded(
            child: rooms.isEmpty
                ? OperationsEmpty(
                    title: data.rooms.isEmpty ? '房況時間表，等你準備好' : '找不到符合條件的房間',
                    message: data.rooms.isEmpty
                        ? '新增房間後，預訂、空房與清潔狀態會在這裡排成清楚的時間表。'
                        : '調整搜尋或篩選，就能繼續查看其他房間。',
                    icon: Icons.calendar_view_week_outlined,
                  )
                : OperationsTimeline(
                    data: data,
                    rooms: rooms,
                    days: days,
                    selectedRoomId: _selected?.id ?? '',
                    onSelect: (room, day) {
                      widget.onSelectRoom(room.id);
                      widget.onDateSelected(day);
                      if (narrow) _showRoomAt(room, day);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showRoomAt(OperationsRoom room, DateTime day) {
    // Wait for the parent to supply the newly selected date before opening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRoom(room);
    });
  }

  void _openTaskPage(WidgetBuilder builder) {
    if (widget.onTaskPage case final open?) {
      open(builder);
    } else {
      Navigator.of(context).push<void>(MaterialPageRoute(builder: builder));
    }
  }

  List<_ShiftEntry> _shiftEntries() {
    final entries = <_ShiftEntry>[
      for (final task in data.tasks)
        (
          time: task.time,
          title: task.title,
          context: [task.roomName, task.pets].where((part) => part.isNotEmpty).join(' · '),
          action: task.action,
          icon: switch (task.group) {
            OperationsTaskGroup.arrivals => Icons.swap_horiz,
            OperationsTaskGroup.housekeeping => Icons.cleaning_services_outlined,
            OperationsTaskGroup.care => Icons.assignment_outlined,
          },
          attention: task.group == OperationsTaskGroup.housekeeping,
          complete: task.state == OperationsTaskState.completed ||
              (task.group == OperationsTaskGroup.arrivals &&
                  task.state == OperationsTaskState.active),
          run: () {
            if (task.booking != null && task.order == 1 && widget.onOrderDeparture != null) {
              widget.onOrderDeparture!(task.booking!);
            } else {
              _runTask(task);
            }
          },
        ),
    ];
    final day = opsDateKey(data.date);
    final now = DateTime.now();
    for (final order in data.bookings) {
      if (widget.canManageOrder?.call(order.data) != true) continue;
      final room = '${order.data['roomName'] ?? '待分房'}';
      final rawMedication = order.data['medication'];
      final legacy = order.data['medicationRequest'];
      final review = rawMedication is Map
          ? rawMedication['state']
          : legacy is Map && legacy.isNotEmpty ? 'pending_shop' : null;
      if (data.isToday &&
          review == 'pending_shop' &&
          const {'pending', 'confirmed', 'checked_in'}.contains(order.data['status'])) {
        entries.add((
          time: '—',
          title: '用藥安排待確認',
          context: '$room · ${opsPets(order.data)}',
          action: '查看用藥交接',
          icon: Icons.medication_outlined,
          attention: true,
          complete: false,
          run: () => _openTaskPage((_) => MedicationTaskPage.arrangement(
            shopId: widget.shopId,
            bookingId: order.id,
          )),
        ));
      }
      for (final task in BookingMedicationTask.fromBooking(order.data)) {
        if (BookingMedicationTask.dateKey(BookingMedicationTask.taipei(task.scheduledAt)) != day) continue;
        if (!task.pending && !task.finished) continue;
        entries.add((
          time: BookingMedicationTask.timeLabel(task.scheduledAt),
          title: task.types.isEmpty ? '用藥' : task.types,
          context: '$room · ${task.pet}',
          action: task.pending ? '登記用藥' : '查看紀錄',
          icon: Icons.medication_outlined,
          attention: task.pending && !task.scheduledAt.isAfter(now),
          complete: !task.pending,
          run: () => openCareReportResult(
            context,
            shopId: widget.shopId,
            bookingId: order.id,
            taskId: task.id,
            medication: true,
          ),
        ));
      }
      for (final task in BookingServiceTask.fromBooking(order.data)) {
        if (task.day != day) continue;
        entries.add((
          time: BookingMedicationTask.timeLabel(task.scheduledAt),
          title: task.title,
          context: '$room · ${task.pet}',
          action: task.pending ? '登記照護' : '查看紀錄',
          icon: Icons.pets_outlined,
          attention: task.pending && !task.scheduledAt.isAfter(now),
          complete: !task.pending,
          run: () => openCareReportResult(
            context,
            shopId: widget.shopId,
            bookingId: order.id,
            taskId: task.id,
            medication: false,
          ),
        ));
      }
    }
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  Widget _shift() => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 900;
      final entries = _shiftEntries();
      final colors = Theme.of(context).colorScheme;
      Widget group(String title, bool Function(bool, bool) include, {bool collapsed = false}) {
        final items = entries.where((entry) => include(entry.attention, entry.complete)).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final rows = [
          for (final entry in items)
            ListTile(
              leading: SizedBox(
                width: 48,
                child: Text(entry.time, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(entry.context),
              trailing: bounds.maxWidth < 680
                  ? Tooltip(message: entry.action, child: Icon(entry.icon, size: 20))
                  : TextButton.icon(
                      onPressed: widget.busy ? null : entry.run,
                      icon: Icon(entry.icon, size: 17),
                      label: Text(entry.action),
                    ),
              onTap: widget.busy ? null : entry.run,
              titleAlignment: ListTileTitleAlignment.center,
            ),
        ];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: collapsed
              ? ExpansionTile(title: Text('$title · ${items.length}'), children: rows)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      rows[i],
                    ],
                  ],
                ),
        );
      }

      final rooms = Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('房況', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: TextButton(onPressed: widget.onRoomView, child: const Text('查看房況')),
            ),
            for (final room in data.rooms)
              ListTile(
                dense: true,
                leading: Icon(Icons.meeting_room_outlined, color: data.day(room, data.date).status.color),
                title: Text(room.name),
                trailing: Text(data.day(room, data.date).status.presentation.label),
                onTap: () {
                  widget.onSelectRoom(room.id);
                  _showRoom(room);
                },
              ),
          ],
        ),
      );
      final queue = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group('需要處理', (attention, complete) => attention && !complete),
          group('今日行程', (attention, complete) => !attention && !complete),
          if (!entries.any((entry) => !entry.complete))
            const Card(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('這一天沒有待處理的行程'),
            )),
          group('已完成', (_, complete) => complete, collapsed: true),
          if (widget.careTasks case final careTasks?)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.pets_outlined),
                title: const Text('所有照護待辦'),
                children: [careTasks],
              ),
            ),
        ],
      );

      return ColoredBox(
        color: opsBackground,
        child: ListView(
          padding: EdgeInsets.all(wide ? 22 : 12),
          children: [
            Container(
              padding: EdgeInsets.all(wide ? 24 : 16),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text(data.isToday ? '今日營運' : '營運行程',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: colors.onPrimaryContainer)),
                  OutlinedButton.icon(
                    onPressed: widget.busy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text('${data.date.year}/${opsShortDate(data.date)}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 18,
                children: [
                  Expanded(flex: 2, child: queue),
                  Expanded(child: rooms),
                ],
              )
            else ...[
              queue,
              const SizedBox(height: 10),
              rooms,
            ],
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => widget.shift ? _shift() : LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 1150;
      final medium = box.maxWidth >= 800;
      final room = _selected;
      Widget body;
      if (widget.view == WorkbenchView.rooms) {
        body = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 286, child: _roomList(narrow: false)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: _monthCalendar(room)),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _roomDetails(room)),
                      ],
                    ),
                  ),
                ],
              )
            : medium
            ? Row(
                children: [
                  Expanded(flex: 4, child: _roomList(narrow: true)),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: _monthCalendar(room)),
                ],
              )
            : _roomList(narrow: true);
      } else if (widget.view == WorkbenchView.tasks) {
        body = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 66, child: _taskBoard(false)),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 34,
                    child: ListView(
                      children: [
                        _roomGrid(),
                        const SizedBox(height: 14),
                        _taskDetail(),
                      ],
                    ),
                  ),
                ],
              )
            : _taskBoard(box.maxWidth < 700);
      } else {
        body = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 74, child: _timeline(false)),
                  const SizedBox(width: 14),
                  Expanded(flex: 26, child: _roomDetails(room)),
                ],
              )
            : _timeline(true);
      }
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
          },
        ),
        child: ColoredBox(
        color: opsBackground,
        child: Padding(
          padding: EdgeInsets.all(wide ? 18 : 10),
          child: Column(
            children: [
              // On a short mobile viewport keep controls reachable without consuming
              // the work area: filters remain available in a scrollable toolbar.
              SizedBox(
                height: wide ? null : 60,
                child: wide
                    ? _toolbar()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: widget.view == WorkbenchView.timeline
                              ? 1130
                              : 1000,
                          child: _toolbar(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (box.maxHeight >= 620) ...[
                _statsRow(),
                const SizedBox(height: 14),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
      );
    },
  );
}

class OperationsTimeline extends StatefulWidget {
  const OperationsTimeline({
    super.key,
    required this.data,
    required this.rooms,
    required this.days,
    required this.selectedRoomId,
    required this.onSelect,
  });
  final OperationsWorkbenchData data;
  final List<OperationsRoom> rooms;
  final List<DateTime> days;
  final String selectedRoomId;
  final void Function(OperationsRoom, DateTime) onSelect;

  @override
  State<OperationsTimeline> createState() => _OperationsTimelineState();
}

class _OperationsTimelineState extends State<OperationsTimeline> {
  final _horizontal = ScrollController();
  OperationsWorkbenchData get data => widget.data;
  List<OperationsRoom> get rooms => widget.rooms;
  List<DateTime> get days => widget.days;
  String get selectedRoomId => widget.selectedRoomId;
  void Function(OperationsRoom, DateTime) get onSelect => widget.onSelect;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const roomWidth = 142.0;
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final rowHeight = 76.0 + math.max(0.0, textScale - 1) * 48;
      final headerHeight = 59.0 + math.max(0.0, textScale - 1) * 32;
      final dayWidth = math.max(
        108.0,
        (box.maxWidth - roomWidth) / days.length,
      );
      final width = roomWidth + dayWidth * days.length;
      Widget cell(
        Widget child, {
        double? width,
        Color color = Colors.white,
        double? height,
      }) => Container(
        width: width ?? dayWidth,
        height: height ?? rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: const Border(
            right: BorderSide(color: opsLine),
            bottom: BorderSide(color: opsLine),
          ),
        ),
        child: child,
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: opsLine)),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              dragDevices: {
                ...ScrollConfiguration.of(context).dragDevices,
                PointerDeviceKind.mouse,
              },
            ),
            child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: width > box.maxWidth + 0.5,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(bottom: width > box.maxWidth + 0.5 ? 12 : 0),
                child: SizedBox(
                  width: width,
              child: Column(
                children: [
                  Row(
                    children: [
                      cell(
                        const Text(
                          '房間／房型',
                          style: TextStyle(
                            color: opsInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        width: roomWidth,
                        height: headerHeight,
                        color: const Color(0xFFF7F9FD),
                      ),
                      for (final day in days)
                        cell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                opsShortDate(day),
                                style: TextStyle(
                                  color: DateUtils.isSameDay(day, data.date)
                                      ? opsBlue
                                      : opsInk,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '週${['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}',
                                style: const TextStyle(
                                  color: opsMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          height: headerHeight,
                          color: DateUtils.isSameDay(day, data.date)
                              ? const Color(0xFFE7EFFF)
                              : const Color(0xFFF7F9FD),
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final type
                            in rooms.map((room) => room.type).toSet()) ...[
                          Container(
                            width: width,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            color: const Color(0xFFEEEDF9),
                            child: Text(
                              '$type（${rooms.where((room) => room.type == type).length} 間）',
                              style: const TextStyle(
                                color: Color(0xFF65608A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final room in rooms.where(
                            (room) => room.type == type,
                          ))
                            Row(
                              children: [
                                cell(
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          room.name,
                                          style: const TextStyle(
                                            color: opsInk,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          data
                                              .day(room, data.date)
                                              .status
                                              .presentation
                                              .label,
                                          style: TextStyle(
                                            color: data
                                                .day(room, data.date)
                                                .status
                                                .color,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  width: roomWidth,
                                  color: room.id == selectedRoomId
                                      ? const Color(0xFFEDF3FF)
                                      : Colors.white,
                                ),
                                SizedBox(
                                  width: dayWidth * days.length,
                                  height: rowHeight,
                                  child: Stack(
                                    children: [
                                      Row(
                                        children: [
                                          for (final day in days)
                                            cell(
                                              _dayCell(room, day),
                                              color:
                                                  DateUtils.isSameDay(
                                                    day,
                                                    data.date,
                                                  )
                                                  ? const Color(0xFFF1F5FE)
                                                  : Colors.white,
                                            ),
                                        ],
                                      ),
                                      ..._bars(room, dayWidth, rowHeight),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
      );
    },
  );
  Widget _dayCell(OperationsRoom room, DateTime day) {
    final facts = data.day(room, day);
    final label = facts.orders.length > 1
        ? '${facts.orders.length} 筆訂單'
        : facts.status.label;
    return InkWell(
      onTap: () => onSelect(room, day),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: facts.status.color.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(7),
          border:
              room.id == selectedRoomId && DateUtils.isSameDay(day, data.date)
              ? Border.all(color: opsBlue, width: 1.4)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          facts.spanId.isEmpty ? label : '',
          textAlign: TextAlign.center,
          style: TextStyle(color: facts.status.color, fontSize: 11),
        ),
      ),
    );
  }

  List<Widget> _bars(OperationsRoom room, double dayWidth, double rowHeight) {
    final bars = <Widget>[];
    var first = 0;
    while (first < days.length) {
      final start = first;
      final facts = data.day(room, days[start]);
      final id = facts.spanId;
      if (id.isEmpty) {
        first++;
        continue;
      }
      var end = start + 1;
      while (end < days.length && data.day(room, days[end]).spanId == id) {
        end++;
      }
      final color = facts.status.color;
      final label = facts.pets.isEmpty ? '已預訂' : facts.pets;
      bars.add(
        Positioned(
          left: start * dayWidth + 4,
          top: (rowHeight - 46) / 2,
          width: (end - start) * dayWidth - 8,
          height: 46,
          child: Material(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
            child: Tooltip(
              message: '$label・${opsOrderRange(facts.preferred!.data)}',
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (var index = start; index < end; index++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label:
                                  '${room.name} ${opsShortDate(days[index])} $label',
                              child: InkWell(
                                onTap: () => onSelect(room, days[index]),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$label　${opsOrderRange(facts.preferred!.data)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      first = end;
    }
    return bars;
  }
}
