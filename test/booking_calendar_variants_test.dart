import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

void main() {
  setUpAll(() async {
    final font = Platform.environment['BOOKING_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('BookingPreview')
        ..addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())),
        );
      await loader.load();
    }
    final icons = Platform.environment['BOOKING_PREVIEW_ICONS'];
    if (icons != null) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(ByteData.sublistView(await File(icons).readAsBytes())),
        );
      await loader.load();
    }
  });
  test('retired planner falls back and ribbon belongs to weekly category', () {
    final restored = BookingPageAppearance.fromShop({
      'homeAppearance': {
        'bookingPage': {'calendarStyle': 'planner'},
      },
    });
    expect(restored.calendarStyle, 'classic');
    expect(
      BookingPageAppearance.monthCalendarStyles.contains('ribbon'),
      isFalse,
    );
    expect(BookingPageAppearance.weekCalendarStyles.contains('ribbon'), isTrue);
  });
  test('calendar custom colors persist and invalid mode falls back', () {
    const appearance = BookingPageAppearance(
      calendarStyle: 'ribbon',
      calendarColorMode: 'custom',
      calendarBackground: 0xFF243136,
      calendarAccent: 0xFF89CABC,
    );
    final restored = BookingPageAppearance.fromShop({
      'homeAppearance': {'bookingPage': appearance.toMap()},
    });
    expect(restored.calendarStyle, 'ribbon');
    expect(restored.calendarColorMode, 'custom');
    expect(restored.calendarBackground, 0xFF243136);
    expect(restored.calendarAccent, 0xFF89CABC);
    expect(
      BookingPageAppearance.fromShop({
        'homeAppearance': {
          'bookingPage': {'calendarColorMode': 'bad'},
        },
      }).calendarColorMode,
      'template',
    );
  });
  test('calendar preferences persist and invalid data keep old calendar', () {
    for (final style in BookingPageAppearance.calendarStyles.keys) {
      final a = BookingPageAppearance(
        calendarStyle: style,
        calendarPresentation: 'sheet',
        calendarDensity: 'comfortable',
      );
      final restored = BookingPageAppearance.fromShop({
        'homeAppearance': {'bookingPage': a.toMap()},
      });
      expect(restored.calendarStyle, style);
      expect(restored.calendarPresentation, 'sheet');
      expect(restored.calendarDensity, 'comfortable');
    }
    final legacy = BookingPageAppearance.fromShop({
      'homeAppearance': {
        'bookingPage': {'calendarStyle': 'bad', 'calendarPresentation': false},
      },
    });
    expect(legacy.calendarStyle, 'classic');
    expect(legacy.calendarPresentation, 'dialog');
  });
  for (final style in BookingPageAppearance.calendarStyles.keys) {
    testWidgets('$style retains blocked and full day rules', (tester) async {
      final selected = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCalendar(
                initialMonth: DateTime(2026, 11),
                firstDate: DateTime(2026, 11, 1),
                lastDate: DateTime(2026, 12),
                onDayTap: selected.add,
                visualStyle: style,
                blockedDateKeys: const {'2026-11-04'},
                unbookableDateKeys: const {'2026-11-05'},
                compactCells: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('4'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      await tester.ensureVisible(find.text('5'));
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      await tester.ensureVisible(find.text('6'));
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      expect(selected.single, DateTime(2026, 11, 6));
      expect(tester.takeException(), isNull);
    });
  }
  for (final presentation in BookingPageAppearance.calendarPresentations.keys) {
    testWidgets(
      '$presentation preview uses real selected calendar and cancels safely',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingArrivalPreview(
                  appearance: BookingPageAppearance(
                    style: 'original',
                    calendarStyle: 'round',
                    calendarPresentation: presentation,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('選擇日期'));
        await tester.tap(find.text('選擇日期'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BookingCalendarDialog>(find.byType(BookingCalendarDialog))
              .presentation,
          presentation,
        );
        expect(
          tester
              .widget<BookingCalendar>(find.byType(BookingCalendar))
              .visualStyle,
          'round',
        );
        final first = tester
            .widget<BookingCalendar>(find.byType(BookingCalendar))
            .firstDate;
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar))
            .onDayTap(first);
        await tester.pumpAndSettle();
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar))
            .onDayTap(first.add(const Duration(days: 2)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('確認'));
        await tester.tap(find.text('確認'));
        await tester.pumpAndSettle();
        expect(find.text('2 晚'), findsOneWidget);
        await tester.ensureVisible(find.text('重新選擇日期'));
        await tester.tap(find.text('重新選擇日期'));
        await tester.pumpAndSettle();
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar))
            .onDayTap(first.add(const Duration(days: 5)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('取消'));
        await tester.ensureVisible(find.text('取消'));
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('2 晚'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'calendar controls update preview independently of page template',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 2300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '月曆設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '週／分組'));
      await tester.pumpAndSettle();
      expect(find.text('週曆時間軸'), findsOneWidget);
      expect(find.text('整月卡片牆'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '整月'));
      await tester.pumpAndSettle();
      expect(find.text('整月卡片牆'), findsOneWidget);
      expect(find.text('週曆時間軸'), findsNothing);
      await tester.tap(find.text('旅宿日期卡'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar).last)
            .visualStyle,
        'stay',
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '自訂配色'));
      await tester.tap(find.widgetWithText(ChoiceChip, '自訂配色'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('海藍'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '海藍'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar).last)
            .backgroundColor,
        const Color(0xFFEEF5FC),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '跟隨預約頁背景'));
      await tester.tap(find.widgetWithText(ChoiceChip, '跟隨預約頁背景'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingCalendar>(find.byType(BookingCalendar).last)
            .backgroundColor,
        isNotNull,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '底部滑出'));
      await tester.tap(find.widgetWithText(ChoiceChip, '底部滑出'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('試開日期視窗'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '外觀設定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('booking-style-original')),
      );
      await tester.tap(find.byKey(const ValueKey('booking-style-original')));
      await tester.pumpAndSettle();
      final value = tester
          .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
          .appearance;
      expect(value.style, 'original');
      expect(value.calendarStyle, 'stay');
      expect(value.calendarPresentation, 'sheet');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('complete layouts fit narrow screens with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final style in [
      'stay',
      'week',
      'journal',
      'board',
      'ribbon',
      'weekbands',
      'monthlist',
      'monthwall',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: BookingCalendar(
                  key: ValueKey(style),
                  visualStyle: style,
                  initialMonth: DateTime(2026, 11),
                  firstDate: DateTime(2026, 11),
                  lastDate: DateTime(2026, 12),
                  onDayTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: style);
    }
  });
  testWidgets('render full month calendar layouts for comparison', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'BookingPreview'),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: BookingPageAppearance.calendarStyles.entries
                  .where(
                    (e) => const [
                      'weekbands',
                      'monthlist',
                      'monthwall',
                    ].contains(e.key),
                  )
                  .map(
                    (entry) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            BookingCalendar(
                              initialMonth: DateTime(2026, 11),
                              firstDate: DateTime(2026, 11, 1),
                              lastDate: DateTime(2026, 12),
                              onDayTap: (_) {},
                              rangeStart: DateTime(2026, 11, 12),
                              rangeEnd: DateTime(2026, 11, 15),
                              visualStyle: entry.key,
                              compactCells: true,
                              accentColor: const Color(0xFF5268AA),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['BOOKING_CALENDAR_PREVIEW_OUTPUT'];
    if (output != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
