// 檔案名稱：test/shop_opening_welcome_screenshot_test.dart
// 功能說明：以正式本機字體與照片驗證三種尺寸的 Flutter 畫面。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'package:petnest_saas/features/auth/pages/shop_opening_welcome_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in <String, Size>{
    'phone_320': const Size(320, 800),
    'phone_390': const Size(390, 844),
    'desktop_1440': const Size(1440, 1024),
  }.entries) {
    testWidgets('正式照片與字體 ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final sans = FontLoader('NotoSansTC')
          ..addFont(
            rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
          );
        final hand = FontLoader('KleeOne')
          ..addFont(rootBundle.load('assets/fonts/KleeOne-SemiBold.ttf'));
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await Future.wait([sans.load(), hand.load(), icons.load()]);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: PetNestAppTheme.build(),
          home: const RepaintBoundary(
            key: ValueKey('welcome-capture'),
            child: ShopOpeningWelcomePage(activationCode: 'VISUAL-CHECK'),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ShopOpeningWelcomePage));
        await precacheImage(
          AssetImage(
            'assets/images/shop_onboarding/welcome_${entry.value.width >= 900 ? 'desktop' : 'mobile'}.webp',
          ),
          context,
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('welcome-capture')),
        matchesGoldenFile('goldens/shop_opening_${entry.key}.png'),
      );
    });
  }
}
