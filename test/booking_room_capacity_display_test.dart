import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_room_type_options.dart';

const types = <Map<String, dynamic>>[
  {
    'roomTypeId': 'one',
    'name': '單貓小屋',
    'capacity': 1,
    'availableRooms': 2,
    'price': 800,
  },
  {
    'roomTypeId': 'full',
    'name': '森林套房',
    'capacity': 2,
    'availableRooms': 0,
    'price': 1200,
  },
  {
    'roomTypeId': 'two',
    'name': '標準雙貓房',
    'capacity': 2,
    'availableRooms': 2,
    'price': 500,
    'extraPrice': 100,
  },
];
Future<void> show(
  WidgetTester tester, {
  int pets = 3,
  List<Map<String, dynamic>> rooms = types,
  ValueChanged<Map<String, dynamic>>? selected,
  VoidCallback? adjust,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: BookingRoomTypeOptions(
              roomTypes: rooms,
              petCount: pets,
              theme: HomeThemeModel.classicDefault,
              onSelect: selected ?? (_) {},
              onAdjustSelection: adjust,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'BookingPreview': 'BOOKING_PREVIEW_FONT',
      'MaterialIcons': 'BOOKING_PREVIEW_ICONS',
    }.entries) {
      final path = Platform.environment[entry.value];
      if (path == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(ByteData.sublistView(await File(path).readAsBytes())),
        );
      await loader.load();
    }
  });
  testWidgets(
    'three cats still see all room types but cannot choose undersized rooms',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0, adjusted = 0;
      await show(tester, selected: (_) => selected++, adjust: () => adjusted++);
      expect(find.text('目前選擇 3 隻，超過所有房型容量'), findsOneWidget);
      for (final room in types) {
        expect(find.text(room['name'].toString()), findsOneWidget);
        final card = find.byKey(ValueKey('booking-room-${room['roomTypeId']}'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
      }
      expect(selected, 0);
      expect(find.text('超過容量，無法入住'), findsNWidgets(3));
      final adjust = find.text('返回調整日期／貓咪');
      await tester.ensureVisible(adjust);
      await tester.pumpAndSettle();
      await tester.tap(adjust);
      expect(adjusted, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'capacity and full dates have different reasons; fitting available room can be chosen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Map<String, dynamic>? chosen;
      await show(tester, pets: 2, selected: (room) => chosen = room);
      expect(find.byKey(const ValueKey('booking-room-one')), findsNothing);
      expect(find.text('超過容量，無法入住'), findsNothing);
      expect(find.text('所選日期已滿房'), findsOneWidget);
      final blocked = find.byKey(const ValueKey('booking-room-full'));
      await tester.ensureVisible(blocked);
      await tester.pumpAndSettle();
      await tester.tap(blocked);
      expect(chosen, isNull);
      final available = find.byKey(const ValueKey('booking-room-two'));
      await tester.ensureVisible(available);
      await tester.pumpAndSettle();
      await tester.tap(available);
      expect(chosen?['roomTypeId'], 'two');
      expect(find.text('NT\$ 600'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all fitting rooms full explains date issue instead of capacity issue',
    (tester) async {
      await show(tester, pets: 2, rooms: [types[1]]);
      expect(find.text('符合 2 隻入住的房型，在所選日期已滿'), findsOneWidget);
      expect(find.text('所選日期已滿房'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'capacity reminders remain readable at narrow width and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await show(tester, scale: 2, adjust: () {});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('render capacity warning and all disabled rooms', (tester) async {
    final output = Platform.environment['BOOKING_ROOM_CAPACITY_OUTPUT'];
    if (output == null) return;
    await tester.binding.setSurfaceSize(const Size(500, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'BookingPreview'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFFFF9F0),
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: BookingRoomTypeOptions(
                roomTypes: types,
                petCount: 3,
                theme: HomeThemeModel.classicDefault,
                onSelect: (_) {},
                onAdjustSelection: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
