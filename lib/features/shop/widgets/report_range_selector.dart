// lib/features/shop/widgets/report_range_selector.dart
// 📅 報表期間選擇器
// 功能：提供今天、本週、本月、今年、自訂日期範圍選擇

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/report_range.dart';

class ReportRangeSelector extends StatelessWidget {
  const ReportRangeSelector({
    super.key,
    required this.range,
    required this.onChanged,
  });

  final ReportRange range;
  final ValueChanged<ReportRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy/MM/dd');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _RangeChip(
              label: '今天',
              selected: range.type == ReportRangeType.today,
              onTap: () => onChanged(ReportRange.today()),
            ),
            _RangeChip(
              label: '本週',
              selected: range.type == ReportRangeType.thisWeek,
              onTap: () => onChanged(ReportRange.thisWeek()),
            ),
            _RangeChip(
              label: '本月',
              selected: range.type == ReportRangeType.thisMonth,
              onTap: () => onChanged(ReportRange.thisMonth()),
            ),
            _RangeChip(
              label: '今年',
              selected: range.type == ReportRangeType.thisYear,
              onTap: () => onChanged(ReportRange.thisYear()),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                range.type == ReportRangeType.custom
                    ? '${formatter.format(range.startDate)} ~ ${formatter.format(range.endDate)}'
                    : '自訂',
              ),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: DateTimeRange(
                    start: range.startDate,
                    end: range.endDate,
                  ),
                );

                if (picked == null) return;

                onChanged(
                  ReportRange.custom(
                    startDate: picked.start,
                    endDate: picked.end,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
