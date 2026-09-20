// 檔案名稱：test/shop_room_type_editor_layout_test.dart
// 功能說明：房型編輯器桌機左右分欄、窄螢幕單欄切換預覽

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, {required double width}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: width,
          height: 900,
          child: const ShopRoomTypeEditorPage(shopId: 'shop-test'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('390 與 800 為單欄，可切換預覽且草稿保留', (WidgetTester tester) async {
    for (final double width in <double>[390, 430, 800]) {
      await pumpEditor(tester, width: width);
      expect(
        find.byKey(const ValueKey<String>('shop-room-type-editor-mobile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shop-room-type-editor-split')),
        findsNothing,
      );
      await tester.enterText(find.widgetWithText(TextField, '房型名稱'), '豪華套房');
      await tester.pump();
      await tester.tap(find.text('預覽'));
      await tester.pump();
      expect(find.text('顧客看到的房型介紹'), findsOneWidget);
      expect(find.text('豪華套房'), findsWidgets);
      expect(find.text('尚未填寫介紹'), findsOneWidget);
      expect(find.text('尚未填寫每晚價格'), findsOneWidget);
      await tester.tap(find.text('編輯'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '房型名稱'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '房型名稱'))
            .controller
            ?.text,
        '豪華套房',
      );
    }
  });

  testWidgets('1366 與 1920 為左預覽右表單', (WidgetTester tester) async {
    for (final double width in <double>[1366, 1920]) {
      await pumpEditor(tester, width: width);
      expect(
        find.byKey(const ValueKey<String>('shop-room-type-editor-split')),
        findsOneWidget,
      );
      expect(find.byType(ShopRoomTypeLivePreview), findsOneWidget);
      expect(find.text('新增房型'), findsWidgets);
      expect(find.text('儲存房型'), findsOneWidget);
    }
  });

  testWidgets('編輯模式儲存按鈕文案為儲存房型', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 1366,
          height: 900,
          child: ShopRoomTypeEditorPage(
            shopId: 'shop-test',
            existing: <String, dynamic>{
              'id': 'rt1',
              'name': '標準房',
              'price': 1200,
              'capacity': 2,
              'totalRooms': 3,
              'description': '安靜舒適',
              'extraPrice': 200,
              'width': 120,
              'depth': 90,
              'height': 200,
              'features': <String>['camera'],
              'customFeatures': <Map<String, String>>[
                <String, String>{'icon': '💊', 'name': '藥盒'},
              ],
              'images': <String>[],
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('儲存房型'), findsOneWidget);
    expect(find.text('標準房'), findsWidgets);
    expect(find.text('安靜舒適'), findsWidgets);
    expect(find.textContaining('每多一隻 +200 元'), findsOneWidget);
  });
}
