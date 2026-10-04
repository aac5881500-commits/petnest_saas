import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_flow.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_span.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_entry_card.dart';

void main() {
  HomeSectionSpan spanOf(String sectionId) {
    switch (sectionId) {
      case 'rooms':
      case 'facilities':
      case 'services':
        return HomeSectionSpan.half;
      default:
        return HomeSectionSpan.full;
    }
  }

  List<List<String>> rowIds(List<String> order) {
    return packHomeSections(
      order,
      spanOf,
    ).map((HomeSectionRow row) => row.sectionIds).toList();
  }

  test('half + half share one row', () {
    expect(rowIds(<String>['rooms', 'facilities', 'reviews']), <List<String>>[
      <String>['rooms', 'facilities'],
      <String>['reviews'],
    ]);
  });

  test('half + full stay on separate rows', () {
    expect(rowIds(<String>['rooms', 'reviews']), <List<String>>[
      <String>['rooms'],
      <String>['reviews'],
    ]);
  });

  test('full + half + half puts the pair on the second row', () {
    expect(rowIds(<String>['reviews', 'rooms', 'facilities']), <List<String>>[
      <String>['reviews'],
      <String>['rooms', 'facilities'],
    ]);
  });

  test('three halves keep the third card at half width', () {
    final List<HomeSectionRow> rows = packHomeSections(<String>[
      'rooms',
      'facilities',
      'services',
    ], spanOf);
    expect(rows.map((HomeSectionRow row) => row.sectionIds), <List<String>>[
      <String>['rooms', 'facilities'],
      <String>['services'],
    ]);
    expect(rows.last.span, HomeSectionSpan.half);
    expect(rows.last.isPair, isFalse);
  });

  test('dragging a half re-pairs the following row', () {
    const List<String> saved = <String>[
      'rooms',
      'facilities',
      'reviews',
      'services',
    ];
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: saved,
      oldIndex: 1,
      newIndex: 4,
    );
    expect(moved, <String>['rooms', 'reviews', 'services', 'facilities']);
    expect(rowIds(moved), <List<String>>[
      <String>['rooms'],
      <String>['reviews'],
      <String>['services', 'facilities'],
    ]);
    expect(moved[1], 'reviews');
    expect(moved.last, 'facilities');
  });

  test('old data without span still resolves from the card size', () {
    final HomeRoomSectionSetting rooms = HomeRoomSectionSetting.fromMap(null);
    final HomeEnvironmentSectionSetting environment =
        HomeEnvironmentSectionSetting.fromMap(null);
    expect(
      homeSectionSpan(
        sectionId: 'rooms',
        rooms: rooms,
        environment: environment,
      ),
      HomeSectionSpan.full,
    );
    expect(
      homeSectionSpan(
        sectionId: 'facilities',
        rooms: rooms,
        environment: environment,
      ),
      HomeSectionSpan.full,
    );
    expect(
      homeSectionSpan(
        sectionId: 'banners',
        rooms: rooms,
        environment: environment,
      ),
      HomeSectionSpan.full,
    );
    expect(
      homeSectionSpan(
        sectionId: 'rooms',
        rooms: HomeRoomSectionSetting.fromMap(<String, dynamic>{
          'layout': 'simpleEntry',
        }),
        environment: environment,
      ),
      HomeSectionSpan.full,
    );
    expect(
      homeSectionSpan(
        sectionId: 'facilities',
        rooms: rooms,
        environment: HomeEnvironmentSectionSetting.fromMap(<String, dynamic>{
          'layout': 'simpleEntry',
          'simpleCardSize': 'small',
        }),
      ),
      HomeSectionSpan.half,
    );
    expect(
      homeSectionSpan(
        sectionId: 'rooms',
        rooms: const HomeRoomSectionSetting(
          layout: HomeRoomSectionLayouts.simpleEntry,
          simple: HomeRoomSimpleSetting(
            cardSize: HomeRoomSimpleCardSizes.small,
          ),
        ),
        environment: const HomeEnvironmentSectionSetting(
          layout: HomeEnvironmentLayouts.imageEntry,
        ),
      ),
      HomeSectionSpan.half,
    );
    expect(
      homeSectionSpan(
        sectionId: 'facilities',
        rooms: rooms,
        environment: const HomeEnvironmentSectionSetting(
          layout: HomeEnvironmentLayouts.imageEntry,
        ),
      ),
      HomeSectionSpan.full,
    );
  });

  testWidgets('packed rows place two small cards side by side', (
    WidgetTester tester,
  ) async {
    const HomeThemeModel theme = HomeThemeModel.modernDefault;
    for (final double width in <double>[320, 500]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: Column(
                children: buildHomeSectionRows(
                  sectionIds: const <String>[
                    'rooms',
                    'facilities',
                    'reviews',
                    'services',
                  ],
                  spanOf: (String id) {
                    if (id == 'reviews') {
                      return HomeSectionSpan.full;
                    }
                    return HomeSectionSpan.half;
                  },
                  itemBuilder: (String id) {
                    if (id == 'reviews') {
                      return SizedBox(
                        key: Key('section-$id'),
                        height: 36,
                        child: Text(id),
                      );
                    }
                    return ModernHomeEntryCard(
                      cardKey: Key('section-$id'),
                      theme: theme,
                      title: '很長的標題用來確認半寬不會爆版',
                      subtitle: '很長的副標題用來確認兩張小卡可以並排',
                      showSubtitle: true,
                      cardSize: 'small',
                      surface: 'filled',
                      icon: Icons.home_outlined,
                      onTap: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final Offset rooms = tester.getTopLeft(
        find.byKey(const Key('section-rooms')),
      );
      final Offset facilities = tester.getTopLeft(
        find.byKey(const Key('section-facilities')),
      );
      final Offset reviews = tester.getTopLeft(
        find.byKey(const Key('section-reviews')),
      );
      final Offset services = tester.getTopLeft(
        find.byKey(const Key('section-services')),
      );
      expect(facilities.dy, closeTo(rooms.dy, 0.5));
      expect(facilities.dx, greaterThan(rooms.dx));
      expect(reviews.dy, greaterThan(rooms.dy));
      expect(services.dy, greaterThan(reviews.dy));
      final double roomsWidth = tester
          .getSize(find.byKey(const Key('section-rooms')))
          .width;
      final double facilitiesWidth = tester
          .getSize(find.byKey(const Key('section-facilities')))
          .width;
      final double servicesWidth = tester
          .getSize(find.byKey(const Key('section-services')))
          .width;
      final double reviewsWidth = tester
          .getSize(find.byKey(const Key('section-reviews')))
          .width;
      expect(roomsWidth, closeTo(facilitiesWidth, 1));
      expect(servicesWidth, closeTo(roomsWidth, 1));
      expect(roomsWidth, lessThan(width * 0.55));
      expect(reviewsWidth, greaterThan(width * 0.9));
      expect(
        facilities.dx - (rooms.dx + roomsWidth),
        closeTo(kHomeSectionGap, 0.5),
      );
    }
  });
}
