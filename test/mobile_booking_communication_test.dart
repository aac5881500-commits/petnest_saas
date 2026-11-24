import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_communication_summary.dart';
import 'package:petnest_saas/features/medication/service_task_page.dart';

void main() {
  testWidgets('手機交接分頁一次只顯示一區且保留留言筆數', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingCommunicationTabs(
            unread: 2,
            pages: [Text('交接內容'), Text('備註內容'), Text('表單內容'), Text('留言內容')],
          ),
        ),
      ),
    );
    expect(find.text('交接內容'), findsOneWidget);
    expect(find.text('表單內容'), findsNothing);
    await tester.tap(find.text('表單'));
    await tester.pumpAndSettle();
    expect(find.text('表單內容'), findsOneWidget);
    expect(find.text('交接內容'), findsNothing);
    await tester.tap(find.text('留言 2'));
    await tester.pumpAndSettle();
    expect(find.text('留言內容'), findsOneWidget);
    expect(find.text('表單內容'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('未執行允許入住前時間，已完成仍拒絕，未來仍拒絕', () {
    final actual = DateTime.utc(2026, 11, 22, 13);
    final start = DateTime.utc(2026, 11, 22, 14);
    final now = DateTime.utc(2026, 11, 22, 15);
    expect(
      serviceActualTimeError(
        actual: actual,
        checkIn: start,
        now: now,
        skipped: true,
      ),
      isNull,
    );
    expect(
      serviceActualTimeError(actual: actual, checkIn: start, now: now),
      contains('早於入住'),
    );
    expect(
      serviceActualTimeError(
        actual: now.add(const Duration(hours: 1)),
        checkIn: start,
        now: now,
        skipped: true,
      ),
      contains('晚於現在'),
    );
  });
}
