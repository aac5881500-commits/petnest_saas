// 檔案名稱：test/housekeeping_workbench_test.dart
// 功能說明：現場巡房工作台的篩選、排序、選取與下一筆。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/features/room/models/housekeeping_workbench_task.dart';
import 'package:petnest_saas/features/room/services/housekeeping_workbench_logic.dart';
import 'package:petnest_saas/features/room/widgets/housekeeping_workbench.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 26);

  test('待處理不顯示空房，並依漏填、今天、房務、入住退房排序', () {
    final HousekeepingWorkbenchBoard board = HousekeepingWorkbenchLogic.build(
      rooms: <HousekeepingRoomInput>[
        _room('vacant', '空房B', DaycareOccupancyService.vacantLabel),
        _room('clean', 'A03', DaycareOccupancyService.cleaningLabel),
        _room('arrive', 'A04', '已訂', bookingId: 'bArrive'),
        _room('in', 'A08', '入住中', bookingId: 'bStay'),
      ],
      bookings: <HousekeepingBookingMark>[
        HousekeepingBookingMark(
          roomId: 'arrive',
          bookingId: 'bArrive',
          start: today,
          status: 'confirmed',
        ),
      ],
      items: <DailyCareReportCenterItem>[
        _item(bookingId: 'bOld', roomName: 'A02', date: DateTime(2026, 9, 25)),
        _item(bookingId: 'bToday', roomName: 'A01', date: today, session: 1),
        _item(
          bookingId: 'bLock',
          roomName: 'A06',
          date: DateTime(2026, 9, 24),
          locked: true,
        ),
      ],
      filter: HousekeepingWorkbenchFilter.todo,
      today: today,
      selectedDate: today,
    );

    expect(
      board.visible.map((HousekeepingWorkbenchTask task) => task.title),
      <String>['A02', 'A01', 'A03', 'A04'],
    );
    expect(
      board.visible.map((HousekeepingWorkbenchTask task) => task.taskName),
      <String>['上午', '下午', '待清潔', '今日入住'],
    );
    expect(
      board.visible.any(
        (HousekeepingWorkbenchTask task) => task.title == '空房B',
      ),
      isFalse,
    );
    expect(
      board.visible.any(
        (HousekeepingWorkbenchTask task) => task.title == 'A06',
      ),
      isFalse,
    );
  });

  test('已鎖定歷史未完成只出現在待回報', () {
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[
      _item(
        bookingId: 'bLock',
        roomName: 'A06',
        date: DateTime(2026, 9, 24),
        locked: true,
      ),
    ];
    final HousekeepingWorkbenchBoard todo = HousekeepingWorkbenchLogic.build(
      rooms: const <HousekeepingRoomInput>[],
      bookings: const <HousekeepingBookingMark>[],
      items: items,
      filter: HousekeepingWorkbenchFilter.todo,
      today: today,
      selectedDate: today,
    );
    final HousekeepingWorkbenchBoard reports = HousekeepingWorkbenchLogic.build(
      rooms: const <HousekeepingRoomInput>[],
      bookings: const <HousekeepingBookingMark>[],
      items: items,
      filter: HousekeepingWorkbenchFilter.reports,
      today: today,
      selectedDate: today,
    );
    expect(todo.visible, isEmpty);
    expect(reports.visible, hasLength(1));
    expect(reports.visible.single.statusLabel, '已鎖定');
    expect(reports.visible.single.muted, isTrue);
  });

  test('回報選取帶入 bookingId、日期與場次', () {
    final HousekeepingWorkbenchTask task = HousekeepingWorkbenchLogic.build(
      rooms: const <HousekeepingRoomInput>[],
      bookings: const <HousekeepingBookingMark>[],
      items: <DailyCareReportCenterItem>[
        _item(
          bookingId: 'b1',
          roomId: 'room-a',
          roomName: 'A01',
          date: today,
          session: 2,
        ),
      ],
      filter: HousekeepingWorkbenchFilter.todo,
      today: today,
      selectedDate: today,
    ).visible.single;
    final HousekeepingWorkbenchSelection selection =
        HousekeepingWorkbenchLogic.selectionFor(task);
    expect(selection.bookingId, 'b1');
    expect(selection.roomId, 'room-a');
    expect(selection.recordDate, today);
    expect(selection.sessionIndex, 2);
  });

  test('入住中預設選今天第一個可填場次', () {
    final HousekeepingRoomInput room = _room(
      'r1',
      'A01',
      '入住中',
      bookingId: 'bStay',
    );
    final HousekeepingWorkbenchSelection selection =
        HousekeepingWorkbenchLogic.selectionForStay(
          room: room,
          today: today,
          items: <DailyCareReportCenterItem>[
            _item(
              bookingId: 'bStay',
              roomId: 'r1',
              date: DateTime(2026, 9, 25),
              session: 0,
            ),
            _item(
              bookingId: 'bStay',
              roomId: 'r1',
              date: today,
              session: 0,
              completed: true,
            ),
            _item(bookingId: 'bStay', roomId: 'r1', date: today, session: 1),
          ],
        );
    expect(selection.bookingId, 'bStay');
    expect(selection.recordDate, today);
    expect(selection.sessionIndex, 1);
  });

  test('儲存後先選同一訂單下一場，再選下一筆待回報', () {
    final List<DailyCareReportCenterItem> items = <DailyCareReportCenterItem>[
      _item(bookingId: 'b1', date: today, session: 0),
      _item(bookingId: 'b1', date: today, session: 1),
      _item(bookingId: 'b2', roomName: 'B02', date: today, session: 0),
    ];
    final HousekeepingWorkbenchSelection? next =
        HousekeepingWorkbenchLogic.nextAfterSave(
          items: items,
          bookingId: 'b1',
          recordDate: today,
          sessionIndex: 0,
          today: today,
        );
    expect(next?.bookingId, 'b1');
    expect(next?.sessionIndex, 1);

    final HousekeepingWorkbenchSelection? after =
        HousekeepingWorkbenchLogic.nextAfterSave(
          items: items,
          bookingId: 'b1',
          recordDate: today,
          sessionIndex: 1,
          today: today,
          savedSessionKeys: <String>{'b1|2026/09/26|0', 'b1|2026/09/26|1'},
        );
    expect(after?.bookingId, 'b2');
    expect(after?.sessionIndex, 0);

    final HousekeepingWorkbenchSelection? done =
        HousekeepingWorkbenchLogic.nextAfterSave(
          items: items,
          bookingId: 'b2',
          recordDate: today,
          sessionIndex: 0,
          today: today,
          savedSessionKeys: <String>{
            'b1|2026/09/26|0',
            'b1|2026/09/26|1',
            'b2|2026/09/26|0',
          },
        );
    expect(done, isNull);
  });

  test('沒有房間的安親仍出現在待回報', () {
    final HousekeepingWorkbenchBoard board = HousekeepingWorkbenchLogic.build(
      rooms: <HousekeepingRoomInput>[
        _room('vacant', '空房B', DaycareOccupancyService.vacantLabel),
      ],
      bookings: const <HousekeepingBookingMark>[],
      items: <DailyCareReportCenterItem>[
        _item(
          bookingId: 'day1',
          date: today,
          daycare: true,
          roomId: '',
          roomName: '',
          customer: '小安',
          pets: '奶茶',
        ),
      ],
      filter: HousekeepingWorkbenchFilter.todo,
      today: today,
      selectedDate: today,
    );
    expect(board.visible, hasLength(1));
    expect(board.visible.single.title, '安親');
    expect(board.visible.single.roomId, isEmpty);
    expect(board.visible.single.subtitle, contains('小安／奶茶'));
  });

  test('小於分割門檻不顯示桌機工作台', () {
    expect(
      HousekeepingWorkbenchLogic.showsDesktopWorkbench(
        width: 1099,
        reportsEnabled: true,
        splitSelected: true,
      ),
      isFalse,
    );
    expect(
      HousekeepingWorkbenchLogic.showsDesktopWorkbench(
        width: 1100,
        reportsEnabled: true,
        splitSelected: true,
      ),
      isTrue,
    );
    expect(
      HousekeepingWorkbenchLogic.showsDesktopWorkbench(
        width: 1400,
        reportsEnabled: false,
        splitSelected: true,
      ),
      isFalse,
    );
    expect(
      HousekeepingWorkbenchLogic.showsDesktopWorkbench(
        width: 1400,
        reportsEnabled: true,
        splitSelected: false,
      ),
      isFalse,
    );
  });

  testWidgets('待處理不列出空房，全部房間才列出', (WidgetTester tester) async {
    await tester.pumpWidget(_BrowseHost(today: today));
    expect(
      find.byKey(const ValueKey<String>('housekeeping-workbench')),
      findsOneWidget,
    );
    expect(find.text('空房B'), findsNothing);
    expect(find.text('A02'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('workbench-filter-allRooms')),
    );
    await tester.pumpAndSettle();
    expect(find.text('空房B'), findsOneWidget);
  });

  testWidgets('點回報與入住中會帶入場次，儲存後前往下一筆', (WidgetTester tester) async {
    final _Harness harness = _Harness(today: today);
    await tester.pumpWidget(harness);
    await tester.tap(
      find.byKey(const ValueKey<String>('workbench-task-report-b1-20260926-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('editor-b1-0'), findsOneWidget);

    await tester.tap(find.text('儲存這一場'));
    await tester.pumpAndSettle();
    expect(find.text('editor-b1-1'), findsOneWidget);

    await tester.tap(find.text('儲存這一場'));
    await tester.pumpAndSettle();
    expect(find.text('editor-b2-0'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('workbench-filter-checkedIn')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('workbench-task-stay-rStay')),
    );
    await tester.pumpAndSettle();
    expect(find.text('editor-bStay-1'), findsOneWidget);
  });
}

HousekeepingRoomInput _room(
  String id,
  String name,
  String status, {
  String bookingId = '',
}) {
  return HousekeepingRoomInput(
    id: id,
    name: name,
    statusLabel: status,
    bookingId: bookingId,
  );
}

DailyCareReportCenterItem _item({
  required String bookingId,
  required DateTime date,
  String roomId = 'r',
  String roomName = 'A01',
  int session = 0,
  bool completed = false,
  bool locked = false,
  bool daycare = false,
  String customer = '客人',
  String pets = '毛毛',
}) {
  return DailyCareReportCenterItem(
    id: '$bookingId-$session-${date.day}',
    shopId: 'shop',
    bookingId: bookingId,
    sessionIndex: session,
    sessionName: session == 0 ? '上午' : '下午',
    recordDate: date,
    entitlement: const DailyCareEntitlement(),
    serviceType: daycare
        ? DailyCareServiceTypes.daycare
        : DailyCareServiceTypes.accommodation,
    roomId: roomId,
    roomName: roomName,
    customerName: customer,
    petNames: <String>[pets],
    isCompleted: completed,
    reportsLocked: locked,
    canOperate: true,
  );
}

class _BrowseHost extends StatefulWidget {
  const _BrowseHost({required this.today});

  final DateTime today;

  @override
  State<_BrowseHost> createState() => _BrowseHostState();
}

class _BrowseHostState extends State<_BrowseHost> {
  HousekeepingWorkbenchFilter filter = HousekeepingWorkbenchFilter.todo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          height: 800,
          child: HousekeepingWorkbench(
            shopId: 'shop',
            rooms: <HousekeepingRoomInput>[
              _room('vacant', '空房B', DaycareOccupancyService.vacantLabel),
              _room('clean', 'A03', DaycareOccupancyService.cleaningLabel),
            ],
            bookings: const <HousekeepingBookingMark>[],
            items: <DailyCareReportCenterItem>[
              _item(
                bookingId: 'bOld',
                roomName: 'A02',
                date: DateTime(2026, 9, 25),
              ),
            ],
            today: widget.today,
            selectedDate: widget.today,
            filter: filter,
            selection: null,
            setting: const DailyCareSettingModel(),
            onFilter: (HousekeepingWorkbenchFilter value) {
              setState(() => filter = value);
            },
            onSelection: (_) {},
            onShiftDate: (_) {},
            onToday: () {},
            actionsFor: (_) => const <HousekeepingWorkbenchAction>[],
            onOpenRoom: (_) {},
            editorBuilder:
                ({
                  required HousekeepingWorkbenchTask task,
                  required DailyCareReportCenterItem item,
                  required DailyCareSettingModel setting,
                  required VoidCallback onSaved,
                }) {
                  return Text('editor-${item.bookingId}-${item.sessionIndex}');
                },
          ),
        ),
      ),
    );
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.today});

  final DateTime today;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  HousekeepingWorkbenchFilter filter = HousekeepingWorkbenchFilter.todo;
  HousekeepingWorkbenchSelection? selection;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1280,
          height: 900,
          child: HousekeepingWorkbench(
            shopId: 'shop',
            rooms: <HousekeepingRoomInput>[
              _room('rStay', 'A09', '入住中', bookingId: 'bStay'),
            ],
            bookings: const <HousekeepingBookingMark>[],
            items: <DailyCareReportCenterItem>[
              _item(
                bookingId: 'b1',
                roomName: 'A01',
                date: widget.today,
                session: 0,
              ),
              _item(
                bookingId: 'b1',
                roomName: 'A01',
                date: widget.today,
                session: 1,
              ),
              _item(
                bookingId: 'b2',
                roomName: 'B02',
                date: widget.today,
                session: 0,
              ),
              _item(
                bookingId: 'bStay',
                roomId: 'rStay',
                roomName: 'A09',
                date: widget.today,
                session: 0,
                completed: true,
              ),
              _item(
                bookingId: 'bStay',
                roomId: 'rStay',
                roomName: 'A09',
                date: widget.today,
                session: 1,
              ),
            ],
            today: widget.today,
            selectedDate: widget.today,
            filter: filter,
            selection: selection,
            setting: const DailyCareSettingModel(),
            onFilter: (HousekeepingWorkbenchFilter value) {
              setState(() => filter = value);
            },
            onSelection: (HousekeepingWorkbenchSelection? value) {
              setState(() => selection = value);
            },
            onShiftDate: (_) {},
            onToday: () {},
            actionsFor: (_) => const <HousekeepingWorkbenchAction>[],
            onOpenRoom: (_) {},
            editorBuilder:
                ({
                  required HousekeepingWorkbenchTask task,
                  required DailyCareReportCenterItem item,
                  required DailyCareSettingModel setting,
                  required VoidCallback onSaved,
                }) {
                  return Column(
                    children: <Widget>[
                      Text('editor-${item.bookingId}-${item.sessionIndex}'),
                      TextButton(
                        onPressed: onSaved,
                        child: const Text('儲存這一場'),
                      ),
                    ],
                  );
                },
          ),
        ),
      ),
    );
  }
}
