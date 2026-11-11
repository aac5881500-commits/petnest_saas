import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking_medication_task.dart';
import '../models/booking_service_task.dart';
import '../../features/medication/medication_task_page.dart';
import '../../features/medication/service_task_page.dart';

class BookingCareActivity extends StatefulWidget {
  const BookingCareActivity({
    super.key,
    required this.bookingId,
    required this.booking,
    this.staff = false,
    this.dateKey,
    this.showMedication = true,
    this.showServices = true,
    this.recordedOnly = false,
  });
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool staff, showMedication, showServices, recordedOnly;
  final String? dateKey;
  @override
  State<BookingCareActivity> createState() => _BookingCareActivityState();
}

class _BookingCareActivityState extends State<BookingCareActivity> {
  String? _day;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;
    final rows =
        <
            ({
              String id,
              String petId,
              String pet,
              String title,
              String day,
              DateTime time,
              String result,
              bool pending,
              DateTime? actual,
              String note,
              bool medication,
            })
          >[
            if (widget.showMedication)
              for (final t in BookingMedicationTask.fromBooking(b))
                (
                  id: t.id,
                  petId: t.petId,
                  pet: t.pet,
                  title: t.types,
                  day: t.day,
                  time: t.scheduledAt,
                  result: t.resultLabel,
                  pending: t.pending,
                  actual: t.actualAt,
                  note:
                      '${BookingServiceTask.maps((b['medication'] as Map?)?['tasks']).where((r) => r['id'] == t.id).firstOrNull?['note'] ?? ''}',
                  medication: true,
                ),
            if (widget.showServices)
              for (final t in BookingServiceTask.fromBooking(b))
                (
                  id: t.id,
                  petId: t.petId,
                  pet: t.pet,
                  title: t.title,
                  day: t.day,
                  time: t.scheduledAt,
                  result: t.resultLabel,
                  pending: t.pending,
                  actual: t.actualAt,
                  note: '${t.record['note'] ?? ''}',
                  medication: false,
                ),
          ]
          ..sort((a, b) => a.time.compareTo(b.time));
    final available = rows
        .where((r) => !widget.recordedOnly || r.actual != null)
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    final dates = available.map((r) => r.day).toSet().toList()..sort();
    final today = BookingMedicationTask.dateKey(
      BookingMedicationTask.taipei(now),
    );
    final day =
        widget.dateKey ??
        (dates.contains(_day)
            ? _day
            : dates.contains(today)
            ? today
            : dates.first);
    final shown = available.where((r) => r.day == day).toList();
    if (widget.dateKey != null && shown.isEmpty) return const SizedBox.shrink();
    final ended = {
      'cancelled',
      'checked_out',
      'completed',
    }.contains(b['status']);
    final due = shown.where((r) => r.pending && !r.time.isAfter(now)).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_available_outlined, color: colors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '照護時程與結果',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.staff
                  ? '填寫一次，同步到客戶訂單；本訂單有照護回報時自動帶入。'
                  : '用藥與預約服務的執行紀錄會在這裡更新，不受是否包含每日回報影響。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (widget.dateKey == null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final date in dates)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${date.substring(5).replaceAll('-', '/')} ${date == today ? '今日' : ''}',
                          ),
                          selected: day == date,
                          onSelected: (_) => setState(() => _day = date),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${shown.where((r) => !r.pending).length} / ${shown.length} 項已記錄${widget.staff && !ended && due > 0 ? ' · $due 項已到點待確認' : ''}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            for (final row in shown)
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final active = !ended && b['status'] == 'checked_in';
                  final soon =
                      active &&
                      row.pending &&
                      row.time.isAfter(now) &&
                      row.time.difference(now) <=
                          BookingMedicationTask.advanceNotice;
                  final overdue =
                      active && row.pending && !row.time.isAfter(now);
                  final recorded = row.actual != null;
                  final exception =
                      recorded && !{'成功', '已完成'}.contains(row.result);
                  final color = exception || overdue
                      ? colors.error
                      : soon
                      ? const Color(0xFFAA6200)
                      : !row.pending
                      ? const Color(0xFF26704B)
                      : colors.primary;
                  final label = !row.medication && row.petId.isEmpty
                      ? '寵物資料待核對'
                      : !row.pending
                      ? row.result
                      : recorded
                      ? row.result
                      : ended
                      ? (b['status'] == 'cancelled' ? '訂單已取消' : '未留執行紀錄')
                      : b['status'] != 'checked_in'
                      ? '等待入住'
                      : overdue
                      ? '已到點 · 尚未記錄'
                      : soon
                      ? '即將到點'
                      : '已排定';
                  final pet = BookingServiceTask.maps(b['pets'])
                      .where(
                        (p) => '${p['petId'] ?? p['id'] ?? ''}' == row.petId,
                      )
                      .firstOrNull;
                  final photo = '${pet?['photoUrl'] ?? pet?['imageUrl'] ?? ''}';
                  final canRecord =
                      widget.staff &&
                      row.pending &&
                      (row.medication || row.petId.isNotEmpty) &&
                      (row.medication
                          ? BookingMedicationTask.canRecord(b)
                          : BookingServiceTask.canRecord(b));
                  final action = FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => row.medication
                            ? MedicationTaskPage(
                                shopId: '${b['shopId']}',
                                bookingId: widget.bookingId,
                                taskId: row.id,
                                scheduledAt: row.time.toUtc().toIso8601String(),
                              )
                            : ServiceTaskPage(
                                shopId: '${b['shopId']}',
                                bookingId: widget.bookingId,
                                taskId: row.id,
                                scheduledAt: row.time.toUtc().toIso8601String(),
                              ),
                      ),
                    ),
                    child: Text(recorded ? '補齊結果' : '填寫結果'),
                  );
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .045),
                      border: Border.all(color: color.withValues(alpha: .18)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 54,
                              child: Column(
                                children: [
                                  Text(
                                    BookingMedicationTask.timeLabel(row.time),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Icon(
                                    row.medication
                                        ? Icons.medication_outlined
                                        : Icons.pets_outlined,
                                    color: color,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ClipOval(
                              child: photo.isNotEmpty
                                  ? Image.network(
                                      photo,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, e, s) => const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Icon(Icons.pets),
                                      ),
                                    )
                                  : const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Icon(Icons.pets),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row.pet} · ${row.title}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canRecord && wide) ...[
                              const SizedBox(width: 16),
                              action,
                            ],
                          ],
                        ),
                        if (row.actual case final time?)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '實際 ${BookingMedicationTask.dateKey(BookingMedicationTask.taipei(time))} ${BookingMedicationTask.timeLabel(time)}',
                            ),
                          ),
                        if (row.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(row.note),
                          ),
                        if (canRecord && !wide)
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            Text(
              '執行結果與費用分開記錄；應收、減收或退款請以訂單費用明細為準。',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
