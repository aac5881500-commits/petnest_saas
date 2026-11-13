import 'package:flutter/material.dart';

enum WorkbenchView {
  original('原本排版', Icons.dashboard_outlined),
  rooms('房間與訂單', Icons.view_column_outlined),
  tasks('今日待辦', Icons.checklist_outlined),
  timeline('房況時間表', Icons.calendar_view_week_outlined);

  const WorkbenchView(this.label, this.icon);
  final String label;
  final IconData icon;
}

class WorkbenchSettingsMenu extends StatelessWidget {
  const WorkbenchSettingsMenu({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onHousekeeping,
    this.enabled = true,
  });
  final WorkbenchView selected;
  final ValueChanged<WorkbenchView> onChanged;
  final VoidCallback onHousekeeping;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '工作台排版與房務設定',
    enabled: enabled,
    icon: const Icon(Icons.settings_outlined),
    onSelected: (value) {
      if (value == 'housekeeping') {
        onHousekeeping();
        return;
      }
      onChanged(WorkbenchView.values.firstWhere((view) => view.name == value));
    },
    itemBuilder: (_) => [
      const PopupMenuItem<String>(enabled: false, child: Text('工作台檢視')),
      for (final view in WorkbenchView.values)
        CheckedPopupMenuItem<String>(
          value: view.name,
          checked: selected == view,
          child: Text(view.label),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(value: 'housekeeping', child: Text('房務設定')),
    ],
  );
}

/// A scrollable weekly overview. Uses the caller's existing
/// room-day resolver so presentation never invents availability or writes data.
class WorkbenchTimeline extends StatelessWidget {
  const WorkbenchTimeline({
    super.key,
    required this.days,
    required this.names,
    required this.types,
    required this.selectedRow,
    required this.selectedDay,
    required this.labelAt,
    required this.colorAt,
    required this.onSelect,
  });
  final List<DateTime> days;
  final List<String> names, types;
  final int selectedRow;
  final DateTime selectedDay;
  final String Function(int, int) labelAt;
  final Color Function(int, int) colorAt;
  final void Function(int, int) onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const labelWidth = 132.0;
      final cellWidth = ((box.maxWidth - labelWidth) / 7).clamp(106.0, 170.0);
      Widget cell(Widget child, {double? width, Color? color}) => Container(
        width: width ?? cellWidth,
        height: 68,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        alignment: Alignment.center,
        child: child,
      );
      return Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: labelWidth + cellWidth * 7,
            child: Column(
              children: [
                Row(
                  children: [
                    cell(const Text('房間／房型'), width: labelWidth),
                    for (final day in days)
                      cell(
                        Text(
                          '${day.month}/${day.day}\n${['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}',
                          textAlign: TextAlign.center,
                        ),
                        color: DateUtils.isSameDay(day, selectedDay)
                            ? const Color(0xFFE4EEFF)
                            : null,
                      ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: names.length,
                    itemBuilder: (context, row) => Row(
                      children: [
                        cell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                names[row],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                types[row],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          width: labelWidth,
                          color: row == selectedRow
                              ? const Color(0xFFE4EEFF)
                              : null,
                        ),
                        for (var col = 0; col < days.length; col++)
                          Semantics(
                            button: true,
                            label:
                                '${names[row]} ${days[col].month}/${days[col].day} ${labelAt(row, col)}',
                            child: InkWell(
                              onTap: () => onSelect(row, col),
                              child: cell(
                                Text(
                                  labelAt(row, col),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorAt(row, col),
                                    fontSize: 12,
                                  ),
                                ),
                                color: colorAt(row, col).withValues(
                                  alpha:
                                      row == selectedRow &&
                                          DateUtils.isSameDay(
                                            days[col],
                                            selectedDay,
                                          )
                                      ? 0.22
                                      : 0.08,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
