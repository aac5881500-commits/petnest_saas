import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
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
      legendColors,
      containsAll(<Color>[
        RoomStatusPresentation.availableColor,
        RoomStatusPresentation.stayColor,
        RoomStatusPresentation.daycareColor,
        RoomStatusPresentation.checkedInColor,
        RoomStatusPresentation.completedColor,
        RoomStatusPresentation.cleaningColor,
        RoomStatusPresentation.closedColor,
        RoomStatusPresentation.maintenanceColor,
        RoomStatusPresentation.disabledColor,
      ]),
    );
  });

  test('有訂單進訂單詳細，多筆不代選，沒有訂單才開房間紀錄', () {
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

    final List<RoomDayBookingChoice> none = activeBookingsOnRoomDay(
      bookings: <RoomDayBookingChoice>[otherRoom, cancelled],
      roomId: 'r1',
      day: DateTime(2026, 9, 1),
    );
    expect(planRoomOverviewOpen(none).kind, RoomOverviewOpenKind.roomRecord);

    final List<RoomDayBookingChoice> one = activeBookingsOnRoomDay(
      bookings: <RoomDayBookingChoice>[stay, otherRoom],
      roomId: 'r1',
      day: DateTime(2026, 9, 2),
    );
    final RoomOverviewOpenPlan onePlan = planRoomOverviewOpen(one);
    expect(onePlan.kind, RoomOverviewOpenKind.orderDetail);
    expect(onePlan.booking?.id, 'stay-1');

    final List<RoomDayBookingChoice> many = activeBookingsOnRoomDay(
      bookings: <RoomDayBookingChoice>[stay, daycare],
      roomId: 'r1',
      day: DateTime(2026, 9, 1),
    );
    expect(many.map((RoomDayBookingChoice item) => item.id).toSet(), <String>{
      'stay-1',
      'day-1',
    });
    final RoomOverviewOpenPlan manyPlan = planRoomOverviewOpen(many);
    expect(manyPlan.kind, RoomOverviewOpenKind.bookingPicker);
    expect(manyPlan.booking, isNull);
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
}
