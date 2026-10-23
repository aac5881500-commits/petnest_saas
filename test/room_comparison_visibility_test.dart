// 功能：共用比較開關、排版回退、跨分頁草稿與離開保護的局部驗證。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_list.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_comparison.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_related.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_scope.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_intro_appearance_editor.dart';

const theme = HomeThemeModel.classicDefault;
const rooms = <Map<String, dynamic>>[
  {'id': 'a', 'name': 'A', 'description': '介紹 A'},
  {'id': 'b', 'name': 'B'},
];

void main() {
  test('缺欄位預設開啟，序列化與 copyWith 保留共用設定和比較排版', () {
    expect(RoomIntroAppearance.fromMap(null).showComparison, isTrue);
    final original = const RoomIntroAppearance(
      list: RoomListAppearance(layout: 'comparison'),
    ).copyWith(showComparison: false);
    final restored = RoomIntroAppearance.fromShop({
      'homeAppearance': {'roomIntro': original.toMap()},
    });
    expect(restored.showComparison, isFalse);
    expect(
      restored.copyWith(detail: const RoomDetailAppearance()).showComparison,
      isFalse,
    );
    expect(restored.list.layout, 'comparison');
    expect(const RoomIntroAppearance().showComparison, isTrue);
  });

  testWidgets('所有列表與詳細排版共用開關，比較版關閉後保留一般列表', (tester) async {
    for (final width in [390.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final layout in [
        'vertical',
        'horizontal',
        'columns',
        'carousel',
        'switcher',
        'comparison',
        'lodging',
      ]) {
        for (final enabled in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RoomIntroList(
                    rooms: rooms,
                    setting: RoomListAppearance(layout: layout),
                    showComparison: enabled,
                    theme: theme,
                    onOpen: (_) {},
                    onCompare: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('比較房型'), enabled ? findsOneWidget : findsNothing);
          expect(
            find.byType(RoomIntroComparison),
            enabled && layout == 'comparison' ? findsOneWidget : findsNothing,
          );
          expect(find.text('A'), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      }
      for (final layout in [
        'classic',
        'compact',
        'sideBySide',
        'tabs',
        'panel',
        'anchors',
        'lodging',
      ]) {
        for (final enabled in [true, false]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: RoomIntroAppearanceScope(
                  appearance: RoomIntroAppearance(
                    showComparison: enabled,
                    detail: RoomDetailAppearance(layout: layout),
                  ),
                  theme: theme,
                  child: RoomIntroRelated(
                    shopId: 'local',
                    theme: theme,
                    compare: const Text('比較入口'),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('比較入口'), enabled ? findsOneWidget : findsNothing);
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('草稿即時預覽、取消恢復與僅儲存共用欄位後重開', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey<RoomIntroAppearanceEditorState>();
    final writes = <Map<String, dynamic>>[];
    Widget screen(RoomIntroAppearance appearance, {bool detail = false}) =>
        MaterialApp(
          home: Scaffold(
            body: RoomIntroAppearanceScope(
              appearance: appearance,
              theme: theme,
              child: RoomIntroAppearanceEditor(
                key: key,
                shopId: 'local',
                detailMode: detail,
                roomTypesStream: Stream.value(rooms),
                saveAppearance: (data) async => writes.add(data),
              ),
            ),
          ),
        );
    const initial = RoomIntroAppearance(
      list: RoomListAppearance(layout: 'comparison'),
    );
    await tester.pumpWidget(screen(initial));
    await tester.pumpAndSettle();
    expect(find.byType(RoomIntroComparison), findsOneWidget);
    await tester.tap(find.text('顯示比較房型'));
    await tester.pumpAndSettle();
    expect(find.text('比較房型'), findsNothing);
    expect(find.byType(RoomIntroComparison), findsNothing);
    expect(find.byKey(const ValueKey('room-intro-card-a')), findsOneWidget);
    expect(key.currentState!.hasChanges, isTrue);
    await tester.pumpWidget(screen(initial, detail: true));
    await tester.pumpAndSettle();
    expect(find.text('比較房型'), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '顯示比較房型'))
          .value,
      isFalse,
    );
    final staying = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(await staying, isFalse);
    expect(key.currentState!.hasChanges, isTrue);
    expect(find.text('比較房型'), findsNothing);
    await tester.pumpWidget(screen(initial));
    await tester.pumpAndSettle();
    final leaving = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放棄變更並離開'));
    await tester.pumpAndSettle();
    expect(await leaving, isTrue);
    expect(find.text('比較房型'), findsOneWidget);
    expect(find.byType(RoomIntroComparison), findsOneWidget);
    expect(writes, isEmpty);
    await tester.tap(find.text('顯示比較房型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存外觀'));
    await tester.pumpAndSettle();
    expect(writes.single, {'homeAppearance.roomIntro.showComparison': false});
    expect(key.currentState!.hasChanges, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      screen(
        RoomIntroAppearance.fromMap({
          'showComparison': false,
          'list': {'layout': 'comparison'},
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('比較房型'), findsNothing);
    expect(find.byType(RoomIntroComparison), findsNothing);
    expect(key.currentState!.hasChanges, isFalse);
  });
}
