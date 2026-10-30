import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/shop/pages/shop_share_card_page.dart';

Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
  final sans = FontLoader('NotoSansTC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([sans.load(), icons.load()]);
});

void main() {
  testWidgets(
    'full share card combines QR, APP code and web instructions at print resolution',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await loadFonts(tester);
      const link =
          'https://petnest-saas.web.app/s/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      await tester.pumpWidget(
        MaterialApp(
          theme: PetNestAppTheme.build().copyWith(
            textTheme: PetNestAppTheme.build().textTheme.apply(
              fontFamily: 'NotoSansTC',
            ),
          ),
          home: ShopShareCardPage(
            shopId: 'SHOP0018',
            link: link,
            searchCode: 'CATSTAY_2026',
            loadShopName: () async => '貓咪小屋旅店',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('貓咪小屋旅店'), findsOneWidget);
      expect(find.text('CATSTAY_2026'), findsOneWidget);
      expect(find.text('網頁版｜不必下載 APP'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(ShopGuestShareCard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      expect(boundary.size.width, 480);
      await tester.runAsync(() async {
        final image = await boundary.toImage(
          pixelRatio: 1080 / boundary.size.width,
        );
        expect(image.width, 1080);
        // 155 mm wide print fits in A4's 267 mm printable height.
        expect(image.height / image.width, lessThan(267 / 155));
        final output = Platform.environment['SHARING_PREVIEW_DIR'];
        if (output != null) {
          Directory(output).createSync(recursive: true);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$output/guest-share-card.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        }
        image.dispose();
      });
    },
  );
  testWidgets(
    'unconfigured and long codes remain readable without fake codes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await loadFonts(tester);
      for (final code in ['', 'CAT_HOME_2026_PRIVATE_GUEST_123456']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShopGuestShareCard(
                  shopName: '一家名字比較長的貓咪旅店',
                  link: 'https://petnest-saas.web.app/s/token',
                  searchCode: code,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (code.isEmpty) {
          expect(find.text('尚未設定，請使用上方 QR Code 進店'), findsOneWidget);
        } else {
          expect(find.text(code), findsOneWidget);
        }
      }
    },
  );
}
