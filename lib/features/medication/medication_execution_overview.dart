import 'package:flutter/material.dart';

class MedicationExecutionOverview extends StatefulWidget {
  const MedicationExecutionOverview({
    super.key,
    required this.tasks,
    required this.petName,
    required this.medicineLabel,
    this.initialFilter = 'all',
    this.onRecord,
  });
  final List<Map<String, dynamic>> tasks;
  final String Function(Object?) petName;
  final String Function(Map<String, dynamic>) medicineLabel;
  final String initialFilter;
  final ValueChanged<Map<String, dynamic>>? onRecord;
  @override
  State<MedicationExecutionOverview> createState() =>
      _MedicationExecutionOverviewState();
}

class _MedicationExecutionOverviewState
    extends State<MedicationExecutionOverview> {
  late String filter =
      widget.initialFilter == 'pending' &&
          !widget.tasks.any((t) => state(t) == 'pending')
      ? 'all'
      : widget.initialFilter;
  @override
  void didUpdateWidget(covariant MedicationExecutionOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tasks, widget.tasks) &&
        statuses.containsKey(filter) &&
        !widget.tasks.any((t) => state(t) == filter)) {
      filter = 'all';
    }
  }

  static const statuses = {
    'done': ('成功', Color(0xFF237546), Icons.check_circle_outline),
    'failed': ('未成功', Color(0xFFB33B34), Icons.error_outline),
    'skipped': ('未執行', Color(0xFF626975), Icons.pause_circle_outline),
    'pending': ('待補登', Color(0xFF365FA5), Icons.edit_note),
    'partial': ('部分成功', Color(0xFF946000), Icons.rule),
    'review': ('待確認', Color(0xFF946000), Icons.pending_outlined),
  };
  String state(Map<String, dynamic> task) => switch (task['result']) {
    'done' => 'done',
    'failed' => 'failed',
    'skipped' => 'skipped',
    'partial' => task['finished'] == true ? 'partial' : 'review',
    'mixed' => 'review',
    _ => 'pending',
  };
  DateTime? date(Object? value) =>
      DateTime.tryParse('$value')?.toUtc().add(const Duration(hours: 8));
  String day(Map<String, dynamic> task) {
    final d = date(task['scheduledAt']);
    return d == null
        ? '日期待確認'
        : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String clock(Object? raw) {
    final d = date(raw);
    return d == null
        ? '時間待確認'
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final shown =
        widget.tasks
            .where(
              (t) =>
                  filter == 'all' ||
                  (filter == 'today' ? day(t) == today : state(t) == filter),
            )
            .toList()
          ..sort(
            (a, b) => '${a['scheduledAt']}'.compareTo('${b['scheduledAt']}'),
          );
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final task in shown) {
      groups.putIfAbsent(day(task), () => []).add(task);
    }
    final unresolved = widget.tasks
        .where(
          (t) =>
              t['finished'] != true && ['pending', 'review'].contains(state(t)),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '用藥執行總覽',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text('共 ${widget.tasks.length} 項・尚有 $unresolved 項待完成確認'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in statuses.entries)
              ChoiceChip(
                avatar: Icon(entry.value.$3, size: 18, color: entry.value.$2),
                label: Text(
                  '${entry.value.$1} ${widget.tasks.where((t) => state(t) == entry.key).length}',
                ),
                labelStyle: TextStyle(
                  color: entry.value.$2,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: entry.value.$2.withValues(alpha: .06),
                selectedColor: entry.value.$2.withValues(alpha: .18),
                selected: filter == entry.key,
                onSelected: (_) => setState(
                  () => filter = filter == entry.key ? 'all' : entry.key,
                ),
              ),
            ChoiceChip(
              label: Text('全部 ${widget.tasks.length}'),
              selected: filter == 'all',
              onSelected: (_) => setState(() => filter = 'all'),
            ),
            ChoiceChip(
              label: const Text('今日'),
              selected: filter == 'today',
              onSelected: (_) => setState(() => filter = 'today'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('這個分類沒有用藥紀錄')),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${group.key}・${group.value.length} 項',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final task in group.value)
            Builder(
              builder: (context) {
                final status = statuses[state(task)]!;
                final pending =
                    task['finished'] != true &&
                    ['pending', 'review'].contains(state(task));
                final hasDetails =
                    task['actualAt'] != null ||
                    task['by'] != null ||
                    '${task['note'] ?? ''}'.trim().isNotEmpty ||
                    task['medicineResults'] is Map;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: status.$2.withValues(alpha: .25)),
                    borderRadius: BorderRadius.circular(12),
                    color: status.$2.withValues(alpha: .035),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 460;
                            final title = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${clock(task['scheduledAt'])}  ${widget.petName(task['petId'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(widget.medicineLabel(task)),
                              ],
                            );
                            final badge = Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: status.$2.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(status.$3, size: 17, color: status.$2),
                                  const SizedBox(width: 5),
                                  Text(
                                    status.$1,
                                    style: TextStyle(
                                      color: status.$2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            final action = pending && widget.onRecord != null
                                ? Tooltip(
                                    message: '記錄結果',
                                    child: TextButton(
                                      onPressed: () => widget.onRecord!(task),
                                      child: const Text('填寫結果'),
                                    ),
                                  )
                                : null;
                            return narrow
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: title),
                                          const SizedBox(width: 8),
                                          badge,
                                        ],
                                      ),
                                      if (action != null)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: action,
                                        ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: title),
                                      badge,
                                      if (action != null) ...[
                                        const SizedBox(width: 12),
                                        action,
                                      ],
                                    ],
                                  );
                          },
                        ),
                      ),
                      if (hasDetails)
                        ExpansionTile(
                          dense: true,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: const Text(
                            '執行時間與備註',
                            style: TextStyle(fontSize: 12),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task['actualAt'] != null)
                                    Text('實際時間：${clock(task['actualAt'])}'),
                                  if (task['by'] != null)
                                    Text('執行人：${task['byName'] ?? '店家人員'}'),
                                  if ('${task['note'] ?? ''}'.trim().isNotEmpty)
                                    Text('${task['note']}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}
