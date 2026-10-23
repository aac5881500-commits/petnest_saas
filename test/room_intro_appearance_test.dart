// 功能：房型內頁外觀相容、列表高度、手機／桌機排版與外觀草稿局部驗證。
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// 沿用現有 Firebase 測試 mock，不新增套件或連線正式資料。
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_list.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_type_detail_content.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_data_stream.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  test('共用資料流回放最新值，僅訂閱來源一次並在離頁釋放', () async {
    int subscriptions = 0, cancellations = 0;
    final source = StreamController<int>(
      onListen: () => subscriptions++,
      onCancel: () => cancellations++,
    );
    final cache = RoomIntroDataStream(source.stream);
    final first = cache.stream.listen((_) {});
    source.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(await cache.stream.first, 7);
    expect(subscriptions, 1);
    await first.cancel();
    cache.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(cancellations, 1);
    await source.close();
  });
  final theme = HomeThemeModel.classicDefault;
  final rooms = <Map<String, dynamic>>[
    {
      'id': 'a',
      'name': '豪華觀景房型，保留完整名稱',
      'price': 1800,
      'capacity': 2,
      'features': ['camera', 'daily_clean'],
      'description': '安靜的獨立空間',
      'images': <String>[],
    },
    {
      'id': 'b',
      'name': '標準房',
      'price': 900,
      'capacity': 1,
      'features': ['private_space'],
      'images': <String>[],
    },
    {
      'id': 'new',
      'name': '新房型',
      'price': 1300,
      'capacity': 1,
      'images': <String>[],
    },
  ];
  testWidgets('旅宿組合只改草稿，儲存兩欄且後續可獨立切換詳細版型', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final updates = <Map<String, dynamic>>[];
    final source = Stream.value(rooms);
    Widget screen(bool detail) => MaterialApp(
      home: Scaffold(
        body: RoomIntroAppearanceScope(
          appearance: const RoomIntroAppearance(),
          theme: theme,
          child: RoomIntroAppearanceEditor(
            shopId: 'test',
            detailMode: detail,
            roomTypesStream: source,
            saveAppearance: (data) async => updates.add(data),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('套用旅宿瀏覽組合'));
    await tester.pumpAndSettle();
    expect(updates, isEmpty);
    await tester.tap(find.text('儲存外觀'));
    await tester.pumpAndSettle();
    expect(
      updates.single['${RoomIntroAppearance.path}.list']['layout'],
      'lodging',
    );
    expect(
      updates.single['${RoomIntroAppearance.path}.detail']['layout'],
      'lodging',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('分頁閱讀'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('room-detail-appearance')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('分頁閱讀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存外觀'));
    await tester.pumpAndSettle();
    expect(updates.last.keys, ['${RoomIntroAppearance.path}.detail']);
    expect(updates.last.values.single['layout'], 'tabs');
    expect(tester.takeException(), isNull);
  });
  testWidgets('新增分頁權限、晚載入資料及切分頁取消離開保留草稿', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopBookingSetupCenterPage(
          shopId: 'test',
          appBarActions: const [],
          loadMember: () async => {
            'role': 'staff',
            'permissions': {ShopPermissionKeys.manageFrontendContent: true},
          },
          shopStream: Stream.value({
            'homeAppearance': {
              'roomIntro': const RoomIntroAppearance().toMap(),
            },
          }),
          roomTypesStream: Stream.value(rooms),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('房型列表外觀'), findsOneWidget);
    expect(find.text('房型詳細頁外觀'), findsOneWidget);
    expect(find.text('預約設定'), findsNothing);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, '頁面標題'),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('room-list-appearance')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.widgetWithText(TextField, '頁面標題'), '共用外觀草稿');
    await tester.pump();
    await tester.tap(find.text('房型詳細頁外觀'));
    await tester.pumpAndSettle();
    expect(find.text('預覽房型'), findsOneWidget);
    await tester.tap(find.text('房型列表外觀'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '頁面標題'))
          .controller!
          .text,
      '共用外觀草稿',
    );
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '頁面標題'))
          .controller!
          .text,
      '共用外觀草稿',
    );
    expect(tester.takeException(), isNull);
  });
  test('兩套外觀完整讀回，舊資料與未知值回退，排序不修改原資料', () {
    const original = RoomIntroAppearance(
      list: RoomListAppearance(
        layout: 'columns',
        title: '全部房型',
        description: '短文',
        showDescription: false,
        imageAspect: 'wide',
        imageFit: 'contain',
        showCapacity: false,
        showFeatures: false,
        spacing: 'wide',
        buttonStyle: 'filled',
        roomOrder: ['b', 'deleted', 'a'],
      ),
      detail: RoomDetailAppearance(
        layout: 'sideBySide',
        imageAspect: 'square',
        imageFit: 'contain',
        showThumbnails: false,
        dimensionsStyle: 'line',
        contentOrder: 'featuresFirst',
        surface: 'pale',
        radius: 'large',
        spacing: 'compact',
      ),
    );
    expect(
      RoomIntroAppearance.fromMap(original.toMap()).toMap(),
      original.toMap(),
    );
    final reloaded = RoomIntroAppearance.fromShop({
      'homeAppearance': {'roomIntro': original.toMap()},
    });
    expect(reloaded.list.ordered(rooms).map((r) => r['id']), ['b', 'a', 'new']);
    expect(rooms.map((r) => r['id']), ['a', 'b', 'new']);
    expect(
      RoomIntroAppearance.fromMap({
        'list': {'layout': 900, 'imageAspect': 'bad', 'imageFit': false},
        'detail': {'layout': 'unknown', 'radius': -8},
      }).toMap(),
      const RoomIntroAppearance().toMap(),
    );
    expect(
      original
          .copyWith(list: original.list.copyWith(layout: 'horizontal'))
          .detail
          .toMap(),
      original.detail.toMap(),
    );
    expect(
      roomPhotoUrls([
        '',
        {'url': 'first'},
        {'imageUrl': 'second'},
      ]),
      ['first', 'second'],
    );
  });

  testWidgets('三種列表在手機、文字放大與桌機自然高度，缺圖仍可開啟', (tester) async {
    int opens = 0;
    for (final width in [360.0, 390.0, 430.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final layout in ['vertical', 'horizontal', 'columns']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoomIntroList(
                  rooms: rooms,
                  setting: RoomListAppearance(layout: layout),
                  theme: theme,
                  onOpen: (_) => opens++,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('room-intro-card-a')))
              .height,
          lessThan(650),
        );
        final button = find.text('查看房型介紹').first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
    expect(opens, 12);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('三種詳細版型隱藏空尺寸、保留部分尺寸與照片切換，按鈕滿寬', (tester) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    for (final width in [360.0, 390.0, 430.0, 1100.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final layout in ['classic', 'compact', 'sideBySide']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoomTypeDetailContent(
                roomType: {
                  ...rooms.first,
                  'width': null,
                  'depth': '',
                  'height': 0,
                },
                theme: theme,
                appearance: RoomDetailAppearance(
                  layout: layout,
                  showThumbnails: false,
                ),
                localImages: [pixel, pixel],
                showChrome: true,
                previewOnly: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('房間尺寸'), findsNothing);
        expect(find.text('—'), findsNothing);
        final firstPhoto = find.text('1 / 2').evaluate().isNotEmpty;
        await tester.ensureVisible(find.byTooltip('下一張照片'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('下一張照片'));
        await tester.pump();
        expect(find.text(firstPhoto ? '2 / 2' : '1 / 2'), findsOneWidget);
        final button = find.widgetWithText(ElevatedButton, '我要預約');
        expect(
          tester.getSize(button).width,
          greaterThanOrEqualTo(width < 720 ? width - 40 : 680),
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomTypeDetailContent(
            roomType: {...rooms.first, 'width': 60, 'depth': null, 'height': 0},
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('60 cm'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('預約與介紹模式回呼保留，後台預覽不觸發', (tester) async {
    int book = 0, select = 0;
    for (final intro in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: RoomTypeDetailBookBar(
              theme: theme,
              isIntroMode: intro,
              onBook: () => book++,
              onSelectOptions: () => select++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
    }
    expect(book, 1);
    expect(select, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RoomTypeDetailBookBar(
            theme: theme,
            isIntroMode: true,
            previewOnly: true,
            onBook: () => book++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(book, 1);
  });

  testWidgets('兩個分頁保留草稿、取消離開、僅局部儲存外觀，儲存失敗不清草稿', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey<RoomIntroAppearanceEditorState>();
    final stream = Stream.value(rooms);
    Map<String, dynamic>? saved;
    bool fail = true;
    Future<void> pump(bool detail) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomIntroAppearanceScope(
            appearance: const RoomIntroAppearance(),
            theme: theme,
            child: RoomIntroAppearanceEditor(
              key: key,
              shopId: 'test',
              detailMode: detail,
              roomTypesStream: stream,
              saveAppearance: (updates) async {
                if (fail) throw StateError('失敗');
                saved = updates;
              },
            ),
          ),
        ),
      ),
    );
    await pump(false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, '頁面標題'),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('room-list-appearance')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.widgetWithText(TextField, '頁面標題'), '我的房型');
    await tester.pump();
    await pump(true);
    await tester.pumpAndSettle();
    expect(key.currentState!.hasChanges, isTrue);
    final leave = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(await leave, isFalse);
    await pump(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '頁面標題'))
          .controller!
          .text,
      '我的房型',
    );
    await tester.tap(find.text('儲存外觀'));
    await tester.pumpAndSettle();
    expect(key.currentState!.hasChanges, isTrue);
    fail = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存外觀'));
    await tester.pumpAndSettle();
    expect(saved!.keys, ['homeAppearance.roomIntro.list']);
    expect((saved!.values.single as Map)['title'], '我的房型');
    expect(key.currentState!.hasChanges, isFalse);
    expect(tester.takeException(), isNull);
  });
}
