import '../models/booking_service_task.dart';

/// Uses the existing per-task record APIs, preserving completed medicine results.
class SettlementQuickCare {
  static Map<String, dynamic> medicationPayload({
    required String bookingId,
    required Map<String, dynamic> booking,
    required String taskId,
    required String result,
    required DateTime now,
    String note = '',
  }) {
    if (!['done', 'skipped'].contains(result)) throw ArgumentError('請選擇成功或未執行');
    final medication = Map<String, dynamic>.from(booking['medication'] as Map);
    final task = (medication['tasks'] as List)
        .whereType<Map>()
        .where((task) => task['id'] == taskId)
        .firstOrNull;
    if (task == null) throw StateError('找不到用藥項目');
    if (task['finished'] == true ||
        !['pending', 'partial', 'mixed'].contains(task['result'])) {
      throw StateError('此項已記錄，請重新讀取');
    }
    final scheduled = DateTime.parse('${task['scheduledAt']}');
    if (result == 'done' && scheduled.isAfter(now)) {
      throw StateError('未到時間不能快速標記成功');
    }
    final previous = task['medicineResults'] is Map
        ? task['medicineResults'] as Map
        : const {};
    final results = <String, String>{
      for (final id in task['medicineIds'] as List)
        '$id': ['done', 'failed', 'skipped'].contains(previous[id])
            ? '${previous[id]}'
            : result,
    };
    final aggregate = results.values.toSet().length == 1
        ? results.values.first
        : 'partial';
    return {
      'bookingId': bookingId,
      'action': 'record',
      'revision': medication['revision'],
      'taskId': taskId,
      'result': aggregate,
      'medicineResults': results,
      'actualAt': (result == 'done' ? scheduled : now)
          .toUtc()
          .toIso8601String(),
      'note':
          '${result == 'done' ? '結算快速核對：確認已完成，依原訂時間補記。' : '結算快速核對：確認未執行。'}${note.trim().isEmpty ? '' : ' ${note.trim()}'}',
    };
  }

  static Map<String, dynamic> servicePayload({
    required String bookingId,
    required BookingServiceTask task,
    required String result,
    required DateTime now,
    String note = '',
  }) {
    if (!['done', 'skipped'].contains(result)) throw ArgumentError('請選擇成功或未執行');
    if (!task.pending) throw StateError('此項已記錄，請重新讀取');
    if (result == 'done' && task.scheduledAt.isAfter(now)) {
      throw StateError('未到時間不能快速標記成功');
    }
    return {
      'bookingId': bookingId,
      'taskId': task.id,
      'scheduledAt': task.scheduledAt.toUtc().toIso8601String(),
      'result': result,
      'actualAt': (result == 'done' ? task.scheduledAt : now)
          .toUtc()
          .toIso8601String(),
      'note':
          '${result == 'done' ? '結算快速核對：確認已完成，依原訂時間補記。' : '結算快速核對：確認未執行。'}${note.trim().isEmpty ? '' : ' ${note.trim()}'}',
    };
  }
}
