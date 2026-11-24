import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/settlement_quick_care.dart';
import 'package:petnest_saas/core/models/booking_service_task.dart';

void main() {
  final now = DateTime.utc(2026, 11, 21, 12);
  Map<String, dynamic> booking({bool future = false, bool finished = false}) =>
      {
        'medication': {
          'revision': 7,
          'tasks': [
            {
              'id': 't',
              'scheduledAt': future
                  ? '2026-11-22T09:00:00+08:00'
                  : '2026-11-20T09:00:00+08:00',
              'result': 'partial',
              'finished': finished,
              'medicineIds': ['m1', 'm2'],
              'medicineResults': {'m1': 'failed'},
            },
          ],
        },
      };
  test('快速成功保留已記錄藥品結果，使用最新版本及原訂時間', () {
    final data = SettlementQuickCare.medicationPayload(
      bookingId: 'b',
      booking: booking(),
      taskId: 't',
      result: 'done',
      now: now,
    );
    expect(data['revision'], 7);
    expect(data['result'], 'partial');
    expect(data['medicineResults'], {'m1': 'failed', 'm2': 'done'});
    expect(data['actualAt'], '2026-11-20T01:00:00.000Z');
    expect(data['note'], contains('依原訂時間補記'));
  });
  test('未到時間只能未執行，保留核對時間和說明', () {
    expect(
      () => SettlementQuickCare.medicationPayload(
        bookingId: 'b',
        booking: booking(future: true),
        taskId: 't',
        result: 'done',
        now: now,
      ),
      throwsStateError,
    );
    final data = SettlementQuickCare.medicationPayload(
      bookingId: 'b',
      booking: booking(future: true),
      taskId: 't',
      result: 'skipped',
      now: now,
      note: '提早接回',
    );
    expect(data['actualAt'], now.toIso8601String());
    expect(data['medicineResults'], {'m1': 'failed', 'm2': 'skipped'});
    expect(data['note'], contains('提早接回'));
  });
  test('已完成用藥不重寫，非快速選項不能送出', () {
    expect(
      () => SettlementQuickCare.medicationPayload(
        bookingId: 'b',
        booking: booking(finished: true),
        taskId: 't',
        result: 'done',
        now: now,
      ),
      throwsStateError,
    );
    expect(
      () => SettlementQuickCare.medicationPayload(
        bookingId: 'b',
        booking: booking(),
        taskId: 't',
        result: 'other',
        now: now,
      ),
      throwsArgumentError,
    );
  });
  test('預約未執行與成功使用正確紀錄時間', () {
    final task = BookingServiceTask(
      id: 's',
      petId: 'p',
      pet: '布丁',
      title: '陪玩',
      scheduledAt: now.subtract(const Duration(days: 1)),
      slot: '',
    );
    final done = SettlementQuickCare.servicePayload(
      bookingId: 'b',
      task: task,
      result: 'done',
      now: now,
    );
    final skipped = SettlementQuickCare.servicePayload(
      bookingId: 'b',
      task: task,
      result: 'skipped',
      now: now,
    );
    expect(done['actualAt'], task.scheduledAt.toIso8601String());
    expect(skipped['actualAt'], now.toIso8601String());
    expect(skipped['note'], contains('確認未執行'));
    final finished = BookingServiceTask(
      id: 's',
      petId: 'p',
      pet: '布丁',
      title: '陪玩',
      scheduledAt: now,
      slot: '',
      record: {'result': 'done'},
    );
    expect(
      () => SettlementQuickCare.servicePayload(
        bookingId: 'b',
        task: finished,
        result: 'skipped',
        now: now,
      ),
      throwsStateError,
    );
  });
}
