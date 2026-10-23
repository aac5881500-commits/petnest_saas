// 功能：新版房型瀏覽、比較及裝飾序列化的局部驗證，不連線正式資料。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_list.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_comparison.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_facts.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_type_detail_content.dart';

const listLayouts = [
  'vertical',
  'columns',
  'horizontal',
  'carousel',
  'switcher',
  'comparison',
  'lodging',
];
const detailLayouts = [
  'classic',
  'compact',
  'tabs',
  'sideBySide',
  'panel',
  'anchors',
  'lodging',
];
const theme = HomeThemeModel.classicDefault;
final rooms = <Map<String, dynamic>>[
  {
    'id': 'a',
    'name': '很長的房型名稱 Long Room Name 保持完整可讀',
    'description': '第一間的真實介紹',
    'price': 1300,
    'capacity': 2,
    'width': 60,
    'features': ['camera'],
  },
  {
    'id': 'b',
    'name': '標準房',
    'description': '第二間的介紹',
    'capacity': 1,
    'extraPrice': 200,
    'features': ['private_space'],
  },
  {'id': 'c', 'name': '安靜房'},
];
void main() {
  test('全部版型識別、獨立裝飾、未知值與缺值安全讀回', () {
    for (final layout in listLayouts) {
      final original = RoomListAppearance(
        layout: layout,
        look: const RoomIntroLook(
          textSize: 'large',
          background: 'library',
          backgroundAssetId: 'public-background',
        ),
      );
      final result = RoomListAppearance.fromMap(original.toMap());
      expect(result.layout, layout);
      expect(result.look.toMap(), original.look.toMap());
      expect(
        result.copyWith(layout: 'lodging').look.toMap(),
        original.look.toMap(),
      );
    }
    for (final layout in detailLayouts) {
      final setting = RoomDetailAppearance(
        layout: layout,
        look: const RoomIntroLook(shadow: true),
      );
      expect(RoomDetailAppearance.fromMap(setting.toMap()).layout, layout);
    }
    expect(RoomListAppearance.fromMap({'layout': 'future'}).layout, 'vertical');
    expect(RoomDetailAppearance.fromMap({'layout': 900}).layout, 'classic');
    expect(
      RoomIntroLook.fromMap({
        'radius': double.nan,
        'backgroundColor': 'bad',
        'backgroundAssetId': 'other/shop',
      }).toMap(),
      const RoomIntroLook().toMap(),
    );
    final missing = RoomIntroFacts({
      'price': 'bad',
      'capacity': 0,
      'width': -1,
    });
    expect(missing.price, '未提供');
    expect(missing.capacity, '未提供');
    expect(missing.dimensions, isEmpty);
    expect(missing.extra, '未提供');
  });
  testWidgets('七種列表在360、390、430及桌機、放大文字無溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [360.0, 390.0, 430.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      for (final layout in listLayouts) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoomIntroList(
                  key: ValueKey('$layout-$width'),
                  rooms: rooms,
                  setting: RoomListAppearance(layout: layout),
                  theme: theme,
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$layout $width');
        if (layout == 'carousel') {
          await tester.ensureVisible(find.byTooltip('下一個房型'));
          await tester.tap(find.byTooltip('下一個房型'));
          await tester.pumpAndSettle();
          expect(find.text('2 / 3'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SingleChildScrollView(
              child: RoomIntroList(
                rooms: rooms,
                setting: const RoomListAppearance(layout: 'lodging'),
                theme: theme,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('七種詳細結構在手機與桌機，分頁與面板互動正確', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [360.0, 390.0, 430.0, 1100.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final layout in detailLayouts) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoomTypeDetailContent(
                key: ValueKey('$layout-$width'),
                roomType: rooms.first,
                theme: theme,
                appearance: RoomDetailAppearance(layout: layout),
                showChrome: true,
                previewOnly: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$layout $width');
        if (layout == 'panel') {
          expect(find.text('第一間的真實介紹'), findsNothing);
          await tester.ensureVisible(find.text('展開完整內容'));
          await tester.tap(find.text('展開完整內容'));
          await tester.pumpAndSettle();
          expect(find.text('第一間的真實介紹'), findsOneWidget);
        }
        if (layout == 'tabs') {
          final chip = find.widgetWithText(ChoiceChip, '房型介紹');
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(find.text('第一間的真實介紹'), findsOneWidget);
          final dims = find.widgetWithText(ChoiceChip, '房間尺寸');
          await tester.ensureVisible(dims);
          await tester.tap(dims);
          await tester.pumpAndSettle();
          expect(find.text('第一間的真實介紹'), findsNothing);
          expect(find.text('60 cm'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('比較不重複房型，資料移除與單房型回退不產生假價格', (tester) async {
    Widget screen(List<Map<String, dynamic>> data) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RoomIntroComparison(
            rooms: data,
            theme: theme,
            onOpen: (_) {},
            initialId: 'b',
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(rooms));
    await tester.pumpAndSettle();
    var selectors = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .toList();
    expect(selectors.first.value, 'b');
    expect(selectors.last.value, isNot('b'));
    selectors.first.onChanged!('c');
    await tester.pump();
    await tester.pumpWidget(screen([rooms.first]));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.textContaining('只有一個房型'), findsOneWidget);
    expect(find.text('未提供'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(screen([]));
    await tester.pump();
    expect(find.text('目前沒有可比較的房型'), findsOneWidget);
  });
}
