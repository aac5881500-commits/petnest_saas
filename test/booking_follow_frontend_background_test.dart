import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/booking_page_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_layout.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_arrival_preview.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_look_editor.dart';
import 'package:petnest_saas/features/shop/widgets/shop_app_backdrop.dart';

const appearance = BookingPageAppearance(
  style: 'compact',
  looks: {
    'compact': BookingPageLook(
      followFrontend: true,
      text: 0xFF273B59,
      primary: 0xFF3878AC,
      font: 'jfOpenHuninn',
    ),
  },
);
HomeThemeModel source(String id) => HomeThemeModel.modernDefault.copyWith(
  backgroundColorValue: 0xFFF0F7F2,
  appBackgroundMode: 'image',
  appBackgroundAssetId: id,
  appBackgroundFit: 'contain',
  appBackgroundAlign: 'bottom',
  appBackgroundScrim: .48,
);
void main() {
  test(
    'follow flag persists without duplicating frontend image and keeps local text',
    () {
      final map = appearance.toMap();
      expect(map.toString().contains('assetId'), false);
      final value = BookingPageAppearance.fromShop({
        'homeAppearance': {'bookingPage': map},
      });
      expect(value.look.followFrontend, true);
      final theme = BookingArrivalLayout.themeFor(
        'compact',
        appearance: value,
        originalTheme: source('bg-1'),
      );
      expect(theme.backgroundColorValue, 0xFFF0F7F2);
      expect(theme.appBackgroundAssetId, 'bg-1');
      expect(theme.appBackgroundFit, 'contain');
      expect(theme.appBackgroundAlign, 'bottom');
      expect(theme.appBackgroundScrim, .48);
      expect(theme.textColorValue, 0xFF273B59);
      expect(theme.primaryColorValue, 0xFF3878AC);
      expect(
        BookingArrivalLayout.themeFor(
          'compact',
          appearance: value,
          originalTheme: source('bg-2'),
        ).appBackgroundAssetId,
        'bg-2',
      );
    },
  );
  test(
    'solid frontend and switching to own background do not keep library image',
    () {
      final followed = appearance.applyLook(
        HomeThemeModel.modernDefault,
        frontendTheme: source('bg-1').copyWith(appBackgroundMode: 'color'),
      );
      expect(followed.usesAppBackgroundImage, false);
      expect(followed.backgroundColorValue, 0xFFF0F7F2);
      final own = const BookingPageAppearance(
        style: 'compact',
        looks: {'compact': BookingPageLook(background: 0xFFFFFFFF)},
      ).applyLook(source('bg-1'), frontendTheme: source('bg-1'));
      expect(own.appBackgroundMode, 'color');
      expect(own.appBackgroundAssetId, isEmpty);
    },
  );
  testWidgets(
    'background selection offers frontend and other edits preserve follow',
    (tester) async {
      BookingPageLook current = const BookingPageLook();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: BookingLookEditor(
                  look: current,
                  onChanged: (v) => setState(() => current = v),
                  onReset: () {},
                ),
              ),
            ),
          ),
        ),
      );
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>).first,
          )
          .onChanged!(-1);
      await tester.pumpAndSettle();
      expect(current.followFrontend, true);
      expect(find.text('與前台相同'), findsWidgets);
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>).at(1),
          )
          .onChanged!(0xFF273B59);
      await tester.pumpAndSettle();
      expect(current.followFrontend, true);
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>).first,
          )
          .onChanged!(0xFFFFFFFF);
      await tester.pumpAndSettle();
      expect(current.followFrontend, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preview forwards same library settings and updates with frontend',
    (tester) async {
      Widget screen(String id) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingArrivalPreview(
              appearance: appearance,
              frontendTheme: source(id),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen('bg-1'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ShopAppBackdrop>(find.byType(ShopAppBackdrop))
            .theme
            .appBackgroundAssetId,
        'bg-1',
      );
      expect(
        tester
            .widgetList<Container>(find.byType(Container))
            .any((c) => c.color == Colors.transparent),
        true,
      );
      await tester.pumpWidget(screen('bg-2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ShopAppBackdrop>(find.byType(ShopAppBackdrop))
            .theme
            .appBackgroundAssetId,
        'bg-2',
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('frontend settings are read from current shop document', () {
    final shop = {
      'homeAppearance': {
        'layout': 'modern',
        'modern': {'themeColors': source('current-library').toMap()},
      },
    };
    expect(
      BookingPageAppearance.frontendThemeFromShop(shop).appBackgroundAssetId,
      'current-library',
    );
  });
}
