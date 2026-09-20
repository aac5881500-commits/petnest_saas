// 檔案名稱：test/shop_booking_date_help_pagestorage_test.dart
// 功能說明：確認日期說明 ExpansionTile 不與捲動 PageStorage 的 0 碰撞。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

void main() {
  testWidgets('說明區獨立 PageStorageKey 時，父層寫入 int 0 不會紅屏', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PageStorage(
          bucket: PageStorageBucket(),
          child: Scaffold(
            body: KeyedSubtree(
              key: const PageStorageKey<String>('setup-booking-shop'),
              child: Builder(
                builder: (BuildContext context) {
                  PageStorage.of(context).writeState(context, 0);
                  return const ExpansionTile(
                    key: PageStorageKey<String>('shopBookingDateHelp'),
                    initiallyExpanded: true,
                    title: Text('日期管理說明'),
                    children: <Widget>[Text('說明內容')],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('日期管理說明'), findsOneWidget);
    expect(find.text('說明內容'), findsOneWidget);
  });

  testWidgets('390／800／1366 寬度月曆可建立且可點日期', (WidgetTester tester) async {
    final DateTime today = DateTime(2026, 9, 18);
    DateTime? tapped;
    for (final double width in <double>[390, 800, 1366]) {
      tapped = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: BookingCalendar(
                    initialMonth: today,
                    firstDate: today,
                    lastDate: today.add(const Duration(days: 30)),
                    compactCells: width < 720,
                    allowBlockedTap: true,
                    onDayTap: (DateTime date) {
                      tapped = date;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BookingCalendar), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.pump();
      expect(tapped, isNotNull);
    }
  });
}
