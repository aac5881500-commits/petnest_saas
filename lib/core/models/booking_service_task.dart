import 'dart:convert';
import 'booking_medication_task.dart';

/// Purchased timed services. IDs are shared with the callable; catalog edits
/// never change an already booked schedule or an execution record.
class BookingServiceTask {
  const BookingServiceTask({
    required this.id,
    required this.petId,
    required this.pet,
    required this.title,
    required this.scheduledAt,
    required this.slot,
    this.record = const {},
  });
  final String id, petId, pet, title, slot;
  final DateTime scheduledAt;
  final Map<String, dynamic> record;
  bool get pending => record.isEmpty;
  String get result => '${record['result'] ?? 'pending'}';
  String get resultLabel => switch (result) {
    'done' => '已完成',
    'partial' => '部分完成',
    'skipped' => '未執行',
    _ => '尚未記錄',
  };
  DateTime? get actualAt => DateTime.tryParse('${record['actualAt'] ?? ''}');
  String get day =>
      BookingMedicationTask.dateKey(BookingMedicationTask.taipei(scheduledAt));
  String urgencyAt(DateTime now) => !pending
      ? ''
      : !scheduledAt.isAfter(now)
      ? 'due'
      : scheduledAt.difference(now) <= BookingMedicationTask.advanceNotice
      ? 'soon'
      : '';
  static bool canRecord(Map<String, dynamic> b) =>
      b['status'] == 'checked_in' &&
      b['settlementConfirmed'] != true &&
      b['settlementLocked'] != true &&
      b['settledAt'] == null;
  static Iterable<Map> maps(Object? v) =>
      v is List ? v.whereType<Map>() : const [];
  static DateTime? instant(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static String dayOf(Object? v) {
    if (v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return v;
    final d = instant(v);
    return d == null
        ? ''
        : BookingMedicationTask.dateKey(BookingMedicationTask.taipei(d));
  }

  static List<BookingServiceTask> fromBooking(Map<String, dynamic> b) {
    final tasks = <String, BookingServiceTask>{};
    final names = {
      for (final p in maps(b['pets']))
        '${p['petId'] ?? p['id'] ?? ''}': '${p['name'] ?? p['petName'] ?? ''}',
    };
    final records = b['careServiceRecords'] is Map
        ? b['careServiceRecords'] as Map
        : const {};
    for (final a in maps(b['addons'])) {
      if (!{'daily_timed', 'dailyTimedServices'}.contains(a['type'])) continue;
      final title = '${a['name'] ?? a['label'] ?? '預約服務'}';
      final service = '${a['serviceId'] ?? a['id'] ?? title}';
      void add(
        String petId,
        String day,
        String slotId,
        String label,
        String pet,
      ) {
        final match = RegExp(
          r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)',
        ).firstMatch(label);
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || match == null) {
          return;
        }
        final time = DateTime.tryParse(
          '${day}T${match[1]!.padLeft(2, '0')}:${match[2]}:00+08:00',
        );
        if (time == null) return;
        final id = base64Url
            .encode(
              utf8.encode(
                jsonEncode([
                  service,
                  petId.isEmpty ? 'legacy:$pet' : petId,
                  day,
                  slotId,
                ]),
              ),
            )
            .replaceAll('=', '');
        final raw = records[id];
        final record =
            raw is Map &&
                instant(raw['scheduledAt'])?.isAtSameMomentAs(time) == true
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        tasks[id] = BookingServiceTask(
          id: id,
          petId: petId,
          pet: pet.isEmpty ? '寵物' : pet,
          title: title,
          scheduledAt: time,
          slot: label,
          record: record,
        );
      }

      for (final s in maps(a['selections'])) {
        final matching = names.entries
            .where((p) => p.value == s['petName'])
            .toList();
        final petId =
            '${s['petId'] ?? (matching.length == 1 ? matching.single.key : '')}';
        for (final d in maps(s['dates'])) {
          final ids = d['slotIds'] is List ? d['slotIds'] as List : const [];
          final labels =
              d['slotLabels'] is List && (d['slotLabels'] as List).isNotEmpty
              ? d['slotLabels'] as List
              : ids;
          for (var i = 0; i < labels.length; i++) {
            add(
              petId,
              '${d['date'] ?? ''}',
              i < ids.length ? '${ids[i]}' : '${labels[i]}',
              '${labels[i]}',
              '${s['petName'] ?? names[petId] ?? ''}',
            );
          }
        }
      }
      if (a['selectedPetIds'] is List) {
        for (final petId in a['selectedPetIds'] as List) {
          for (final slot in maps(a['selectedTimeSlots'])) {
            var day = dayOf(b['scheduledStartAt'] ?? b['startAt']);
            final start = instant(b['scheduledStartAt'] ?? b['startAt']);
            final label = '${slot['label'] ?? ''}';
            // Daycare can cross midnight. Use the first occurrence after start.
            final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(label);
            if (start != null && clock != null) {
              final candidate = DateTime.tryParse(
                '${day}T${clock[1]!.padLeft(2, '0')}:${clock[2]}:00+08:00',
              );
              if (candidate != null && candidate.isBefore(start)) {
                day = dayOf(candidate.add(const Duration(days: 1)));
              }
            }
            add(
              '$petId',
              day,
              '${slot['id'] ?? label}',
              label,
              names[petId] ?? '',
            );
          }
        }
      }
    }
    return tasks.values.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }
}
