import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_schedule.dart';
import 'package:petnest_saas/features/admin/widgets/order_care_progress_tables.dart';

DailyCareReportCenterItem session(
  int day,
  int index, {
  bool done = false,
  bool locked = false,
  bool canOperate = true,
}) => DailyCareReportCenterItem(
  id: '$day-$index',
  shopId: 's',
  bookingId: 'b',
  sessionIndex: index,
  sessionName: '第${index + 1}次照護',
  recordDate: DateTime(2026, 11, day),
  entitlement: const DailyCareEntitlement(enabled: true, finalReports: 3),
  isCompleted: done,
  reportsLocked: locked,
  canOperate: canOperate,
  photoCount: done ? 3 : 0,
);

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('回報表日期場次對應正確，$width 寬不溢出', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DailyCareReportCenterItem? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderDailyCareProgressTable(
                sessions: [
                  for (var day = 15; day <= 17; day++)
                    for (var index = 0; index < 3; index++)
                      session(day, index, done: day == 15),
                ],
                onSelect: (item) => selected = item,
              ),
            ),
          ),
        ),
      );
      expect(find.text('已完成 3/9 場'), findsOneWidget);
      expect(find.text('11/15'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      await tester.tap(find.text('＋ 填寫').first);
      expect(selected?.id, '16-0');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('鎖定或無權限不能填寫，已完成鎖定紀錄仍可查看', (tester) async {
    DailyCareReportCenterItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderDailyCareProgressTable(
            sessions: [
              session(15, 0, locked: true),
              session(15, 1, canOperate: false),
              session(15, 2, locked: true, done: true),
            ],
            onSelect: (item) => selected = item,
          ),
        ),
      ),
    );
    await tester.tap(find.text('已鎖定'));
    expect(selected, isNull);
    await tester.tap(find.text('＋ 填寫'));
    expect(selected, isNull);
    await tester.tap(find.text('已完成'));
    expect(selected?.id, '15-2');
  });
  testWidgets('同時間兩隻寵物分開保留，點右箭頭可選最晚時間', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      BookingScheduleEntry(
        kind: BookingScheduleKind.medication,
        time: DateTime.utc(2026, 11, 15, 1),
        title: '口服藥',
        detail: '布丁',
      ),
      BookingScheduleEntry(
        kind: BookingScheduleKind.medication,
        time: DateTime.utc(2026, 11, 15, 1),
        title: '擦藥',
        detail: '咪咪',
      ),
      BookingScheduleEntry(
        kind: BookingScheduleKind.service,
        time: DateTime.utc(2026, 11, 15, 13),
        title: '陪玩',
        detail: '布丁',
      ),
      BookingScheduleEntry(
        kind: BookingScheduleKind.medication,
        time: DateTime.utc(2026, 11, 16, 3),
        title: '晚間用藥',
        detail: '咪咪',
      ),
    ];
    BookingScheduleEntry? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderCareScheduleProgressTable(
            entries: entries,
            onSelect: (item) => selected = item,
          ),
        ),
      ),
    );
    expect(find.textContaining('布丁'), findsWidgets);
    expect(find.textContaining('咪咪'), findsWidgets);
    await tester.tap(find.text('擦藥'));
    expect(selected, same(entries[1]));
    expect(find.text('向右查看更多時段'), findsOneWidget);
    await tester.tap(find.text('向右查看更多時段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('陪玩'));
    expect(selected, same(entries[2]));
    expect(tester.takeException(), isNull);
  });
}
