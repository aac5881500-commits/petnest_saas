/// Read-only projection of the existing booking medication record.
class BookingMedicationTask {
  const BookingMedicationTask({
    required this.id,
    required this.pet,
    this.petId = '',
    required this.scheduledAt,
    required this.result,
    required this.finished,
    required this.types,
    this.actualAt,
  });

  final String id, pet, petId, result, types;
  final DateTime scheduledAt;
  final DateTime? actualAt;
  final bool finished;

  static const advanceNotice = Duration(minutes: 15);

  String urgencyAt(DateTime now) {
    final remaining = scheduledAt.difference(now);
    if (remaining <= Duration.zero) return 'due';
    return remaining <= advanceNotice ? 'soon' : '';
  }

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : const {};
  static Iterable<Map<String, dynamic>> _list(Object? raw) =>
      raw is List ? raw.whereType<Map>().map(_map) : const [];

  static DateTime taipei(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));

  static String dateKey(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';
  static String timeLabel(DateTime instant) {
    final date = taipei(instant);
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  String get day => dateKey(taipei(scheduledAt));
  bool get pending =>
      !finished && const {'pending', 'partial', 'mixed'}.contains(result);
  String get resultLabel => switch (result) {
    'done' => '成功',
    'partial' => '部分完成',
    'mixed' => '待確認食用',
    'failed' => '未成功',
    'skipped' => '未執行',
    _ => '尚未記錄',
  };

  static bool canRecord(Map<String, dynamic> booking) {
    final medication = _map(booking['medication']);
    return booking['status'] == 'checked_in' &&
        booking['settlementConfirmed'] != true &&
        booking['settlementLocked'] != true &&
        booking['settledAt'] == null &&
        medication['state'] == 'confirmed' &&
        medication['finalized'] != true;
  }

  static List<BookingMedicationTask> fromBooking(Map<String, dynamic> booking) {
    final medication = _map(booking['medication']);
    if (medication['state'] != 'confirmed') return const [];
    final request = _map(medication['request']);
    final names = <String, String>{
      for (final pet in _list(booking['pets']))
        '${pet['petId'] ?? pet['id'] ?? ''}':
            '${pet['name'] ?? pet['petName'] ?? ''}',
      for (final pet in _list(request['preferences']))
        if ('${pet['name'] ?? ''}'.isNotEmpty)
          '${pet['petId']}': '${pet['name']}',
    };
    const labels = {
      'oral': '口服藥',
      'topical': '擦藥',
      'spray': '噴藥',
      'eye': '點眼藥',
      'ear': '點耳藥',
      'supplement': '保健品',
    };
    final types = {
      for (final medicine in _list(request['medicines']))
        '${medicine['id']}': labels[medicine['type']] ?? '用藥',
    };
    final tasks = <BookingMedicationTask>[];
    for (final raw in _list(medication['tasks'])) {
      final id = '${raw['id'] ?? ''}';
      final time = DateTime.tryParse('${raw['scheduledAt'] ?? ''}');
      if (id.isEmpty || time == null) continue;
      final medicineIds = raw['medicineIds'];
      final taskTypes = medicineIds is List
          ? medicineIds
                .map((id) => types[id])
                .whereType<String>()
                .toSet()
                .join('、')
          : '';
      final name = names[raw['petId']]?.trim() ?? '';
      tasks.add(
        BookingMedicationTask(
          id: id,
          petId: '${raw['petId'] ?? ''}',
          pet: name.isEmpty ? '寵物 ${raw['petId'] ?? ''}' : name,
          scheduledAt: time,
          result: '${raw['result'] ?? 'pending'}',
          finished: raw['finished'] == true,
          types: taskTypes.isEmpty ? '用藥' : taskTypes,
          actualAt: DateTime.tryParse('${raw['actualAt'] ?? ''}'),
        ),
      );
    }
    return tasks..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }
}
