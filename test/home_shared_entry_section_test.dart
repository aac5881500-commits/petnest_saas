import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_shared_entry_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/refined_image_entry_card.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shared_entry_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shared_entry_settings_card.dart';

void main() {
  test('old appearance data stays independent and keeps its columns', () {
    final HomeSharedEntrySectionSetting missing =
        HomeSharedEntrySectionSetting.fromMap(null);
    expect(missing.enabled, isFalse);
    expect(missing.title, '我們的服務');
    expect(missing.showTitle, isTrue);
    expect(missing.columns, 3);
    expect(missing.cardOrder, isEmpty);

    final HomeRoomSimpleSetting simple = HomeRoomSimpleSetting.fromMap(
      <String, dynamic>{
        'columns': 4,
        'imageAssetId': 'asset-room',
        'subtitle': '保留副標',
      },
    );
    expect(simple.placement, HomeRoomSimplePlacements.independent);
    expect(simple.columns, 4);
    expect(simple.imageAssetId, 'asset-room');

    final HomeRoomSimpleSetting shared = simple.copyWith(
      placement: HomeRoomSimplePlacements.shared,
    );
    final HomeRoomSimpleSetting restored = HomeRoomSimpleSetting.fromMap(
      shared.toMap(),
    );
    expect(restored.placement, HomeRoomSimplePlacements.shared);
    expect(restored.imageAssetId, 'asset-room');
    expect(restored.subtitle, '保留副標');
    expect(restored.columns, 4);
  });

  test(
    'shared zone membership follows the room layout and survives disable',
    () {
      const HomeRoomSectionSetting independent = HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
      );
      expect(
        sharedEntryJoinedIds(
          section: const HomeSharedEntrySectionSetting(),
          rooms: independent,
        ),
        isEmpty,
      );

      final HomeRoomSectionSetting joined = independent.copyWith(
        simple: independent.simple.copyWith(
          placement: HomeRoomSimplePlacements.shared,
          imageAssetId: 'asset-room',
        ),
      );
      final HomeSharedEntrySectionSetting saved =
          const HomeSharedEntrySectionSetting().including(
            HomeSharedEntrySources.rooms,
            when: true,
          );
      expect(sharedEntryJoinedIds(section: saved, rooms: joined), <String>[
        HomeSharedEntrySources.rooms,
      ]);
      expect(saved.enabled, isFalse);
      expect(saved.cardOrder, <String>[HomeSharedEntrySources.rooms]);

      final HomeRoomSectionSetting otherLayout = joined.copyWith(
        layout: HomeRoomSectionLayouts.horizontalScroll,
      );
      expect(sharedEntryJoinedIds(section: saved, rooms: otherLayout), <String>[
        HomeSharedEntrySources.rooms,
      ]);
      expect(
        sharedEntryHidesSimpleSection(
          sourceId: HomeSharedEntrySources.rooms,
          layout: otherLayout.layout,
          simpleLayout: HomeRoomSectionLayouts.simpleEntry,
          section: saved,
          rooms: otherLayout,
        ),
        isFalse,
      );
      expect(
        sharedEntryHidesSimpleSection(
          sourceId: HomeSharedEntrySources.rooms,
          layout: joined.layout,
          simpleLayout: HomeRoomSectionLayouts.simpleEntry,
          section: saved,
          rooms: joined,
        ),
        isFalse,
      );
      expect(
        sharedEntryHidesSimpleSection(
          sourceId: HomeSharedEntrySources.rooms,
          layout: joined.layout,
          simpleLayout: HomeRoomSectionLayouts.simpleEntry,
          section: saved.copyWith(enabled: true),
          rooms: joined,
        ),
        isTrue,
      );
      expect(otherLayout.simple.imageAssetId, 'asset-room');
      expect(otherLayout.simple.placement, HomeRoomSimplePlacements.shared);

      final HomeSharedEntrySectionSetting enabled = saved.copyWith(
        enabled: true,
      );
      final HomeSharedEntrySectionSetting roundTrip =
          HomeSharedEntrySectionSetting.fromMap(enabled.toMap());
      expect(roundTrip.enabled, isTrue);
      expect(roundTrip.cardOrder, <String>[HomeSharedEntrySources.rooms]);
      expect(
        HomeSectionOrder.normalize(null).indexOf('sharedEntries'),
        HomeSectionOrder.defaultOrder.indexOf('banners') + 1,
      );
      expect(
        HomeSectionOrder.visible(
          HomeSectionOrder.normalize(null),
          showAnnouncements: true,
        ),
        isNot(contains('sharedEntries')),
      );
      expect(
        HomeSectionOrder.visible(
          HomeSectionOrder.normalize(null),
          showAnnouncements: true,
          showSharedEntries: true,
          showRooms: false,
        ),
        isNot(contains('rooms')),
      );
    },
  );

  test('internal card order does not drop cards that are temporarily out', () {
    const List<String> saved = <String>['rooms', 'about'];
    final List<String> next = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: const <String>['rooms'],
      oldIndex: 0,
      newIndex: 0,
    );
    expect(next, saved);
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: const <String>['rooms', 'about', 'news'],
      visible: const <String>['rooms', 'news'],
      oldIndex: 0,
      newIndex: 2,
    );
    expect(moved.indexOf('news'), lessThan(moved.indexOf('rooms')));
    expect(moved.contains('about'), isTrue);
  });

  testWidgets('shared grid wraps cards and keeps one card in its slot', (
    WidgetTester tester,
  ) async {
    Future<void> pump({
      required double width,
      required int columns,
      required int count,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: ModernHomeSharedEntrySection(
                theme: HomeThemeModel.modernDefault,
                setting: HomeSharedEntrySectionSetting(
                  enabled: true,
                  columns: columns,
                  showTitle: false,
                ),
                cardIds: <String>[
                  for (int index = 0; index < count; index++) 'card-$index',
                ],
                cardBuilder: (String id) {
                  return RefinedImageEntryCard(
                    cardKey: Key('shared-$id'),
                    featureId: id,
                    theme: HomeThemeModel.modernDefault,
                    title: '入口',
                    subtitle: '副標',
                    showSubtitle: true,
                    textMode: HomeRoomSimpleTextModes.below,
                    textAlign: HomeRoomSimpleTextAligns.bottomStart,
                    textSize: HomeRoomSimpleTextSizes.medium,
                    textWeight: HomeRoomSimpleTextWeights.bold,
                    textColor: HomeRoomSimpleTextColors.dark,
                    aspect: HomeRoomSimpleAspects.square,
                    radius: HomeRoomSimpleRadii.medium,
                    mask: HomeRoomSimpleMasks.none,
                    imageUrl: '',
                    sizeMode: RefinedEntrySizeMode.slot,
                    onTap: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    await pump(width: 640, columns: 2, count: 1);
    final double twoSlot = tester
        .getSize(find.byKey(const Key('shared-card-0')))
        .width;
    await pump(width: 640, columns: 3, count: 1);
    final double threeSlot = tester
        .getSize(find.byKey(const Key('shared-card-0')))
        .width;
    await pump(width: 640, columns: 4, count: 1);
    final double fourSlot = tester
        .getSize(find.byKey(const Key('shared-card-0')))
        .width;
    expect(twoSlot, greaterThan(threeSlot));
    expect(fourSlot, closeTo(threeSlot, 0.5));
    expect(
      tester.getSize(find.byKey(const Key('refined-entry-image'))).height /
          threeSlot,
      closeTo(1, 0.08),
    );

    await pump(width: 640, columns: 3, count: 5);
    final double firstRow = tester
        .getTopLeft(find.byKey(const Key('shared-card-0')))
        .dy;
    final double third = tester
        .getTopLeft(find.byKey(const Key('shared-card-2')))
        .dy;
    final double fourth = tester
        .getTopLeft(find.byKey(const Key('shared-card-3')))
        .dy;
    expect(third, closeTo(firstRow, 1));
    expect(fourth, greaterThan(firstRow + 40));
    expect(find.byKey(const Key('shared-card-4')), findsOneWidget);

    await pump(width: 320, columns: 4, count: 4);
    final double narrowTop = tester
        .getTopLeft(find.byKey(const Key('shared-card-0')))
        .dy;
    final int firstRowCount = <int>[0, 1, 2, 3].where((int index) {
      return (tester.getTopLeft(find.byKey(Key('shared-card-$index'))).dy -
                  narrowTop)
              .abs() <
          1;
    }).length;
    expect(firstRowCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared cards scroll sideways without widening the page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int taps = 0;
    Future<void> pump({required int columns, required String overflow}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ModernHomeSharedEntrySection(
                theme: HomeThemeModel.modernDefault,
                setting: HomeSharedEntrySectionSetting(
                  enabled: true,
                  columns: columns,
                  overflow: overflow,
                  showTitle: false,
                ),
                cardIds: const <String>[
                  'card-0',
                  'card-1',
                  'card-2',
                  'card-3',
                  'card-4',
                ],
                cardBuilder: (String id) {
                  return RefinedImageEntryCard(
                    cardKey: Key('shared-$id'),
                    featureId: id,
                    theme: HomeThemeModel.modernDefault,
                    title: '入口',
                    subtitle: '副標',
                    showSubtitle: true,
                    textMode: HomeRoomSimpleTextModes.below,
                    textAlign: HomeRoomSimpleTextAligns.bottomStart,
                    textSize: HomeRoomSimpleTextSizes.medium,
                    textWeight: HomeRoomSimpleTextWeights.bold,
                    textColor: HomeRoomSimpleTextColors.dark,
                    aspect: HomeRoomSimpleAspects.square,
                    radius: HomeRoomSimpleRadii.medium,
                    mask: HomeRoomSimpleMasks.none,
                    imageUrl: '',
                    sizeMode: RefinedEntrySizeMode.slot,
                    onTap: () => taps += 1,
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    await pump(columns: 3, overflow: HomeSharedEntryOverflows.scroll);
    final double first = tester
        .getTopLeft(find.byKey(const Key('shared-card-0')))
        .dy;
    final double third = tester
        .getTopLeft(find.byKey(const Key('shared-card-2')))
        .dy;
    final double fourthBefore = tester
        .getTopLeft(find.byKey(const Key('shared-card-3')))
        .dx;
    expect(third, closeTo(first, 1));
    expect(
      fourthBefore,
      greaterThan(tester.getTopLeft(find.byKey(const Key('shared-card-2'))).dx),
    );
    expect(find.byKey(const Key('shared-entry-scroll')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('shared-card-0')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(taps, 1);
    await tester.drag(
      find.byKey(const Key('shared-entry-scroll')),
      const Offset(-140, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-3'))).dx,
      lessThan(fourthBefore),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dy,
      closeTo(first, 1),
    );
    expect(taps, 1);
    final ScrollableState scrollable = tester.state(find.byType(Scrollable));
    await tester.drag(
      find.byKey(const Key('shared-entry-scroll')),
      const Offset(-4000, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 0.5),
    );
    expect(taps, 1);

    await pump(columns: 1, overflow: HomeSharedEntryOverflows.scroll);
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-1'))).dx,
      greaterThan(tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dx),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-1'))).dy,
      closeTo(tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dy, 1),
    );

    await pump(columns: 2, overflow: HomeSharedEntryOverflows.wrap);
    expect(find.byKey(const Key('shared-entry-scroll')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-2'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dy),
    );
    expect(
      tester.getSize(find.byKey(const Key('shared-card-2'))).width,
      closeTo(tester.getSize(find.byKey(const Key('shared-card-0'))).width, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared card order buttons keep the saved sequence', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeSharedEntrySectionSetting setting = const HomeSharedEntrySectionSetting(
      enabled: true,
      cardOrder: <String>['rooms', 'about'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SharedEntrySettingsCard(
                setting: setting,
                cards: const <SharedEntryCardRef>[
                  SharedEntryCardRef(id: 'rooms', label: '房型介紹'),
                  SharedEntryCardRef(id: 'about', label: '關於我們'),
                ],
                onChanged: (HomeSharedEntrySectionSetting next) {
                  setState(() => setting = next);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('排列'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-entry-down-rooms')));
    await tester.pump();
    expect(
      setting.cardOrder.indexOf('about'),
      lessThan(setting.cardOrder.indexOf('rooms')),
    );
    expect(setting.enabled, isTrue);
  });

  testWidgets('shared style is unified and the card editor stays short', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeSharedEntrySectionSetting setting =
        const HomeSharedEntrySectionSetting(
          enabled: true,
          cardOrder: <String>['rooms', 'facilities'],
        ).updateCard(
          HomeSharedEntrySources.rooms,
          const HomeSharedEntryCardSetting(title: '住宿'),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: SharedEntrySettingsCard(
                  setting: setting,
                  cards: const <SharedEntryCardRef>[
                    SharedEntryCardRef(id: 'rooms', label: '房型介紹'),
                    SharedEntryCardRef(id: 'facilities', label: '環境介紹'),
                  ],
                  onChanged: (HomeSharedEntrySectionSetting next) {
                    setState(() => setting = next);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('一排 4 張'), findsNothing);
    await tester.tap(find.text('排列'));
    await tester.pumpAndSettle();
    expect(find.text('一排 1 張'), findsOneWidget);
    expect(find.text('一排 3 張'), findsOneWidget);
    await tester.tap(find.text('左右滑動瀏覽'));
    await tester.pump();
    expect(setting.overflow, HomeSharedEntryOverflows.scroll);
    expect(setting.cardOrder, <String>['rooms', 'facilities']);

    await tester.tap(find.text('卡片外觀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('圓角大'));
    await tester.pump();
    expect(setting.style.radius, HomeRoomSimpleRadii.large);
    expect(setting.cardOf(HomeSharedEntrySources.rooms).title, '住宿');
    expect(setting.cardOf(HomeSharedEntrySources.facilities).title, '環境介紹');

    await tester.tap(find.text('排列'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('shared-entry-edit-rooms')),
    );
    await tester.tap(find.byKey(const Key('shared-entry-edit-rooms')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('統一字體'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('圓角大小'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('沿用預設顏色'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('沿用來源圖片'),
      ),
      findsNothing,
    );
    await tester.enterText(find.widgetWithText(TextFormField, '主標題'), '套房');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(setting.cardOf(HomeSharedEntrySources.rooms).title, '套房');
    expect(setting.cardOf(HomeSharedEntrySources.facilities).title, '環境介紹');
    expect(setting.style.radius, HomeRoomSimpleRadii.large);
    await tester.tap(find.text('快速風格'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原始緊湊'));
    await tester.pump();
    expect(setting.style.imageScale, 1);
    expect(setting.style.gapX, 8);
    expect(setting.style.insetX, 0);
    expect(setting.cardOf(HomeSharedEntrySources.rooms).title, '套房');
    expect(
      HomeSharedEntryPresets.match(setting.style),
      HomeSharedEntryPresets.compact,
    );
    await tester.tap(find.text('精緻留白'));
    await tester.pump();
    expect(setting.style.imageScale, closeTo(0.86, 0.001));
    expect(setting.style.gapX, 16);
    expect(setting.cardOf(HomeSharedEntrySources.facilities).title, '環境介紹');
    await tester.tap(find.text('尺寸間距'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(-120, 0));
    await tester.pump();
    expect(setting.style.imageScale, lessThan(0.86));
    expect(
      HomeSharedEntryPresets.match(setting.style),
      HomeSharedEntryPresets.custom,
    );
    expect(setting.cardOf(HomeSharedEntrySources.rooms).title, '套房');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inside-bottom text stays on the image and outside text sits below',
    (WidgetTester tester) async {
      Future<void> pump(
        String placement, {
        String mask = HomeRoomSimpleMasks.none,
        String imageUrl = '',
      }) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                child: SharedEntryRefinedCard(
                  card: const HomeSharedEntryCardSetting(
                    title: '入口標題',
                    subtitle: '說明',
                    textPlacement: HomeSharedEntryPlacements.insideBottom,
                    fontFamily: 'KleeOne',
                  ),
                  style: HomeSharedEntryStyle(
                    textPlacement: placement,
                    mask: mask,
                  ),
                  sourceId: 'rooms',
                  theme: HomeThemeModel.modernDefault,
                  imageUrl: imageUrl,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
      }

      for (final String placement in HomeSharedEntryPlacements.all) {
        await pump(placement);
        await tester.pump();
        expect(
          find.byIcon(Icons.image_outlined),
          findsOneWidget,
          reason: placement,
        );
      }

      await pump(HomeSharedEntryPlacements.center);
      await tester.pump();
      final Rect centerImage = tester.getRect(
        find.byKey(const Key('refined-entry-image')),
      );
      final Rect titleBox = tester.getRect(find.text('入口標題'));
      final Rect subtitleBox = tester.getRect(find.text('說明'));
      final Rect textGroup = titleBox.expandToInclude(subtitleBox);
      expect(textGroup.center.dx, closeTo(centerImage.center.dx, 6));
      expect(textGroup.center.dy, closeTo(centerImage.center.dy, 8));
      expect(
        tester.getBottomLeft(find.byIcon(Icons.image_outlined)).dy,
        lessThanOrEqualTo(titleBox.top + 1),
      );

      await pump(
        HomeSharedEntryPlacements.center,
        imageUrl: 'https://example.invalid/room.png',
      );
      await tester.pump();
      expect(find.byKey(const Key('refined-entry-scrim')), findsNothing);
      expect(find.byKey(const Key('refined-entry-mask')), findsNothing);
      final Rect photo = tester.getRect(
        find.byKey(const Key('refined-entry-image')),
      );
      final Rect photoTitle = tester.getRect(find.text('入口標題'));
      final Rect photoSubtitle = tester.getRect(find.text('說明'));
      final Rect photoGroup = photoTitle.expandToInclude(photoSubtitle);
      expect(photoGroup.center.dx, closeTo(photo.center.dx, 6));
      expect(photoGroup.center.dy, closeTo(photo.center.dy, 8));
      expect(
        tester
            .widgetList<Material>(find.byType(Material))
            .every((Material material) => material.elevation == 0),
        isTrue,
      );
      Object? imageError = tester.takeException();
      while (imageError != null) {
        expect('$imageError', isNot(contains('overflowed')));
        imageError = tester.takeException();
      }

      await pump(HomeSharedEntryPlacements.above);
      await tester.pump();
      expect(
        tester.getBottomLeft(find.text('入口標題')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('refined-entry-image'))).dy +
              1,
        ),
      );

      await pump(HomeSharedEntryPlacements.insideBottom);
      await tester.pump();
      final Rect image = tester.getRect(
        find.byKey(const Key('refined-entry-image')),
      );
      final double insideTitle = tester.getCenter(find.text('入口標題')).dy;
      expect(insideTitle, greaterThan(image.top));
      expect(insideTitle, lessThan(image.bottom));
      expect(
        tester.getTopLeft(find.byIcon(Icons.image_outlined)).dy,
        lessThan(insideTitle),
      );

      await pump(HomeSharedEntryPlacements.outsideBelow);
      await tester.pump();
      final double outsideTitle = tester.getTopLeft(find.text('入口標題')).dy;
      final double imageBottom = tester
          .getBottomLeft(find.byKey(const Key('refined-entry-image')))
          .dy;
      expect(outsideTitle, greaterThan(imageBottom - 1));
      expect(
        DefaultTextStyle.of(tester.element(find.text('入口標題'))).style.fontFamily,
        isNot('KleeOne'),
      );
      await pump(
        HomeSharedEntryPlacements.outsideBelow,
        mask: HomeRoomSimpleMasks.strong,
      );
      await tester.pump();
      expect(find.byKey(const Key('refined-entry-mask')), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow on-image cards keep their text without overflow', (
    WidgetTester tester,
  ) async {
    const String title = '很長的住宿空間主標題';
    const String subtitle = '很長的副標題說明文字不應該溢位';

    Future<void> pump({
      required double width,
      required int columns,
      required String placement,
      required HomeSharedEntryStyle style,
      bool showSubtitle = true,
      String imageUrl = '',
    }) {
      final HomeSharedEntryStyle resolved = style.copyWith(
        textPlacement: placement,
      );
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: ModernHomeSharedEntrySection(
                  theme: HomeThemeModel.modernDefault,
                  setting: HomeSharedEntrySectionSetting(
                    enabled: true,
                    columns: columns,
                    showTitle: false,
                    style: resolved,
                  ),
                  cardIds: const <String>['card-0', 'card-1', 'card-2'],
                  cardBuilder: (String id) {
                    return SharedEntryRefinedCard(
                      card: HomeSharedEntryCardSetting(
                        title: title,
                        subtitle: subtitle,
                        showSubtitle: showSubtitle,
                      ),
                      style: resolved,
                      sourceId: id,
                      theme: HomeThemeModel.modernDefault,
                      imageUrl: imageUrl,
                      columns: columns,
                      onTap: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    void expectNoOverflow(String reason) {
      Object? error = tester.takeException();
      while (error != null) {
        expect('$error', isNot(contains('overflowed')), reason: reason);
        error = tester.takeException();
      }
    }

    for (final int columns in <int>[1, 2, 3]) {
      for (final String placement in HomeSharedEntryPlacements.all) {
        await pump(
          width: 320,
          columns: columns,
          placement: placement,
          style: const HomeSharedEntryStyle(iconSize: 64, imageScale: 0.9),
        );
        await tester.pump();
        expectNoOverflow('$columns $placement');
        expect(find.text(title), findsNWidgets(3));
        if (placement == HomeSharedEntryPlacements.above ||
            placement == HomeSharedEntryPlacements.outsideBelow ||
            columns == 1) {
          expect(find.text(subtitle), findsNWidgets(3));
        }
        expect(find.byIcon(Icons.image_outlined), findsNWidgets(3));
      }
    }

    await pump(
      width: 280,
      columns: 3,
      placement: HomeSharedEntryPlacements.center,
      style: HomeSharedEntryPresets.compactStyle.copyWith(iconSize: 72),
    );
    await tester.pump();
    expectNoOverflow('compact center');
    expect(find.text(title), findsNWidgets(3));
    final Icon compactIcon = tester.widget<Icon>(find.byType(Icon).first);
    expect(compactIcon.size, isNotNull);
    expect(compactIcon.size!, lessThan(72));

    await pump(
      width: 280,
      columns: 3,
      placement: HomeSharedEntryPlacements.insideBottom,
      style: HomeSharedEntryPresets.airyStyle.copyWith(
        aspect: HomeRoomSimpleAspects.landscape,
        iconSize: 72,
      ),
    );
    await tester.pump();
    expectNoOverflow('airy landscape');
    expect(find.text(title), findsNWidgets(3));
    expect(find.byIcon(Icons.image_outlined), findsNWidgets(3));

    await pump(
      width: 320,
      columns: 3,
      placement: HomeSharedEntryPlacements.center,
      style: const HomeSharedEntryStyle(iconSize: 72),
      showSubtitle: false,
    );
    await tester.pump();
    expectNoOverflow('subtitle hidden');
    expect(find.text(title), findsNWidgets(3));
    expect(find.text(subtitle), findsNothing);

    for (final String placement in <String>[
      HomeSharedEntryPlacements.center,
      HomeSharedEntryPlacements.insideBottom,
    ]) {
      await pump(
        width: 320,
        columns: 3,
        placement: placement,
        style: const HomeSharedEntryStyle(iconSize: 64, imageScale: 0.86),
        imageUrl: 'https://example.invalid/shared-card.png',
      );
      await tester.pump();
      expectNoOverflow('photo $placement');
      expect(find.text(title), findsNWidgets(3));
    }
  });

  test('old four-column data loads as three and keeps card text', () {
    final HomeSharedEntrySectionSetting loaded =
        HomeSharedEntrySectionSetting.fromMap(<String, dynamic>{
          'enabled': true,
          'columns': 4,
          'cardOrder': <String>['rooms'],
          'cards': <String, dynamic>{
            'rooms': <String, dynamic>{
              'title': '住宿',
              'fontFamily': 'KleeOne',
              'textPlacement': 'insideBottom',
              'radius': 'large',
              'textColor': 0xFFFFFFFF,
            },
          },
        });
    expect(loaded.columns, 3);
    expect(loaded.overflow, HomeSharedEntryOverflows.wrap);
    expect(loaded.style.radius, HomeRoomSimpleRadii.medium);
    expect(loaded.style.textPlacement, HomeSharedEntryPlacements.outsideBelow);
    expect(loaded.cardOf(HomeSharedEntrySources.rooms).title, '住宿');
    expect(
      loaded.cardOf(HomeSharedEntrySources.rooms).titleColorMode,
      HomeSharedEntryColorModes.custom,
    );
    expect(loaded.cardOf(HomeSharedEntrySources.rooms).textColor, 0xFFFFFFFF);
    expect(
      loaded.cardOf(HomeSharedEntrySources.rooms).bodyColorMode,
      HomeSharedEntryColorModes.custom,
    );
    final HomeSharedEntrySectionSetting themed =
        HomeSharedEntrySectionSetting.fromMap(<String, dynamic>{
          'cards': <String, dynamic>{
            'rooms': <String, dynamic>{
              'titleColorMode': 'theme',
              'textColor': 0xFFFFFFFF,
            },
          },
        });
    expect(
      themed.cardOf(HomeSharedEntrySources.rooms).titleColorMode,
      HomeSharedEntryColorModes.theme,
    );
    expect(loaded.cardOf(HomeSharedEntrySources.rooms).fontFamily, 'KleeOne');
    expect(loaded.toMap()['columns'], 3);
    expect(loaded.toMap()['overflow'], HomeSharedEntryOverflows.wrap);
    expect(loaded.style.imageScale, 0.9);
    expect(loaded.style.gapX, 12);
    final HomeSharedEntryStyle legacy = HomeSharedEntryStyle.fromMap(
      <String, dynamic>{
        'imageScale': 'small',
        'gapX': 'compact',
        'iconSize': 60,
      },
    );
    expect(legacy.imageScale, 0.82);
    expect(legacy.gapX, 6);
    expect(legacy.iconSize, 60);
    final HomeSharedEntryStyle kept = HomeSharedEntryPresets.apply(
      const HomeSharedEntryStyle(fontFamily: 'KleeOne'),
      HomeSharedEntryPresets.airy,
    );
    expect(kept.fontFamily, 'KleeOne');
    expect(kept.imageScale, closeTo(0.86, 0.001));
    expect(
      HomeSharedEntryPresets.match(HomeSharedEntryPresets.compactStyle),
      HomeSharedEntryPresets.compact,
    );
    expect(
      sharedEntryGalleryAssetId(
        const HomeSharedEntryCardSetting(
          useSourceImage: true,
          imageAssetId: '',
        ),
      ),
      isEmpty,
    );
    expect(
      sharedEntryGalleryAssetId(
        const HomeSharedEntryCardSetting(
          useSourceImage: true,
          imageAssetId: 'gallery-1',
        ),
      ),
      'gallery-1',
    );
    expect(
      HomeSectionOrder.visible(
        HomeSectionOrder.defaultOrder,
        showAnnouncements: true,
        showServices: false,
        showSharedEntries: true,
      ).contains('services'),
      isFalse,
    );

    final HomeSharedEntrySectionSetting one = loaded.copyWith(columns: 1);
    expect(one.columns, 1);
    expect(one.cardOf(HomeSharedEntrySources.rooms).title, '住宿');
  });

  testWidgets('smaller images stay centered and spacing stays independent', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> pump(HomeSharedEntryStyle style, {int columns = 3}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ModernHomeSharedEntrySection(
                theme: HomeThemeModel.modernDefault,
                setting: HomeSharedEntrySectionSetting(
                  enabled: true,
                  columns: columns,
                  showTitle: true,
                  title: '我們的服務',
                  style: style,
                ),
                cardIds: const <String>['card-0', 'card-1', 'card-2'],
                cardBuilder: (String id) {
                  return RefinedImageEntryCard(
                    cardKey: Key('shared-$id'),
                    featureId: id,
                    theme: HomeThemeModel.modernDefault,
                    title: '入口',
                    subtitle: '副標',
                    showSubtitle: true,
                    textMode: HomeRoomSimpleTextModes.below,
                    textAlign: HomeRoomSimpleTextAligns.bottomStart,
                    textSize: HomeRoomSimpleTextSizes.medium,
                    textWeight: HomeRoomSimpleTextWeights.bold,
                    textColor: HomeRoomSimpleTextColors.dark,
                    aspect: HomeRoomSimpleAspects.square,
                    radius: HomeRoomSimpleRadii.medium,
                    mask: HomeRoomSimpleMasks.none,
                    imageUrl: '',
                    sizeMode: RefinedEntrySizeMode.slot,
                    contentScale: style.imageScale,
                    maxContentWidth: columns <= 1
                        ? kSharedEntrySingleColumnCap
                        : null,
                    iconExtent: style.iconSize,
                    onTap: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    const HomeSharedEntryStyle small = HomeSharedEntryStyle(
      imageScale: 0.82,
      gapX: 12,
    );
    await pump(small);
    final Finder smallImage = find.descendant(
      of: find.byKey(const Key('shared-card-0')),
      matching: find.byKey(const Key('refined-entry-image')),
    );
    final double smallWidth = tester.getSize(smallImage).width;
    final double smallLeft = tester.getTopLeft(smallImage).dx;
    final double slotWidth = tester
        .getSize(find.byKey(const Key('shared-card-0')))
        .width;

    const HomeSharedEntryStyle large = HomeSharedEntryStyle(
      imageScale: 1,
      gapX: 12,
    );
    await pump(large);
    final Finder largeImage = find.descendant(
      of: find.byKey(const Key('shared-card-0')),
      matching: find.byKey(const Key('refined-entry-image')),
    );
    final double largeWidth = tester.getSize(largeImage).width;
    expect(smallWidth, lessThan(largeWidth * 0.9));
    expect(slotWidth, greaterThan(smallWidth));
    expect(
      smallLeft,
      greaterThan(tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dx),
    );

    await pump(const HomeSharedEntryStyle(gapX: 6));
    final double compactPitch =
        tester.getTopLeft(find.byKey(const Key('shared-card-1'))).dx -
        tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dx;
    await pump(const HomeSharedEntryStyle(gapX: 18));
    final double relaxedPitch =
        tester.getTopLeft(find.byKey(const Key('shared-card-1'))).dx -
        tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dx;
    expect(relaxedPitch, greaterThan(compactPitch));
    expect(
      tester.getTopLeft(find.byKey(const Key('shared-card-2'))).dy,
      closeTo(tester.getTopLeft(find.byKey(const Key('shared-card-0'))).dy, 1),
    );

    await pump(
      const HomeSharedEntryStyle(imageScale: 1, fontFamily: 'NotoSansTC'),
      columns: 1,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byKey(const Key('shared-card-0')),
              matching: find.byKey(const Key('refined-entry-image')),
            ),
          )
          .width,
      lessThan(300),
    );
    expect(
      tester.getSize(find.byKey(const Key('shared-card-0'))).width,
      greaterThan(300),
    );
    expect(
      DefaultTextStyle.of(tester.element(find.text('我們的服務'))).style.fontFamily,
      'NotoSansTC',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('outside text gap follows the shared spacing setting', (
    WidgetTester tester,
  ) async {
    Future<double> gapFor(double gap, {double iconSize = 44}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: SharedEntryRefinedCard(
                card: const HomeSharedEntryCardSetting(
                  title: '入口標題',
                  subtitle: '說明',
                ),
                style: HomeSharedEntryStyle(
                  textPlacement: HomeSharedEntryPlacements.outsideBelow,
                  gapText: gap,
                  iconSize: iconSize,
                  imageScale: 0.7,
                ),
                sourceId: 'rooms',
                theme: HomeThemeModel.modernDefault,
                imageUrl: '',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.text('入口標題')).dy -
          tester.getBottomLeft(find.byKey(const Key('refined-entry-image'))).dy;
    }

    final double compact = await gapFor(4);
    final double relaxed = await gapFor(16);
    final double smallIcon = tester
        .getSize(find.byKey(const Key('refined-entry-image')))
        .width;
    await gapFor(16, iconSize: 64);
    final double largeIcon = tester
        .getSize(find.byKey(const Key('refined-entry-image')))
        .width;
    expect(largeIcon, greaterThan(smallIcon + 8));
    expect(relaxed, greaterThan(compact));
    final Container icon = tester.widget<Container>(
      find.byKey(const Key('refined-entry-image')),
    );
    final BoxDecoration decoration = icon.decoration! as BoxDecoration;
    expect(decoration.borderRadius, isNot(BorderRadius.zero));
    expect(tester.takeException(), isNull);
  });

  test(
    'each shared card keeps its own text and removing it keeps the data',
    () {
      final HomeSharedEntrySectionSetting added =
          const HomeSharedEntrySectionSetting()
              .including(HomeSharedEntrySources.rooms, when: true)
              .including(HomeSharedEntrySources.facilities, when: true);
      expect(added.cardOrder, <String>[
        HomeSharedEntrySources.rooms,
        HomeSharedEntrySources.facilities,
      ]);
      final HomeSharedEntrySectionSetting again = added.including(
        HomeSharedEntrySources.rooms,
        when: true,
      );
      expect(again.cardOrder, added.cardOrder);

      final HomeSharedEntrySectionSetting edited = again
          .updateCard(
            HomeSharedEntrySources.rooms,
            again.cardOf(HomeSharedEntrySources.rooms).copyWith(title: '住宿'),
          )
          .updateCard(
            HomeSharedEntrySources.facilities,
            again
                .cardOf(HomeSharedEntrySources.facilities)
                .copyWith(
                  title: '環境',
                  textPlacement: HomeSharedEntryPlacements.insideBottom,
                ),
          );
      expect(edited.cardOf(HomeSharedEntrySources.rooms).title, '住宿');
      expect(edited.cardOf(HomeSharedEntrySources.facilities).title, '環境');
      expect(
        edited.cardOf(HomeSharedEntrySources.facilities).textPlacement,
        HomeSharedEntryPlacements.insideBottom,
      );

      final HomeSharedEntrySectionSetting removed = edited.without(
        HomeSharedEntrySources.rooms,
      );
      expect(removed.cardOrder, <String>[HomeSharedEntrySources.facilities]);
      expect(removed.cards[HomeSharedEntrySources.rooms]?.title, '住宿');
      final HomeSharedEntrySectionSetting restored = removed.including(
        HomeSharedEntrySources.rooms,
        when: true,
      );
      expect(restored.cardOf(HomeSharedEntrySources.rooms).title, '住宿');

      final HomeSharedEntrySectionSetting old =
          HomeSharedEntrySectionSetting.fromMap(<String, dynamic>{
            'enabled': true,
            'cardOrder': <String>['rooms'],
          });
      expect(old.cardOf(HomeSharedEntrySources.rooms).title, '房型介紹');
      expect(old.cardOf(HomeSharedEntrySources.rooms).useSourceImage, isTrue);
    },
  );

  testWidgets('disabled shared zone warns without clearing the room entry', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeRoomSectionSetting setting = const HomeRoomSectionSetting(
      layout: HomeRoomSectionLayouts.simpleEntry,
      simple: HomeRoomSimpleSetting(
        placement: HomeRoomSimplePlacements.shared,
        imageAssetId: 'asset-room',
        icon: HomeRoomSimpleIcons.hotel,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 1200,
            child: RoomSectionSettingsPanel(
              shopId: 'shop',
              setting: setting,
              theme: HomeThemeModel.modernDefault,
              sharedZoneEnabled: false,
              rooms: const <Map<String, dynamic>>[],
              onChanged: (HomeRoomSectionSetting next) => setting = next,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('目前共用小卡區未啟用，此入口暫時不會顯示。', skipOffstage: false),
      findsOneWidget,
    );
    expect(setting.simple.imageAssetId, 'asset-room');
    expect(setting.simple.placement, HomeRoomSimplePlacements.shared);
  });

  testWidgets('shared settings tabs fit a phone width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SharedEntrySettingsCard(
              setting: const HomeSharedEntrySectionSetting(
                enabled: true,
                cardOrder: <String>['rooms'],
              ),
              cards: const <SharedEntryCardRef>[
                SharedEntryCardRef(id: 'rooms', label: '房型介紹'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    for (final String label in <String>['快速風格', '排列', '尺寸間距', '文字', '卡片外觀']) {
      final Finder tab = find.text(label);
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  test('勾選套用保留順序與被移出的小卡設定', () {
    const HomeSharedEntryCardSetting room = HomeSharedEntryCardSetting(
      title: '住宿',
      subtitle: '舒適安心',
      imageAssetId: 'img-a',
      recentImageAssetIds: <String>['img-a', 'img-b'],
    );
    final HomeSharedEntrySectionSetting start =
        const HomeSharedEntrySectionSetting(
          cardOrder: <String>['about', 'rooms'],
        ).updateCard(HomeSharedEntrySources.rooms, room);
    final HomeSharedEntrySectionSetting added = start
        .applyJoined(const <String>[
          HomeSharedEntrySources.rooms,
          HomeSharedEntrySources.facilities,
          HomeSharedEntrySources.about,
          HomeSharedEntrySources.quickBooking,
          HomeSharedEntrySources.rooms,
        ]);
    expect(added.cardOrder, <String>[
      HomeSharedEntrySources.about,
      HomeSharedEntrySources.rooms,
      HomeSharedEntrySources.facilities,
      HomeSharedEntrySources.quickBooking,
    ]);
    expect(added.cardOf(HomeSharedEntrySources.rooms).title, '住宿');
    expect(added.cardOf(HomeSharedEntrySources.rooms).imageAssetId, 'img-a');

    final HomeSharedEntrySectionSetting hidden = added.applyJoined(
      const <String>[
        HomeSharedEntrySources.facilities,
        HomeSharedEntrySources.quickBooking,
      ],
    );
    expect(hidden.cardOrder, <String>[
      HomeSharedEntrySources.facilities,
      HomeSharedEntrySources.quickBooking,
    ]);
    expect(hidden.cards[HomeSharedEntrySources.rooms]?.subtitle, '舒適安心');
    expect(
      hidden.cards[HomeSharedEntrySources.rooms]?.recentImageAssetIds,
      <String>['img-a', 'img-b'],
    );

    final HomeSharedEntrySectionSetting restored = hidden
        .applyJoined(const <String>[
          HomeSharedEntrySources.facilities,
          HomeSharedEntrySources.rooms,
          HomeSharedEntrySources.quickBooking,
        ]);
    expect(restored.cardOrder.last, HomeSharedEntrySources.rooms);
    expect(restored.cardOf(HomeSharedEntrySources.rooms).imageAssetId, 'img-a');
    expect(restored.cardOrder.where((String id) => id == 'rooms').length, 1);
  });

  test('最近使用圖片去重、置頂，且舊資料缺欄位時為空', () {
    HomeSharedEntryCardSetting card = const HomeSharedEntryCardSetting(
      imageAssetId: 'img-a',
    );
    expect(card.recentImageAssetIds, isEmpty);
    for (final String id in <String>[
      'img-a',
      'img-b',
      'img-c',
      'img-d',
      'img-e',
      'img-f',
      'img-c',
    ]) {
      card = card.rememberImage(id);
    }
    expect(card.recentImageAssetIds, <String>[
      'img-c',
      'img-f',
      'img-e',
      'img-d',
      'img-b',
    ]);
    expect(
      card.rememberImage('bad/id').recentImageAssetIds,
      card.recentImageAssetIds,
    );
    final HomeSharedEntryCardSetting cleared = card.copyWith(imageAssetId: '');
    expect(cleared.imageAssetId, isEmpty);
    expect(cleared.recentImageAssetIds, card.recentImageAssetIds);

    final HomeSharedEntryCardSetting old = HomeSharedEntryCardSetting.fromMap(
      <String, dynamic>{'title': '房型介紹', 'imageAssetId': 'keep-me'},
      HomeSharedEntrySources.rooms,
    );
    expect(old.recentImageAssetIds, isEmpty);
    expect(old.imageAssetId, 'keep-me');
    final HomeSharedEntryCardSetting round = HomeSharedEntryCardSetting.fromMap(
      card.toMap(),
      HomeSharedEntrySources.rooms,
    );
    expect(round.recentImageAssetIds, card.recentImageAssetIds);

    final HomeSharedEntrySectionSetting section =
        const HomeSharedEntrySectionSetting()
            .updateCard(HomeSharedEntrySources.rooms, card)
            .without(HomeSharedEntrySources.rooms);
    final HomeSharedEntrySectionSetting loaded =
        HomeSharedEntrySectionSetting.fromMap(section.toMap());
    expect(loaded.cardOrder, isEmpty);
    expect(
      loaded.cards[HomeSharedEntrySources.rooms]?.recentImageAssetIds,
      card.recentImageAssetIds,
    );
    expect(loaded.cards[HomeSharedEntrySources.rooms]?.imageAssetId, 'img-a');
  });

  testWidgets('加入小卡可多選，取消不套用，移出後設定仍在', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeSharedEntrySectionSetting setting =
        const HomeSharedEntrySectionSetting(
          enabled: true,
          cardOrder: <String>['rooms'],
        ).updateCard(
          HomeSharedEntrySources.rooms,
          const HomeSharedEntryCardSetting(
            title: '住宿',
            subtitle: '舒適安心',
            imageAssetId: 'img-a',
          ),
        );
    int changes = 0;
    Future<void> pumpCard() {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SharedEntrySettingsCard(
                setting: setting,
                cards: <SharedEntryCardRef>[
                  for (final String id in setting.cardOrder)
                    SharedEntryCardRef(
                      id: id,
                      label: HomeSharedEntrySources.label(id),
                    ),
                ],
                onChanged: (HomeSharedEntrySectionSetting next) {
                  changes += 1;
                  setting = next;
                },
                assetLookup: (String id) async => null,
              ),
            ),
          ),
        ),
      );
    }

    await pumpCard();
    await tester.tap(find.text('排列'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('shared-entry-add')));
    await tester.tap(find.byKey(const Key('shared-entry-add')));
    await tester.pumpAndSettle();
    expect(find.text('已加入'), findsOneWidget);
    expect(find.text('已選 1 張'), findsOneWidget);
    for (final String id in <String>['facilities', 'about', 'announcements']) {
      await tester.ensureVisible(find.byKey(Key('shared-entry-option-$id')));
      await tester.tap(find.byKey(Key('shared-entry-option-$id')));
      await tester.pump();
    }
    expect(find.text('已選 4 張'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared-entry-add-cancel')));
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(setting.cardOrder, <String>['rooms']);

    await tester.tap(find.byKey(const Key('shared-entry-add')));
    await tester.pumpAndSettle();
    for (final String id in <String>['facilities', 'about', 'announcements']) {
      await tester.ensureVisible(find.byKey(Key('shared-entry-option-$id')));
      await tester.tap(find.byKey(Key('shared-entry-option-$id')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('shared-entry-add-apply')));
    await tester.pumpAndSettle();
    expect(setting.cardOrder, <String>[
      'rooms',
      'facilities',
      'about',
      'announcements',
    ]);
    await pumpCard();
    await tester.pumpAndSettle();
    final Finder layoutTab = find.widgetWithText(ChoiceChip, '排列');
    await tester.ensureVisible(layoutTab);
    await tester.tap(layoutTab);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('shared-entry-add')));
    await tester.tap(find.byKey(const Key('shared-entry-add')));
    await tester.pumpAndSettle();
    final CheckboxListTile roomTile = tester.widget<CheckboxListTile>(
      find.byKey(const Key('shared-entry-option-rooms')),
    );
    expect(roomTile.value, isTrue);
    await tester.tap(find.byKey(const Key('shared-entry-add-cancel')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('shared-entry-remove-rooms')),
    );
    await tester.tap(find.byKey(const Key('shared-entry-remove-rooms')));
    await tester.pump();
    expect(setting.cardOrder.contains('rooms'), isFalse);
    expect(setting.cards['rooms']?.title, '住宿');
    expect(setting.cards['rooms']?.imageAssetId, 'img-a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('編輯小卡完成才寫入最近使用，取消則保留原設定', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HomeSharedEntrySectionSetting setting =
        const HomeSharedEntrySectionSetting(
          enabled: true,
          cardOrder: <String>['rooms'],
        ).updateCard(
          HomeSharedEntrySources.rooms,
          const HomeSharedEntryCardSetting(
            title: '住宿',
            subtitle: '舒適安心',
            imageAssetId: 'img-a',
            recentImageAssetIds: <String>['img-a', 'img-b'],
          ),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SharedEntrySettingsCard(
              setting: setting,
              cards: const <SharedEntryCardRef>[
                SharedEntryCardRef(id: 'rooms', label: '房型介紹'),
              ],
              onChanged: (HomeSharedEntrySectionSetting next) {
                setting = next;
              },
              assetLookup: (String id) async => null,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('排列'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('shared-entry-edit-rooms')),
    );
    await tester.tap(find.byKey(const Key('shared-entry-edit-rooms')));
    await tester.pumpAndSettle();
    expect(find.text('尚無最近使用的圖片'), findsNothing);
    expect(find.text('最近使用'), findsOneWidget);
    expect(find.text('主標題顏色'), findsOneWidget);
    expect(find.text('清除目前圖片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared-entry-recent-img-b')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shared-entry-edit-cancel')));
    await tester.pumpAndSettle();
    expect(setting.cardOf('rooms').imageAssetId, 'img-a');
    expect(setting.cardOf('rooms').recentImageAssetIds, <String>[
      'img-a',
      'img-b',
    ]);

    await tester.tap(find.byKey(const Key('shared-entry-edit-rooms')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shared-entry-recent-img-b')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shared-entry-edit-done')));
    await tester.pumpAndSettle();
    expect(setting.cardOf('rooms').imageAssetId, 'img-b');
    expect(setting.cardOf('rooms').title, '住宿');
    expect(setting.cardOf('rooms').subtitle, '舒適安心');
    expect(setting.cardOf('rooms').recentImageAssetIds.first, 'img-b');
    expect(setting.cardOf('rooms').recentImageAssetIds, <String>[
      'img-b',
      'img-a',
    ]);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SharedEntrySettingsCard(
              setting: setting,
              cards: const <SharedEntryCardRef>[
                SharedEntryCardRef(id: 'rooms', label: '房型介紹'),
              ],
              onChanged: (HomeSharedEntrySectionSetting next) {
                setting = next;
              },
              assetLookup: (String id) async => null,
            ),
          ),
        ),
      ),
    );
    final Finder layoutTab = find.widgetWithText(ChoiceChip, '排列');
    await tester.ensureVisible(layoutTab);
    await tester.tap(layoutTab);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('shared-entry-edit-rooms')),
    );
    await tester.tap(find.byKey(const Key('shared-entry-edit-rooms')));
    await tester.pumpAndSettle();
    expect(find.text('清除目前圖片'), findsOneWidget);
    expect(find.byKey(const Key('shared-entry-edit-done')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
