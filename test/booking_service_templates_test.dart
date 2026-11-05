import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_service_template_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';

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
  test(
    'second-step template persists independently and keeps original as fallback',
    () {
      expect(BookingPageAppearance.serviceStyles.keys, [
        'original',
        'cream',
        'editorial',
        'journal',
        'premium',
      ]);
      for (final style in BookingPageAppearance.serviceStyles.keys) {
        final saved = BookingPageAppearance(
          serviceStyle: style,
          style: 'house',
          calendarStyle: 'week',
        ).toMap();
        final value = BookingPageAppearance.fromShop({
          'homeAppearance': {'bookingPage': saved},
        });
        expect(value.serviceStyle, style);
        expect(value.style, 'house');
        expect(value.calendarStyle, 'week');
      }
      expect(BookingPageAppearance.fromShop({}).serviceStyle, 'original');
      expect(
        BookingPageAppearance.fromShop({
          'homeAppearance': {
            'bookingPage': {'serviceStyle': 'clean'},
          },
        }).serviceStyle,
        'original',
      );
    },
  );
  for (final style in ['cream', 'editorial', 'journal', 'premium']) {
    testWidgets(
      '$style keeps unavailable rooms locked and real add-on pricing interactive',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BookingServicePreview(
                  appearance: BookingPageAppearance(
                    style: style == 'cream' ? 'cream' : 'warm',
                    serviceStyle: style,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('booking-room-small')), findsNothing);
        final full = find.byKey(const ValueKey('booking-room-forest'));
        await tester.ensureVisible(full);
        await tester.pumpAndSettle();
        await tester.tap(full);
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 1800'), findsOneWidget);
        final snack = find.text('迎賓點心組');
        await tester.ensureVisible(snack);
        await tester.pumpAndSettle();
        await tester.tap(snack);
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 1900'), findsOneWidget);
        final custom = find.text('專屬照護');
        await tester.ensureVisible(custom);
        await tester.pumpAndSettle();
        await tester.tap(custom);
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 2300'), findsOneWidget);
        final pet = const ['editorial', 'cream'].contains(style)
            ? find.widgetWithText(FilterChip, '奶茶').last
            : find.byType(CheckboxListTile).first;
        await tester.ensureVisible(pet);
        await tester.pumpAndSettle();
        await tester.tap(pet);
        await tester.pumpAndSettle();
        final slot = find.widgetWithText(FilterChip, '10:00').first;
        await tester.ensureVisible(slot);
        await tester.pumpAndSettle();
        await tester.tap(slot);
        await tester.pumpAndSettle();
        expect(find.text('預估總額 NT\$ 2350'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('all service templates fit 320px and large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final style in BookingPageAppearance.serviceStyles.keys) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(style),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: BookingServicePreview(
                  appearance: BookingPageAppearance(
                    style: style == 'cream' ? 'cream' : 'warm',
                    serviceStyle: style,
                  ),
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
  testWidgets('backend applies whole suite and can return to original', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
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
    final suite = find.byKey(const ValueKey('booking-editorial-suite'));
    await tester.ensureVisible(suite);
    await tester.tap(suite);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingServicePreview>(
            find.byType(BookingServicePreview, skipOffstage: false),
          )
          .appearance
          .serviceStyle,
      'editorial',
    );
    final original = find.byKey(const ValueKey('booking-style-original'));
    await tester.ensureVisible(original);
    await tester.tap(original);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BookingServicePreview>(
            find.byType(BookingServicePreview, skipOffstage: false),
          )
          .appearance
          .serviceStyle,
      'original',
    );
    expect(find.widgetWithText(ChoiceChip, '房型與服務'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('render three implemented service templates', (tester) async {
    final output = Platform.environment['BOOKING_SERVICE_TEMPLATES_OUTPUT'];
    if (output == null) return;
    await tester.binding.setSurfaceSize(const Size(1500, 3300));
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
              children: [
                for (final style in ['editorial', 'journal', 'premium'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: BookingServicePreview(
                        appearance: BookingPageAppearance(
                          style: style == 'cream' ? 'cream' : 'warm',
                          serviceStyle: style,
                        ),
                      ),
                    ),
                  ),
              ],
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
