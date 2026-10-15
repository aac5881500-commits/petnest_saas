import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_section_order.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_room_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_layout_preview.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/room_section_settings_panel.dart';

Map<String, dynamic> _room(
  String id,
  String name, {
  int price = 1200,
  bool? published,
  List<String> images = const <String>[],
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'price': price,
    'images': images,
    'isPublished': ?published,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing or unknown roomSection uses horizontal scroll', () {
    final HomeRoomSectionSetting setting = HomeRoomSectionSetting.fromMap(null);
    expect(setting.layout, HomeRoomSectionLayouts.horizontalScroll);
    expect(setting.mixed.defaultCardSize, HomeRoomCardSizes.small);
    expect(setting.showPrice, isTrue);
    expect(setting.title, '房型介紹');
    expect(setting.fontFamily, isEmpty);
    expect(setting.appliedFontFamily, isNull);
    expect(setting.fallbackCoverAssetId, isEmpty);
    expect(setting.roomTypeOrder, isEmpty);
    expect(setting.simple.subtitle, '查看住宿空間與價格');

    final HomeRoomSectionSetting broken = HomeRoomSectionSetting.fromMap(
      <String, dynamic>{
        'layout': 12,
        'showPrice': 'yes',
        'compact': 'bad',
        'roomTypeOrder': <Object>[1, 1, ''],
      },
    );
    expect(broken.layout, HomeRoomSectionLayouts.horizontalScroll);
    expect(broken.showPrice, isTrue);
    expect(broken.roomTypeOrder, <String>['1']);
    expect(
      HomeRoomSectionLayouts.migrate('horizontal'),
      HomeRoomSectionLayouts.horizontalScroll,
    );
  });

  test('old card layouts migrate into card grid and keep their details', () {
    final HomeRoomSectionSetting twoColumns = HomeRoomSectionSetting.fromMap(
      <String, dynamic>{
        'layout': 'compactCards',
        'compact': <String, dynamic>{
          'columns': 2,
          'imageHeight': 'tall',
          'allRoomsPlacement': 'titleRight',
        },
        'simple': <String, dynamic>{'subtitle': '保留副標'},
      },
    );
    expect(twoColumns.layout, HomeRoomSectionLayouts.cardGrid);
    expect(twoColumns.mixed.defaultCardSize, HomeRoomCardSizes.small);
    expect(twoColumns.mixed.sizeOf('new'), HomeRoomCardSizes.small);
    expect(twoColumns.mixed.smallImageHeight, HomeRoomImageHeights.tall);
    expect(
      twoColumns.compact.allRoomsPlacement,
      HomeRoomAllRoomsPlacements.titleRight,
    );

    final HomeRoomSectionSetting oneColumn = HomeRoomSectionSetting.fromMap(
      <String, dynamic>{
        'layout': 'compactCards',
        'compact': <String, dynamic>{'columns': 1},
      },
    );
    expect(oneColumn.layout, HomeRoomSectionLayouts.cardGrid);
    expect(oneColumn.mixed.defaultCardSize, HomeRoomCardSizes.single);
    expect(oneColumn.mixed.sizeOf('room'), HomeRoomCardSizes.single);

    final HomeRoomSectionSetting mixed = HomeRoomSectionSetting.fromMap(
      <String, dynamic>{
        'layout': 'mixedGrid',
        'mixed': <String, dynamic>{
          'textPlacement': 'overlay',
          'itemSizes': <String, String>{'vip': 'full'},
        },
      },
    );
    expect(mixed.layout, HomeRoomSectionLayouts.cardGrid);
    expect(mixed.mixed.sizeOf('vip'), HomeRoomCardSizes.single);
    expect(mixed.mixed.sizeOf('other'), HomeRoomCardSizes.small);
    expect(mixed.mixed.sizeOf('missing'), HomeRoomCardSizes.small);
    final HomeRoomMixedSetting legacySizes = HomeRoomSectionSetting.fromMap(
      <String, dynamic>{
        'layout': 'cardGrid',
        'cardGrid': <String, dynamic>{
          'itemSizes': <String, String>{
            'a': 'half',
            'b': 'full',
            'c': 'wide',
            'd': 'nope',
          },
        },
      },
    ).mixed;
    expect(legacySizes.sizeOf('a'), HomeRoomCardSizes.small);
    expect(legacySizes.sizeOf('b'), HomeRoomCardSizes.single);
    expect(legacySizes.sizeOf('c'), HomeRoomCardSizes.wide);
    expect(legacySizes.sizeOf('d'), HomeRoomCardSizes.small);
    expect(legacySizes.toMap()['itemSizes'], <String, String>{
      'a': 'small',
      'b': 'single',
      'c': 'wide',
      'd': 'small',
    });
    expect(mixed.mixed.textPlacement, HomeRoomMixedTextPlacements.overlay);

    final HomeRoomSectionSetting scrolled = mixed.copyWith(
      layout: HomeRoomSectionLayouts.horizontalScroll,
    );
    final HomeRoomSectionSetting back = HomeRoomSectionSetting.fromMap(
      scrolled.toMap(),
    );
    expect(back.layout, HomeRoomSectionLayouts.horizontalScroll);
    expect(back.mixed.sizeOf('vip'), HomeRoomCardSizes.single);
    expect((back.toMap()['cardGrid'] as Map)['itemSizes'], <String, String>{
      'vip': 'single',
    });
    expect(back.simple.subtitle, '查看住宿空間與價格');
    expect(back.toMap()['layout'], 'horizontalScroll');
    expect(back.toMap().containsKey('cardGrid'), isTrue);
    expect(back.toMap().containsKey('compact'), isFalse);
  });

  test(
    'refined layout and font survive a round trip without clearing order',
    () {
      final HomeRoomSectionSetting stored = HomeRoomSectionSetting.fromMap(
        <String, dynamic>{
          'layout': 'refinedCards',
          'fontFamily': 'NotoSansTC',
          'fallbackCoverAssetId': 'asset-1',
          'roomTypeOrder': <String>['b', 'a'],
          'hiddenRoomTypeIds': <String>['c'],
          'showPrice': false,
          'cardGrid': <String, dynamic>{
            'itemSizes': <String, String>{'a': 'wide'},
          },
        },
      );
      expect(stored.layout, HomeRoomSectionLayouts.refinedCards);
      expect(stored.fontFamily, 'NotoSansTC');
      expect(stored.fallbackCoverAssetId, 'asset-1');
      expect(stored.roomTypeOrder, <String>['b', 'a']);
      expect(stored.showPrice, isFalse);
      expect(stored.mixed.sizeOf('a'), HomeRoomCardSizes.wide);

      final HomeRoomSectionSetting switched = stored.copyWith(
        layout: HomeRoomSectionLayouts.cardGrid,
      );
      expect(switched.fontFamily, 'NotoSansTC');
      expect(switched.fallbackCoverAssetId, 'asset-1');
      expect(switched.roomTypeOrder, <String>['b', 'a']);
      expect(switched.mixed.sizeOf('a'), HomeRoomCardSizes.wide);

      final HomeRoomSectionSetting unknown =
          HomeRoomSectionSetting.fromMap(<String, dynamic>{
            'layout': 'not-a-layout',
            'fontFamily': 'ComicSans',
            'fallbackCoverAssetId': 'bad/id',
          });
      expect(unknown.layout, HomeRoomSectionLayouts.horizontalScroll);
      expect(unknown.fontFamily, isEmpty);
      expect(unknown.fallbackCoverAssetId, isEmpty);
    },
  );

  test('order drops duplicates and deleted ids, and appends new rooms', () {
    expect(
      HomeRoomSectionSetting.normalizeOrder(
        saved: <String>['a', 'a', 'gone', 'b'],
        knownIds: <String>['a', 'b', 'c'],
      ),
      <String>['a', 'b', 'c'],
    );
  });

  test('unpublished rooms keep their slot and return when published again', () {
    final List<Map<String, dynamic>> rooms = <Map<String, dynamic>>[
      _room('a', '標準房'),
      _room('b', '豪華房', published: false),
      _room('c', '陽光房'),
    ];
    const HomeRoomSectionSetting setting = HomeRoomSectionSetting(
      roomTypeOrder: <String>['a', 'b', 'c'],
    );
    expect(setting.homeRoomIds(rooms), <String>['a', 'c']);
    expect(setting.orderedIds(rooms), <String>['a', 'b', 'c']);
    expect(
      setting.homeRoomIds(<Map<String, dynamic>>[
        _room('a', '標準房'),
        _room('b', '豪華房', published: true),
        _room('c', '陽光房'),
      ]),
      <String>['a', 'b', 'c'],
    );
  });

  test('reorder keeps hidden unpublished slots and applies the new index', () {
    final List<String> moved = HomeRoomSectionSetting.reorder(
      saved: <String>['a', 'b', 'c'],
      visible: <String>['a', 'c'],
      oldIndex: 0,
      newIndex: 2,
    );
    expect(moved, <String>['c', 'b', 'a']);
  });

  test('hiding a homepage room does not change isPublished', () {
    final Map<String, dynamic> room = _room('a', '標準房', published: true);
    final HomeRoomSectionSetting hidden = const HomeRoomSectionSetting()
        .copyWith(hiddenRoomTypeIds: <String>['a']);
    expect(room['isPublished'], isTrue);
    expect(hidden.toMap().containsKey('isPublished'), isFalse);
    expect(hidden.homeRoomIds(<Map<String, dynamic>>[room]), isEmpty);
    expect(hidden.publishedIds(<Map<String, dynamic>>[room]), <String>['a']);
  });

  test('deleted room ids are ignored without throwing', () {
    const HomeRoomSectionSetting setting = HomeRoomSectionSetting(
      roomTypeOrder: <String>['gone', 'a'],
    );
    expect(
      setting.homeRoomIds(<Map<String, dynamic>>[_room('a', '標準房')]),
      <String>['a'],
    );
  });

  test('mixed rows place a full card alone and pair two half cards', () {
    final List<List<HomeRoomSlot>> rows = HomeRoomSectionSetting.mixedRows(
      roomIds: <String>['vip', 'standard', 'deluxe', 'family'],
      sizeOf: (String id) {
        if (id == 'vip') {
          return HomeRoomCardSizes.wide;
        }
        if (id == 'family') {
          return HomeRoomCardSizes.single;
        }
        return HomeRoomCardSizes.small;
      },
    );
    expect(rows[0].single.roomTypeId, 'vip');
    expect(rows[0].single.size, HomeRoomCardSizes.wide);
    expect(rows[0].single.fullWidth, isTrue);
    expect(
      rows[1].map((HomeRoomSlot slot) => slot.roomTypeId).toList(),
      <String?>['standard', 'deluxe'],
    );
    expect(rows[2].single.roomTypeId, 'family');
    expect(rows[2].single.size, HomeRoomCardSizes.single);
    expect(rows[2].single.fullWidth, isTrue);
  });

  test('a leftover half card is paired with the all-rooms entry once', () {
    final List<List<HomeRoomSlot>> rows = HomeRoomSectionSetting.mixedRows(
      roomIds: <String>['only'],
      sizeOf: (_) => HomeRoomCardSizes.half,
    );
    expect(rows, hasLength(1));
    expect(rows.single[0].roomTypeId, 'only');
    expect(rows.single[1].allRooms, isTrue);
    expect(
      rows
          .expand((List<HomeRoomSlot> row) => row)
          .where((HomeRoomSlot slot) => slot.allRooms),
      hasLength(1),
    );
  });

  testWidgets('horizontal cards stay narrow enough to show the next card', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 320,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.horizontalScroll,
      ),
      rooms: <Map<String, dynamic>>[
        _room('a', '標準房', price: 1800),
        _room('b', '豪華房', price: 2200),
        _room('c', '陽光房'),
      ],
    );
    expect(find.byKey(const Key('home-room-scroll')), findsOneWidget);
    expect(find.text('NT\$1800／晚起'), findsOneWidget);
    expect(find.textContaining('天起'), findsNothing);
    final Size first = tester.getSize(
      find.byKey(const Key('home-room-card-a')),
    );
    final double secondLeft = tester
        .getTopLeft(find.byKey(const Key('home-room-card-b')))
        .dx;
    expect(first.width, lessThan(200));
    expect(secondLeft, greaterThan(first.width));
    expect(secondLeft, lessThan(320));
    await tester.drag(
      find.byKey(const Key('home-room-scroll')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-room-all')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mouse drag scrolls horizontal rooms and a click still opens', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[1100, 500]) {
      Map<String, dynamic>? opened;
      await _pumpSection(
        tester,
        width: width,
        preview: false,
        setting: const HomeRoomSectionSetting(
          layout: HomeRoomSectionLayouts.horizontalScroll,
        ),
        rooms: <Map<String, dynamic>>[
          _room('a', '標準房', price: 1800),
          _room('b', '豪華房', price: 2200),
          _room('c', '陽光房'),
          _room('d', '景觀房'),
          _room('e', '家庭房'),
          _room('f', '套房'),
          _room('g', '雅房'),
          _room('h', '景觀套房'),
        ],
        onOpenRoom: (Map<String, dynamic> room) => opened = room,
      );
      final Finder scroll = find.byKey(const Key('home-room-scroll'));
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, 0);

      await tester.drag(
        scroll,
        const Offset(-140, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(scrollable.position.pixels, greaterThan(20));
      final double afterLeft = scrollable.position.pixels;

      await tester.drag(
        scroll,
        const Offset(80, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(scrollable.position.pixels, lessThan(afterLeft));

      await tester.drag(
        scroll,
        const Offset(2000, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(tester.takeException(), isNull);

      await tester.drag(
        scroll,
        const Offset(-4000, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        scrollable.position.pixels,
        closeTo(scrollable.position.maxScrollExtent, 0.5),
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        scroll,
        const Offset(4000, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);

      await tester.tap(
        find.byKey(const Key('home-room-card-a')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(opened?['id'], 'a');
      opened = null;
    }
  });

  testWidgets('card grid pairs halves and does not stretch a leftover half', (
    WidgetTester tester,
  ) async {
    const HomeRoomSectionSetting grid = HomeRoomSectionSetting(
      layout: HomeRoomSectionLayouts.cardGrid,
    );
    await _pumpSection(
      tester,
      width: 320,
      setting: grid,
      rooms: <Map<String, dynamic>>[
        _room('a', '標準房', price: 1800),
        _room('b', '豪華房', price: 2200),
      ],
    );
    final Size first = tester.getSize(
      find.byKey(const Key('home-room-card-a')),
    );
    final Size second = tester.getSize(
      find.byKey(const Key('home-room-card-b')),
    );
    expect(first.height, second.height);
    expect(first.width, second.width);
    expect(first.width, lessThan(180));
    expect(find.byKey(const Key('home-room-all')), findsNothing);

    await _pumpSection(
      tester,
      width: 320,
      setting: grid.copyWith(
        compact: const HomeRoomCompactSetting(
          allRoomsPlacement: HomeRoomAllRoomsPlacements.titleRight,
        ),
      ),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
    );
    expect(find.byKey(const Key('home-room-all')), findsNothing);
    expect(find.text('全部房型'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home-room-card-a'))).width,
      lessThan(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple entry does not build individual room cards', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 320,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
      ),
      rooms: <Map<String, dynamic>>[_room('a', '標準房'), _room('b', '豪華房')],
    );
    expect(find.byKey(const Key('home-room-simple')), findsOneWidget);
    expect(find.text('房型介紹'), findsOneWidget);
    expect(find.text('查看住宿空間與價格'), findsOneWidget);
    expect(find.text('標準房'), findsNothing);
    expect(find.text('NT\$1200／晚起'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed grid renders full cards, paired cards, and one filler', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 360,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.cardGrid,
        mixed: HomeRoomMixedSetting(
          itemSizes: <String, String>{
            'vip': HomeRoomCardSizes.single,
            'sun': HomeRoomCardSizes.small,
          },
        ),
      ),
      rooms: <Map<String, dynamic>>[
        _room('vip', 'VIP景觀房'),
        _room('standard', '標準房'),
        _room('deluxe', '豪華房'),
        _room('sun', '陽光房'),
      ],
    );
    final double vipTop = tester
        .getTopLeft(find.byKey(const Key('home-room-card-vip')))
        .dy;
    final double standardTop = tester
        .getTopLeft(find.byKey(const Key('home-room-card-standard')))
        .dy;
    final double deluxeTop = tester
        .getTopLeft(find.byKey(const Key('home-room-card-deluxe')))
        .dy;
    final double sunTop = tester
        .getTopLeft(find.byKey(const Key('home-room-card-sun')))
        .dy;
    expect(standardTop, deluxeTop);
    expect(vipTop, lessThan(standardTop));
    expect(sunTop, greaterThan(standardTop));
    expect(
      tester.getSize(find.byKey(const Key('home-room-card-vip'))).width,
      greaterThan(
        tester.getSize(find.byKey(const Key('home-room-card-standard'))).width *
            1.5,
      ),
    );
    expect(find.byKey(const Key('home-room-all')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-room-all'))).dy,
      sunTop,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live home hides the section when nothing is published', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 320,
      preview: false,
      setting: const HomeRoomSectionSetting(),
      rooms: <Map<String, dynamic>>[_room('a', '標準房', published: false)],
    );
    expect(find.text('標準房'), findsNothing);
    expect(find.text('目前尚未建立已發布房型'), findsNothing);
    expect(find.byKey(const Key('home-room-empty-preview')), findsNothing);
  });

  testWidgets('preview explains when no room is published and live navigates', (
    WidgetTester tester,
  ) async {
    String? selected;
    Map<String, dynamic>? opened;
    var openedAll = false;
    await _pumpSection(
      tester,
      width: 320,
      preview: true,
      setting: const HomeRoomSectionSetting(),
      rooms: const <Map<String, dynamic>>[],
      onSelectRoomType: (String id) => selected = id,
    );
    expect(find.text('目前尚未建立已發布房型'), findsOneWidget);
    expect(find.text('前往房型管理'), findsOneWidget);

    await _pumpSection(
      tester,
      width: 320,
      preview: true,
      setting: const HomeRoomSectionSetting(),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
      onSelectRoomType: (String id) => selected = id,
      onOpenRoom: (Map<String, dynamic> room) => opened = room,
    );
    await tester.tap(find.byKey(const Key('home-room-card-a')));
    await tester.pump();
    expect(selected, 'a');
    expect(opened, isNull);

    await _pumpSection(
      tester,
      width: 320,
      preview: false,
      setting: const HomeRoomSectionSetting(),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
      onOpenRoom: (Map<String, dynamic> room) => opened = room,
      onOpenAllRooms: () => openedAll = true,
    );
    await tester.tap(find.byKey(const Key('home-room-card-a')));
    await tester.pump();
    expect(opened?['id'], 'a');
    await tester.tap(find.byKey(const Key('home-room-all')));
    await tester.pump();
    expect(openedAll, isTrue);
  });

  testWidgets('a failed image still shows the bed icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeRoomCover(
            imageUrl: '',
            height: 80,
            theme: HomeThemeModel.modernDefault,
            imageProvider: const _FailingImage(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('home-room-fallback-icon')), findsOneWidget);
    tester.takeException();
  });

  testWidgets('refined cards use room data and the shared font', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? opened;
    await _pumpSection(
      tester,
      width: 390,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.refinedCards,
        fontFamily: 'NotoSerifTC',
        showPrice: true,
      ),
      rooms: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a',
          'name': '景觀房',
          'price': 3200,
          'description': '含早餐',
          'images': <String>[],
        },
        _room('b', '標準房', price: 1800),
      ],
      onOpenRoom: (Map<String, dynamic> room) => opened = room,
    );
    expect(find.byKey(const Key('home-room-refined')), findsOneWidget);
    expect(find.text('景觀房'), findsOneWidget);
    expect(find.text('NT\$3200／晚起'), findsOneWidget);
    expect(find.text('含早餐'), findsOneWidget);
    expect(find.text('查看詳情'), findsWidgets);
    TextStyle effective(String label) {
      final Text text = tester.widget<Text>(find.text(label).first);
      final BuildContext context = tester.element(find.text(label).first);
      return DefaultTextStyle.of(context).style.merge(text.style);
    }

    expect(effective('景觀房').fontFamily, 'NotoSerifTC');
    expect(effective('NT\$3200／晚起').fontFamily, 'NotoSerifTC');
    expect(effective('含早餐').fontFamily, 'NotoSerifTC');
    expect(effective('查看詳情').fontFamily, 'NotoSerifTC');
    final double first = tester.getTopLeft(find.text('景觀房')).dx;
    final double second = tester.getTopLeft(find.text('標準房')).dx;
    expect(second, greaterThan(first));
    expect(second, lessThan(390));
    await tester.tap(find.byKey(const Key('home-room-card-a')));
    await tester.pump();
    expect(opened?['id'], 'a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared font applies to horizontal cards and the simple entry', (
    WidgetTester tester,
  ) async {
    TextStyle effective(String label) {
      final Text text = tester.widget<Text>(find.text(label).first);
      final BuildContext context = tester.element(find.text(label).first);
      return DefaultTextStyle.of(context).style.merge(text.style);
    }

    await _pumpSection(
      tester,
      width: 390,
      setting: const HomeRoomSectionSetting(fontFamily: 'KleeOne'),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
    );
    expect(effective('房型介紹').fontFamily, 'KleeOne');
    expect(effective('標準房').fontFamily, 'KleeOne');

    await _pumpSection(
      tester,
      width: 390,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
        fontFamily: 'ChironSungHK',
        title: '住宿空間',
      ),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
    );
    expect(effective('住宿空間').fontFamily, 'ChironSungHK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('other layouts keep room photos and ignore the entry image', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 390,
      simpleImageUrl: 'https://example.com/gallery.jpg',
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.horizontalScroll,
      ),
      rooms: <Map<String, dynamic>>[
        _room('a', '有照片', images: <String>['https://example.com/own.jpg']),
        _room('b', '沒照片'),
      ],
    );
    final List<String> urls = _networkUrls(tester);
    expect(urls, contains('https://example.com/own.jpg'));
    expect(urls, isNot(contains('https://example.com/gallery.jpg')));
    expect(find.byKey(const Key('home-room-fallback-icon')), findsWidgets);
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();
  });

  testWidgets('simple entry uses the gallery image and not room photos', (
    WidgetTester tester,
  ) async {
    bool opened = false;
    await _pumpSection(
      tester,
      width: 360,
      simpleImageUrl: 'https://example.com/gallery.jpg',
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
        title: '觀看房型',
        fontFamily: 'NotoSansTC',
        simple: HomeRoomSimpleSetting(
          subtitle: '探索舒適住宿空間',
          showSubtitle: true,
          textMode: HomeRoomSimpleTextModes.caption,
          aspect: HomeRoomSimpleAspects.portrait,
        ),
      ),
      rooms: <Map<String, dynamic>>[
        _room('a', '標準房', images: <String>['https://example.com/own.jpg']),
      ],
      onOpenAllRooms: () => opened = true,
    );
    final List<String> urls = _networkUrls(tester);
    expect(urls, <String>['https://example.com/gallery.jpg']);
    expect(find.text('觀看房型'), findsOneWidget);
    expect(find.text('探索舒適住宿空間'), findsOneWidget);
    expect(find.text('標準房'), findsNothing);
    final Text title = tester.widget<Text>(find.text('觀看房型'));
    final BuildContext context = tester.element(find.text('觀看房型'));
    expect(
      DefaultTextStyle.of(context).style.merge(title.style).fontFamily,
      'NotoSansTC',
    );
    final Rect image = tester.getRect(
      find.byKey(const Key('refined-entry-image')),
    );
    final double titleTop = tester.getTopLeft(find.text('觀看房型')).dy;
    expect(titleTop, greaterThan(image.top));
    expect(titleTop, lessThan(image.bottom));
    await tester.tap(find.byKey(const Key('home-room-simple')));
    await tester.pump();
    expect(opened, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();

    await _pumpSection(
      tester,
      width: 320,
      textScale: 1.3,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
        title: '很長的觀看房型標題用來確認不會溢出',
        simple: HomeRoomSimpleSetting(
          textMode: HomeRoomSimpleTextModes.below,
          subtitle: '副標也要收成一行',
        ),
      ),
      rooms: <Map<String, dynamic>>[_room('a', '標準房')],
      simpleImageUrl: 'https://example.com/gallery.jpg',
    );
    final Rect belowImage = tester.getRect(
      find.byKey(const Key('refined-entry-image')),
    );
    expect(
      tester.getTopLeft(find.text('很長的觀看房型標題用來確認不會溢出')).dy,
      greaterThan(belowImage.bottom - 1),
    );
    await tester.pump(const Duration(milliseconds: 50));
    Object? error = tester.takeException();
    while (error != null) {
      expect('$error', isNot(contains('A RenderFlex overflowed')));
      error = tester.takeException();
    }
  });

  testWidgets('independent simple entry keeps its own width', (
    WidgetTester tester,
  ) async {
    Future<Size> measure(int columns) async {
      await _pumpSection(
        tester,
        width: 360,
        simpleImageUrl: 'https://example.com/gallery.jpg',
        setting: HomeRoomSectionSetting(
          layout: HomeRoomSectionLayouts.simpleEntry,
          title: '觀看房型',
          simple: HomeRoomSimpleSetting(
            columns: columns,
            aspect: HomeRoomSimpleAspects.square,
            textMode: HomeRoomSimpleTextModes.below,
            subtitle: '探索空間',
          ),
        ),
        rooms: <Map<String, dynamic>>[_room('a', '標準房')],
      );
      final Size card = tester.getSize(
        find.byKey(const Key('home-room-simple')),
      );
      await tester.pump(const Duration(milliseconds: 50));
      Object? failure = tester.takeException();
      while (failure != null) {
        expect('$failure', isNot(contains('A RenderFlex overflowed')));
        failure = tester.takeException();
      }
      return card;
    }

    final Size two = await measure(2);
    final Size four = await measure(4);
    expect(two.width, greaterThan(220));
    expect(two.width, four.width);
    expect(two.height, four.height);
  });

  testWidgets('image selection disables only the fallback icon', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    HomeRoomSectionSetting setting = const HomeRoomSectionSetting(
      layout: HomeRoomSectionLayouts.simpleEntry,
      simple: HomeRoomSimpleSetting(
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
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return RoomSectionSettingsPanel(
                  shopId: 'shop',
                  setting: setting,
                  theme: HomeThemeModel.modernDefault,
                  rooms: <Map<String, dynamic>>[_room('a', '標準房')],
                  onChanged: (HomeRoomSectionSetting next) {
                    setState(() => setting = next);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(
      find.text('已使用圖片，移除圖片後可設定預設圖示。', skipOffstage: false),
      findsOneWidget,
    );
    final Finder iconLabel = find.text('寵物旅館', skipOffstage: false);
    final Iterable<Opacity> faded = tester.widgetList<Opacity>(
      find.ancestor(of: iconLabel, matching: find.byType(Opacity)),
    );
    expect(faded.any((Opacity opacity) => opacity.opacity == 0.45), isTrue);
    await tester.ensureVisible(find.text('清除圖片', skipOffstage: false));
    await tester.tap(find.text('清除圖片'));
    await tester.pumpAndSettle();
    expect(setting.simple.imageAssetId, isEmpty);
    expect(setting.simple.icon, HomeRoomSimpleIcons.hotel);
    expect(find.text('已使用圖片，移除圖片後可設定預設圖示。', skipOffstage: false), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('room-simple-color-ffa56b45'), skipOffstage: false),
    );
    await tester.tap(find.byKey(const Key('room-simple-color-ffa56b45')));
    await tester.pumpAndSettle();
    expect(setting.simple.textColor, HomeRoomSimpleTextColors.custom);
    expect(setting.simple.textColorValue, 0xFFA56B45);
    expect(setting.simple.icon, HomeRoomSimpleIcons.hotel);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text at 320px does not overflow', (
    WidgetTester tester,
  ) async {
    await _pumpSection(
      tester,
      width: 320,
      textScale: 1.4,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.cardGrid,
        mixed: HomeRoomMixedSetting(
          textPlacement: HomeRoomMixedTextPlacements.overlay,
          itemSizes: <String, String>{
            'a': HomeRoomCardSizes.wide,
            'b': HomeRoomCardSizes.single,
          },
        ),
      ),
      rooms: <Map<String, dynamic>>[
        _room('a', '很長的景觀房型名稱用來確認不會爆版'),
        _room('b', '標準房'),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorting the settings list updates the draft order', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    _useTallSurface(tester);
    HomeRoomSectionSetting? updated;
    final Map<String, dynamic> first = _room('a', '標準房', published: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 1200,
            child: RoomSectionSettingsPanel(
              shopId: 'shop',
              theme: HomeThemeModel.modernDefault,
              rooms: <Map<String, dynamic>>[
                first,
                _room('b', '豪華房'),
                _room('c', '陽光房', published: false),
              ],
              setting: const HomeRoomSectionSetting(
                roomTypeOrder: <String>['a', 'b', 'c'],
              ),
              onChanged: (HomeRoomSectionSetting value) => updated = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('陽光房'), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    final TestGesture drag = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('room-drag-a'))),
    );
    await tester.pump(kPressTimeout);
    await drag.moveBy(const Offset(0, 20));
    await tester.pump();
    await drag.moveBy(const Offset(0, 400));
    await tester.pumpAndSettle();
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(updated?.roomTypeOrder, <String>['b', 'a', 'c']);
    debugDefaultTargetPlatformOverride = null;
    expect(updated?.roomTypeOrder, contains('c'));
    expect(first['isPublished'], isTrue);

    await tester.tap(find.byKey(const Key('room-visible-a')));
    await tester.pumpAndSettle();
    expect(updated?.hiddenRoomTypeIds, isNotEmpty);
    expect(first['isPublished'], isTrue);
  });

  testWidgets('horizontal layout diagram fits a wide and a narrow column', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[360, 148]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: const RoomSectionLayoutPreview(
                  layout: HomeRoomSectionLayouts.horizontalScroll,
                  theme: HomeThemeModel.modernDefault,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Size preview = tester.getSize(
        find.byType(RoomSectionLayoutPreview),
      );
      expect(preview.width, width);
      expect(
        find.descendant(
          of: find.byType(RoomSectionLayoutPreview),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('card sizes keep their rows and a wide card stays horizontal', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? opened;
    await _pumpSection(
      tester,
      width: 320,
      textScale: 1.4,
      preview: false,
      setting: const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.cardGrid,
        mixed: HomeRoomMixedSetting(
          itemSizes: <String, String>{
            'vip': HomeRoomCardSizes.wide,
            'standard': HomeRoomCardSizes.small,
            'deluxe': HomeRoomCardSizes.small,
            'family': HomeRoomCardSizes.single,
          },
        ),
      ),
      rooms: <Map<String, dynamic>>[
        _room('vip', 'VIP尊爵房很長的名稱用來確認不會被擠出畫面', price: 3200),
        _room('standard', '舒適標準房', price: 1800),
        _room('deluxe', '陽光景觀房', price: 2200),
        _room('family', '豪華家庭房', price: 2600),
      ],
      onOpenRoom: (Map<String, dynamic> room) => opened = room,
    );
    final Size vip = tester.getSize(
      find.byKey(const Key('home-room-card-vip')),
    );
    final Size standard = tester.getSize(
      find.byKey(const Key('home-room-card-standard')),
    );
    final Size deluxe = tester.getSize(
      find.byKey(const Key('home-room-card-deluxe')),
    );
    final Size family = tester.getSize(
      find.byKey(const Key('home-room-card-family')),
    );
    expect(vip.width, greaterThan(standard.width * 1.5));
    expect(family.width, greaterThan(standard.width * 1.5));
    expect(standard.width, deluxe.width);
    expect(standard.width, lessThan(180));
    expect(
      tester.getTopLeft(find.byKey(const Key('home-room-card-standard'))).dy,
      tester.getTopLeft(find.byKey(const Key('home-room-card-deluxe'))).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('home-room-card-family'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('home-room-card-deluxe'))).dy,
      ),
    );
    expect(find.byKey(const Key('home-room-wide-hint-vip')), findsOneWidget);
    expect(find.byKey(const Key('home-room-wide-hint-family')), findsNothing);
    expect(
      tester.getTopLeft(find.textContaining('VIP尊爵房')).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('home-room-card-vip'))).dx + 40,
      ),
    );
    expect(find.text('NT\$3200／晚起'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-room-card-vip')));
    await tester.pump();
    expect(opened?['id'], 'vip');
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple entry locks ordering without clearing saved sizes', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    HomeRoomSectionSetting setting = const HomeRoomSectionSetting(
      layout: HomeRoomSectionLayouts.cardGrid,
      roomTypeOrder: <String>['a', 'b'],
      hiddenRoomTypeIds: <String>['b'],
      mixed: HomeRoomMixedSetting(
        itemSizes: <String, String>{'a': HomeRoomCardSizes.wide},
      ),
    );
    late StateSetter refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              refresh = setState;
              return SizedBox(
                width: 420,
                height: 1200,
                child: RoomSectionSettingsPanel(
                  shopId: 'shop',
                  theme: HomeThemeModel.modernDefault,
                  rooms: <Map<String, dynamic>>[
                    _room('a', 'VIP尊爵房'),
                    _room('b', '舒適標準房'),
                  ],
                  setting: setting,
                  onChanged: (HomeRoomSectionSetting value) {
                    setState(() => setting = value);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-size-a')), findsOneWidget);

    refresh(() {
      setting = setting.copyWith(layout: HomeRoomSectionLayouts.simpleEntry);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-layout-simpleEntry')), findsOneWidget);
    expect(find.byType(SliverReorderableList), findsNothing);
    expect(find.textContaining('已儲存的排序'), findsOneWidget);
    expect(setting.roomTypeOrder, <String>['a', 'b']);
    expect(setting.hiddenRoomTypeIds, <String>['b']);
    expect(setting.mixed.sizeOf('a'), HomeRoomCardSizes.wide);

    await tester.tap(find.byKey(const Key('room-layout-cardGrid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-size-a')), findsOneWidget);
    expect(setting.mixed.sizeOf('a'), HomeRoomCardSizes.wide);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'room size choices stay on one row when the settings pane is wide',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      HomeRoomSectionSetting? updated;
      Future<void> pump(double width) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 1200,
                child: RoomSectionSettingsPanel(
                  shopId: 'shop',
                  theme: HomeThemeModel.modernDefault,
                  rooms: <Map<String, dynamic>>[
                    _room('a', '標準房'),
                    _room('b', '豪華房'),
                  ],
                  setting: const HomeRoomSectionSetting(
                    layout: HomeRoomSectionLayouts.cardGrid,
                  ),
                  onChanged: (HomeRoomSectionSetting value) => updated = value,
                ),
              ),
            ),
          ),
        );
      }

      await pump(760);
      await tester.pumpAndSettle();
      expect(
        (tester.getTopLeft(find.text('小卡').first).dy -
                tester.getTopLeft(find.text('標準房')).dy)
            .abs(),
        lessThan(36),
      );
      expect(tester.takeException(), isNull);

      await pump(340);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('單卡').first).dy,
        greaterThan(tester.getTopLeft(find.text('標準房')).dy + 20),
      );
      await tester.tap(find.text('長卡').first);
      await tester.pumpAndSettle();
      expect(updated?.mixed.sizeOf('a'), HomeRoomCardSizes.wide);
      expect(tester.takeException(), isNull);
    },
  );

  test('simple card size defaults to wide and round-trips', () {
    final HomeRoomSimpleSetting missing = HomeRoomSimpleSetting.fromMap(
      <String, dynamic>{'subtitle': '舊副標', 'showSubtitle': false},
    );
    expect(missing.cardSize, HomeRoomSimpleCardSizes.wide);
    expect(missing.subtitle, '舊副標');
    expect(missing.showSubtitle, isFalse);
    expect(missing.imageAssetId, isEmpty);
    expect(missing.textMode, HomeRoomSimpleTextModes.below);
    expect(missing.mask, HomeRoomSimpleMasks.none);
    expect(missing.columns, HomeRoomSimpleColumns.three);
    expect(missing.placement, HomeRoomSimplePlacements.independent);

    for (final String size in HomeRoomSimpleCardSizes.all) {
      final HomeRoomSimpleSetting setting = HomeRoomSimpleSetting.fromMap(
        HomeRoomSimpleSetting(
          subtitle: '保留副標',
          icon: HomeRoomSimpleIcons.hotel,
          surface: HomeRoomSimpleSurfaces.outlined,
          cardSize: size,
        ).toMap(),
      );
      expect(setting.cardSize, size);
      expect(setting.subtitle, '保留副標');
      expect(setting.icon, HomeRoomSimpleIcons.hotel);
      expect(setting.surface, HomeRoomSimpleSurfaces.outlined);
    }

    expect(
      HomeRoomSimpleSetting.fromMap(<String, dynamic>{
        'cardSize': 'huge',
      }).cardSize,
      HomeRoomSimpleCardSizes.wide,
    );
    expect(
      HomeRoomSimpleSetting.fromMap(<String, dynamic>{'cardSize': ''}).cardSize,
      HomeRoomSimpleCardSizes.wide,
    );
    expect(
      HomeRoomSimpleSetting.fromMap(<String, dynamic>{'cardSize': 3}).cardSize,
      HomeRoomSimpleCardSizes.wide,
    );

    const HomeRoomSimpleSetting original = HomeRoomSimpleSetting(
      subtitle: '保留副標',
      showSubtitle: false,
      icon: HomeRoomSimpleIcons.home,
      surface: HomeRoomSimpleSurfaces.transparent,
      cardSize: HomeRoomSimpleCardSizes.small,
    );
    final HomeRoomSimpleSetting changed = original.copyWith(
      cardSize: HomeRoomSimpleCardSizes.single,
    );
    expect(changed.cardSize, HomeRoomSimpleCardSizes.single);
    expect(changed.subtitle, '保留副標');
    expect(changed.showSubtitle, isFalse);
    expect(changed.icon, HomeRoomSimpleIcons.home);
    expect(changed.surface, HomeRoomSimpleSurfaces.transparent);

    final HomeRoomSectionSetting restored = HomeRoomSectionSetting.fromMap(
      const HomeRoomSectionSetting(
        layout: HomeRoomSectionLayouts.simpleEntry,
        simple: original,
      ).copyWith(layout: HomeRoomSectionLayouts.cardGrid).toMap(),
    );
    expect(restored.simple.cardSize, HomeRoomSimpleCardSizes.small);
    expect(restored.simple.subtitle, '保留副標');
  });

  test('dragging the rooms section keeps hidden sections in place', () {
    final List<String> saved = HomeSectionOrder.normalize(null);
    final List<String> visible = HomeSectionOrder.visible(
      saved,
      showAnnouncements: false,
    );
    final int rooms = visible.indexOf('rooms');
    final int announcements = saved.indexOf('announcements');
    final List<String> moved = HomeSectionOrder.reorderVisible(
      saved: saved,
      visible: visible,
      oldIndex: rooms,
      newIndex: 0,
    );
    expect(moved.first, 'rooms');
    expect(moved.contains('announcements'), isTrue);
    expect(moved.indexOf('announcements'), announcements);
    expect(moved.toSet(), saved.toSet());
    expect(
      HomeSectionOrder.visible(
        moved,
        showAnnouncements: false,
      ).indexOf('rooms'),
      0,
    );
  });

  testWidgets('simple entry sizes open all rooms without overflow', (
    WidgetTester tester,
  ) async {
    for (final double width in <double>[320, 500, 900]) {
      double? wideHeight;
      double? singleHeight;
      for (final String size in HomeRoomSimpleCardSizes.all) {
        var openedAll = false;
        await _pumpSection(
          tester,
          width: width,
          textScale: 1.3,
          preview: false,
          setting: HomeRoomSectionSetting(
            layout: HomeRoomSectionLayouts.simpleEntry,
            title: '很長的房型介紹標題用來確認最多兩行並且不會爆版',
            simple: HomeRoomSimpleSetting(
              cardSize: size,
              subtitle: '很長的副標題用來確認窄螢幕不會和圖示或箭頭重疊',
            ),
          ),
          rooms: <Map<String, dynamic>>[_room('a', '標準房', price: 1800)],
          onOpenAllRooms: () => openedAll = true,
        );
        expect(find.text('標準房'), findsNothing);
        expect(find.textContaining('晚起'), findsNothing);
        expect(tester.takeException(), isNull);
        final Size card = tester.getSize(
          find.byKey(const Key('home-room-simple')),
        );
        expect(card.width, greaterThan(width * 0.8));
        if (size == HomeRoomSimpleCardSizes.small) {
          expect(
            tester.getTopLeft(find.byKey(const Key('home-room-simple'))).dx,
            lessThan(40),
          );
        }
        if (size == HomeRoomSimpleCardSizes.wide) {
          wideHeight = card.height;
        }
        if (size == HomeRoomSimpleCardSizes.single) {
          singleHeight = card.height;
        }
        await tester.tap(find.byKey(const Key('home-room-simple')));
        await tester.pump();
        expect(openedAll, isTrue);
      }
      expect(singleHeight, isNotNull);
      expect(wideHeight, isNotNull);
      expect(singleHeight!, greaterThan(wideHeight!));
    }
  });

  testWidgets('font choice stays when the room layout changes', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    HomeRoomSectionSetting setting = const HomeRoomSectionSetting(
      roomTypeOrder: <String>['a'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 1200,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return RoomSectionSettingsPanel(
                  shopId: 'shop',
                  setting: setting,
                  theme: HomeThemeModel.modernDefault,
                  rooms: <Map<String, dynamic>>[_room('a', '標準房')],
                  onChanged: (HomeRoomSectionSetting next) {
                    setState(() => setting = next);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('精緻圖片小卡'), findsOneWidget);
    expect(find.text('統一字體'), findsOneWidget);
    expect(find.text('顯示內容'), findsOneWidget);
    expect(find.text('房型排列'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('room-font-family-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noto Sans TC 現代黑體').last);
    await tester.pumpAndSettle();
    expect(setting.fontFamily, 'NotoSansTC');
    expect(setting.layout, HomeRoomSectionLayouts.horizontalScroll);
    await tester.tap(find.byKey(const Key('room-layout-refinedCards')));
    await tester.pumpAndSettle();
    expect(setting.layout, HomeRoomSectionLayouts.refinedCards);
    expect(setting.fontFamily, 'NotoSansTC');
    expect(setting.roomTypeOrder, <String>['a']);
    expect(tester.takeException(), isNull);
  });
}

List<String> _networkUrls(WidgetTester tester) {
  return <String>[
    for (final Image image in tester.widgetList<Image>(find.byType(Image)))
      if (image.image is NetworkImage) (image.image as NetworkImage).url,
  ];
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required double width,
  required HomeRoomSectionSetting setting,
  required List<Map<String, dynamic>> rooms,
  bool preview = false,
  double textScale = 1,
  ValueChanged<String>? onSelectRoomType,
  ValueChanged<Map<String, dynamic>>? onOpenRoom,
  VoidCallback? onOpenAllRooms,
  String simpleImageUrl = '',
}) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ModernHomeRoomSection(
              theme: HomeThemeModel.modernDefault,
              setting: setting,
              roomTypes: rooms,
              preview: preview,
              onSelectRoomType: onSelectRoomType,
              onOpenRoom: onOpenRoom,
              onOpenAllRooms: onOpenAllRooms,
              onManageRooms: () {},
              simpleImageUrl: simpleImageUrl,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('image failed')),
    );
  }
}
