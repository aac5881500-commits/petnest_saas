import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_appearance_editor.dart';

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
  testWidgets(
    'mobile preview is immediately accessible and keeps draft and both scroll positions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
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
      expect(tester.getTopLeft(find.text('即時預覽')).dy, lessThan(90));
      await tester.tap(find.byKey(const ValueKey('booking-quick-house')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('即時預覽'));
      await tester.pumpAndSettle();
      expect(find.text('即時預覽・圓潤小屋'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('template-pet-奶茶')));
      await tester.tap(find.byKey(const ValueKey('template-pet-奶茶')));
      await tester.pumpAndSettle();
      expect(find.text('選擇入住貓咪（已選 1 隻）'), findsOneWidget);
      await tester.tap(find.text('外觀設定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, '手機草稿標題');
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(
                    const PageStorageKey('booking-mobile-settings'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      await tester.tap(find.text('即時預覽'));
      await tester.pumpAndSettle();
      expect(find.text('選擇入住貓咪（已選 1 隻）'), findsOneWidget);
      await tester.tap(find.text('外觀設定'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '手機草稿標題',
      );
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byKey(
                      const PageStorageKey('booking-mobile-settings'),
                    ),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .pixels,
        position,
      );
      expect(tester.getBottomRight(find.text('儲存設定')).dy, lessThan(844));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('320px workspace supports 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('即時預覽'));
    await tester.pumpAndSettle();
    expect(find.text('即時預覽・月曆直選'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('render mobile settings and preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 930));
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
            appBar: AppBar(title: const Text('預約頁外觀')),
            body: BookingAppearanceEditor(
              shopId: 'test',
              shopStream: Stream.value({
                'name': 'PetNest 測試旅宿',
                'homeAppearance': {
                  'bookingPage': {'style': 'original'},
                },
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final prefix = Platform.environment['BOOKING_MOBILE_PREVIEW_OUTPUT'];
      if (prefix == null) return;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$prefix-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('settings');
    await tester.tap(find.text('即時預覽'));
    await tester.pumpAndSettle();
    await capture('preview');
    expect(tester.takeException(), isNull);
  });
}
