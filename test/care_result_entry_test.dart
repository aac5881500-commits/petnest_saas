import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/medication/care_actual_time_field.dart';
import 'package:petnest_saas/features/medication/medication_widgets.dart';
import 'package:petnest_saas/features/medication/service_task_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_schedule.dart';
import 'package:petnest_saas/features/admin/widgets/booking_care_display.dart';

Map<String, dynamic> fixture(String state) => {
  'shopId': 'test',
  'status': 'checked_in',
  'startDate': Timestamp.fromDate(DateTime.utc(2026, 11, 10)),
  'endDate': Timestamp.fromDate(DateTime.utc(2026, 11, 13)),
  'pets': [
    {'petId': 'p1', 'name': '麻糬'},
  ],
  'medication': {
    'state': state,
    'revision': 1,
    'setting': {
      'enabled': true,
      'mode': 'visit',
      'price': 50,
      'types': ['oral'],
    },
    'request': {
      'careStart': '2026-11-10T15:00:00+08:00',
      'careEnd': '2026-11-13T12:00:00+08:00',
      'medicines': [
        {
          'id': 'm1',
          'petId': 'p1',
          'name': '藥品 A',
          'dose': '依藥袋',
          'instruction': '依飼主交接',
          'type': 'oral',
          'schedule': 'fixed',
          'times': ['09:30'],
        },
      ],
    },
    'tasks': [
      {
        'id': 't1',
        'petId': 'p1',
        'scheduledAt': '2026-11-11T09:30:00+08:00',
        'medicineIds': ['m1'],
        'result': 'pending',
      },
    ],
    'history': [],
  },
};

Widget panel(Map<String, dynamic> b, {bool canManage = true}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: BookingMedicationPanel(
        bookingId: 'test-order',
        booking: b,
        staff: true,
        canManage: canManage,
      ),
    ),
  ),
);

void main() {
  test('時間固定於時程台灣日期，凌晨不會落到錯誤日期', () {
    final scheduled = DateTime.parse('2026-11-10T16:30:00Z');
    expect(
      careTimeOnScheduledDay(scheduled, const TimeOfDay(hour: 0, minute: 5)),
      DateTime.parse('2026-11-10T16:05:00Z'),
    );
    expect(
      careTimeOnScheduledDay(scheduled, const TimeOfDay(hour: 21, minute: 40)),
      DateTime.parse('2026-11-11T13:40:00Z'),
    );
  });

  test('當日預填當下時分，補登過去時程不會送成今日', () {
    final task = DateTime.parse('2026-11-11T01:30:00Z');
    expect(
      initialCareActualTime(task, DateTime.parse('2026-11-11T13:40:22Z')),
      DateTime.parse('2026-11-11T13:40:00Z'),
    );
    expect(
      initialCareActualTime(task, DateTime.parse('2026-11-12T13:40:00Z')),
      task,
    );
  });

  testWidgets('實際時間直接開時間選擇器，確認後保留原日期', (tester) async {
    final scheduled = DateTime.parse('2026-11-11T01:30:00Z');
    DateTime? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CareActualTimeField(
            scheduledAt: scheduled,
            value: scheduled,
            onChanged: (v) => saved = v,
          ),
        ),
      ),
    );
    expect(find.textContaining('2026-11-11（同上方時程）'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(saved, scheduled);
  });

  testWidgets('待店家確認有可用入口，能打開藥品編輯而不是執行結果', (tester) async {
    await tester.pumpWidget(panel(fixture('pending_shop')));
    await tester.pumpAndSettle();
    expect(find.text('核對藥品與安排'), findsOneWidget);
    expect(find.textContaining('補齊藥名'), findsOneWidget);
    expect(find.byTooltip('記錄結果'), findsNothing);
    await tester.tap(find.text('核對藥品與安排'));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationRequestEditor), findsOneWidget);
    expect(find.text('新增藥品／保健品'), findsOneWidget);
    expect(find.text('送客人確認'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('等飼主確認有原因提示，不開放填寫結果', (tester) async {
    await tester.pumpWidget(panel(fixture('pending_customer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已送出安排，等待飼主同意'), findsOneWidget);
    expect(find.text('修改安排並重新送確認'), findsOneWidget);
    expect(find.byTooltip('記錄結果'), findsNothing);
  });

  testWidgets('唯讀與結算鎖定的帳號不顯示安排操作', (tester) async {
    await tester.pumpWidget(panel(fixture('pending_shop'), canManage: false));
    await tester.pumpAndSettle();
    expect(find.text('核對藥品與安排'), findsNothing);
    await tester.pumpWidget(
      panel({...fixture('pending_shop'), 'settlementLocked': true}),
    );
    await tester.pumpAndSettle();
    expect(find.text('核對藥品與安排'), findsNothing);
  });

  testWidgets('手機時程直接顯示待核對入口，確認後改成填寫結果', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final state in ['pending_shop', 'pending_customer', 'confirmed']) {
      final data = AdminBookingScheduleData(
        shopId: 'test',
        bookingId: 'test-order',
        canEdit: true,
        booking: fixture(state),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminBookingSchedule(
                data: data,
                entries: data.entries(showMedication: true),
                initialDay: '2026-11-11',
                view: AdminBookingScheduleView.timeline,
                display: const BookingCareDisplay(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(switch (state) {
          'pending_shop' => '核對藥品與安排',
          'pending_customer' => '查看待確認安排',
          _ => '填寫結果',
        }),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('已確認用藥的結果表單直接選時間，補登仍保留用藥日', (tester) async {
    await tester.pumpWidget(panel(fixture('confirmed')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('記錄結果'));
    await tester.tap(find.byTooltip('記錄結果'));
    await tester.pumpAndSettle();
    expect(find.byType(CareActualTimeField), findsOneWidget);
    expect(find.textContaining('2026-11-11（同上方時程）'), findsOneWidget);
    final button = find.descendant(
      of: find.byType(CareActualTimeField),
      matching: find.byType(OutlinedButton),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-11-11（同上方時程）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('儲存狀態不明不能宣稱成功，業務錯誤保留原因', () {
    final text = serviceResultErrorMessage(
      FirebaseFunctionsException(code: 'internal', message: 'internal'),
    );
    expect(text, contains('無法確認儲存結果'));
    expect(text, isNot(contains('internal')));
    expect(
      serviceResultErrorMessage(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: '尚未到服務時間',
        ),
      ),
      '尚未到服務時間',
    );
  });
}
