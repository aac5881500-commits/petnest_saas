import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_quick_template_card.dart';

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
  testWidgets('original order and reminder hiding match initial page', (
    tester,
  ) async {
    Widget screen(bool hasDates) => MaterialApp(
      home: Scaffold(
        body: BookingArrivalLayout(
          style: 'original',
          shopName: 'test',
          dateSection: const Text('original-date'),
          petsSection: const Text('original-pets'),
          reminder: const Text('original-reminder'),
          campaign: const SizedBox(),
          calendar: const Text('unused-calendar'),
          hasDates: hasDates,
          petCount: 0,
          dateLabel: '尚未選擇',
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    expect(
      tester.getTopLeft(find.text('original-date')).dy,
      lessThan(tester.getTopLeft(find.text('original-reminder')).dy),
    );
    expect(
      tester.getTopLeft(find.text('original-reminder')).dy,
      lessThan(tester.getTopLeft(find.text('original-pets')).dy),
    );
    expect(find.text('unused-calendar'), findsNothing);
    await tester.pumpWidget(screen(true));
    expect(find.text('original-reminder'), findsNothing);
    expect(find.text('original-pets'), findsOneWidget);
  });
  testWidgets(
    'uniform cards preserve reminder and width when switching to original',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({
                'homeAppearance': {
                  'bookingPage': const BookingPageAppearance(
                    style: 'house',
                    narrow: true,
                    note: '客製提醒',
                  ).toMap(),
                },
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getSize(
            find.byKey(const ValueKey('booking-style-original')),
          ),
          second = tester.getSize(
            find.byKey(const ValueKey('booking-quick-cream')),
          );
      expect(first, second);
      await tester.tap(find.byKey(const ValueKey('booking-style-original')));
      await tester.pumpAndSettle();
      expect(find.text('即時預覽・最初版本'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '客製提醒',
      );
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '窄版內容'))
            .value,
        true,
      );
      expect(find.byType(BookingQuickTemplateCard), findsNWidgets(9));
      final otherTop = tester
          .getTopLeft(find.byKey(const ValueKey('booking-quick-house')))
          .dy;
      for (final key in [
        'booking-style-original',
        'booking-editorial-suite',
        'booking-quick-cream',
      ]) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey(key))).dy,
          lessThan(otherTop),
        );
      }
      expect(find.text('完整三頁套裝'), findsOneWidget);
      expect(find.text('其他版型・待逐步調整'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('editor organization screenshot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1550));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'BookingPreview',
          colorSchemeSeed: const Color(0xFF52649A),
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            body: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({
                'name': 'PetNest 測試旅宿',
                'homeAppearance': {
                  'bookingPage': const BookingPageAppearance(
                    style: 'original',
                  ).toMap(),
                },
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['BOOKING_EDITOR_PREVIEW_OUTPUT'];
    if (output != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
