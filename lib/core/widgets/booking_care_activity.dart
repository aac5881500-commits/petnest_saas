import 'dart:async';
import 'package:flutter/material.dart';
import '../models/booking_medication_task.dart';
import '../models/booking_service_task.dart';
import '../models/daily_care_stay_info.dart';
import '../../features/medication/care_task_dialog.dart';

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
  bool? _medicationFilter;
  String? _petFilter;
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
    if (rows.isEmpty) return const SizedBox.shrink();
    final dates = {
      ...rows.map((r) => r.day),
      if (!widget.staff)
        ...DailyCareStayInfo.fromBookingMap(
          b,
        ).stayDateKeys().map((date) => date.replaceAll('/', '-')),
    }.toList()..sort();
    final pets = <String, String>{
      for (final row in rows)
        if (row.petId.isNotEmpty) row.petId: row.pet,
    };
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
    final dayRows = available
        .where(
          (r) =>
              r.day == day &&
              (widget.staff || _petFilter == null || r.petId == _petFilter),
        )
        .toList();
    final shown = dayRows
        .where(
          (r) =>
              widget.staff ||
              _medicationFilter == null ||
              r.medication == _medicationFilter,
        )
        .toList();
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
                    '每日照護動態',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.staff
                  ? '填寫一次，同步到客戶訂單；本訂單有照護回報時自動帶入。'
                  : '依日期查看用藥與專屬服務的最新紀錄。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (widget.dateKey == null)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final date in dates)
                    ChoiceChip(
                      label: Text(
                        '${date.substring(5).replaceAll('-', '/')} ${date == today ? '今日' : ''}',
                      ),
                      selected: day == date,
                      onSelected: (_) => setState(() => _day = date),
                    ),
                ],
              ),
            if (!widget.staff && pets.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('全部寵物'),
                    selected: _petFilter == null,
                    onSelected: (_) => setState(() => _petFilter = null),
                  ),
                  for (final pet in pets.entries)
                    ChoiceChip(
                      label: Text(pet.value),
                      selected: _petFilter == pet.key,
                      onSelected: (_) => setState(() => _petFilter = pet.key),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${shown.where((r) => !r.pending).length} / ${shown.length} 項已記錄${widget.staff && !ended && due > 0 ? ' · $due 項已到點待確認' : ''}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (!widget.staff) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final filter in <bool?>[null, true, false])
                    ChoiceChip(
                      label: Text(
                        filter == null
                            ? '全部 ${dayRows.length}'
                            : filter
                            ? '用藥 ${dayRows.where((r) => r.medication).length}'
                            : '專屬服務 ${dayRows.where((r) => !r.medication).length}',
                      ),
                      selected: _medicationFilter == filter,
                      onSelected: (_) =>
                          setState(() => _medicationFilter = filter),
                    ),
                ],
              ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('這一天尚無此類照護紀錄。'),
                ),
            ],
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
                      ? (widget.staff ? '已到點 · 尚未記錄' : '已到時間 · 待填寫')
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
                    onPressed: () => openCareReportResult(
                      context,
                      shopId: '${b['shopId']}',
                      bookingId: widget.bookingId,
                      taskId: row.id,
                      medication: row.medication,
                    ),
                    child: Text(recorded ? '補齊結果' : '填寫結果'),
                  );
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(widget.staff ? 12 : 10),
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
                                  if (widget.staff)
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
                                  if (widget.staff)
                                    Text(
                                      '${row.pet} · ${row.title}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  else
                                    _CareIdentity(
                                      pet: row.pet,
                                      title: row.title,
                                      medication: row.medication,
                                      taskId: row.id,
                                    ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .09),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
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
                        if (row.note.trim().isNotEmpty)
                          Container(
                            key: ValueKey('care-note-${row.id}'),
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                color.withValues(alpha: .07),
                                colors.surface,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: color.withValues(alpha: .5),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  exception
                                      ? Icons.info_outline_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: color,
                                  size: 18,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exception ? '原因與後續安排' : '店家照護說明',
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        row.note.trim(),
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

class _CareIdentity extends StatelessWidget {
  const _CareIdentity({
    required this.pet,
    required this.title,
    required this.medication,
    required this.taskId,
  });
  final String pet, title, taskId;
  final bool medication;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = Text(
      pet,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: colors.onSurface,
      ),
    );
    final tag = Container(
      key: ValueKey('care-type-$taskId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.primary.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            medication ? Icons.medication_outlined : Icons.pets_outlined,
            size: 14,
            color: colors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 180) {
          return Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [name, tag],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: name),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .6),
              child: tag,
            ),
          ],
        );
      },
    );
  }
}
