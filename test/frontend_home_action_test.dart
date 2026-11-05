import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_actions.dart';
import 'package:petnest_saas/features/shop/navigation/frontend_navigation_models.dart';
import 'package:petnest_saas/features/shop/navigation/shop_main_tab_route.dart';

void main() {
  for (final fromTab in [false, true]) {
    testWidgets('home closes drawer and returns correctly fromTab=$fromTab', (
      tester,
    ) async {
      var scrolled = 0;
      Widget page(String title) => Scaffold(
        appBar: AppBar(title: Text(title)),
        drawer: Drawer(
          child: Builder(
            builder: (drawerContext) => TextButton(
              onPressed: () => FrontendNavigationLaunch(
                shopId: 'test',
                shop: const {},
                theme: HomeThemeModel.classicDefault,
                onScrollHomeToTop: () => scrolled++,
              ).open(drawerContext, FrontendNavigationRegistry.find('home')!),
              child: const Text('選單首頁'),
            ),
          ),
        ),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: RouteSettings(
                  name: ShopMainTabRoute.nameFor('booking'),
                ),
                builder: (_) => page('預約子頁'),
              ),
            ),
            child: const Text('前往預約'),
          ),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: page('店家首頁')));
      if (fromTab) {
        await tester.tap(find.text('前往預約'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選單首頁'));
      await tester.pumpAndSettle();
      expect(find.text('店家首頁'), findsOneWidget);
      expect(find.text('預約子頁'), findsNothing);
      expect(scrolled, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
