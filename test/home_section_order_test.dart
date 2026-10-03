import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_banner_carousel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_menu_button.dart';

void main() {
  test('missing homeSectionOrder uses the original order', () {
    expect(HomeSectionOrder.normalize(null), HomeSectionOrder.defaultOrder);
  });

  test('unknown and duplicate ids are removed and missing ids are filled', () {
    final List<String> order = HomeSectionOrder.normalize(<Object?>[
      'rooms',
      'banners',
      'nope',
      'banners',
      'announcements',
    ]);
    expect(order.contains('nope'), isFalse);
    expect(order.where((String id) => id == 'banners').length, 1);
    expect(order.indexOf('rooms'), lessThan(order.indexOf('banners')));
    expect(order.indexOf('facilities'), greaterThan(order.indexOf('banners')));
    expect(
      order.indexOf('facilities'),
      lessThan(order.indexOf('announcements')),
    );
    expect(order.indexOf('dailyCare'), order.indexOf('announcements') + 1);
    expect(order.toSet(), HomeSectionOrder.defaultOrder.toSet());
  });

  test('moving banners below announcements closes the gap', () {
    final List<String> saved = HomeSectionOrder.normalize(null);
    final List<String> visible = HomeSectionOrder.visible(
      saved,
      showAnnouncements: true,
    );
    final int announcements = visible.indexOf('announcements');
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: visible,
      oldIndex: 0,
      newIndex: announcements + 1,
    );
    expect(moved.indexOf('banners'), moved.indexOf('announcements') + 1);
    expect(moved.first, 'facilities');
    expect(moved.indexOf('rooms'), greaterThan(moved.indexOf('banners')));
    expect(HomeSectionOrder.normalize(moved), moved);
  });

  test('hiding announcements keeps their saved slot', () {
    final List<String> saved = HomeSectionOrder.reorderVisible(
      saved: HomeSectionOrder.normalize(null),
      visible: HomeSectionOrder.visible(
        HomeSectionOrder.normalize(null),
        showAnnouncements: true,
      ),
      oldIndex: 0,
      newIndex: 3,
    );
    final int slot = saved.indexOf('announcements');
    final List<String> hidden = HomeSectionOrder.visible(
      saved,
      showAnnouncements: false,
    );
    expect(hidden.contains('announcements'), isFalse);
    expect(
      HomeSectionOrder.visible(
        saved,
        showAnnouncements: true,
      ).indexOf('announcements'),
      slot,
    );
  });

  test('appearance preview hides the shop menu and the live home keeps it', () {
    expect(showHomeShopMenu(layoutCanvas: true, isPreview: true), isFalse);
    expect(showHomeShopMenu(layoutCanvas: true, isPreview: false), isFalse);
    expect(showHomeShopMenu(layoutCanvas: false, isPreview: true), isFalse);
    expect(showHomeShopMenu(layoutCanvas: false, isPreview: false), isTrue);
  });

  testWidgets('banner carousel has no review badge and sections stack', (
    WidgetTester tester,
  ) async {
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: HomeSectionOrder.normalize(null),
      visible: HomeSectionOrder.defaultOrder,
      oldIndex: 0,
      newIndex: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              for (final String id in moved)
                SizedBox(
                  key: ValueKey<String>(id),
                  height: 24,
                  child: Text(id),
                ),
              const SizedBox(
                width: 320,
                height: 180,
                child: ModernHomeBannerCarousel(
                  banners: [],
                  theme: HomeThemeModel(
                    backgroundColorValue: 0xFFFFFBF7,
                    cardColorValue: 0xFFFFFFFF,
                    cardBorderColorValue: 0xFFFFD9B3,
                    primaryColorValue: 0xFFFF8A00,
                    textColorValue: 0xFF3A2A20,
                  ),
                  frameSetting: ModernBannerFrameSetting(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('尚無評價'), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byType(ShopMenuButton), findsNothing);
    final double announcements = tester
        .getTopLeft(find.text('announcements'))
        .dy;
    final double banners = tester.getTopLeft(find.text('banners')).dy;
    final double facilities = tester.getTopLeft(find.text('facilities')).dy;
    expect(facilities, lessThan(announcements));
    expect(announcements, lessThan(banners));
    expect(banners - announcements, greaterThanOrEqualTo(24));
  });

  test('customer reviews stay on the home and the banner badge is gone', () {
    final String page = File(
      'lib/features/shop/pages/shop_public_modern_page.dart',
    ).readAsStringSync();
    expect(page.contains('ModernReviewSection('), isTrue);
    expect(page.contains("case 'reviews':"), isTrue);
    expect(page.contains('_buildBannerReviewBadge'), isFalse);
    expect(page.contains('reviewBadge:'), isFalse);
    expect(page.contains('class ShopMenuButton'), isFalse);
    expect(page.contains('showHomeShopMenu('), isTrue);
    expect(page.contains('_shopMenuButton('), isTrue);
  });
}
