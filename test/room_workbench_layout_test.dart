import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/features/room/widgets/room_workbench_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSansTC')
      ..addFont(
        rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
      );
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('status filters match exactly rather than the whole task queue', () {
    final statuses = [
      RoomStatusPresentation.available(),
      RoomStatusPresentation.stayBooked(),
      RoomStatusPresentation.stayCheckedIn(),
      RoomStatusPresentation.daycareCheckedIn(),
      RoomStatusPresentation.cleaning(),
      RoomStatusPresentation.closed(),
      RoomStatusPresentation.maintenance(),
      RoomStatusPresentation.disabled(),
    ];
    List<String> match(RoomOverviewFilter filter) => statuses
        .where(
          (status) => roomOverviewMatches(
            filter: filter,
            status: status,
            needsAction: RoomStatusPresentation.countsAsHousekeepingTodo(
              status,
            ),
          ),
        )
        .map((status) => status.value)
        .toList();
    expect(match(RoomOverviewFilter.cleaning), ['cleaning']);
    expect(match(RoomOverviewFilter.closed), ['closed']);
    expect(match(RoomOverviewFilter.maintenance), ['maintenance']);
    expect(match(RoomOverviewFilter.disabled), ['disabled']);
    expect(match(RoomOverviewFilter.inUse), [
      'occupied',
      'checked_in',
      'daycare_checked_in',
    ]);
    expect(match(RoomOverviewFilter.checkedIn), ['checked_in']);
    expect(match(RoomOverviewFilter.vacant), ['available']);
    expect(
      match(RoomOverviewFilter.needs),
      containsAll(['cleaning', 'closed', 'maintenance']),
    );
  });
  test(
    'keyword and state filters intersect; multiple search terms ignore case',
    () {
      bool match(String query, RoomOverviewFilter filter) =>
          roomOverviewMatches(
            filter: filter,
            status: RoomStatusPresentation.available(),
            needsAction: false,
            name: 'A01',
            type: '日式豪華房',
            pets: '小橘、Mimi',
            query: query,
          );
      expect(match(' a01   Mimi ', RoomOverviewFilter.vacant), isTrue);
      expect(match('日式 小橘', RoomOverviewFilter.all), isTrue);
      expect(match('A02', RoomOverviewFilter.all), isFalse);
      expect(match('A01', RoomOverviewFilter.cleaning), isFalse);
      expect(match('', RoomOverviewFilter.all), isTrue);
    },
  );
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double width = 1440,
    double height = 900,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget card({VoidCallback? onTap, ValueChanged<int>? onDayTap}) =>
      RoomWorkbenchRoomCard(
        name: 'A01',
        type: '日式豪華房',
        status: RoomStatusPresentation.available(),
        selected: true,
        days: List.generate(7, (index) => DateTime(2026, 10, 26 + index)),
        colors: List.filled(7, RoomStatusPresentation.availableColor),
        labels: List.filled(7, '空房'),
        selectedDate: DateTime(2026, 10, 26),
        onTap: onTap ?? () {},
        onDayTap: onDayTap ?? (_) {},
      );
  for (final width in [300.0, 360.0]) {
    testWidgets('room card at $width has readable date targets', (
      tester,
    ) async {
      var selected = -1;
      var opened = 0;
      await show(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: card(
              onTap: () => opened++,
              onDayTap: (index) => selected = index,
            ),
          ),
        ),
        width: width,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('28'));
      expect(selected, 2);
      expect(opened, 0);
      await tester.tap(find.text('A01'));
      expect(opened, 1);
      expect(find.byTooltip('10/28 · 空房'), findsOneWidget);
    });
  }
  for (final size in [
    const Size(700, 700),
    const Size(1100, 700),
    const Size(1600, 700),
  ]) {
    testWidgets('split rail remains bounded at $size', (tester) async {
      await show(
        tester,
        RoomWorkbenchSplit(
          rooms: Container(key: const ValueKey('rail')),
          detail: Container(key: const ValueKey('detail')),
        ),
        width: size.width,
        height: size.height,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('rail'))).width,
        inInclusiveRange(300, 360),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('detail'))).width,
        greaterThan(350),
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(320, 350),
    const Size(600, 700),
    const Size(1100, 700),
  ]) {
    testWidgets('calendar and actions adapt at $size', (tester) async {
      await show(
        tester,
        RoomRecordWorkspaceLayout(
          calendar: Container(
            key: const ValueKey('calendar'),
            color: Colors.white,
          ),
          detail: ListView(children: const [Text('當日房務'), Text('關閉此日')]),
        ),
        width: size.width,
        height: size.height,
      );
      expect(tester.takeException(), isNull);
      if (size.width >= 1000) {
        expect(tester.getTopLeft(find.text('當日房務')).dx, greaterThan(500));
      } else if (size.height < 480) {
        await tester.scrollUntilVisible(
          find.text('當日房務'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('當日房務').hitTestable(), findsOneWidget);
      } else {
        expect(tester.getTopLeft(find.text('當日房務')).dy, greaterThan(300));
      }
    });
  }
}
