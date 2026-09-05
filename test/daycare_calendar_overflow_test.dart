// 檔案名稱：test/daycare_calendar_overflow_test.dart
// 功能說明：安親日曆溢出的單元測試

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

void main() {
  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                BookingCalendar(
                  compactCells: true,
                  initialMonth: DateTime(2026, 9),
                  firstDate: DateTime(2026, 9, 1),
                  lastDate: DateTime(2026, 10, 31),
                  onDayTap: (_) {},
                  blockedDateKeys: const <String>{'2026-09-03'},
                  unbookableDateKeys: const <String>{'2026-09-10'},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('320px compact calendar has no overflow', (
    WidgetTester tester,
  ) async {
    await pumpAtWidth(tester, 320);
  });

  testWidgets('360px compact calendar has no overflow', (
    WidgetTester tester,
  ) async {
    await pumpAtWidth(tester, 360);
  });

  testWidgets('392px compact calendar has no overflow', (
    WidgetTester tester,
  ) async {
    await pumpAtWidth(tester, 392);
  });

  testWidgets('406px compact calendar has no overflow', (
    WidgetTester tester,
  ) async {
    await pumpAtWidth(tester, 406);
  });
}
