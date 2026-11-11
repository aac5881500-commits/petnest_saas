import 'package:flutter/material.dart';
import 'package:petnest_saas/features/room/widgets/workbench_booking_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/room/widgets/workbench_views.dart';

void main() {
  test('task dates use Taipei calendar dates and daycare service dates', () {
    expect(
      workbenchBookingTaskDate({
        'startDate': DateTime.utc(2026, 11, 5, 18),
      }, departure: false),
      DateTime(2026, 11, 6),
    );
    expect(
      workbenchBookingTaskDate({
        'bookingKind': 'daycare',
        'serviceDate': '2026-11-06',
      }, departure: true),
      DateTime(2026, 11, 6),
    );
    expect(workbenchBookingTaskDate({}, departure: false), isNull);
  });
  testWidgets(
    'settings retains original and housekeeping while selecting each layout',
    (tester) async {
      var selected = WorkbenchView.original;
      var settingsOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => Scaffold(
              appBar: AppBar(
                actions: [
                  WorkbenchSettingsMenu(
                    selected: selected,
                    onChanged: (value) => update(() => selected = value),
                    onHousekeeping: () => settingsOpened = true,
                  ),
                ],
              ),
              body: Text('selected:${selected.name}'),
            ),
          ),
        ),
      );
      for (final view in [
        ...WorkbenchView.values.skip(1),
        WorkbenchView.original,
      ]) {
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.text('原本排版'), findsOneWidget);
        expect(find.text('房務設定'), findsOneWidget);
        await tester.tap(
          find.ancestor(
            of: find.text(view.label),
            matching: find.byType(CheckedPopupMenuItem<String>),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('selected:${view.name}'), findsOneWidget);
      }
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('房務設定'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue);
    },
  );

  testWidgets('timeline scrolls on mobile and maps room/day taps correctly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final days = List.generate(7, (i) => DateTime(2026, 11, 2 + i));
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 844);
      var selected = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchTimeline(
              key: ValueKey(width),
              days: days,
              names: const ['A1', 'A2'],
              types: const ['日式豪房', '標準房'],
              selectedRow: 0,
              selectedDay: days[4],
              labelAt: (row, col) => row == 0 ? '入住中\n麻糬' : '待清潔',
              colorAt: (row, col) => row == 0 ? Colors.blue : Colors.orange,
              onSelect: (row, col) => selected = '$row:$col',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('待清潔').first);
      expect(selected, '1:0');
      if (width < 1000) {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-900, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
