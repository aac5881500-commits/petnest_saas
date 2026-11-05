import 'package:petnest_saas/features/shop/widgets/booking/booking_confirmation_preview.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_service_template_editor.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';

void main() {
  const suite = BookingPageAppearance(
    style: 'editorial',
    serviceStyle: 'editorial',
  );
  testWidgets('one quick suite applies three steps and roundtrips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
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
    final button = find.byKey(const ValueKey('booking-editorial-suite'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final data = tester
        .widget<BookingArrivalPreview>(find.byType(BookingArrivalPreview))
        .appearance
        .toMap();
    expect(data['style'], 'editorial');
    expect(data['serviceStyle'], 'editorial');
    final parsed = BookingPageAppearance.fromShop({
      'homeAppearance': {'bookingPage': data},
    });
    expect(parsed.style, 'editorial');
    expect(parsed.serviceStyle, 'editorial');
    expect(tester.takeException(), isNull);
  });
  testWidgets('three editorial steps fit narrow mobile and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final child in [
      const BookingArrivalPreview(appearance: suite),
      const BookingServicePreview(appearance: suite),
      const BookingConfirmationPreview(appearance: suite),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,reason:child.runtimeType.toString());
    }
  });
  testWidgets('render implemented editorial mobile pages', (tester) async {
    final output = Platform.environment['EDITORIAL_OUTPUT'];
    if (output == null) return;
    await tester.runAsync(() async {
      for (final item in {
        'NotoSerifTC': 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
        'NotoSansTC': 'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
        'MaterialIcons':
            'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final f = File(item.value);
        if (await f.exists()) {
          final loader = FontLoader(
            item.key,
          )..addFont(Future.value(ByteData.sublistView(await f.readAsBytes())));
          await loader.load();
        }
      }
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final step in [1, 2, 3]) {
      final key = GlobalKey();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'NotoSansTC'),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: SingleChildScrollView(
                controller: scroll,
                child: step == 1
                    ? const BookingArrivalPreview(
                        appearance: suite,
                        shopName: '喵屋貓咪旅館',
                      )
                    : step == 2
                    ? const BookingServicePreview(
                        appearance: suite,
                        shopName: '喵屋貓咪旅館',
                      )
                    : const BookingConfirmationPreview(
                        appearance: suite,
                        shopName: '喵屋貓咪旅館',
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final lower in [false, true]) {
        if (lower) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/step$step-${lower ? 'lower' : 'top'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
