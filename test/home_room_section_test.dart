import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_room_section.dart';
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
    expect(setting.mixed.defaultCardSize, HomeRoomCardSizes.half);
    expect(setting.showPrice, isTrue);
    expect(setting.title, '房型介紹');
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
    expect(twoColumns.mixed.defaultCardSize, HomeRoomCardSizes.half);
    expect(twoColumns.mixed.sizeOf('new'), HomeRoomCardSizes.half);
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
    expect(oneColumn.mixed.defaultCardSize, HomeRoomCardSizes.full);
    expect(oneColumn.mixed.sizeOf('room'), HomeRoomCardSizes.full);

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
    expect(mixed.mixed.sizeOf('vip'), HomeRoomCardSizes.full);
    expect(mixed.mixed.sizeOf('other'), HomeRoomCardSizes.half);
    expect(mixed.mixed.textPlacement, HomeRoomMixedTextPlacements.overlay);

    final HomeRoomSectionSetting scrolled = mixed.copyWith(
      layout: HomeRoomSectionLayouts.horizontalScroll,
    );
    final HomeRoomSectionSetting back = HomeRoomSectionSetting.fromMap(
      scrolled.toMap(),
    );
    expect(back.layout, HomeRoomSectionLayouts.horizontalScroll);
    expect(back.mixed.sizeOf('vip'), HomeRoomCardSizes.full);
    expect(back.simple.subtitle, '查看住宿空間與價格');
    expect(back.toMap()['layout'], 'horizontalScroll');
    expect(back.toMap().containsKey('cardGrid'), isTrue);
    expect(back.toMap().containsKey('compact'), isFalse);
  });

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
      roomIds: <String>['vip', 'standard', 'deluxe'],
      sizeOf: (String id) =>
          id == 'vip' ? HomeRoomCardSizes.full : HomeRoomCardSizes.half,
    );
    expect(rows[0].single.roomTypeId, 'vip');
    expect(rows[0].single.fullWidth, isTrue);
    expect(
      rows[1].map((HomeRoomSlot slot) => slot.roomTypeId).toList(),
      <String?>['standard', 'deluxe'],
    );
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
            'vip': HomeRoomCardSizes.full,
            'sun': HomeRoomCardSizes.half,
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
          itemSizes: <String, String>{'a': HomeRoomCardSizes.full},
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
    HomeRoomSectionSetting? updated;
    final Map<String, dynamic> first = _room('a', '標準房', published: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 640,
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
    await tester.tap(find.text('房型排序'));
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

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(updated?.hiddenRoomTypeIds, isNotEmpty);
    expect(first['isPublished'], isTrue);
  });
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
