import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/models/daily_care_report_center_item.dart';
import 'admin_booking_schedule.dart';

/// Date rows with session columns for one booking, independent of data loading.
class OrderDailyCareProgressTable extends StatelessWidget {
  const OrderDailyCareProgressTable({
    super.key,
    required this.sessions,
    required this.onSelect,
  });
  final List<DailyCareReportCenterItem> sessions;
  final ValueChanged<DailyCareReportCenterItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('這筆訂單目前沒有每日回報場次'),
      );
    }
    final sorted = [...sessions]
      ..sort((a, b) {
        final date = a.recordDate.compareTo(b.recordDate);
        return date == 0 ? a.sessionIndex.compareTo(b.sessionIndex) : date;
      });
    String day(DailyCareReportCenterItem item) =>
        '${item.recordDate.year}-${item.recordDate.month.toString().padLeft(2, '0')}-${item.recordDate.day.toString().padLeft(2, '0')}';
    final days = sorted.map(day).toSet().toList();
    final indices = sorted.map((item) => item.sessionIndex).toSet().toList()
      ..sort();
    final completed = sorted.where((item) => item.isCompleted).length;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  '每日照護回報',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '已完成 $completed/${sorted.length} 場',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completed / sorted.length,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            _ProgressMatrix(
              headers: ['日期', for (final index in indices) '第${index + 1}次照護'],
              rows: [
                for (final date in days)
                  [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        date.substring(5).replaceAll('-', '/'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final index in indices)
                      Builder(
                        builder: (context) {
                          final item = sorted
                              .where(
                                (item) =>
                                    day(item) == date &&
                                    item.sessionIndex == index,
                              )
                              .firstOrNull;
                          if (item == null) {
                            return const Center(child: Text('—'));
                          }
                          final enabled = item.reportsLocked
                              ? item.isCompleted
                              : item.canOperate;
                          return _ProgressAction(
                            title: item.reportsLocked && !item.isCompleted
                                ? '已鎖定'
                                : item.isCompleted
                                ? '已完成'
                                : '＋ 填寫',
                            subtitle:
                                '${item.photoCount}/${item.maxPhotos} 張照片',
                            completed: item.isCompleted,
                            locked: item.reportsLocked,
                            onTap: enabled ? () => onSelect(item) : null,
                          );
                        },
                      ),
                  ],
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '點選格子填寫或查看紀錄；時間未指定的回報，於當日完成即可。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date rows with time columns, preserving every pet's individual task.
class OrderCareScheduleProgressTable extends StatelessWidget {
  const OrderCareScheduleProgressTable({
    super.key,
    required this.entries,
    required this.onSelect,
  });
  final List<BookingScheduleEntry> entries;
  final ValueChanged<BookingScheduleEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = entries.map((entry) => entry.day).toSet().toList()..sort();
    final times = entries.map((entry) => entry.timeLabel).toSet().toList()
      ..sort();
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '預約與用藥時程',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ProgressMatrix(
              headers: ['日期', ...times],
              rows: [
                for (final day in days)
                  [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        day.substring(5).replaceAll('-', '/'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final time in times)
                      Builder(
                        builder: (context) {
                          final tasks = entries
                              .where(
                                (entry) =>
                                    entry.day == day && entry.timeLabel == time,
                              )
                              .toList();
                          if (tasks.isEmpty) {
                            return const Center(child: Text('—'));
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final task in tasks)
                                _ProgressAction(
                                  title: task.title,
                                  subtitle:
                                      '${task.detail}\n${task.service?.resultLabel ?? task.medication?.resultLabel ?? (task.completed ? '已記錄' : '待記錄・填寫')}',
                                  completed: task.completed,
                                  result:
                                      task.service?.result ??
                                      task.medication?.result,
                                  onTap: () => onSelect(task),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '點選項目開啟填寫視窗；左右滑動查看其他時間。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMatrix extends StatefulWidget {
  const _ProgressMatrix({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<Widget>> rows;
  @override
  State<_ProgressMatrix> createState() => _ProgressMatrixState();
}

class _ProgressMatrixState extends State<_ProgressMatrix> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final minimum = 68.0 + (widget.headers.length - 1) * 88.0;
      final width = bounds.maxWidth < minimum ? minimum : bounds.maxWidth;
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: {...PointerDeviceKind.values}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (width > bounds.maxWidth)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    if (_controller.hasClients) {
                      _controller.animateTo(
                        (_controller.offset + 220).clamp(
                          0.0,
                          _controller.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('向右查看更多時段'),
                ),
              ),
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Table(
                  border: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {0: FixedColumnWidth(68)},
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                      ),
                      children: [
                        for (final label in widget.headers)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final row in widget.rows) TableRow(children: row),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ProgressAction extends StatelessWidget {
  const _ProgressAction({
    required this.title,
    required this.subtitle,
    required this.completed,
    this.locked = false,
    this.result,
    this.onTap,
  });
  final String title, subtitle;
  final String? result;
  final bool completed, locked;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = result == 'failed'
        ? const Color(0xFFB34A43)
        : result == 'skipped'
        ? const Color(0xFF6D7180)
        : result == 'partial' || result == 'mixed'
        ? const Color(0xFFAA6200)
        : completed
        ? const Color(0xFF237546)
        : locked
        ? const Color(0xFF766A61)
        : const Color(0xFF986414);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
