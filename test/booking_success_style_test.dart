import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/booking/widgets/booking_success_content.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';

void main() {
  for (final style in ['default', 'cream', 'editorial']) {
    testWidgets(
      '$style completion preserves actions and shows accurate receipt',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var view = 0, back = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingSuccessContent(
                shopName: '喵屋旅館',
                appearance: style == 'default'
                    ? null
                    : BookingPageAppearance(style: style, serviceStyle: style),
                startDate: DateTime(2026, 11, 5),
                endDate: DateTime(2026, 11, 7),
                petCount: 2,
                roomTypeName: '標準雙貓房',
                totalPrice: 1300,
                bookingId: 'test-order',
                onViewOrder: () => view++,
                onReturnToShop: () => back++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('預約成功'), findsOneWidget);
        expect(find.text('預約成功 🎉'), findsNothing);
        expect(find.text('2 隻'), findsOneWidget);
        expect(find.text('標準雙貓房'), findsOneWidget);
        expect(find.text('訂單金額'), findsOneWidget);
        expect(find.text('已付款'), findsNothing);
        expect(find.text('已確認入住'), findsNothing);
        final viewButton = find.byKey(const ValueKey('success-view-order'));
        await tester.ensureVisible(viewButton);
        await tester.tap(viewButton);
        final backButton = find.byKey(const ValueKey('success-return-shop'));
        await tester.ensureVisible(backButton);
        await tester.tap(backButton);
        expect(view, 1);
        expect(back, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$style completion scrolls at 320px and 200 percent text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(2),
            ),
            child: BookingSuccessPage(
              shopName: '喵屋貓咪旅館・很長的店家名稱測試',
              shopId: 'test',
              appearance: style == 'default'
                  ? null
                  : BookingPageAppearance(style: style, serviceStyle: style),
              message: '訂單已送出，等待店家確認',
              startDate: DateTime(2026, 11, 5),
              endDate: DateTime(2026, 11, 7),
              petCount: 2,
              roomTypeName: '標準雙貓房',
              totalPrice: 1300,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('success-return-shop')),
      );
      await tester.pumpAndSettle();
      expect(find.text('訂單已送出，等待店家確認'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('completion honors frontend color and font settings', (
    tester,
  ) async {
    const a = BookingPageAppearance(
      style: 'cream',
      suiteColorMode: 'frontend',
      looks: {'cream': BookingPageLook(font: 'NotoSansTC', fontWeight: 700)},
    );
    final front = HomeThemeModel.modernDefault.copyWith(
      primaryColorValue: 0xFF6554A5,
      textColorValue: 0xFF493853,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BookingSuccessPage(
          shopName: '喵屋旅館',
          shopId: 'test',
          appearance: a,
          frontendTheme: front,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('success-view-order')),
    );
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF6554A5));
    final title = tester.widget<Text>(find.text('預約成功'));
    expect(title.style!.fontFamily, 'NotoSansTC');
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(tester.takeException(), isNull);
  });
  testWidgets('render completed booking page variants', (tester) async {
    final output = Platform.environment['BOOKING_SUCCESS_OUTPUT'];
    if (output == null) return;
    await tester.runAsync(() async {
      for (final e in {
        'jfOpenHuninn': 'assets/fonts/jf-openhuninn-2.1.ttf',
        'NotoSerifTC': 'assets/fonts/NotoSerifTC-VariableFont_wght.ttf',
        'NotoSansTC': 'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
        'MaterialIcons':
            'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(e.key)
          ..addFont(
            Future.value(
              ByteData.sublistView(await File(e.value).readAsBytes()),
            ),
          );
        await loader.load();
      }
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final style in ['default', 'cream', 'editorial']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: BookingSuccessPage(
              shopName: '喵屋貓咪旅館',
              shopId: 'test',
              appearance: style == 'default'
                  ? null
                  : BookingPageAppearance(style: style, serviceStyle: style),
              startDate: DateTime(2026, 11, 5),
              endDate: DateTime(2026, 11, 7),
              petCount: 2,
              roomTypeName: '標準雙貓房',
              totalPrice: 1300,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final img =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/$style.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }
  });
}
