import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/housekeeping_setting_model.dart';
import 'package:petnest_saas/core/models/room_status_palette.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/services/housekeeping_setting_service.dart';
import 'package:petnest_saas/features/room/widgets/room_status_palette_state.dart';
import 'package:petnest_saas/features/room/widgets/room_status_palette_editor.dart';
import 'package:petnest_saas/features/room/widgets/room_status_legend.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';

class PaletteHost extends StatefulWidget {
  const PaletteHost({super.key, required this.shop, required this.streams});
  final String shop;
  final Map<String, StreamController<RoomStatusPalette>> streams;
  @override
  State<PaletteHost> createState() => _PaletteHostState();
}

class _PaletteHostState extends State<PaletteHost>
    with RoomStatusPaletteState<PaletteHost> {
  @override
  String get roomPaletteShopId => widget.shop;
  @override
  Stream<RoomStatusPalette> roomPaletteStream(String shop) =>
      widget.streams[shop]!.stream;
  @override
  Widget build(BuildContext context) {
    final facts = resolveRoomDayStatus(
      date: DateTime(2026, 11, 8),
      today: DateTime(2026, 11, 7),
      palette: roomPalette,
    );
    return Column(
      children: [
        Container(
          key: const ValueKey('calendar-dot'),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: facts.color, shape: BoxShape.circle),
        ),
        RoomWeekDots(colors: List.filled(7, facts.color)),
        RoomStatusLegend(palette: roomPalette),
      ],
    );
  }
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
  test('defaults preserve every original status color and legacy settings', () {
    final defaults = RoomStatusPalette.defaults;
    for (final item in RoomStatusPresentation.legendItems()) {
      expect(defaults.color(item.value), item.color, reason: item.label);
    }
    expect(defaults.color('history'), roomDayHistoryColor);
    expect(
      HousekeepingSettingModel.fromMap({
        'autoCleaningAfterCheckout': false,
      }).roomStatusColors,
      defaults,
    );
    expect(HousekeepingSettingModel.fromMap(null).roomStatusColors, defaults);
  });
  test(
    'palette parsing validates colors, aliases daycare, preserves labels and resets',
    () {
      final custom = RoomStatusPalette.fromMap({
        'available': '#00AACC',
        'history': 'FFCC00',
        'cleaning': 'invalid',
        'occupied': -5,
        'maintenance': '#ff11aa',
        'unknown': '#000000',
      });
      expect(custom.color('available'), const Color(0xFF00AACC));
      expect(custom.hex('history'), '#FFCC00');
      expect(custom.color('cleaning'), RoomStatusPresentation.cleaningColor);
      expect(custom.color('occupied'), RoomStatusPresentation.stayColor);
      expect(RoomStatusPalette.fromMap(custom.toMap()), custom);
      expect(
        custom.reset('available').color('available'),
        RoomStatusPresentation.availableColor,
      );
      final daycare = custom.withColor('daycare', const Color(0xFFFF6600));
      expect(daycare.color('daycare_checked_in'), daycare.color('daycare'));
      final changed = daycare.apply(RoomStatusPresentation.stayBooked());
      expect(changed.label, RoomStatusPresentation.stayBooked().label);
      expect(changed.value, 'occupied');
    },
  );
  test(
    'edited settings payload never resets unrelated care settings or omits default reset colors',
    () {
      final palette = RoomStatusPalette.defaults.withColor(
        'available',
        Colors.pink,
      );
      final fields = housekeepingSettingsPatch(
        autoCleaningAfterCheckout: false,
        roomStatusColors: palette,
      );
      expect(
        fields.keys,
        unorderedEquals(['autoCleaningAfterCheckout', 'roomStatusColors']),
      );
      expect(fields['roomStatusColors']['available'], palette.hex('available'));
      final previous = HousekeepingSettingModel.fromMap({
        'dailyCareEnabled': true,
        'dailyCareSessionCount': 4,
        'cameraEnabled': true,
        'roomStatusColors': palette.toMap(),
      });
      final copy = previous.copyWith(autoCleaningAfterCheckout: false);
      expect(copy.roomStatusColors, palette);
      expect(copy.dailyCareSessionCount, 4);
      expect(copy.cameraEnabled, isTrue);
      expect(
        housekeepingSettingsPatch(
          autoCleaningAfterCheckout: true,
        ).containsKey('roomStatusColors'),
        isFalse,
      );
      expect(
        (housekeepingSettingsPatch(
                  autoCleaningAfterCheckout: true,
                  roomStatusColors: RoomStatusPalette.defaults,
                )['roomStatusColors']
                as Map)
            .length,
        11,
      );
    },
  );
  test(
    'day and history dots recolor without changing state, eligibility or default palette',
    () {
      final palette = RoomStatusPalette.defaults
          .withColor('available', Colors.pink)
          .withColor('history', Colors.purple);
      final future = resolveRoomDayStatus(
        date: DateTime(2026, 11, 8),
        today: DateTime(2026, 11, 7),
        palette: palette,
      );
      final past = resolveRoomDayStatus(
        date: DateTime(2026, 11, 6),
        today: DateTime(2026, 11, 7),
        palette: palette,
      );
      expect(future.color.toARGB32(), Colors.pink.toARGB32());
      expect(future.presentation.value, 'available');
      expect(future.canEditStatus, isTrue);
      expect(past.color.toARGB32(), Colors.purple.toARGB32());
      expect(past.label, roomDayHistoryLabel);
      expect(past.canEditStatus, isFalse);
      expect(
        RoomStatusPalette.defaults.color('available'),
        RoomStatusPresentation.availableColor,
      );
    },
  );
  testWidgets(
    'saved stream changes update desktop/mobile dots and legends; shops stay independent',
    (tester) async {
      final a = StreamController<RoomStatusPalette>.broadcast(),
          b = StreamController<RoomStatusPalette>.broadcast();
      final streams = {'a': a, 'b': b};
      addTearDown(a.close);
      addTearDown(b.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: PaletteHost(
                    key: const ValueKey('desktop'),
                    shop: 'a',
                    streams: streams,
                  ),
                ),
                Expanded(
                  child: PaletteHost(
                    key: const ValueKey('mobile'),
                    shop: 'a',
                    streams: streams,
                  ),
                ),
                Expanded(
                  child: PaletteHost(
                    key: const ValueKey('other-shop'),
                    shop: 'b',
                    streams: streams,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      Color dot(String host, String key) {
        final target = find.descendant(
          of: find.byKey(ValueKey(host)),
          matching: find.byKey(ValueKey(key)),
        );
        return (tester.widget<Container>(target).decoration! as BoxDecoration)
            .color!;
      }

      final custom = RoomStatusPalette.defaults.withColor(
        'available',
        const Color(0xFFFF00BB),
      );
      a.add(custom);
      await tester.pumpAndSettle();
      for (final host in ['desktop', 'mobile']) {
        expect(dot(host, 'calendar-dot'), custom.color('available'));
        expect(
          dot(host, 'room-status-legend-available'),
          custom.color('available'),
        );
        final week = tester.widget<RoomWeekDots>(
          find.descendant(
            of: find.byKey(ValueKey(host)),
            matching: find.byType(RoomWeekDots),
          ),
        );
        expect(week.colors, everyElement(custom.color('available')));
      }
      expect(
        dot('other-shop', 'calendar-dot'),
        RoomStatusPresentation.availableColor,
      );
      a.addError(StateError('temporary offline'));
      await tester.pumpAndSettle();
      expect(dot('desktop', 'calendar-dot'), custom.color('available'));
      a.add(RoomStatusPalette.defaults);
      await tester.pumpAndSettle();
      expect(
        dot('mobile', 'room-status-legend-available'),
        RoomStatusPresentation.availableColor,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editor supports narrow and desktop widths, individual reset and restore defaults',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        var palette = RoomStatusPalette.defaults.withColor(
          'available',
          Colors.pink,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'jfOpenHuninn'),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => ListView(
                  children: [
                    RoomStatusPaletteEditor(
                      value: palette,
                      onChanged: (value) => update(() => palette = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('恢復空房預設色'));
        await tester.pumpAndSettle();
        expect(palette, RoomStatusPalette.defaults);
        await tester.tap(find.text('全部恢復預設'));
        await tester.pumpAndSettle();
        expect(palette, RoomStatusPalette.defaults);
      }
    },
  );
  testWidgets(
    'color picker cancel preserves draft and HEX apply updates matching legend',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var palette = RoomStatusPalette.defaults;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'jfOpenHuninn'),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ListView(
                children: [
                  RoomStatusPaletteEditor(
                    value: palette,
                    onChanged: (value) => update(() => palette = value),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('#2E7D32'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(palette, RoomStatusPalette.defaults);
      await tester.tap(find.text('#2E7D32'));
      await tester.pumpAndSettle();
      final hue = find.byType(Slider);
      final track = tester.getRect(hue);
      expect(track.width, greaterThan(150));
      await tester.tapAt(
        Offset(track.left + track.width * 0.7, track.center.dy),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(hue).value, greaterThan(220));
      await tester.tap(find.byTooltip('紫'));
      await tester.pumpAndSettle();
      final hex = find.byType(TextField);
      expect(tester.widget<TextField>(hex).controller!.text, '#8E24AA');
      await tester.enterText(hex, '#invalid');
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      expect(find.text('請輸入 #RRGGBB'), findsOneWidget);
      await tester.enterText(hex, '#FF00BB');
      await tester.pumpAndSettle();
      await tester.tap(find.text('套用'));
      await tester.pumpAndSettle();
      expect(palette.hex('available'), '#FF00BB');
      final color = tester.widget<Container>(
        find.byKey(const ValueKey('room-status-legend-available')),
      );
      expect(
        (color.decoration! as BoxDecoration).color,
        palette.color('available'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture real color settings editor', (tester) async {
    final directory = Platform.environment['PETNEST_COLOR_CAPTURES'];
    if (directory == null) return;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1400);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'jfOpenHuninn', useMaterial3: true),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: Scaffold(
              appBar: AppBar(title: const Text('房務設定')),
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  RoomStatusPaletteEditor(
                    value: RoomStatusPalette.defaults,
                    onChanged: (_) {},
                  ),
                  FilledButton(onPressed: () {}, child: const Text('儲存設定')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('$directory/settings-${width.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
