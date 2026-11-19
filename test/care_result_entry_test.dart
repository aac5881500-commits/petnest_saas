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

  test('服務結果允許同一入住分鐘，並分別提示早於入住或晚於現在', () {
    final start = serviceBookingStart({
      'actualStartAt': 'invalid',
      'checkInAt': Timestamp.fromDate(
        DateTime.parse('2026-11-12T21:00:35+08:00'),
      ),
      'startDate': '2026-11-12',
    });
    final now = DateTime.parse('2026-11-12T21:05:00+08:00');
    String? error(String time) => serviceActualTimeError(
      actual: DateTime.parse(time),
      checkIn: start,
      now: now,
    );
    expect(error('2026-11-12T21:00:00+08:00'), isNull);
    expect(
      error('2026-11-12T20:59:00+08:00'),
      contains('早於入住時間 2026-11-12 21:00'),
    );
    expect(error('2026-11-12T21:07:00+08:00'), contains('晚於現在'));
    expect(
      serviceBookingStart({'startDate': '2026-11-12'}),
      DateTime.parse('2026-11-11T16:00:00Z'),
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
    expect(find.text('到店核對用藥'), findsOneWidget);
    expect(find.textContaining('飼主到店後'), findsOneWidget);
    expect(find.byTooltip('記錄結果'), findsNothing);
    await tester.tap(find.text('到店核對用藥'));
    await tester.pumpAndSettle();
    expect(find.text('到店核對用藥'), findsOneWidget);
    expect(find.byType(MedicationRequestEditor), findsOneWidget);
    expect(find.text('新增藥品／保健品'), findsOneWidget);
    expect(find.text('確認並加入用藥排程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('到店核對逐日帶入並可排除日期、刪除單筆時段', (tester) async {
    Map<String, dynamic>? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              child: MedicationRequestEditor(
                shopId: 'test',
                pets: const [
                  {'petId': 'p1', 'name': '麻糬'},
                ],
                setting: const {
                  'types': ['oral'],
                },
                startDate: DateTime(2026, 11, 10),
                endDate: DateTime(2026, 11, 12),
                reviewByDate: true,
                initial: const {
                  'preferences': [
                    {
                      'petId': 'p1',
                      'types': ['oral'],
                      'dates': [
                        {
                          'date': '2026-11-10',
                          'times': ['16:00', '19:00'],
                        },
                        {
                          'date': '2026-11-11',
                          'times': ['09:00'],
                        },
                      ],
                    },
                  ],
                },
                onChanged: (value) => draft = value,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('2026/11/10'), findsOneWidget);
    expect(find.text('2026/11/11'), findsOneWidget);
    await tester.tap(find.byTooltip('刪除 19:00'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2026/11/11'));
    await tester.tap(find.text('2026/11/11'));
    await tester.pumpAndSettle();
    final medicine = medList(draft!['medicines']).single;
    expect(medicine['dates'], [
      {
        'date': '2026-11-10',
        'times': ['16:00'],
      },
    ]);
  });

  testWidgets('等飼主確認有原因提示，不開放填寫結果', (tester) async {
    await tester.pumpWidget(panel(fixture('pending_customer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('已送出安排，等待飼主同意'), findsOneWidget);
    expect(find.text('到店核對用藥'), findsOneWidget);
    expect(find.byTooltip('記錄結果'), findsNothing);
  });

  testWidgets('唯讀與結算鎖定的帳號不顯示安排操作', (tester) async {
    await tester.pumpWidget(panel(fixture('pending_shop'), canManage: false));
    await tester.pumpAndSettle();
    expect(find.text('到店核對用藥'), findsNothing);
    await tester.pumpWidget(
      panel({...fixture('pending_shop'), 'settlementLocked': true}),
    );
    await tester.pumpAndSettle();
    expect(find.text('到店核對用藥'), findsNothing);
  });

  testWidgets('待確認用藥先引導至訂單或訂金確認', (tester) async {
    for (final (deposit, label) in const [(0, '確認訂單'), (965, '確認訂金入帳')]) {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openMedicationArrangement(
                  context,
                  bookingId: 'test-order',
                  booking: {
                    ...fixture('pending_shop'),
                    'status': 'pending',
                    'depositAmount': deposit,
                    'payAmountType': 'deposit',
                  },
                  onViewOrderConfirmation: () => opened = true,
                ),
                child: const Text('核對用藥'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('核對用藥'));
      await tester.pumpAndSettle();
      expect(find.text('請先$label'), findsOneWidget);
      expect(find.byType(MedicationRequestEditor), findsNothing);
      await tester.tap(find.text('前往$label'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    }
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
          'pending_shop' => '到店核對用藥',
          'pending_customer' => '查看待確認安排',
          _ => '填寫結果',
        }),
        findsOneWidget,
      );
      if (state == 'pending_shop') {
        await tester.tap(find.text('到店核對用藥'));
        await tester.pumpAndSettle();
        expect(find.byType(MedicationRequestEditor), findsOneWidget);
        expect(find.text('確認並加入用藥排程'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
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
    await tester.scrollUntilVisible(
      find.byType(CareActualTimeField),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
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
