import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/features/auth/pages/room_calendar_page.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';

void main() {
  test('房態顏色與文字只來自 RoomStatusPresentation', () {
    expect(RoomStatusPresentation.available().label, '空房');
    expect(
      RoomStatusPresentation.available().color,
      RoomStatusPresentation.availableColor,
    );
    expect(RoomStatusPresentation.stayBooked().label, '住宿・已訂');
    expect(
      RoomStatusPresentation.stayBooked().color,
      RoomStatusPresentation.stayColor,
    );
    expect(RoomStatusPresentation.daycareBooked().label, '安親・已訂');
    expect(RoomStatusPresentation.daycareCheckedIn().label, '安親中');
    expect(
      RoomStatusPresentation.daycareCheckedIn().color,
      RoomStatusPresentation.daycareColor,
    );
    expect(RoomStatusPresentation.stayCheckedIn().label, '入住中');
    expect(
      RoomStatusPresentation.stayCheckedIn().color,
      RoomStatusPresentation.checkedInColor,
    );
    expect(RoomStatusPresentation.completed().label, '退房／完成');
    expect(RoomStatusPresentation.cleaning().label, '清潔中');
    expect(RoomStatusPresentation.checkoutHold().label, '退房日・待清潔');
    expect(
      RoomStatusPresentation.checkoutHold().color,
      RoomStatusPresentation.checkoutHoldColor,
    );
    expect(
      RoomStatusPresentation.calendarDot('checkout_cleaning').label,
      '退房日・待清潔',
    );
    expect(
      RoomStatusPresentation.checkoutHold().color,
      isNot(RoomStatusPresentation.stayColor),
    );
    expect(
      RoomStatusPresentation.checkoutHold().color,
      isNot(RoomStatusPresentation.cleaningColor),
    );
    expect(
      RoomStatusPresentation.stayBooked().color,
      isNot(RoomStatusPresentation.cleaning().color),
    );
    expect(
      RoomStatusPresentation.daycareBooked().color,
      isNot(RoomStatusPresentation.completed().color),
    );
    expect(
      _channelGap(
        RoomStatusPresentation.stayColor,
        RoomStatusPresentation.cleaningColor,
      ),
      greaterThan(80),
    );
    expect(
      _channelGap(
        RoomStatusPresentation.daycareColor,
        RoomStatusPresentation.completedColor,
      ),
      greaterThan(80),
    );
    expect(RoomStatusPresentation.closed().label, '今日關閉');
    expect(RoomStatusPresentation.maintenance().label, '維修中');
    expect(RoomStatusPresentation.disabled().label, '未啟用');

    expect(
      RoomStatusPresentation.fromHousekeepingLabel('清潔中').color,
      RoomStatusPresentation.calendarDot('cleaning').color,
    );
    expect(
      RoomStatusPresentation.fromHousekeepingLabel(
        '入住中',
        booking: <String, dynamic>{
          'bookingKind': 'daycare',
          'status': 'checked_in',
        },
      ).label,
      RoomStatusPresentation.daycareCheckedIn().label,
    );
    expect(
      RoomStatusPresentation.fromHousekeepingLabel('已訂').label,
      RoomStatusPresentation.calendarDot('booked').label,
    );

    final Set<Color> legendColors = RoomStatusPresentation.legendItems()
        .map((RoomStatusPresentation item) => item.color)
        .toSet();
    expect(
      roomDayBookingCovers(
        booking: <String, dynamic>{
          'startDate': DateTime.parse('2026-10-01T00:00:00+08:00'),
          'endDate': DateTime.parse('2026-10-03T00:00:00+08:00'),
        },
        date: DateTime(2026, 9, 30),
      ),
      isFalse,
    );
    expect(
      roomDayBookingCovers(
        booking: <String, dynamic>{
          'startDate': DateTime.parse('2026-10-01T00:00:00+08:00'),
          'endDate': DateTime.parse('2026-10-03T00:00:00+08:00'),
        },
        date: DateTime(2026, 10, 1),
      ),
      isTrue,
    );
    expect(
      roomDayBookingCovers(
        booking: <String, dynamic>{
          'startDate': DateTime.parse('2026-10-01T00:00:00+08:00'),
          'endDate': DateTime.parse('2026-10-03T00:00:00+08:00'),
        },
        date: DateTime(2026, 10, 3),
      ),
      isFalse,
    );

    final Map<String, dynamic> completedStay = <String, dynamic>{
      'bookingKind': 'accommodation',
      'status': 'completed',
      'roomId': 'A1',
      'startDate': DateTime(2026, 9, 29),
      'endDate': DateTime(2026, 10, 1),
    };
    final RoomDayStatus stayed = resolveRoomDayStatus(
      date: DateTime(2026, 9, 29),
      today: DateTime(2026, 10, 1),
      calendarStatus: '',
      booking: completedStay,
    );
    final RoomDayStatus stayedNext = resolveRoomDayStatus(
      date: DateTime(2026, 9, 30),
      today: DateTime(2026, 10, 1),
      calendarStatus: 'booked',
      booking: completedStay,
    );
    final RoomDayStatus cleaningDay = resolveRoomDayStatus(
      date: DateTime(2026, 10, 1),
      today: DateTime(2026, 10, 1),
      calendarStatus: 'cleaning',
      booking: completedStay,
    );
    expect(stayed.color, RoomStatusPresentation.stayColor);
    expect(stayed.presentation.label, '住宿・已訂');
    expect(stayed.isHistory, isFalse);
    expect(stayedNext.color, RoomStatusPresentation.stayColor);
    expect(cleaningDay.color, RoomStatusPresentation.cleaningColor);
    expect(cleaningDay.presentation.label, '清潔中');
    expect(
      resolveRoomDayStatus(
        date: DateTime(2026, 10, 2),
        today: DateTime(2026, 10, 2),
        calendarStatus: 'completed',
      ).presentation.label,
      '退房／完成',
    );

    expect(
      legendColors,
      containsAll(<Color>[
        RoomStatusPresentation.availableColor,
        RoomStatusPresentation.stayColor,
        RoomStatusPresentation.daycareColor,
        RoomStatusPresentation.checkedInColor,
        RoomStatusPresentation.completedColor,
        RoomStatusPresentation.checkoutHoldColor,
        RoomStatusPresentation.cleaningColor,
        RoomStatusPresentation.closedColor,
        RoomStatusPresentation.maintenanceColor,
        RoomStatusPresentation.disabledColor,
      ]),
    );
  });

  test('房間與日期點擊只選取，只有查看訂單才導航', () {
    final RoomDayBookingChoice stay = RoomDayBookingChoice(
      id: 'stay-1',
      data: <String, dynamic>{
        'roomId': 'r1',
        'status': 'confirmed',
        'bookingKind': 'stay',
        'startDate': DateTime(2026, 9, 1),
        'endDate': DateTime(2026, 9, 3),
      },
    );
    final RoomDayBookingChoice daycare = RoomDayBookingChoice(
      id: 'day-1',
      data: <String, dynamic>{
        'roomId': 'r1',
        'status': 'pending',
        'bookingKind': 'daycare',
        'startDate': DateTime(2026, 9, 1),
        'endDate': DateTime(2026, 9, 2),
      },
    );
    final RoomDayBookingChoice otherRoom = RoomDayBookingChoice(
      id: 'other',
      data: <String, dynamic>{
        'roomId': 'r2',
        'status': 'checked_in',
        'startDate': DateTime(2026, 9, 1),
        'endDate': DateTime(2026, 9, 3),
      },
    );
    final RoomDayBookingChoice cancelled = RoomDayBookingChoice(
      id: 'gone',
      data: <String, dynamic>{
        'roomId': 'r1',
        'status': 'cancelled',
        'startDate': DateTime(2026, 9, 1),
        'endDate': DateTime(2026, 9, 3),
      },
    );

    final DateTime day = DateTime(2026, 9, 1);
    for (final RoomOverviewGesture gesture in <RoomOverviewGesture>[
      RoomOverviewGesture.roomCard,
      RoomOverviewGesture.weekDot,
      RoomOverviewGesture.calendarDay,
    ]) {
      final RoomOverviewGestureResult result = resolveRoomOverviewGesture(
        gesture: gesture,
        roomId: 'r1',
        date: day,
        bookingId: 'stay-1',
      );
      expect(result.navigatesToOrder, isFalse);
      expect(result.roomId, 'r1');
      expect(result.date, day);
    }

    final RoomOverviewGestureResult viewOrder = resolveRoomOverviewGesture(
      gesture: RoomOverviewGesture.viewOrderButton,
      roomId: 'r1',
      date: day,
      bookingId: 'stay-1',
    );
    expect(viewOrder.navigatesToOrder, isTrue);
    expect(viewOrder.bookingId, 'stay-1');

    final List<RoomDayBookingChoice> many = activeBookingsOnRoomDay(
      bookings: <RoomDayBookingChoice>[stay, daycare, otherRoom, cancelled],
      roomId: 'r1',
      day: day,
      occupancies: <Map<String, dynamic>>[
        <String, dynamic>{
          'status': 'active',
          'roomId': 'r1',
          'bookingId': 'day-1',
          'serviceDate': '2026-09-01',
        },
      ],
    );
    expect(many.map((RoomDayBookingChoice item) => item.id).toSet(), <String>{
      'stay-1',
      'day-1',
    });
  });

  testWidgets('訂單摘要只有按下查看訂單才回傳該筆', (WidgetTester tester) async {
    final RoomDayBookingChoice stay = RoomDayBookingChoice(
      id: 'stay-1',
      data: <String, dynamic>{
        'customerName': '王小明',
        'petNames': <String>['豆豆'],
        'status': 'confirmed',
        'bookingKind': 'stay',
      },
    );
    final RoomDayBookingChoice daycare = RoomDayBookingChoice(
      id: 'day-1',
      data: <String, dynamic>{
        'customerName': '林安親',
        'petName': '咪咪',
        'status': 'pending',
        'bookingKind': 'daycare',
      },
    );
    final List<String> opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomDayOrderSummaries(
            orders: <RoomDayBookingChoice>[stay, daycare],
            onViewOrder: (RoomDayBookingChoice choice) {
              opened.add(choice.id);
            },
          ),
        ),
      ),
    );
    expect(find.text('服務類型：住宿'), findsOneWidget);
    expect(find.text('服務類型：安親'), findsOneWidget);
    expect(find.text('客戶：王小明'), findsOneWidget);
    expect(find.text('查看訂單'), findsNWidgets(2));
    await tester.tap(find.text('客戶：王小明'));
    await tester.pump();
    expect(opened, isEmpty);
    await tester.tap(find.text('查看訂單').at(1));
    await tester.pump();
    expect(opened, <String>['day-1']);
  });

  testWidgets('沒有訂單時顯示所選日期沒有有效訂單', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomDayOrderSummaries(
            orders: const <RoomDayBookingChoice>[],
            onViewOrder: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('此日期沒有有效訂單或安親訂單'), findsOneWidget);
    expect(find.text('查看訂單'), findsNothing);
  });

  testWidgets('清潔完成按取消不回傳可寫入的狀態', (WidgetTester tester) async {
    String? written;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () async {
                final String? result = await showRoomCleaningCompleteDialog(
                  context,
                );
                written = result ?? 'cancelled';
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.text('完成並立即開放'), findsOneWidget);
    expect(find.text('完成但今日維持關閉'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(written, 'cancelled');
  });

  testWidgets('清潔完成確認後才回傳所選結果', (WidgetTester tester) async {
    String? written;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () async {
                written = await showRoomCleaningCompleteDialog(context);
              },
              child: const Text('開啟'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成但今日維持關閉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(written, 'closed');
  });

  testWidgets('所選日期摘要顯示該日狀態，而不是固定今天待辦', (WidgetTester tester) async {
    final DateTime selected = DateTime(2026, 9, 18);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSelectedDateSummary(
            date: selected,
            status: resolveRoomDayStatus(
              date: selected,
              today: DateTime(2026, 9, 29),
              calendarStatus: 'cleaning',
              booking: <String, dynamic>{
                'status': 'confirmed',
                'bookingKind': 'stay',
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('所選日期 2026/09/18'), findsOneWidget);
    expect(find.text('清潔中'), findsOneWidget);
    expect(find.text('今日待處理'), findsNothing);
  });

  test('退房日待清潔文案依台灣營業日區分過去、今天、未來', () {
    final DateTime today = DateTime(2026, 10, 10);
    final String past = checkoutHoldExplanation(DateTime(2026, 10, 3), today);
    final String current = checkoutHoldExplanation(
      DateTime(2026, 10, 10),
      today,
    );
    final String future = checkoutHoldExplanation(
      DateTime(2026, 10, 12),
      today,
    );
    expect(past, '此日為住宿退房日的待清潔保留紀錄。歷史日期僅供查詢。');
    expect(past.contains('目前尚未完成退房'), isFalse);
    expect(past.contains('暫時無法開始清潔'), isFalse);
    expect(roomCalendarDateIsPast(DateTime(2026, 10, 3), today), isTrue);
    expect(current.contains('目前尚未完成退房'), isTrue);
    expect(current.contains('此房今日有住宿退房'), isTrue);
    expect(roomCalendarDateIsPast(DateTime(2026, 10, 10), today), isFalse);
    expect(future.contains('今日'), isFalse);
    expect(future.contains('預留為退房清潔時段'), isTrue);
    expect(roomCalendarDateIsPast(DateTime(2026, 10, 12), today), isFalse);
  });

  test('安親時段占用顯示在當天，失效或隔天不占房，房務待辦不含未分房', () {
    final DateTime serviceDay = DateTime(2026, 10, 3);
    final Map<String, dynamic> daycare = <String, dynamic>{
      'roomId': 'A2',
      'bookingKind': 'daycare',
      'status': 'confirmed',
      'serviceDate': '2026-10-03',
      'scheduledStartAt': DateTime.parse('2026-10-03T09:00:00+08:00'),
      'scheduledEndAt': DateTime.parse('2026-10-03T16:00:00+08:00'),
    };
    final Map<String, dynamic> occupancy = <String, dynamic>{
      'status': 'active',
      'roomId': 'A2',
      'bookingId': 'dc-1',
      'serviceDate': '2026-10-03',
    };
    expect(
      roomDayBookingCovers(booking: daycare, date: serviceDay),
      isTrue,
    );
    expect(
      roomDayBookingCovers(booking: daycare, date: DateTime(2026, 10, 4)),
      isFalse,
    );
    expect(daycareServiceTimeLabel(daycare), '09:00～16:00');

    RoomDayStatus shown(String status, DateTime day) {
      final List<RoomDayBookingChoice> matches = activeBookingsOnRoomDay(
        bookings: <RoomDayBookingChoice>[
          RoomDayBookingChoice(id: 'dc-1', data: <String, dynamic>{
            ...daycare,
            'status': status,
          }),
        ],
        roomId: 'A2',
        day: day,
        occupancies: <Map<String, dynamic>>[occupancy],
      );
      return resolveRoomDayStatus(
        date: day,
        today: serviceDay,
        booking: matches.isEmpty ? null : matches.single.data,
      );
    }

    expect(shown('confirmed', serviceDay).label, '安親・已訂');
    expect(shown('checked_in', serviceDay).label, '安親中');
    expect(shown('cancelled', serviceDay).label, '空房');
    expect(shown('completed', serviceDay).label, '空房');
    expect(shown('no_show', serviceDay).label, '空房');
    expect(shown('confirmed', DateTime(2026, 10, 4)).label, '空房');

    final RoomDayBookingChoice morning = RoomDayBookingChoice(
      id: 'dc-am',
      data: daycare,
    );
    final RoomDayBookingChoice afternoon = RoomDayBookingChoice(
      id: 'dc-pm',
      data: <String, dynamic>{
        ...daycare,
        'scheduledStartAt': DateTime.parse('2026-10-03T13:00:00+08:00'),
        'scheduledEndAt': DateTime.parse('2026-10-03T16:00:00+08:00'),
      },
    );
    final List<RoomDayBookingChoice> both = activeBookingsOnRoomDay(
      bookings: <RoomDayBookingChoice>[morning, afternoon],
      roomId: 'A2',
      day: serviceDay,
      occupancies: <Map<String, dynamic>>[
        <String, dynamic>{
          ...occupancy,
          'bookingId': 'dc-am',
        },
        <String, dynamic>{
          ...occupancy,
          'bookingId': 'dc-pm',
        },
      ],
    );
    expect(both.map((RoomDayBookingChoice item) => item.id).toList(), <String>[
      'dc-am',
      'dc-pm',
    ]);
    expect(
      planRoomOverviewOpen(both).kind,
      RoomOverviewOpenKind.bookingPicker,
    );

    final RoomDayStatus checkout = resolveRoomDayStatus(
      date: serviceDay,
      today: serviceDay,
      calendarStatus: 'checkout_cleaning',
      booking: daycare,
    );
    expect(checkout.label, '退房日・待清潔');
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(checkout.presentation),
      isTrue,
    );
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(
        RoomStatusPresentation.cleaning(),
      ),
      isTrue,
    );
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(
        RoomStatusPresentation.available(),
      ),
      isFalse,
    );
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(
        RoomStatusPresentation.daycareBooked(),
      ),
      isFalse,
    );
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(
        RoomStatusPresentation.stayBooked(),
      ),
      isFalse,
    );
    expect(
      RoomStatusPresentation.countsAsHousekeepingTodo(
        RoomStatusPresentation.stayCheckedIn(),
      ),
      isFalse,
    );
  });
}

int _channelGap(Color a, Color b) {
  int gap(double left, double right) => ((left - right).abs() * 255).round();
  return gap(a.r, b.r) + gap(a.g, b.g) + gap(a.b, b.b);
}
