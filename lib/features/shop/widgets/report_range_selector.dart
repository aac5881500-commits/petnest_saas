// lib/features/shop/widgets/report_range_selector.dart
// 📅 報表期間選擇器

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
    final DateFormat formatter = DateFormat('yyyy/MM/dd');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _chip('今天', ReportRangeType.today, () => ReportRange.today()),
            _chip('昨天', ReportRangeType.yesterday, ReportRange.yesterday),
            _chip('本週', ReportRangeType.thisWeek, ReportRange.thisWeek),
            _chip('上週', ReportRangeType.lastWeek, ReportRange.lastWeek),
            _chip('本月', ReportRangeType.thisMonth, ReportRange.thisMonth),
            _chip('上月', ReportRangeType.lastMonth, ReportRange.lastMonth),
            _chip('近 7 天', ReportRangeType.last7, ReportRange.last7),
            _chip('近 30 天', ReportRangeType.last30, ReportRange.last30),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                range.type == ReportRangeType.custom
                    ? '${formatter.format(range.startDate)} ~ ${formatter.format(range.endDate)}'
                    : '自訂日期',
              ),
              onPressed: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: DateTimeRange(
                    start: range.startDate,
                    end: range.endDate,
                  ),
                );
                if (picked == null) {
                  return;
                }
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

  Widget _chip(
    String label,
    ReportRangeType type,
    ReportRange Function() make,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: range.type == type,
      onSelected: (_) => onChanged(make()),
    );
  }
}
