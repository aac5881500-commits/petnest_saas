import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_date_section.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_template_pet_grid.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_quick_template_surface.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('jfOpenHuninn')
      ..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'));
    await loader.load();
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
  testWidgets('quick templates only change draft and retain custom reminder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey<BookingAppearanceEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingAppearanceEditor(
            key: key,
            shopId: 'test',
            shopStream: Stream.value({}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '保留標題');
    await tester.enterText(find.byType(TextField).last, '保留補充提醒');
    for (final style in ['cream', 'house']) {
      final button = find.descendant(
        of: find.byKey(ValueKey('booking-quick-$style')),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text('即時預覽・${BookingPageAppearance.styles[style]}'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '保留標題',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '保留補充提醒',
      );
      expect(key.currentState!.hasChanges, true);
    }
    expect(tester.takeException(), isNull);
  });
  for (final style in ['cream', 'house']) {
    testWidgets('$style functional dates and pet tiles at 320px and 200%', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var dates = 0, pets = 0;
      final theme = BookingArrivalLayout.themeFor(style);
      Widget screen(bool enabled) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: BookingAppearanceScope(
                appearance: BookingPageAppearance(style: style),
                child: Column(
                  children: [
                    BookingDateSection(
                      shopName: 'test',
                      bookingEnabled: enabled,
                      theme: theme,
                      onOpenCalendar: () => dates++,
                    ),
                    BookingTemplatePetGrid(
                      style: style,
                      pets: const [
                        {'petId': 'one', 'name': '一隻名字很長的貓咪'},
                      ],
                      selectedIds: const [],
                      theme: theme,
                      onToggle: (id, selected) {
                        expect(id, 'one');
                        expect(selected, true);
                        pets++;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-date-control')),
      );
      await tester.tap(find.byKey(const ValueKey('template-date-control')));
      expect(dates, 1);
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-pet-one')),
      );
      await tester.tap(find.byKey(const ValueKey('template-pet-one')));
      expect(pets, 1);
      await tester.pumpWidget(screen(false));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-date-control')),
      );
      await tester.tap(find.byKey(const ValueKey('template-date-control')));
      expect(dates, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('render two implemented templates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'BookingPreview',
          colorSchemeSeed: const Color(0xFF4E9BD1),
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFFEFF2F4),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ['cream', 'house']
                    .map(
                      (style) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: BookingArrivalPreview(
                            appearance: BookingPageAppearance(style: style),
                          ),
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
    await tester.runAsync(() async {
      for (final asset in [
        BookingQuickTemplateSurface.heroAsset,
        'assets/images/booking_demo_ginger_chibi_v1.png',
        'assets/images/booking_demo_tabby_chibi_v1.png',
      ]) {
        await precacheImage(AssetImage(asset), key.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['BOOKING_QUICK_PREVIEW_OUTPUT'];
    if (output != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
