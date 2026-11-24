import 'package:flutter/material.dart';
import '../../core/models/booking_medication_task.dart';

/// Combine the task's Taiwan calendar day with a clock time, returning UTC.
DateTime careTimeOnScheduledDay(DateTime scheduledAt, TimeOfDay time) {
  final day = BookingMedicationTask.taipei(scheduledAt);
  return DateTime.utc(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  ).subtract(const Duration(hours: 8));
}

DateTime initialCareActualTime(DateTime scheduledAt, DateTime now) {
  final day = BookingMedicationTask.taipei(scheduledAt);
  final today = BookingMedicationTask.taipei(now);
  final clock =
      BookingMedicationTask.dateKey(day) == BookingMedicationTask.dateKey(today)
      ? today
      : day;
  return careTimeOnScheduledDay(scheduledAt, TimeOfDay.fromDateTime(clock));
}

class CareActualTimeField extends StatelessWidget {
  const CareActualTimeField({
    super.key,
    required this.scheduledAt,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final DateTime scheduledAt, value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '執行日期：${BookingMedicationTask.dateKey(BookingMedicationTask.taipei(scheduledAt))}（同上方時程）',
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        icon: const Icon(Icons.schedule),
        label: Text('實際時間 ${BookingMedicationTask.timeLabel(value)} · 修改時間'),
        onPressed: !enabled
            ? null
            : () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    BookingMedicationTask.taipei(value),
                  ),
                  initialEntryMode: TimePickerEntryMode.input,
                  helpText: '輸入實際執行時間',
                  hourLabelText: '時',
                  minuteLabelText: '分',
                  cancelText: '取消',
                  confirmText: '套用時間',
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  ),
                );
                if (time != null && context.mounted) {
                  onChanged(careTimeOnScheduledDay(scheduledAt, time));
                }
              },
      ),
      const Text('日期固定為本筆時程日期，時間以台灣時間記錄。', style: TextStyle(fontSize: 12)),
    ],
  );
}
