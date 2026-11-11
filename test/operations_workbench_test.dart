import 'package:petnest_saas/core/models/room_status_palette.dart';
import 'package:petnest_saas/features/room/widgets/room_status_legend.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';
import 'package:petnest_saas/features/room/widgets/workbench_views.dart';
import 'package:petnest_saas/features/room/widgets/operations_workbench.dart';
import 'package:petnest_saas/features/room/widgets/operations_workbench_data.dart';

final date = DateTime(2026, 11, 6);
const captureKey = ValueKey('operations-capture');
List<OperationsRoom> rooms({bool few = false}) => [
  for (final name
      in few
          ? ['A1', 'A01', 'A02']
          : [
              'A1',
              'A2',
              'A3',
              'A4',
              'B1',
              'B2',
              'B3',
              'B4',
              'C1',
              'C2',
              'C3',
              'C4',
            ])
    OperationsRoom({
      'id': name,
      'name': name,
      'roomTypeName': name == 'A1'
          ? '日式豪房'
          : few
          ? '測試標準房'
          : name.startsWith('A')
          ? '日式豪房'
          : name.startsWith('B')
          ? '景觀套房'
          : '豪華套房',
      'enabled': true,
    }),
];
RoomDayBookingChoice booking(
  String id,
  String room,
  int start,
  int end,
  String pet,
  String status,
) => RoomDayBookingChoice(
  id: id,
  data: {
    'roomId': room,
    'roomName': room,
    'bookingCode': 'PN-202611-$id',
    'status': status,
    'startDate': Timestamp.fromDate(DateTime.utc(2026, 11, start)),
    'endDate': Timestamp.fromDate(DateTime.utc(2026, 11, end)),
    'petNames': [pet],
    'customerName': '測試飼主',
  },
);
OperationsWorkbenchData fixtureData(String state) {
  final busy = state == 'busy';
  final bookings = busy
      ? [
          booking('001', 'A1', 3, 7, '麻糬', 'checked_in'),
          booking('002', 'A3', 4, 8, '奶茶', 'checked_in'),
          booking('003', 'B1', 6, 9, '布丁', 'confirmed'),
          booking('004', 'B2', 3, 6, '小虎', 'checked_in'),
          booking('005', 'C1', 6, 10, '團團', 'confirmed'),
          booking('006', 'A1', 8, 12, '豆花', 'confirmed'),
        ]
      : <RoomDayBookingChoice>[];
  return OperationsWorkbenchData(
    rooms: state == 'none' ? [] : rooms(few: !busy),
    bookings: bookings,
    calendar: busy
        ? {
            'A2|2026-11-06': 'cleaning',
            'C2|2026-11-06': 'cleaning',
            for (var day = 4; day < 8; day++)
              'B3|2026-11-${day.toString().padLeft(2, '0')}': 'maintenance',
          }
        : {},
    occupancies: [],
    report: DailyCareReportCenterSnapshot(
      settingEnabled: true,
      items: busy
          ? [
              for (final item in [('001', 'A1', '麻糬'), ('002', 'A3', '奶茶')])
                DailyCareReportCenterItem(
                  id: item.$1,
                  shopId: 'fixture',
                  bookingId: item.$1,
                  sessionIndex: 0,
                  sessionName: '晚間照護回報',
                  recordDate: date,
                  roomId: item.$2,
                  roomName: item.$2,
                  petNames: [item.$3],
                  entitlement: const DailyCareEntitlement(
                    enabled: true,
                    finalReports: 1,
                  ),
                ),
            ]
          : [],
    ),
    date: date,
    today: date,
  );
}

Widget fixture(
  WorkbenchView view,
  String state, {
  ValueChanged<String>? onAction,
  double scale = 1,
  RoomStatusPalette palette = RoomStatusPalette.defaults,
}) {
  var selected = state == 'none' ? '' : 'A1';
  var selectedDate = date;
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'jfOpenHuninn',
      colorScheme: ColorScheme.fromSeed(seedColor: opsBlue),
      scaffoldBackgroundColor: opsBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: StatefulBuilder(
      builder: (context, update) {
        final original = fixtureData(state);
        final data = OperationsWorkbenchData(
          rooms: original.rooms,
          bookings: original.bookings,
          calendar: original.calendar,
          occupancies: original.occupancies,
          report: original.report,
          date: selectedDate,
          palette: palette,
          today: date,
        );
        return RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'PetNest 營運工作台',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: opsInk,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width >= 900) ...[
                    const SizedBox(width: 18),
                    OperationsBadge(view.label),
                  ],
                ],
              ),
              actions: [
                if (MediaQuery.sizeOf(context).width >= 800)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        '房務總覽　│　每日回報',
                        style: TextStyle(color: opsMuted, fontSize: 12),
                      ),
                    ),
                  ),
                WorkbenchSettingsMenu(
                  selected: view,
                  onChanged: (_) {},
                  onHousekeeping: () {},
                ),
                const SizedBox(width: 10),
              ],
            ),
            body: OperationsWorkbench(
              view: view,
              data: data,
              selectedRoomId: selected,
              onSelectRoom: (id) => update(() => selected = id),
              onDateSelected: (value) => update(() => selectedDate = value),
              onOrder: (order) => onAction?.call('order:${order.id}'),
              onRoomRecord: (room) => onAction?.call('room:${room.id}'),
              onRoomStatus: (room, status) =>
                  onAction?.call('status:${room.id}:$status'),
              onCare: (item) => onAction?.call('care:${item.bookingId}'),
              onReports: () => onAction?.call('reports'),
              onCamera: () => onAction?.call('camera'),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('jfOpenHuninn')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
    'timeline merges only one effective booking and never overlays closed or maintenance',
    () {
      final data = fixtureData('busy');
      final a1 = data.rooms.first;
      expect(data.day(a1, DateTime(2026, 11, 3)).spanId, '001');
      expect(data.day(a1, DateTime(2026, 11, 7)).spanId, isEmpty);
      expect(
        data.day(data.rooms.firstWhere((room) => room.id == 'B3'), date).spanId,
        isEmpty,
      );
      expect(opsOrderRange(data.bookings.first.data), '11/03－11/07（4 晚）');
    },
  );
  for (final view in [
    WorkbenchView.rooms,
    WorkbenchView.tasks,
    WorkbenchView.timeline,
  ]) {
    testWidgets(
      '${view.name}: empty, no rooms and busy full presentation across responsive widths',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final state in ['empty', 'none', 'busy']) {
          for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
            tester.view.physicalSize = Size(width, 1000);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(fixture(view, state));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${view.name}/$state/$width',
            );
          }
        }
      },
    );
  }
  testWidgets(
    'task row selects details; only the action opens the correct order',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var action = '';
      await tester.pumpWidget(
        fixture(
          WorkbenchView.tasks,
          'busy',
          onAction: (value) => action = value,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('預計抵達').first);
      await tester.pumpAndSettle();
      expect(action, isEmpty);
      expect(find.text('選取任務詳情'), findsOneWidget);
      await tester.tap(find.text('查看訂單').last);
      await tester.pumpAndSettle();
      expect(action, 'order:003');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty room has real status actions; occupied room hides them', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var action = '';
    await tester.pumpWidget(
      fixture(
        WorkbenchView.rooms,
        'empty',
        onAction: (value) => action = value,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('關閉此日'));
    await tester.tap(find.text('關閉此日'));
    expect(action, 'status:A1:closed');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(fixture(WorkbenchView.rooms, 'busy'));
    await tester.pumpAndSettle();
    expect(find.text('關閉此日'), findsNothing);
    expect(find.text('設為維修中'), findsNothing);
  });

  testWidgets(
    'merged stay bar selects the tapped day instead of its first day',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final data = fixtureData('busy');
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationsTimeline(
              data: data,
              rooms: data.rooms,
              days: List.generate(7, (i) => DateTime(2026, 11, 2 + i)),
              selectedRoomId: 'A1',
              onSelect: (room, day) => selected = day,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byTooltip('麻糬・11/03－11/07（4 晚）');
      final rect = tester.getRect(bar);
      await tester.tapAt(Offset(rect.left + rect.width * .88, rect.center.dy));
      expect(selected, date);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text and short windows retain reachable controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final view in [
      WorkbenchView.rooms,
      WorkbenchView.tasks,
      WorkbenchView.timeline,
    ]) {
      for (final size in [const Size(390, 700), const Size(1440, 700)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(fixture(view, 'empty', scale: 1.5));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${view.name}/$size/1.5',
        );
      }
    }
  });
  testWidgets(
    'custom palette reaches all new layouts and every month/timeline legend',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final palette = RoomStatusPalette.defaults.withColor(
        'available',
        const Color(0xFFFF00BB),
      );
      for (final view in [
        WorkbenchView.rooms,
        WorkbenchView.tasks,
        WorkbenchView.timeline,
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(fixture(view, 'empty', palette: palette));
        await tester.pumpAndSettle();
        if (view != WorkbenchView.tasks) {
          expect(
            tester
                .widget<RoomStatusLegend>(find.byType(RoomStatusLegend))
                .palette,
            palette,
          );
          final dot = tester.widget<Container>(
            find.byKey(const ValueKey('room-status-legend-available')),
          );
          expect(
            (dot.decoration! as BoxDecoration).color,
            palette.color('available'),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('capture actual production widgets with empty and sample data', (
    tester,
  ) async {
    final directory = Platform.environment['PETNEST_WORKBENCH_CAPTURES'];
    if (directory == null) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final state in ['empty', 'busy', 'none']) {
      for (final view in [
        WorkbenchView.rooms,
        WorkbenchView.tasks,
        WorkbenchView.timeline,
      ]) {
        tester.view.physicalSize = const Size(1600, 1000);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(fixture(view, state));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (state == 'busy' && view == WorkbenchView.tasks) {
          await tester.tap(find.text('預計抵達').first);
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final file = File('$directory/${view.name}-$state.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
