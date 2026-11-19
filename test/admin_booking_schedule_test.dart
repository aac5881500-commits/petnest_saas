import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/widgets/member_avatar.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_experience.dart';
import 'package:petnest_saas/features/admin/widgets/booking_care_display.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_medication_fees.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_schedule.dart';

void main() {
  testWidgets('桌機時間格選到正確寵物，手機可依寵物分組及隱藏照片', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const data = AdminBookingScheduleData(
      shopId: 'demo',
      bookingId: 'order',
      canEdit: true,
      booking: {
        'status': 'pending',
        'pets': [
          {
            'petId': 'p1',
            'name': '小布',
            'photoUrl': 'https://example.test/p1.png',
          },
          {'petId': 'p2', 'name': '奶茶'},
        ],
      },
    );
    final time = DateTime.parse('2026-11-10T01:30:00Z');
    final entries = [
      BookingScheduleEntry(
        kind: BookingScheduleKind.medication,
        time: time,
        title: '擦藥',
        detail: '小布',
        petIds: const ['p1'],
        requestStatus: '待店家確認',
      ),
      BookingScheduleEntry(
        kind: BookingScheduleKind.medication,
        time: time,
        title: '口服藥',
        detail: '奶茶',
        petIds: const ['p2'],
        requestStatus: '待飼主確認',
      ),
    ];
    Widget page(BookingCareDisplay display) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminBookingSchedule(
            data: data,
            entries: entries,
            view: AdminBookingScheduleView.timeline,
            display: display,
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(page(const BookingCareDisplay()));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('選取的時段'), findsNothing);
    expect(find.byType(MemberAvatar), findsWidgets);
    await tester.tap(find.widgetWithText(OutlinedButton, '口服藥'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('待飼主確認'),
      ),
      findsOneWidget,
    );
    expect(find.text('填寫結果'), findsNothing);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(320, 780);
    await tester.pumpWidget(page(const BookingCareDisplay()));
    expect(find.byType(Table), findsNothing);
    expect(find.text('奶茶'), findsOneWidget);
    await tester.pumpWidget(
      page(
        const BookingCareDisplay(
          layout: BookingCareLayout.pets,
          showPhotos: false,
        ),
      ),
    );
    expect(find.byType(MemberAvatar), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('奶茶'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('齒輪的照護選項與原版型分開儲存，重開保留', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Widget page() => MaterialApp(
      home: Scaffold(
        body: AdminBookingDetailExperience(
          scope: 'shop:worker',
          hasCareDisplay: true,
          sectionBuilder: (_, experience, care) =>
              Text('layout=${experience.name}; care=${care.storageValue}'),
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    Future<void> choose(Key key) async {
      await tester.tap(find.byKey(const ValueKey('booking-layout-settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    await choose(const ValueKey('choose-care-layout-pets'));
    await choose(const ValueKey('care-display-photos'));
    expect(find.text('layout=tabs; care=pets|hide'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('layout=tabs; care=pets|hide'), findsOneWidget);
  });

  testWidgets('待確認用藥逐筆列出且不提供執行按鈕', (tester) async {
    const data = AdminBookingScheduleData(
      shopId: 'shop',
      bookingId: 'booking',
      canEdit: true,
      booking: {
        'status': 'pending',
        'pets': [
          {'petId': 'p1', 'name': '小布'},
          {'petId': 'p2', 'name': '奶茶'},
        ],
        'medication': {
          'state': 'pending_shop',
          'request': {
            'preferences': [
              {
                'petId': 'p1',
                'types': ['oral'],
                'dates': [
                  {
                    'date': '2026-11-10',
                    'times': ['09:00', '11:00'],
                  },
                ],
              },
              {
                'petId': 'p2',
                'types': ['eye'],
                'dates': [
                  {
                    'date': '2026-11-10',
                    'times': ['09:00'],
                  },
                  {
                    'date': '2026-11-11',
                    'times': ['14:30'],
                  },
                ],
              },
            ],
          },
        },
      },
    );
    final entries = data.entries(showMedication: true);
    expect(entries.length, 4);
    expect(entries.every((entry) => entry.medication == null), isTrue);
    expect(data.entries(showMedication: false), isEmpty);
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminBookingSchedule(
              data: data,
              entries: entries,
              view: AdminBookingScheduleView.timeline,
              initialDay: '2026-11-10',
            ),
          ),
        ),
      ),
    );
    expect(find.text('尚未跟客戶核對'), findsNWidgets(3));
    expect(find.text('奶茶'), findsOneWidget);
    expect(find.text('填寫結果'), findsNothing);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is ChoiceChip &&
                widget.label is Text &&
                ((widget.label as Text).data ?? '').startsWith('11/11'),
          )
          .first,
    );
    await tester.pump();
    expect(find.text('14:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('已列入預約應付與最終用藥費分開呈現，零元也顯示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBookingMedicationFees(
            inFinance: true,
            booking: {
              'medication': {
                'state': 'confirmed',
                'advanceAmount': 200,
                'estimate': {'amount': 200},
                'finalized': true,
                'finalAmount': 0,
              },
            },
          ),
        ),
      ),
    );
    expect(find.text('用藥費與退房結算'), findsOneWidget);
    expect(find.text('已列入預約應付'), findsOneWidget);
    expect(find.text('最終用藥費'), findsOneWidget);
    expect(find.text('NT\$ 0'), findsOneWidget);
    expect(find.text('NT\$ -200'), findsOneWidget);
  });

  test('住宿只用明確選定的時段，分時服務與用藥依台北日期排列', () {
    const data = AdminBookingScheduleData(
      shopId: 'shop',
      bookingId: 'booking',
      canEdit: true,
      booking: {
        'status': 'checked_in',
        'startDate': '2026-11-10',
        'endDate': '2026-11-12',
        'pets': [
          {'petId': 'p1', 'name': '小布'},
        ],
        'addons': [
          {'type': 'time', 'label': '09:00 - 09:59 入住'},
          {
            'type': 'daily_timed',
            'name': '陪玩',
            'selections': [
              {
                'petName': '小布',
                'dates': [
                  {
                    'date': '2026-11-11',
                    'slotLabels': ['10:00–10:30'],
                  },
                ],
              },
            ],
          },
        ],
        'medication': {
          'state': 'confirmed',
          'request': {
            'medicines': [
              {'id': 'm1', 'type': 'topical'},
            ],
          },
          'tasks': [
            {
              'id': 't1',
              'petId': 'p1',
              'scheduledAt': '2026-11-11T01:30:00Z',
              'medicineIds': ['m1'],
              'result': 'pending',
            },
          ],
        },
      },
    );
    final entries = data.entries(showMedication: true);
    expect(entries.map((entry) => entry.title), ['住宿入住', '擦藥', '陪玩']);
    expect(entries.first.timeLabel, '09:00–09:59');
    expect(entries.first.completed, isTrue);
    expect(entries[1].day, '2026-11-11');
    expect(entries[1].timeLabel, '09:30');
    expect(data.entries(showMedication: false).map((entry) => entry.title), [
      '住宿入住',
      '陪玩',
    ]);
    expect(
      data.medicationEnabled({
        'medicationSetting': {'enabled': false},
      }),
      isFalse,
    );
  });

  testWidgets('安親總覽提醒和照護時程使用同一筆資料', (tester) async {
    final start = DateTime.now().toUtc().add(const Duration(minutes: 12));
    final data = AdminBookingScheduleData(
      shopId: 'shop',
      bookingId: 'daycare',
      canEdit: true,
      booking: {
        'bookingKind': 'daycare',
        'status': 'confirmed',
        'scheduledStartAt': start,
        'scheduledEndAt': start.add(const Duration(hours: 2)),
      },
    );
    final entries = data.entries(showMedication: false);
    expect(entries.map((entry) => entry.title), ['安親送達', '安親接回']);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminBookingSchedule(
            data: data,
            entries: entries,
            view: AdminBookingScheduleView.next,
            onViewTimeline: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('下一個預約時段'), findsOneWidget);
    expect(find.text('還有 12 分鐘'), findsOneWidget);
    await tester.tap(find.text('查看完整時程'));
    expect(opened, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
