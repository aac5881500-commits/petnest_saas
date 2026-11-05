import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';

const payload = FrontCalendarPayload(
  blockedDateKeys: {},
  blockedDateReasons: {},
  unbookableDateKeys: {},
  priceMap: {},
  remainingRoomsMap: {},
);
Future<void> open(
  WidgetTester tester,
  String style,
  String presentation,
  double width, {
  double scale = 1,
  ValueChanged<DateTime>? onDay,
  GlobalKey? captureKey,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 740));
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(fontFamily: 'BookingPreview'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBookingCalendarSurface<void>(
              context: context,
              presentation: presentation,
              builder: (context) => BookingCalendarDialog(
                payload: payload,
                calendarMonth: DateTime(2026, 11),
                today: DateTime(2026, 11),
                maxDays: 60,
                tempStartDate: null,
                tempEndDate: null,
                rangeMessage: '',
                visualStyle: style,
                presentation: presentation,
                density: 'comfortable',
                onMonthChanged: (_) {},
                onDayTap: onDay ?? (_) {},
                onCancel: () => Navigator.pop(context),
                onConfirm: () => Navigator.pop(context),
              ),
            ),
            child: const Text('開啟月曆'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開啟月曆'));
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
  testWidgets('render repaired mobile weekly calendar', (tester) async {
    final output = Platform.environment['BOOKING_WEEK_FIXED_OUTPUT'];
    if (output == null) return;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await open(tester, 'week', 'dialog', 500, captureKey: key);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('week shows all seven days fully and Saturday can be selected', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 500.0]) {
      DateTime? selected;
      await open(tester, 'week', 'dialog', width, onDay: (v) => selected = v);
      for (var day = 1; day <= 7; day++) {
        final tile = find.byKey(ValueKey('calendar-day-2026-11-0$day'));
        expect(tile, findsOneWidget);
        final rect = tester.getRect(tile);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      final saturday = find.byKey(const ValueKey('calendar-day-2026-11-07'));
      await tester.ensureVisible(saturday);
      await tester.pumpAndSettle();
      await tester.tap(saturday);
      expect(selected, DateTime(2026, 11, 7));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'all active calendars expose dates and confirm at narrow width and large text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final style in [
        'classic',
        'stay',
        'week',
        'journal',
        'board',
        'ribbon',
        'weekbands',
        'monthlist',
        'monthwall',
      ]) {
        for (final presentation in ['dialog', 'summary', 'sheet']) {
          await open(tester, style, presentation, 320, scale: 2);
          expect(
            find.text('確認').hitTestable(),
            findsOneWidget,
            reason: '$style/$presentation fixed confirm',
          );
          if (style == 'ribbon') {
            final arrow = find.byTooltip('往後瀏覽日期');
            for (var i = 0; i < 16; i++) {
              await tester.ensureVisible(arrow);
              await tester.pumpAndSettle();
              await tester.tap(arrow);
              await tester.pumpAndSettle();
            }
          }
          final day = ['week', 'journal', 'board'].contains(style)
              ? '07'
              : '30';
          final tile = find.byKey(ValueKey('calendar-day-2026-11-$day'));
          expect(tile, findsOneWidget, reason: '$style/$presentation');
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          expect(
            tile.hitTestable(),
            findsOneWidget,
            reason: '$style/$presentation date',
          );
          final rect = tester.getRect(tile);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          await tester.ensureVisible(find.text('確認'));
          await tester.pumpAndSettle();
          expect(
            find.text('確認').hitTestable(),
            findsOneWidget,
            reason: '$style/$presentation confirm',
          );
          await tester.tap(find.text('確認'));
          await tester.pumpAndSettle();
          expect(find.text('開啟月曆'), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '$style/$presentation',
          );
        }
      }
    },
  );
}
