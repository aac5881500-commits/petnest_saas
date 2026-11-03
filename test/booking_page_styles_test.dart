import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';

const theme = HomeThemeModel(
  backgroundColorValue: 0xFFFFF8EF,
  cardColorValue: 0xFFFFFCF7,
  cardBorderColorValue: 0xFFFFCBA6,
  primaryColorValue: 0xFFFF881E,
  textColorValue: 0xFF603A27,
);
Widget sample(String style) =>
    BookingArrivalPreview(appearance: BookingPageAppearance(style: style));
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
  test('all presets persist and unknown styles fall back', () {
    for (final style in BookingPageAppearance.styles.keys) {
      final value = BookingPageAppearance.fromShop({
        'homeAppearance': {
          'bookingPage': BookingPageAppearance(
            style: style,
            note: '保留提醒',
          ).toMap(),
        },
      });
      expect(value.style, style);
      expect(value.note, '保留提醒');
    }
    expect(
      BookingPageAppearance.fromShop({
        'homeAppearance': {
          'bookingPage': {'style': 'future'},
        },
      }).style,
      'warm',
    );
  });
  for (final style in BookingPageAppearance.styles.keys) {
    testWidgets('$style at narrow width and 200% text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(child: sample(style)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('即時預覽・${BookingPageAppearance.styles[style]}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('preset selection preserves reminder draft', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
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
    await tester.enterText(find.byType(TextField).first, '保留這段提醒');
    for (final style in BookingPageAppearance.styles.keys) {
      final quick = style == 'cream' || style == 'house';
      final picker = quick
          ? find.descendant(
              of: find.byKey(ValueKey('booking-quick-$style')),
              matching: find.byType(FilledButton),
            )
          : find.byKey(ValueKey('booking-style-$style'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '保留這段提醒',
      );
      expect(
        find.text('即時預覽・${BookingPageAppearance.styles[style]}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('render five style comparison', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3150, 1900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'BookingPreview',
          colorSchemeSeed: theme.primaryColor,
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFF0ECE7),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: BookingPageAppearance.styles.keys
                    .map(
                      (style) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: sample(style),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['BOOKING_PREVIEW_OUTPUT'];
    if (output != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
